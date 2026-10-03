# AGENTS.md — Prescription Scanner

<!-- flutter-builder:agent-pack:start v1.13.0 -->
## Rule #1 — CI is manual; preflight is your check

This repository runs CI **only when the human dispatches it** (Actions → *Flutter
CI* → Run workflow). Nothing runs on a push. So:

- Work lands on `main` **directly** — no feature branch, no pull request.
- Do **not** wait for a run after pushing. Nothing started; waiting only wastes
  time.
- `tool/preflight.py` is your only automatic check. Run it before every push —
  it is seconds, not minutes, and catches the mistakes that would otherwise
  surface in the next manual CI run.
- **Dart edits get a real check, not a guess.** `preflight.py` cannot see a
  type error or a failing widget test, so install the SDK once per session
  (~40 s, no credentials) and run `flutter analyze` — plus `flutter test` before
  asking for CI. Everything else (Markdown, YAML, scripts, docs) still ships on
  preflight alone. See *Checking Dart for real* below.
- **When CI does run, it is the source of truth** — read its result before
  calling a batch done. But it runs when the human says so, not on your push.

```bash
python3 tool/preflight.py     # before every push: dead code / unused params / unused imports
python3 tool/agent_loop.py -m "fix(scope): what changed"   # preflight + commit + push, one call
```

### What a check costs

| Check | Cost | When it is the right check |
|---|---|---|
| `python3 tool/preflight.py` | ~1 s | every change, before every push |
| `flutter analyze` (via flutter-bootstrap) | 40 s once per session, then ~20 s | any Dart change |
| `flutter test` | 1–3 min | any behaviour change, before asking for CI |
| `python3 tool/see_screen.py` | one CI run | before and after a UI change |
| The human's CI run | the human's attention + a runner | once per finished batch — never per edit |

Pick the cheapest check that actually covers the change. Building the whole app
to answer a question `flutter analyze` can answer is the most common way to turn
a two-minute task into a twenty-minute one.

### Checking Dart for real (flutter-bootstrap)

The sandbox starts without a Flutter SDK, and one installed now is gone next
session. `flutter-bootstrap` installs a working SDK in ~40 seconds, with no
credentials and a sha256-verified download:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Keshab1997/flutter-bootstrap/main/setup.sh) --quiet --json
cd <app-dir> && flutter pub get && flutter analyze && flutter test
```

- `flutter analyze` is the minimum for any Dart change — it catches exactly what
  preflight cannot, in ~20 seconds.
- `flutter test` before asking the human to run CI, whenever behaviour changed.
- CI pins its own Flutter version: a local pass is *indicative*, not final. When
  the two disagree, CI wins — do not "fix" code to satisfy the local version
  without saying so in the commit message.
- Do **not** `flutter build apk` / `flutter build aab` / `flutter build web`
  locally "just to check". That is minutes per run for an artifact only the CI
  workflow needs to produce, and the signing secrets live in CI anyway.
- Re-running that one-liner later in the same session is safe and instant (~0.2 s
  when the SDK is already there).
- Need a GitHub token in this session (to dispatch a run, read logs, push)? The
  companion repo `agent-bootstrap` pairs one with three browser clicks; pushing
  with `git` over HTTPS may already work, in which case skip it.

## The batch loop — many small changes, one push, one CI run

Small edits are cheap; CI runs are not. So batch them instead of running CI per
change:

1. **Edit** the smallest diff that does one thing.
2. **`python3 tool/preflight.py`** — 1 second, no SDK. Fix what it reports.
3. **Commit and push to `main`.** `python3 tool/agent_loop.py -m "…"` does
   preflight, the secret guard, the commit and the push in one call. Repeat for
   each small change; every commit goes straight to `main`.
4. **Do not wait for CI.** Nothing started. Keep working.
5. **When the batch is ready, tell the human** to run CI once (Actions → *Flutter
   CI* → Run workflow). If a run is already in flight, `python3 tool/ci_watch.py`
   prints the conclusion of every workflow plus the interesting lines of the
   failed ones.

Rules of thumb: a CI run per push wastes the most time; push freely, run CI once
per batch. When a red run does arrive, read the log before editing — guessing at
a red build doubles the rounds.

### The same loop as one command

`tool/agent_loop.py` performs preflight, the secret guard, the commit and the
push in a single call:

```bash
python3 tool/agent_loop.py -m "fix(profile): guard a null avatar"
python3 tool/agent_loop.py -m "fix(profile): drop the unused import" --amend
python3 tool/agent_loop.py -m "chore: wip" --no-push     # commit without pushing
python3 tool/agent_loop.py -m "…" --watch                # wait, only if a run is in flight
```

It refuses, before touching the repository, when

- a staged file looks like a credential (`.env`, `*.jks`, `*.keystore`, `*.pem`,
  `key.properties`, `google-services.json`, `secrets/**`, …) — a refusal costs
  one edit, a leaked keystore costs a rotation;
- `preflight.py` reports anything — use `--no-preflight` only when the findings
  are deliberate.

It commits on the current branch (normally `main`) and pushes there; no branch,
no pull request. Exit codes: `0` committed/pushed, `1` the push failed,
`2` refused before changing anything. An `--amend` push uses
`--force-with-lease`, never a bare `--force`.

## Seeing a screen — look, do not guess

You cannot run the app, but you can *see* it. `tool/see_screen.py` asks CI to
build the app for web and photograph the routes you name, waits for the run,
downloads the images and prints their paths. Then open them — with your image
tool, not your imagination:

```bash
python3 tool/see_screen.py --route /settings           # one screen
python3 tool/see_screen.py --route / --route /profile  # several, one build
python3 tool/see_screen.py --route /settings --wait-ms 12000   # slow first frame
```

* **Use it before and after a UI change.** Before: see what the screen looks
  like now. After: see what your change did. A green CI says the code compiles;
  only the picture says the layout is right.
* This is the one thing that does start a run — it dispatches the UI-screenshots
  workflow itself, so use it deliberately, not on every edit.
* The routes are the app's own (`/settings`, `/profile`) — the same names the
  app navigates to. A screen behind a login or several taps cannot be reached
  this way; ask the human for a screenshot of that one instead.
* It is the **web** build: layout, colours and text are faithful; fonts and
  platform widgets differ, and camera/bluetooth/notification plugins render as a
  blank screen. The script says so when the pixels are flat — believe it rather
  than "fixing" the capture.
* `--out` defaults to `.agent-screens/` (git-ignored). The images are throwaway
  artifacts: never commit them, and never use one as a test fixture.
* No token? `gh auth login` once, or pass `--token-file`.

## Four things that cost an hour here (do not do them)

1. **Waiting for CI after a push.** Nothing was queued — see the manual-only
   table below. Waiting is pure loss.
2. **Running a full build to check a Dart edit.** `flutter build apk|aab|web`
   takes minutes and proves nothing `analyze` + `test` did not already prove.
3. **Asking the human for a CI run before preflight, `analyze` and `test` are
   green.** A red run spends their attention and a runner, and tells you what a
   twenty-second local check would have.
4. **Guessing at a red build.** Read the failing step's log first (below). A
   guess that misses doubles the rounds, which is the whole cost this file
   exists to avoid.

## What a push costs here

| Situation | What runs |
|---|---|
| Push to `main` (any change) | nothing — CI is manual |
| Docs-only change (`**.md`, `docs/**`, `distribution/**`) | nothing |
| You ask the human to run CI | CI once, for the whole batch |
| `flutter analyze` / `flutter test` (via flutter-bootstrap) | nothing on GitHub — 40 s to install once per session, then seconds to minutes |
| `see_screen.py` | the UI-screenshots workflow, once per call |

If you want a run right now, do **not** retrigger it with an empty commit — use
*Actions → Run workflow* (or ask the human to).

## CI map

| Workflow | Runs when | What it does |
|---|---|---|
| `ci.yml` → shared `flutter-build.yml` | **manual** (`workflow_dispatch`) | `dart format` check → `flutter analyze --fatal-infos` → `flutter test` + coverage |
| `web-preview.yml` | manual dispatch, branch delete | builds the web app, deploys `preview/<branch>/` to GitHub Pages |
| `manual-build.yml` | manual dispatch | APK / AAB artifact |
| `publish-release.yml` | manual dispatch | signed build → tag → GitHub Release (+ Play internal if configured) |
| `release.yml` | `v*` tag push | signed AAB artifact for the tag |

The reusable workflows are pinned by tag; bump the pin in one place
(`.github/workflows/*.yml`) and every project picks the change up.

## Reading CI without wasting a turn

```bash
python3 tool/ci_watch.py                       # HEAD commit, waits, prints failures
python3 tool/ci_watch.py --branch main         # newest runs of a branch
python3 tool/ci_watch.py --once                # no waiting: current state only
python3 tool/ci_watch.py --sha <sha>           # a specific commit
python3 tool/ci_watch.py --token-file secrets/gh_token.txt
```

Token order: `--token-file`, then `$GITHUB_TOKEN` / `$GH_TOKEN`, then `gh auth
token`. Never print a token, and never paste one into a log or a commit.

Raw API equivalents, if you need them:

```bash
GET /repos/{owner}/{repo}/actions/runs?head_sha=<sha>     # run list + conclusions
GET /repos/{owner}/{repo}/actions/runs/{run_id}/jobs      # failing job and step
GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs      # plain-text log
```

The log endpoint answers with a **302 to blob storage**; the pre-signed URL
rejects a request that still carries the `Authorization` header
(`InvalidAuthenticationInfo`), so strip it on redirect — `ci_watch.py` does.

## Working rules

- **Small, focused diffs.** One concern per commit; conventional commit
  messages (`fix(profile): …`, `feat(cv): …`, `chore(ci): …`).
- **Push straight to `main`.** No feature branch, no pull request. Batch small
  changes and let the human run CI once at the end.
- **Secrets never enter git:** `google-services.json`, `android/key.properties`,
  `*.jks` / `*.keystore`, `.pem`, tokens. CI receives them from repository
  secrets. Do not add them to the repo to "make CI pass".
- **Respect existing structure:** edit existing files over adding new ones, and
  read the file you are about to change (comments explain *why* the code is the
  way it is — keep that voice).
- **Match the check to the change** — the cost table near the top of this file
  is the map. Cheap checks run every time; CI runs once, at the end.

## Ask the human before

- running CI, when a batch is ready to be checked (they own the run button);
- **tagging a release**, or touching workflows / secrets / repository settings;
- force-pushing over history you do not own, or deleting branches, tags, or
  repository content;
- anything that publishes publicly, spends money, or is irreversible.

## মানুষের জন্য — এই ফাইলটা কী

- **দুই স্তরের যাচাই:** ছোট পরিবর্তনে agent নিজেই `preflight.py` চালায়
  (~১ সেকেন্ড); Dart কোড বদলালে `flutter-bootstrap` দিয়ে Flutter SDK বসিয়ে
  `flutter analyze` আর দরকারে `flutter test` চালায় — অর্থাৎ ভাঙা কোড আপনার
  CI পর্যন্ত পৌঁছায় না।
- **সরাসরি `main`-এ push** — branch নেই, PR নেই। push করলে CI নিজে থেকে চলে না।
- **CI চালানোর বোতাম আপনারই** — একটা batch শেষ হলে একবার চালালেই যথেষ্ট।
- **UI বদলালে ছবি দেখে যাচাই** — `python3 tool/see_screen.py`।
- **agent আগে অনুমতি নেবে** — tag/release, secrets, store metadata, বা যা
  ফিরিয়ে আনা যায় না এমন কিছুর আগে।
- এই ব্লকটা `install-agent-pack.sh` চালালে নিজে থেকেই update হয়; নিচের
  আপনার নিজের notes কখনো মোছা হয় না।

<!-- flutter-builder:agent-pack:end -->

Repository-specific instructions for coding agents working on this project.

## Product and repository

Prescription Scanner is an Android-first Flutter application by Keshab Studios. It transcribes visible prescription details with Google Gemini and presents a structured, review-oriented result. It must never diagnose, prescribe, recommend treatment, or silently guess unclear medical text.

Main directories:

- `apps/mobile` — Flutter Android user application
- `apps/admin` — Flutter Web administrator console
- `apps/admin/firestore.rules` — current Firestore authorization rules
- `docs` — setup and implementation notes
- `design` — approved KS mascot/icon assets
- `supabase` — legacy reference implementation; not used by the current runtime

Current identifiers:

- Android application ID: `com.keshabstudios.prescriptionscanner`
- Firebase project: `prescription-scanner-admin`
- Primary verified admin email fallback: `Keshabsarkar2018@gmail.com`
- First market: India
- Primary UI language: English, with Bengali/Hindi result summaries

## Current architecture

### Authentication and cloud data

- Firebase Authentication provides email/password sign-in.
- Mobile users must verify their email before Home, Firestore settings or scanning are available.
- Firestore stores profiles, app settings, per-user daily usage, feedback and deletion requests.
- The admin web app requires a verified user plus either:
  - Firebase custom claim `admin: true`, or
  - the configured admin email fallback.
- Firestore rules are the final security boundary. UI checks are not authorization.

### Prescription processing

- The mobile app prepares/compresses the image locally.
- The prepared image is sent directly from the device to Google Gemini.
- Do not claim that image processing is entirely on-device or that the image never leaves the phone.
- The app does not upload prescription images to its own Firebase/Supabase storage.
- The prepared local image is deleted after processing.
- Structured prescription results remain locally in Hive and are namespaced by Firebase UID.

### Local user isolation

- Results box: `ks_results_v2`
- Consent box: `ks_consent_v2`
- Result key format: `{firebaseUid}::{prescriptionId}`
- Every result includes `_owner_uid` and must be checked against the active Firebase UID.
- Legacy owner-less `rx_results` and shared `rx_consent` data are deleted rather than assigned to an arbitrary user.
- Account deletion clears only that UID's local results and consent.
- Never reintroduce unscoped `getAll()`, `get(id)`, `save(result)` or `delete(id)` APIs.

### Gemini key pool

- `admin_api_key_manager` reads Gemini keys from Firestore collections `admin_api_keys` and `admin_key_groups`.
- `ApiKeyManager` starts lazily only after a verified user begins a scan.
- A Gemini key fetched by a client application is not a true secret. The current direct-client design is temporary compatibility; a backend proxy is recommended before a high-risk production launch.
- Never hardcode Gemini keys, service-account credentials, JWTs or private keys.

## Firestore data model

Mobile collections:

- `profiles/{uid}`
  - `displayName`, `email`, `role`, `status`, `createdAt`, `updatedAt`
  - users may only edit `displayName` and `updatedAt`
- `app_settings/1`
  - `daily_limit`
  - `ai_enabled`
  - `maintenance_mode`
  - `updated_at`
- `daily_usage/{uid}-{yyyy-MM-dd}`
  - `user_id`, `usage_date`, `request_count`, `successful_count`, `failed_count`, `updated_at`
- `prescription_feedback/{autoId}`
  - must contain the authenticated `user_id`
- `account_deletion_requests/{uid}`

Administrative collections:

- `admin_api_keys`
- `admin_key_groups`
- `api_error_logs`
- `admin_alerts`
- `admin_contacts/primary`

When changing fields, update all of these together:

1. mobile/admin Dart code
2. `apps/admin/firestore.rules`
3. tests
4. documentation when behavior or privacy wording changes

Validate rules locally from `apps/admin`:

```bash
npx --yes firebase-tools@14.12.1 \
  emulators:exec --only firestore \
  --project demo-prescription-scanner \
  "echo rules-ok"
```

Rules are not live until manually deployed/published:

```bash
cd apps/admin
firebase deploy --only firestore:rules
```

## Firebase configuration

Mobile configuration:

- `apps/mobile/lib/firebase_options.dart`
- `apps/mobile/android/app/google-services.json`
- Android Firebase app ID must correspond to `com.keshabstudios.prescriptionscanner`.

Current Android Firebase app ID:

```text
1:780785545429:android:43c8668bd33be20a4eb25c
```

When package registration changes, regenerate with `flutterfire configure` and ensure Dart options and `google-services.json` still match.

Admin configuration:

- `apps/admin/lib/firebase_options.dart`
- `apps/admin/.firebaserc`
- `apps/admin/firebase.json`

Do not call a Firebase client API key a private secret. Do treat service-account JSON and Admin SDK credentials as secrets.

## Mobile navigation rules

- Back navigation is handled before Navigator deactivation with `BackButtonListener`.
- Do not navigate synchronously from `PopScope.onPopInvokedWithResult`; this previously triggered Flutter's `_dependents.isEmpty` assertion.
- Pushed standalone pages pop to their real previous page.
- Root standalone pages use a safe fallback route.
- Shell pages return to Home.
- Home shows an explicit exit confirmation.
- Add/update tests in `apps/mobile/test/app_back_scope_test.dart` for navigation changes.

## Animation and layout rules

Animations must be paint-only when surrounding content must stay fixed.

- Do not animate parent width, height, margin or padding for ripple effects.
- Use fixed `SizedBox`/constraints, `ClipRect`, `Stack`, `Positioned`, `Transform`, opacity and `RepaintBoundary`.
- `PulseRing` children must not participate in parent layout sizing.
- Keep New Scan preview height fixed at 320 and its animation viewport fixed at 132 unless an approved design change requires otherwise.
- Test small, middle and expanded animation frames at 320, 360 and 412 logical-pixel widths.

Relevant tests:

- `apps/mobile/test/pulse_ring_layout_test.dart`
- `apps/mobile/test/scan_preview_layout_test.dart`

## Medical and privacy requirements

- Transcription only; no diagnosis or treatment recommendation.
- Never guess medicine name, strength, dose, frequency, duration or route.
- Missing/unclear fields must stay null or be marked for manual review.
- Do not log images, extracted prescription content, user tokens or API keys.
- User-facing privacy text must accurately state that Google Gemini receives the prepared image.
- Do not say “nothing is uploaded” or “the image never leaves the device.”
- Results are local and UID-scoped; feedback and operational usage are stored in Firestore.

## Flutter workflow

Required SDK for CI:

```text
Flutter 3.38.4
Dart 3.10.3
Java 17 for Android builds
```

Mobile validation:

```bash
cd apps/mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

Admin validation:

```bash
cd apps/admin
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web
```

CI workflow:

- `.github/workflows/mobile_ci.yml` validates both mobile Android and admin web.
- `.github/workflows/manual_android_build.yml` calls the reusable `Keshab1997/flutter-builder@v1` workflow for a manual APK build.
- Formatting failures are blocking; do not use `continue-on-error`.

Prefer targeted tests while editing, then run the complete relevant suite before claiming verification. Never say a fix passed unless the command or CI job actually passed.

## Android notes

Important files:

- `apps/mobile/android/app/build.gradle.kts`
- `apps/mobile/android/settings.gradle.kts`
- `apps/mobile/android/app/src/main/AndroidManifest.xml`
- `apps/mobile/android/app/src/main/kotlin/com/keshabstudios/prescriptionscanner/MainActivity.kt`

Requirements:

- Main manifest must include `INTERNET` and `CAMERA`.
- Keep the AdMob metadata valid while `google_mobile_ads` is installed.
- Do not use debug signing for a Play Store release.
- For startup crashes, obtain the fatal `adb logcat` stack before broad refactors.

## Admin requirements

- Never render the Dashboard for a merely signed-in user.
- Keep `apps/admin/lib/admin_authorization.dart` aligned with Firestore `isAdmin()`.
- Admin email matching is case-insensitive in both Dart and Firestore rules.
- Password input must never be trimmed.
- Settings page owns `app_settings/1` and `admin_contacts/primary` with merge semantics.
- Permission-denied errors should explain that a verified administrator and published rules are required.

## Legacy Supabase code

The current app does not use Supabase Auth, Storage or Edge Functions. Do not extend these unless the architecture is explicitly changed:

- `supabase/migrations`
- `supabase/functions`
- `supabase/config.toml`
- `docs/supabase_*`

Keep legacy files for reference or move them in a dedicated cleanup task; do not mix Supabase and Firebase runtime paths accidentally.

## Agent operating rules

- Search narrowly before reading large files.
- Do not inspect generated/cache/build folders unless directly relevant.
- Avoid unrelated refactors and formatting churn.
- Format changed Dart files before committing.
- Preserve user-created assets unless a requested design change replaces them.
- Ask before changing package ID, branding, quota/product policy, medical disclaimers, backend architecture or deleting user data.
- Ask before publishing, deploying or pushing externally.
- Batch GitHub changes when possible so Device Flow authorization is requested once, not after every small edit.
- Never request a PAT, private key or service-account secret in chat.

Ignored/generated paths include:

- `.dart_tool`
- `build`
- `.gradle`
- `.idea`
- `.vscode`
- coverage output
- local `.env*` files

## Final response style

When the user writes Bangla/Banglish, respond concisely in Bangla/Banglish.

Always state:

- what changed
- exact files changed
- tests/build commands actually run
- pass/fail status
- any remaining manual deploy/publish step
