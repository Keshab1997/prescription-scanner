import 'package:hive_flutter/hive_flutter.dart';

/// Stores AI-processing consent locally and separately for each Firebase UID.
abstract final class ConsentStore {
  static const String _boxName = 'ks_consent_v2';
  static const String _legacyBoxName = 'rx_consent';
  static const String _consentPrefix = 'ai_consent_v1::';
  static Box? _box;

  static Future<Box> _open() async {
    if (_box != null && _box!.isOpen) return _box!;

    // The legacy value was shared by every account on the device. Delete it so
    // every user must provide their own consent once.
    if (await Hive.boxExists(_legacyBoxName)) {
      if (Hive.isBoxOpen(_legacyBoxName)) {
        await Hive.box(_legacyBoxName).close();
      }
      await Hive.deleteBoxFromDisk(_legacyBoxName);
    }

    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  static Future<bool> hasAiConsent(String ownerUid) async {
    final box = await _open();
    return box.get('$_consentPrefix$ownerUid', defaultValue: false) as bool;
  }

  static Future<void> grantAiConsent(String ownerUid) async {
    final box = await _open();
    await box.put('$_consentPrefix$ownerUid', true);
  }

  static Future<void> clearUser(String ownerUid) async {
    final box = await _open();
    await box.delete('$_consentPrefix$ownerUid');
  }
}
