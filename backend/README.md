# FlexUp API

A tiny Cloudflare Worker that sits between the app and Anthropic, so the
Anthropic API key lives on the server and never ships inside the app.

```
iPhone ──photo──▶ flexup-api (Cloudflare Worker, holds the key) ──▶ Claude Haiku 4.5
       ◀─itemised estimate (calories + macros per item)─┘
```

- `POST /v1/estimate` — `{ image, media_type, cuisine_context?, correction? }` with header
  `X-FlexUp-Install: <uuid>`. Returns `{ meal_name, items[], confidence, notes }`.
- `GET /health` — `{ "ok": true }`.
- Errors are always `{ "error": { "type", "message" } }`, with a message the app shows as-is.

The prompt and JSON schema live in `src/estimate.ts`. Improving estimates is a
server deploy, not an App Store update.

## Set it up (about 10 minutes, once)

You need Node 20+ (`brew install node`) and a free Cloudflare account (the
login step below creates one).

```bash
cd ~/Flexup-habits/backend
npm install
npx wrangler login          # opens the browser; sign up / log in to Cloudflare (free)
npm run deploy              # first time it asks you to pick a workers.dev subdomain
npx wrangler secret put ANTHROPIC_API_KEY   # paste your sk-ant-... key when prompted
```

`npm run deploy` prints your URL, e.g. `https://flexup-api.yourname.workers.dev`.
Check it's alive:

```bash
curl https://flexup-api.yourname.workers.dev/health    # → {"ok":true}
```

Then paste that URL into `FlexUp/Support/BackendConfig.swift`:

```swift
static let baseURLString = "https://flexup-api.yourname.workers.dev"
```

Build and run the app. The "Estimate calories with AI" button appears once the URL is set.

**Set a spend limit.** In the Claude Console (platform.claude.com → Settings → Limits),
set a monthly limit. That's the hard ceiling on what the AI can ever cost you.

## Day to day

| Task | Command |
| --- | --- |
| Watch live requests and errors | `npm run logs` |
| Deploy a prompt change | `npm run deploy` |
| Rotate the key | `npx wrangler secret put ANTHROPIC_API_KEY` |
| Type-check | `npm run typecheck` |
| Run locally | copy `.dev.vars.example` to `.dev.vars`, add a key, `npm run dev` |

## Cost

Claude Haiku 4.5 at $1 / $5 per million input / output tokens: about **$0.004–0.005 per
photo** (~1,000 image tokens + ~1,000 prompt tokens in, ~500 out). Cloudflare's free
plan covers 100,000 requests a day.

## Abuse protection — what's there and what isn't

- The key is only on the server.
- Rate limits: 8 estimates a minute per app install, 30 a minute per IP (`wrangler.jsonc`).
- Photos are capped at ~2.2 MB, text fields at 500 characters, and the model and
  `max_tokens` are fixed on the server.
- Photos are not stored. They pass through to Anthropic and are discarded.

**Not there yet:** anyone who finds the URL can call it, within the rate limits. The
Console spend limit caps the damage. Before a wide launch, add **App Attest**
(Apple's DeviceCheck), so the server only accepts requests from genuine copies of
the app.
