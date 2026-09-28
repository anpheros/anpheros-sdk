# Conformance results

Raw results of conformance test runs against the Anpheros platform, published so that anyone can check our claims
instead of taking our word for them. These are test results, not a certification: Anpheros is not ONC-certified,
and a run covers only what its test group covers.

## Inferno: SMART App Launch STU2, Standalone Launch group

| Date | Platform | Test kit | Result | Raw results |
|---|---|---|---|---|
| 28 Sep 2026 | Anpheros Platform 0.3.0 | [SMART App Launch Test Kit](https://github.com/inferno-framework/smart-app-launch-test-kit) v1.0.3 (commit `980e54e`), inferno_core 1.4.3 | **22 of 22 tests passed**, 0 failed, 0 skipped | [JSON](inferno/2026-09-28-smart-stu2-standalone-launch.json) |

**How it ran.** The official Inferno test kit ran in a temporary Docker environment against
`https://platform.anpheros.com/fhir/R4`, suite `smart_stu2`, group "Standalone Launch". The client was a public
(PKCE) application in a sandbox project and asked for `launch/patient openid fhirUser offline_access patient/*.rs`.
Inferno waits for a person to log in and authorize the app. Our script did that step: it signed up a new test user,
chose "Allow" on the consent page for a new, empty record, and passed the authorization code back to Inferno. No real
patient data was involved.

**What the group covers:** SMART discovery (`.well-known/smart-configuration`); the authorization request with PKCE
(S256); the token exchange and the token response body and headers; OpenID Connect (configuration, JWKS, `id_token`
header and payload, `fhirUser` claim); token refresh with and without explicit scopes.

**What it does not cover:**

- EHR launch (the `launch` scope). Anpheros does not support it.
- The OpenID Connect `nonce` parameter. Not supported.
- The other groups of the suite. Backend Services and Token Introspection were not run; the platform's discovery
  document offers neither asymmetric client authentication nor an introspection endpoint.
- Only the public-client path ran. The confidential (client secret) path was not part of this run.
- The FHIR data API itself (resources, search, `Patient/$summary`) is outside this group.

**Reading the file.** Entries with a `test_id` are tests: 22, all `pass`. Entries without one are group roll-ups:
a group is `wait` while Inferno waits for the authorization redirect, and a later entry for the same group has its
final result (all `pass`). In messages, OAuth parameter values, tokens and e-mail addresses would be replaced with
`[redacted]`; in this run every message is empty. The HTTP requests Inferno recorded are not published because they
contain the test user's tokens.

**Earlier run.** The first cloud run, on 23 Sep 2026 (raw results not published), found two problems: token responses
without `Cache-Control: no-store`, and no `id_token` for `openid fhirUser`. Both were fixed the same day.
