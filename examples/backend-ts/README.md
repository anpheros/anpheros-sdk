# Backend starter (TypeScript / Node)

The backend of a healthcare app on Anpheros, with no framework: the API key stays on this server, your frontend calls only these routes, and Anpheros errors become answers your UI can show.

| Route | Does |
|---|---|
| `GET /api/patients` | the project's patients (in the sandbox: your 30 synthetic patients and any you created) |
| `GET /api/patients/:id/summary` | latest vital signs and lab results per code, active conditions, active medications |
| `POST /api/patients/:id/weight` | `{"kg": 72.5}` → a body-weight Observation (LOINC 29463-7), validated before it is sent |
| `GET /api/patients/:id/fhir` | the same record as FHIR R4 (`Patient/$everything`, first page of 100 entries) |

```bash
npm install
ANPHEROS_KEY=sk_test_… npm start
curl localhost:3000/api/patients
curl localhost:3000/api/patients/<id>/summary
curl -X POST -d '{"kg":72.5}' localhost:3000/api/patients/<id>/weight
```

## Environment

| Variable | Required | |
|---|---|---|
| `ANPHEROS_KEY` | yes | a sandbox key (`sk_test_…`); a production key is refused unless `ALLOW_LIVE=1` |
| `ANPHEROS_BASE_URL` | no | defaults to `https://platform.anpheros.com` |
| `PORT` | no | defaults to 3000 |

## Error handling

| Anpheros | Your frontend gets | Why |
|---|---|---|
| network error | 502 | Anpheros unreachable |
| 401 | 502 | the server's key is invalid or revoked: a server problem, not the user's |
| 403 | 403 | no access: consent missing, expired or revoked, or a read-only key |
| 400 | 400 | invalid input; the message names the problem and `field` the field |
| 404 | 404 | not in this project |
| 422 | 422 | a reference that does not exist for you (for example another project's patient) |
| 429 | 503 | rate limit; the SDK already retried with backoff |

Each error answer carries the Anpheros `request_id`, which is what to quote to support. The upstream body and the key never reach the browser.

## Checked

Run on 13 October 2026 against a local instance of the platform with the sandbox's synthetic patients and `@anpheros/sdk` 0.1.2 from npm: every route, plus invalid input (400) and an unknown patient (404).

## Production

The same code runs in production with a `sk_live_` key issued to a verified organisation. Add your own user authentication in front of these routes and check that the signed-in user may see the patient id they ask for: the API key gives access to every patient of the project.

Docs: [Healthcare API in TypeScript](https://developers.anpheros.com/guides/healthcare-api-typescript) · [Errors](https://developers.anpheros.com/guides/errors) · [API reference](https://developers.anpheros.com/docs)
