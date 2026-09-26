/**
 * Privacy policy, terms and support pages, served by the Worker so the App
 * Store listing has URLs without a separate website:
 *   <server>/privacy   <server>/terms   <server>/support
 * Keep in sync with FlexUp/PrivacyInfo.xcprivacy and the App Store Connect
 * privacy answers. Update before switching community features on.
 */

export interface LegalEnv {
  SUPPORT_EMAIL?: string;
}

const UPDATED = "September 26, 2026";

function page(title: string, body: string): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · FlexUp</title>
<style>
  :root { --bg:#F4F0E6; --ink:#1C2733; --sub:#6B685E; --accent:#2F6D53; --card:#FFFFFF; }
  @media (prefers-color-scheme: dark) { :root { --bg:#121211; --ink:#F1EFE8; --sub:#9C998F; --accent:#6FBF97; --card:#1D1D1B; } }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  main { max-width:720px; margin:0 auto; padding:40px 20px 80px; }
  .eyebrow { font:600 12px/1 ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing:.18em; text-transform:uppercase; color:var(--accent); }
  h1 { font-size:40px; line-height:1.05; font-weight:900; text-transform:uppercase; margin:10px 0 6px; letter-spacing:-.01em; }
  h2 { font-size:15px; font-family:ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing:.14em; text-transform:uppercase; margin:36px 0 8px; }
  p, li { color:var(--ink); } .sub { color:var(--sub); }
  ul { padding-left:20px; } li { margin:6px 0; }
  .card { background:var(--card); border-radius:18px; padding:18px 20px; margin:20px 0; }
  a { color:var(--accent); }
</style>
</head>
<body><main>${body}</main></body>
</html>`;
  return new Response(html, {
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=3600" },
  });
}

function contact(env: LegalEnv): string {
  const email = env.SUPPORT_EMAIL?.trim();
  return email ? `<a href="mailto:${email}">${email}</a>` : "the support address on our App Store listing";
}

export function privacyPage(env: LegalEnv): Response {
  return page(
    "Privacy Policy",
    `<div class="eyebrow">FlexUp</div>
<h1>Privacy Policy</h1>
<p class="sub">Last updated ${UPDATED}</p>

<div class="card"><strong>The short version:</strong> your logs stay on your phone. We keep only what's needed for your account.
We don't show ads, track you across apps, or sell anyone's data.</div>

<h2>What stays on your device</h2>
<p>Wake-ups and alarms, sleep, runs and their GPS routes, workouts, food and water logs, body weight, progress photos, habits,
goals and commitments are stored on your iPhone only. They are removed when you delete the app.</p>

<h2>What we collect</h2>
<ul>
  <li><strong>Account details</strong>: your name, email address and an account ID. If you use Sign in with Apple, we get the
  identifier and (optionally) the email Apple shares with us. Passwords are stored only as a salted hash. Used to sign you in.</li>
  <li><strong>Meal photos and notes, only when you ask for an AI estimate</strong>: after you agree in the app, the photo, any
  correction you type or speak, and your cuisine description are sent to our server and passed to Anthropic (Claude) to estimate
  calories. We don't store them. Anthropic processes them under its commercial terms, which don't allow using them to train its models
  (<a href="https://www.anthropic.com/legal/privacy">Anthropic privacy policy</a>). You can turn AI estimates off at any time
  in Profile → Privacy &amp; data.</li>
  <li><strong>An app-install key</strong>: Apple's App Attest creates a key on your device that proves requests come from the
  genuine FlexUp app. It contains no personal information.</li>
  <li><strong>Security logs</strong>: our host keeps short-lived request logs (such as IP address and time) to prevent
  abuse and enforce rate limits.</li>
</ul>

<h2>Permissions</h2>
<ul>
  <li><strong>Location</strong>: used only while you record a run, to measure distance and pace. Routes stay on your device.</li>
  <li><strong>Camera and photos</strong>: for progress photos, check-ins and meal photos. They stay on your device unless you
  ask for an AI estimate.</li>
  <li><strong>Microphone and speech recognition</strong>: to turn a spoken meal correction into text. Apple may process
  speech under its own privacy policy.</li>
  <li><strong>Notifications and alarms</strong>: for your wake alarm, bedtime and habit reminders, scheduled on your device.</li>
</ul>

<h2>Who we share with</h2>
<p>Cloudflare hosts our server. Anthropic provides AI calorie estimates. That's all. There's no advertising, analytics
or data-broker sharing, and no tracking.</p>

<h2>Community features</h2>
<p>Friends, posts and messages are not active in this version. If we switch them on, we'll update this policy first and ask before
anything is shared.</p>

<h2>Keeping and deleting your data</h2>
<p>Delete your account any time in the app (Today → Stats → Delete account). This permanently removes your account and everything
stored with it on our server. To remove the data on your phone, delete the app.</p>

<h2>Children</h2>
<p>FlexUp isn't directed at children under 13, and we don't knowingly collect their information.</p>

<h2>Changes and contact</h2>
<p>We'll post changes here and update the date above. Questions or requests: ${contact(env)}.</p>`,
  );
}

export function termsPage(env: LegalEnv): Response {
  return page(
    "Terms of Use",
    `<div class="eyebrow">FlexUp</div>
<h1>Terms of Use</h1>
<p class="sub">Last updated ${UPDATED}</p>

<h2>Not medical advice</h2>
<p>FlexUp helps you build habits. It isn't a medical device and doesn't give medical, nutritional or fitness advice. Calorie and
macro estimates, including AI estimates from photos, are approximate. Talk to a doctor before starting a new diet or exercise
program, especially if you have a health condition.</p>

<h2>Your account</h2>
<p>Keep your login details private. You're responsible for activity on your account. You can delete it at any time in the app.</p>

<h2>Acceptable use</h2>
<p>Don't misuse the service: no attempts to break, overload or reverse-engineer it, and no automated access. We may suspend accounts
that do.</p>

<h2>The service</h2>
<p>FlexUp is provided "as is". Features may change. To the extent the law allows, we aren't liable for indirect or consequential
losses arising from your use of the app. Apple's standard licensed application end user license agreement also applies.</p>

<h2>Contact</h2>
<p>${contact(env)}</p>`,
  );
}

export function supportPage(env: LegalEnv): Response {
  return page(
    "Support",
    `<div class="eyebrow">FlexUp</div>
<h1>Support</h1>
<p>Need help? Email ${contact(env)}. We reply within two working days.</p>

<h2>Forgot your password?</h2>
<p>Email us from the address on your account and we'll help you back in. If you signed up with Apple, use Sign in with Apple.</p>

<h2>My alarm didn't ring on silent</h2>
<p>On iOS 26 and later, FlexUp schedules a real alarm that rings through silent mode — allow alarms when asked. On earlier
versions it sends time-sensitive notifications, which follow your silent switch.</p>

<h2>Delete my account</h2>
<p>In the app: Today → Stats → Delete account. This removes everything stored on our server.</p>

<h2>Privacy</h2>
<p>See our <a href="/privacy">privacy policy</a> and <a href="/terms">terms of use</a>.</p>`,
  );
}
