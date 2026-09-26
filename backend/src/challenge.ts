import { base64Decode, concat } from "./appattest";

/**
 * Stateless one-time challenges for App Attest. A challenge is
 * `version ‖ expiry ‖ random nonce ‖ HMAC`, so the server can check it
 * without storing anything; single use is enforced separately by keying a
 * limit-1 rate limiter on the nonce.
 */

export const CHALLENGE_TTL_SECONDS = 60;
const VERSION = 1;

async function hmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
    "verify",
  ]);
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function issueChallenge(secret: string, now = Date.now()): Promise<string> {
  const body = new Uint8Array(21);
  body[0] = VERSION;
  new DataView(body.buffer).setUint32(1, Math.floor(now / 1000) + CHALLENGE_TTL_SECONDS);
  crypto.getRandomValues(body.subarray(5));
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", await hmacKey(secret), body));
  return base64Url(concat(body, mac));
}

/** Returns the nonce (hex) for single-use tracking, or null if the challenge isn't ours or has expired. */
export async function checkChallenge(secret: string, challenge: string, now = Date.now()): Promise<string | null> {
  if (challenge.length > 100) return null;
  let bytes: Uint8Array;
  try {
    bytes = base64Decode(challenge);
  } catch {
    return null;
  }
  if (bytes.length !== 53 || bytes[0] !== VERSION) return null;
  const body = bytes.subarray(0, 21);
  const valid = await crypto.subtle.verify("HMAC", await hmacKey(secret), bytes.subarray(21), body);
  if (!valid) return null;
  const expires = new DataView(body.buffer, body.byteOffset).getUint32(1);
  if (Math.floor(now / 1000) > expires) return null;
  return [...body.subarray(5)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
