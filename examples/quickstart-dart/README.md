# Quickstart (Dart / Flutter)

Writes and reads a patient's HL7 FHIR R4 record through the Anpheros Platform API with the [`anpheros_sdk`](https://pub.dev/packages/anpheros_sdk) package: a patient, a weight and a lab result with their authors, a filtered list, the timeline, a FHIR search and an AI-ready context. The same calls work inside a Flutter app.

```bash
dart pub get
ANPHEROS_KEY=sk_test_… dart run bin/quickstart.dart
```

In a mobile app, do not ship an API key: call your own backend, or act for the person with OAuth (`OAuthFlow`, `AnpherosAuth.oauth`).

Docs: [SDKs](https://developers.anpheros.com/guides/sdks) · [Medical app backend](https://developers.anpheros.com/guides/medical-app-backend)
