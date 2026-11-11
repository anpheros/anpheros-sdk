/** Typed shapes of the `/v1` API. Every object carries `fhir`, its `/fhir/R4` reference. */

export interface Page<T> { data: T[]; total: number; next_cursor: string | null }

export interface Identifier { system?: string; value: string }

export type AuthorType = 'patient' | 'practitioner' | 'device' | 'import' | 'ai' | 'derived';
export type Category = 'vital-signs' | 'laboratory' | 'symptom' | 'activity' | 'survey' | 'exam' | 'imaging' | 'social-history';

export interface PatientInput { given: string; family: string; birth_date?: string; gender?: 'male' | 'female' | 'other' | 'unknown'; identifiers?: Identifier[] }
export interface Patient { id: string; given: string | null; family: string | null; birth_date: string | null; gender: string | null; identifiers: Identifier[]; updated_at: string | null; fhir: string }

export interface Component { code: string; system?: string | null; display?: string | null; value: number; unit?: string | null }
export interface ReferenceRange { low?: number | null; high?: number | null }

export interface ObservationInput {
  code: string; system?: string; display?: string; category: Category; effective_at: string;
  value?: number; unit?: string; value_text?: string; components?: Component[]; reference_range?: ReferenceRange;
  note?: string; derived_from?: string[]; author_type?: AuthorType;
}
export interface Observation {
  id: string; patient: string; code: string; system: string | null; display: string | null; category: string | null; effective_at: string | null;
  value: number | null; unit: string | null; value_text: string | null; components: Component[]; reference_range: ReferenceRange | null;
  note: string | null; derived_from: string[]; status: string | null; updated_at: string | null; fhir: string;
}

export type ClinicalStatus = 'active' | 'recurrence' | 'relapse' | 'inactive' | 'remission' | 'resolved';
export interface ConditionInput { code: string; system?: string; display?: string; clinical_status?: ClinicalStatus; onset?: string; abatement?: string; note?: string; author_type?: AuthorType }
export interface Condition { id: string; patient: string; code: string; system: string | null; display: string | null; clinical_status: string | null; onset: string | null; abatement: string | null; note: string | null; updated_at: string | null; fhir: string }

export type MedStatus = 'active' | 'completed' | 'stopped' | 'on-hold' | 'intended' | 'unknown';
export interface MedicationInput { display: string; code?: string; system?: string; status?: MedStatus; dosage?: string; start?: string; end?: string; note?: string; author_type?: AuthorType }
export interface Medication { id: string; patient: string; display: string; code: string | null; system: string | null; status: string | null; dosage: string | null; start: string | null; end: string | null; note: string | null; updated_at: string | null; fhir: string }

export type DocKind = 'lab_report' | 'discharge_summary' | 'prescription' | 'imaging_report' | 'referral' | 'other';
export interface DocumentInput { title: string; kind?: DocKind; content_type: string; date?: string; description?: string; author_type?: AuthorType }
export interface UploadTarget { url: string; method: string; headers: Record<string, string>; expires_in_seconds: number }
export interface Document { identifiers: { system: string; value: string }[];
  id: string; patient: string; kind: string; title: string | null; description: string | null; date: string | null; content_type: string | null;
  size: number | null; sha256: string | null; status: 'pending' | 'final'; download_url?: string | null; upload?: UploadTarget | null; updated_at: string | null; fhir: string;
}

export interface TimelineItem { type: 'observation' | 'condition' | 'medication' | 'document' | 'encounter' | 'appointment' | 'immunization' | 'episode'; id: string; date: string | null; title: string; summary: string | null; fhir: string }
export interface ProvenanceEntry { version: number | null; activity: string | null; recorded: string | null; author_type: string | null; author: string | null; source_system: string | null; origin_id: string | null; fhir: string }

export interface GrantInfo {
  id: string; status: string; purpose: string | null; application: { id: string; name: string | null; kind: string | null; organization: string | null; privacy_url: string | null };
  scopes: string[]; scopes_text: string[]; granted_at: string; expires_at: string | null; revoked_at: string | null; granted_by: string; consent: string | null;
  /** Only on the patient API (`me`). */
  access_count?: number; last_access_at?: string | null;
}

/** One of the person's records on the platform (their own or a dependent's). */
export interface MyPatient { id: string; given: string | null; family: string | null; birth_date: string | null; relationship: 'self' | 'dependent' }

/** One request an application made under a grant. */
export interface AccessEntry { ts: string; action: string; resource_type: string | null; resource_id: string | null; status: string | null; actor?: string | null; actor_ref?: string | null }

export interface ContextRequest { patient: string; task?: string; question?: string; needs?: string[]; budget_tokens?: number; format?: 'structured' | 'text'; window_days?: number }
export interface ContextSection { kind: string; tokens: number; items: Record<string, unknown>[]; text?: string; note?: string; sources: Record<string, number> }
export interface ContextResult {
  manifest_id: string; patient: string; budget_tokens: number; tokens_used: number; needs: Record<string, unknown>;
  sections: ContextSection[]; omitted: string[]; warnings: string[]; provenance_note: string; text?: string;
}

export interface Concept { system: string; code: string; display: string; display_ro: string; category: string; unit: string | null }

/** Any FHIR resource (kept loose on purpose; use a FHIR typing package if you want strict types). */
export type FhirResource = { resourceType: string; id?: string; [k: string]: unknown };
export type Bundle = FhirResource & { type: string; total?: number; entry?: { fullUrl?: string; resource?: FhirResource; response?: Record<string, unknown> }[]; link?: { relation: string; url: string }[] };

/** A webhook endpoint of the project. `secret` is present only when created or rotated. */
export interface WebhookEndpoint {
  id: string; url: string; events: string[]; description: string | null; active: boolean; environment: 'sandbox' | 'production';
  created_at: string; updated_at: string; last_success_at: string | null; last_failure_at: string | null; failure_streak: number; secret?: string;
}

/** One attempt log of an event sent to an endpoint. */
export interface WebhookDelivery {
  id: string; endpoint_id: string; event_id: string; event_type: string; status: 'pending' | 'delivered' | 'failed' | 'exhausted';
  attempts: number; next_attempt_at: string | null; last_status_code: number | null; last_error: string | null;
  created_at: string; delivered_at: string | null; payload: Record<string, unknown>;
}

/** The outcome of a lab report import. */
export interface LabImportResult { created: number; skipped: number; unmapped: string[]; warnings: string[]; observations: Record<string, unknown>[] }

/** Webhook event types the platform emits (kept in sync with app/webhooks/events.py). */
export const WEBHOOK_EVENT_TYPES = [
  'resource.created', 'resource.updated', 'resource.deleted',
  'consent.granted', 'consent.revoked',
  'document.finalized',
  'proposal.created',
  'result.released',
  'access_request.created',
  'patterns.updated',
  'ping',
] as const;
export type WebhookEventType = typeof WEBHOOK_EVENT_TYPES[number];

/** Health patterns (beta; on production records only under a patient's `anpheros/patterns` consent): derived by fixed statistical rules; not diagnoses, and an association is not a cause. */
export type PatternStrength = 'strong' | 'moderate' | 'weak' | 'not_tested';
export type PatternType = 'trend' | 'baseline_deviation' | 'recurrence' | 'association' | 'convergence';

export interface PatternEvidence { resource: string; version: number; date: string | null; value: number | null; author_type: string | null }

/** Method maturity (engine 0.6.0): only `internally_validated` or above is shown to the person, with `disclosure`. */
export type PatternMaturity = 'experimental' | 'internally_validated' | 'clinically_reviewed' | 'production_approved';
export interface PatternMethodRef {
  name: string;
  version: string;
  parameters: Record<string, unknown>;
  /** From the method registry (engine 0.6.0); absent on older servers. */
  maturity?: PatternMaturity;
  patient_facing?: boolean;
  /** `true` only for `internally_validated` methods marked eligible: the transition to supported may notify. */
  notify?: boolean;
}
export type PatternLevel = 'low' | 'medium' | 'high';
/** Five separate axes, no single score (engine 0.6.0). */
export interface PatternConfidence {
  data_quality: { level: PatternLevel; coverage: number | null; regularity: number | null; sources: number;
                  excluded: Record<string, number>; local_time_share: number | null };
  /** No strength grade here either: only q and the effect over the threshold. */
  statistical: { q: number | null; effect_vs_threshold: number | null; [extra: string]: unknown };
  extraction: { level: PatternLevel; share_manual: number; share_device: number; share_import_or_document: number;
                share_clinician?: number };
  generalizability: 'personal' | 'population' | 'research_supported' | string;
  research: { level: string; references: unknown[] };
  [extra: string]: unknown;
}
/** What would unlock a test that could not run (engine 0.6.0). `within_days`/`by` are null for events, episodes and nights. */
export interface PatternNextStep {
  variable: Record<string, unknown>;
  need: 'days' | 'events' | 'episodes' | 'nights';
  missing: number;
  within_days: number | null;
  by: string | null;
  /** `variable`: days with a value of this variable; `any`: days with any entry by the person. */
  entry: 'variable' | 'any';
  method: string;
  type: string;
  /** Whether the method this step unlocks is patient-facing now; show the step to a person only when true (absent on older servers). */
  patient_facing?: boolean;
}

export interface PatternFinding {
  id: string;
  patient: string;
  type: PatternType;
  subtype: string | null;
  epistemic_status: 'descriptive_observation' | 'statistical_association' | 'validated_prediction';
  /** @deprecated Not sent since 5 Nov 2026 (no strength grade in the output); kept optional for older payloads. */
  strength?: PatternStrength;
  /** Only `true` means statistical support; weak and not_tested findings are descriptions. */
  statistically_supported: boolean;
  summary_code: string;
  summary_text: string;
  variables: Record<string, unknown>[];
  window: { start: string; end: string };
  comparison_window: { start: string; end: string } | null;
  result: Record<string, unknown>;
  statistics: Record<string, unknown> | null;
  threshold: Record<string, unknown> | null;
  evidence: PatternEvidence[];
  evidence_total: number;
  limitations: { code: string; text: string }[];
  method: PatternMethodRef;
  engine_version: string;
  input_fingerprint: string;
  config_fingerprint: string;
  safety: { not_a_diagnosis: true; causal_claim: false; intended_use: string; interpretation_guidance: string };
  review: { thresholds_reviewed_by_clinician: boolean; thresholds_origin: string };
  /** Engine 0.6.0; absent on findings stored before it. */
  confidence?: PatternConfidence | null;
  /** The standard disclosure to show with the finding when its method is patient-facing; null otherwise. */
  disclosure?: string | null;
  /** True for step_change, day_of_week, time_of_day and month_of_year: show it to a person only when statistically supported.
   * Older servers leave it out: use `shownOnlyIfSupported(finding)`, which falls back to the subtype. */
  shown_only_if_supported?: boolean;
  /** Live runs: true only when the stored finding with the same key is shown under the display rule. */
  shown?: boolean;
  [extra: string]: unknown;
}

/** Subtypes that pick what they name among many tries (the fallback when `shown_only_if_supported` is absent). */
export const SELECTION_SUBTYPES: readonly string[] = ["step_change", "day_of_week", "time_of_day", "month_of_year"];

/** `shown_only_if_supported`, or, on a payload from an older server without it, whether the subtype is a selection subtype. */
export function shownOnlyIfSupported(f: Pick<PatternFinding, "shown_only_if_supported" | "subtype">): boolean {
  return f.shown_only_if_supported ?? SELECTION_SUBTYPES.includes(f.subtype ?? "");
}

export interface PatternNotComputed {
  type: string; variables: Record<string, unknown>[]; window: { start: string; end: string }; reason: string; detail: string;
  /** Engine 0.6.0: only when recording more data can unlock the test. */
  next_step?: PatternNextStep | null;
}

export interface PatternRun {
  patient: string;
  window: { start: string; end: string };
  engine_version: string;
  time_basis: Record<string, unknown>;
  tests_in_run: number;
  family_fingerprint: string | null;
  findings: PatternFinding[];
  not_computed: PatternNotComputed[];
  /** Engine 0.6.0: what would unlock the tests that could not run, fewest entries first. */
  next_steps?: PatternNextStep[];
  omitted: string[];
  interpretation_guidance: string;
}

/** One method of the engine's registry (`GET /v1/patterns/methods`). */
export interface PatternMethodInfo {
  name: string; version: string; finding_type: string; subtype: string | null; maturity: PatternMaturity;
  patient_facing: boolean; notify: boolean; inputs: string[]; minimums: Record<string, unknown>; missing_data: string;
  assumptions: string[]; threshold_source: string; fp_risks: string[]; validation: Record<string, unknown> | null;
  complexity: string; limitations: { code: string; text: string }[]; disclosure: string | null;
  [extra: string]: unknown;
}
export interface PatternMethods {
  engine_version: string; data: PatternMethodInfo[]; maturities: PatternMaturity[]; disclosure: string;
  confidence_rules: Record<string, string>;
}

export interface SeriesResult {
  patient: string;
  window: { start: string; end: string };
  time_basis: Record<string, unknown>;
  series: { code: string; unit: string | null; component_of: string | null; display: string | null; flags: string[];
            quality: Record<string, unknown>; days: { date: string; value: number; n: number; resources: string[] }[] }[];
  omitted: string[];
}

export interface CompareInput {
  code: string;
  unit?: string;
  component_of?: string;
  first: { start: string; end: string };
  second: { start: string; end: string };
}

export interface CompareResult { finding: PatternFinding | null; not_computed: PatternNotComputed | null; omitted: string[]; interpretation_guidance: string }

/** Stored findings (beta): kept up to date in the background for the trusted project the person consented to. */
export type PatternEventType = 'appeared' | 'supported' | 'unsupported' | 'gone';
export interface PatternEvent { event: PatternEventType; at: string; engine_version: string; trigger: 'dirty' | 'reconcile' | 'upgrade' | 'manual' }
export interface StoredPatternFinding extends PatternFinding {
  /** Stable for your project and this patient: it stays the same when new readings arrive (`id` changes with the data). */
  finding_key: string;
  status: 'current' | 'gone';
  first_seen_at: string;
  last_changed_at: string;
  became_supported_at: string | null;
  /** The display rule (`display_rule`): show the finding to the person only when `shown` and `method.patient_facing` are true. */
  shown?: boolean;
  /** Last day of the window of the run that made it shown; null when not shown. */
  shown_since?: string | null;
  events?: PatternEvent[];
}
/** The rule behind `shown`: evaluated at most once per `tick_days`; shown after `show_after_days` supported, hidden after `hide_after_days` unsupported. */
export interface PatternDisplayRule { version: number; tick_days: number; show_after_days: number; hide_after_days: number; text: string }
export interface StoredPatterns {
  patient: string;
  consent: { feature: string; granted_at: string; text_version: string };
  last_run: { finished_at: string; engine_version: string; window: { start: string; end: string }; trigger: string; tests_in_run: number;
              findings_total: number; supported_total: number; not_computed_total: number };
  /** Last day of the analysed window; `stale` once the person's local date has passed it. */
  as_of: string;
  stale: boolean;
  refresh: { queued: boolean; status: 'pending' | 'failed' | null };
  findings: StoredPatternFinding[];
  /** Engine 0.6.0: from the last run, fewest entries first; empty for runs before it. */
  next_steps?: PatternNextStep[];
  display_rule?: PatternDisplayRule;
  interpretation_guidance: string;
}
export interface PatternHistory { patient: string; finding_key: string; status: 'current' | 'gone'; data: PatternEvent[] }
export interface PatternFeedbackInput { response: 'matches' | 'does_not_match' | 'unsure' | 'more_info'; /** At most 500 characters. */ note?: string }
export interface PatternFeedbackResult { id: string; finding_key: string; response: string; note: string | null; created_at: string }
/** `data` of the `patterns.updated` webhook: keys and events only, no clinical content. */
export interface PatternsUpdatedEvent {
  patient: string; engine_version: string; trigger: string; findings_total: number; supported_total: number;
  /** `shown` / `hidden` come from the display rule (notify on `shown` only); the others are statistical transitions. */
  changed: { finding_key: string; event: PatternEventType | 'shown' | 'hidden'; statistically_supported: boolean }[];
  /** The display rule the run used (absent on older servers). */
  display?: { version: number; tick_days: number; show_after_days: number; hide_after_days: number };
}

/** Neurology view (beta): `GET /v1/patients/{id}/neuro-summary`. Every item carries `reference` + `provenance`; nothing interpretive. */
export interface NeuroProvenance { author_type: string | null; source_system: string | null; organization: string | null; last_updated: string | null; version: number | null }
export interface NeuroImagingItem { reference: string; date: string | null; title: string | null; kind: 'DocumentReference' | 'DiagnosticReport'; conclusion: string | null; provenance: NeuroProvenance }
export interface NeuroEpisodeItem { reference: string; date: string | null; kind: string | null; intensity: number | null; period: { start?: string | null; end?: string | null }; triggers: string[]; provenance: NeuroProvenance }
export interface NeuroSymptomItem { reference: string; date: string | null; code: string | null; intensity: number | null; provenance: NeuroProvenance }
export interface NeuroChangeFinding { key: 'symptom_days' | 'notes' | 'episodes'; before: number; after: number; delta: number }
export interface NeuroChanges { anchor: string; previous: string | null; days: number; before: { start: string; end: string }; after: { start: string; end: string }; findings: NeuroChangeFinding[]; limitations: string[] }
export interface NeuroSummary {
  patient: string | null;
  generated_at: string;
  imaging: NeuroImagingItem[];
  episodes: NeuroEpisodeItem[];
  /** `null` when the grant does not include symptom observations. */
  head_symptoms: { window_days: number; notes: number; days_with: number; items: NeuroSymptomItem[] } | null;
  medications: { reference: string; date: string | null; display: string | null; status: string | null; provenance: NeuroProvenance }[];
  /** `null` without a dated head MRI/CT. */
  changes: NeuroChanges | null;
  limitations: string[];
  disclaimer: string;
}

/** Crisis lines for one country (`GET /v1/safety/crisis-resources`). Show `text` to the person at once. */
export interface CrisisResources {
  country: string | null;
  emergency_number: string | null;
  crisis_line: { name: string; number: string } | null;
  directory: { name: string; url: string };
  text: string;
}

// ── research library (HIE Phase 5C, beta) ────────────────────────────────────

export type ResearchStatusValue = 'active' | 'corrected' | 'expression_of_concern' | 'superseded' | 'withdrawn' | 'retracted';

export interface ResearchStatus {
  value: ResearchStatusValue;
  notice_id: string | null;
  notice_source: string | null;
  since: string | null;
  counted_in_assessments: boolean;
  text: { key: string; text: string };
  last_verified_at: string | null;
  last_verification_result: string | null;
}

/** A research record. `abstract` only where the source's licence allows reuse. Detail-only fields are absent in lists. */
export interface ResearchRecord {
  id: string;
  identifiers: { doi: string | null; pmid: string | null; pmcid: string | null; nct_id: string | null; linked: Record<string, string[]> };
  title: string;
  authors: unknown[];
  published: string | null;
  venue: string | null;
  url: string;
  citation: { title: string; venue: string | null; year: number | null; identifier: { type: string; value: string; url: string }; url: string; licence: string };
  licence: string;
  abstract: string | null;
  evidence: { class: string; rank: number; rule: string };
  studied: Record<string, { key: string; text: string }>;
  status: ResearchStatus;
  source: string;
  ingested_at: string | null;
  updated_at: string | null;
  population?: Record<string, unknown> | null;
  sample_size?: number | null;
  sample_size_type?: string | null;
  design_detail?: Record<string, unknown> | null;
  methodology?: Record<string, unknown> | null;
  outcomes?: Record<string, unknown> | null;
  source_limitations?: string | null;
  sources?: Record<string, unknown>[];
  concepts?: { concept_id: string | null; token: string | null; system: string; code: string; method: string }[];
  status_history?: { from: string | null; to: string; notice_id: string | null; notice_source: string | null; rule: string; detected_at: string | null }[];
}

export interface ResearchRecordPage {
  data: ResearchRecord[];
  total: number;
  next_cursor: string | null;
  note: { key: string; text: string };
  evidence_classes: string[];
  statuses: string[];
  /** With `exclude_status`: how many records those statuses left out. */
  left_out_by_status?: number | null;
}

/** Published research on one stored finding (local research library only). */
export interface FindingResearch {
  patient: string;
  finding_key: string;
  method: Record<string, unknown> | null;
  shown: boolean;
  available: boolean;
  reason: { key: string; text: string } | null;
  interpretation: { key: string; text: string };
  research: {
    verdict: 'investigated' | 'not_adequately_investigated';
    best_level: { class: string; rank: number } | null;
    counts: Record<string, unknown>;
    missing: { key: string; text: string }[];
    summary: { key: string; text: string; cites: string[] };
    records: Record<string, unknown>[];
    excluded: Record<string, unknown>[];
    curation: { direction: 'supports' | 'contradicts' | 'mixed' | null; supports: number; contradicts: number; statements: Record<string, unknown>[]; ignored: Record<string, unknown>[]; note: { key: string; text: string } | null };
    notes: { key: string; text: string }[];
    query: Record<string, unknown>;
    store_fingerprint: string;
    assessment_version: string;
    wording_version: string;
  } | null;
}
