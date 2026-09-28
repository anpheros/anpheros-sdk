import type { Auth } from './auth.js';
import { AnpherosError } from './errors.js';
import type {
  AuthorType, Bundle, Concept, Condition, ConditionInput, ContextRequest, ContextResult, Document, DocumentInput, FhirResource,
  GrantInfo, Medication, MedicationInput, Observation, ObservationInput, Page, Patient, PatientInput, ProvenanceEntry, TimelineItem,
  MyPatient, AccessEntry, WebhookEndpoint, WebhookDelivery, LabImportResult,
} from './models.js';

export interface AnpherosOptions {
  auth: Auth;
  baseUrl?: string;
  fetch?: typeof fetch;
  /** Retries on 429/502/503/504 and network errors (default 2). */
  maxRetries?: number;
}

interface RequestOptions {
  query?: Record<string, string | number | undefined>;
  json?: unknown;
  body?: BodyInit;
  headers?: Record<string, string>;
  idempotent?: boolean;
  accept?: string;
}

export interface AnpherosResponse<T = unknown> { status: number; body: T; headers: Headers; raw: Response }

const enc = encodeURIComponent;
const authorHeaders = (o: { author_type?: AuthorType; source_system?: string; origin_id?: string } = {}): Record<string, string> => ({
  ...(o.author_type ? { 'X-Anpheros-Author-Type': o.author_type } : {}),
  ...(o.source_system ? { 'X-Anpheros-Source-System': o.source_system } : {}),
  ...(o.origin_id ? { 'X-Anpheros-Origin-Id': o.origin_id } : {}),
});

/** Entry point. One instance per credential. */
export class Anpheros {
  readonly baseUrl: string;
  readonly auth: Auth;
  private readonly f: typeof fetch;
  private readonly maxRetries: number;
  /** Request id of the last response, to quote in support requests. */
  lastRequestId?: string;

  constructor(o: AnpherosOptions) {
    this.auth = o.auth;
    this.baseUrl = (o.baseUrl ?? 'https://platform.anpheros.com').replace(/\/$/, '');
    this.f = o.fetch ?? fetch;
    this.maxRetries = o.maxRetries ?? 2;
  }

  /** Low-level call: auth, retries with backoff, one token refresh on 401, typed errors. */
  async request<T = unknown>(method: string, path: string, o: RequestOptions = {}): Promise<AnpherosResponse<T>> {
    const url = new URL(this.baseUrl + path);
    for (const [k, v] of Object.entries(o.query ?? {})) if (v !== undefined && v !== '') url.searchParams.set(k, String(v));
    const idem = o.idempotent ? crypto.randomUUID() : undefined;
    let recovered = false;
    for (let attempt = 0; ; attempt++) {
      const headers: Record<string, string> = {
        Authorization: `Bearer ${await this.auth.token()}`, Accept: o.accept ?? 'application/json', 'User-Agent': '@anpheros/sdk 0.1.0', ...(o.headers ?? {}),
      };
      if (idem) headers['Idempotency-Key'] = idem;
      let body: BodyInit | undefined = o.body;
      if (o.json !== undefined) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(o.json); }
      let res: Response;
      try {
        res = await this.f(url, { method, headers, body });
      } catch (e) {
        if (attempt < this.maxRetries) { await backoff(attempt); continue; }
        throw new AnpherosError(0, 'network', (e as Error).message);
      }
      this.lastRequestId = res.headers.get('anpheros-request-id') ?? undefined;
      if (res.status === 401 && !recovered && this.auth.recover && (await this.auth.recover())) { recovered = true; continue; }
      if ((res.status === 429 || res.status >= 502) && attempt < this.maxRetries) { await backoff(attempt, res.headers.get('retry-after')); continue; }
      const ct = res.headers.get('content-type') ?? '';
      const parsed = ct.includes('json') ? await res.json().catch(() => null) : null;
      if (res.status >= 400) throw AnpherosError.fromResponse(res.status, parsed, this.lastRequestId);
      return { status: res.status, body: parsed as T, headers: res.headers, raw: res };
    }
  }

  private async get<T>(path: string, query?: RequestOptions['query']): Promise<T> { return (await this.request<T>('GET', path, { query })).body; }
  private async post<T>(path: string, json: unknown, headers?: Record<string, string>): Promise<T> {
    return (await this.request<T>('POST', path, { json, headers, idempotent: true })).body;
  }

  readonly patients = {
    list: (q: { limit?: number; cursor?: string } = {}) => this.get<Page<Patient>>('/v1/patients', q),
    listAll: async function* (this: Anpheros, pageSize = 200): AsyncGenerator<Patient> {
      let cursor: string | undefined;
      do {
        const page = await this.patients.list({ limit: pageSize, cursor });
        yield* page.data;
        cursor = page.next_cursor ?? undefined;
      } while (cursor);
    }.bind(this),
    create: (input: PatientInput, o: { author_type?: AuthorType } = {}) => this.post<Patient>('/v1/patients', input, authorHeaders(o)),
    get: (id: string) => this.get<Patient>(`/v1/patients/${enc(id)}`),
    update: async (id: string, input: PatientInput) => (await this.request<Patient>('PUT', `/v1/patients/${enc(id)}`, { json: input })).body,
  };

  readonly observations = {
    list: (patientId: string, q: { category?: string; code?: string; from?: string; to?: string; limit?: number; cursor?: string } = {}) =>
      this.get<Page<Observation>>(`/v1/patients/${enc(patientId)}/observations`, q),
    create: (patientId: string, input: ObservationInput, o: { source_system?: string; origin_id?: string } = {}) =>
      this.post<Observation>(`/v1/patients/${enc(patientId)}/observations`, input, authorHeaders(o)),
    get: (id: string) => this.get<Observation>(`/v1/observations/${enc(id)}`),
    delete: async (id: string) => { await this.request('DELETE', `/v1/observations/${enc(id)}`); },
  };

  readonly conditions = {
    list: (patientId: string, q: { clinical_status?: string; limit?: number; cursor?: string } = {}) =>
      this.get<Page<Condition>>(`/v1/patients/${enc(patientId)}/conditions`, q),
    create: (patientId: string, input: ConditionInput, o: { source_system?: string; origin_id?: string } = {}) =>
      this.post<Condition>(`/v1/patients/${enc(patientId)}/conditions`, input, authorHeaders(o)),
    get: (id: string) => this.get<Condition>(`/v1/conditions/${enc(id)}`),
    delete: async (id: string) => { await this.request('DELETE', `/v1/conditions/${enc(id)}`); },
  };

  readonly medications = {
    list: (patientId: string, q: { status?: string; limit?: number; cursor?: string } = {}) =>
      this.get<Page<Medication>>(`/v1/patients/${enc(patientId)}/medications`, q),
    create: (patientId: string, input: MedicationInput, o: { source_system?: string; origin_id?: string } = {}) =>
      this.post<Medication>(`/v1/patients/${enc(patientId)}/medications`, input, authorHeaders(o)),
    get: (id: string) => this.get<Medication>(`/v1/medications/${enc(id)}`),
    delete: async (id: string) => { await this.request('DELETE', `/v1/medications/${enc(id)}`); },
  };

  readonly documents = {
    list: (patientId: string, q: { kind?: string; limit?: number; cursor?: string } = {}) => this.get<Page<Document>>(`/v1/patients/${enc(patientId)}/documents`, q),
    create: (patientId: string, input: DocumentInput, o: { source_system?: string } = {}) =>
      this.post<Document>(`/v1/patients/${enc(patientId)}/documents`, input, authorHeaders(o)),
    /** Uploads through the platform and finalizes (sha256, size, immutable). */
    uploadContent: async (documentId: string, bytes: BodyInit, contentType: string) =>
      (await this.request<Document>('PUT', `/v1/documents/${enc(documentId)}/content`, { body: bytes, headers: { 'Content-Type': contentType } })).body,
    upload: async (patientId: string, input: DocumentInput, bytes: BodyInit) => {
      const doc = await this.documents.create(patientId, input);
      return this.documents.uploadContent(doc.id, bytes, input.content_type);
    },
    finalize: (documentId: string) => this.post<Document>(`/v1/documents/${enc(documentId)}/finalize`, undefined),
    get: (documentId: string) => this.get<Document>(`/v1/documents/${enc(documentId)}`),
    /** The original bytes (follows the signed-URL redirect when storage is remote). */
    download: async (documentId: string) => (await this.request('GET', `/v1/documents/${enc(documentId)}/content`, { accept: '*/*' })).raw.arrayBuffer(),
  };

  readonly timeline = {
    list: (patientId: string, q: { from?: string; to?: string; types?: string; limit?: number; cursor?: string } = {}) =>
      this.get<Page<TimelineItem>>(`/v1/patients/${enc(patientId)}/timeline`, q),
  };

  readonly provenance = {
    /** `fhirRef` like `Observation/abc`. */
    of: async (patientId: string, fhirRef: string) => {
      const [type, id] = fhirRef.split('/');
      return (await this.get<{ data: ProvenanceEntry[] }>(`/v1/patients/${enc(patientId)}/provenance/${enc(type)}/${enc(id)}`)).data;
    },
  };

  readonly context = {
    build: (req: ContextRequest) => this.post<ContextResult>('/v1/context', req),
  };

  readonly grants = {
    of: async (patientId: string) => (await this.get<{ data: GrantInfo[] }>(`/v1/patients/${enc(patientId)}/grants`)).data,
  };

  /** Lab connector: a whole report becomes laboratory Observations; re-sending skips rows already imported. */
  readonly labs = {
    importCsv: async (patientId: string, csv: string, o: { sourceSystem?: string; defaultDate?: string } = {}) =>
      (await this.request<LabImportResult>('POST', `/v1/patients/${enc(patientId)}/labs/import`,
        { body: csv, idempotent: true, query: { date: o.defaultDate }, headers: { 'Content-Type': 'text/csv', ...(o.sourceSystem ? { 'X-Anpheros-Source-System': o.sourceSystem } : {}) } })).body,
    importHl7: async (patientId: string, message: string, o: { sourceSystem?: string } = {}) =>
      (await this.request<LabImportResult>('POST', `/v1/patients/${enc(patientId)}/labs/import`,
        { body: message, idempotent: true, headers: { 'Content-Type': 'x-application/hl7-v2+er7', ...(o.sourceSystem ? { 'X-Anpheros-Source-System': o.sourceSystem } : {}) } })).body,
    importItems: async (patientId: string, items: Record<string, unknown>[], o: { defaultDate?: string; origin?: string; sourceSystem?: string } = {}) =>
      (await this.request<LabImportResult>('POST', `/v1/patients/${enc(patientId)}/labs/import`,
        { json: { items, ...(o.defaultDate ? { date: o.defaultDate } : {}), ...(o.origin ? { origin: o.origin } : {}) }, idempotent: true, headers: o.sourceSystem ? { 'X-Anpheros-Source-System': o.sourceSystem } : undefined })).body,
  };

  /** Webhooks: signed event deliveries to your server (`/v1/webhooks`). */
  readonly webhooks = {
    /** Registers an endpoint. The returned `secret` is shown only now; keep it to verify signatures. */
    create: (url: string, o: { events?: string[]; description?: string } = {}) =>
      this.post<WebhookEndpoint>('/v1/webhooks', { url, events: o.events ?? ['*'], ...(o.description ? { description: o.description } : {}) }),
    list: async () => (await this.get<{ data: WebhookEndpoint[] }>('/v1/webhooks')).data,
    eventTypes: async () => (await this.get<{ data: string[] }>('/v1/webhooks/event-types')).data,
    get: (id: string) => this.get<WebhookEndpoint>(`/v1/webhooks/${enc(id)}`),
    update: async (id: string, patch: { url?: string; events?: string[]; description?: string; active?: boolean }) =>
      (await this.request<WebhookEndpoint>('PATCH', `/v1/webhooks/${enc(id)}`, { json: patch })).body,
    delete: async (id: string) => { await this.request('DELETE', `/v1/webhooks/${enc(id)}`); },
    /** New secret (shown once); the old one stops working immediately. */
    rotateSecret: (id: string) => this.post<WebhookEndpoint>(`/v1/webhooks/${enc(id)}/rotate`, {}),
    /** Sends a `ping` event now. */
    ping: (id: string) => this.post<WebhookDelivery>(`/v1/webhooks/${enc(id)}/ping`, {}),
    /** Delivery log, newest first. */
    deliveries: async (id: string, o: { status?: WebhookDelivery['status']; limit?: number } = {}) =>
      (await this.get<{ data: WebhookDelivery[] }>(`/v1/webhooks/${enc(id)}/deliveries`, { status: o.status, limit: o.limit ?? 50 })).data,
    redeliver: (id: string, deliveryId: string) => this.post<WebhookDelivery>(`/v1/webhooks/${enc(id)}/deliveries/${enc(deliveryId)}/redeliver`, {}),
    /** Dead-letter: re-queue every exhausted delivery of an endpoint (after you fixed it). */
    redeliverExhausted: (id: string) => this.post<{ requeued: number }>(`/v1/webhooks/${enc(id)}/deliveries/redeliver-exhausted`, {}),
  };

  /**
   * The person's own view: their records, who has access, what each app did.
   * Authenticate with the person's Firebase ID token (`bearer(token)`), not an API key.
   */
  readonly me = {
    patients: async (environment: 'production' | 'sandbox' = 'production') =>
      (await this.get<{ data: MyPatient[] }>('/me/patients', { environment })).data,
    grants: async (patientId: string, o: { lang?: string; environment?: 'production' | 'sandbox' } = {}) =>
      (await this.get<{ data: GrantInfo[] }>(`/me/patients/${enc(patientId)}/grants`, { lang: o.lang ?? 'en', environment: o.environment ?? 'production' })).data,
    revoke: async (patientId: string, grantId: string, o: { reason?: string; environment?: 'production' | 'sandbox' } = {}) =>
      (await this.request<GrantInfo>('POST', `/me/patients/${enc(patientId)}/grants/${enc(grantId)}/revoke`,
        { json: o.reason ? { reason: o.reason } : {}, query: { environment: o.environment ?? 'production' } })).body,
    accessLog: async (patientId: string, grantId: string, o: { limit?: number; environment?: 'production' | 'sandbox' } = {}) =>
      (await this.get<{ data: AccessEntry[] }>(`/me/patients/${enc(patientId)}/grants/${enc(grantId)}/access-log`,
        { limit: o.limit ?? 100, environment: o.environment ?? 'production' })).data,
  };

  readonly terminology = {
    search: async (system: 'loinc' | 'atc', q: string, limit = 20) => (await this.get<{ data: Concept[] }>(`/v1/terminology/${system}`, { q, limit })).data,
    lookup: (system: 'loinc' | 'atc', code: string) => this.get<Concept>(`/v1/terminology/${system}/${enc(code)}`),
  };

  /** Raw FHIR R4 access at `/fhir/R4`. */
  readonly fhir = {
    metadata: () => this.get<FhirResource>('/fhir/R4/metadata'),
    read: <T extends FhirResource = FhirResource>(type: string, id: string) => this.get<T>(`/fhir/R4/${enc(type)}/${enc(id)}`),
    search: (type: string, params: Record<string, string> = {}) => this.get<Bundle>(`/fhir/R4/${enc(type)}`, params),
    create: <T extends FhirResource>(resource: T, o: { author_type?: AuthorType; source_system?: string; origin_id?: string } = {}) =>
      this.post<T>(`/fhir/R4/${enc(resource.resourceType)}`, resource, authorHeaders(o)),
    update: async <T extends FhirResource>(resource: T, o: { ifMatch?: string; author_type?: AuthorType } = {}) =>
      (await this.request<T>('PUT', `/fhir/R4/${enc(resource.resourceType)}/${enc(resource.id!)}`, {
        json: resource, headers: { ...(o.ifMatch ? { 'If-Match': o.ifMatch } : {}), ...authorHeaders(o) },
      })).body,
    delete: async (type: string, id: string) => { await this.request('DELETE', `/fhir/R4/${enc(type)}/${enc(id)}`); },
    history: (type: string, id: string) => this.get<Bundle>(`/fhir/R4/${enc(type)}/${enc(id)}/_history`),
    vread: <T extends FhirResource = FhirResource>(type: string, id: string, version: number) => this.get<T>(`/fhir/R4/${enc(type)}/${enc(id)}/_history/${version}`),
    transaction: (bundle: Bundle, o: { author_type?: AuthorType } = {}) => this.post<Bundle>('/fhir/R4', bundle, authorHeaders(o)),
    everything: (patientId: string, q: { _count?: number; _offset?: number; _type?: string; _since?: string } = {}) =>
      this.get<Bundle>(`/fhir/R4/Patient/${enc(patientId)}/$everything`, q),
    summary: (patientId: string) => this.get<Bundle>(`/fhir/R4/Patient/${enc(patientId)}/$summary`),
    validate: async (resource: FhirResource, profile?: string) =>
      (await this.request<FhirResource>('POST', `/fhir/R4/${enc(resource.resourceType)}/$validate`, { json: resource, query: { profile } })).body,
  };
}

function backoff(attempt: number, retryAfter?: string | null): Promise<void> {
  const ra = retryAfter ? Number(retryAfter) : NaN;
  const ms = Number.isFinite(ra) ? ra * 1000 : 300 * 2 ** attempt + Math.random() * 200;
  return new Promise((r) => setTimeout(r, ms));
}
