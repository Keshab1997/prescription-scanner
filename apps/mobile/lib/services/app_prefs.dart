import 'dart:async' show unawaited;

import 'package:hive_flutter/hive_flutter.dart';

/// Device-level UI preferences (not medical data).
abstract final class AppPrefs {
  static const _boxName = 'ks_prefs_v1';
  static const _languageKey = 'result_language';
  static const _chosenKey = 'language_chosen';
  static const _mediaAskedKey = 'media_permissions_asked';
  static const _onboardingSeenKey = 'onboarding_seen_v1';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _store {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('AppPrefs.init() must be called first.');
    }
    return box;
  }

  static bool get isReady => _box != null && _box!.isOpen;

  static bool get hasChosenLanguage =>
      _box?.get(_chosenKey, defaultValue: false) == true;

  /// `en`, `bn` or `hi`. Defaults to Bengali for the first market.
  static String get languageCode {
    final raw = _box?.get(_languageKey)?.toString();
    if (raw == 'en' || raw == 'bn' || raw == 'hi') return raw!;
    return 'bn';
  }

  static Future<void> setLanguageCode(String code) async {
    await _store.put(_languageKey, code);
    await _store.put(_chosenKey, true);
  }

  static bool get hasAskedMediaPermissions =>
      _box?.get(_mediaAskedKey, defaultValue: false) == true;

  static Future<void> markMediaPermissionsAsked() async {
    if (!isReady) return;
    await _store.put(_mediaAskedKey, true);
  }

  /// Whether the illustrated first-launch onboarding has been completed.
  static bool get hasSeenOnboarding =>
      _box?.get(_onboardingSeenKey, defaultValue: false) == true;

  static Future<void> markOnboardingSeen() async {
    if (!isReady) return;
    await _store.put(_onboardingSeenKey, true);
  }

  /// Updates the in-memory flag immediately so router redirects see it
  /// before Hive finishes file I/O (needed under flutter_test).
  static void markOnboardingSeenNow() {
    if (!isReady) return;
    unawaited(_store.put(_onboardingSeenKey, true));
  }
}
