# Consent app (TypeScript)

A minimal web app — Node's built-in HTTP server plus [`@anpheros/sdk`](https://www.npmjs.com/package/@anpheros/sdk) — that shows the whole consent chain:

```
Your app ──► Anpheros consent page ──► the person chooses the record and the duration
   ▲                                               │
   └────── code (PKCE) ──► tokens ◄────────────────┘
Your app ──► Anpheros API (access token) ──► that person's FHIR record, only within the scopes
```

It asks for read-only access to observations, medications and conditions (`patient/Observation.rs patient/MedicationStatement.rs patient/Condition.rs offline_access`) and then lists the person's latest vital signs, lab results, active medications and conditions.

## Run

1. Register an application in your sandbox project as a **public** client with the redirect URI `http://localhost:3000/callback` (`POST /admin/projects/{id}/applications`).
2. Start the app:

   ```bash
   npm install
   ANPHEROS_CLIENT_ID=client_… npm start
   ```

3. Open http://localhost:3000 and choose **Connect with Anpheros**.

Tokens live in memory for one demo session. A real application keeps them on its server per user, refreshes them (the SDK does it for you with `OAuthAuth`) and handles revocation: once the person revokes access in Anpheros, the next call is refused.

Docs: [Authentication and OAuth](https://developers.anpheros.com/guides/authentication) · [Consent and access model](https://developers.anpheros.com/guides/consent)
