# AI context + an LLM of your choice

Answers a question about a patient's record in three steps:

1. **Anpheros** builds a context from the patient's FHIR R4 record — only the relevant sections, within a token budget, each item labelled with its author type and source (`POST /v1/context`);
2. the script builds a prompt that keeps those labels and tells the model how to use them;
3. it sends the prompt to **any chat-completions endpoint in the OpenAI API format** — for example a local Ollama server or a hosted provider that offers that format.

Anpheros has no built-in integration with any model provider; the model call is ordinary client code, and the model never receives Anpheros credentials.

```bash
npm install
# a local model served by Ollama
ANPHEROS_KEY=sk_test_… PATIENT_ID=… LLM_BASE_URL=http://localhost:11434/v1 LLM_MODEL=<model> \
  npm start -- "How has my blood pressure changed?"
# a hosted provider: set LLM_BASE_URL, LLM_MODEL and LLM_API_KEY
```

With a local model, the prompt and the answer stay on your machine; with a hosted one, the context is sent to that provider — the person's consent and your agreements must cover it. The script prints the context's `manifest_id`, which records which parts of the record the answer was based on.

Docs: [LLM applications and healthcare data](https://developers.anpheros.com/guides/llm-healthcare-data) · [AI medical assistant](https://developers.anpheros.com/guides/ai-medical-assistant)
