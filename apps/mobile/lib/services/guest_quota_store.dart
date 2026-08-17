import 'package:hive_flutter/hive_flutter.dart';

/// Tracks how many free scans an anonymous (not signed-in) user has used
/// today.
///
/// Anonymous users have no Firebase UID, so they also have no Firestore
/// document. Their daily free-scan usage is therefore kept locally on the
/// device (per calendar day), while signed-in usage continues to live in
/// Firestore's `daily_usage` collection.
abstract final class GuestQuotaStore {
  static const String _boxName = 'ks_guest_quota_v1';
  static const String _usedPrefix = 'used::';
  static Box? _box;

  static Future<Box> _open() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox(_boxName);
    return _box!;
  }

  static String _dayKey(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// Number of successful scans used by this device's anonymous user today.
  static Future<int> usedToday() async {
    final box = await _open();
    final key = '$_usedPrefix${_dayKey(DateTime.now())}';
    return box.get(key, defaultValue: 0) as int;
  }

  /// Records one more successful anonymous scan for today.
  static Future<void> recordSuccessfulScan() async {
    final box = await _open();
    final key = '$_usedPrefix${_dayKey(DateTime.now())}';
    await box.put(key, (box.get(key, defaultValue: 0) as int) + 1);
  }
}
