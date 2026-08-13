# Phase 6 — Gemini Processing Deployment

## What is implemented

- Authenticated `process-prescription` Supabase Edge Function
- User ownership check through RLS before privileged work
- Current AI-consent record required server-side
- Atomic daily-quota reservation
- Private Storage download
- Gemini image input using inline bytes; no Gemini Files API
- Stateless `generateContent` request
- Strict JSON Schema structured output
- Prompt-injection defense for instructions written inside the image
- No patient/doctor/diagnosis fields in the output schema
- No diagnosis, recommendation or missing-field completion
- Confidence thresholds and forced manual-review states
- Output length/type/range validation after Gemini responds
- Transient provider retry with attempt accounting
- Safe operational logs without prompt, image or full response
- Structured result and medicine rows saved transactionally
- Original Storage object deleted after a successful result
- Flutter processing screen invokes the function and handles retry

## 1. Run the Phase 6 database migration

In Supabase SQL Editor, run:

```text
supabase/migrations/202608130003_ai_processing_support.sql
```

It adds provider-attempt/schema-version fields to AI logs and creates one service-role-only metadata RPC.

## 2. Create a Gemini API key

Create the key in Google AI Studio under the correct Google Cloud project.

Never paste the key into Flutter, Git, SQL tables, app settings, support messages or chat.

## Rate-limit architecture — do not rotate keys to bypass quota

Gemini rate limits are applied per Google Cloud project, not per API key. Multiple keys created in the same project share the same quota, so switching keys after a 429 response does not create additional capacity.

Use one production key per environment. Additional keys may be kept only for controlled credential rotation or emergency replacement—not automatic 429 avoidance. Scale through an official paid usage tier/quota increase, queueing, backoff, global RPM controls and a separately tested fallback provider/model.

## 3. Save the key in Supabase secrets

Open:

**Supabase Dashboard → Edge Functions → Secrets**

Add:

```text
Name: GEMINI_API_KEY
Value: your Gemini API key
```

Supabase encrypts the function secret. The Edge Function reads it at runtime.

## 4. Deploy the function from Dashboard

A single-file Dashboard upload bundle is ready (no relative imports):

```text
deliverables/process-prescription-v2.zip
```

The original `process-prescription.zip` has also been replaced with the corrected single-file bundle.

Dashboard steps:

1. Open **Edge Functions**.
2. Click **Deploy a new function**.
3. Choose **Via Editor**.
4. Upload or drag `process-prescription.zip` into the editor.
5. Function name must be exactly:

```text
process-prescription
```

6. In the deployed function's **Settings**, set **Verify JWT with legacy secret: OFF** for projects using the new publishable/JWKS key system.
7. Click **Save changes**, then deploy.

The legacy-only gateway check is disabled, but the endpoint is not public: the code uses `withSupabase({ auth: 'user' })`, which validates the signed-in user's JWT and rejects anonymous callers.

### CLI alternative

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase secrets set GEMINI_API_KEY=YOUR_KEY
supabase functions deploy process-prescription
```

Do not save the key in shell history on a shared machine; an environment file excluded from Git is safer.

## 5. Enable Gemini only after deployment

After the secret is saved and deployment succeeds, run in SQL Editor:

```text
supabase/setup/enable_gemini_after_secret.sql
```

This selects:

```text
gemini-3.6-flash
```

and then enables `app_settings.ai_enabled`.

## 6. Development test

Use only synthetic or properly de-identified sample prescriptions initially.

1. Register and verify an app user.
2. Sign in.
3. Capture or pick a test prescription.
4. Crop the medicine section.
5. Accept the explicit Gemini processing disclosure.
6. Upload.
7. Confirm status moves `uploaded → processing → completed/needs_review`.
8. Confirm `prescription_medicines` rows are created.
9. Confirm an `ai_request_logs` row exists without prompt/image content.
10. Confirm the private Storage object is removed and `image_deleted_at` is set.

## Data-retention warning before real-user production

Prescription images can contain sensitive health and identity data. The Gemini Developer API may retain prompts, contextual information and outputs for abuse monitoring under its applicable terms. Using stateless `generateContent`, inline bytes and no Files API reduces avoidable storage, but it does not by itself remove provider abuse-monitoring retention.

Before processing real prescriptions at production scale:

- disclose Google Gemini processing clearly in the Privacy Policy and consent screen;
- review Google's current terms and retention policy;
- use an appropriate paid project/data-control arrangement;
- consider applying for Gemini zero-data-retention controls where available;
- obtain legal/privacy review for the launch market;
- never enable optional log sharing for sensitive prescription traffic;
- use synthetic/de-identified data during development.

## Failure behavior

- Invalid/non-prescription images become `needs_review` without invented medicines.
- Provider/network errors become `failed` with a safe error code.
- A failed job may be retried if its private source image still exists.
- A successful job deletes its source image immediately.
- If Storage deletion fails twice, the result is kept but `image_deleted_at` remains empty so a cleanup job can find it.
