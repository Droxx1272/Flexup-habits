# FlexUp

**The operating system for becoming the person you want to be.**

People don't struggle because they don't know what to do. They struggle because they don't consistently follow through. FlexUp helps people follow through.

FlexUp is not a habit tracker, not a fitness tracker, and not another social network. It is a system that turns intentions into actions.

## The core loop

Everything in the app reinforces one loop:

```
Plan → Commit → Do → Verify → Celebrate → Repeat
```

- **Plan** — onboarding turns "who I'm becoming" into scheduled habits; the Calendar plans one-off commitments; Discover finds activities with real people.
- **Commit** — every plan becomes a `Commitment` with a status lifecycle: scheduled → confirmed → completed / missed / rescheduled.
- **Do** — Home answers "what should I do next?"; Quick Start removes friction to begin something right now.
- **Verify** — timer verification runs a real countdown; photo verification opens the camera (the shot is filed as a check-in); runs and workouts verify themselves by being tracked. Partner and GPS check-in verification light up with the backend. No fake completions.
- **Celebrate** — a completion moment with streaks and meaningful achievements (firsts, consistency, community, exploration, milestones, leadership — including hidden ones).
- **Repeat** — missed days roll over honestly, streaks reset, and the coach nudges a restart without guilt.

## Running the app

1. Open `FlexUp.xcodeproj` in **Xcode 16 or later** (the project uses folder-synchronized groups).
2. Select the FlexUp scheme and any iOS 17+ simulator or device.
3. Build and run. First launch walks through onboarding and seeds a local "world" of nearby activities, friends, and communities so every screen is alive.

No dependencies, no packages, no account — everything is local in v1. The one server piece is the optional AI-estimate proxy in `backend/` (see its README).

## App structure

Four pillars plus the proof — one tab each, nothing buried:

| Tab | Purpose |
| --- | --- |
| **Wake** | Wake/Sleep toggle. **Wake**: Erly-style wake time with a real alarm (AlarmKit on iOS 26+ — rings through the mute switch like the Clock app; older systems fall back to a burst of Time Sensitive notifications 40s apart that stop the moment you check in), morning check-in (photo of the sky counts), weekly streak strip, and a 5-second alarm preview. **Sleep**: bedtime reminder, log-last-night flow (bedtime/wake time pickers + quality rating), duration/quality history, 7-day average and night streak. No snoozing, no backup alarms. |
| **Run** | GPS tracking (Strava-style): live route map while recording, time/distance/pace/elevation, per-km splits, and a run detail view with the route drawn, headline stats, and split pace bars. |
| **Gym** | Training log (Hevy-style): saved routines you can start from, live session with a rest timer, sets × kg × reps prefilled from your last set, last-session and all-time bests per exercise, volume stats, history. |
| **Diet** | Nutrition (Lose It-style, more data): step back through any day to review or back-fill it; calorie budget ring and logging streak; **macros** (protein / carbs / fat bars against goals, energy-split donut, fibre / sugar / sodium) with an honest note when some calories have no macro data; water tracker (+250 / +500 ml against a daily goal); last-7-days calorie chart against budget; tap any food for its full breakdown and "log again"; recent foods and 16 quick-adds with macros; nutrition goals (Lose / Maintain / Build split, protein from body weight, fibre, water); body-weight logging; and photo estimation built for real plates — see below. |
| **Today** | Where the loop closes, with a **Today / Progress / Stats** toggle. **Today**: progress ring, the day's commitments (tap to run a timer, take photo proof, complete, reschedule or skip), plan a one-off, and Quick Start. **Progress**: every pillar over 7D / 30D / 90D / 1Y — follow-through rate, a square-per-morning wake grid, sleep hours vs 8h, km per day/week, gym volume with personal records, calories vs budget with average macros and water, body weight and photo count. Unlogged days are gaps, never zeros. **Stats**: per-pillar streaks and totals, weekly consistency chart, habit management, body-weight trend, progress photos with pose guides and then-vs-now comparison, achievements, account. |

**Friends** (Today tab → Friends): real accounts on the FlexUp server, a 6-character friend code (share it, or add someone by code/@handle), requests to accept, and a crew list showing who's already shown up today — with one preset **nudge** per friend per day for anyone who's quiet. A friends-only feed of the last two weeks shows what people actually logged (wake-ups, runs, workouts, habits — sleep optional, food never), each with one-tap **cheers**. Nudges also surface as a banner on Today. No strangers, no public profiles, no follower counts; removing a friend works as a block, and accounts can be deleted in-app.

Everything logged can be removed — long-press any run, workout, night, weigh-in, routine, or habit to delete it.

## Photo calorie estimation

Snap a plate and Claude Haiku 4.5 vision returns an **itemised** estimate — calories plus protein, carbs, fat, fibre, sugar and sodium per component (~$0.002/photo, structured JSON output). A single number is untrustworthy, so the flow is built around correcting it:

- **Tap to adjust any portion.** Each component gets its own row with the portion the model believed it saw; − / + scale it in quarter steps and the total updates live.
- **Add what the photo missed.** Cooking fat is invisible in a photo and is the biggest single source of error — one tap adds ghee, oil, butter, cream, coconut milk, deep-frying and more.
- **Correct it by voice or text.** Say or type "cooked in mustard oil, only two rotis" and re-estimate; the correction is passed to the model as authoritative. Hand-added ingredients survive the re-run.
- **Teach it your kitchen once.** A persisted cuisine context ("North Indian home cooking, mustard oil, moderate ghee") ships with every request, so regional and mixed dishes stop being scored against Western database equivalents. 21 presets, or write your own.

The app never holds an Anthropic key: photos go to a small Cloudflare Worker in [`backend/`](backend/README.md) that holds the key, owns the prompt, and returns the itemised estimate (about $0.004–0.005 per photo). The Worker answers only genuine copies of the app on real Apple devices — **App Attest** registers each install's Secure Enclave key once, then every estimate is signed over a single-use server challenge plus the exact photo. Setup is about 15 minutes; until the Worker URL is set in `FlexUp/Support/BackendConfig.swift`, the app says AI estimates aren't switched on and you log by hand.

Discover, Squad (social feed + memories), Calendar, Activity detail, and the coach remain in the codebase but out of the nav — the navigation stays simple until the pillars are solid.

## Introduction, login & onboarding

- A five-page **introduction** runs once before sign-in (the loop, then Wake, Run + Gym, Diet, Progress), each with an animated ink illustration; Skip or swipe through. Replayable from Stats.
- With the FlexUp server connected, accounts are real: **Sign in with Apple** (requires the capability + a paid Apple Developer account) or **email + password**, the same account friends add. Without a server it falls back to an on-device account so early builds still work. Sign-out and account deletion live in Stats. Logs stay on the phone; only what you choose to share with friends goes to the server.
- Onboarding is one question per screen (progress bar, back arrow, big type): name → identity → focus areas → starter habits → wake-up time, so day one starts tomorrow morning.

## Architecture

- **SwiftUI + Observation** (`@Observable`), iOS 17+, zero third-party dependencies.
- **Performance**: photos decode as async, cached, downsampled thumbnails (ImageIO) — never full-resolution on the main thread; captures are capped at 1600px; persistence is debounced and encodes/writes off the main thread.
- `AppStore` is the single source of truth: all state, all actions, the scheduling engine (habits → materialized commitments), the achievement unlock rules, and the rule-based coach live there. Views never mutate state directly.
- Persistence is a JSON snapshot in Application Support — deliberately boring, and isolated so it can be swapped for a synced backend without touching views.
- The coach is rule-based in v1 (inactivity restarts, skipped-weekday detection, friend-activity nudges). Its interface (`CoachInsight` with an optional action) is what a model-backed coach will plug into.
- Sample data (activities, friends, communities) is fixture-based and self-refreshing so Discover never looks dead; it is the seam where the real location-aware backend goes.

## Product principles encoded in the code

- One primary CTA per screen; calm, whitespace-heavy design; light and dark themes.
- Typography system: huge black display titles (`HEY DEVMAY`), monospaced uppercase taglines (`YOUR PROGRESS. YOUR PEOPLE.`), ink pill buttons, giant stat numerals.
- No XP, no levels, no infinite scroll, no popularity metrics.
- Success is measured in completions and follow-through, not screen time — the celebration screen's only button sends you back to your life.

## Roadmap (post-v1)

- Backend: accounts, real friends, real activities, communities that organize events.
- Verification: GPS check-in, partner confirmation, photo proof, HealthKit.
- AI coach: replace the rules engine behind `CoachInsight` with a model-backed coach.
- Feed: replace Squad's fixture events with real friend activity from the backend.
- Plus tier: AI planner, smart scheduling, weekly reports, calendar integrations.
