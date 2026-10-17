# Changelog

## Unreleased

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
