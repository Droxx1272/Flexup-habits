import Anthropic from "@anthropic-ai/sdk";
import { EstimateMalformedError, EstimateRefusedError, estimateMeal, type ImageMediaType } from "./estimate";

/**
 * FlexUp API. One job today: turn a meal photo into an itemised estimate
 * without the Anthropic key ever leaving the server.
 *
 *   POST /v1/estimate   { image, media_type, cuisine_context?, correction? }
 *                       header X-FlexUp-Install: <per-install UUID>
 *   GET  /health
 *
 * Errors are always `{ "error": { "type": string, "message": string } }`
 * with a message written for the person holding the phone.
 */

export interface Env {
  ANTHROPIC_API_KEY: string;
  INSTALL_LIMITER: RateLimit;
  IP_LIMITER: RateLimit;
}

const MEDIA_TYPES: readonly ImageMediaType[] = ["image/jpeg", "image/png", "image/webp"];
/** ~2.2 MB of image. The app sends a 1024 px JPEG, typically 150–300 KB. */
const MAX_IMAGE_BASE64 = 3_000_000;
const MAX_TEXT = 500;
const INSTALL_ID = /^[0-9A-Fa-f-]{36}$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function fail(status: number, type: string, message: string): Response {
  return json({ error: { type, message } }, status);
}

function cleanText(value: unknown): string {
  return typeof value === "string" ? value.trim().slice(0, MAX_TEXT) : "";
}

async function handleEstimate(request: Request, env: Env): Promise<Response> {
  if (!env.ANTHROPIC_API_KEY) {
    return fail(500, "not_configured", "The FlexUp server isn't set up yet (missing API key).");
  }

  const installID = request.headers.get("x-flexup-install") ?? "";
  if (!INSTALL_ID.test(installID)) {
    return fail(400, "bad_request", "Missing install ID.");
  }

  const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
  const [perInstall, perIP] = await Promise.all([
    env.INSTALL_LIMITER.limit({ key: installID }),
    env.IP_LIMITER.limit({ key: ip }),
  ]);
  if (!perInstall.success || !perIP.success) {
    return fail(429, "rate_limited", "That's a lot of estimates in a row — give it a minute.");
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (declaredLength > MAX_IMAGE_BASE64 + 10_000) {
    return fail(413, "too_large", "That photo is too large.");
  }

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return fail(400, "bad_request", "Couldn't read the request.");
  }

  const image = body.image;
  const mediaType = body.media_type;
  if (typeof image !== "string" || image.length === 0) {
    return fail(400, "bad_request", "No photo was sent.");
  }
  if (image.length > MAX_IMAGE_BASE64) {
    return fail(413, "too_large", "That photo is too large.");
  }
  if (typeof mediaType !== "string" || !MEDIA_TYPES.includes(mediaType as ImageMediaType)) {
    return fail(400, "bad_request", "Unsupported photo format.");
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
    if (error instanceof EstimateRefusedError) {
      return fail(422, "refused", error.message);
    }
    if (error instanceof EstimateMalformedError) {
      return fail(502, "malformed", error.message);
    }
    if (error instanceof Anthropic.BadRequestError) {
      console.error("Anthropic 400", error.message);
      return fail(400, "bad_request", "Couldn't read that photo — try another.");
    }
    if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
      console.error("Anthropic auth", error.status, error.message);
      return fail(500, "not_configured", "The FlexUp server's AI key isn't working.");
    }
    if (error instanceof Anthropic.RateLimitError) {
      return fail(429, "rate_limited", "The AI is busy right now — try again in a moment.");
    }
    if (error instanceof Anthropic.APIError) {
      console.error("Anthropic", error.status, error.message);
      return fail(502, "upstream", "The AI didn't respond — try again.");
    }
    console.error("Unexpected", error);
    return fail(500, "internal", "Something went wrong — try again.");
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === "/health" && request.method === "GET") {
      return json({ ok: true });
    }
    if (pathname === "/v1/estimate") {
      if (request.method !== "POST") return fail(405, "method_not_allowed", "Use POST.");
      return handleEstimate(request, env);
    }
    return fail(404, "not_found", "Not found.");
  },
} satisfies ExportedHandler<Env>;
