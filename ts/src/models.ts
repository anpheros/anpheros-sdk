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
  'ping',
] as const;
export type WebhookEventType = typeof WEBHOOK_EVENT_TYPES[number];
