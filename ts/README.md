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

## Health patterns (beta)

What changed in a record and what recurs, by fixed statistical rules: not diagnoses, not causes. The full guide,
with consent, the display rule, maturity, research and the safety obligation, is
[Health patterns developer guide](https://developers.anpheros.com/guides/health-patterns-api).

```ts
// Sandbox: compute on request for a synthetic person with a planted pattern (p01: home blood pressure falling).
const anpheros = new Anpheros({ auth: apiKey(process.env.ANPHEROS_KEY!) });   // sk_test_…
const bundle = await anpheros.fhir.search('Patient', { identifier: 'https://anpheros.com/fhir/sid/sandbox-persona|p01' });
const patientId = bundle.entry![0].resource!.id!;
const run = await anpheros.patterns.run(patientId, { window_days: 180 });
for (const f of run.findings) {
  console.log(f.summary_text, f.statistically_supported, f.method.maturity, f.limitations.map((l) => l.code));
}
const methods = await anpheros.patterns.methods();   // maturity, patient_facing, notify per method

// Trusted first-party project, under the person's anpheros/patterns consent: stored findings.
const stored = await anpheros.patterns.current(patientId);
const forThePerson = stored.findings.filter((f) => f.shown && f.method.patient_facing);
const research = await anpheros.patterns.research(patientId, forThePerson[0].finding_key);
if (!research.available) console.log(research.reason?.key);   // e.g. finding.library_not_populated: show this, not a verdict
await anpheros.patterns.feedback(patientId, forThePerson[0].finding_key, { response: 'unsure' });
```

**Safety.** A write that records a PHQ-9 item 9 answer above 0 comes back with `X-Anpheros-Safety: crisis-resources`.
Your app must then show crisis lines to the person at once:

```ts
const anpheros = new Anpheros({
  auth,
  onSafety: async () => showCrisisSheet(await anpheros.patterns.crisisResources(userCountry)),
});
```
