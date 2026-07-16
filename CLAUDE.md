# FlexUp — notes for Claude Code sessions

FlexUp is a SwiftUI iOS app (iOS 17+, Xcode 16 folder-synchronized project, zero third-party dependencies). Read `README.md` for the product vision. The core loop is **Plan → Commit → Do → Verify → Celebrate → Repeat**; the four pillars are **Wake, Run, Gym, Diet**, plus a **Stats** tab.

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
- Images: always render via `AsyncPhotoView` (downsampled, cached, off-main-thread — `FlexUp/Support/ImageLoading.swift`); save captures via `UIImage.flexJPEGData()` (1600px cap). Never `UIImage(contentsOfFile:)` in a view body.
- AI calorie estimation (`FlexUp/AI/CalorieEstimator.swift`) calls the Anthropic API directly with an on-device key — prototype only; a backend proxy replaces this before release.
- Auth is on-device (`Account` in the store): Sign in with Apple + email fallback. Sign in with Apple needs the capability + paid developer account; the email path always works.

## Design system (match it exactly)

- Tokens in `FlexUp/DesignSystem/Theme.swift`: cream background / deep-navy ink / green accent, dynamic light+dark via `Color(light:dark:)` hex pairs.
- Typography voices: `.flexDisplay()` (huge black uppercase titles), `.flexMono()` with `.tracking(1–3)` (UPPERCASE eyebrows/taglines), `.flexStat()` (big numerals), `.flexBody/.flexCaption` for quiet text.
- Components in `FlexUp/DesignSystem/Components.swift`: `ScreenHeader` (every tab), `FlexCard`, `PrimaryButtonStyle` (ink pill — one per screen), `SecondaryButtonStyle`, `TrackStat`, `SelectableChip`, `SegmentPills`, `IconBadge`, `AvatarStack`.
- No XP/levels/follower counts/infinite scroll. Calm, whitespace-heavy, one primary CTA per screen.
- Dormant (built but out of the tab bar, kept for later): Home, Discover, Squad (feed + memories), Calendar, Track hub, Profile — they must keep compiling.

## Product rules

- Every feature must answer: "does this help someone follow through?"
- No fake completions: verification methods (timer, photo, GPS run, logged workout) must be real or honestly labeled as coming with the backend.
- Optimize for completions and consistency, never for screen time.
