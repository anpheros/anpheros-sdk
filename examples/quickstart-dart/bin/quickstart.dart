// Anpheros quickstart for Dart and Flutter.
//
// Writes and reads a patient's HL7 FHIR R4 record through the Anpheros Platform API:
// patient → weight and lab result → timeline → FHIR search → AI-ready context.
// Runs against the sandbox (synthetic data only).
//
//   ANPHEROS_KEY=sk_test_… dart run bin/quickstart.dart
//
// Docs: https://developers.anpheros.com/guides/sdks
import 'dart:io';

import 'package:anpheros_sdk/anpheros_sdk.dart';

Future<void> main() async {
  final key = Platform.environment['ANPHEROS_KEY'] ?? '';
  if (!key.startsWith('sk_test_')) {
    stderr.writeln('Set ANPHEROS_KEY to a sandbox key (sk_test_…). Never use a production key in examples.');
    exit(1);
  }
  final baseUrl = Platform.environment['ANPHEROS_BASE_URL'];
  final anpheros = baseUrl == null
      ? Anpheros(auth: AnpherosAuth.apiKey(key))
      : Anpheros(auth: AnpherosAuth.apiKey(key), baseUrl: baseUrl);

  // 1. A patient owned by this project.
  final patient = await anpheros.patients.create(const PatientInput(given: 'Ion', family: 'Example', gender: 'male'));
  print('Patient ${patient.id} (${patient.fhir})');

  // 2. Medical data with its author: a weight from the patient, a lab result imported from a report.
  final now = DateTime.now().toUtc();
  await anpheros.observations.createObservation(
    patient.id,
    ObservationInput(code: '29463-7', display: 'Body weight', category: 'vital-signs', effectiveAt: now, value: 82.5, unit: 'kg', authorType: AuthorType.patient),
  );
  await anpheros.observations.createObservation(
    patient.id,
    ObservationInput(
      code: '2345-7', display: 'Glucose', category: 'laboratory', effectiveAt: now, value: 104, unit: 'mg/dL',
      referenceRange: const ReferenceRange(low: 70, high: 100), authorType: AuthorType.import,
    ),
  );

  // 3. Read it back.
  final labs = await anpheros.observations.list(patient.id, category: 'laboratory');
  for (final o in labs.data) {
    print('Lab: ${o.display} ${o.value} ${o.unit} (range ${o.referenceRange?.low}–${o.referenceRange?.high})');
  }
  final timeline = await anpheros.timeline.list(patient.id);
  for (final t in timeline.data) {
    print('Timeline: ${t.date} ${t.type}: ${t.title}');
  }

  // 4. The same data as strict FHIR R4.
  final bundle = await anpheros.fhir.search('Observation', {'patient': patient.id, 'category': 'laboratory'});
  print('FHIR search: ${(bundle['entry'] as List?)?.length ?? 0} Observation(s)');

  // 5. An AI-ready context for a model of your choice (Anpheros does not call any model).
  final ctx = await anpheros.context.build(ContextRequest(patient: patient.id, task: 'weekly check-in', budgetTokens: 600, format: 'text'));
  print('Context: ${ctx.tokensUsed}/${ctx.budgetTokens} tokens, sections: ${ctx.sections.map((s) => s.kind).join(', ')}');
  print(ctx.text);
  anpheros.close();
}
