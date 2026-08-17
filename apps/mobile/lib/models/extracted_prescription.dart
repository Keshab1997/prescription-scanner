/// Local representation of an extracted prescription, stored on-device only.
///
/// Field names intentionally mirror the former server-backed
/// `PrescriptionDetail` / `MedicineItem` so the existing result-screen UI
/// widgets can be reused with minimal changes.
class ExtractedPrescription {
  const ExtractedPrescription({
    required this.id,
    required this.overallConfidence,
    required this.needsManualReview,
    required this.isPrescription,
    required this.medicines,
    required this.warnings,
    required this.tests,
    required this.followUp,
    required this.createdAt,
    this.imageDeleted = false,
    this.model,
  });

  factory ExtractedPrescription.fromJson(Map<String, dynamic> json) {
    final medicines =
        (json['medicines'] as List?)
            ?.whereType<Map>()
            .map((row) => Medicine.fromJson(Map<String, dynamic>.from(row)))
            .toList() ??
        <Medicine>[];
    return ExtractedPrescription(
      id: json['id']?.toString() ?? '',
      overallConfidence:
          (json['overall_confidence'] is num ? json['overall_confidence'] : 0)
              .toDouble(),
      needsManualReview: json['needs_manual_review'] == true,
      isPrescription: json['is_prescription'] != false,
      medicines: medicines,
      warnings: _stringList(json['warnings']),
      tests: _stringList(json['tests']),
      followUp: _nullable(json['follow_up']?.toString()),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      imageDeleted: json['image_deleted'] == true,
      model: _nullable(json['model']?.toString()),
    );
  }

  final String id;
  final double overallConfidence;
  final bool needsManualReview;
  final bool isPrescription;
  final List<Medicine> medicines;
  final List<String> warnings;
  final List<String> tests;
  final String? followUp;
  final DateTime createdAt;
  final bool imageDeleted;
  final String? model;

  Map<String, dynamic> toJson() => {
    'id': id,
    'overall_confidence': overallConfidence,
    'needs_manual_review': needsManualReview,
    'is_prescription': isPrescription,
    'medicines': medicines.map((m) => m.toJson()).toList(),
    'warnings': warnings,
    'tests': tests,
    'follow_up': followUp,
    'created_at': createdAt.toIso8601String(),
    'image_deleted': imageDeleted,
    'model': model,
  };

  ExtractedPrescription copyWith({
    String? id,
    double? overallConfidence,
    bool? needsManualReview,
    bool? isPrescription,
    List<Medicine>? medicines,
    List<String>? warnings,
    List<String>? tests,
    String? followUp,
    bool? imageDeleted,
    String? model,
  }) => ExtractedPrescription(
    id: id ?? this.id,
    overallConfidence: overallConfidence ?? this.overallConfidence,
    needsManualReview: needsManualReview ?? this.needsManualReview,
    isPrescription: isPrescription ?? this.isPrescription,
    medicines: medicines ?? this.medicines,
    warnings: warnings ?? this.warnings,
    tests: tests ?? this.tests,
    followUp: followUp ?? this.followUp,
    createdAt: createdAt,
    imageDeleted: imageDeleted ?? this.imageDeleted,
    model: model ?? this.model,
  );
}

class Medicine {
  const Medicine({
    required this.name,
    this.normalizedName,
    this.strength,
    this.dosage,
    this.frequency,
    this.route,
    this.duration,
    this.instructions,
    this.summaryEn,
    this.summaryBn,
    this.summaryHi,
    this.purposeEn,
    this.purposeBn,
    this.purposeHi,
    required this.confidence,
    required this.needsReview,
    this.position = 0,
    this.userEdited = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
    name: json['name']?.toString() ?? 'Unclear medicine',
    normalizedName: _nullable(json['normalized_name']?.toString()),
    strength: _nullable(json['strength']?.toString()),
    dosage: _nullable(json['dosage']?.toString()),
    frequency: _nullable(json['frequency']?.toString()),
    route: _nullable(json['route']?.toString()),
    duration: _nullable(json['duration']?.toString()),
    instructions: _nullable(json['instructions']?.toString()),
    summaryEn: _nullable(json['summary_en']?.toString()),
    summaryBn: _nullable(json['summary_bn']?.toString()),
    summaryHi: _nullable(json['summary_hi']?.toString()),
    purposeEn: _nullable(json['purpose_en']?.toString()),
    purposeBn: _nullable(json['purpose_bn']?.toString()),
    purposeHi: _nullable(json['purpose_hi']?.toString()),
    confidence: (json['confidence'] is num ? json['confidence'] : 0).toDouble(),
    needsReview: json['needs_review'] == true,
    position: json['position'] is int ? json['position'] as int : 0,
    userEdited: json['user_edited'] == true,
  );

  final String name;
  final String? normalizedName;
  final String? strength;
  final String? dosage;
  final String? frequency;
  final String? route;
  final String? duration;
  final String? instructions;
  final String? summaryEn;
  final String? summaryBn;
  final String? summaryHi;
  final String? purposeEn;
  final String? purposeBn;
  final String? purposeHi;
  final double confidence;
  final bool needsReview;
  final int position;
  final bool userEdited;

  Medicine copyWith({
    String? name,
    String? normalizedName,
    String? strength,
    String? dosage,
    String? frequency,
    String? route,
    String? duration,
    String? instructions,
    bool? needsReview,
    bool? userEdited,
  }) => Medicine(
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    strength: strength ?? this.strength,
    dosage: dosage ?? this.dosage,
    frequency: frequency ?? this.frequency,
    route: route ?? this.route,
    duration: duration ?? this.duration,
    instructions: instructions ?? this.instructions,
    summaryEn: summaryEn,
    summaryBn: summaryBn,
    summaryHi: summaryHi,
    purposeEn: purposeEn,
    purposeBn: purposeBn,
    purposeHi: purposeHi,
    confidence: confidence,
    needsReview: needsReview ?? this.needsReview,
    position: position,
    userEdited: userEdited ?? this.userEdited,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'normalized_name': normalizedName,
    'strength': strength,
    'dosage': dosage,
    'frequency': frequency,
    'route': route,
    'duration': duration,
    'instructions': instructions,
    'summary_en': summaryEn,
    'summary_bn': summaryBn,
    'summary_hi': summaryHi,
    'purpose_en': purposeEn,
    'purpose_bn': purposeBn,
    'purpose_hi': purposeHi,
    'confidence': confidence,
    'needs_review': needsReview,
    'position': position,
    'user_edited': userEdited,
  };
}

List<String> _stringList(Object? value) => value is List
    ? value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
    : const <String>[];

String? _nullable(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}
