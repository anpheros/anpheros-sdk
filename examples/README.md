# Anpheros examples

Runnable examples of building on **Anpheros**, interoperable medical-data infrastructure: a patient-controlled HL7 FHIR R4 record per person and an API for healthcare applications, software and AI services.

Every example runs against the **sandbox** — a separate database with synthetic patients — with a sandbox key (`sk_test_…`). Sandbox keys cannot reach real patient data. During the private beta, access is by request on [platform.anpheros.com](https://platform.anpheros.com/).

| Example | Shows | Language |
|---|---|---|
| [quickstart-ts](quickstart-ts) | patient → blood pressure, lab result, diagnosis, medication → timeline → FHIR search → International Patient Summary → AI context | TypeScript / Node 18+ |
| [quickstart-dart](quickstart-dart) | the same flow from Dart (and Flutter) | Dart 3.4+ |
| [consent-app-ts](consent-app-ts) | a web app that asks a person for consent (OAuth 2.1 + PKCE, SMART on FHIR scopes) and reads their record | TypeScript / Node 18+ |
| [ai-context-llm](ai-context-llm) | a question about a patient's record answered by a model of your choice (local or hosted), using the context API | TypeScript / Node 18+ |
| [fhir-transaction](fhir-transaction) | a FHIR R4 transaction bundle (Patient, Observation, Condition, MedicationStatement) and the resulting IPS | curl / FHIR JSON |

All examples read `ANPHEROS_BASE_URL` when it is set, so they can also point to a local or test instance; by default they use `https://platform.anpheros.com`.

## How they were checked

Each example was run on 28 September 2026 against a local instance of the platform with the synthetic sandbox data, using the published SDK packages (`@anpheros/sdk` 0.1.1 from npm, `anpheros_sdk` 0.1.1 from pub.dev). The consent example was run end to end with a simulated sign-in on the consent page; `ai-context-llm` was run with a local model served by Ollama.

## Documentation

- Guides: https://developers.anpheros.com/guides/
- Build a healthcare app: https://developers.anpheros.com/guides/build-a-healthcare-app
- API reference: https://developers.anpheros.com/docs
- Anpheros: https://anpheros.com/
