import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final prescriptionProcessingServiceProvider =
    Provider<PrescriptionProcessingService?>((ref) {
      if (!AppConfig.hasSupabaseConfig) return null;
      return PrescriptionProcessingService(Supabase.instance.client);
    });

class PrescriptionProcessingService {
  const PrescriptionProcessingService(this.client);

  final SupabaseClient client;

  Future<ProcessingOutcome> process(String prescriptionId) async {
    try {
      final response = await client.functions.invoke(
        'process-prescription',
        body: {'prescription_id': prescriptionId},
      );
      if (response.status < 200 || response.status >= 300) {
        throw ProcessingException(_messageFromPayload(response.data));
      }
      final data = response.data;
      if (data is! Map) {
        throw const ProcessingException('The processing response was invalid.');
      }
      final returnedId = data['prescription_id']?.toString();
      if (returnedId != prescriptionId) {
        throw const ProcessingException('The processing response was invalid.');
      }
      return ProcessingOutcome(
        prescriptionId: returnedId!,
        status: data['status']?.toString() ?? 'completed',
        medicineCount: _asInteger(data['medicine_count']),
        needsReview: data['needs_manual_review'] == true,
        imageDeleted: data['image_deleted'] == true,
      );
    } on FunctionException catch (error) {
      throw ProcessingException(_messageFromPayload(error.details));
    } catch (error) {
      if (error is ProcessingException) rethrow;
      throw const ProcessingException(
        'Processing could not be completed. Check your connection and retry.',
      );
    }
  }

  String _messageFromPayload(Object? payload) {
    if (payload is Map) {
      final error = payload['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
      if (payload['message'] is String) return payload['message'] as String;
    }
    return 'AI processing failed. Please try again.';
  }

  int _asInteger(Object? value) => value is int ? value : 0;
}

class ProcessingOutcome {
  const ProcessingOutcome({
    required this.prescriptionId,
    required this.status,
    required this.medicineCount,
    required this.needsReview,
    required this.imageDeleted,
  });

  final String prescriptionId;
  final String status;
  final int medicineCount;
  final bool needsReview;
  final bool imageDeleted;
}

class ProcessingException implements Exception {
  const ProcessingException(this.message);
  final String message;
}
