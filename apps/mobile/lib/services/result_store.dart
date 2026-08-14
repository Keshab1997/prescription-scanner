import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';

/// Local, Supabase-free store for extracted prescriptions. Results are kept in
/// a Hive box keyed by the local prescription id, so the result and history
/// screens no longer depend on Supabase. (Auth/login still uses Supabase.)
class ResultStore {
  ResultStore._();

  static const String _boxName = 'rx_results';
  static ResultStore? _instance;

  /// Must be called after `HiveFlutter.init()` (done in `main.dart`).
  static Future<ResultStore> init() async {
    if (_instance != null) return _instance!;
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

  void save(ExtractedPrescription result) {
    _box.put(result.id, result.toJson());
  }

  ExtractedPrescription? get(String id) {
    final raw = _box.get(id);
    if (raw is! Map) return null;
    return ExtractedPrescription.fromJson(Map<String, dynamic>.from(raw));
  }

  List<ExtractedPrescription> getAll() {
    final items = _box.values
        .whereType<Map>()
        .map(
          (raw) =>
              ExtractedPrescription.fromJson(Map<String, dynamic>.from(raw)),
        )
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  void delete(String id) => _box.delete(id);
}

final resultStoreProvider = Provider<ResultStore>(
  (ref) => ResultStore.instance,
);
