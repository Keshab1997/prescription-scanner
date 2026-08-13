import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_api_key_manager/admin_api_key_manager.dart';

import 'package:prescription_scanner/app.dart';
import 'package:prescription_scanner/config.dart';
import 'package:prescription_scanner/firebase_options.dart';
import 'package:prescription_scanner/services/result_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase is used only for authentication (login/account).
  if (AppConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
  }

  // Firebase powers the admin_api_key_manager key pool (Gemini keys only).
  // Prescription data itself is NOT stored in Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await KeyCache.init();
  await ResultStore.init();

  // Optional build-time Gemini key fallback (see docs/vision_setup.md).
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

  ApiKeyManager.instance.initialize();

  runApp(const ProviderScope(child: PrescriptionScannerApp()));
}
