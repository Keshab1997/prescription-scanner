# Phase 4 — Supabase Email Authentication

## Implemented in Flutter

- Supabase session initialization through Dart defines
- Secure email/password sign-in
- Registration with display-name metadata
- Email verification success state
- Forgot-password email
- Password-recovery deep link and new-password screen
- Auth-aware route protection
- Automatic session refresh through Supabase Flutter
- Profile populated from the signed-in user
- Sign out
- Account-deletion request RPC with confirmation
- Friendly errors that do not expose backend details

## Required Supabase Dashboard settings

### 1. Enable email authentication

Open:

**Authentication → Providers → Email**

Recommended MVP settings:

- Enable Email provider: ON
- Confirm email: ON
- Secure email change: ON
- Minimum password length: 8 or higher

### 2. Add mobile redirect URL

Open:

**Authentication → URL Configuration → Redirect URLs**

Add this exact URL:

```text
com.rxscanlabs.prescriptionscanner://login-callback
```

It is used for email verification and password recovery. The Android bootstrap script adds the matching intent filter to `AndroidManifest.xml`.

### 3. Customize emails

Under **Authentication → Email Templates**, use the product identity:

- Product: Prescription Scanner
- Developer: Keshab Studios
- Support: keshabsarkar2018@gmail.com

Do not claim that the app provides medical advice.

## Run configuration

The project URL and publishable key remain outside Git:

```bash
cd apps/mobile
flutter run \
  --dart-define=SUPABASE_URL=YOUR_PROJECT_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=APP_ENV=development
```

## Manual acceptance test

1. Register a new email.
2. Confirm that an Auth user and matching `profiles` row are created.
3. Open the verification email on the Android device.
4. Confirm that the app opens through the custom callback URL.
5. Sign in and confirm that Home opens.
6. Close/reopen the app and confirm that the session remains.
7. Request a password reset and set a new password in-app.
8. Sign out and confirm that protected routes return to Login.
9. Submit account deletion and confirm a `pending` row exists in `account_deletion_requests`.

## Still required before production

- Public Privacy Policy and Terms URLs
- CAPTCHA/anti-abuse decision for registration
- Production SMTP for reliable email delivery
- Edge Function/worker that completes account deletion
- External website-based deletion request page required by Play policy
