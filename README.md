# Anpheros SDKs and examples

**Anpheros is interoperable medical-data infrastructure for building healthcare applications, medical software and AI services.** Each patient has one HL7 FHIR R4 record that they control; applications, clinics, laboratories and AI agents read and write it through the Anpheros Platform API — with patient consent (OAuth 2.1 / SMART on FHIR), provenance on every write and an access log the patient can see. This repository contains the official client libraries and runnable examples.

| Language | Package | Install | Source |
|---|---|---|---|
| Dart / Flutter | [`anpheros_sdk`](https://pub.dev/packages/anpheros_sdk) | `dart pub add anpheros_sdk` | [`dart/anpheros_sdk`](https://github.com/anpheros/anpheros-sdk/tree/main/dart/anpheros_sdk) |
| TypeScript (Node 18+, browsers, Deno, Bun) | [`@anpheros/sdk`](https://www.npmjs.com/package/@anpheros/sdk) | `npm install @anpheros/sdk` | [`ts`](https://github.com/anpheros/anpheros-sdk/tree/main/ts) |

## Who it is for

Developers building patient and family health apps, medical-app backends, clinic and laboratory integrations, and AI assistants or agents that need a patient's structured medical context — without designing a medical database, a consent system and an audit trail from scratch.

## Get a sandbox key

The sandbox is free and self-service. Sign in with Google on the [dashboard](https://platform.anpheros.com/dashboard/) and press **Get a sandbox key**: you get a sandbox project and a key instantly. Every sandbox project comes with its own 30 synthetic patients — six months of conditions, medications, allergies, lab results and vital signs — that you can change freely and reset at any time. Sandbox keys (`sk_test_…`) never reach real patient data.

When you go live, production is for verified organisations with a data processing agreement, and production starts at €49 a month with the first month free ([pricing](https://developers.anpheros.com/guides/pricing)).

## Connect

```ts
import { Anpheros, apiKey } from '@anpheros/sdk';

const anpheros = new Anpheros({ auth: apiKey(process.env.ANPHEROS_KEY!) });   // sk_test_… in the sandbox
const { data: patients } = await anpheros.patients.list();
const labs = await anpheros.observations.list(patients[0].id, { category: 'laboratory', limit: 10 });
const ctx = await anpheros.context.build({ patient: patients[0].id, task: 'weekly check-in', budget_tokens: 1500, format: 'text' });
```

```dart
import 'package:anpheros_sdk/anpheros_sdk.dart';

final anpheros = Anpheros(auth: AnpherosAuth.apiKey('sk_test_…'));
final patients = await anpheros.patients.list();
final labs = await anpheros.observations.list(patients.data.first.id, category: 'laboratory', limit: 10);
```

API keys belong on servers. An app acting for a person uses OAuth instead: both SDKs implement the consent flow (authorization code + PKCE) and refresh tokens automatically.

## What the SDKs cover

Both cover the whole public surface (`/v1`, `/fhir/R4`, `/oauth/token`, `/oauth/revoke`) with the
same shape: `patients`, `observations`, `conditions`, `medications`, `documents`, `timeline`,
`provenance`, `context`, `grants`, `terminology` and raw `fhir`. A test fails the
build when a public route is missing from either SDK or when an SDK calls a route the server
does not have.

Both SDKs: automatic `Idempotency-Key` on creates, retries with backoff on 429/5xx, one token
refresh on 401, typed errors with the request id, PKCE helpers and the consent flow.

## Medical data and FHIR

The record is made of standard FHIR R4 resources — 26 types, including `Observation`, `Condition`, `MedicationStatement`, `DocumentReference`, `Immunization` and `AllergyIntolerance` — coded with LOINC, ICD-10, ATC and UCUM. The REST API (`/v1`) and the FHIR API (`/fhir/R4`) read and write the same resources with the same ids; `fhir` in both SDKs gives raw FHIR access (search, transactions, `$everything`, `$summary`, `$validate`).

## Examples

| Example | Shows |
|---|---|
| [quickstart-ts](https://github.com/anpheros/anpheros-sdk/tree/main/examples/quickstart-ts) | write and read a record: measurements, lab result, diagnosis, medication, timeline, FHIR search, IPS, AI context |
| [quickstart-dart](https://github.com/anpheros/anpheros-sdk/tree/main/examples/quickstart-dart) | the same from Dart / Flutter |
| [consent-app-ts](https://github.com/anpheros/anpheros-sdk/tree/main/examples/consent-app-ts) | a web app that asks for consent (OAuth 2.1 + PKCE) and reads the person's record |
| [ai-context-llm](https://github.com/anpheros/anpheros-sdk/tree/main/examples/ai-context-llm) | a question about a record answered by a model of your choice (local or hosted) |
| [fhir-transaction](https://github.com/anpheros/anpheros-sdk/tree/main/examples/fhir-transaction) | a FHIR R4 transaction bundle and the resulting International Patient Summary |

The examples run against the free sandbox, where each sandbox project has its own 30 synthetic patients — see [Get a sandbox key](#get-a-sandbox-key).

## Conformance

Raw test results, published so they can be checked (test results, not certifications): [conformance/](https://github.com/anpheros/anpheros-sdk/tree/main/conformance). On 28 September 2026 the Standalone Launch group of the Inferno SMART App Launch STU2 test kit (v1.0.3) passed 22 of 22 tests against the platform. EHR launch is not supported.

## Documentation

- Developer guides: https://developers.anpheros.com/guides/
- SDK guide: https://developers.anpheros.com/guides/sdks
- API reference (OpenAPI): https://developers.anpheros.com/docs
- For AI assistants: https://developers.anpheros.com/llms.txt
- Anpheros: https://anpheros.com/

## Issues and security

Report bugs in this repository's issues. Never include API keys, tokens or patient data in an issue. Security reports: contact@anpheros.com.

## License

Apache License 2.0 — see the `LICENSE` file of each package. Copyright 2026 Anpheros.
