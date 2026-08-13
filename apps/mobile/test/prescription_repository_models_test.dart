import 'package:flutter_test/flutter_test.dart';
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

  group('PrescriptionSummary', () {
    test('counts structured medicines and exposes review state', () {
      final summary = PrescriptionSummary.fromJson({
        'id': '11111111-1111-4111-8111-111111111111',
        'status': 'needs_review',
        'overall_confidence': 0.72,
        'created_at': '2026-08-13T10:00:00Z',
        'processed_at': '2026-08-13T10:00:05Z',
        'image_deleted_at': '2026-08-13T10:00:06Z',
        'structured_result': {
          'medicines': [
            {'raw_name': 'Sample A'},
            {'raw_name': 'Sample B'},
          ],
        },
      });

      expect(summary.medicineCount, 2);
      expect(summary.needsReview, isTrue);
      expect(summary.isProcessing, isFalse);
      expect(summary.isFailed, isFalse);
      expect(summary.imageDeleted, isTrue);
    });

    test('treats uploaded records as processing', () {
      final summary = PrescriptionSummary.fromJson({
        'id': '22222222-2222-4222-8222-222222222222',
        'status': 'uploaded',
        'created_at': '2026-08-13T10:00:00Z',
      });

      expect(summary.isProcessing, isTrue);
      expect(summary.medicineCount, 0);
    });
  });

  group('PrescriptionDetail', () {
    test('parses visible details and sorts medicines by position', () {
      final detail = PrescriptionDetail.fromJson({
        'id': '33333333-3333-4333-8333-333333333333',
        'status': 'needs_review',
        'overall_confidence': 0.81,
        'created_at': '2026-08-13T10:00:00Z',
        'processed_at': '2026-08-13T10:00:05Z',
        'image_deleted_at': '2026-08-13T10:00:06Z',
        'structured_result': {
          'is_prescription': true,
          'needs_manual_review': true,
          'warnings': ['Verify one unclear field.'],
          'tests': ['Complete Blood Count'],
          'follow_up': 'After 7 days',
        },
        'prescription_medicines': [
          {
            'id': 'medicine-2',
            'position': 2,
            'raw_name': 'SampleMed Beta',
            'normalized_name': null,
            'strength': '10 mg',
            'dosage': '1 tablet',
            'frequency': 'Once at night',
            'route': 'Oral',
            'duration': '7 days',
            'instructions': null,
            'confidence': 0.74,
            'needs_review': true,
          },
          {
            'id': 'medicine-1',
            'position': 1,
            'raw_name': 'SampleMed Alpha',
            'normalized_name': 'SampleMed Alpha',
            'strength': '500 mg',
            'dosage': '1 tablet',
            'frequency': 'Twice daily',
            'route': 'Oral',
            'duration': '5 days',
            'instructions': 'After food',
            'confidence': 0.96,
            'needs_review': false,
          },
        ],
      });

      expect(detail.medicines, hasLength(2));
      expect(detail.medicines.first.position, 1);
      expect(detail.medicines.first.name, 'SampleMed Alpha');
      expect(detail.medicines.last.needsReview, isTrue);
      expect(detail.needsManualReview, isTrue);
      expect(detail.isPrescription, isTrue);
      expect(detail.imageDeleted, isTrue);
      expect(detail.tests, ['Complete Blood Count']);
      expect(detail.followUp, 'After 7 days');
      expect(detail.warnings, ['Verify one unclear field.']);
    });
  });
}
