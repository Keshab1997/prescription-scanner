# Privacy Policy — Prescription Scanner

**Effective date:** 2026-08-18
**App:** Prescription Scanner (Android)
**Developer:** Keshab Studios ([GitHub: Keshab1997](https://github.com/Keshab1997))

Prescription Scanner is a "privacy-first" app that helps you capture and
transcribe medical prescriptions using on-device capture and AI-assisted
transcription. This policy explains what data the app handles, how it is used,
and the choices you have.

> **Note for the developer:** text in `[square brackets]` are placeholders.
> Replace them with your real legal name, contact email, address, and the
> exact data-retention periods you intend to apply before publishing.

---

## 1. Data controller

The data controller responsible for your information is **[Keshab Studios /
Full Legal Name]**, reachable at **[privacy@your-domain.example]**.

## 2. Information we collect

### 2.1 Prescription images and transcribed text
- The app uses the device **camera** (and the system photo picker) to capture
  images of prescriptions.
- Captured images are processed (compressed on-device) and sent to an
  AI transcription service (Google **Gemini**, via a server-side API key pool)
  to produce transcribed prescription text.
- The transcribed text (medicine names, dosage, notes) is the primary content
  you create with the app.

### 2.2 Device information
- We may collect non-identifying device information (model, OS version,
  locale, and a stable app-instance identifier) via platform APIs, used for
  crash diagnosis and basic analytics.

### 2.3 Analytics
- **Firebase Analytics** records aggregated, anonymized usage events
  (e.g., which screens are opened, feature usage counts) to help improve the
  app.

### 2.4 Crash reports
- **Firebase Crashlytics** automatically collects crash logs and stack traces
  (which may include the state of the screen you were on) to diagnose failures.

### 2.5 Advertising
- The app may display ads through **Google AdMob** (`google_mobile_ads`).
  AdMob may use advertising identifiers and contextual signals to serve ads.
  You can reset or opt out of personalized ads in your device's privacy
  settings.

### 2.6 Account (optional)
- If you sign in with **Firebase Authentication**, we store the account
  identifier needed to associate your data with you. Sign-in is optional and
  the core capture/transcription features work without it.

## 3. How we use information

- To transcribe prescriptions and present the result to you.
- To store your prescriptions **locally on your device** (see Section 4).
- To diagnose crashes and improve app quality (Crashlytics / Analytics).
- To serve ads (AdMob).
- To comply with legal obligations.

## 4. Local-first storage

Prescription Scanner is designed to be **privacy-first**: transcribed
prescriptions are stored primarily **on your device** using local storage
(Hive). They are not uploaded to a shared server solely for storage unless a
feature you explicitly enable requires cloud synchronization.

## 5. Cloud services (Firebase)

When enabled, the following Google Firebase services process data on our
behalf:

| Service | Purpose | Data involved |
| --- | --- | --- |
| Firebase Auth | Optional sign-in | Account identifier |
| Cloud Firestore | Optional cloud sync | Prescription data you choose to sync |
| Firebase Analytics | Usage analytics | Aggregated events |
| Firebase Crashlytics | Crash diagnosis | Crash logs / stack traces |

Google's own privacy policy governs how Google processes data under these
services: https://policies.google.com/privacy

## 6. AI transcription (Gemini)

Prescription images/text you submit for transcription are sent to Google's
Gemini model via a server-side proxy. Transient image and text data needed
for the transcription request is processed to generate the result and is not
retained by us beyond what is required to return the response.

## 7. Advertising (Google AdMob)

AdMob may collect and process:
- Advertising identifier (resettable).
- Device and coarse location signals (depending on your ad settings).
- Interaction with ads served.

AdMob privacy & consent: https://policies.google.com/technologies/ads

## 8. Data retention and deletion

- **On-device data** (your prescriptions in local storage) remains on your
  device until you delete it in the app or uninstall the app.
- **Cloud-synced data** (if enabled) is retained for **[e.g., 24 months]** or
  until you request deletion.
- **Analytics/Crashlytics** data is retained per Google's standard retention
  (typically ~60 days for Crashlytics; Analytics per your Google config).
- You may request deletion of your cloud account and associated data by
  emailing **[privacy@your-domain.example]**; we will action verifiable
  requests within **[30]** days.

## 9. Children's privacy

Prescription Scanner is **not directed to children under 13** (or the
equivalent minimum age in your jurisdiction). We do not knowingly collect
personal data from children. If you believe a child has provided us data,
contact us and we will delete it.

## 10. Security

We use industry-standard measures (encrypted transport, Firebase security
rules, signed release builds) to protect data in transit and at rest. No
method of transmission or storage is 100% secure.

## 11. Your rights

Depending on your jurisdiction, you may have rights to access, correct,
export, or delete your personal data, and to object to or restrict certain
processing. To exercise these rights, contact **[privacy@your-domain.example]**.

## 12. Changes to this policy

We may update this policy as the app evolves. Material changes will be
reflected by updating the "Effective date" above and, where required,
notified in-app or via the store listing.

## 13. Contact

Questions about this policy or your data:
**Keshab Studios** — **[privacy@your-domain.example]**
Project: https://github.com/Keshab1997/prescription-scanner
