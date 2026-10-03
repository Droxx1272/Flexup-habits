# FlexUp 1.0 — App Store submission checklist

## Already done in the code

**App setup**
- [x] 1024 px app icon (placeholder in brand colours — swap `AppIcon-1024.png` for a designer's version any time).
- [x] iPhone only, portrait only. No iPad screenshots or iPad layout review needed.
- [x] `ITSAppUsesNonExemptEncryption = NO`, so there's no export-compliance question on each upload (HTTPS only).
- [x] Category: Health & Fitness.
- [x] Every permission has a plain-English purpose string: camera, location, microphone, speech, alarms.

**Privacy**
- [x] Privacy manifest (`FlexUp/PrivacyInfo.xcprivacy`): no tracking; UserDefaults declared with reason CA92.1; collected data declared.
- [x] **AI consent** (guideline 5.1.2(i)). Before the first meal photo is sent to Claude, the app explains what's sent and asks. It can be turned off in Profile → Privacy & data.
- [x] Privacy policy, terms and support pages served by the Worker at `/privacy`, `/terms` and `/support`, and linked from Profile → Privacy & data.
- [x] Account deletion in the app (guideline 5.1.1(v)): Stats → Delete account, and Profile → Privacy & data.

**Content and safety**
- [x] "Estimates, not medical advice" wording on AI calorie estimates and in the terms (guideline 1.4.1).
- [x] Community (user posts and messages) is off in 1.0 (`FeatureFlags.community = false`), so there's no user-generated content to moderate yet.
- [x] The developer bypass for App Attest exists only in Debug builds.

## You need to do these

1. **Apple Developer Program** ($99/yr) — required to submit, and for Sign in with Apple and App Attest.
2. **Register the bundle ID** `com.flexup.FlexUp` (or change it in Xcode if taken) at developer.apple.com → Identifiers, with the **Sign in with Apple** and **App Attest** capabilities.
3. **In Xcode, open the FlexUp target → Signing & Capabilities and add these.** This is done in Xcode, not in code.
   - **Sign in with Apple.** Without it, the Apple button fails, and reviewers do tap it.
   - **App Attest**, with the environment set to **Production**.
   - **Background Modes → Location updates**, so runs keep recording when the screen locks. The code switches this on automatically once the mode is present.
4. **Deploy the server** (`backend/README.md`):
   - Set `APPLE_TEAM_ID` in `backend/wrangler.jsonc` (`SUPPORT_EMAIL` is supportflexup@gmail.com), then `npm run deploy`.
   - Paste the URL into `FlexUp/Support/BackendConfig.swift`.
   - Check that `https://<your-worker>/privacy` opens in a browser.
5. **Set a spend limit** in the Claude Console.
6. **Create a demo account** for App Review, using the app's own sign-up with an email you control. Put it in the review notes below.
7. **Screenshots**: 6.9" iPhone (1320 × 2868), 3–10 of them. Suggested: Wake alarm, a run with its map, a gym session, a Diet day with macros, the AI plate estimate, and Progress.
8. **Archive and upload**: in Xcode, choose Product → Archive → Distribute App → App Store Connect. Try it on TestFlight first.

## App Store Connect answers

**URLs**
- Privacy Policy URL: `https://<your-worker>.workers.dev/privacy`
- Support URL: `https://<your-worker>.workers.dev/support`

**App Privacy**
- Data used to track you: **none**.
- Data linked to you: **none** (accounts live on the phone while `FeatureFlags.cloudAccounts` is off).
- Data not linked to you, for **App Functionality**:
  - User Content → **Photos or Videos** (meal photos, only when the person asks for an AI estimate)
  - User Content → **Other User Content** (meal notes)
- Everything else (runs, location, sleep, weight, food logs, photos) stays on the device, so don't declare it.

**Age rating**: answer the questionnaire honestly. There's no user-generated content in 1.0, and it contains fitness and nutrition information.

## Review notes (paste into App Review Information)

```
No demo account needed: tap "Continue with email", enter any name and
email. The account lives on the device; nothing is sent to a server.

FlexUp is a habit and accountability app for four daily pillars: Wake, Run, Gym, Diet.
- Wake: on iOS 26 it schedules a real alarm with AlarmKit; on earlier iOS it uses
  time-sensitive notifications. "Preview the alarm" in Wake → alarm settings rings in 5 s.
- Run: GPS tracking during a recorded run only, including with the screen locked.
- Diet: "Estimate calories with AI" sends the meal photo to our server and to Anthropic's
  Claude, only after the user agrees in an in-app consent screen.
- Wake check-in can require a photo of a "proof spot" (set in Wake → Edit wake-up).
  The two photos are compared on the device with Apple's Vision framework.
- AI meal estimates are limited to 3 per day. The food search uses the bundled
  USDA FoodData Central database (public domain), offline.
- All logs and the account are stored on the device. Account deletion (erases all
  data): Today → Stats → Delete account, or Profile → Privacy and data.
```

## Known review risk

- **Login for an on-device account (guideline 5.1.1(v)).** Apple asks apps without significant account-based features to work without a login. Accounts are local while `FeatureFlags.cloudAccounts` is off, so a reviewer may ask why sign-in is required. Answer in the review notes (the account keeps one phone's logs separate per person and lets them log out), or add a "Continue without an account" path if it's rejected.
- Placeholder features: none in 1.0. Community is hidden entirely, and every verification method offered actually verifies.
