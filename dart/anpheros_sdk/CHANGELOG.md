# Changelog

## Unreleased

- Safety (additive): `Anpheros(onSafety: …)` is called whenever a response carries `X-Anpheros-Safety` (a PHQ-9 item 9
  answer above 0); `lastSafety` keeps the last `SafetySignal`. Typed results (beta, not released before):
  `patterns.crisisResources()` returns `CrisisResources`, `patterns.research()` returns `FindingResearch` (with `KeyedText`
  reasons; `verdict` is null when the library has nothing) and `patterns.feedback()` returns `PatternFeedbackResult` and
  now sends an `Idempotency-Key`. README: a Health patterns section with examples.
- Health patterns, display rule (additive): `StoredPatternFinding.shown` / `shownSince` and `StoredPatterns.displayRule`:
  show a stored finding to the person only when `shown` and `method.patientFacing` are true;
  `PatternFinding.shownOnlyIfSupported` (selection subtypes) and `PatternNextStep.patientFacing`, so consumers need no
  hand-copied lists. `patterns.updated` may carry `shown` / `hidden` events; notify on `shown` only.
- Health patterns, engine 0.6.0 (additive): `PatternFinding.method` / `StoredPatternFinding.method` (`PatternMethodRef` with
  `maturity`, `patientFacing`, `notify`), `confidence` and `disclosure`; `PatternRun.nextSteps` and `StoredPatterns.nextSteps`
  (`PatternNextStep`); `patterns.methods()` reads the method registry `GET /v1/patterns/methods` (`PatternMethods`).
- Fix: `PatternFinding.fromJson` no longer throws on current payloads: `strength` is now `String?` (deprecated; the server
  has not sent it since 5 Nov 2026).
- `patterns.current(patientId)`, `patterns.history(patientId, findingKey)` and `patterns.feedback(patientId, findingKey, response)`
  (beta): the stored findings the platform keeps up to date in the background for the trusted project the person gave the
  `anpheros/patterns` feature consent to (`StoredPatterns`, `StoredPatternFinding` with a stable `findingKey`, `PatternEvent`);
  `409 not_computed_yet` until the first run. `webhookEventTypes` includes `patterns.updated`.
- `neuro.summary(patientId)` (beta): the neurology view `GET /v1/patients/{id}/neuro-summary` — head imaging, episodes,
  head symptoms, active medications and plain before/after numbers around the latest head MRI/CT, each with provenance.
  Built under the caller's grant; nothing interpretive. See `docs/neuro-view.md`.

## 0.2.0 — 2026-10-16

- `patterns` (beta, sandbox credentials only): `run`, `get`, `evidence`, `series` and `compare` for the Health Pattern
  Engine, with `PatternRun` and `PatternFinding`. Each finding has its period, supporting resources, method version,
  limitations, `review` (clinician review of the thresholds; `false` for now) and `safety`.

## 0.1.2 — 2026-09-28

- Documentation: dartdoc comments on the models; the package metadata points to the developer guides
  (https://developers.anpheros.com/guides/sdks) and to the public repository anpheros/anpheros-sdk.
- LICENSE is now the verbatim Apache License 2.0 text, so tools recognise it.
- No API changes.

## 0.1.1 — 2026-09-19

First automated release (GitHub Actions tag `sdk-v0.1.1`, OIDC to pub.dev / npm trusted publishing). No API changes.

## 0.1.0 — 2026-09-19

First release.

- API-key and OAuth clients (authorization code + PKCE, refresh with rotation, client credentials, identity exchange for trusted first-party apps).
- `/v1`: patients, observations, conditions, medications, documents (upload, finalize, download), timeline, provenance, grants, context, terminology.
- FHIR R4: read, vread, search, create, update, delete, bundles, `$everything`, `$summary`, `$validate`, capability statement.
- Patient-side API (`me`): my records, who has access, access log, revoke.
- Retries with backoff on 429/5xx, one token refresh on 401, Idempotency-Key on writes, request ids on errors.
