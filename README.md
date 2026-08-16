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
package — no secret is compiled into the app. Extracted results are stored
locally in Hive (no Firebase writes for prescription data). Supabase remains
responsible for **authentication only**.

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
- Phase 3: secure schema, private Storage and RLS migration applied
- Phase 4: Supabase email/password authentication and SMTP configured
- Phase 5: camera, crop, validation and private upload pipeline completed
- Phase 6: **Direct Gemini vision** — image is sent straight to Gemini (no Supabase Edge Function); structured result stored locally in Hive.
- Phase 7: local history, result and deletion completed; feedback/report is acknowledged locally.

## Security rules

- Never place Gemini or Supabase secret/service keys in Flutter source.
- Flutter receives only a Supabase publishable key (auth).
- Gemini API key is fetched at runtime from Firestore (`admin_api_keys`) via the admin_api_key_manager package.
- The original prescription image is processed locally and never uploaded to a server; only the structured result is kept (in local Hive).

