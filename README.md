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

## Bootstrap Android files

The hosted workspace does not contain Flutter SDK. Generate platform files with the stable SDK installed on the development computer:

```bash
./scripts/bootstrap_flutter_android.sh
cd apps/mobile
flutter run
```

The script forces the final package ID to `com.rxscanlabs.prescriptionscanner`.

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
