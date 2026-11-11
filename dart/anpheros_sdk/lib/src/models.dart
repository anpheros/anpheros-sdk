/// Typed models mirroring the platform's `/v1` shapes. Every object carries `fhir`,
/// the reference to the same resource on `/fhir/R4`.
library;

String? _s(Object? v) => v?.toString();
double? _d(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

/// One page of results with an opaque cursor for the next one.
class Page<T> {
  Page({required this.data, required this.total, this.nextCursor});
  /// The items of this page.
  final List<T> data;

  /// The total number of matching items.
  final int total;

  /// Cursor for the next page; `null` on the last page.
  final String? nextCursor;

  /// Whether another page follows.
  bool get hasMore => nextCursor != null;

  static Page<T> fromJson<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) item) => Page<T>(
        data: (json['data'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        nextCursor: json['next_cursor'] as String?,
      );
}

/// An identifier of a resource in another system (`system` + `value`), e.g. a national patient id.
class Identifier {
  const Identifier({this.system, required this.value});
  final String? system;
  final String value;
  factory Identifier.fromJson(Map<String, dynamic> j) => Identifier(system: _s(j['system']), value: j['value'] as String);
  Map<String, dynamic> toJson() => {if (system != null) 'system': system, 'value': value};
}

// ── Patient ──────────────────────────────────────────────────────────────────

/// The data needed to create a patient owned by your project (`POST /v1/patients`).
class PatientInput {
  const PatientInput({required this.given, required this.family, this.birthDate, this.gender, this.identifiers = const []});
  final String given;
  final String family;
  final DateTime? birthDate;

  /// male | female | other | unknown
  final String? gender;
  final List<Identifier> identifiers;
  Map<String, dynamic> toJson() => {
        'given': given,
        'family': family,
        if (birthDate != null) 'birth_date': _date(birthDate!),
        if (gender != null) 'gender': gender,
        if (identifiers.isNotEmpty) 'identifiers': identifiers.map((i) => i.toJson()).toList(),
      };
}

/// A patient record visible to your project, under your own (pairwise) id.
class Patient {
  Patient({required this.id, this.given, this.family, this.birthDate, this.gender, this.identifiers = const [], this.updatedAt, required this.fhir});
  final String id;
  final String? given;
  final String? family;
  final String? birthDate;
  final String? gender;
  final List<Identifier> identifiers;
  /// When the record was last updated (ISO 8601).
  final String? updatedAt;

  /// The same patient on the FHIR API, e.g. `Patient/…`.
  final String fhir;

  /// Given and family name joined with a space.
  String get displayName => [given, family].where((x) => x != null && x.isNotEmpty).join(' ');
  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
        id: j['id'] as String,
        given: _s(j['given']),
        family: _s(j['family']),
        birthDate: _s(j['birth_date']),
        gender: _s(j['gender']),
        identifiers: ((j['identifiers'] as List?) ?? []).map((e) => Identifier.fromJson(e as Map<String, dynamic>)).toList(),
        updatedAt: _s(j['updated_at']),
        fhir: j['fhir'] as String,
      );
}

// ── Observation ──────────────────────────────────────────────────────────────

/// One part of a composite measurement, e.g. systolic (LOINC 8480-6) inside a blood-pressure panel.
class Component {
  const Component({required this.code, this.system, this.display, required this.value, this.unit});
  final String code;
  final String? system;
  final String? display;
  final double value;
  final String? unit;
  factory Component.fromJson(Map<String, dynamic> j) =>
      Component(code: j['code'] as String, system: _s(j['system']), display: _s(j['display']), value: _d(j['value']) ?? 0, unit: _s(j['unit']));
  Map<String, dynamic> toJson() => {'code': code, if (system != null) 'system': system, if (display != null) 'display': display, 'value': value, if (unit != null) 'unit': unit};
}

/// The normal range of a laboratory value, as reported by the laboratory.
class ReferenceRange {
  const ReferenceRange({this.low, this.high});
  final double? low;
  final double? high;
  factory ReferenceRange.fromJson(Map<String, dynamic> j) => ReferenceRange(low: _d(j['low']), high: _d(j['high']));
  Map<String, dynamic> toJson() => {if (low != null) 'low': low, if (high != null) 'high': high};
}

/// Who produced a value: patient | practitioner | device | import | ai | derived.
enum AuthorType { patient, practitioner, device, import, ai, derived }

/// A measurement, lab result, symptom or survey answer to record for a patient (FHIR `Observation`).
class ObservationInput {
  const ObservationInput({
    required this.code,
    this.system = 'http://loinc.org',
    this.display,
    required this.category,
    required this.effectiveAt,
    this.value,
    this.unit,
    this.valueText,
    this.components = const [],
    this.referenceRange,
    this.note,
    this.derivedFrom = const [],
    this.authorType,
  });
  /// The code of what was measured, e.g. LOINC `4548-4` (HbA1c).
  final String code;

  /// The code system; LOINC by default.
  final String? system;

  /// A human-readable name; filled from LOINC when omitted.
  final String? display;

  /// vital-signs | laboratory | symptom | activity | survey | exam | imaging | social-history
  final String category;

  /// When the value was measured or collected.
  final DateTime effectiveAt;

  /// The numeric value, in [unit].
  final double? value;

  /// The unit, preferably UCUM (e.g. `mg/dL`, `mm[Hg]`, `kg`).
  final String? unit;

  /// A textual value, for results that are not numbers.
  final String? valueText;

  /// Parts of a composite measurement, e.g. systolic and diastolic pressure.
  final List<Component> components;

  /// The normal range reported with a lab value.
  final ReferenceRange? referenceRange;

  /// A free-text note.
  final String? note;

  /// FHIR references this value was derived from, e.g. `DocumentReference/…`.
  final List<String> derivedFrom;

  /// Who produced the value; the platform records `import` when omitted.
  final AuthorType? authorType;
  Map<String, dynamic> toJson() => {
        'code': code,
        if (system != null) 'system': system,
        if (display != null) 'display': display,
        'category': category,
        'effective_at': effectiveAt.toUtc().toIso8601String(),
        if (value != null) 'value': value,
        if (unit != null) 'unit': unit,
        if (valueText != null) 'value_text': valueText,
        if (components.isNotEmpty) 'components': components.map((c) => c.toJson()).toList(),
        if (referenceRange != null) 'reference_range': referenceRange!.toJson(),
        if (note != null) 'note': note,
        if (derivedFrom.isNotEmpty) 'derived_from': derivedFrom,
        if (authorType != null) 'author_type': authorType!.name,
      };
}

/// A stored observation: a vital sign, lab result, symptom, activity summary or survey answer.
class Observation {
  Observation({
    required this.id,
    required this.patient,
    required this.code,
    this.system,
    this.display,
    this.category,
    this.effectiveAt,
    this.value,
    this.unit,
    this.valueText,
    this.components = const [],
    this.referenceRange,
    this.note,
    this.derivedFrom = const [],
    this.status,
    this.updatedAt,
    required this.fhir,
  });
  final String id;
  final String patient;
  final String code;
  final String? system;
  final String? display;
  final String? category;
  final String? effectiveAt;
  final double? value;
  final String? unit;
  final String? valueText;
  final List<Component> components;
  final ReferenceRange? referenceRange;
  final String? note;
  final List<String> derivedFrom;
  final String? status;
  final String? updatedAt;
  final String fhir;
  DateTime? get effectiveDateTime => effectiveAt == null ? null : DateTime.tryParse(effectiveAt!);
  factory Observation.fromJson(Map<String, dynamic> j) => Observation(
        id: j['id'] as String,
        patient: j['patient'] as String,
        code: j['code'] as String,
        system: _s(j['system']),
        display: _s(j['display']),
        category: _s(j['category']),
        effectiveAt: _s(j['effective_at']),
        value: _d(j['value']),
        unit: _s(j['unit']),
        valueText: _s(j['value_text']),
        components: ((j['components'] as List?) ?? []).map((e) => Component.fromJson(e as Map<String, dynamic>)).toList(),
        referenceRange: j['reference_range'] == null ? null : ReferenceRange.fromJson(j['reference_range'] as Map<String, dynamic>),
        note: _s(j['note']),
        derivedFrom: ((j['derived_from'] as List?) ?? []).cast<String>(),
        status: _s(j['status']),
        updatedAt: _s(j['updated_at']),
        fhir: j['fhir'] as String,
      );
}

// ── Condition ────────────────────────────────────────────────────────────────

/// A diagnosis or health problem to record for a patient (FHIR `Condition`, ICD-10 by default).
class ConditionInput {
  const ConditionInput({required this.code, this.system = 'http://hl7.org/fhir/sid/icd-10', this.display, this.clinicalStatus = 'active', this.onset, this.abatement, this.note, this.authorType});
  final String code;
  final String? system;
  final String? display;
  final String clinicalStatus;
  final DateTime? onset;
  final DateTime? abatement;
  final String? note;
  final AuthorType? authorType;
  Map<String, dynamic> toJson() => {
        'code': code,
        if (system != null) 'system': system,
        if (display != null) 'display': display,
        'clinical_status': clinicalStatus,
        if (onset != null) 'onset': _date(onset!),
        if (abatement != null) 'abatement': _date(abatement!),
        if (note != null) 'note': note,
        if (authorType != null) 'author_type': authorType!.name,
      };
}

/// A stored condition (diagnosis or health problem) of a patient.
class Condition {
  Condition({required this.id, required this.patient, required this.code, this.system, this.display, this.clinicalStatus, this.onset, this.abatement, this.note, this.updatedAt, required this.fhir});
  final String id, patient, code;
  final String? system, display, clinicalStatus, onset, abatement, note, updatedAt;
  final String fhir;
  factory Condition.fromJson(Map<String, dynamic> j) => Condition(
        id: j['id'] as String, patient: j['patient'] as String, code: j['code'] as String, system: _s(j['system']), display: _s(j['display']),
        clinicalStatus: _s(j['clinical_status']), onset: _s(j['onset']), abatement: _s(j['abatement']), note: _s(j['note']),
        updatedAt: _s(j['updated_at']), fhir: j['fhir'] as String);
}

// ── Medication ───────────────────────────────────────────────────────────────

/// A medication a patient takes or took (FHIR `MedicationStatement`, ATC by default).
class MedicationInput {
  const MedicationInput({required this.display, this.code, this.system = 'http://www.whocc.no/atc', this.status = 'active', this.dosage, this.start, this.end, this.note, this.authorType});
  final String display;
  final String? code;
  final String? system;

  /// active | completed | stopped | on-hold | intended | unknown
  final String status;
  final String? dosage;
  final DateTime? start;
  final DateTime? end;
  final String? note;
  final AuthorType? authorType;
  Map<String, dynamic> toJson() => {
        'display': display,
        if (code != null) 'code': code,
        if (system != null) 'system': system,
        'status': status,
        if (dosage != null) 'dosage': dosage,
        if (start != null) 'start': _date(start!),
        if (end != null) 'end': _date(end!),
        if (note != null) 'note': note,
        if (authorType != null) 'author_type': authorType!.name,
      };
}

/// A stored medication statement of a patient.
class Medication {
  Medication({required this.id, required this.patient, required this.display, this.code, this.system, this.status, this.dosage, this.start, this.end, this.note, this.updatedAt, required this.fhir});
  final String id, patient, display;
  final String? code, system, status, dosage, start, end, note, updatedAt;
  final String fhir;
  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String, patient: j['patient'] as String, display: j['display'] as String, code: _s(j['code']), system: _s(j['system']),
        status: _s(j['status']), dosage: _s(j['dosage']), start: _s(j['start']), end: _s(j['end']), note: _s(j['note']),
        updatedAt: _s(j['updated_at']), fhir: j['fhir'] as String);
}

// ── Document ─────────────────────────────────────────────────────────────────

/// Metadata of a medical document to create before uploading its bytes (FHIR `DocumentReference`).
class DocumentInput {
  const DocumentInput({required this.title, this.kind = 'other', required this.contentType, this.date, this.description, this.authorType});
  final String title;

  /// lab_report | discharge_summary | prescription | imaging_report | referral | other
  final String kind;
  final String contentType;
  final DateTime? date;
  final String? description;
  final AuthorType? authorType;
  Map<String, dynamic> toJson() => {
        'title': title, 'kind': kind, 'content_type': contentType,
        if (date != null) 'date': _date(date!),
        if (description != null) 'description': description,
        if (authorType != null) 'author_type': authorType!.name,
      };
}

/// Where and how to upload a document's bytes directly to storage, valid for [expiresInSeconds].
class UploadTarget {
  UploadTarget({required this.url, required this.method, required this.headers, required this.expiresInSeconds});
  final String url, method;
  final Map<String, String> headers;
  final int expiresInSeconds;
  factory UploadTarget.fromJson(Map<String, dynamic> j) => UploadTarget(
      url: j['url'] as String, method: j['method'] as String, headers: (j['headers'] as Map).cast<String, String>(), expiresInSeconds: (j['expires_in_seconds'] as num).toInt());
}

/// A medical document: metadata, status (`preliminary` until finalized, then `final`) and checksum.
class Document {
  Document({required this.id, required this.patient, required this.kind, this.identifiers = const [], this.title, this.description, this.date, this.contentType, this.size, this.sha256, required this.status, this.downloadUrl, this.upload, this.updatedAt, required this.fhir});
  final String id, patient, kind, status, fhir;
  final String? title, description, date, contentType, sha256, downloadUrl, updatedAt;
  final int? size;
  final UploadTarget? upload;

  /// Your own identifiers on the document (`{system, value}`), if you set any.
  final List<Map<String, String>> identifiers;
  bool get isFinal => status == 'final';
  factory Document.fromJson(Map<String, dynamic> j) => Document(
        id: j['id'] as String, patient: j['patient'] as String, kind: j['kind'] as String,
        identifiers: ((j['identifiers'] as List?) ?? const []).map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))).toList(),
        title: _s(j['title']), description: _s(j['description']),
        date: _s(j['date']), contentType: _s(j['content_type']), size: (j['size'] as num?)?.toInt(), sha256: _s(j['sha256']), status: j['status'] as String,
        downloadUrl: _s(j['download_url']), upload: j['upload'] == null ? null : UploadTarget.fromJson(j['upload'] as Map<String, dynamic>),
        updatedAt: _s(j['updated_at']), fhir: j['fhir'] as String);
}

// ── Timeline, provenance, grants, context ────────────────────────────────────

/// One entry of a patient's chronological timeline across resource types.
class TimelineItem {
  TimelineItem({required this.type, required this.id, this.date, required this.title, this.summary, required this.fhir});
  final String type, id, title, fhir;
  final String? date, summary;
  factory TimelineItem.fromJson(Map<String, dynamic> j) => TimelineItem(
      type: j['type'] as String, id: j['id'] as String, date: _s(j['date']), title: j['title'] as String, summary: _s(j['summary']), fhir: j['fhir'] as String);
}

/// Who wrote one version of a resource, when, and from which source system.
class ProvenanceEntry {
  ProvenanceEntry({this.version, this.activity, this.recorded, this.authorType, this.author, this.sourceSystem, this.originId, required this.fhir});
  final int? version;
  final String? activity, recorded, authorType, author, sourceSystem, originId;
  final String fhir;
  factory ProvenanceEntry.fromJson(Map<String, dynamic> j) => ProvenanceEntry(
      version: (j['version'] as num?)?.toInt(), activity: _s(j['activity']), recorded: _s(j['recorded']), authorType: _s(j['author_type']),
      author: _s(j['author']), sourceSystem: _s(j['source_system']), originId: _s(j['origin_id']), fhir: j['fhir'] as String);
}

/// A consent grant: which application may access a patient's record, with which scopes, until when.
class GrantInfo {
  GrantInfo({
    required this.id,
    required this.status,
    this.purpose,
    required this.scopes,
    required this.scopesText,
    this.grantedAt,
    this.expiresAt,
    this.revokedAt,
    this.grantedBy,
    this.applicationId,
    this.applicationName,
    this.applicationKind,
    this.organization,
    this.privacyUrl,
    this.accessCount,
    this.lastAccessAt,
  });
  final String id, status;
  final String? purpose, grantedAt, expiresAt, revokedAt, grantedBy, applicationId, applicationName, applicationKind, organization, privacyUrl, lastAccessAt;
  final List<String> scopes, scopesText;

  /// How many requests were made under this grant (only on the patient API).
  final int? accessCount;

  /// The grant was created by the application itself (a trusted first-party app
  /// exchanging the person's identity), not through the consent page.
  bool get byCreator => grantedBy == 'creator';

  factory GrantInfo.fromJson(Map<String, dynamic> j) {
    final app = (j['application'] as Map?) ?? const {};
    return GrantInfo(
        id: j['id'] as String, status: j['status'] as String, purpose: _s(j['purpose']), scopes: ((j['scopes'] as List?) ?? []).cast<String>(),
        scopesText: ((j['scopes_text'] as List?) ?? []).cast<String>(), grantedAt: _s(j['granted_at']), expiresAt: _s(j['expires_at']),
        revokedAt: _s(j['revoked_at']), grantedBy: _s(j['granted_by']), applicationId: _s(app['id']), applicationName: _s(app['name']),
        applicationKind: _s(app['kind']), organization: _s(app['organization']), privacyUrl: _s(app['privacy_url']),
        accessCount: (j['access_count'] as num?)?.toInt(), lastAccessAt: _s(j['last_access_at']));
  }
}

/// One of the person's records on the platform (their own or a dependent's).
class MyPatient {
  MyPatient({required this.id, this.given, this.family, this.birthDate, required this.relationship});
  final String id;
  final String? given, family, birthDate;

  /// `self` or `dependent`.
  final String relationship;
  String get displayName => [given, family].where((p) => p != null && p.isNotEmpty).join(' ');
  factory MyPatient.fromJson(Map<String, dynamic> j) => MyPatient(
      id: j['id'] as String, given: _s(j['given']), family: _s(j['family']), birthDate: _s(j['birth_date']), relationship: (j['relationship'] as String?) ?? 'self');
}

/// One request an application made under a grant.
class AccessEntry {
  AccessEntry({required this.ts, required this.action, this.resourceType, this.resourceId, this.status, this.actor, this.actorRef});
  final String ts, action;
  final String? resourceType, resourceId, status;

  /// The practitioner behind the request, by name (`actor`) and reference (`actorRef`), when the app declared one.
  final String? actor, actorRef;
  factory AccessEntry.fromJson(Map<String, dynamic> j) => AccessEntry(
      ts: j['ts'] as String, action: j['action'] as String, resourceType: _s(j['resource_type']), resourceId: _s(j['resource_id']),
      status: _s(j['status']), actor: _s(j['actor']), actorRef: _s(j['actor_ref']));
}

/// A request for an AI-ready context of a patient's record (`POST /v1/context`).
class ContextRequest {
  const ContextRequest({required this.patient, this.task, this.question, this.needs, this.budgetTokens = 2000, this.format = 'structured', this.windowDays});
  final String patient;
  final String? task, question;

  /// e.g. `['labs:4548-4', 'vitals:trend:85354-9', 'timeline:180d']`
  final List<String>? needs;
  final int budgetTokens;

  /// structured | text
  final String format;
  final int? windowDays;
  Map<String, dynamic> toJson() => {
        'patient': patient, if (task != null) 'task': task, if (question != null) 'question': question, if (needs != null) 'needs': needs,
        'budget_tokens': budgetTokens, 'format': format, if (windowDays != null) 'window_days': windowDays,
      };
}

/// One section of an AI context (e.g. `medications`, `labs`, `vitals`, `ai_notes`), with its sources.
class ContextSection {
  ContextSection({required this.kind, required this.tokens, required this.items, this.text, this.note, required this.sources});
  final String kind;
  final int tokens;
  final List<Map<String, dynamic>> items;
  final String? text, note;
  final Map<String, int> sources;
  factory ContextSection.fromJson(Map<String, dynamic> j) => ContextSection(
      kind: j['kind'] as String, tokens: (j['tokens'] as num).toInt(), items: ((j['items'] as List?) ?? []).cast<Map<String, dynamic>>(),
      text: _s(j['text']), note: _s(j['note']), sources: ((j['sources'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
}

/// An AI-ready, provenance-labelled context of a patient's record, within a token budget.
class ContextResult {
  ContextResult({required this.manifestId, required this.patient, required this.budgetTokens, required this.tokensUsed, required this.sections, required this.omitted, required this.warnings, this.text, required this.needs});
  final String manifestId, patient;
  final int budgetTokens, tokensUsed;
  final List<ContextSection> sections;
  final List<String> omitted, warnings;
  final String? text;
  final Map<String, dynamic> needs;
  ContextSection? section(String kind) => sections.where((s) => s.kind == kind).firstOrNull;
  factory ContextResult.fromJson(Map<String, dynamic> j) => ContextResult(
      manifestId: j['manifest_id'] as String, patient: j['patient'] as String, budgetTokens: (j['budget_tokens'] as num).toInt(),
      tokensUsed: (j['tokens_used'] as num).toInt(), sections: (j['sections'] as List).map((e) => ContextSection.fromJson(e as Map<String, dynamic>)).toList(),
      omitted: ((j['omitted'] as List?) ?? []).cast<String>(), warnings: ((j['warnings'] as List?) ?? []).cast<String>(), text: _s(j['text']),
      needs: (j['needs'] as Map?)?.cast<String, dynamic>() ?? {});
}

/// A code from the platform's bundled terminology subset (LOINC or ATC), with its display names.
class Concept {
  Concept({required this.system, required this.code, required this.display, required this.displayRo, required this.category, this.unit});
  final String system, code, display, displayRo, category;
  final String? unit;
  factory Concept.fromJson(Map<String, dynamic> j) => Concept(
      system: j['system'] as String, code: j['code'] as String, display: j['display'] as String, displayRo: j['display_ro'] as String,
      category: j['category'] as String, unit: _s(j['unit']));
}

String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A webhook endpoint of the project. `secret` is present only when created or rotated.
class WebhookEndpoint {
  WebhookEndpoint({required this.id, required this.url, required this.events, this.description, required this.active, required this.environment,
      this.createdAt, this.updatedAt, this.lastSuccessAt, this.lastFailureAt, this.failureStreak = 0, this.secret});
  final String id, url, environment;
  final List<String> events;
  final String? description, createdAt, updatedAt, lastSuccessAt, lastFailureAt, secret;
  final bool active;
  final int failureStreak;
  factory WebhookEndpoint.fromJson(Map<String, dynamic> j) => WebhookEndpoint(
      id: j['id'] as String, url: j['url'] as String, events: ((j['events'] as List?) ?? []).cast<String>(), description: _s(j['description']),
      active: j['active'] as bool? ?? true, environment: (j['environment'] as String?) ?? 'sandbox', createdAt: _s(j['created_at']),
      updatedAt: _s(j['updated_at']), lastSuccessAt: _s(j['last_success_at']), lastFailureAt: _s(j['last_failure_at']),
      failureStreak: (j['failure_streak'] as num?)?.toInt() ?? 0, secret: _s(j['secret']));
}

/// One attempt log of an event sent to an endpoint.
class WebhookDelivery {
  WebhookDelivery({required this.id, required this.endpointId, required this.eventId, required this.eventType, required this.status,
      required this.attempts, this.nextAttemptAt, this.lastStatusCode, this.lastError, this.createdAt, this.deliveredAt, required this.payload});
  final String id, endpointId, eventId, eventType, status;
  final int attempts;
  final int? lastStatusCode;
  final String? nextAttemptAt, lastError, createdAt, deliveredAt;
  final Map<String, dynamic> payload;
  factory WebhookDelivery.fromJson(Map<String, dynamic> j) => WebhookDelivery(
      id: j['id'] as String, endpointId: j['endpoint_id'] as String, eventId: j['event_id'] as String, eventType: j['event_type'] as String,
      status: j['status'] as String, attempts: (j['attempts'] as num?)?.toInt() ?? 0, nextAttemptAt: _s(j['next_attempt_at']),
      lastStatusCode: (j['last_status_code'] as num?)?.toInt(), lastError: _s(j['last_error']), createdAt: _s(j['created_at']),
      deliveredAt: _s(j['delivered_at']), payload: ((j['payload'] as Map?) ?? const {}).cast<String, dynamic>());
}

/// Webhook event types the platform emits (kept in sync with app/webhooks/events.py).
const List<String> webhookEventTypes = [
  'resource.created', 'resource.updated', 'resource.deleted',
  'consent.granted', 'consent.revoked',
  'document.finalized',
  'proposal.created',
  'result.released',
  'access_request.created',
  'patterns.updated',
  'ping',
];

/// One health-pattern finding (beta; on production records only under a patient's `anpheros/patterns` consent): what the record shows over a period, with its evidence,
/// method and limitations. Derived by fixed statistical rules: not a diagnosis, and an association is not a cause.
class PatternFinding {
  PatternFinding({required this.id, required this.type, this.subtype, this.strength, required this.statisticallySupported,
      required this.summaryCode, required this.summaryText, required this.windowStart, required this.windowEnd,
      required this.limitations, required this.evidenceTotal, required this.method, this.confidence, this.disclosure,
      this.shownOnlyIfSupported = false, required this.raw});
  final String id, type, summaryCode, summaryText, windowStart, windowEnd;

  /// True for `step_change`, `day_of_week`, `time_of_day` and `month_of_year`: show it to a person only when supported.
  final bool shownOnlyIfSupported;
  final String? subtype;

  /// Deprecated: the server has not sent a strength grade since 5 Nov 2026; null on current payloads.
  final String? strength;

  /// The method, with its maturity and whether its findings may be shown to the person or notify (engine 0.6.0).
  final PatternMethodRef method;

  /// Five separate axes (`data_quality`, `statistical`, `extraction`, `generalizability`, `research`), no single score;
  /// null on findings stored before engine 0.6.0.
  final Map<String, dynamic>? confidence;

  /// The standard disclosure to show with the finding when its method is patient-facing; null otherwise.
  final String? disclosure;

  /// Only `true` means statistical support; weak and not_tested findings are descriptions.
  final bool statisticallySupported;

  /// Limitation codes, e.g. `not_causal`, `no_clinical_review`, `weak_evidence`.
  final List<String> limitations;
  final int evidenceTotal;

  /// The whole finding as sent by the server (result, statistics, evidence, method, safety…).
  final Map<String, dynamic> raw;

  factory PatternFinding.fromJson(Map<String, dynamic> j) => PatternFinding(
      id: j['id'] as String, type: j['type'] as String, subtype: _s(j['subtype']), strength: _s(j['strength']),
      statisticallySupported: j['statistically_supported'] as bool? ?? false, summaryCode: j['summary_code'] as String,
      summaryText: j['summary_text'] as String, windowStart: (j['window'] as Map)['start'] as String,
      windowEnd: (j['window'] as Map)['end'] as String,
      limitations: ((j['limitations'] as List?) ?? []).map((e) => (e as Map)['code'] as String).toList(),
      evidenceTotal: (j['evidence_total'] as num?)?.toInt() ?? 0,
      method: PatternMethodRef.fromJson(((j['method'] as Map?) ?? const {}).cast<String, dynamic>()),
      confidence: (j['confidence'] as Map?)?.cast<String, dynamic>(), disclosure: _s(j['disclosure']),
      shownOnlyIfSupported: j['shown_only_if_supported'] as bool? ?? selectionSubtypes.contains(j['subtype']), raw: j);

  /// Subtypes that pick what they name among many tries; the fallback when an older server leaves out
  /// `shown_only_if_supported` (as the first-party backend does).
  static const Set<String> selectionSubtypes = {'step_change', 'day_of_week', 'time_of_day', 'month_of_year'};
}

/// The method behind a finding (engine 0.6.0 adds the registry status; older servers send name, version, parameters).
class PatternMethodRef {
  PatternMethodRef({required this.name, required this.version, required this.maturity, required this.patientFacing,
      required this.notify, required this.parameters});
  final String name, version;

  /// `experimental`, `internally_validated`, `clinically_reviewed` or `production_approved`; `experimental` when absent.
  final String maturity;

  /// Only patient-facing methods may be shown to the person (with the disclosure); only those marked `notify` may notify.
  final bool patientFacing, notify;
  final Map<String, dynamic> parameters;

  factory PatternMethodRef.fromJson(Map<String, dynamic> j) => PatternMethodRef(
      name: j['name'] as String? ?? '', version: j['version'] as String? ?? '', maturity: j['maturity'] as String? ?? 'experimental',
      patientFacing: j['patient_facing'] as bool? ?? false, notify: j['notify'] as bool? ?? false,
      parameters: ((j['parameters'] as Map?) ?? const {}).cast<String, dynamic>());
}

/// What would unlock a test that could not run (engine 0.6.0). `withinDays` and `by` are null for events, episodes and
/// nights, which depend on what happens, not only on recording.
class PatternNextStep {
  PatternNextStep({required this.variable, required this.need, required this.missing, this.withinDays, this.by, required this.entry,
      required this.method, required this.type, this.patientFacing = false});
  final Map<String, dynamic> variable;

  /// Whether the method this step unlocks is patient-facing now; show the step to a person only when true.
  final bool patientFacing;

  /// `days`, `events`, `episodes` or `nights`.
  final String need;
  final int missing;
  final int? withinDays;
  final String? by;

  /// `variable`: days with a value of this variable; `any`: days with any entry by the person.
  final String entry;
  final String method, type;

  factory PatternNextStep.fromJson(Map<String, dynamic> j) => PatternNextStep(
      variable: ((j['variable'] as Map?) ?? const {}).cast<String, dynamic>(), need: j['need'] as String? ?? 'days',
      missing: (j['missing'] as num?)?.toInt() ?? 0, withinDays: (j['within_days'] as num?)?.toInt(), by: _s(j['by']),
      entry: j['entry'] as String? ?? 'variable', method: j['method'] as String? ?? '', type: j['type'] as String? ?? '',
      patientFacing: j['patient_facing'] as bool? ?? false);
}

List<PatternNextStep> _nextSteps(Object? v) =>
    ((v as List?) ?? const []).map((e) => PatternNextStep.fromJson((e as Map).cast<String, dynamic>())).toList();

/// The engine's method registry (`GET /v1/patterns/methods`): one entry per method, with maturity and validation.
class PatternMethods {
  PatternMethods({required this.engineVersion, required this.data, required this.maturities, required this.disclosure,
      required this.confidenceRules});
  final String engineVersion, disclosure;
  final List<Map<String, dynamic>> data;
  final List<String> maturities;
  final Map<String, dynamic> confidenceRules;

  factory PatternMethods.fromJson(Map<String, dynamic> j) => PatternMethods(
      engineVersion: j['engine_version'] as String? ?? '',
      data: ((j['data'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      maturities: ((j['maturities'] as List?) ?? const []).map((e) => e as String).toList(), disclosure: j['disclosure'] as String? ?? '',
      confidenceRules: ((j['confidence_rules'] as Map?) ?? const {}).cast<String, dynamic>());
}

/// One event in the history of a stored finding: `appeared`, `supported`, `unsupported` or `gone`.
class PatternEvent {
  PatternEvent({required this.event, required this.at, required this.engineVersion, required this.trigger});
  final String event, at, engineVersion, trigger;

  factory PatternEvent.fromJson(Map<String, dynamic> j) => PatternEvent(
      event: j['event'] as String, at: j['at'] as String, engineVersion: j['engine_version'] as String, trigger: j['trigger'] as String);
}

/// A stored finding (beta): kept up to date in the background under the person's feature consent. `findingKey` stays the
/// same when new readings arrive; `id` changes with the data.
class StoredPatternFinding {
  StoredPatternFinding({required this.findingKey, required this.id, required this.type, this.subtype, required this.status,
      required this.statisticallySupported, required this.summaryCode, required this.summaryText, required this.firstSeenAt,
      required this.lastChangedAt, this.becameSupportedAt, required this.events, required this.method, this.confidence,
      this.disclosure, this.shown = false, this.shownSince, required this.raw});
  final String findingKey, id, type, status, summaryCode, summaryText, firstSeenAt, lastChangedAt;
  final String? subtype, becameSupportedAt;

  /// The display rule (`StoredPatterns.displayRule`): show the finding to the person only when `shown` and
  /// `method.patientFacing` are both true. `shownSince`: last day of the window of the run that made it shown.
  final bool shown;
  final String? shownSince;

  /// The method with its maturity, `patientFacing` and `notify` (engine 0.6.0).
  final PatternMethodRef method;

  /// Five separate axes, no single score; null on findings stored before engine 0.6.0.
  final Map<String, dynamic>? confidence;

  /// The standard disclosure when the method is patient-facing; null otherwise.
  final String? disclosure;

  /// Only `true` means statistical support; other findings are descriptions.
  final bool statisticallySupported;

  /// Filled with `includeEvents: true`.
  final List<PatternEvent> events;

  /// The whole finding as sent by the server (window, evidence, method, limitations, safety…).
  final Map<String, dynamic> raw;

  factory StoredPatternFinding.fromJson(Map<String, dynamic> j) => StoredPatternFinding(
      findingKey: j['finding_key'] as String, id: j['id'] as String, type: j['type'] as String, subtype: _s(j['subtype']),
      status: j['status'] as String, statisticallySupported: j['statistically_supported'] as bool? ?? false,
      summaryCode: j['summary_code'] as String, summaryText: j['summary_text'] as String, firstSeenAt: j['first_seen_at'] as String,
      lastChangedAt: j['last_changed_at'] as String, becameSupportedAt: _s(j['became_supported_at']),
      events: ((j['events'] as List?) ?? []).map((e) => PatternEvent.fromJson(e as Map<String, dynamic>)).toList(),
      method: PatternMethodRef.fromJson(((j['method'] as Map?) ?? const {}).cast<String, dynamic>()),
      confidence: (j['confidence'] as Map?)?.cast<String, dynamic>(), disclosure: _s(j['disclosure']),
      shown: j['shown'] as bool? ?? false, shownSince: _s(j['shown_since']), raw: j);
}

/// The stored findings of a record, with the last background run and whether it is stale.
class StoredPatterns {
  StoredPatterns({required this.patient, required this.asOf, required this.stale, required this.queued, this.refreshStatus,
      required this.lastRun, required this.consent, required this.findings, this.nextSteps = const [],
      this.displayRule = const {}, required this.interpretationGuidance});

  /// The rule behind `shown` (`version`, `tick_days`, `show_after_days`, `hide_after_days`, `text`).
  final Map<String, dynamic> displayRule;
  final String patient, asOf, interpretationGuidance;

  /// True once the person's local date has passed `asOf`; a refresh is due.
  final bool stale;

  /// A new run is waiting; `refreshStatus` is `pending`, `failed` or null.
  final bool queued;
  final String? refreshStatus;
  final Map<String, dynamic> lastRun, consent;
  final List<StoredPatternFinding> findings;

  /// From the last run, fewest entries first (engine 0.6.0); empty for older runs.
  final List<PatternNextStep> nextSteps;

  factory StoredPatterns.fromJson(Map<String, dynamic> j) => StoredPatterns(
      patient: j['patient'] as String, asOf: j['as_of'] as String, stale: j['stale'] as bool? ?? false,
      queued: ((j['refresh'] as Map?) ?? const {})['queued'] as bool? ?? false, refreshStatus: _s(((j['refresh'] as Map?) ?? const {})['status']),
      lastRun: ((j['last_run'] as Map?) ?? const {}).cast<String, dynamic>(), consent: ((j['consent'] as Map?) ?? const {}).cast<String, dynamic>(),
      findings: ((j['findings'] as List?) ?? []).map((e) => StoredPatternFinding.fromJson(e as Map<String, dynamic>)).toList(),
      nextSteps: _nextSteps(j['next_steps']), displayRule: ((j['display_rule'] as Map?) ?? const {}).cast<String, dynamic>(),
      interpretationGuidance: j['interpretation_guidance'] as String? ?? '');
}

/// A run of the pattern engine for one patient and window.
class PatternRun {
  PatternRun({required this.patient, required this.engineVersion, required this.testsInRun, this.familyFingerprint, required this.findings,
      required this.notComputed, this.nextSteps = const [], required this.omitted, required this.interpretationGuidance});
  final String patient, engineVersion, interpretationGuidance;
  final int testsInRun;
  final String? familyFingerprint;
  final List<PatternFinding> findings;

  /// What could not be computed and why (too little data, no variation…): not findings. Since engine 0.6.0 each may carry
  /// a `next_step` (see [PatternNextStep]).
  final List<Map<String, dynamic>> notComputed;

  /// What would unlock the tests that could not run, fewest entries first (engine 0.6.0); empty on older servers.
  final List<PatternNextStep> nextSteps;

  /// What the consent behind the credential left out.
  final List<String> omitted;

  factory PatternRun.fromJson(Map<String, dynamic> j) => PatternRun(
      patient: j['patient'] as String, engineVersion: j['engine_version'] as String, testsInRun: (j['tests_in_run'] as num).toInt(),
      familyFingerprint: _s(j['family_fingerprint']),
      findings: (j['findings'] as List).map((e) => PatternFinding.fromJson(e as Map<String, dynamic>)).toList(),
      notComputed: (j['not_computed'] as List).map((e) => e as Map<String, dynamic>).toList(), nextSteps: _nextSteps(j['next_steps']),
      omitted: (j['omitted'] as List).map((e) => e as String).toList(), interpretationGuidance: j['interpretation_guidance'] as String);
}

/// The person's feedback on a stored finding, as the platform kept it (`POST …/patterns/{findingKey}/feedback`).
class PatternFeedbackResult {
  PatternFeedbackResult({required this.id, required this.findingKey, required this.response, this.note, required this.createdAt});
  final String id, findingKey, response, createdAt;
  final String? note;

  factory PatternFeedbackResult.fromJson(Map<String, dynamic> j) => PatternFeedbackResult(
      id: j['id'] as String, findingKey: j['finding_key'] as String, response: j['response'] as String,
      note: _s(j['note']), createdAt: j['created_at'] as String);
}

/// A server text with its translation key (`key`) and English base (`text`).
class KeyedText {
  KeyedText({required this.key, required this.text});
  final String key, text;

  static KeyedText? fromJson(Object? v) {
    if (v is! Map) return null;
    return KeyedText(key: v['key']?.toString() ?? '', text: v['text']?.toString() ?? '');
  }
}

/// Published research on a stored finding (`GET …/patterns/{findingKey}/research`, beta). When [available] is false,
/// [reason] says why (for example `finding.library_not_populated` while the library is being built) and [research] is
/// null: show the reason, never a verdict. Research describes groups of people, not this person.
class FindingResearch {
  FindingResearch({required this.patient, required this.findingKey, required this.shown, required this.available, this.reason,
      this.interpretation, this.research, required this.raw});
  final String patient, findingKey;
  final bool shown, available;
  final KeyedText? reason, interpretation;

  /// `verdict` (`investigated` / `not_adequately_investigated`), `best_level`, `counts`, `missing`, `summary`, `records`
  /// (each with its citation, design limits and status), `excluded`, `curation` (human reviewers only), `notes`.
  final Map<String, dynamic>? research;

  /// `investigated`, `not_adequately_investigated`, or null when not [available].
  String? get verdict => _s(research?['verdict']);
  final Map<String, dynamic> raw;

  factory FindingResearch.fromJson(Map<String, dynamic> j) => FindingResearch(
      patient: j['patient']?.toString() ?? '', findingKey: j['finding_key']?.toString() ?? '', shown: j['shown'] as bool? ?? false,
      available: j['available'] as bool? ?? false, reason: KeyedText.fromJson(j['reason']),
      interpretation: KeyedText.fromJson(j['interpretation']), research: (j['research'] as Map?)?.cast<String, dynamic>(), raw: j);
}

/// Crisis lines for one country (`GET /v1/safety/crisis-resources`). Show [text] to the person at once.
class CrisisResources {
  CrisisResources({this.country, this.emergencyNumber, this.crisisLineName, this.crisisLineNumber, required this.directoryName,
      required this.directoryUrl, required this.text});
  final String? country, emergencyNumber, crisisLineName, crisisLineNumber;
  final String directoryName, directoryUrl, text;

  factory CrisisResources.fromJson(Map<String, dynamic> j) {
    final line = (j['crisis_line'] as Map?) ?? const {};
    final dir = (j['directory'] as Map?) ?? const {};
    return CrisisResources(
        country: _s(j['country']), emergencyNumber: _s(j['emergency_number']), crisisLineName: _s(line['name']),
        crisisLineNumber: _s(line['number']), directoryName: dir['name']?.toString() ?? 'Find A Helpline',
        directoryUrl: dir['url']?.toString() ?? 'https://findahelpline.com', text: j['text']?.toString() ?? '');
  }
}
