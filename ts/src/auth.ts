/** How the client authenticates. */
export interface Auth {
  /** The current bearer token (refreshing first when needed). */
  token(): Promise<string>;
  /** After a 401: renew once and return true to let the call retry. */
  recover?(): Promise<boolean>;
}

export interface OAuthTokens {
  access_token: string;
  refresh_token?: string;
  expires_in: number;
  scope?: string;
  /** The patient id your application sees for this person (pairwise). */
  patient?: string;
  grant_id?: string;
  /** Set by the SDK: epoch milliseconds when the tokens were obtained. */
  obtained_at?: number;
}

/** A project key (`sk_test_…` / `sk_live_…`). Server-side only. */
export function apiKey(key: string): Auth {
  return { token: async () => key };
}

/** Any static bearer token. */
export function bearer(value: string): Auth {
  return { token: async () => value };
}

export interface OAuthAuthOptions {
  tokens: OAuthTokens;
  /** Exchanges a refresh token for new tokens (typically `flow.refresh`). */
  onRefresh?: (refreshToken: string) => Promise<OAuthTokens>;
  /** Called whenever tokens change, so you can persist them. */
  onTokens?: (tokens: OAuthTokens) => void;
}

/** OAuth tokens with automatic refresh. */
export class OAuthAuth implements Auth {
  private tokens: OAuthTokens;
  private inflight?: Promise<void>;
  constructor(private readonly opts: OAuthAuthOptions) {
    this.tokens = { obtained_at: Date.now(), ...opts.tokens };
  }

  get current(): OAuthTokens { return this.tokens; }

  private expiringSoon(): boolean {
    const at = this.tokens.obtained_at ?? Date.now();
    return Date.now() > at + (this.tokens.expires_in - 60) * 1000;
  }

  async token(): Promise<string> {
    if (this.expiringSoon() && this.tokens.refresh_token && this.opts.onRefresh) await this.refresh();
    return this.tokens.access_token;
  }

  async recover(): Promise<boolean> {
    if (!this.tokens.refresh_token || !this.opts.onRefresh) return false;
    try { await this.refresh(); return true; } catch { return false; }
  }

  private refresh(): Promise<void> {
    this.inflight ??= this.opts.onRefresh!(this.tokens.refresh_token!).then((t) => {
      this.tokens = { ...t, refresh_token: t.refresh_token ?? this.tokens.refresh_token, obtained_at: Date.now() };
      this.opts.onTokens?.(this.tokens);
    }).finally(() => { this.inflight = undefined; });
    return this.inflight;
  }
}
