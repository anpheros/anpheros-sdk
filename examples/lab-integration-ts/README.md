# Lab integration: HL7 v2 or CSV → FHIR R4 Observations

A laboratory report becomes laboratory `Observation`s in a patient's record, in one request:

1. creates a test patient owned by your sandbox project;
2. sends a synthetic lipid panel as **HL7 v2 ORU^R01** ([report.hl7](report.hl7)) or a **CSV** report ([report.csv](report.csv));
3. prints what was mapped to LOINC, what kept the lab's own code (`unmapped`), and one result as strict FHIR R4 with its reference range;
4. sends the same report again: rows already imported are **skipped**, nothing is duplicated.

```bash
npm install
ANPHEROS_KEY=sk_test_… npm start      # HL7 v2
ANPHEROS_KEY=sk_test_… npm run csv    # CSV
```

Output (HL7, run against a local instance with sandbox data, 13 October 2026):

```
Imported HL7: created 6, skipped 0
  Cholesterol [Mass/volume] in Serum or Plasma = 212 mg/dL  →  http://loinc.org|2093-3
  …
  Example in-house marker = 3.2 U/L  →  urn:hl7:l|EX-991
  Not mapped to LOINC (kept with the lab's own code): Example in-house marker
…
Sent again: created 0, skipped 6
```

## Environment

| Variable | Required | |
|---|---|---|
| `ANPHEROS_KEY` | yes | a sandbox key (`sk_test_…`); the script refuses any other key |
| `ANPHEROS_BASE_URL` | no | defaults to `https://platform.anpheros.com` |

## What to know

- **Mapping.** A LOINC code in the report always wins (`OBX-3` with `^LN`, or a `LOINC` column in CSV). Otherwise the platform matches the marker name; names it cannot match keep the lab's code and are listed in `unmapped`, so you can add the code on your side. Send LOINC codes when your lab system has them.
- **Re-sending is safe.** Each row gets a stable identifier from the report, code, date and value.
- **Provenance.** Every Observation records `author_type = import` and your source system (`X-Anpheros-Source-System`, here `example-lab`).
- **Errors.** The script prints the status, error type, field and request id, with a hint for 401, 403, 413, 422 and 429.
- **Security.** Keep the key on the server that receives lab reports; never in a browser or mobile app. The report here is synthetic: never use real patient data in the sandbox.
- **Patient matching** is yours: a real integration finds the patient by an identifier it shares with your app; this example creates a new one.

Docs: [Lab connector](https://developers.anpheros.com/guides/lab-connector) · [Import lab results into FHIR](https://developers.anpheros.com/guides/import-lab-results-fhir) · [API reference](https://developers.anpheros.com/docs)
