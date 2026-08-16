import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/result_store.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(
    FirebaseFirestore.instance,
    fb.FirebaseAuth.instance,
  );
});

final quotaProvider = FutureProvider<ScanQuota>((ref) async {
  final authState = ref.watch(authUidProvider);
  final ownerUid = authState.hasValue
      ? authState.value
      : await ref.watch(authUidProvider.future);
  if (ownerUid == null) {
    throw const RepositoryException('Please sign in again.');
  }
  return ref.read(prescriptionRepositoryProvider).loadQuota(ownerUid);
});

/// Recent scans stay local for privacy but are strictly scoped to the current
/// Firebase UID. Watching [authUidProvider] prevents stale account data from
/// surviving a sign-out/account switch in Riverpod's provider cache.
final recentPrescriptionsProvider = FutureProvider<List<ExtractedPrescription>>(
  (ref) async {
    final authState = ref.watch(authUidProvider);
    final ownerUid = authState.hasValue
        ? authState.value
        : await ref.watch(authUidProvider.future);
    if (ownerUid == null) return const <ExtractedPrescription>[];
    return ResultStore.instance.getAll(ownerUid);
  },
);

final prescriptionHistoryProvider = FutureProvider<List<ExtractedPrescription>>(
  (ref) async {
    final authState = ref.watch(authUidProvider);
    final ownerUid = authState.hasValue
        ? authState.value
        : await ref.watch(authUidProvider.future);
    if (ownerUid == null) return const <ExtractedPrescription>[];
    return ResultStore.instance.getAll(ownerUid);
  },
);

class PrescriptionRepository {
  const PrescriptionRepository(this.firestore, this.auth);

  final FirebaseFirestore firestore;
  final fb.FirebaseAuth auth;

  String? get _uid => auth.currentUser?.uid;

  Future<ScanQuota> loadQuota(String ownerUid) async {
    final settingsDoc = await firestore
        .collection('app_settings')
        .doc('1')
        .get();
    final settings = settingsDoc.data() ?? const <String, dynamic>{};
    final dailyLimit = _asInt(settings['daily_limit']) ?? 3;
    final aiEnabled = settings['ai_enabled'] == true;
    final maintenanceMode = settings['maintenance_mode'] == true;

    final today = DateTime.now();
    final day = '${today.year}-${_two(today.month)}-${_two(today.day)}';
    final usageDoc = await firestore
        .collection('daily_usage')
        .doc('$ownerUid-$day')
        .get();
    final used = _asInt(usageDoc.data()?['request_count']) ?? 0;

    return ScanQuota(
      dailyLimit: dailyLimit,
      used: used,
      rewardedBonus: 0,
      remaining: (dailyLimit - used).clamp(0, dailyLimit),
      aiEnabled: aiEnabled,
      maintenanceMode: maintenanceMode,
    );
  }

  Future<void> recordSuccessfulScan() async {
    final uid = _uid;
    if (uid == null) throw const RepositoryException('Please sign in again.');

    final now = DateTime.now();
    final day = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    final usageRef = firestore.collection('daily_usage').doc('$uid-$day');

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(usageRef);
      final existing = snapshot.data();
      if (existing != null && existing['user_id'] != uid) {
        throw const RepositoryException('Invalid usage record owner.');
      }

      final requestCount = (_asInt(existing?['request_count']) ?? 0) + 1;
      final successfulCount = (_asInt(existing?['successful_count']) ?? 0) + 1;
      transaction.set(usageRef, {
        'user_id': uid,
        'usage_date': day,
        'request_count': requestCount,
        'successful_count': successfulCount,
        'failed_count': _asInt(existing?['failed_count']) ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitFeedback({
    required String prescriptionId,
    required String category,
    String? details,
  }) async {
    final uid = _uid;
    if (uid == null) throw const RepositoryException('Please sign in again.');
    await firestore.collection('prescription_feedback').add({
      'user_id': uid,
      'prescription_id': prescriptionId,
      'category': category,
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}

class ScanQuota {
  const ScanQuota({
    required this.dailyLimit,
    required this.used,
    required this.rewardedBonus,
    required this.remaining,
    required this.aiEnabled,
    required this.maintenanceMode,
  });

  factory ScanQuota.fromJson(Map<String, dynamic> json) => ScanQuota(
    dailyLimit: _asInt(json['daily_limit']) ?? 3,
    used: _asInt(json['used']) ?? 0,
    rewardedBonus: _asInt(json['rewarded_bonus']) ?? 0,
    remaining: _asInt(json['remaining']) ?? 0,
    aiEnabled: json['ai_enabled'] == true,
    maintenanceMode: json['maintenance_mode'] == true,
  );

  final int dailyLimit;
  final int used;
  final int rewardedBonus;
  final int remaining;
  final bool aiEnabled;
  final bool maintenanceMode;
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _two(int n) => n.toString().padLeft(2, '0');
