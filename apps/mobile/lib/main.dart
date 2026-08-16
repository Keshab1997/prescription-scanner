import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:admin_api_key_manager/admin_api_key_manager.dart';

import 'package:prescription_scanner/app.dart';
import 'package:prescription_scanner/config.dart';
import 'package:prescription_scanner/firebase_options.dart';
import 'package:prescription_scanner/services/result_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail-safe startup: a single failing dependency must not freeze the native
  // splash (logo). Run each init independently and keep the app booting.
  final initErrors = <String>[];

  // Firebase powers authentication, Firestore (profiles/quota/feedback), and
  // the admin_api_key_manager key pool (Gemini keys).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final existingUser = FirebaseAuth.instance.currentUser;
    if (existingUser != null) {
      await existingUser.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser?.emailVerified != true) {
        await FirebaseAuth.instance.signOut();
      } else {
        final profile = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(refreshedUser!.uid)
            .get();
        if (profile.data()?['status'] == 'blocked') {
          await FirebaseAuth.instance.signOut();
        }
      }
    }
  } catch (e, st) {
    initErrors.add('Firebase: $e');
    debugPrint('[main] Firebase init failed: $e\n$st');
  }

  try {
    await Hive.initFlutter();
  } catch (e, st) {
    initErrors.add('Hive: $e');
    debugPrint('[main] Hive init failed: $e\n$st');
  }

  try {
    await KeyCache.init();
  } catch (e, st) {
    initErrors.add('KeyCache: $e');
    debugPrint('[main] KeyCache init failed: $e\n$st');
  }

  try {
    await ResultStore.init();
  } catch (e, st) {
    initErrors.add('ResultStore: $e');
    debugPrint('[main] ResultStore init failed: $e\n$st');
  }

  // Optional build-time Gemini key fallback (see docs/vision_setup.md).
  try {
    if (AppConfig.geminiApiKey.isNotEmpty) {
      final cached = KeyCache.getCachedAdminKeys();
      final alreadySeeded = cached.any((k) => k.provider == 'google');
      if (!alreadySeeded) {
        await KeyCache.saveCachedAdminKeys([
          ...cached,
          AdminApiKey(
            id: 'local-fallback',
            name: 'Local fallback key',
            key: AppConfig.geminiApiKey,
            baseUrl: 'https://generativelanguage.googleapis.com',
            model: 'gemini-2.5-flash',
            provider: 'google',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ]);
      }
    }
  } catch (e, st) {
    initErrors.add('Gemini fallback: $e');
    debugPrint('[main] Gemini fallback seed failed: $e\n$st');
  }

  // ApiKeyManager starts lazily immediately before a verified user scans.
  // Starting its Firestore listeners here (before authentication) would make
  // the verified-user Firestore rules reject and permanently close them.

  if (initErrors.isNotEmpty) {
    debugPrint(
      '[main] startup completed with ${initErrors.length} non-fatal '
      'error(s): ${initErrors.join(' | ')}',
    );
  }

  runApp(const ProviderScope(child: PrescriptionScannerApp()));
}
