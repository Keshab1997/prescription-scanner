# Play Store রিলিজ গাইড — Prescription Scanner

এই গাইডটি **Prescription Scanner** অ্যাপটি Google Play Store-এ রিলিজ করার step-by-step প্রসেস কভার করে। যা যা আমরা ইতিমধ্যে সেটআপ করেছি (signed AAB build, privacy policy, GitHub Release) তার সবটাই এখানে রেফারেন্স হিসেবে দেওয়া আছে।

---

## 1. Prerequisites (আগে যা লাগবে)
- একটি **Google Play Developer** অ্যাকাউন্ট (এককালীন $25 ফি)।
- **Upload keystore** — রেপোর CI-এ `ANDROID_KEYSTORE_BASE64` secret হিসেবে কনফিগার করা আছে, তাই AAB স্বয়ংক্রিয়ভাবে signed হয়।
- App version: `0.1.0+1` (`apps/mobile/pubspec.yaml`)।

## 2. AAB build করা (স্বয়ংক্রিয়)
- GitHub-এ **Manual Android Test Build** workflow ট্রিগার করো (`workflow_dispatch`)।
- এটি `Keshab1997/flutter-builder` reusable workflow ব্যবহার করে `flutter build appbundle --release` চালায়। Flutter 3.44+ এর AAB strip regression বাইপাস করতে এটি Gradle (`bundleRelease`) দিয়ে সরাসরি AAB টি build করে।
- Output: `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
- সর্বশেষ সফল build: **#22** (AAB 67.2 MB + APK 33.7 MB artifact)।

Local ভাবে করতে চাইলে:
```bash
cd apps/mobile
flutter build appbundle --release
```
> নোট: Local-এ সরাসরি `flutter build appbundle` Flutter 3.44+ এ "failed to strip debug symbols" error দিতে পারে — সেক্ষেত্রে CI workflow টিই ব্যবহার করো (যেটা gradle-bypass দিয়ে fix করা আছে)।

## 3. Privacy Policy (গুরুত্বপূর্ণ)
Play Console-এর জন্য public, accessible privacy policy লাগে। আমরা GitHub Pages-এ হোস্ট করেছি:

🔗 **https://keshab1997.github.io/prescription-scanner/privacy-policy.html**

Play Console → **App content → Privacy policy**-এর ওই URL টি বসাও।

## 4. Play Console-এ App তৈরি করা
1. Play Console → **Create app**।
2. App name: `Prescription Scanner`।
3. Default language: English (বা Bengali)।
4. App category: **Health & Fitness** / **Medical** (উপযুক্তটি বাছাই)।
5. Free না Paid ঠিক করো।

## 5. App content পূরণ
- **Privacy policy**: উপরের URL (#3)।
- **Data safety form**: নিচের তথ্য দাও (app-এর dependency অনুযায়ী):
  - Prescription images (camera / `image_picker`) — collected
  - Transcribed text (Gemini AI via `admin_api_key_manager`) — collected
  - Device info, Crash logs (`firebase_crashlytics`), Analytics (`firebase_analytics`)
  - Ads (`google_mobile_ads` / AdMob) — advertising ID
  - Local storage (`hive_flutter`) — on-device
- **Target audience**: বয়স সীমা ঠিক করো (সাধারণত 13+)।
- **Ads**: AdMob ব্যবহার করে → "Yes, the app contains ads" সিলেক্ট করো।

## 6. Store listing লেখা
- **Title**, **Short description**, **Full description**।
- **Screenshots** (phone), **Feature graphic** (1024×500), **App icon** (512×512)।
- (Assets গুলো `design/` বা `deliverables/` folder-এ থাকলে সেখান থেকে নাও।)

## 7. AAB upload ও review-এ পাঠানো
1. **Release → Production → Create new release**।
2. `app-release.aab` upload করো — Build #22 থেকে, বা GitHub Release `v0.1.0`-এর AAB artifact থেকে।
3. Release notes লেখো।
4. **Send for review** → Google কয়েক ঘণ্টা থেকে কয়েক দিনের মধ্যে approve করবে।

## 8. Troubleshooting
- **AAB strip error** ("Release app bundle failed to strip debug symbols from native libraries"): Flutter 3.44+ regression; `flutter-builder` reusable workflow-এর gradle-bypass দিয়ে resolve করা আছে।
- **Data safety mismatch**: privacy policy আর Data safety form-এ একই তথ্য দাও, নাহলে reject হতে পারে।
- **Policy placeholders**: privacy policy-এর ভিতর থাকা `[square brackets]` গুলো (যদি থাকে) রিয়েল তথ্য দিয়ে replace করে নাও।

## Related links
- 🔒 Privacy policy: https://keshab1997.github.io/prescription-scanner/privacy-policy.html
- 📦 GitHub Release (APK + AAB): https://github.com/Keshab1997/prescription-scanner/releases/tag/v0.1.0
- 💻 Repo: https://github.com/Keshab1997/prescription-scanner
- 🔧 Build workflow: `.github/workflows/manual_android_build.yml` (uses `Keshab1997/flutter-builder/.github/workflows/flutter-build.yml@v1`)
