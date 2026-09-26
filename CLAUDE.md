# FlexUp — notes for Claude Code sessions

FlexUp is a SwiftUI iOS app (iOS 17+, Xcode 16 folder-synchronized project, zero third-party dependencies). Read `README.md` for the product vision. The core loop is **Plan → Commit → Do → Verify → Celebrate → Repeat**; the four pillars are **Wake, Run, Gym, Diet**, plus a **Today** tab (commitments · Community · Progress · Stats).

## Build & verify

- Open/build with Xcode 16+: `xcodebuild -project FlexUp.xcodeproj -scheme FlexUp -destination 'platform=iOS Simulator,name=iPhone 16' build`
- There are no tests yet. At minimum, make sure the project compiles before committing.
- New Swift files are picked up automatically (PBXFileSystemSynchronizedRootGroup) — just create them under `FlexUp/`; never hand-edit `project.pbxproj` to register files.

## Git conventions

- Work on branch `claude/flexup-accountability-app-xqpifv` unless told otherwise.
- Xcode writes the local signing team into `FlexUp.xcodeproj/project.pbxproj`. **Never commit that change**; before pulling, run `git checkout -- FlexUp.xcodeproj/project.pbxproj`.
- A cloud Claude session may also push to this branch — pull before starting work.

## Architecture

- `FlexUp/Store/AppStore.swift` is the single source of truth (`@Observable`). All state mutations go through store methods; views never mutate collections directly. Persistence is a JSON `Snapshot` written debounced/off-main-thread by `save()` — **new Snapshot fields must be optional** (`var foo: [Foo]?`) so old on-device saves still decode.
- Models live in `FlexUp/Models/Models.swift`; sample/fixture data in `FlexUp/Store/SampleData.swift`.
- Completing runs/workouts auto-completes matching commitments (see `logRun`/`logWorkout`); achievements unlock via `unlock(key:)` and the catalog merges on load (`mergeAchievementCatalog`).
- Every log type has a delete on the store (`deleteRun`/`deleteWorkout`/`deleteSleep`/`deleteFood`/`deleteWeight`/`deleteRoutine`/`deleteHabit`), surfaced in the UI via `.contextMenu` — rows live in `ScrollView`s, not `List`s, so `.swipeActions` won't work.
- Editing a habit (`updateHabit`) re-materializes only its **upcoming** commitments; completed and missed ones are never touched, so history stays honest.
- Images: always render via `AsyncPhotoView` (downsampled, cached, off-main-thread — `FlexUp/Support/ImageLoading.swift`); save captures via `UIImage.flexJPEGData()` (1600px cap). Never `UIImage(contentsOfFile:)` in a view body.
- AI calorie estimation: the app **never holds an Anthropic key**. `FlexUp/AI/CalorieEstimator.swift` POSTs the downscaled photo + `store.cuisineContext` + the user's spoken/typed correction to the Cloudflare Worker in `backend/` (URL in `FlexUp/Support/BackendConfig.swift`; empty = AI honestly shown as off). The Worker holds the key, owns the prompt + JSON schema (`backend/src/estimate.ts` — prompt changes are a `npm run deploy`, not an app release), requires **App Attest** (`FlexUp/Support/AppAttestClient.swift` registers a Secure Enclave key once via `/v1/attest/register`, then signs `challenge ‖ exact body` on every `/v1/estimate`; verification is dependency-free WebCrypto in `backend/src/appattest.ts`, tested against real Apple attestations with `npm test`), rate-limits per key/IP, and returns an **itemised** `MealEstimate` (per-component name/portion/calories/macros) which `AddFoodSheet` turns into editable `FoodItem`s. Keep the app's `MealEstimate` decoder and the Worker's response shape in sync. Type-check and test the Worker with `cd backend && npm run typecheck && npm test`. The simulator can't use App Attest — debug builds send the `FLEXUP_DEV_TOKEN` scheme env var instead (server secret `DEV_BYPASS_TOKEN`). Never add a way for release builds to skip attestation. `VoiceDictation` (Speech framework) backs the mic button and needs the microphone + speech-recognition usage descriptions already in build settings.
- Nutrition: `FoodEntry.macros` / `FoodItem.baseMacros` are optional `Macros` (nil = calories only — never fake zeros; the Diet tab reports how many kcal have macro data). `store.nutritionGoals` holds all daily targets; `calorieBudget` is a computed alias onto it. Food can be logged to a past day via `addFood(date:)` / `logDate(for:meal:)`. Water lives in `waterByDay` keyed by `dayKey`.
- Progress (`FlexUp/Views/Progress/ProgressSection.swift`) reads only store range helpers (`runDistanceSeries`, `sleepSeries`, `calorieSeries`, … via the private `series(_:in:perDay:perBucket:)`), which bucket by day for 7D/30D and by week for 90D/1Y and emit no point for unlogged days.
- The intro (`FlexUp/Views/Intro/IntroView.swift`) gates on `store.hasSeenIntro` before `AuthView`; older saves default it to "seen" when an account exists.
- Auth: with `BackendConfig` set, `AuthView` creates real server accounts (email + password or Sign in with Apple → `/v1/auth/*`) and stores `Account(userID: server id)`; without it, the old on-device account keeps early builds usable. The session token lives in the Keychain (`FlexUp/Community/Keychain.swift`), never UserDefaults.
- Community: `store.community` is a `CommunityStore` owned by `AppStore` — views call its methods, never mutate its arrays. Social methods (posts, kudos, comments, messages, notifications, profiles, photos, block/report) are in `CommunityStore+Social.swift`; one-off lists (a chat, a post's comments, someone's profile) are returned to the screen, not stored. Every tab's `ScreenHeader` shows `HeaderActions` (chat, bell with counts, your avatar → sheets); community screens push via `CommunityDestination` + `.communityDestinations()`. Photos from the server render with `RemoteImageView` / `ProfileAvatar` (`FlexUp/Support/RemoteImage.swift`), never `AsyncImage`. Anything that changes observed state is `@MainActor`. Activities reach friends only through `AppStore.shareWithFriends` from real log paths (`checkInWake`, `logRun`, `logWorkout`, `logSleep`, `complete`), filtered by `store.sharing`; `complete(_:sharesActivity: false)` stops a run/workout being shared twice. Shares queue on disk (`PendingActivity`, idempotent `clientID`) so offline logs arrive later. Server side is `backend/src/community.ts` (D1; schema created lazily in `db.ts` — additive changes only). Friends-only with no public discovery — keep it that way. Posts, comments and messages are free text, so App Store UGC rules apply: every new surface needs Report + Block, text goes through `filterText` (`backend/src/moderation.ts`) server-side, and sign-up keeps the guidelines agreement. Keep `CommunityModels.swift` in sync with the server's JSON (snake_case → `.convertFromSnakeCase`, ISO dates without fractional seconds).

## Design system (match it exactly)

- Tokens in `FlexUp/DesignSystem/Theme.swift`: cream background / deep-navy ink / green accent, dynamic light+dark via `Color(light:dark:)` hex pairs.
- Typography voices: `.flexDisplay()` (huge black uppercase titles), `.flexMono()` with `.tracking(1–3)` (UPPERCASE eyebrows/taglines), `.flexStat()` (big numerals), `.flexBody/.flexCaption` for quiet text.
- Components in `FlexUp/DesignSystem/Components.swift`: `ScreenHeader` (every tab), `FlexCard`, `PrimaryButtonStyle` (ink pill — one per screen), `SecondaryButtonStyle`, `TrackStat`, `SelectableChip`, `SegmentPills`, `IconBadge`, `AvatarStack`.
- No XP/levels/follower counts/infinite scroll. Calm, whitespace-heavy, one primary CTA per screen.
- Dormant (built but out of the tab bar, kept for later): Home, Discover, Squad (feed + memories), Calendar, Track hub, Profile — they must keep compiling. `CommitmentDetailSheet`, `CommitmentRow` and `PlanSheet` live under those folders but **are** reachable from `TodayView`.
- Tabs are Wake · Run · Gym · Diet · Today. `TodayView` owns the navigation and toggles between the commitments list, `CommunitySection`, `ProgressSection` and `StatsSection` (plain content views with no navigation of their own, like `RunSection`/`LiftSection`/`FuelSection`). Crew management is `CrewView` (pushed from your profile / the bell).
- Goals & preferences from onboarding live in `store.goals` (`UserGoals`: focuses, weekly run/gym targets, weights) and `store.reminders`; `store.weekProgress` measures the calendar week against them.

## Wake alarm constraints

- **Two paths, never both at once.** `updateWakeSchedule()` first tries `WakeAlarmScheduler` (AlarmKit, iOS 26+) — a real alarm that rings through the mute switch. Only when that returns `.unavailable` (pre-iOS 26 or permission denied) does it fall back to `scheduleWakeNotifications()`. Firing both would double-alert the morning.
- AlarmKit needs `INFOPLIST_KEY_NSAlarmKitUsageDescription` (already in build settings) — a missing or empty value silently blocks all scheduling. The scheduled alarm's ID lives in `WakeConfig.alarmID` so a reschedule can cancel the previous one.
- Notifications **cannot** ring through the mute switch; `.timeSensitive` pierces Focus modes only (and wants the Time Sensitive Notifications capability in Xcode). Don't claim alarm behavior the code can't deliver.
- **Notification budget: iOS allows 64 pending per app.** The fallback uses 6 nudges × 7 days = 42, plus 7 bedtime = 49. Anything new must stay under 64.
- `checkInWake` calls `silenceWakeNudges()` to drop the rest of today's nudges while keeping next week's; `NotificationPresenter` is the notification delegate (set in `FlexUpApp.init()`) so alerts still sound while the app is foregrounded.

## Product rules

- Every feature must answer: "does this help someone follow through?"
- No fake completions: verification methods (timer, photo, GPS run, logged workout) must be real or honestly labeled as coming with the backend.
- Optimize for completions and consistency, never for screen time.
