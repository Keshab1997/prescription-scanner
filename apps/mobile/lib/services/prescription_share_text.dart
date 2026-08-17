import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';

/// Plain-text export of a transcription. Never includes the prescription image.
String prescriptionShareText(ExtractedPrescription details) {
  final buffer = StringBuffer()
    ..writeln('${LegalCopy.appName} — AI transcription only')
    ..writeln(LegalCopy.medicalShort)
    ..writeln();
  if (!details.isPrescription) {
    buffer.writeln('Not recognized as a prescription.');
    return buffer.toString().trim();
  }
  if (details.medicines.isEmpty) {
    buffer.writeln('No medicines could be read.');
    return buffer.toString().trim();
  }
  for (var i = 0; i < details.medicines.length; i++) {
    final m = details.medicines[i];
    final bits = <String>[
      m.name,
      if (m.strength != null) m.strength!,
      if (m.dosage != null) m.dosage!,
      if (m.frequency != null) m.frequency!,
      if (m.duration != null) m.duration!,
      if (m.route != null) m.route!,
    ];
    buffer.writeln('${i + 1}. ${bits.join(' · ')}');
    if (m.instructions != null) buffer.writeln('   ${m.instructions}');
  }
  if (details.tests.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('Tests: ${details.tests.join(', ')}');
  }
  if (details.followUp != null) {
    buffer.writeln('Follow-up: ${details.followUp}');
  }
  buffer
    ..writeln()
    ..writeln('Confirm every detail with a doctor or pharmacist.');
  return buffer.toString().trim();
}
