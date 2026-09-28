// Anpheros quickstart (Node 18+).
//
// Writes and reads a patient's HL7 FHIR R4 record through the Anpheros Platform API:
// patient → blood pressure, diagnosis, medication → timeline → FHIR search → International
// Patient Summary → AI-ready context. Runs against the sandbox (synthetic data only).
//
//   ANPHEROS_KEY=sk_test_… node quickstart.mjs
//
// Docs: https://developers.anpheros.com/guides/build-a-healthcare-app
import { Anpheros, apiKey } from '@anpheros/sdk';

const key = process.env.ANPHEROS_KEY;
if (!key || !key.startsWith('sk_test_')) {
  console.error('Set ANPHEROS_KEY to a sandbox key (sk_test_…). Never use a production key in examples.');
  process.exit(1);
}
const anpheros = new Anpheros({ auth: apiKey(key), baseUrl: process.env.ANPHEROS_BASE_URL });

// 1. A patient owned by this project (your own, pairwise id for this person).
const patient = await anpheros.patients.create({ given: 'Ana', family: 'Example', birth_date: '1980-05-17', gender: 'female' });
console.log(`Patient ${patient.id} (${patient.fhir})`);

// 2. Medical data, each write attributed to its author (provenance is recorded by the platform).
const now = new Date().toISOString();
await anpheros.observations.create(patient.id, {
  code: '85354-9', display: 'Blood pressure panel', category: 'vital-signs', effective_at: now, author_type: 'device',
  components: [
    { code: '8480-6', display: 'Systolic blood pressure', value: 128, unit: 'mm[Hg]' },
    { code: '8462-4', display: 'Diastolic blood pressure', value: 82, unit: 'mm[Hg]' },
  ],
});
await anpheros.observations.create(patient.id, {
  code: '4548-4', display: 'Hemoglobin A1c', category: 'laboratory', effective_at: now,
  value: 6.4, unit: '%', reference_range: { low: 4.0, high: 5.6 }, author_type: 'import',
});
await anpheros.conditions.create(patient.id, { code: 'I10', display: 'Essential hypertension', onset: '2024-03-01', author_type: 'practitioner' });
await anpheros.medications.create(patient.id, { display: 'Amlodipine 5 mg', code: 'C08CA01', dosage: '1 tablet in the morning', start: '2024-03-01', author_type: 'patient' });

// 3. Read it back: a filtered list and the chronological timeline.
const labs = await anpheros.observations.list(patient.id, { category: 'laboratory' });
console.log('Lab results:', labs.data.map((o) => `${o.display} ${o.value} ${o.unit}`));
const timeline = await anpheros.timeline.list(patient.id);
console.log('Timeline:', timeline.data.map((t) => `${t.date ?? '—'} ${t.type}: ${t.title}`));

// 4. The same data as strict FHIR R4.
const bundle = await anpheros.fhir.search('Observation', { patient: patient.id, code: 'http://loinc.org|4548-4' });
console.log(`FHIR search: ${bundle.entry?.length ?? 0} Observation(s)`);

// 5. An International Patient Summary (a FHIR document bundle).
const ips = await anpheros.fhir.summary(patient.id);
console.log(`IPS: ${ips.entry?.length ?? 0} entries in a ${ips.type} bundle`);

// 6. An AI-ready context for a model of your choice (Anpheros does not call any model).
const ctx = await anpheros.context.build({ patient: patient.id, task: 'medication review', question: 'How is blood pressure controlled?', budget_tokens: 800, format: 'text' });
console.log(`Context: ${ctx.tokens_used}/${ctx.budget_tokens} tokens, sections: ${ctx.sections.map((s) => s.kind).join(', ')}`);
console.log(ctx.text);
