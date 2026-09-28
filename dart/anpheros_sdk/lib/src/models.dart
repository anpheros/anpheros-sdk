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
  'ping',
];
