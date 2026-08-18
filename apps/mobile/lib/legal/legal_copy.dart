/// Play-facing legal copy. Keep this aligned with Data safety, Help, and
/// in-app consent so store listings never contradict the runtime.
abstract final class LegalCopy {
  static const supportEmail = 'keshabsarkar2018@gmail.com';
  static const publisher = 'Keshab Studios';
  static const appName = 'Prescription Scanner';

  static const medicalShort =
      'AI transcribes only — this is not a diagnosis, prescription, or medical advice.';

  static const medicalFull =
      '''
$appName uses AI to transcribe visible text from a prescription image.

It is not a medical device. It does not diagnose, treat, prescribe, recommend, or replace a doctor or pharmacist.

Unclear handwriting is left blank or marked for review. Never take, stop, or change medicine based only on this app. Confirm every detail with a qualified healthcare professional.''';

  static const privacySummary =
      'Prescription Scanner prepares the photo on your device, then our AI transcription service reads visible medicine details. We do not store that image in our own cloud. The local prepared copy is deleted after processing. Structured results stay on this device, scoped to your account or guest session. Usage counts and optional feedback go to Firebase.';

  static const privacyPolicy =
      '''
Last updated: 18 August 2026

Who we are
$publisher (“we”) publishes $appName for Android. Contact: $supportEmail

What the app does
You capture or pick a prescription photo. Prescription Scanner compresses it on the device and uses our AI transcription pipeline so visible medicine details become a structured list.

Data we process
• Account: email, display name, and Firebase Authentication identifiers when you sign in. If you choose Google Sign-In, Google shares your Google account name and email with Firebase so we can create or open that account.
• Images: the prepared photo is processed by our AI transcription pipeline, which uses a third-party cloud vision provider (Google). We do not upload it to our Firebase Storage. The local prepared file is deleted after processing.
• On-device results: transcribed lists stay in local storage (Hive), namespaced by your Firebase user id or a guest namespace.
• Usage: daily scan counts (and, for guests, a device-scoped counter) in Firestore so limits can be enforced.
• Optional feedback you submit about a transcription error.
• Diagnostics: Crashlytics/Analytics crash and usage events. These must not include prescription images or extracted medicine text.
• Ads: Google Mobile Ads may collect advertising identifiers after consent where required (EEA/UK). This app is not directed at children.

What we do not do
• We do not sell your prescription images.
• We do not provide medical advice.
• We do not guess unclear medicine names or doses.

Permissions
• Camera — only to photograph a prescription after you tap Take photo and accept the on-screen explanation.
• Photos / gallery — only when you choose Gallery.
• Internet — to reach Firebase, our AI transcription service, and ads.

Retention
Local results remain until you delete an item, delete your account, or clear app data. Firebase profile and usage records are removed when you complete in-app account deletion (best-effort). An audit row may remain so we can confirm the request.

Your choices
• Use 1 guest scan per day without an account.
• Sign in (verified email) for the full daily allowance (typically 3, including any guest scan already used today).
• Delete individual results from History.
• Delete your account and associated data from Profile.

International transfers
Google and Firebase may process data outside India. Use the app only if you accept that.

Changes
We will update this in-app text when the data flow changes. A public URL can be added in Play Console when you publish one.''';

  static const terms =
      '''
Last updated: 18 August 2026

By using $appName you agree to these terms.

1. Service
The app offers AI transcription of visible prescription text. Results can be wrong. You must verify them.

2. Eligibility
The app is intended for adults. It is not designed for children under 13 and is not directed at kids.

3. Accounts
You must use a real email. Disposable addresses may be blocked. Email verification is required before signed-in scanning.

4. Acceptable use
Do not scan documents you are not allowed to process. Do not try to reverse-engineer API keys or overload the service.

5. Limits
Guest users get 1 free scan per day. Signed-in verified users get the administrator-configured daily limit (default 3), minus any guest scans already used on this device today.

6. Ads
The free app may show ads. Ads use Google’s test units in debug/development builds. Production units are injected at release time. Personalized ads in the EEA/UK require Google UMP consent.

7. Disclaimer
THE APP IS PROVIDED “AS IS”. $publisher is not liable for medical decisions, missed doses, or transcription errors.

8. Termination
We may block accounts that abuse the service. You may delete your account at any time from Profile.

9. Contact
$supportEmail''';

  static const cameraRationaleTitle = 'Camera access';

  static const cameraRationale =
      'Camera is used only to photograph a paper prescription so AI can transcribe visible medicine details. Photos are not saved to our cloud. You can use Gallery instead.';

  static const guestLimitTitle = 'Guest: 1 free scan / day';

  static const guestLimitBody =
      'Without an account you can run 1 free scan today. Sign in and verify email to unlock the full daily allowance (usually 3). A guest scan you already used today still counts, so login typically adds 2 more scans.';

  static const signedInLimitBody =
      'Signed-in verified users share one daily budget (default 3 scans). Guest scans from this device today are included in that budget. Limits reset at local midnight and can be changed by the administrator.';
}
