/** Shared request/response plumbing. Every error is `{ error: { type, message } }`. */

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly type: string,
    message: string,
  ) {
    super(message);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

export function fail(status: number, type: string, message: string): Response {
  return json({ error: { type, message } }, status);
}

export async function readBody(request: Request, maxBytes: number): Promise<Uint8Array> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > maxBytes) throw new HttpError(413, "too_large", "That's too large.");
  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length > maxBytes) throw new HttpError(413, "too_large", "That's too large.");
  return bytes;
}

export function parseJson(bytes: Uint8Array): Record<string, unknown> {
  if (bytes.length === 0) return {};
  try {
    const value = JSON.parse(new TextDecoder().decode(bytes));
    if (typeof value === "object" && value !== null && !Array.isArray(value)) return value as Record<string, unknown>;
  } catch {
    // fall through
  }
  throw new HttpError(400, "bad_request", "Couldn't read the request.");
}

export async function readJson(request: Request, maxBytes = 16_000): Promise<Record<string, unknown>> {
  return parseJson(await readBody(request, maxBytes));
}

export function text(value: unknown, max: number): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}
