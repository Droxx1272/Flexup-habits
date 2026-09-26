import Anthropic from "@anthropic-ai/sdk";
import { AppAttestError, base64Decode, base64Encode, concat, utf8, verifyAssertion, verifyAttestation } from "./appattest";
import { CHALLENGE_TTL_SECONDS, checkChallenge, issueChallenge } from "./challenge";
import { communityRoutes, type CommunityEnv, type Params } from "./community";
import { EstimateMalformedError, EstimateRefusedError, estimateMeal, type ImageMediaType } from "./estimate";
import { HttpError, fail, json, parseJson, readBody as readLimitedBody } from "./http";
import { socialRoutes } from "./social";

/**
 * FlexUp API. Turns a meal photo into an itemised estimate without the
 * Anthropic key ever leaving the server — and, with App Attest, only for
 * genuine copies of the app running on real Apple devices.
 *
 *   POST /v1/attest/challenge  → { challenge, expires_in }
 *   POST /v1/attest/register   { key_id, attestation, challenge }        (once per install)
 *   POST /v1/estimate          { image, media_type, cuisine_context?, correction? }
 *        headers X-FlexUp-Key-Id, X-FlexUp-Challenge, X-FlexUp-Assertion
 *        (assertion signs  challenge ‖ exact request body)
 *   GET  /health
 *
 * Community (accounts, friends, feed, cheers, nudges) lives in
 * `community.ts` and authenticates with a bearer session token.
 *
 * Errors are always `{ "error": { "type", "message" } }`. The app reacts to
 * `attestation_required` (re-register, retry once) and `challenge_expired`
 * (fetch a new challenge, retry once); every message is shown as-is.
 */

export interface Env extends CommunityEnv {
  ANTHROPIC_API_KEY: string;
  /** Signs challenges. `openssl rand -hex 32 | npx wrangler secret put CHALLENGE_SECRET` */
  CHALLENGE_SECRET: string;
  /** Optional. Lets simulator/debug builds through when they send it as X-FlexUp-Dev-Token. */
  DEV_BYPASS_TOKEN?: string;
  APPLE_TEAM_ID: string;
  APPLE_BUNDLE_ID: string;
  /** "required" (default) or "off". */
  ATTEST_MODE?: string;
  /** "true" (default) accepts development-environment attestations too. */
  ALLOW_DEVELOPMENT_ATTESTATION?: string;
  ATTEST_KEYS: KVNamespace;
  INSTALL_LIMITER: RateLimit;
  CHALLENGE_ONCE: RateLimit;
}

interface StoredKey {
  spki: string;
  environment: string;
  created: string;
}

const MEDIA_TYPES: readonly ImageMediaType[] = ["image/jpeg", "image/png", "image/webp"];
/** ~2.2 MB of image. The app sends a 1024 px JPEG, typically 150–300 KB. */
const MAX_IMAGE_BASE64 = 3_000_000;
const MAX_BODY_BYTES = MAX_IMAGE_BASE64 + 10_000;
const MAX_TEXT = 500;
const KEY_ID = /^[A-Za-z0-9+/]{43}=$/;

function cleanText(value: unknown): string {
  return typeof value === "string" ? value.trim().slice(0, MAX_TEXT) : "";
}

function attestationOn(env: Env): boolean {
  return (env.ATTEST_MODE ?? "required") !== "off";
}

function appId(env: Env): string {
  if (!env.APPLE_TEAM_ID || !env.APPLE_BUNDLE_ID) {
    throw new HttpError(500, "not_configured", "The FlexUp server isn't set up yet (missing Apple Team ID).");
  }
  return `${env.APPLE_TEAM_ID}.${env.APPLE_BUNDLE_ID}`;
}

function challengeSecret(env: Env): string {
  if (!env.CHALLENGE_SECRET) {
    throw new HttpError(500, "not_configured", "The FlexUp server isn't set up yet (missing challenge secret).");
  }
  return env.CHALLENGE_SECRET;
}

async function limitIP(request: Request, env: Env): Promise<void> {
  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  const { success } = await env.IP_LIMITER.limit({ key: ip });
  if (!success) throw new HttpError(429, "rate_limited", "That's a lot of estimates in a row — give it a minute.");
}

/** Valid, unexpired, and never seen before. */
async function consumeChallenge(env: Env, challenge: string): Promise<void> {
  const nonce = await checkChallenge(challengeSecret(env), challenge);
  if (!nonce) throw new HttpError(401, "challenge_expired", "That request took too long — try again.");
  const { success } = await env.CHALLENGE_ONCE.limit({ key: nonce });
  if (!success) throw new HttpError(401, "challenge_expired", "That request was already used — try again.");
}

function readBody(request: Request): Promise<Uint8Array> {
  return readLimitedBody(request, MAX_BODY_BYTES);
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// MARK: - Attestation

async function handleChallenge(request: Request, env: Env): Promise<Response> {
  await limitIP(request, env);
  return json({ challenge: await issueChallenge(challengeSecret(env)), expires_in: CHALLENGE_TTL_SECONDS });
}

async function handleRegister(request: Request, env: Env): Promise<Response> {
  await limitIP(request, env);
  const body = parseJson(await readBody(request));
  const keyId = body.key_id;
  const attestation = body.attestation;
  const challenge = body.challenge;
  if (typeof keyId !== "string" || !KEY_ID.test(keyId) || typeof attestation !== "string" || typeof challenge !== "string") {
    throw new HttpError(400, "bad_request", "Couldn't read the request.");
  }
  await consumeChallenge(env, challenge);

  try {
    const result = await verifyAttestation({
      attestation: base64Decode(attestation),
      clientData: utf8(challenge),
      keyId,
      appId: appId(env),
      allowDevelopment: (env.ALLOW_DEVELOPMENT_ATTESTATION ?? "true") === "true",
    });
    const record: StoredKey = {
      spki: base64Encode(result.publicKeySpki),
      environment: result.environment,
      created: new Date().toISOString(),
    };
    await env.ATTEST_KEYS.put(`key:${keyId}`, JSON.stringify(record));
    return json({ ok: true, environment: result.environment });
  } catch (error) {
    if (error instanceof AppAttestError) {
      console.warn("attestation rejected", error.message);
      throw new HttpError(403, "attestation_failed", "This copy of FlexUp couldn't be verified.");
    }
    throw error;
  }
}

/**
 * Proves the request came from a registered install and returns the key to
 * rate-limit on. Throws `HttpError` otherwise.
 */
async function authorize(request: Request, env: Env, body: Uint8Array): Promise<string> {
  if (!attestationOn(env)) {
    return `ip:${request.headers.get("cf-connecting-ip") ?? "unknown"}`;
  }

  const devToken = request.headers.get("x-flexup-dev-token");
  if (devToken && env.DEV_BYPASS_TOKEN && constantTimeEqual(devToken, env.DEV_BYPASS_TOKEN)) {
    return "dev";
  }

  const keyId = request.headers.get("x-flexup-key-id") ?? "";
  const challenge = request.headers.get("x-flexup-challenge") ?? "";
  const assertion = request.headers.get("x-flexup-assertion") ?? "";
  if (!KEY_ID.test(keyId) || !challenge || !assertion) {
    throw new HttpError(401, "attestation_required", "This copy of FlexUp needs to verify itself first.");
  }

  const stored = await env.ATTEST_KEYS.get<StoredKey>(`key:${keyId}`, "json");
  if (!stored) {
    throw new HttpError(401, "attestation_required", "This copy of FlexUp needs to verify itself first.");
  }
  await consumeChallenge(env, challenge);

  try {
    await verifyAssertion({
      assertion: base64Decode(assertion),
      clientData: concat(utf8(challenge), body),
      publicKeySpki: base64Decode(stored.spki),
      appId: appId(env),
    });
  } catch (error) {
    if (error instanceof AppAttestError) {
      console.warn("assertion rejected", error.message);
      throw new HttpError(401, "attestation_required", "This copy of FlexUp needs to verify itself again.");
    }
    throw error;
  }
  return `key:${keyId}`;
}

// MARK: - Estimate

async function handleEstimate(request: Request, env: Env): Promise<Response> {
  if (!env.ANTHROPIC_API_KEY) {
    throw new HttpError(500, "not_configured", "The FlexUp server isn't set up yet (missing API key).");
  }

  await limitIP(request, env);
  const bodyBytes = await readBody(request);
  const caller = await authorize(request, env, bodyBytes);
  const { success } = await env.INSTALL_LIMITER.limit({ key: caller });
  if (!success) throw new HttpError(429, "rate_limited", "That's a lot of estimates in a row — give it a minute.");

  const body = parseJson(bodyBytes);
  const image = body.image;
  const mediaType = body.media_type;
  if (typeof image !== "string" || image.length === 0) {
    throw new HttpError(400, "bad_request", "No photo was sent.");
  }
  if (image.length > MAX_IMAGE_BASE64) throw new HttpError(413, "too_large", "That photo is too large.");
  if (typeof mediaType !== "string" || !MEDIA_TYPES.includes(mediaType as ImageMediaType)) {
    throw new HttpError(400, "bad_request", "Unsupported photo format.");
  }

  const client = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, timeout: 60_000, maxRetries: 2 });

  try {
    const estimate = await estimateMeal(
      client,
      { data: image, mediaType: mediaType as ImageMediaType },
      cleanText(body.cuisine_context),
      cleanText(body.correction),
    );
    return json(estimate);
  } catch (error) {
    if (error instanceof EstimateRefusedError) throw new HttpError(422, "refused", error.message);
    if (error instanceof EstimateMalformedError) throw new HttpError(502, "malformed", error.message);
    if (error instanceof Anthropic.BadRequestError) {
      console.error("Anthropic 400", error.message);
      throw new HttpError(400, "bad_request", "Couldn't read that photo — try another.");
    }
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      console.error("Anthropic auth", error.status, error.message);
      throw new HttpError(500, "not_configured", "The FlexUp server's AI key isn't working.");
    }
    if (error instanceof Anthropic.RateLimitError) {
      throw new HttpError(429, "rate_limited", "The AI is busy right now — try again in a moment.");
    }
    if (error instanceof Anthropic.APIError) {
      console.error("Anthropic", error.status, error.message);
      throw new HttpError(502, "upstream", "The AI didn't respond — try again.");
    }
    throw error;
  }
}

// MARK: - Router

type Handler = (request: Request, env: Env, params: Params) => Promise<Response>;

const routeTable: Record<string, Handler> = {
  "POST /v1/attest/challenge": handleChallenge,
  "POST /v1/attest/register": handleRegister,
  "POST /v1/estimate": handleEstimate,
  ...communityRoutes(),
  ...socialRoutes(),
};

/** "METHOD /path/:param" routes, matched segment by segment. */
const routes = Object.entries(routeTable).map(([key, handler]) => {
  const [method, pattern] = key.split(" ");
  return { method, segments: pattern.split("/").filter(Boolean), handler };
});

function match(method: string, pathname: string): { handler?: Handler; params: Params; pathExists: boolean } {
  const parts = pathname.split("/").filter(Boolean);
  let pathExists = false;
  for (const route of routes) {
    if (route.segments.length !== parts.length) continue;
    const params: Params = {};
    const ok = route.segments.every((segment, index) => {
      if (segment.startsWith(":")) {
        const value = decodeURIComponent(parts[index]);
        if (!/^[A-Za-z0-9-]{1,64}$/.test(value)) return false;
        params[segment.slice(1)] = value;
        return true;
      }
      return segment === parts[index];
    });
    if (!ok) continue;
    pathExists = true;
    if (route.method === method) return { handler: route.handler, params, pathExists };
  }
  return { params: {}, pathExists };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === "/health" && request.method === "GET") {
      return json({ ok: true, attestation: attestationOn(env) ? "required" : "off" });
    }

    const { handler, params, pathExists } = match(request.method, pathname);
    if (!handler) {
      return pathExists ? fail(405, "method_not_allowed", "Wrong method.") : fail(404, "not_found", "Not found.");
    }

    try {
      return await handler(request, env, params);
    } catch (error) {
      if (error instanceof HttpError) return fail(error.status, error.type, error.message);
      console.error("Unexpected", error);
      return fail(500, "internal", "Something went wrong — try again.");
    }
  },
} satisfies ExportedHandler<Env>;
