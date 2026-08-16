# AGENTS.md — Prescription Scanner

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
