// Anpheros lab integration (Node 18+).
//
// A laboratory's report → FHIR R4 laboratory Observations in a patient's record:
//   1. a test patient owned by this project;
//   2. the report sent as HL7 v2 ORU^R01 (report.hl7) or CSV (report.csv);
//   3. what was mapped to LOINC, what was not, and the resulting FHIR Observation;
//   4. the same report sent again: rows already imported are skipped, nothing is duplicated.
// Runs against the sandbox only; the report is synthetic.
//
//   ANPHEROS_KEY=sk_test_… node import.mjs            # HL7 v2
//   ANPHEROS_KEY=sk_test_… node import.mjs csv        # CSV
//
// Docs: https://developers.anpheros.com/guides/import-lab-results-fhir
import { readFile } from 'node:fs/promises';
import { Anpheros, AnpherosError, apiKey } from '@anpheros/sdk';

const key = process.env.ANPHEROS_KEY;
if (!key || !key.startsWith('sk_test_')) {
  console.error('Set ANPHEROS_KEY to a sandbox key (sk_test_…). Get one at https://platform.anpheros.com/dashboard/ → Get a sandbox key.');
  process.exit(1);
}
const format = process.argv[2] === 'csv' ? 'csv' : 'hl7';
const anpheros = new Anpheros({ auth: apiKey(key), baseUrl: process.env.ANPHEROS_BASE_URL });
const SOURCE = 'example-lab'; // your lab system's name, recorded in Provenance

try {
  // 1. The patient. A real lab would look the patient up by an identifier it shares with your app.
  const patient = await anpheros.patients.create({ given: 'Lab', family: 'Example', birth_date: '1975-02-11', gender: 'male' });
  console.log(`Patient ${patient.id}`);

  // 2. The report, as the lab sends it.
  const report = await readFile(new URL(format === 'csv' ? './report.csv' : './report.hl7', import.meta.url), 'utf8');
  const send = () => format === 'csv'
    ? anpheros.labs.importCsv(patient.id, report, { sourceSystem: SOURCE })
    : anpheros.labs.importHl7(patient.id, report.replace(/\r?\n/g, '\r'), { sourceSystem: SOURCE });
  const first = await send();
  console.log(`\nImported ${format.toUpperCase()}: created ${first.created}, skipped ${first.skipped}`);
  for (const o of first.observations) console.log(`  ${o.marker} = ${o.value} ${o.unit ?? ''}  →  ${o.system}|${o.code}`);
  if (first.unmapped.length) console.log(`  Not mapped to LOINC (kept with the lab's own code): ${first.unmapped.join(', ')}`);
  for (const w of first.warnings) console.log(`  Warning: ${w}`);

  // 3. One result as strict FHIR R4, with its reference range and LOINC coding.
  const bundle = await anpheros.fhir.search('Observation', { patient: patient.id, category: 'laboratory', _count: 1 });
  const obs = bundle.entry?.[0]?.resource;
  if (obs) console.log('\nFHIR Observation:\n' + JSON.stringify({ resourceType: obs.resourceType, status: obs.status, code: obs.code, valueQuantity: obs.valueQuantity, referenceRange: obs.referenceRange, effectiveDateTime: obs.effectiveDateTime }, null, 2));

  // 4. The lab resends the same report (a retry, a corrected batch): nothing is duplicated.
  const again = await send();
  console.log(`\nSent again: created ${again.created}, skipped ${again.skipped}`);
} catch (e) {
  if (!(e instanceof AnpherosError)) throw e;
  // Every API error has a status, a type, often the field at fault, and a request id to quote to support.
  const hint = {
    401: 'The key is wrong or revoked. Create a new one in the dashboard.',
    403: 'This key may not write to this patient (read-only key, or no consent covering it).',
    413: 'The report is too large: up to 500 rows per request.',
    422: 'The report could not be read. Check the format in https://developers.anpheros.com/guides/lab-connector',
    429: 'Rate limit or the sandbox daily write limit was reached. Try again later.',
  }[e.status] ?? '';
  console.error(`Anpheros error ${e.status} ${e.type}${e.field ? ` (field ${e.field})` : ''}: ${e.message}${e.requestId ? ` [request ${e.requestId}]` : ''}`);
  if (hint) console.error(hint);
  process.exit(1);
}
