import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';

void main() {
  group('ScanQuota', () {
    test('parses the secure quota RPC response', () {
      final quota = ScanQuota.fromJson({
        'daily_limit': 3,
        'used': 1,
        'rewarded_bonus': 1,
        'remaining': 3,
        'ai_enabled': true,
        'maintenance_mode': false,
      });

      expect(quota.dailyLimit, 3);
      expect(quota.used, 1);
      expect(quota.rewardedBonus, 1);
      expect(quota.remaining, 3);
      expect(quota.aiEnabled, isTrue);
      expect(quota.maintenanceMode, isFalse);
    });
  });

  group('ExtractedPrescription', () {
    test('parses medicine list and review state', () {
      final result = ExtractedPrescription.fromJson({
        'id': '11111111-1111-4111-8111-111111111111',
        'overall_confidence': 0.72,
        'is_prescription': true,
        'needs_manual_review': true,
        'created_at': '2026-08-13T10:00:00Z',
        'image_deleted': true,
        'medicines': [
          {'raw_name': 'Sample A'},
          {'raw_name': 'Sample B'},
        ],
      });

      expect(result.medicines, hasLength(2));
      expect(result.needsManualReview, isTrue);
      expect(result.isPrescription, isTrue);
      expect(result.imageDeleted, isTrue);
      expect(result.id, '11111111-1111-4111-8111-111111111111');
    });

    test('treats missing is_prescription as a prescription', () {
      final result = ExtractedPrescription.fromJson({
        'id': '22222222-2222-4222-8222-222222222222',
        'created_at': '2026-08-13T10:00:00Z',
      });

      expect(result.isPrescription, isTrue);
      expect(result.medicines, isEmpty);
      expect(result.overallConfidence, 0.0);
    });
  });
}
