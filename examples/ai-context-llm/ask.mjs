// Anpheros + an LLM of your choice (Node 18+).
//
// Asks a question about a patient's record: Anpheros builds a budgeted, source-labelled context
// from the patient's FHIR R4 record (POST /v1/context); this script sends it to any
// chat-completions endpoint that follows the OpenAI API format — for example a local Ollama
// server (http://localhost:11434/v1) or a hosted provider that offers that format.
// Anpheros has no built-in integration with any model provider; this is ordinary client code.
//
//   ANPHEROS_KEY=sk_test_… PATIENT_ID=… LLM_BASE_URL=http://localhost:11434/v1 LLM_MODEL=llama3.1 \
//   node ask.mjs "How has my blood pressure changed?"
//
// With a hosted model the context leaves your infrastructure for that provider: make sure consent
// and agreements cover it. Docs: https://developers.anpheros.com/guides/llm-healthcare-data
import { Anpheros, apiKey } from '@anpheros/sdk';

const { ANPHEROS_KEY, ANPHEROS_BASE_URL, PATIENT_ID, LLM_BASE_URL, LLM_MODEL, LLM_API_KEY } = process.env;
const question = process.argv.slice(2).join(' ') || 'Summarise my recent measurements.';
if (!ANPHEROS_KEY?.startsWith('sk_test_') || !PATIENT_ID || !LLM_BASE_URL || !LLM_MODEL) {
  console.error('Set ANPHEROS_KEY (sandbox), PATIENT_ID, LLM_BASE_URL and LLM_MODEL (and LLM_API_KEY for hosted providers).');
  process.exit(1);
}

// 1. Context from Anpheros: only what the task needs, within a token budget, with sources.
const anpheros = new Anpheros({ auth: apiKey(ANPHEROS_KEY), baseUrl: ANPHEROS_BASE_URL });
const ctx = await anpheros.context.build({ patient: PATIENT_ID, task: 'answer a patient question', question, budget_tokens: 1500, format: 'text' });

// 2. The prompt keeps the provenance labels and says how to use them.
const system = [
  'You help a person understand their own health record. Use only the context below.',
  'Each item is labelled with its author type (patient, practitioner, device, import, derived) and source;',
  'items under ai_notes were written by an AI earlier and are not verified. Say which items you rely on.',
  ctx.omitted.length ? `The context is partial; left out: ${ctx.omitted.join(', ')}.` : '',
  'Do not diagnose or change treatment; suggest discussing concerns with a clinician.',
].filter(Boolean).join(' ');

// 3. Any OpenAI-format chat-completions endpoint.
const res = await fetch(`${LLM_BASE_URL.replace(/\/$/, '')}/chat/completions`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', ...(LLM_API_KEY ? { Authorization: `Bearer ${LLM_API_KEY}` } : {}) },
  body: JSON.stringify({ model: LLM_MODEL, messages: [
    { role: 'system', content: system },
    { role: 'user', content: `Context:\n${ctx.text}\n\nQuestion: ${question}` },
  ] }),
});
if (!res.ok) throw new Error(`Model endpoint answered ${res.status}: ${await res.text()}`);
const answer = (await res.json()).choices?.[0]?.message?.content ?? '';

// 4. Keep the manifest id with the answer: it records which parts of the record were used.
console.log(answer);
console.log(`\n[context ${ctx.manifest_id}: ${ctx.tokens_used} tokens, sections ${ctx.sections.map((s) => s.kind).join(', ')}]`);
