# 💊 Prescription Scanner

> **Android-first prescription transcription app by Keshab Studios** — আপনার ক্যামেরা দিয়ে প্রেসক্রিপশন স্ক্যান করুন, আর AI সেটিকে সাজানো, খোঁজা-যাওয়া মেডিসিন ডেটায় রূপান্তর করে দেবে।  
> *Point your camera at a prescription, and AI turns it into structured, searchable medicine data.*

| | |
|---|---|
| 📱 **App ID** | `com.keshabstudios.prescriptionscanner` |
| 🌏 **First market** | India |
| 🇬🇧 **First language** | English (localization-ready) |
| 🤖 **AI provider** | Google Gemini (direct from app) |
| 🔥 **Backend** | Firebase (Auth + Firestore + Hosting) — **no Supabase** |
| 📧 **Support** | [keshabsarkar2018@gmail.com](mailto:keshabsarkar2018@gmail.com) |

---

## 🚨 Supabase removed

> ✅ **Supabase সম্পূর্ণ বাদ দেওয়া হয়েছে।** অ্যাপটি এখন সম্পূর্ণ **Firebase-ভিত্তিক** চলে — কোনো Supabase client, Edge Function বা ডেটাবেস ব্যবহার হয় না।  
> The app no longer uses Supabase. All runtime code is Firebase-based, and the legacy `supabase/` folder and `docs/supabase_*` files have been **removed from this repository**.

---

## ✨ Key features

- 📸 **Camera-first scanning** — capture or pick a prescription photo, with automatic image compression and validation.
- 🆓 **Free guest scans** — try **1 free scan per day** without an account, then sign in to unlock **2 more free scans** (3/day in total).
- 🧠 **Direct Gemini vision** — the prepared image is sent straight to Google Gemini (`gemini-2.5-flash`); no backend proxy involved.
- 📋 **Structured results** — AI output is parsed and repaired into a consistent JSON medicine list (medicine, dosage, frequency, duration, notes).
- 💾 **On-device history** — results are stored locally in **Hive**, scoped to the signed-in user's UID; delete anytime.
- 🔐 **Secure sign-in** — Firebase Authentication with email/password and **verified-email enforcement**.
- 🗂️ **Usage & feedback tracking** — per-user usage and feedback synced to Firestore, UID-scoped.
- 🛡️ **Runtime-managed AI keys** — Gemini keys are fetched at runtime from Firestore via the reused [`admin_api_key_manager`](https://github.com/Keshab1997/admin_api_key_manager) package (with cooldowns & usage counting). No secrets in Flutter source.
- 🖥️ **Admin web console** — Flutter Web admin (Firebase Hosting) for dashboard, API-key pool, users, usage and prescriptions management.
- 📢 **AdMob** — monetization-ready with Google Mobile Ads.

---

## 🧱 Architecture (Supabase-free)

```
┌────────────────────────────────────────────────────────────┐
│                    Flutter Android app                     │
│                       (apps/mobile)                        │
│                                                            │
│  camera ──► compress ──► validate ──► prepared image       │
│                                            │               │
│                                            ▼               │
│               Google Gemini API (direct call)              │
│               key ◄── Firestore `admin_api_keys`           │
│                      (admin_api_key_manager pkg)           │
│                                            │               │
│                                            ▼               │
│                 structured JSON result                     │
│                      │           │                         │
│                      ▼           ▼                         │
│                 Hive (local    Firestore (usage,           │
│                 UID-scoped     feedback, profile,          │
│                 history)       settings)                   │
│                                                            │
│   Firebase Auth (email/password)  ·  AdMob (ads)           │
└────────────────────────────────────────────────────────────┘
                          │
                          ▼
             ┌─────────────────────────┐
             │  Flutter Web admin app  │
             │      (apps/admin)       │
             │  dashboard · keys ·     │
             │  users · usage ·        │
             │  prescriptions          │
             └─────────────────────────┘
```

**Data flow (short version):** camera → local image preparation → direct Gemini call → repaired JSON → Hive for on-device history + Firestore for usage/feedback. Sign-in via Firebase Auth. No Supabase anywhere.

---

## 📁 Repository structure

```text
prescription-scanner/
├── apps/
│   ├── mobile/            📱 Flutter Android user app
│   └── admin/             🖥️ Flutter Web admin console (Firebase Hosting)
├── docs/                  📚 Phase & implementation notes
├── design/                🎨 Approved icon source
├── deliverables/          📦 Delivery packages (process-prescription zips)
├── test_assets/           🧪 Sample assets for tests
├── scripts/               🔧 Helper scripts
├── melos.yaml             🧩 Melos workspace config
├── AGENTS.md              🤖 Agent/contributor guide
└── README.md
```

---

## 🚀 Getting started

### Prerequisites

- [Flutter](https://flutter.dev) **3.38.4 or newer** (stable channel)
- A Firebase project with **Authentication** (email/password), **Firestore**, and (for the admin app) **Hosting**
- A [Google Gemini API key](https://aistudio.google.com/apikey)

### 1. Configure Firebase

```bash
cd apps/mobile
flutterfire configure          # generates lib/firebase_options.dart
flutter pub get
```

> Commit the generated `firebase_options.dart` whenever the Firebase registration or Android package ID changes.

### 2. Seed a Gemini API key

In the Firebase console → **Firestore**, create a document in the `admin_api_keys` collection:

```json
{
  "name": "Primary Gemini",
  "key": "AIza...your-gemini-api-key...",
  "baseUrl": "https://generativelanguage.googleapis.com",
  "model": "gemini-2.5-flash",
  "provider": "google",
  "isActive": true,
  "priority": 1,
  "usageCount": 0,
  "errorCount": 0,
  "createdAt": "<serverTimestamp>",
  "updatedAt": "<serverTimestamp>"
}
```

> ⚠️ Use a **real** model id — e.g. `gemini-2.5-flash`, `gemini-2.0-flash` or `gemini-1.5-flash`.

**Optional:** bake a key in at build time as a fallback:

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...
```

### 3. Run the app

```bash
cd apps/mobile
flutter run --dart-define-from-file=.env.local.json
```

Only use `scripts/bootstrap_flutter_android.sh` to regenerate missing Android files (it restores the package ID, permissions, auth callback, AdMob test metadata and crop activity).

### 4. Run the admin web app

```bash
cd apps/admin
flutter pub get
flutterfire configure
flutter run -d chrome
```

---

## 🧪 Testing & CI

- **Unit & widget tests** — `flutter test` (6 test files in `apps/mobile/test`)
- **Static analysis** — `flutter analyze` (zero-tolerance via `analysis_options.yaml`)
- **Melos workspace** — `melos analyze` / `melos test` runs across all apps

**GitHub Actions** (`.github/workflows/`):

| Workflow | Trigger | What it does |
|---|---|---|
| `mobile_ci.yml` | push / PR to `main` | `flutter analyze` → `flutter test` → build **debug APK** |
| `manual_android_build.yml` | manual | Manual Android build |

---

## 📍 Development status

| Phase | Status | What was delivered |
|---|---|---|
| 0 | ✅ Complete | Project kickoff, scope |
| 1 | ✅ Complete | UX approved (see `prescription_scanner_ux_prototype.html`) |
| 2 | ✅ Complete | Flutter foundation, monorepo structure |
| 3 | ✅ Complete | Legacy Supabase schema **archived** — runtime is Firebase |
| 4 | ✅ Complete | Firebase email/password auth with verified-email enforcement |
| 5 | ✅ Complete | Camera, image preparation, validation, local cleanup |
| 6 | ✅ Complete | **Direct Gemini vision** — structured result in per-user Hive data |
| 7 | ✅ Complete | Per-user local history/deletion + UID-scoped Firestore usage & feedback |

📋 Full roadmap: [`prescription_ai_app_roadmap_bn.md`](prescription_ai_app_roadmap_bn.md)

---

## 📚 Documentation

| Doc | Contents |
|---|---|
| [`docs/vision_setup.md`](docs/vision_setup.md) | Direct-Gemini vision setup (keys, models, Firestore) |
| [`docs/phase_2_foundation.md`](docs/phase_2_foundation.md) | Flutter foundation notes |
| [`docs/phase_4_auth_setup.md`](docs/phase_4_auth_setup.md) | Firebase authentication setup |
| [`docs/phase_5_upload_pipeline.md`](docs/phase_5_upload_pipeline.md) | Image upload & preparation pipeline |
| [`docs/phase_6_gemini_deployment.md`](docs/phase_6_gemini_deployment.md) | Gemini vision deployment |
| [`docs/phase_7_results_history.md`](docs/phase_7_results_history.md) | Results & history implementation |
| [`AGENTS.md`](AGENTS.md) | Contributor / agent guide |

---

## 🔒 Security notes

- 🚫 **Never** place service-account credentials or private keys in Flutter source.
- 🔑 Gemini API keys are fetched at runtime from Firestore (`admin_api_keys`) — this is a temporary compatibility design; a production backend proxy is recommended for true secret storage.
- 🖼️ The prepared prescription image is sent **only** to Google Gemini for transcription; it is not stored in the cloud. The local prepared copy is deleted after processing; account-scoped structured results stay on-device in Hive.
- 👥 Firebase client config is public by nature but protected by Authentication, App rules and per-user ownership checks.

---

## 🛠️ Tech stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3.38.4+ (Dart) |
| **Monorepo** | Melos |
| **State management** | Riverpod |
| **Routing** | go_router |
| **Backend** | Firebase (Auth, Firestore, Hosting) |
| **Local storage** | Hive (Flutter) |
| **AI vision** | Google Gemini (direct REST) |
| **Ads** | Google Mobile Ads |
| **Camera** | image_picker + flutter_image_compress |
| **Key pool** | [`admin_api_key_manager`](https://github.com/Keshab1997/admin_api_key_manager) (Firestore-backed) |

---

## 💬 Support

Questions, feedback or feature ideas? Reach out at [keshabsarkar2018@gmail.com](mailto:keshabsarkar2018@gmail.com).

<p align="center">Made with ❤️ by <b>Keshab Studios</b></p>
