import 'package:flutter_test/flutter_test.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/prescription_share_text.dart';

void main() {
  ExtractedPrescription sample() => ExtractedPrescription(
    id: 'rx-1',
    overallConfidence: 0.9,
    needsManualReview: false,
    isPrescription: true,
    medicines: const [
      Medicine(
        name: 'Paracetamol',
        strength: '500 mg',
        dosage: '1 tablet',
        frequency: 'twice a day',
        duration: '5 days',
        confidence: 0.9,
        needsReview: false,
        position: 1,
      ),
    ],
    warnings: const [],
    tests: const ['CBC'],
    followUp: '7 days',
    createdAt: DateTime(2026, 8, 18),
  );

  test('share text is transcription only and never claims diagnosis', () {
    final text = prescriptionShareText(sample());
    expect(text.toLowerCase(), contains('transcription'));
    expect(text.toLowerCase(), contains('not a diagnosis'));
    expect(text, contains('Paracetamol'));
    expect(text, contains('500 mg'));
    expect(text, contains('CBC'));
    expect(text.toLowerCase(), isNot(contains('diagnose')));
  });

  test('user edits persist through json', () {
    final edited = sample().medicines.first.copyWith(
      name: 'Paracetamol extra',
      userEdited: true,
      needsReview: false,
    );
    final restored = Medicine.fromJson(edited.toJson());
    expect(restored.name, 'Paracetamol extra');
    expect(restored.userEdited, isTrue);
    expect(restored.needsReview, isFalse);
  });
}
