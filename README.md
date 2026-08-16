# Prescription Scanner

Android-first prescription transcription app by **Keshab Studios**.

- App ID: `com.keshabstudios.prescriptionscanner`
- First market: India
- First language: English
- First AI provider: Gemini
- Support: keshabsarkar2018@gmail.com

## Structure

```text
apps/mobile       Flutter Android user app
apps/admin        Flutter Web admin foundation
design            Approved icon source
supabase          Migrations and Edge Functions (auth + legacy)
docs              Product and implementation notes
```

## Vision architecture (Supabase-free)

Prescription transcription now calls **Google Gemini directly from the app**
(no Supabase Edge Function). Gemini API keys live in a Firestore
`admin_api_keys` collection and are read at runtime via the reused
[`admin_api_key_manager`](https://github.com/Keshab1997/admin_api_key_manager)
package. Extracted results are stored locally in UID-scoped Hive records;
Firebase Authentication handles sign-in, while Firestore stores profiles,
settings, per-user usage and feedback.

See [docs/vision_setup.md](docs/vision_setup.md) for the full setup.

## Run the Android app

Android platform files are tracked with the final package ID. On a development computer with stable Flutter 3.38.4 or newer:

```bash
cd apps/mobile
flutterfire configure        # generates lib/firebase_options.dart
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=.env.local.json
```

Use `scripts/bootstrap_flutter_android.sh` only to regenerate missing Android files. It restores package ID `com.keshabstudios.prescriptionscanner`, permissions, auth callback, AdMob test metadata, and crop activity.

GitHub Actions workflow `.github/workflows/mobile_ci.yml` automatically analyzes, tests, and builds a debug APK on every push to `main`.

## Current status

- Phase 0: complete
- Phase 1: UX approved
- Phase 2: Flutter foundation created
- Phase 3: legacy Supabase schema retained for reference; current runtime is Firebase-based.
- Phase 4: Firebase email/password authentication with verified-email enforcement.
- Phase 5: camera, image preparation, validation and local cleanup completed.
- Phase 6: **Direct Gemini vision** — image is sent straight to Gemini; structured result is stored in per-user local Hive data.
- Phase 7: per-user local history/deletion plus UID-scoped Firestore usage and feedback completed.

## Security rules

- Never place service-account credentials or private keys in Flutter source.
- Firebase client configuration is public and protected by Authentication, App rules and per-user ownership checks.
- Gemini API keys are currently fetched at runtime from Firestore (`admin_api_keys`) for direct client calls. This is temporary compatibility, not true secret storage; a production backend proxy is still recommended.
- The prepared prescription image is sent directly to Google Gemini for transcription and is not stored in this app's cloud database. The local prepared copy is deleted after processing; account-scoped structured results remain on-device in Hive.

