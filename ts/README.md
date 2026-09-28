# @anpheros/sdk

TypeScript client for **Anpheros Platform**: a FHIR R4 health record per patient, project
isolation, patient consent (OAuth 2.1 / SMART on FHIR), provenance on every write and an AI
context API. Runs anywhere `fetch` exists (Node 18+, browsers, Deno, Bun).

```ts
import { Anpheros, apiKey } from '@anpheros/sdk';

const anpheros = new Anpheros({ auth: apiKey(process.env.ANPHEROS_KEY!) });
const { data: patients } = await anpheros.patients.list();
const labs = await anpheros.observations.list(patients[0].id, { category: 'laboratory', limit: 10 });
const ctx = await anpheros.context.build({ patient: patients[0].id, task: 'weekly check-in', budget_tokens: 1500, format: 'text' });
```

Acting for a person:

```ts
import { OAuthFlow, OAuthAuth, generatePkce } from '@anpheros/sdk';

const flow = new OAuthFlow({ baseUrl: BASE, clientId: 'client_…', redirectUri: 'https://myapp.example/callback' });
const pkce = await generatePkce();
location.href = flow.authorizeUrl({ scopes: ['patient/Observation.rs?category=laboratory', 'offline_access'], state, pkce, lang: 'ro' });
// on the callback:
const tokens = await flow.exchange(code, pkce);
const anpheros = new Anpheros({ auth: new OAuthAuth({ tokens, onRefresh: flow.refresh, onTokens: persist }) });
```

Errors are `AnpherosError` (`status`, `type`, `message`, `field`, `requestId`). Creates send an
`Idempotency-Key`; 429/5xx are retried; expired tokens are refreshed once and the call retried.
