# FHIR R4 transaction

[`bundle.json`](bundle.json) creates a small patient record in one atomic FHIR R4 transaction: a `Patient`, an HbA1c `Observation` (LOINC 4548-4, with its reference range), a `Condition` (ICD-10 E11) and a `MedicationStatement` (ATC A10BA02). The other entries point to the patient through its `urn:uuid` full URL, which the server resolves.

```bash
curl -X POST https://platform.anpheros.com/fhir/R4 \
     -H "Authorization: Bearer $ANPHEROS_KEY" -H "Content-Type: application/fhir+json" \
     -H "X-Anpheros-Author-Type: import" \
     --data-binary @bundle.json
```

The response is a `transaction-response` bundle with a `201 Created` entry and the location of each new resource. Then:

```bash
# the whole record
curl "https://platform.anpheros.com/fhir/R4/Patient/$PID/\$everything" -H "Authorization: Bearer $ANPHEROS_KEY"
# an International Patient Summary document
curl "https://platform.anpheros.com/fhir/R4/Patient/$PID/\$summary?lang=en" -H "Authorization: Bearer $ANPHEROS_KEY"
```

Every write also gets a `Provenance` resource, visible in `$everything`.

Docs: [FHIR platform](https://developers.anpheros.com/guides/fhir) · [FHIR code systems](https://developers.anpheros.com/guides/fhir-code-systems) · [Healthcare data interoperability](https://developers.anpheros.com/guides/interoperability)
