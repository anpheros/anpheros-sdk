import 'dart:convert';

import 'client.dart';
import 'models.dart';

String _enc(String s) => Uri.encodeComponent(s);

/// `/v1/patients`
class PatientsResource {
  PatientsResource(this._c);
  final Anpheros _c;

  Future<Page<Patient>> list({int limit = 50, String? cursor}) async {
    final r = await _c.request('GET', '/v1/patients', query: {'limit': '$limit', if (cursor != null) 'cursor': cursor});
    return Page.fromJson(r.json, Patient.fromJson);
  }

  /// Every patient visible to this credential, page after page.
  Stream<Patient> listAll({int pageSize = 200}) async* {
    String? cursor;
    do {
      final page = await list(limit: pageSize, cursor: cursor);
      yield* Stream.fromIterable(page.data);
      cursor = page.nextCursor;
    } while (cursor != null);
  }

  Future<Patient> create(PatientInput input, {AuthorType? authorType}) async {
    final r = await _c.request('POST', '/v1/patients', json: input.toJson(), idempotent: true,
        headers: authorType == null ? null : {'X-Anpheros-Author-Type': authorType.name});
    return Patient.fromJson(r.json);
  }

  Future<Patient> get(String id) async => Patient.fromJson((await _c.request('GET', '/v1/patients/${_enc(id)}')).json);

  Future<Patient> update(String id, PatientInput input) async =>
      Patient.fromJson((await _c.request('PUT', '/v1/patients/${_enc(id)}', json: input.toJson())).json);
}

/// `/v1/patients/{id}/observations|conditions|medications` — one class, three kinds.
class ClinicalResource<T> {
  ClinicalResource(this._c, this.kind);
  final Anpheros _c;
  final String kind;

  /// Observations: filter by `category`, `code`, `from`, `to` (dates).
  Future<Page<Observation>> list(String patientId,
      {String? category, String? code, DateTime? from, DateTime? to, String? clinicalStatus, String? status, int limit = 50, String? cursor}) async {
    final q = {
      if (category != null) 'category': category,
      if (code != null) 'code': code,
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
      if (clinicalStatus != null) 'clinical_status': clinicalStatus,
      if (status != null) 'status': status,
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    };
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/$kind', query: q);
    return Page.fromJson(r.json, Observation.fromJson);
  }

  Future<Page<Condition>> listConditions(String patientId, {String? clinicalStatus, int limit = 50, String? cursor}) async {
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/$kind',
        query: {if (clinicalStatus != null) 'clinical_status': clinicalStatus, 'limit': '$limit', if (cursor != null) 'cursor': cursor});
    return Page.fromJson(r.json, Condition.fromJson);
  }

  Future<Page<Medication>> listMedications(String patientId, {String? status, int limit = 50, String? cursor}) async {
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/$kind',
        query: {if (status != null) 'status': status, 'limit': '$limit', if (cursor != null) 'cursor': cursor});
    return Page.fromJson(r.json, Medication.fromJson);
  }

  Future<Map<String, dynamic>> _create(String patientId, Map<String, dynamic> body, {String? sourceSystem, String? originId}) async {
    final r = await _c.request('POST', '/v1/patients/${_enc(patientId)}/$kind', json: body, idempotent: true, headers: {
      if (sourceSystem != null) 'X-Anpheros-Source-System': sourceSystem,
      if (originId != null) 'X-Anpheros-Origin-Id': originId,
    });
    return r.json;
  }

  Future<Observation> createObservation(String patientId, ObservationInput input, {String? sourceSystem, String? originId}) async =>
      Observation.fromJson(await _create(patientId, input.toJson(), sourceSystem: sourceSystem, originId: originId));

  Future<Condition> createCondition(String patientId, ConditionInput input, {String? sourceSystem, String? originId}) async =>
      Condition.fromJson(await _create(patientId, input.toJson(), sourceSystem: sourceSystem, originId: originId));

  Future<Medication> createMedication(String patientId, MedicationInput input, {String? sourceSystem, String? originId}) async =>
      Medication.fromJson(await _create(patientId, input.toJson(), sourceSystem: sourceSystem, originId: originId));

  Future<Map<String, dynamic>> getRaw(String id) async => (await _c.request('GET', '/v1/$kind/${_enc(id)}')).json;
  Future<Observation> getObservation(String id) async => Observation.fromJson(await getRaw(id));
  Future<Condition> getCondition(String id) async => Condition.fromJson(await getRaw(id));
  Future<Medication> getMedication(String id) async => Medication.fromJson(await getRaw(id));

  Future<void> delete(String id) async => _c.request('DELETE', '/v1/$kind/${_enc(id)}');
}

/// `/v1/patients/{id}/documents`, `/v1/documents/{id}`
class DocumentsResource {
  DocumentsResource(this._c);
  final Anpheros _c;

  Future<Page<Document>> list(String patientId, {String? kind, int limit = 50, String? cursor}) async {
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/documents',
        query: {if (kind != null) 'kind': kind, 'limit': '$limit', if (cursor != null) 'cursor': cursor});
    return Page.fromJson(r.json, Document.fromJson);
  }

  /// Creates the document and returns it with an [Document.upload] target.
  Future<Document> create(String patientId, DocumentInput input, {String? sourceSystem}) async {
    final r = await _c.request('POST', '/v1/patients/${_enc(patientId)}/documents', json: input.toJson(), idempotent: true,
        headers: sourceSystem == null ? null : {'X-Anpheros-Source-System': sourceSystem});
    return Document.fromJson(r.json);
  }

  /// Uploads the bytes through the platform and finalizes (sha256, size, immutable).
  Future<Document> uploadContent(String documentId, List<int> bytes, {required String contentType}) async {
    final r = await _c.request('PUT', '/v1/documents/${_enc(documentId)}/content', bytes: bytes, contentType: contentType);
    return Document.fromJson(r.json);
  }

  /// Creates + uploads in one call.
  Future<Document> upload(String patientId, DocumentInput input, List<int> bytes) async {
    final doc = await create(patientId, input);
    return uploadContent(doc.id, bytes, contentType: input.contentType);
  }

  /// After a direct-to-storage upload through [Document.upload].
  Future<Document> finalize(String documentId) async =>
      Document.fromJson((await _c.request('POST', '/v1/documents/${_enc(documentId)}/finalize')).json);

  Future<Document> get(String documentId) async => Document.fromJson((await _c.request('GET', '/v1/documents/${_enc(documentId)}')).json);

  /// The original bytes (follows the signed-URL redirect when storage is remote).
  Future<List<int>> download(String documentId) async =>
      (await _c.request('GET', '/v1/documents/${_enc(documentId)}/content', headers: {'Accept': '*/*'})).bytes;
}

class TimelineResource {
  TimelineResource(this._c);
  final Anpheros _c;

  Future<Page<TimelineItem>> list(String patientId, {DateTime? from, DateTime? to, List<String>? types, int limit = 100, String? cursor}) async {
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/timeline', query: {
      if (from != null) 'from': _day(from),
      if (to != null) 'to': _day(to),
      if (types != null) 'types': types.join(','),
      'limit': '$limit',
      if (cursor != null) 'cursor': cursor,
    });
    return Page.fromJson(r.json, TimelineItem.fromJson);
  }
}

class ProvenanceResource {
  ProvenanceResource(this._c);
  final Anpheros _c;

  /// Who wrote a resource and when; `fhirRef` like `Observation/abc`.
  Future<List<ProvenanceEntry>> of(String patientId, String fhirRef) async {
    final parts = fhirRef.split('/');
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/provenance/${_enc(parts[0])}/${_enc(parts[1])}');
    return (r.json['data'] as List).map((e) => ProvenanceEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class ContextResource {
  ContextResource(this._c);
  final Anpheros _c;

  Future<ContextResult> build(ContextRequest req) async => ContextResult.fromJson((await _c.request('POST', '/v1/context', json: req.toJson())).json);
}

class GrantsResource {
  GrantsResource(this._c);
  final Anpheros _c;

  /// What this credential may do for the patient, until when.
  Future<List<GrantInfo>> of(String patientId) async {
    final r = await _c.request('GET', '/v1/patients/${_enc(patientId)}/grants');
    return (r.json['data'] as List).map((e) => GrantInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// The person's own view: their records, who has access, what each app did.
///
/// Authenticate with the person's Firebase ID token (`AnpherosAuth.bearer`), not
/// with an API key or an OAuth access token.
class MeResource {
  MeResource(this._c);
  final Anpheros _c;

  /// My records and my dependents' (`environment`: production or sandbox).
  Future<List<MyPatient>> patients({String environment = 'production'}) async {
    final r = await _c.request('GET', '/me/patients', query: {'environment': environment});
    return (r.json['data'] as List).map((e) => MyPatient.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Every grant on a record, newest first, with scope texts in `lang`.
  Future<List<GrantInfo>> grants(String patientId, {String lang = 'en', String environment = 'production'}) async {
    final r = await _c.request('GET', '/me/patients/${_enc(patientId)}/grants', query: {'lang': lang, 'environment': environment});
    return (r.json['data'] as List).map((e) => GrantInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Ends an application's access now; the app's tokens stop working immediately.
  Future<GrantInfo> revoke(String patientId, String grantId, {String? reason, String environment = 'production'}) async {
    final r = await _c.request('POST', '/me/patients/${_enc(patientId)}/grants/${_enc(grantId)}/revoke',
        query: {'environment': environment}, json: {if (reason != null) 'reason': reason});
    return GrantInfo.fromJson(r.json);
  }

  /// What the application read or wrote under this grant, newest first.
  Future<List<AccessEntry>> accessLog(String patientId, String grantId, {int limit = 100, String environment = 'production'}) async {
    final r = await _c.request('GET', '/me/patients/${_enc(patientId)}/grants/${_enc(grantId)}/access-log',
        query: {'limit': '$limit', 'environment': environment});
    return (r.json['data'] as List).map((e) => AccessEntry.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class TerminologyResource {
  TerminologyResource(this._c);
  final Anpheros _c;

  Future<List<Concept>> search(String system, String q, {int limit = 20}) async {
    final r = await _c.request('GET', '/v1/terminology/${_enc(system)}', query: {'q': q, 'limit': '$limit'});
    return (r.json['data'] as List).map((e) => Concept.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Concept> lookup(String system, String code) async =>
      Concept.fromJson((await _c.request('GET', '/v1/terminology/${_enc(system)}/${_enc(code)}')).json);
}

/// Raw FHIR R4 access at `/fhir/R4` for anything the simplified API does not cover.
class FhirResource {
  FhirResource(this._c);
  final Anpheros _c;

  Future<Map<String, dynamic>> metadata() async => (await _c.request('GET', '/fhir/R4/metadata', headers: {'Accept': 'application/fhir+json'})).json;

  Future<Map<String, dynamic>> read(String type, String id) async => (await _c.request('GET', '/fhir/R4/${_enc(type)}/${_enc(id)}')).json;

  Future<Map<String, dynamic>> search(String type, Map<String, String> params) async =>
      (await _c.request('GET', '/fhir/R4/${_enc(type)}', query: params)).json;

  Future<Map<String, dynamic>> create(Map<String, dynamic> resource, {AuthorType? authorType, String? sourceSystem, String? originId}) async {
    final type = resource['resourceType'] as String;
    final r = await _c.request('POST', '/fhir/R4/${_enc(type)}', json: resource, idempotent: true, headers: {
      if (authorType != null) 'X-Anpheros-Author-Type': authorType.name,
      if (sourceSystem != null) 'X-Anpheros-Source-System': sourceSystem,
      if (originId != null) 'X-Anpheros-Origin-Id': originId,
    });
    return r.json;
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> resource, {String? ifMatch, AuthorType? authorType}) async {
    final type = resource['resourceType'] as String;
    final r = await _c.request('PUT', '/fhir/R4/${_enc(type)}/${_enc(resource['id'] as String)}', json: resource, headers: {
      if (ifMatch != null) 'If-Match': ifMatch,
      if (authorType != null) 'X-Anpheros-Author-Type': authorType.name,
    });
    return r.json;
  }

  Future<void> delete(String type, String id) async => _c.request('DELETE', '/fhir/R4/${_enc(type)}/${_enc(id)}');

  Future<Map<String, dynamic>> history(String type, String id) async => (await _c.request('GET', '/fhir/R4/${_enc(type)}/${_enc(id)}/_history')).json;

  /// A specific version of a resource.
  Future<Map<String, dynamic>> vread(String type, String id, int version) async =>
      (await _c.request('GET', '/fhir/R4/${_enc(type)}/${_enc(id)}/_history/$version')).json;

  Future<Map<String, dynamic>> transaction(Map<String, dynamic> bundle, {AuthorType? authorType}) async =>
      (await _c.request('POST', '/fhir/R4', json: bundle, idempotent: true, headers: authorType == null ? null : {'X-Anpheros-Author-Type': authorType.name})).json;

  Future<Map<String, dynamic>> everything(String patientId, {int count = 100, int offset = 0, List<String>? types}) async =>
      (await _c.request('GET', '/fhir/R4/Patient/${_enc(patientId)}/\$everything',
              query: {'_count': '$count', '_offset': '$offset', if (types != null) '_type': types.join(',')}))
          .json;

  /// International Patient Summary document Bundle.
  Future<Map<String, dynamic>> summary(String patientId) async => (await _c.request('GET', '/fhir/R4/Patient/${_enc(patientId)}/\$summary')).json;

  /// `$validate`, optionally against a profile (`eu-lab`, `ips-observation`).
  Future<Map<String, dynamic>> validate(Map<String, dynamic> resource, {String? profile}) async {
    final type = resource['resourceType'] as String;
    return (await _c.request('POST', '/fhir/R4/${_enc(type)}/\$validate', json: resource, query: profile == null ? null : {'profile': profile})).json;
  }
}

String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Webhooks: signed event deliveries to your server (`/v1/webhooks`).
class WebhooksResource {
  WebhooksResource(this._c);
  final Anpheros _c;

  /// Registers an endpoint. The returned `secret` is shown only now; keep it to verify signatures.
  Future<WebhookEndpoint> create(String url, {List<String> events = const ['*'], String? description}) async {
    final r = await _c.request('POST', '/v1/webhooks', json: {'url': url, 'events': events, if (description != null) 'description': description});
    return WebhookEndpoint.fromJson(r.json);
  }

  Future<List<WebhookEndpoint>> list() async {
    final r = await _c.request('GET', '/v1/webhooks');
    return (r.json['data'] as List).map((e) => WebhookEndpoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> eventTypes() async => ((await _c.request('GET', '/v1/webhooks/event-types')).json['data'] as List).cast<String>();

  Future<WebhookEndpoint> get(String id) async => WebhookEndpoint.fromJson((await _c.request('GET', '/v1/webhooks/${_enc(id)}')).json);

  Future<WebhookEndpoint> update(String id, {String? url, List<String>? events, String? description, bool? active}) async {
    final r = await _c.request('PATCH', '/v1/webhooks/${_enc(id)}', json: {
      if (url != null) 'url': url, if (events != null) 'events': events, if (description != null) 'description': description, if (active != null) 'active': active,
    });
    return WebhookEndpoint.fromJson(r.json);
  }

  Future<void> delete(String id) async => _c.request('DELETE', '/v1/webhooks/${_enc(id)}');

  /// New secret (shown once); the old one stops working immediately.
  Future<WebhookEndpoint> rotateSecret(String id) async => WebhookEndpoint.fromJson((await _c.request('POST', '/v1/webhooks/${_enc(id)}/rotate')).json);

  /// Sends a `ping` event now.
  Future<WebhookDelivery> ping(String id) async => WebhookDelivery.fromJson((await _c.request('POST', '/v1/webhooks/${_enc(id)}/ping')).json);

  /// Delivery log, newest first (`status`: pending, delivered, failed, exhausted).
  Future<List<WebhookDelivery>> deliveries(String id, {String? status, int limit = 50}) async {
    final r = await _c.request('GET', '/v1/webhooks/${_enc(id)}/deliveries', query: {if (status != null) 'status': status, 'limit': '$limit'});
    return (r.json['data'] as List).map((e) => WebhookDelivery.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WebhookDelivery> redeliver(String id, String deliveryId) async =>
      WebhookDelivery.fromJson((await _c.request('POST', '/v1/webhooks/${_enc(id)}/deliveries/${_enc(deliveryId)}/redeliver')).json);

  /// Dead-letter: re-queue every exhausted delivery of an endpoint (after you fixed it).
  /// Returns how many were re-queued.
  Future<int> redeliverExhausted(String id) async =>
      ((await _c.request('POST', '/v1/webhooks/${_enc(id)}/deliveries/redeliver-exhausted')).json as Map)['requeued'] as int;
}

/// The outcome of a lab report import.
class LabImportResult {
  LabImportResult({required this.created, required this.skipped, required this.unmapped, required this.warnings, required this.observations});
  final int created, skipped;
  final List<String> unmapped, warnings;
  final List<Map<String, dynamic>> observations;
  factory LabImportResult.fromJson(Map<String, dynamic> j) => LabImportResult(
      created: (j['created'] as num).toInt(), skipped: (j['skipped'] as num?)?.toInt() ?? 0,
      unmapped: ((j['unmapped'] as List?) ?? []).cast<String>(), warnings: ((j['warnings'] as List?) ?? []).cast<String>(),
      observations: ((j['observations'] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList());
}

/// Lab connector: a whole report becomes laboratory Observations (`/v1/patients/{id}/labs/import`).
/// Re-sending the same report is safe: rows already imported are skipped.
class LabsResource {
  LabsResource(this._c);
  final Anpheros _c;

  Future<LabImportResult> _import(String patientId, List<int> bytes, String contentType, {String? sourceSystem, String? defaultDate}) async {
    final r = await _c.request('POST', '/v1/patients/${_enc(patientId)}/labs/import', bytes: bytes, contentType: contentType, idempotent: true,
        query: {if (defaultDate != null) 'date': defaultDate}, headers: {if (sourceSystem != null) 'X-Anpheros-Source-System': sourceSystem});
    return LabImportResult.fromJson(r.json);
  }

  /// CSV with a header row: marker, value, unit, reference range (or ref_low/ref_high), date, optional LOINC code.
  Future<LabImportResult> importCsv(String patientId, String csv, {String? sourceSystem, String? defaultDate}) =>
      _import(patientId, utf8.encode(csv), 'text/csv', sourceSystem: sourceSystem, defaultDate: defaultDate);

  /// An HL7 v2 ORU^R01 message (ER7 text).
  Future<LabImportResult> importHl7(String patientId, String message, {String? sourceSystem}) =>
      _import(patientId, utf8.encode(message), 'x-application/hl7-v2+er7', sourceSystem: sourceSystem);

  /// Structured rows: `{marker, value, unit?, ref_low?, ref_high?, date?, code?}`.
  Future<LabImportResult> importItems(String patientId, List<Map<String, dynamic>> items, {String? defaultDate, String? origin, String? sourceSystem}) =>
      _import(patientId, utf8.encode(jsonEncode({'items': items, if (defaultDate != null) 'date': defaultDate, if (origin != null) 'origin': origin})),
          'application/json', sourceSystem: sourceSystem);
}
