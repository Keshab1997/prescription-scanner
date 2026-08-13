# Phase 7 — Database-backed results and history

## What this phase adds

- Real daily quota from `get_my_quota()`.
- Real recent prescriptions and complete history from user-owned rows protected by RLS.
- Structured result details with transcription confidence, review states, medicine fields, visible tests/follow-up, and AI uncertainty warnings.
- Clear source-image deletion status.
- User-owned extraction issue reports.
- Permanent deletion of completed history only after its private source image has been deleted.
- Result navigation uses and validates the real prescription UUID returned by the processing function.

## Deploy the Phase 7 migration

**Project status: successfully deployed on 13 August 2026.** The steps below remain the setup record for another environment.

The first three migrations are already deployed. In Supabase Dashboard → SQL Editor, run the complete contents of:

```text
supabase/migrations/202608130004_history_feedback.sql
```

A successful run creates `prescription_feedback`, enables RLS, and creates `delete_my_completed_prescription(uuid)`.

Do not continue to feedback/deletion acceptance tests until this migration succeeds.

## Local Flutter validation

The hosted workspace does not include Flutter. On a development computer with stable Flutter 3.38.1 or newer:

```bash
cd apps/mobile
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test test/app_smoke_test.dart
flutter run --dart-define-from-file=.env.local.json
```

Create the ignored local `.env.local.json` with only public mobile configuration:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY",
  "APP_ENV": "development"
}
```

Use the Supabase publishable key only. Never add the service-role key or Gemini key to Flutter.

## Authenticated synthetic-data acceptance test

Use only a synthetic or fully de-identified prescription image. A ready-made fictional test image is included at:

```text
test_assets/synthetic_prescription_acceptance.png
```

Copy or download it to the test phone; it contains no real patient or clinician data.

1. Register/sign in through the mobile app.
2. Pull to refresh Home and confirm today’s quota loads.
3. Tap **Scan prescription** and select a clear synthetic image.
4. Accept the current AI-processing consent if prompted.
5. Confirm upload leads to the processing screen.
6. Confirm processing opens a result for the same real prescription UUID.
7. Verify medicine count, expandable details, confidence, uncertain-field labels, warnings, tests/follow-up, and the non-medical-advice notice.
8. Confirm the source-image-deleted notice appears after successful cleanup.
9. Open History and confirm the same record and status appear.
10. Submit a non-sensitive extraction issue report.
11. Delete the completed record and confirm it disappears from History and Home.

## Safe server-side inspection

If processing fails, first review Dashboard → Edge Functions → `process-prescription` → Logs. You may also inspect non-image operational fields in SQL Editor:

```sql
select
  id,
  status,
  provider,
  model,
  overall_confidence,
  error_code,
  image_deleted_at,
  created_at,
  processed_at
from public.prescriptions
order by created_at desc
limit 10;

select
  prescription_id,
  request_status,
  provider_status_code,
  latency_ms,
  provider_attempts,
  response_schema_version,
  error_code,
  created_at
from public.ai_request_logs
order by created_at desc
limit 10;
```

Do not paste prescription images, API keys, access tokens, or patient data into chat or bug reports.

## Expected privacy behavior

- Source images remain private.
- Successful extraction triggers Storage deletion, then records `image_deleted_at`.
- The app never requests diagnosis, treatment, or medicine recommendations.
- Structured results remain user-owned and readable only through authenticated RLS access.
- Completed-history deletion is refused until source-image cleanup has been confirmed.
