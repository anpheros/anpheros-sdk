# Changelog

## Unreleased

- Safety (additive): `AnpherosOptions.onSafety` is called whenever a response carries `X-Anpheros-Safety` (a PHQ-9 item 9
  answer above 0); `lastSafety` keeps the last signal and `safetySignal(headers)` reads it from a raw response. Show
  crisis lines at once with `patterns.crisisResources(country)`. README: a Health patterns section with examples.
- Health patterns, display rule (additive): `StoredPatternFinding.shown` / `shown_since` and `StoredPatterns.display_rule`
  (`PatternDisplayRule`): show a stored finding to the person only when `shown` and `method.patient_facing` are true;
  `PatternFinding.shown_only_if_supported` (selection subtypes) and `PatternNextStep.patient_facing`, so consumers need no
  hand-copied lists. `patterns.updated` may carry `shown` / `hidden` events and a `display` block; notify on `shown` only.
- Health patterns, engine 0.6.0 (additive): `PatternFinding.method` carries `maturity`, `patient_facing` and `notify`
  (`PatternMethodRef`); optional `confidence` (`PatternConfidence`, five axes, no single score) and `disclosure`;
  `PatternNotComputed.next_step`, `PatternRun.next_steps` and `StoredPatterns.next_steps` (`PatternNextStep`: what would
  unlock a test). `patterns.methods()` reads the method registry `GET /v1/patterns/methods`.
- Fix: `PatternFinding.strength` is optional (deprecated); the server has not sent it since 5 Nov 2026.
- `patterns.current(patientId)`, `patterns.history(patientId, findingKey)` and `patterns.feedback(patientId, findingKey, input)`
  (beta): the stored findings the platform keeps up to date in the background for the trusted project the person gave the
  `anpheros/patterns` feature consent to, each with a stable `finding_key`; `409 not_computed_yet` until the first run.
  New webhook event type `patterns.updated` (`PatternsUpdatedEvent`: keys and events only).
- `neuro.summary(patientId)` (beta): the neurology view `GET /v1/patients/{id}/neuro-summary` — head imaging, episodes,
  head symptoms, active medications and plain before/after numbers around the latest head MRI/CT, each with provenance.
  Built under the caller's grant; nothing interpretive. See `docs/neuro-view.md`.

## 0.2.0 — 2026-10-16

- `patterns` (beta, sandbox credentials only): `run`, `get`, `evidence`, `series` and `compare` for the Health Pattern
  Engine: trends, deviations from the person's usual level and symptom recurrence, each with its period, supporting
  resources, method version and limitations. Findings carry `review` (whether a clinician reviewed the thresholds;
  `false` for now) and `safety` (not a diagnosis, no causal claim).

## 0.1.2 — 2026-09-28

- `TimelineItem.type` includes `episode` (episodes of care, already returned by the server).
- Package metadata points to the developer guides (https://developers.anpheros.com/guides/sdks) and to the
  public repository anpheros/anpheros-sdk; LICENSE is the verbatim Apache License 2.0 text.

## 0.1.1 — 2026-09-19

First automated release (GitHub Actions tag `sdk-v0.1.1`, OIDC to pub.dev / npm trusted publishing). No API changes.

## 0.1.0 — 2026-09-19

First release.

- API-key and OAuth clients (authorization code + PKCE, refresh with rotation, client credentials, identity exchange for trusted first-party apps).
- `/v1`: patients, observations, conditions, medications, documents (upload, finalize, download), timeline, provenance, grants, context, terminology.
- FHIR R4: read, vread, search, create, update, delete, bundles, `$everything`, `$summary`, `$validate`, capability statement.
- Patient-side API (`me`): my records, who has access, access log, revoke.
- Retries with backoff on 429/5xx, one token refresh on 401, Idempotency-Key on writes, request ids on errors.
