// Anpheros consent example (Node 18+, no framework).
//
// A minimal web app that asks a person for consent to read their Anpheros record (OAuth 2.1 +
// PKCE, SMART on FHIR scopes) and then shows their latest vital signs, active medications and
// conditions. It demonstrates the chain: application → Anpheros API → FHIR record → consent.
//
//   ANPHEROS_CLIENT_ID=client_… node server.mjs      then open http://localhost:3000
//
// Register the application first (public client, redirect URI http://localhost:3000/callback).
// Tokens are kept in memory for one demo session only; a real app stores them server-side per user.
// Docs: https://developers.anpheros.com/guides/authentication
import { createServer } from 'node:http';
import { randomBytes } from 'node:crypto';
import { Anpheros, OAuthAuth, OAuthFlow, generatePkce } from '@anpheros/sdk';

const baseUrl = process.env.ANPHEROS_BASE_URL ?? 'https://platform.anpheros.com';
const clientId = process.env.ANPHEROS_CLIENT_ID;
const redirectUri = process.env.ANPHEROS_REDIRECT_URI ?? 'http://localhost:3000/callback';
const port = Number(new URL(redirectUri).port || 3000);
if (!clientId) {
  console.error('Set ANPHEROS_CLIENT_ID to the client id of your registered application.');
  process.exit(1);
}

// Read-only access to vital signs and lab results, medications and conditions, for as long as the person allows.
const SCOPES = ['patient/Observation.rs', 'patient/MedicationStatement.rs', 'patient/Condition.rs', 'offline_access'];

const flow = new OAuthFlow({ baseUrl, clientId, redirectUri });
const pending = new Map();      // state → PKCE verifier, for the round trip to the consent page
let session = null;             // { anpheros, patient } after consent

const page = (title, body) => `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${title}</title>
<style>body{font:16px/1.5 system-ui,sans-serif;max-width:720px;margin:40px auto;padding:0 16px}a.btn{display:inline-block;padding:10px 18px;border-radius:999px;background:#0e1a33;color:#fff;text-decoration:none}li{margin:4px 0}</style>
</head><body>${body}</body></html>`;
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

async function home() {
  if (!session) {
    return page('Connect your health record', `<h1>Connect your health record</h1>
<p>This example app asks for read access to your vital signs, lab results, medications and conditions in Anpheros.
You choose the record and for how long; you can revoke access at any time from Anpheros.</p>
<p><a class="btn" href="/connect">Connect with Anpheros</a></p>`);
  }
  const { anpheros, patient } = session;
  const [vitals, labs, meds, conditions] = await Promise.all([
    anpheros.observations.list(patient, { category: 'vital-signs', limit: 10 }),
    anpheros.observations.list(patient, { category: 'laboratory', limit: 10 }),
    anpheros.medications.list(patient, { status: 'active' }),
    anpheros.conditions.list(patient, { clinical_status: 'active' }),
  ]);
  const obs = (o) => `<li>${esc(o.effective_at?.slice(0, 10))} — ${esc(o.display ?? o.code)}: ${
    o.value != null ? `${esc(o.value)} ${esc(o.unit)}` : esc(o.components?.map((c) => `${c.value}`).join('/'))}</li>`;
  return page('Your record', `<h1>Your record</h1>
<p>Patient id seen by this app: <code>${esc(patient)}</code> (other apps see a different id).</p>
<h2>Vital signs</h2><ul>${vitals.data.map(obs).join('') || '<li>None</li>'}</ul>
<h2>Lab results</h2><ul>${labs.data.map(obs).join('') || '<li>None</li>'}</ul>
<h2>Active medications</h2><ul>${meds.data.map((m) => `<li>${esc(m.display)} ${esc(m.dosage)}</li>`).join('') || '<li>None</li>'}</ul>
<h2>Active conditions</h2><ul>${conditions.data.map((c) => `<li>${esc(c.display ?? c.code)}</li>`).join('') || '<li>None</li>'}</ul>
<p><a href="/disconnect">Forget this session</a></p>`);
}

async function connect(res) {
  const pkce = await generatePkce();
  const state = randomBytes(16).toString('hex');
  pending.set(state, pkce);
  res.writeHead(302, { Location: flow.authorizeUrl({ scopes: SCOPES, state, pkce, purpose: 'treatment', lang: 'en' }) }).end();
}

async function callback(url, res) {
  const error = url.searchParams.get('error');
  const pkce = pending.get(url.searchParams.get('state') ?? '');
  if (error || !pkce) {
    res.writeHead(400, { 'Content-Type': 'text/html' }).end(page('Not connected', `<h1>Not connected</h1><p>${esc(error ?? 'Unknown or expired request.')}</p><p><a href="/">Back</a></p>`));
    return;
  }
  pending.delete(url.searchParams.get('state'));
  const tokens = await flow.exchange(url.searchParams.get('code'), pkce);
  const auth = new OAuthAuth({ tokens, onRefresh: flow.refresh });
  session = { anpheros: new Anpheros({ auth, baseUrl }), patient: tokens.patient };
  res.writeHead(302, { Location: '/' }).end();
}

createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  try {
    if (url.pathname === '/connect') return await connect(res);
    if (url.pathname === '/callback') return await callback(url, res);
    if (url.pathname === '/disconnect') { session = null; res.writeHead(302, { Location: '/' }).end(); return; }
    if (url.pathname === '/') { res.writeHead(200, { 'Content-Type': 'text/html' }).end(await home()); return; }
    res.writeHead(404).end();
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'text/html' }).end(page('Error', `<h1>Error</h1><pre>${esc(e.message)}${e.requestId ? `\nrequest id: ${esc(e.requestId)}` : ''}</pre>`));
  }
}).listen(port, () => console.log(`Open http://localhost:${port}`));
