// Anpheros backend starter (Node 18+, no framework).
//
// The shape of a healthcare app's backend on Anpheros: the API key stays on this server, the
// app's frontend talks only to these routes, and every Anpheros error becomes a clear answer.
//
//   GET  /api/patients                 the project's patients (in the sandbox: 30 synthetic ones)
//   GET  /api/patients/:id/summary     latest vital signs and labs, conditions, medications
//   POST /api/patients/:id/weight      {"kg": 72.5} → a body-weight Observation (LOINC 29463-7)
//   GET  /api/patients/:id/fhir        the same record as strict FHIR R4 (Patient/$everything)
//
//   ANPHEROS_KEY=sk_test_… node server.mjs        then open http://localhost:3000/api/patients
//
// Docs: https://developers.anpheros.com/guides/healthcare-api-typescript
import { createServer } from 'node:http';
import { Anpheros, AnpherosError, apiKey } from '@anpheros/sdk';

const key = process.env.ANPHEROS_KEY;
if (!key || !/^sk_(test|live)_/.test(key)) {
  console.error('Set ANPHEROS_KEY to an API key. For this example use a sandbox key (sk_test_…): https://platform.anpheros.com/dashboard/');
  process.exit(1);
}
if (key.startsWith('sk_live_') && process.env.ALLOW_LIVE !== '1') {
  console.error('This is a production key. The starter refuses it unless ALLOW_LIVE=1 is set on purpose.');
  process.exit(1);
}
const anpheros = new Anpheros({ auth: apiKey(key), baseUrl: process.env.ANPHEROS_BASE_URL });
const PORT = Number(process.env.PORT ?? 3000);

class BadRequest extends Error { constructor(message, field) { super(message); this.field = field; } }

const routes = [
  ['GET', /^\/api\/patients$/, async () => {
    const page = await anpheros.patients.list({ limit: 50 });
    return { total: page.total, patients: page.data.map((p) => ({ id: p.id, name: [p.given, p.family].filter(Boolean).join(' '), birth_date: p.birth_date, gender: p.gender })) };
  }],
  ['GET', /^\/api\/patients\/([^/]+)\/summary$/, async ([id]) => {
    const [patient, vitals, labs, conditions, medications] = await Promise.all([
      anpheros.patients.get(id),
      anpheros.observations.list(id, { category: 'vital-signs', limit: 200 }),
      anpheros.observations.list(id, { category: 'laboratory', limit: 200 }),
      anpheros.conditions.list(id, { clinical_status: 'active' }),
      anpheros.medications.list(id, { status: 'active' }),
    ]);
    return {
      patient: { id: patient.id, name: [patient.given, patient.family].filter(Boolean).join(' '), birth_date: patient.birth_date },
      vital_signs: latestByCode(vitals.data), labs: latestByCode(labs.data),
      conditions: conditions.data.map((c) => ({ code: c.code, display: c.display, onset: c.onset })),
      medications: medications.data.map((m) => ({ display: m.display, dosage: m.dosage, start: m.start })),
    };
  }],
  ['POST', /^\/api\/patients\/([^/]+)\/weight$/, async ([id], body) => {
    const kg = Number(body?.kg);
    if (!Number.isFinite(kg) || kg < 1 || kg > 400) throw new BadRequest('kg must be a number between 1 and 400', 'kg');
    const o = await anpheros.observations.create(id, {
      code: '29463-7', display: 'Body weight', category: 'vital-signs', value: kg, unit: 'kg',
      effective_at: new Date().toISOString(), author_type: 'patient',
    });
    return { id: o.id, fhir: o.fhir, value: o.value, unit: o.unit, effective_at: o.effective_at };
  }],
  ['GET', /^\/api\/patients\/([^/]+)\/fhir$/, async ([id]) => anpheros.fhir.everything(id)],
];

// Latest value of each code, newest first.
function latestByCode(list) {
  const seen = new Map();
  for (const o of [...list].sort((a, b) => String(b.effective_at).localeCompare(String(a.effective_at)))) {
    if (seen.has(o.code)) continue;
    seen.set(o.code, {
      code: o.code, display: o.display, date: o.effective_at,
      value: o.components.length ? o.components.map((c) => `${c.value}`).join('/') : o.value ?? o.value_text, unit: o.components[0]?.unit ?? o.unit,
    });
  }
  return [...seen.values()];
}

// Anpheros errors → answers your frontend can show. Never pass the key or the raw upstream body to the browser.
function toResponse(e) {
  if (e instanceof BadRequest) return [400, { error: 'invalid_input', message: e.message, field: e.field }];
  if (!(e instanceof AnpherosError)) { console.error(e); return [500, { error: 'internal', message: 'Unexpected error' }]; }
  console.error(`Anpheros ${e.status} ${e.type}: ${e.message} [request ${e.requestId ?? '–'}]`);
  const map = {
    0: [502, 'Anpheros could not be reached'],
    401: [502, 'The server\'s Anpheros key is invalid or revoked'],          // a server problem, not the user's
    403: [403, 'No access to this patient (consent missing, expired or revoked, or a read-only key)'],
    404: [404, 'Patient or record not found in this project'],
    409: [409, 'The record changed meanwhile; reload and retry'],
    422: [422, e.message],                                                      // validation: the message names the problem
    429: [503, 'Too many requests; try again shortly'],
  };
  const [status, message] = map[e.status] ?? [502, 'Anpheros returned an error'];
  return [status, { error: e.type, message, field: e.field, request_id: e.requestId }];
}

async function readJson(req) {
  let raw = '';
  for await (const chunk of req) { raw += chunk; if (raw.length > 100_000) throw new BadRequest('Body too large'); }
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { throw new BadRequest('Body must be JSON'); }
}

createServer(async (req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  let status = 404, payload = { error: 'not_found', message: 'No such route' };
  for (const [method, pattern, handler] of routes) {
    const m = path.match(pattern);
    if (!m || req.method !== method) continue;
    try {
      payload = await handler(m.slice(1).map(decodeURIComponent), method === 'POST' ? await readJson(req) : null);
      status = method === 'POST' ? 201 : 200;
    } catch (e) { [status, payload] = toResponse(e); }
    break;
  }
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload, null, 2));
}).listen(PORT, () => console.log(`Backend on http://localhost:${PORT}  (Anpheros: ${anpheros.baseUrl}, ${key.startsWith('sk_test_') ? 'sandbox' : 'PRODUCTION'})`));
