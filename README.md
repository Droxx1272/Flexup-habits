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

No dependencies, no packages, no account — everything is local in v1.

## App structure

Four pillars plus the proof — one tab each, nothing buried:

| Tab | Purpose |
| --- | --- |
| **Wake** | Wake/Sleep toggle. **Wake**: Erly-style wake time with a real alarm (AlarmKit on iOS 26+ — rings through the mute switch like the Clock app; older systems fall back to a burst of Time Sensitive notifications 40s apart that stop the moment you check in), morning check-in (photo of the sky counts), weekly streak strip, and a 5-second alarm preview. **Sleep**: bedtime reminder, log-last-night flow (bedtime/wake time pickers + quality rating), duration/quality history, 7-day average and night streak. No snoozing, no backup alarms. |
| **Run** | GPS tracking (Strava-style): live route map while recording, time/distance/pace/elevation, per-km splits, and a run detail view with the route drawn, headline stats, and split pace bars. |
| **Gym** | Training log (Hevy-style): saved routines you can start from, live session with a rest timer, sets × kg × reps prefilled from your last set, last-session and all-time bests per exercise, volume stats, history. |
| **Diet** | Calorie tracking (Lose It-style): daily budget ring, four meals, quick-add foods, body-weight logging with a 30-day trend, and meal photos — snap the plate and let AI estimate the calories (Claude Haiku 4.5 vision via the Anthropic API with structured JSON output, ~$0.002/photo; bring-your-own key in v1, backend proxy before release). |
| **Today** | Where the loop closes, with a **Today / Stats** toggle. **Today**: progress ring, the day's commitments (tap to run a timer, take photo proof, complete, reschedule or skip), plan a one-off, and Quick Start. **Stats**: per-pillar streaks and totals, weekly consistency chart, habit management (add/edit/delete the habits that schedule your days), body-weight trend, progress photos with pose guides and then-vs-now comparison, achievements, account. |

Everything logged can be removed — long-press any run, workout, night, weigh-in, routine, or habit to delete it.

Discover, Squad (social feed + memories), Calendar, Activity detail, and the coach remain in the codebase but out of the nav — the navigation stays simple until the pillars are solid.

## Login & onboarding

- **Sign in with Apple** (primary; requires the Sign In with Apple capability + a paid Apple Developer account) with an on-device **email account** fallback. Accounts gate the app; sign-out lives in Stats. Data stays on device in v1 — a backend later adds verification and sync.
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
