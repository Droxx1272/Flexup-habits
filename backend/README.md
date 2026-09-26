# FlexUp API

A tiny Cloudflare Worker that sits between the app and Anthropic. The Anthropic key
lives here and never ships in the app. Only genuine copies of the app, running on real
Apple devices, get answers; that's enforced with Apple's **App Attest**.

```
iPhone ──signed photo──▶ flexup-api (Cloudflare Worker, holds the key) ──▶ Claude Haiku 4.5
       ◀──itemised estimate (calories + macros per item)──┘
```

| Endpoint | What it does |
| --- | --- |
| `POST /v1/attest/challenge` | A one-time challenge, valid 60 s. |
| `POST /v1/attest/register` | Once per install: `{ key_id, attestation, challenge }`. Verifies Apple's attestation and stores the device key's public half. |
| `POST /v1/estimate` | `{ image, media_type, cuisine_context?, correction? }`, signed with headers `X-FlexUp-Key-Id`, `X-FlexUp-Challenge`, `X-FlexUp-Assertion`. |
| `GET /health` | `{ "ok": true, "attestation": "required" }` |

Errors are always `{ "error": { "type", "message" } }`, with a message the app shows as-is.
The prompt and JSON schema live in `src/estimate.ts`, so improving estimates is a server
deploy, not an App Store update.

## Set it up (about 15 minutes, once)

You need Node 20+ (`brew install node`), a free Cloudflare account (the login step
creates one), and your **Apple Team ID**. That's the 10-character ID in Xcode → FlexUp
target → Signing & Capabilities → Team, or at developer.apple.com → Membership.

1. Put your Team ID in `wrangler.jsonc`:

   ```jsonc
   "APPLE_TEAM_ID": "ABCDE12345",
   ```

2. Deploy and set the two secrets:

   ```bash
   cd ~/Flexup-habits/backend
   npm install
   npx wrangler login                                        # browser: sign up / log in (free)
   npm run deploy                                            # first time: pick a workers.dev subdomain
   npx wrangler secret put ANTHROPIC_API_KEY                 # paste your sk-ant-... key
   openssl rand -hex 32 | npx wrangler secret put CHALLENGE_SECRET
   ```

   The first deploy also creates the small key store (`ATTEST_KEYS`) and writes its ID
   into `wrangler.jsonc`. Commit that change.

3. Check it's alive. `npm run deploy` printed your URL:

   ```bash
   curl https://flexup-api.yourname.workers.dev/health    # → {"ok":true,"attestation":"required"}
   ```

4. Paste the URL into `FlexUp/Support/BackendConfig.swift`:

   ```swift
   static let baseURLString = "https://flexup-api.yourname.workers.dev"
   ```

5. **Set a spend limit** in the Claude Console (platform.claude.com → Settings → Limits).
   It's the hard ceiling on what the AI can ever cost.

Run the app **on your iPhone**. The first estimate registers the phone, which takes a
second or two extra; after that it's one quick signed request per photo.

### The simulator

The iOS Simulator can't use App Attest. To test AI estimates there, give debug builds a
development token:

```bash
openssl rand -hex 24                                   # copy the output
npx wrangler secret put DEV_BYPASS_TOKEN               # paste it
```

Then in Xcode go to Product → Scheme → Edit Scheme → Run → Arguments → Environment
Variables and add `FLEXUP_DEV_TOKEN` with the same value. Scheme variables only exist
when Xcode launches the app, so the token never ships. It's only sent when the device
can't use App Attest. To shut it off, run `npx wrangler secret delete DEV_BYPASS_TOKEN`.

### Before the App Store

In Xcode, go to Signing & Capabilities → **+ Capability → App Attest**, and set the
environment to **production** for release builds. Once everyone is on such a build, set
`"ALLOW_DEVELOPMENT_ATTESTATION": "false"` in `wrangler.jsonc` and redeploy.

## Day to day

| Task | Command |
| --- | --- |
| Watch live requests and rejections | `npm run logs` |
| Deploy a prompt change | `npm run deploy` |
| Rotate the Anthropic key | `npx wrangler secret put ANTHROPIC_API_KEY` |
| Tests (App Attest checks against real Apple attestations) | `npm test` |
| Type-check | `npm run typecheck` |
| Run locally | copy `.dev.vars.example` to `.dev.vars`, fill it in, `npm run dev` |
| Emergency: turn App Attest off | set `"ATTEST_MODE": "off"`, `npm run deploy` |

## Cost

Claude Haiku 4.5 at $1 / $5 per million input / output tokens comes to about
**$0.004–0.005 per photo**. Cloudflare's free plan covers it: 100,000 requests a day,
and the key store writes once per install, well under the free 1,000 writes a day.

## How the protection works

- **The key is only on the server.**
- **Only genuine app installs are answered.** On first use the phone's Secure Enclave
  creates a key, and Apple signs a statement that it belongs to *your* app (Team ID +
  bundle ID) on a real device. The server checks that statement against Apple's root
  certificate (`src/appattest.ts`, tested with real Apple attestations in `test/`) and
  stores the key.
- **Every estimate is signed.** The phone signs a fresh 60-second server challenge
  together with the exact request body. A captured request can't be replayed (each
  challenge works once), and it can't be reused with a different photo (the signature
  covers the body).
- **Rate limits:** 8 estimates a minute per install and 40 requests a minute per IP.
- **Size caps:** ~2.2 MB per photo and 500 characters per text field. The model and
  `max_tokens` are fixed on the server.
- **No storage:** photos go to Anthropic and are discarded.

**Known gaps:**
- The server doesn't persist the assertion counter, to stay inside the free KV write
  budget. Single-use challenges and body-bound signatures cover the replay case it
  exists for.
- App Attest proves the app is genuine, not that the person using it is honest. A
  jailbroken device running your real app can still use its own rate-limited quota.
