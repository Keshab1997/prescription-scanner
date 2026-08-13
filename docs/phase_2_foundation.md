# Phase 2 — Flutter Foundation

## Confirmed identity

- App: Prescription Scanner
- Developer: Keshab Studios
- Support: keshabsarkar2018@gmail.com
- Android package: com.rxscanlabs.prescriptionscanner
- Launch market: India
- UI: English
- AI provider: Gemini

## Implemented

- Mobile Flutter package and dependency manifest
- Material 3 design tokens matching the approved prototype
- Riverpod application root
- go_router navigation
- Login, Home, Upload, Processing, Result, History and Profile UI
- Mock extraction result with clear/unclear confidence states
- Privacy copy for automatic raw-image deletion
- AdMob placeholder only on Home
- Flutter Web admin foundation
- Android bootstrap script that preserves the final package ID
- Smoke test and lint configuration
- Environment example with public values only

## Completed after this foundation

- Secure Supabase database migration and RLS applied
- Private Storage bucket and ownership policies applied
- Email/password Auth source implemented
- Registration, email verification, reset-password and session routing implemented
- Account-deletion request connected to the database RPC

## Not connected yet

- Real-device Auth acceptance test and Dashboard redirect confirmation
- Real image picker/camera
- Gemini processing Edge Function
- UMP and AdMob ad units

No secret should be added to the mobile app.

## Validation limitation

Flutter SDK is not installed in the hosted workspace. The source and configuration were created, but `flutter pub get`, `flutter analyze` and device builds must run after executing `scripts/bootstrap_flutter_android.sh` on a computer with stable Flutter 3.38.1 or later.
