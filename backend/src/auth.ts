import { base64Decode, sha256, utf8 } from "./appattest";

/**
 * Accounts: email + password (PBKDF2) and Sign in with Apple (identity
 * token verified against Apple's published keys). Sessions are random
 * bearer tokens; only their SHA-256 is stored.
 */

export class AuthError extends Error {}

// MARK: - Passwords

/** Cloudflare Workers cap PBKDF2 at 100,000 iterations. */
const PBKDF2_ITERATIONS = 100_000;

function hex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function unhex(text: string): Uint8Array {
  const out = new Uint8Array(text.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(text.slice(i * 2, i * 2 + 2), 16);
  return out;
}

async function pbkdf2(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", utf8(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, 256);
  return new Uint8Array(bits);
}

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, PBKDF2_ITERATIONS);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${hex(salt)}$${hex(hash)}`;
}

export async function checkPassword(password: string, stored: string): Promise<boolean> {
  const [scheme, iterations, salt, expected] = stored.split("$");
  if (scheme !== "pbkdf2" || !iterations || !salt || !expected) return false;
  const actual = await pbkdf2(password, unhex(salt), Number(iterations));
  const want = unhex(expected);
  if (actual.length !== want.length) return false;
  let diff = 0;
  for (let i = 0; i < actual.length; i++) diff |= actual[i] ^ want[i];
  return diff === 0;
}

// MARK: - Sessions

export function newSessionToken(): string {
  return hex(crypto.getRandomValues(new Uint8Array(32)));
}

export async function hashToken(token: string): Promise<string> {
  return hex(await sha256(utf8(token)));
}

// MARK: - Sign in with Apple

export interface AppleIdentity {
  sub: string;
  email?: string;
}

interface Jwk extends JsonWebKey {
  kid: string;
}

export type JwksFetcher = () => Promise<Jwk[]>;

let cachedKeys: { keys: Jwk[]; fetchedAt: number } | null = null;

export const fetchAppleKeys: JwksFetcher = async () => {
  if (cachedKeys && Date.now() - cachedKeys.fetchedAt < 60 * 60 * 1000) return cachedKeys.keys;
  const response = await fetch("https://appleid.apple.com/auth/keys");
  if (!response.ok) throw new AuthError("Couldn't reach Apple to check the sign-in.");
  const { keys } = (await response.json()) as { keys: Jwk[] };
  cachedKeys = { keys, fetchedAt: Date.now() };
  return keys;
};

function decodeJsonPart(part: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(base64Decode(part))) as Record<string, unknown>;
}

/**
 * Verifies an identity token from `ASAuthorizationAppleIDCredential`:
 * RS256 signature by one of Apple's current keys, issuer, audience (this
 * app's bundle ID) and expiry.
 */
export async function verifyAppleIdentityToken(
  token: string,
  bundleId: string,
  fetchKeys: JwksFetcher = fetchAppleKeys,
  now = Date.now(),
): Promise<AppleIdentity> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new AuthError("Malformed Apple token.");
  const [headerPart, payloadPart, signaturePart] = parts;

  let header: Record<string, unknown>;
  let payload: Record<string, unknown>;
  try {
    header = decodeJsonPart(headerPart);
    payload = decodeJsonPart(payloadPart);
  } catch {
    throw new AuthError("Malformed Apple token.");
  }
  if (header.alg !== "RS256" || typeof header.kid !== "string") throw new AuthError("Unexpected Apple token.");

  const jwk = (await fetchKeys()).find((key) => key.kid === header.kid);
  if (!jwk) throw new AuthError("Apple token signed by an unknown key.");
  const key = await crypto.subtle.importKey(
    "jwk",
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64Decode(signaturePart),
    utf8(`${headerPart}.${payloadPart}`),
  );
  if (!valid) throw new AuthError("Apple token signature is invalid.");

  if (payload.iss !== "https://appleid.apple.com") throw new AuthError("Apple token has the wrong issuer.");
  const audience = payload.aud;
  const audiences = Array.isArray(audience) ? audience : [audience];
  if (!audiences.includes(bundleId)) throw new AuthError("Apple token is for a different app.");
  if (typeof payload.exp !== "number" || payload.exp * 1000 < now) throw new AuthError("Apple token has expired.");
  if (typeof payload.sub !== "string" || !payload.sub) throw new AuthError("Apple token has no user.");

  return { sub: payload.sub, email: typeof payload.email === "string" ? payload.email : undefined };
}
