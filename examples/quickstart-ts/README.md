# Quickstart (TypeScript)

Writes and reads a patient's HL7 FHIR R4 record through the Anpheros Platform API with the [`@anpheros/sdk`](https://www.npmjs.com/package/@anpheros/sdk) package:

1. creates a patient owned by your project;
2. records a blood-pressure reading (from a device), an HbA1c result (imported), a diagnosis (ICD-10) and a medication (ATC) — each with its author, so the platform keeps provenance;
3. reads them back as a filtered list and as a timeline;
4. searches the same data through the FHIR R4 API;
5. generates an International Patient Summary;
6. builds an AI-ready context — the text you would pass to a model of your choice.

```bash
npm install
ANPHEROS_KEY=sk_test_… npm start
```

The script refuses anything that is not a sandbox key.

Docs: [Build a healthcare app](https://developers.anpheros.com/guides/build-a-healthcare-app) · [Medical data API](https://developers.anpheros.com/guides/medical-data-api) · [FHIR platform](https://developers.anpheros.com/guides/fhir)
