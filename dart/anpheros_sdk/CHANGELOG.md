# Changelog

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
