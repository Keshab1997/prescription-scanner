import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository?>((ref) {
  if (!AppConfig.hasSupabaseConfig) return null;
  return PrescriptionRepository(Supabase.instance.client);
});

final quotaProvider = FutureProvider<ScanQuota>((ref) async {
  final repository = ref.watch(prescriptionRepositoryProvider);
  if (repository == null) {
    throw const RepositoryException('Supabase is not configured.');
  }
  return repository.loadQuota();
});

final recentPrescriptionsProvider = FutureProvider<List<PrescriptionSummary>>((
  ref,
) async {
  final repository = ref.watch(prescriptionRepositoryProvider);
  if (repository == null) {
    throw const RepositoryException('Supabase is not configured.');
  }
  return repository.loadRecent(limit: 3);
});

final prescriptionHistoryProvider = FutureProvider<List<PrescriptionSummary>>((
  ref,
) async {
  final repository = ref.watch(prescriptionRepositoryProvider);
  if (repository == null) {
    throw const RepositoryException('Supabase is not configured.');
  }
  return repository.loadRecent(limit: 60);
});

final prescriptionDetailProvider =
    FutureProvider.family<PrescriptionDetail, String>((
      ref,
      prescriptionId,
    ) async {
      final repository = ref.watch(prescriptionRepositoryProvider);
      if (repository == null) {
        throw const RepositoryException('Supabase is not configured.');
      }
      if (prescriptionId.isEmpty) {
        throw const RepositoryException('Missing prescription ID.');
      }
      return repository.loadDetail(prescriptionId);
    });

class PrescriptionRepository {
  const PrescriptionRepository(this.client);
  final SupabaseClient client;

  Future<ScanQuota> loadQuota() async {
    try {
      final response = await client.rpc('get_my_quota');
      final rows = response is List ? response : const <dynamic>[];
      if (rows.isEmpty || rows.first is! Map) {
        throw const RepositoryException('Scan limits are unavailable.');
      }
      return ScanQuota.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } on RepositoryException {
      rethrow;
    } catch (_) {
      throw const RepositoryException('Could not load today’s scan limits.');
    }
  }

  Future<List<PrescriptionSummary>> loadRecent({required int limit}) async {
    try {
      final rows = await client
          .from('prescriptions')
          .select(
            'id,status,overall_confidence,error_code,created_at,processed_at,'
            'image_deleted_at,structured_result',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map(
            (row) =>
                PrescriptionSummary.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    } catch (_) {
      throw const RepositoryException('Could not load prescription history.');
    }
  }

  Future<PrescriptionDetail> loadDetail(String prescriptionId) async {
    try {
      final row = Map<String, dynamic>.from(
        await client
            .from('prescriptions')
            .select(
              'id,status,overall_confidence,structured_result,image_deleted_at,'
              'processed_at,created_at,'
              'prescription_medicines('
              'id,position,raw_name,normalized_name,strength,dosage,frequency,'
              'route,duration,instructions,confidence,needs_review)',
            )
            .eq('id', prescriptionId)
            .single(),
      );
      return PrescriptionDetail.fromJson(row);
    } catch (_) {
      throw const RepositoryException(
        'Could not load this prescription result.',
      );
    }
  }

  Future<void> deletePrescription(String prescriptionId) async {
    try {
      final deleted = await client.rpc(
        'delete_my_completed_prescription',
        params: {'p_prescription_id': prescriptionId},
      );
      if (deleted != true) {
        throw const RepositoryException(
          'This record cannot be deleted until its source image is removed.',
        );
      }
    } on RepositoryException {
      rethrow;
    } catch (_) {
      throw const RepositoryException('Could not delete this prescription.');
    }
  }

  Future<void> submitFeedback({
    required String prescriptionId,
    required String category,
    String? details,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const RepositoryException('Please sign in again.');
    }
    try {
      await client.from('prescription_feedback').insert({
        'user_id': userId,
        'prescription_id': prescriptionId,
        'category': category,
        'details': _nullable(details),
      });
    } catch (_) {
      throw const RepositoryException('Could not submit the report.');
    }
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
    dailyLimit: _asInt(json['daily_limit']),
    used: _asInt(json['used']),
    rewardedBonus: _asInt(json['rewarded_bonus']),
    remaining: _asInt(json['remaining']),
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

class PrescriptionSummary {
  const PrescriptionSummary({
    required this.id,
    required this.status,
    required this.overallConfidence,
    required this.errorCode,
    required this.createdAt,
    required this.processedAt,
    required this.medicineCount,
    required this.imageDeleted,
  });

  factory PrescriptionSummary.fromJson(Map<String, dynamic> json) {
    final result = _map(json['structured_result']);
    final medicines = result['medicines'];
    return PrescriptionSummary(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'uploaded',
      overallConfidence: _asDouble(json['overall_confidence']),
      errorCode: _nullable(json['error_code']?.toString()),
      createdAt: _asDate(json['created_at']),
      processedAt: _asNullableDate(json['processed_at']),
      medicineCount: medicines is List ? medicines.length : 0,
      imageDeleted: json['image_deleted_at'] != null,
    );
  }

  final String id;
  final String status;
  final double? overallConfidence;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime? processedAt;
  final int medicineCount;
  final bool imageDeleted;

  bool get isProcessing =>
      status == 'uploaded' || status == 'queued' || status == 'processing';
  bool get isFailed => status == 'failed';
  bool get needsReview => status == 'needs_review';
}

class PrescriptionDetail {
  const PrescriptionDetail({
    required this.id,
    required this.status,
    required this.overallConfidence,
    required this.needsManualReview,
    required this.isPrescription,
    required this.imageDeleted,
    required this.createdAt,
    required this.processedAt,
    required this.medicines,
    required this.warnings,
    required this.tests,
    required this.followUp,
  });

  factory PrescriptionDetail.fromJson(Map<String, dynamic> json) {
    final result = _map(json['structured_result']);
    final nestedMedicines = json['prescription_medicines'];
    final medicines = nestedMedicines is List
        ? nestedMedicines
              .whereType<Map>()
              .map(
                (row) => MedicineItem.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList()
        : <MedicineItem>[];
    medicines.sort((a, b) => a.position.compareTo(b.position));
    final status = json['status']?.toString() ?? 'completed';
    return PrescriptionDetail(
      id: json['id']?.toString() ?? '',
      status: status,
      overallConfidence:
          _asDouble(json['overall_confidence']) ??
          _asDouble(result['overall_confidence']) ??
          0,
      needsManualReview:
          status == 'needs_review' || result['needs_manual_review'] == true,
      isPrescription: result['is_prescription'] != false,
      imageDeleted: json['image_deleted_at'] != null,
      createdAt: _asDate(json['created_at']),
      processedAt: _asNullableDate(json['processed_at']),
      medicines: medicines,
      warnings: _stringList(result['warnings']),
      tests: _stringList(result['tests']),
      followUp: _nullable(result['follow_up']?.toString()),
    );
  }

  final String id;
  final String status;
  final double overallConfidence;
  final bool needsManualReview;
  final bool isPrescription;
  final bool imageDeleted;
  final DateTime createdAt;
  final DateTime? processedAt;
  final List<MedicineItem> medicines;
  final List<String> warnings;
  final List<String> tests;
  final String? followUp;
}

class MedicineItem {
  const MedicineItem({
    required this.id,
    required this.position,
    required this.name,
    required this.normalizedName,
    required this.strength,
    required this.dosage,
    required this.frequency,
    required this.route,
    required this.duration,
    required this.instructions,
    required this.confidence,
    required this.needsReview,
  });

  factory MedicineItem.fromJson(Map<String, dynamic> json) => MedicineItem(
    id: json['id']?.toString() ?? '',
    position: _asInt(json['position']),
    name: json['raw_name']?.toString() ?? 'Unclear medicine',
    normalizedName: _nullable(json['normalized_name']?.toString()),
    strength: _nullable(json['strength']?.toString()),
    dosage: _nullable(json['dosage']?.toString()),
    frequency: _nullable(json['frequency']?.toString()),
    route: _nullable(json['route']?.toString()),
    duration: _nullable(json['duration']?.toString()),
    instructions: _nullable(json['instructions']?.toString()),
    confidence: _asDouble(json['confidence']) ?? 0,
    needsReview: json['needs_review'] == true,
  );

  final String id;
  final int position;
  final String name;
  final String? normalizedName;
  final String? strength;
  final String? dosage;
  final String? frequency;
  final String? route;
  final String? duration;
  final String? instructions;
  final double confidence;
  final bool needsReview;
}

class RepositoryException implements Exception {
  const RepositoryException(this.message);
  final String message;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

DateTime _asDate(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

DateTime? _asNullableDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

String? _nullable(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

List<String> _stringList(Object? value) => value is List
    ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList()
    : const <String>[];
