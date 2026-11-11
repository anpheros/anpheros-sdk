// Health patterns end to end on a synthetic sandbox patient (Node 18+, sandbox key only).
//
//   ANPHEROS_KEY=sk_test_… node patterns.mjs [persona]      (default persona: p01)
//
// p01 carries a planted pattern: home blood pressure falling by about 8/5 mmHg over six months. The engine
// should report a decreasing systolic trend (LOINC 8480-6). Everything here is synthetic.
// Findings describe the record: not a diagnosis, not a cause, never a reason to change a medicine.
// Guide: https://developers.anpheros.com/guides/health-patterns-api
import { Anpheros, apiKey } from '@anpheros/sdk';

const { ANPHEROS_KEY, ANPHEROS_BASE_URL } = process.env;
const persona = process.argv[2] || 'p01';
if (!ANPHEROS_KEY?.startsWith('sk_test_')) {
  console.error('Set ANPHEROS_KEY to a sandbox key (sk_test_…).');
  process.exit(1);
}

const anpheros = new Anpheros({
  auth: apiKey(ANPHEROS_KEY),
  baseUrl: ANPHEROS_BASE_URL,
  // A real app shows crisis lines to the person here, at once.
  onSafety: (s) => console.log(`\n! ${s.value} after ${s.method} ${s.path}: show crisis lines now (${s.link})`),
});

// 1. The synthetic person.
const bundle = await anpheros.fhir.search('Patient', { identifier: `https://anpheros.com/fhir/sid/sandbox-persona|${persona}` });
const patientId = bundle.entry?.[0]?.resource?.id;
if (!patientId) throw new Error(`No sandbox persona ${persona}: reset the synthetic patients from the dashboard.`);

// 2. What changed over six months, computed now.
const run = await anpheros.patterns.run(patientId, { window_days: 180 });
console.log(`${run.findings.length} findings, engine ${run.engine_version}`);
for (const f of run.findings.filter((x) => x.statistically_supported)) {
  console.log(`- ${f.summary_text}`);
  console.log(`  period ${f.window.start} to ${f.window.end}; method ${f.method.name} ${f.method.version} (${f.method.maturity})`);
  console.log(`  limitations: ${f.limitations.map((l) => l.code).join(', ') || 'none'}; shown to the person: ${f.shown ?? false}`);
}

// 3. The resources behind the first supported finding.
const first = run.findings.find((x) => x.statistically_supported);
if (first) {
  const ev = await anpheros.patterns.evidence(patientId, first.id, { window_days: 180, limit: 5 });
  console.log(`\nEvidence (${ev.total} resources), first ${ev.data.length}:`);
  for (const e of ev.data) console.log(`  ${e.date} ${e.resource} = ${e.value}`);
}

// 4. The method registry: only patient-facing methods may reach a person, and only once a stored finding is shown.
const methods = await anpheros.patterns.methods();
const facing = methods.data.filter((m) => m.patient_facing).map((m) => m.name);
console.log(`\nPatient-facing methods: ${facing.join(', ')}`);

// 5. The safety header: a PHQ-9 whose item 9 is answered above 0 triggers onSafety.
await anpheros.fhir.create({
  resourceType: 'QuestionnaireResponse', status: 'completed', questionnaire: 'http://loinc.org/q/44249-1',
  subject: { reference: `Patient/${patientId}` }, authored: new Date().toISOString(),
  item: [{ linkId: '44260-8', answer: [{ valueInteger: 1 }] }],
});
const lines = await anpheros.patterns.crisisResources('US');
console.log(`Crisis lines: ${lines.text}`);
