# Phase 3 — Supabase Setup

## Project connection

The project URL and publishable key supplied by the owner are intentionally **not committed** to source control. The app reads them from Dart compile-time variables.

Create a local `apps/mobile/.env` from `.env.example`, or run with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=APP_ENV=development
```

The legacy anon JWT is not needed when the new publishable key is used.

## Apply the schema

Until Supabase CLI authentication is configured, use one of these methods:

### Supabase SQL Editor

1. Open the correct Supabase project.
2. Open **SQL Editor**.
3. Paste `supabase/migrations/202608130001_initial_secure_schema.sql`.
4. Run it once as the project owner.
5. Confirm that the final result has no errors.

### Supabase CLI

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Do not share the database password, secret key, service-role key or access token in app code.

## What the migration creates

- Profiles with user/admin/super-admin roles
- Active/blocked state
- Single-row application settings
- Gemini/OpenAI/OpenAI-compatible configuration metadata
- Prescription state machine
- Structured medicine rows
- Daily quotas and rewarded bonuses
- AI request operational logs without prompts/images
- Consent records
- Account-deletion requests
- Admin audit logs
- Private `prescriptions` Storage bucket
- Ownership-based Storage policies
- Row Level Security policies
- User-safe quota/upload/deletion RPCs
- Service-role-only AI transaction RPCs

## Initial state

`ai_enabled` is deliberately `false`. The Gemini API key and model must be configured safely before enabling processing.

The raw-image retention setting is `0` days. The processing Edge Function must delete the object immediately after a successful structured result and then call `mark_prescription_image_deleted()`.

## First administrator

1. Register a normal account in the app.
2. In SQL Editor, promote only the intended account:

```sql
update public.profiles
set role = 'super_admin'
where id = (
  select id from auth.users where email = 'YOUR_ADMIN_EMAIL'
);
```

Never allow the Flutter client to update `role`, `status`, limits or AI configuration.

## Required verification

- User A cannot select User B's profile, prescriptions or medicines.
- Authenticated users cannot read AI provider configuration or request logs.
- Authenticated users cannot call service-role AI RPCs.
- Upload paths must start with the authenticated user's UUID.
- The Storage bucket remains private.
- Creating a scan while AI is disabled returns `AI_DISABLED`.
