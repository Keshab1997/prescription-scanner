# Prescription Scanner

Android-first prescription transcription app by **Keshab Studios**.

- App ID: `com.rxscanlabs.prescriptionscanner`
- First market: India
- First language: English
- First AI provider: Gemini
- Support: keshabsarkar2018@gmail.com

## Structure

```text
apps/mobile       Flutter Android user app
apps/admin        Flutter Web admin foundation
design            Approved icon source
supabase          Migrations and Edge Functions (Phase 3)
docs              Product and implementation notes
```

## Run the Android app

Android platform files are tracked with the final package ID. On a development computer with stable Flutter 3.38.4 or newer:

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=.env.local.json
```

Use `scripts/bootstrap_flutter_android.sh` only to regenerate missing Android files. It restores package ID `com.rxscanlabs.prescriptionscanner`, permissions, auth callback, AdMob test metadata, and crop activity.

GitHub Actions workflow `.github/workflows/mobile_ci.yml` automatically analyzes, tests, and builds a debug APK on every push to `main`.

## Current status

- Phase 0: complete
- Phase 1: UX approved
- Phase 2: Flutter foundation created
- Phase 3: secure schema, private Storage and RLS migration applied
- Phase 4: Supabase email/password authentication and SMTP configured
- Phase 5: camera, crop, validation and private upload pipeline completed
- Phase 6: Gemini Edge Function deployed; Gemini 3.6 Flash and authenticated processing enabled
- Phase 7: database-backed quota, results, recent records and history source completed; feedback/deletion migration deployed; Flutter/device validation pending

## Security rules

- Never place Gemini or Supabase secret/service keys in Flutter source.
- Flutter receives only a Supabase publishable key.
- Gemini calls happen in authenticated Supabase Edge Functions.
- Prescription images are private and deleted after successful extraction.
