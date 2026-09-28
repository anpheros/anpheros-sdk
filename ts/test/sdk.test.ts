import assert from 'node:assert/strict';
import { test } from 'node:test';

import { createHmac } from 'node:crypto';
import { Anpheros, AnpherosError, OAuthAuth, OAuthFlow, apiKey, bearer, generatePkce, verifyWebhookSignature } from '../src/index.js';

type Handler = (req: Request) => Response;

function fake(...script: Handler[]) {
  const calls: Request[] = [];
  const f = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const req = new Request(input, init);
    calls.push(req);
    const h = script[Math.min(calls.length - 1, script.length - 1)];
    return h ? h(req) : json({});
  }) as typeof fetch;
  return { f, calls };
}

const json = (body: unknown, status = 200, headers: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json', 'anpheros-request-id': 'req-1', ...headers } });

test('sends the key, parses pages', async () => {
  const { f, calls } = fake(() => json({ data: [{ id: 'p1', given: 'Elena', family: 'Ionescu', identifiers: [], fhir: 'Patient/p1' }], total: 5, next_cursor: 'NTA' }));
  const a = new Anpheros({ auth: apiKey('sk_test_x'), baseUrl: 'https://api.test', fetch: f });
  const page = await a.patients.list({ limit: 1 });
  assert.equal(calls[0].headers.get('authorization'), 'Bearer sk_test_x');
  assert.equal(calls[0].url, 'https://api.test/v1/patients?limit=1');
  assert.equal(page.total, 5);
  assert.equal(page.data[0].given, 'Elena');
  assert.equal(a.lastRequestId, 'req-1');
});

test('creates with Idempotency-Key and author headers', async () => {
  const { f, calls } = fake(() => json({ id: 'o1', patient: 'p1', code: '2339-0', fhir: 'Observation/o1', components: [], derived_from: [] }, 201));
  const a = new Anpheros({ auth: apiKey('sk_test_x'), baseUrl: 'https://api.test', fetch: f });
  const obs = await a.observations.create('p1', { code: '2339-0', category: 'laboratory', effective_at: '2026-09-19T08:10:00Z', value: 112, unit: 'mg/dL', author_type: 'device' }, { source_system: 'glucometer' });
  assert.equal(calls[0].method, 'POST');
  assert.equal(calls[0].headers.get('idempotency-key')?.length, 36);
  assert.equal(calls[0].headers.get('x-anpheros-source-system'), 'glucometer');
  assert.equal((await calls[0].json()).author_type, 'device');
  assert.equal(obs.fhir, 'Observation/o1');
});

test('turns errors into AnpherosError', async () => {
  const { f } = fake(
    () => json({ error: { type: 'invalid', message: 'given is required', field: 'given' } }, 400),
    () => json({ resourceType: 'OperationOutcome', issue: [{ severity: 'error', code: 'not-found', diagnostics: 'gone' }] }, 404),
  );
  const a = new Anpheros({ auth: apiKey('sk_test_x'), baseUrl: 'https://api.test', fetch: f, maxRetries: 0 });
  await assert.rejects(a.patients.create({ given: '', family: 'x' }), (e: AnpherosError) => e.status === 400 && e.field === 'given');
  await assert.rejects(a.fhir.read('Patient', 'x'), (e: AnpherosError) => e.isNotFound && e.type === 'not-found');
});

test('retries on 429 and refreshes on 401', async () => {
  const { f, calls } = fake(
    () => json({ error: { type: 'throttled', message: 'slow' } }, 429, { 'retry-after': '0' }),
    () => json({ error: { type: 'login', message: 'expired' } }, 401),
    () => json({ data: [], total: 0, next_cursor: null }),
  );
  let refreshed = 0;
  const auth = new OAuthAuth({ tokens: { access_token: 'at_old', refresh_token: 'rt_1', expires_in: 1800 }, onRefresh: async () => { refreshed++; return { access_token: 'at_new', refresh_token: 'rt_2', expires_in: 1800 }; } });
  const a = new Anpheros({ auth, baseUrl: 'https://api.test', fetch: f });
  const page = await a.patients.list();
  assert.equal(page.total, 0);
  assert.equal(calls.length, 3);
  assert.equal(refreshed, 1);
  assert.equal(calls[2].headers.get('authorization'), 'Bearer at_new');
  assert.equal(auth.current.refresh_token, 'rt_2');
});

test('oauth flow builds the url and exchanges the code', async () => {
  const { f, calls } = fake(() => json({ access_token: 'at_1', refresh_token: 'rt_1', expires_in: 1800, patient: 'pw' }));
  const flow = new OAuthFlow({ baseUrl: 'https://api.test', clientId: 'client_1', redirectUri: 'app://cb', fetch: f });
  const pkce = await generatePkce();
  const url = new URL(flow.authorizeUrl({ scopes: ['patient/*.r', 'offline_access'], state: 's', pkce, lang: 'ro' }));
  assert.equal(url.pathname, '/oauth/authorize');
  assert.equal(url.searchParams.get('code_challenge'), pkce.challenge);
  const tokens = await flow.exchange('c', pkce);
  const sent = new URLSearchParams(await calls[0].text());
  assert.equal(sent.get('code_verifier'), pkce.verifier);
  assert.equal(tokens.patient, 'pw');
  assert.ok(tokens.obtained_at);
});

test('me: my records, grants, access log and revoke with a user token', async () => {
  const { f, calls } = fake(
    () => json({ data: [{ id: 'p1', given: 'Ana', family: 'Pop', birth_date: null, relationship: 'self' }] }),
    () => json({ data: [{ id: 'g1', status: 'active', purpose: 'care', application: { id: 'app_1', name: 'Clinica X', kind: 'confidential', organization: 'X SRL', privacy_url: null },
      scopes: ['patient/Observation.r'], scopes_text: ['Citește analizele'], granted_at: '2026-09-01T00:00:00Z', expires_at: null, revoked_at: null, granted_by: 'patient', consent: null,
      access_count: 3, last_access_at: '2026-09-18T10:00:00Z' }] }),
    () => json({ data: [{ ts: '2026-09-18T10:00:00Z', action: 'search', resource_type: 'Observation', resource_id: null, status: 'ok' }] }),
    () => json({ id: 'g1', status: 'revoked', scopes: [], scopes_text: [], granted_by: 'patient' }),
  );
  const a = new Anpheros({ auth: bearer('firebase-id-token'), baseUrl: 'https://api.test', fetch: f });
  const mine = await a.me.patients();
  assert.equal(mine[0].given, 'Ana');
  assert.equal(calls[0].headers.get('authorization'), 'Bearer firebase-id-token');
  assert.equal(calls[0].url, 'https://api.test/me/patients?environment=production');
  const grants = await a.me.grants('p1', { lang: 'ro' });
  assert.equal(grants[0].access_count, 3);
  assert.equal(calls[1].url, 'https://api.test/me/patients/p1/grants?lang=ro&environment=production');
  const log = await a.me.accessLog('p1', 'g1');
  assert.equal(log[0].resource_type, 'Observation');
  const revoked = await a.me.revoke('p1', 'g1', { reason: 'patient' });
  assert.equal(revoked.status, 'revoked');
  assert.equal(calls[3].method, 'POST');
});

test('webhooks: create, ping, deliveries and signature verification', async () => {
  const { f, calls } = fake(
    () => json({ id: 'whe_1', url: 'https://x/hook', events: ['*'], active: true, environment: 'sandbox', secret: 'whsec_abc' }, 201),
    () => json({ id: 'whd_1', endpoint_id: 'whe_1', event_id: 'evt_1', event_type: 'ping', status: 'delivered', attempts: 1, payload: {} }),
    () => json({ data: [{ id: 'whd_1', endpoint_id: 'whe_1', event_id: 'evt_1', event_type: 'resource.created', status: 'failed', attempts: 2, last_status_code: 500, payload: {} }] }),
  );
  const a = new Anpheros({ auth: apiKey('sk_test_x'), baseUrl: 'https://api.test', fetch: f });
  const ep = await a.webhooks.create('https://x/hook');
  assert.equal(ep.secret, 'whsec_abc');
  assert.equal(JSON.parse(await calls[0].text()).events[0], '*');
  assert.equal((await a.webhooks.ping(ep.id)).status, 'delivered');
  const log = await a.webhooks.deliveries(ep.id, { status: 'failed' });
  assert.equal(log[0].last_status_code, 500);
  assert.equal(calls[2].url, 'https://api.test/v1/webhooks/whe_1/deliveries?status=failed&limit=50');
  const body = '{"a":1}';
  const ts = 1_800_000_000;
  const sig = createHmac('sha256', 'whsec_abc').update(`${ts}.${body}`).digest('hex');
  assert.equal(await verifyWebhookSignature({ secret: 'whsec_abc', header: `t=${ts},v1=${sig}`, body, now: ts + 10 }), true);
  assert.equal(await verifyWebhookSignature({ secret: 'whsec_no', header: `t=${ts},v1=${sig}`, body, now: ts + 10 }), false);
  assert.equal(await verifyWebhookSignature({ secret: 'whsec_abc', header: `t=${ts},v1=${sig}`, body, now: ts + 1000 }), false);
});
