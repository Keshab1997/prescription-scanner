// GENERATED FILE — REPLACE WITH YOUR OWN.
//
// This is a template so the app compiles before you run:
//   flutterfire configure
//
// After `flutterfire configure` finishes it will overwrite this file with your
// real Firebase project options. Until then the values below are placeholders
// and Firebase will fail at runtime (not at compile time).
//
// See docs/vision_setup.md for the full setup steps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4evztyQ4frzTXvK64VjzQm0vZe779b5s',
    appId: '1:780785545429:web:b80e9b349267bedb4eb25c',
    messagingSenderId: '780785545429',
    projectId: 'prescription-scanner-admin',
    authDomain: 'prescription-scanner-admin.firebaseapp.com',
    storageBucket: 'prescription-scanner-admin.firebasestorage.app',
  );

  // NOTE: the apiKey MUST match the `current_key` in android/app/google-services.json.
  // The GMS plugin auto-initializes the default app from that JSON at process
  // start; if these options differ, FlutterFire throws `duplicate-app` and the
  // native splash (logo) never gets removed — the app appears stuck on launch.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUp08GG5QRnX58hQTGalTGjiBhWADKtZg',
    appId: '1:780785545429:android:d6f22e63048722284eb25c',
    messagingSenderId: '780785545429',
    projectId: 'prescription-scanner-admin',
    storageBucket: 'prescription-scanner-admin.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC4evztyQ4frzTXvK64VjzQm0vZe779b5s',
    appId: '1:780785545429:web:b80e9b349267bedb4eb25c',
    messagingSenderId: '780785545429',
    projectId: 'prescription-scanner-admin',
    storageBucket: 'prescription-scanner-admin.firebasestorage.app',
    iosBundleId: 'com.keshabstudios.prescriptionscanner',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC4evztyQ4frzTXvK64VjzQm0vZe779b5s',
    appId: '1:780785545429:web:b80e9b349267bedb4eb25c',
    messagingSenderId: '780785545429',
    projectId: 'prescription-scanner-admin',
    storageBucket: 'prescription-scanner-admin.firebasestorage.app',
    iosBundleId: 'com.keshabstudios.prescriptionscanner',
  );
}
