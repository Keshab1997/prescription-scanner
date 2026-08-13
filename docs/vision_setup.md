# Vision setup (Direct Gemini, Supabase-free)

Prescription vision now runs **directly against Google Gemini** from the app —
no Supabase Edge Function is involved. Gemini API keys are managed by the
reused [`admin_api_key_manager`](https://github.com/Keshab1997/admin_api_key_manager)
package, which reads them from a Firestore collection at runtime (so no secret
lives in the Flutter source).

Supabase is still used for **authentication only**.

## 1. Firebase (for the key pool)

The package needs Firebase to read the `admin_api_keys` collection.

```bash
cd apps/mobile
flutter pub get
flutterfire configure      # generates lib/firebase_options.dart
```

`flutterfire configure` overwrites the placeholder `lib/firebase_options.dart`.

## 2. Seed a Gemini key

In the Firebase console → Firestore, create a document in collection
`admin_api_keys` (doc id = anything unique) with:

```json
{
  "name": "Primary Gemini",
  "key": "AIza...your Gemini API key...",
  "baseUrl": "https://generativelanguage.googleapis.com",
  "model": "gemini-2.5-flash",
  "provider": "google",
  "isActive": true,
  "priority": 1,
  "usageCount": 0,
  "errorCount": 0,
  "addedBy": "",
  "createdAt": "<serverTimestamp>",
  "updatedAt": "<serverTimestamp>"
}
```

> Use a **real** model: `gemini-2.5-flash`, `gemini-2.0-flash`, or
> `gemini-1.5-flash`. The old `gemini-3.6-flash` name does not exist and
> returns 404.

(Optional) Create `admin_key_groups` doc id `google` to tune cooldowns.

## 3. Build-time fallback (optional)

You can also bake a key in at build time (convenience only — prefer Firestore):

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...
```

This is seeded into the local Hive cache so the app works before any Firestore
key is added.

## 4. Security

- The Gemini key is fetched at runtime from Firestore, never hard-coded.
- The original prescription image is processed locally and never uploaded to a
  server; only the structured result is kept (in local Hive).
- Firestore rules: allow admin writes to `admin_api_keys`; end users only need
  read (or none — the package reads via the app's own initialized client).

## 5. Verify

```bash
cd apps/mobile
flutter analyze
```

Then run the app, capture/select a prescription image, grant AI consent, and
confirm the result screen shows the extracted medicines without any Supabase AI
call (`grep -rn "process-prescription" lib/` should show no invocations in the
scan path).
