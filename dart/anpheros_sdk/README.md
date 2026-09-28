# anpheros_sdk

Dart / Flutter client for **Anpheros Platform**: a health-data backend with a FHIR R4 record
per patient, project isolation, patient consent (OAuth 2.1 / SMART on FHIR), provenance on every
write and an AI context API.

```dart
import 'package:anpheros_sdk/anpheros_sdk.dart';

final anpheros = Anpheros(auth: AnpherosAuth.apiKey('sk_test_…'));      // server / sandbox

final patients = await anpheros.patients.list();
final elena = patients.data.first;
final labs = await anpheros.observations.list(elena.id, category: 'laboratory', limit: 10);
final ctx = await anpheros.context.build(ContextRequest(patient: elena.id, task: 'weekly check-in', budgetTokens: 1500));
```

## Acting for a person (apps)

```dart
final flow = OAuthFlow(baseUrl: 'https://…', clientId: 'client_…', redirectUri: 'myapp://callback');
final pkce = Pkce.generate();
final url = flow.authorizeUrl(scopes: ['patient/Observation.rs?category=laboratory', 'patient/MedicationStatement.r', 'offline_access'],
                              state: 'abc', pkce: pkce, lang: 'ro');
// open `url`; on return with ?code=…:
final tokens = await flow.exchange(code: code, pkce: pkce);
final anpheros = Anpheros(auth: AnpherosAuth.oauth(
  accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, expiresAt: tokens.expiresAt,
  onRefresh: flow.refresh, onTokens: persist));
final meds = await anpheros.medications.listMedications(tokens.patient!);
```

Every object carries `fhir` (its `/fhir/R4` reference); `anpheros.fhir` gives raw FHIR access
(read, search, create, transaction, `$everything`, `$summary`, `$validate`).

Errors are `AnpherosException` with `status`, `type`, `message`, `field` and `requestId`.
Creates send an `Idempotency-Key` automatically; 429/5xx are retried with backoff; expired OAuth
tokens are refreshed once and the call retried.
