# AGENTS.md — Prescription Scanner

Project-specific instructions for ZCode/AI agents working in this repository.

## Project summary

Prescription Scanner is an Android-first Flutter app by Keshab Studios for AI-assisted prescription transcription.

Main parts:

- `apps/mobile` — Flutter Android user app
- `apps/admin` — Flutter Web admin foundation
- `supabase` — database migrations and Edge Functions
- `docs` — implementation notes and deployment docs
- `design` — approved visual assets

Current app direction:

- First market: India
- First language: English
- AI provider: Gemini through Supabase Edge Functions
- Android package/app ID target: `com.rxscanlabs.prescriptionscanner`

## Token-saving workflow

Use the smallest useful context first.

1. For questions about architecture or file relationships, use `graphify` first if available.
2. Use focused search before reading whole files.
3. Read only the specific files/line ranges needed.
4. Do not dump generated/build/cache files unless the bug is specifically there.
5. Avoid repeatedly re-reading files after edits; trust successful edit/write tool results.
6. Prefer one targeted build/test command over many broad commands.
7. Keep final responses short, with exact file paths and commands.

Ignore these unless directly relevant:

- `.dart_tool/`
- `build/`
- `.gradle/`
- `.idea/`
- `.DS_Store`
- generated Flutter localization files unless localization is being changed
- generated plugin registrant files unless Android plugin registration is the suspected issue

## Accuracy rules

- Never guess Supabase/Gemini secrets.
- Never say a fix is verified unless a relevant command actually passed.
- If tests fail because of unrelated stale tests, say that clearly.
- If Flutter is not on PATH, use the local SDK path from `apps/mobile/android/local.properties`.
- Before deleting or overwriting user-created files, read/check them first.
- Match the surrounding Dart/Flutter style; avoid unnecessary comments.

## Security rules

- Never put Gemini API keys or Supabase service-role keys in Flutter source.
- Flutter may receive only public Supabase values: project URL and publishable/anon key.
- Gemini calls must stay inside authenticated Supabase Edge Functions.
- Prescription images are private and should be deleted after successful extraction.
- Do not log prescription image contents, extracted medical data, JWTs, or secrets.
- Do not commit local env files containing project keys.

## Supabase configuration

The mobile app reads config using Dart compile-time environment values:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `APP_ENV`

The app will show **“Supabase configuration is missing”** if it is run without these values.

Preferred local run command:

```bash
cd apps/mobile
/Users/keshabsarkar/flutter/bin/flutter run --dart-define-from-file=.env.local.json
```

Preferred local debug APK command:

```bash
cd apps/mobile
/Users/keshabsarkar/flutter/bin/flutter build apk --debug --dart-define-from-file=.env.local.json
```

Do not replace these with plain `flutter run` unless the app has been changed to load env values another way.

Local env files should be ignored:

- `.env.local.json`
- `.env*.json`

## Flutter/mobile workflow

For most mobile changes:

1. Inspect only relevant files under `apps/mobile/lib` and `apps/mobile/android`.
2. Run formatting only on changed Dart files when possible.
3. Run `flutter analyze` from `apps/mobile`.
4. Run targeted tests if applicable.
5. For Android startup/config changes, run a debug APK build.

Useful commands:

```bash
cd apps/mobile
/Users/keshabsarkar/flutter/bin/flutter analyze
/Users/keshabsarkar/flutter/bin/flutter test
/Users/keshabsarkar/flutter/bin/flutter build apk --debug --dart-define-from-file=.env.local.json
```

Known current test issue:

- `apps/mobile/test/widget_test.dart` references old template `MyApp`; this can fail even when the app build is okay.
- Prefer `apps/mobile/test/app_smoke_test.dart` for startup smoke validation until the stale template test is fixed.

## Android notes

Main Android files:

- `apps/mobile/android/app/build.gradle.kts`
- `apps/mobile/android/settings.gradle.kts`
- `apps/mobile/android/app/src/main/AndroidManifest.xml`
- `apps/mobile/android/app/src/main/kotlin/com/example/prescription_scanner/MainActivity.kt`

Startup-crash checks:

- Confirm `INTERNET` permission exists in main manifest for release/debug APK behavior.
- If `google_mobile_ads` is included, ensure main manifest has `com.google.android.gms.ads.APPLICATION_ID` metadata.
- If app opens then closes immediately, ask for or collect `adb logcat` fatal exception output before broad refactors.

## Supabase workflow

Supabase files:

- `supabase/migrations/`
- `supabase/functions/`
- `supabase/config.toml`
- `docs/supabase_*`

Rules:

- Use migrations for schema/RLS changes.
- Keep Edge Function secrets in Supabase secrets, never in repo.
- For Edge Function changes, inspect related docs before changing behavior.
- Validate auth, RLS, private storage, and cleanup behavior when touching upload/processing flow.

## BrowserClaw workflow

Use BrowserClaw only when the user's logged-in browser session is needed, for example Supabase dashboard checks.

Token-saving browser loop:

1. `tabs` list/new
2. `grep` for specific text or controls
3. `act` click/fill
4. `diff` to verify
5. use `snapshot` only as last resort
6. close the tab when done

Never use Playwright browser tools unless the user explicitly asks.

## When to ask before changing

Ask the user first when:

- changing app branding, package ID, pricing/quota, auth flow, or medical disclaimer text
- adding paid services or external integrations
- deleting data, migrations, assets, or generated deliverables
- replacing Supabase project settings or secrets
- publishing, deploying, pushing, or uploading anything external

No need to ask for straightforward fixes such as:

- manifest permission/meta-data fixes
- stale test import/name fixes
- formatting changed files
- adding ignored local config files for user-provided public keys

## Final response style

Use concise Bangla/Banglish when the user writes Bangla/Banglish.

Include:

- what changed
- exact file path(s)
- exact command(s) run
- whether build/tests passed or failed
- next command the user should run

Avoid long explanations unless the user asks.
