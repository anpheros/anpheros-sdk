# Changelog

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
