import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/guest_quota_store.dart';
import 'package:prescription_scanner/services/result_store.dart';

/// Stable pseudo-UID used to namespace local Hive data (results, consent and
/// quota) belonging to anonymous users who scan without signing in.
const String guestOwnerUid = 'guest';

/// Number of free scans an anonymous user may run per day. After this is
/// used up they are invited to sign in, which unlocks the regular daily
/// allowance ([ScanQuota.dailyLimit], default 3) with the guest scan counting
/// toward it — i.e. 1 guest scan + 2 more after login = 3 free per day.
const int kGuestFreeScansPerDay = 1;

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(
    FirebaseFirestore.instance,
    fb.FirebaseAuth.instance,
  );
});

/// Loads the current user's (or anonymous guest's) daily scan quota. When not
/// signed in the quota comes from the local guest store; when signed in it
/// comes from Firestore, with any guest scans used earlier today counting
/// toward the daily limit so "log in" genuinely unlocks the remaining scans.
final quotaProvider = FutureProvider<ScanQuota>((ref) async {
  final authState = ref.watch(authUidProvider);
  final ownerUid = authState.hasValue
      ? authState.value
      : await ref.watch(authUidProvider.future);
  return ref.read(prescriptionRepositoryProvider).loadQuota(ownerUid);
});

/// Recent scans stay local for privacy but are strictly scoped to the current
/// Firebase UID (or the guest namespace when signed out). Watching
/// [authUidProvider] prevents stale account data from surviving a
/// sign-out/account switch in Riverpod's provider cache.
final recentPrescriptionsProvider = FutureProvider<List<ExtractedPrescription>>(
  (ref) async {
    final authState = ref.watch(authUidProvider);
    final ownerUid = authState.hasValue
        ? authState.value
        : await ref.watch(authUidProvider.future);
    return ResultStore.instance.getAll(ownerUid ?? guestOwnerUid);
  },
);

final prescriptionHistoryProvider = FutureProvider<List<ExtractedPrescription>>(
  (ref) async {
    final authState = ref.watch(authUidProvider);
    final ownerUid = authState.hasValue
        ? authState.value
        : await ref.watch(authUidProvider.future);
    return ResultStore.instance.getAll(ownerUid ?? guestOwnerUid);
  },
);

class PrescriptionRepository {
  const PrescriptionRepository(this.firestore, this.auth);

  final FirebaseFirestore firestore;
  final fb.FirebaseAuth auth;

  String? get _uid => auth.currentUser?.uid;

  /// Loads the scan quota for [ownerUid] (null = anonymous guest).
  Future<ScanQuota> loadQuota(String? ownerUid) async {
    if (ownerUid == null || ownerUid == guestOwnerUid) {
      return _loadGuestQuota();
    }
    return _loadSignedInQuota(ownerUid);
  }

  Future<ScanQuota> _loadGuestQuota() async {
    var aiEnabled = true;
    var maintenanceMode = false;
    // Best-effort: honour maintenance/AI switch if the rules allow anonymous
    // reads of app_settings; fall back to defaults otherwise.
    try {
      final settings = await firestore
          .collection('app_settings')
          .doc('1')
          .get();
      final data = settings.data() ?? const <String, dynamic>{};
      aiEnabled = data['ai_enabled'] is bool
          ? data['ai_enabled'] as bool
          : true;
      maintenanceMode = data['maintenance_mode'] == true;
    } on FirebaseException {
      // Guests are not required to read app_settings; keep defaults.
    } catch (_) {
      // Any other failure must not block anonymous scanning.
    }

    final used = await GuestQuotaStore.usedToday();
    return ScanQuota(
      dailyLimit: kGuestFreeScansPerDay,
      used: used,
      rewardedBonus: 0,
      remaining: (kGuestFreeScansPerDay - used).clamp(0, kGuestFreeScansPerDay),
      aiEnabled: aiEnabled,
      maintenanceMode: maintenanceMode,
      isGuest: true,
    );
  }

  Future<ScanQuota> _loadSignedInQuota(String ownerUid) async {
    final settingsDoc = await firestore
        .collection('app_settings')
        .doc('1')
        .get();
    final settings = settingsDoc.data() ?? const <String, dynamic>{};
    final dailyLimit = _asInt(settings['daily_limit']) ?? 3;
    final aiEnabled = settings['ai_enabled'] is bool
        ? settings['ai_enabled'] as bool
        : true;
    final maintenanceMode = settings['maintenance_mode'] == true;

    final today = DateTime.now();
    final day = '${today.year}-${_two(today.month)}-${_two(today.day)}';
    final usageDoc = await firestore
        .collection('daily_usage')
        .doc('$ownerUid-$day')
        .get();
    final firestoreUsed = _asInt(usageDoc.data()?['request_count']) ?? 0;

    // Guest scans performed earlier today on this device count toward the
    // same daily budget, so a guest who used 1 free scan then signs in has
    // exactly (dailyLimit - 1) = 2 scans left.
    final guestUsed = await GuestQuotaStore.usedToday();
    final used = (firestoreUsed + guestUsed).clamp(0, dailyLimit);

    return ScanQuota(
      dailyLimit: dailyLimit,
      used: used,
      rewardedBonus: 0,
      remaining: (dailyLimit - used).clamp(0, dailyLimit),
      aiEnabled: aiEnabled,
      maintenanceMode: maintenanceMode,
      isGuest: false,
    );
  }

  Future<void> recordSuccessfulScan({String? ownerUid}) async {
    if (ownerUid == null || ownerUid == guestOwnerUid) {
      await GuestQuotaStore.recordSuccessfulScan();
      return;
    }

    final now = DateTime.now();
    final day = '${now.year}-${_two(now.month)}-${_two(now.day)}';
    final usageRef = firestore.collection('daily_usage').doc('$ownerUid-$day');

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(usageRef);
      final existing = snapshot.data();
      if (existing != null && existing['user_id'] != ownerUid) {
        throw const RepositoryException('Invalid usage record owner.');
      }

      final requestCount = (_asInt(existing?['request_count']) ?? 0) + 1;
      final successfulCount = (_asInt(existing?['successful_count']) ?? 0) + 1;
      transaction.set(usageRef, {
        'user_id': ownerUid,
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
    this.isGuest = false,
  });

  factory ScanQuota.fromJson(Map<String, dynamic> json) => ScanQuota(
    dailyLimit: _asInt(json['daily_limit']) ?? 3,
    used: _asInt(json['used']) ?? 0,
    rewardedBonus: _asInt(json['rewarded_bonus']) ?? 0,
    remaining: _asInt(json['remaining']) ?? 0,
    aiEnabled: json['ai_enabled'] == true,
    maintenanceMode: json['maintenance_mode'] == true,
    isGuest: json['is_guest'] == true,
  );

  final int dailyLimit;
  final int used;
  final int rewardedBonus;
  final int remaining;
  final bool aiEnabled;
  final bool maintenanceMode;

  /// True when the quota belongs to an anonymous guest (daily limit is the
  /// guest free-scan allowance and usage lives on the device).
  final bool isGuest;
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
