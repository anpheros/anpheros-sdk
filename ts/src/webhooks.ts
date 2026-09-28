/**
 * Verifies the `Anpheros-Signature` header of a webhook delivery
 * (`t=<unix>,v1=<hex HMAC-SHA256 over "<t>.<raw body>">`).
 *
 * Works in Node ≥ 18 and modern runtimes through WebCrypto. Pass the raw request
 * body (string or bytes), not a re-serialised JSON object.
 */
export async function verifyWebhookSignature(opts: {
  secret: string; header: string | null | undefined; body: string | Uint8Array; toleranceSeconds?: number; now?: number;
}): Promise<boolean> {
  const { secret, header, body } = opts;
  if (!header) return false;
  const parts: Record<string, string> = {};
  for (const p of header.split(',')) {
    const i = p.indexOf('=');
    if (i > 0) parts[p.slice(0, i).trim()] = p.slice(i + 1).trim();
  }
  const ts = Number.parseInt(parts.t ?? '', 10);
  const given = parts.v1;
  if (!Number.isFinite(ts) || !given) return false;
  const now = opts.now ?? Math.floor(Date.now() / 1000);
  if (Math.abs(now - ts) > (opts.toleranceSeconds ?? 300)) return false;
  const enc = new TextEncoder();
  const bodyBytes = typeof body === 'string' ? enc.encode(body) : body;
  const prefix = enc.encode(`${ts}.`);
  const data = new Uint8Array(prefix.length + bodyBytes.length);
  data.set(prefix, 0);
  data.set(bodyBytes, prefix.length);
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, data));
  const expected = Array.from(mac, (b) => b.toString(16).padStart(2, '0')).join('');
  if (expected.length !== given.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}
