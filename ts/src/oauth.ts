import { AnpherosError } from './errors.js';
import type { OAuthTokens } from './auth.js';

export interface Pkce { verifier: string; challenge: string }

const b64url = (bytes: ArrayBuffer | Uint8Array): string =>
  btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/** PKCE verifier/challenge pair (Web Crypto; works in browsers, Node 18+, Deno, Bun). */
export async function generatePkce(): Promise<Pkce> {
  const raw = new Uint8Array(48);
  crypto.getRandomValues(raw);
  const verifier = b64url(raw);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return { verifier, challenge: b64url(digest) };
}

export interface OAuthFlowOptions {
  baseUrl: string;
  clientId: string;
  redirectUri: string;
  /** Confidential (server-side) clients only. Never ship it to a browser. */
  clientSecret?: string;
  fetch?: typeof fetch;
}

/** The consent flow (authorization code + PKCE, SMART on FHIR scopes). */
export class OAuthFlow {
  private readonly f: typeof fetch;
  constructor(private readonly o: OAuthFlowOptions) { this.f = o.fetch ?? fetch; }

  authorizeUrl(p: { scopes: string[]; state: string; pkce: Pkce; purpose?: string; patient?: string; lang?: string }): string {
    const q = new URLSearchParams({
      response_type: 'code', client_id: this.o.clientId, redirect_uri: this.o.redirectUri, scope: p.scopes.join(' '),
      state: p.state, code_challenge: p.pkce.challenge, code_challenge_method: 'S256', lang: p.lang ?? 'en',
    });
    if (p.purpose) q.set('purpose', p.purpose);
    if (p.patient) q.set('patient', p.patient);
    return `${this.o.baseUrl}/oauth/authorize?${q}`;
  }

  exchange(code: string, pkce: Pkce): Promise<OAuthTokens> {
    return this.token({ grant_type: 'authorization_code', code, code_verifier: pkce.verifier, redirect_uri: this.o.redirectUri });
  }

  refresh = (refreshToken: string): Promise<OAuthTokens> => this.token({ grant_type: 'refresh_token', refresh_token: refreshToken });

  /** Server-to-server access as the project (confidential clients). */
  clientCredentials(scopes: string[] = ['read', 'write']): Promise<OAuthTokens> {
    return this.token({ grant_type: 'client_credentials', scope: scopes.join(' ') });
  }

  /** First-party apps whose users sign in with Anpheros identity (trusted clients only). */
  exchangeIdentity(firebaseIdToken: string, scopes: string[] = ['patient/*.cruds', 'offline_access'], patient?: string): Promise<OAuthTokens> {
    return this.token({ grant_type: 'urn:anpheros:params:oauth:grant-type:identity', subject_token: firebaseIdToken, scope: scopes.join(' '), ...(patient ? { patient } : {}) });
  }

  async revoke(token: string): Promise<void> {
    const body = new URLSearchParams({ token, client_id: this.o.clientId });
    if (this.o.clientSecret) body.set('client_secret', this.o.clientSecret);
    await this.f(`${this.o.baseUrl}/oauth/revoke`, { method: 'POST', body });
  }

  private async token(form: Record<string, string>): Promise<OAuthTokens> {
    const body = new URLSearchParams({ ...form, client_id: this.o.clientId });
    if (this.o.clientSecret) body.set('client_secret', this.o.clientSecret);
    const res = await this.f(`${this.o.baseUrl}/oauth/token`, { method: 'POST', body });
    const json = (await res.json().catch(() => null)) as unknown;
    if (!res.ok) throw AnpherosError.fromResponse(res.status, json, res.headers.get('anpheros-request-id') ?? undefined);
    return { obtained_at: Date.now(), ...(json as OAuthTokens) };
  }
}
