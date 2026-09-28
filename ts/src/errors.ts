/** Every server error: platform error type, message, field when known, request id to quote. */
export class AnpherosError extends Error {
  readonly status: number;
  readonly type: string;
  readonly field?: string;
  readonly requestId?: string;
  readonly body?: unknown;

  constructor(status: number, type: string, message: string, opts: { field?: string; requestId?: string; body?: unknown } = {}) {
    super(message);
    this.name = 'AnpherosError';
    this.status = status;
    this.type = type;
    this.field = opts.field;
    this.requestId = opts.requestId;
    this.body = opts.body;
  }

  get isUnauthorized(): boolean { return this.status === 401; }
  get isForbidden(): boolean { return this.status === 403; }
  get isNotFound(): boolean { return this.status === 404; }
  get isRateLimited(): boolean { return this.status === 429; }

  /** Builds from `/v1` (`{error:{…}}`), FHIR `OperationOutcome` or OAuth error bodies. */
  static fromResponse(status: number, body: unknown, requestId?: string): AnpherosError {
    let type = 'error';
    let message = `HTTP ${status}`;
    let field: string | undefined;
    if (body && typeof body === 'object') {
      const b = body as Record<string, unknown>;
      const err = b.error;
      if (err && typeof err === 'object') {
        const e = err as Record<string, unknown>;
        type = String(e.type ?? type);
        message = String(e.message ?? message);
        field = e.field ? String(e.field) : undefined;
      } else if (b.resourceType === 'OperationOutcome' && Array.isArray(b.issue) && b.issue.length) {
        const first = b.issue[0] as Record<string, unknown>;
        type = String(first.code ?? type);
        message = String(first.diagnostics ?? message);
        const expr = first.expression;
        if (Array.isArray(expr) && expr.length) field = String(expr[0]);
      } else if (typeof b.error === 'string') {
        type = b.error;
        message = String(b.error_description ?? message);
      }
    }
    return new AnpherosError(status, type, message, { field, requestId, body });
  }
}
