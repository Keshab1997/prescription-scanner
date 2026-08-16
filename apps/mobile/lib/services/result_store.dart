import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';

/// Per-user local storage for sensitive prescription results.
///
/// Results remain on the device, but every record is namespaced and tagged by
/// its Firebase UID. This prevents one account from seeing another account's
/// history when multiple people use the same phone.
class ResultStore {
  ResultStore._();

  static const String _boxName = 'ks_results_v2';
  static const String _legacyBoxName = 'rx_results';
  static const String _ownerField = '_owner_uid';
  static ResultStore? _instance;

  /// Must be called after `HiveFlutter.init()` (done in `main.dart`).
  static Future<ResultStore> init() async {
    if (_instance != null) return _instance!;

    // Legacy records had no owner UID and therefore cannot be assigned safely.
    // The selected migration policy is to delete them rather than risk showing
    // one person's medical data to another account on the same device.
    if (await Hive.boxExists(_legacyBoxName)) {
      if (Hive.isBoxOpen(_legacyBoxName)) {
        await Hive.box(_legacyBoxName).close();
      }
      await Hive.deleteBoxFromDisk(_legacyBoxName);
    }

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _instance = ResultStore._();
    return _instance!;
  }

  static ResultStore get instance {
    if (_instance == null) {
      throw StateError('ResultStore.init() must be called before use.');
    }
    return _instance!;
  }

  Box get _box => Hive.box(_boxName);

  String _key(String ownerUid, String resultId) => '$ownerUid::$resultId';

  Future<void> save(String ownerUid, ExtractedPrescription result) {
    return _box.put(_key(ownerUid, result.id), {
      ...result.toJson(),
      _ownerField: ownerUid,
    });
  }

  ExtractedPrescription? get(String ownerUid, String id) {
    final raw = _box.get(_key(ownerUid, id));
    if (raw is! Map || raw[_ownerField] != ownerUid) return null;
    return ExtractedPrescription.fromJson(Map<String, dynamic>.from(raw));
  }

  List<ExtractedPrescription> getAll(String ownerUid) {
    final items = _box.values
        .whereType<Map>()
        .where((raw) => raw[_ownerField] == ownerUid)
        .map(
          (raw) =>
              ExtractedPrescription.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> delete(String ownerUid, String id) {
    return _box.delete(_key(ownerUid, id));
  }

  Future<void> clearUser(String ownerUid) async {
    final keys = _box.keys
        .whereType<String>()
        .where((key) => key.startsWith('$ownerUid::'))
        .toList();
    if (keys.isNotEmpty) await _box.deleteAll(keys);
  }
}

final resultStoreProvider = Provider<ResultStore>(
  (ref) => ResultStore.instance,
);
