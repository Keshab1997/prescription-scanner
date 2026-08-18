# Play Store রিলিজ গাইড — Prescription Scanner

এই গাইড **Keshab Studios / Prescription Scanner** (`com.keshabstudios.prescriptionscanner`) অ্যাপ প্লে স্টোরে প্রথমবার ও পরেরবার পাবলিশ করার ধাপ। কনসোলের বাটন নাম ইংরেজিতে রাখা হয়েছে, যাতে স্ক্রিনে মিলিয়ে নিতে পারেন।

| | |
|---|---|
| প্যাকেজ / App ID | `com.keshabstudios.prescriptionscanner` |
| অ্যাপ নাম | Prescription Scanner |
| ডেভেলপার | Keshab Studios |
| সাপোর্ট ইমেইল | keshabsarkar2018@gmail.com |
| ভার্সন সোর্স | `apps/mobile/pubspec.yaml` → `version: 0.1.0+1` |
| আইকন সোর্স | `design/app_icon.png` (১০২৪×১০২৪) |
| সাইনিং | `apps/mobile/android/key.properties` + `upload-keystore.jks` |

---

## ০) আগে বুঝে নিন: দুই ধরনের রিলিজ

| রিলিজ | কী উদ্দেশ্য | AdMob |
|---|---|---|
| **প্রথম Production** | অ্যাপ লাইভ, ইউজার ইনস্টল করতে পারে | টেস্ট অ্যাড রেখে দিন |
| **দ্বিতীয়+** | আসল বিজ্ঞাপন, ফিক্স, ফিচার | প্রোড App ID + Banner ID |

ইন-অ্যাপ ফোর্স আপডেট কোড প্রথম বিল্ডেই আছে। ইউজার সেই বিল্ড ইনস্টল করার **পরের** ভার্সনে আপডেট স্ক্রিন দেখবে।

---

## ১) Play Console অ্যাকাউন্ট (একবার)

1. [play.google.com/console](https://play.google.com/console) এ সাইন ইন।
2. ডেভেলপার অ্যাকাউন্ট **Active** (রেজিস্ট্রেশন ফি দেওয়া)।
3. **Payments profile** খুলুন (ব্যাংক + ট্যাক্স) — পরে AdMob/পেআউটের জন্য লাগবে।
4. **Create app**
   - App name: `Prescription Scanner`
   - Default language: English (United States) বা English (India)
   - App or game: **App**
   - Free or paid: **Free**
   - Declarations: Play policies + US export laws টিক দিন।

---

## ২) স্টোর সেটিং (প্রথমবার Complete করতে হবে)

Dashboard-এ লাল/ধূসর আইটেম শেষ না হলে Production রোলআউট ব্লক থাকে।

### 2.1 Store listing

- **App name:** Prescription Scanner (৩০ অক্ষরের মধ্যে)
- **Short description** (৮০ অক্ষর), উদাহরণ:

  `Scan a prescription photo. AI turns it into a clear medicine list — private on your phone.`

- **Full description**, উদাহরণ:

  ```
  Prescription Scanner by Keshab Studios helps you read paper prescriptions.

  • Point the camera or pick a photo
  • AI transcribes medicines, dosage, frequency and duration
  • History stays on this device
  • Try a free guest scan, then sign in for more daily scans

  This app is not a doctor and does not give medical advice.
  Always follow your clinician and the original prescription.

  Support: keshabsarkar2018@gmail.com
  ```

- **App icon:** `design/app_icon.png` থেকে ৫১২×৫১২ PNG (কোণা গোল করতে হবে না — স্টোর নিজে মাস্কে করে)।
- **Feature graphic:** ১০২৪×৫০০ PNG/JPG (টিল–ইন্ডিগো ব্যাকগ্রাউন্ড + অ্যাপ নাম + মাসকট)।
- **Phone screenshots:** অন্তত ২টা, ভালো হয় ৪–৮টা (লগইন, স্ক্যান, রেজাল্ট, হিস্ট্রি)। সাইজ সাধারণত ১০৮০×১৯২০।
- **Contact:** `keshabsarkar2018@gmail.com`

### 2.2 Store settings

- App category: **Medical** (বা Health & Fitness — মেডিকেল ট্রান্সক্রিপশন হলে Medical বেশি মিলে)
- Tags: prescription, medicine, scanner, health
- Email: সাপোর্ট ইমেইল

### 2.3 Privacy policy (বাধ্যতামূলক)

একটা **পাবলিক HTTPS URL** লাগবে। অ্যাপে `/privacy` স্ক্রিন আছে; সেটাকে ওয়েবে হোস্ট করুন (Firebase Hosting / GitHub Pages) অথবা আলাদা পেজ।

পলিসিতে লিখুন:

- ক্যামেরা / গ্যালারি কেন লাগে
- অ্যাকাউন্ট (ইমেইল, ডিসপ্লে নেম, Firebase Auth)
- ছবি Gemini-এ ট্রান্সক্রিপশনের জন্য যায়, ক্লাউডে হিস্ট্রি হিসেবে রাখা হয় না
- AdMob / অ্যাডভার্টাইজিং আইডি (প্রথম রিলিজেও উল্লেখ করা নিরাপদ)
- অ্যাকাউন্ট ডিলিট কীভাবে

### 2.4 App content ফর্ম

| ফর্ম | কী দিবেন |
|---|---|
| **Privacy policy** | উপরের URL |
| **Ads** | প্রথম রিলিজ: Yes, my app contains ads (কোডে ব্যানার আছে) **অথবা** No যদি শুধু টেস্ট ইউনিট থাকে ও ইউজার-ফেসিং অ্যাড না দেখান — সৎ থাকুন। প্রোড অ্যাড চালু করলে অবশ্যই **Yes** |
| **App access** | সব ফিচার লগইন ছাড়া টেস্ট করা যায় (গেস্ট স্ক্যান) — সাধারণত *All functionality is available* |
| **Content ratings** | IARC প্রশ্নপত্র পূরণ; বাচ্চাদের অ্যাপ নয় |
| **Target audience** | ১৮+ (স্বাস্থ্য/প্রেসক্রিপশন) |
| **News / COVID / Data safety** | নিচের Data safety দেখুন |
| **Government / Financial** | সাধারণত No |

### 2.5 Data safety

অ্যাপ যা করে, সেটাই ঘোষণা করুন। সাধারণ ম্যাপ:

| ডেটা | Collected? | Shared? | Purpose |
|---|---|---|---|
| ইমেইল, নাম | হ্যাঁ (অ্যাকাউন্ট) | Firebase-এর সাথে প্রসেসিং | Account |
| অ্যাপ অ্যাক্টিভিটি / স্ক্যান কাউন্ট | হ্যাঁ (Firestore usage) | না (আপনার প্রজেক্ট) | App functionality |
| Photos | অস্থায়ী, ডিভাইসে প্রসেস; Gemini-এ পাঠানো | Gemini (transcription) | App functionality |
| Crash logs | হ্যাঁ (Crashlytics) | Google | Analytics / stability |
| Advertising ID | AdMob চালু থাকলে | Google Ads | Advertising |

**Is the app encrypted in transit?** Yes (HTTPS).  
**Can users request deletion?** Yes (Profile → Delete account & data).

### 2.6 Countries

প্রথম মার্কেট README অনুযায়ী **India**। চাইলে পরে দেশ বাড়ান।

---

## ৩) সাইনিং কি (হারালে অ্যাপ আপডেট করা যায় না)

লোকাল রিলিজ সাইন হয় `apps/mobile/android/key.properties` দিয়ে।

```bash
cd apps/mobile/android

# একবার: আপলোড কিস্টোর (নাম/পাসওয়ার্ড নিজের মতো রাখুন, সেভ করুন)
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

cp key.properties.example key.properties
# key.properties এ storePassword, keyPassword, keyAlias=upload, storeFile=upload-keystore.jks
```

- `key.properties`, `.jks`, পাসওয়ার্ড **কখনো Git-এ দেবেন না** (gitignore আছে)।
- ক্লাউডে / পেনড্রাইভে ব্যাকআপ রাখুন।
- Play Console → Setup → **App signing**: প্রথম AAB আপলোডের পর Google **app signing key** ধরে; আপনার `.jks` হলো **upload key**।

Firebase-এ Google Sign-In চালু থাকলে Play App Signing-এর **SHA-1 / SHA-256** (App signing certificate, শুধু upload না) Firebase Console → Project settings → Android অ্যাপে যোগ করুন। নাহলে প্রোডাকশনে Google লগইন ভাঙতে পারে।

---

## ৪) ভার্সন বাড়ানো

`apps/mobile/pubspec.yaml`:

```yaml
version: 0.1.0+1
#          │     └─ versionCode  (প্রতি রিলিজে অবশ্যই +1: 1, 2, 3…)
#          └─────── versionName  (ইউজার দেখে: 0.1.0, 0.1.1…)
```

| রিলিজ | উদাহরণ |
|---|---|
| প্রথম Production | `0.1.0+1` |
| আইকন/লগইন ফিক্স | `0.1.1+2` |
| AdMob প্রোড | `0.1.2+3` |

একই `versionCode` দুবার আপলোড করা যায় না।

---

## ৫) রিলিজ বিল্ড (AAB)

প্লে স্টোর চায় **Android App Bundle (`.aab`)**, APK নয়।

```bash
cd "/path/to/prescription-scanner"
git pull origin main
cd apps/mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

# প্রথম রিলিজ — টেস্ট অ্যাড (ADMOB_BANNER_ID দেবেন না)
flutter build appbundle --release

# ফাইল:
# build/app/outputs/bundle/release/app-release.aab
```

### দ্বিতীয় রিলিজ — আসল বিজ্ঞাপন (প্লে লাইভ + AdMob লিংকের পরে)

1. `AndroidManifest.xml`-এ স্যাম্পল App ID বদলে নিজের `ca-app-pub-xxxx~yyyy`
2. বিল্ড:

```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/YYYY
```

`APP_ENV=production` **এবং** আসল ব্যানার আইডি দুটোই লাগবে। নাহলে অ্যাপ টেস্ট অ্যাডই দেখায়।

Gemini কি বিল্ডে বেক করতে চাইলে (ঐচ্ছিক; প্রেফার Firestore পুল):

```bash
--dart-define=GEMINI_API_KEY=AIza...
```

প্রোডাকশনে কি সোর্সে/লগে ফেলবেন না।

---

## ৬) টেস্টিং ট্র্যাক → Production

Play Console → আপনার অ্যাপ → **Test and release**

1. **Internal testing** (নিজের জিমেইল) — AAB আপলোড, টেস্টার যোগ, লিংক থেকে ইনস্টল। Google Sign-In, স্ক্যান, অনবোর্ডিং চেক।
2. (ঐচ্ছিক) **Closed testing** — বন্ধু/পরিবার।
3. **Production** → **Create new release**
   - AAB আপলোড
   - Release name: `0.1.0 (1)`
   - Release notes (en-US / en-IN):

     ```
     First public release of Prescription Scanner.
     Scan a prescription, get a structured medicine list, and keep history on your device.
     ```

   - **Next** → Review → **Start rollout to Production**
   - প্রথমবার **100%** ঠিক আছে; পরে বড় চেঞ্জে ২০% → ৫০% → ১০০% staged rollout ভালো।

রিভিউ সাধারণত কয়েক ঘণ্টা থেকে ১–৩ দিন। স্ট্যাটাস **Available on Google Play** হলে ইউজার স্টোর সার্চে পাবে (নতুন অ্যাপ ইনডেক্স হতে আরও সময় লাগতে পারে)।

**Managed publishing** চালু থাকলে রিভিউ শেষে নিজে **Publish** চাপতে হয়।

---

## ৭) ইউজার কীভাবে আপডেট পাবে

- অটো-আপডেট চালু থাকলে প্লে নিজে ইনস্টল করে (মিনিট–কয়েক দিন)।
- ম্যানুয়াল: Play Store → অ্যাপ পেজ → **Update**।
- এই অ্যাপে **Play In-App Updates** আছে: স্টোরে নতুন `versionCode` লাইভ থাকলে পুরনো ইউজার অ্যাপ খুললে **Update required** স্ক্রিন আসে (শুধু প্লে থেকে ইনস্টল করা বিল্ডে)।

ডিবাগ APK / সাইডলোডে ইন-অ্যাপ আপডেট কাজ করে না।

---

## ৮) AdMob — প্রথম রিলিজের পরে

1. অ্যাপ Production-এ Available।
2. [admob.google.com](https://admob.google.com) → Add app → প্লে থেকে লিংক।
3. Banner unit তৈরি।
4. ম্যানিফেস্টে আসল App ID + উপরের প্রোড `dart-define` দিয়ে নতুন AAB।
5. `versionCode` বাড়িয়ে Production রিলিজ।

নিজে বিজ্ঞাপনে ক্লিক করবেন না। Designed for children = **No**।

বিস্তারিত আয়ের চেকলিস্ট কথোপকথনে আলোচিত; এখানে অর্ডার: **আগে স্টোর, পরে প্রোড অ্যাড**।

---

## ৯) প্রতি রিলিজের চেকলিস্ট

- [ ] `main` আপ টু ডেট, working tree পরিষ্কার
- [ ] `pubspec.yaml` versionName + **নতুন versionCode**
- [ ] `flutter analyze` ক্লিন, `flutter test` পাস
- [ ] `android/key.properties` আছে, কিস্টোর ব্যাকআপ আছে
- [ ] প্রথম রিলিজে টেস্ট AdMob ID; পরে প্রোড ID
- [ ] AAB: `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
- [ ] Internal test ইনস্টল করে লগইন / গেস্ট স্ক্যান / প্রাইভেসি পেজ দেখা হয়েছে
- [ ] Store listing, privacy URL, Data safety, content rating Complete
- [ ] Firebase-এ Play **app signing** SHA-1 যোগ
- [ ] Release notes লেখা
- [ ] Production rollout স্টার্ট
- [ ] কিস্টোর Git-এ পড়েনি (`git status` চেক)

---

## ১০) সাধারণ সমস্যা

| সমস্যা | কারণ / সমাধান |
|---|---|
| *You need to use a different version code* | `+N` বাড়ান |
| *Upload key mismatch* | অন্য `.jks` দিয়ে সাইন হয়েছে — আসল upload key লাগবে |
| Google Sign-In প্রোডে ফেল | Play App Signing SHA-1 Firebase-এ নেই |
| বিজ্ঞাপন আসে না / টেস্ট লেখা | `APP_ENV` বা `ADMOB_BANNER_ID` ছাড়া বিল্ড |
| ইন-অ্যাপ আপডেট আসে না | ইউজার প্লে বিল্ডে নেই, বা নতুন ভার্সন এখনো Production-এ Available নয় |
| মেডিকেল পলিসি ওয়ার্নিং | স্টোর/অ্যাপে “not medical advice” রাখুন; ডাক্তারি দাবি করবেন না |
| রিভিউ রিজেক্ট — broken ads ID | স্যাম্পল App ID দিয়ে প্রোড ক্লেইম করলে সমস্যা হতে পারে; প্রথম রিলিজে টেস্ট ID রেখে Ads ফর্ম সততার সাথে পূরণ করুন |
| *failed to strip debug symbols from native libraries* | NDK/`llvm-strip` পাওয়া যায়নি। প্রজেক্টে স্ট্রিপ স্কিপ করা আছে — `git pull` করে আবার `flutter build appbundle --release`। স্থায়ী ফিক্স: Android Studio → SDK Manager → SDK Tools → **NDK (Side by side)** + **CMake** ইনস্টল, তারপর `flutter doctor -v` |

---

## ১১) দ্রুত কমান্ড (কপি-পেস্ট)

```bash
cd "/Users/keshabsarkar/Vs Code Apps/prescription-scanner"
git pull origin main
cd apps/mobile

# 1) pubspec.yaml এ version বাড়ান, তারপর:
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release

open build/app/outputs/bundle/release
```

AAB প্লে কনসোল → Production → Create new release-এ টেনে দিন।

---

প্রশ্ন: keshabsarkar2018@gmail.com · Keshab Studios
