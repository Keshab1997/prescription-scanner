export const RESPONSE_SCHEMA_VERSION = '1.0';

const nullableString = (description: string, maxLength: number) => ({
  type: ['string', 'null'],
  description,
  maxLength,
});

export const prescriptionResponseSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    schema_version: {
      type: 'string',
      enum: [RESPONSE_SCHEMA_VERSION],
      description: 'Version of this extraction schema.',
    },
    is_prescription: {
      type: 'boolean',
      description: 'True only when the image is a medical prescription.',
    },
    document_languages: {
      type: 'array',
      description: 'BCP-47 language codes visible in the document.',
      items: { type: 'string', maxLength: 20 },
      maxItems: 10,
    },
    overall_confidence: {
      type: 'number',
      minimum: 0,
      maximum: 1,
      description: 'Confidence in the transcription, not clinical correctness.',
    },
    needs_manual_review: {
      type: 'boolean',
      description: 'True whenever any visible field is unclear or incomplete.',
    },
    medicines: {
      type: 'array',
      maxItems: 100,
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          raw_name: {
            type: 'string',
            maxLength: 500,
            description: 'Medicine name exactly as visibly read. Never invent a name.',
          },
          normalized_name: nullableString(
            'Canonical spelling only when directly and clearly supported by the visible text; otherwise null.',
            500,
          ),
          strength: nullableString('Visible strength, including unit.', 160),
          dosage: nullableString('Visible amount per administration.', 300),
          frequency: nullableString('Visible frequency or timing.', 300),
          route: nullableString('Visible administration route.', 120),
          duration: nullableString('Visible treatment duration.', 200),
          instructions: nullableString('Other visible instructions only.', 1000),
          confidence: {
            type: 'number',
            minimum: 0,
            maximum: 1,
          },
          needs_review: { type: 'boolean' },
        },
        required: [
          'raw_name',
          'normalized_name',
          'strength',
          'dosage',
          'frequency',
          'route',
          'duration',
          'instructions',
          'confidence',
          'needs_review',
        ],
      },
    },
    tests: {
      type: 'array',
      items: { type: 'string', maxLength: 500 },
      maxItems: 50,
      description: 'Clearly visible lab or diagnostic tests, without interpretation.',
    },
    follow_up: nullableString('Clearly visible follow-up instruction only.', 1000),
    warnings: {
      type: 'array',
      items: { type: 'string', maxLength: 500 },
      maxItems: 50,
      description: 'Transcription uncertainty warnings, not medical warnings.',
    },
  },
  required: [
    'schema_version',
    'is_prescription',
    'document_languages',
    'overall_confidence',
    'needs_manual_review',
    'medicines',
    'tests',
    'follow_up',
    'warnings',
  ],
} as const;

export type MedicineResult = {
  raw_name: string;
  normalized_name: string | null;
  strength: string | null;
  dosage: string | null;
  frequency: string | null;
  route: string | null;
  duration: string | null;
  instructions: string | null;
  confidence: number;
  needs_review: boolean;
};

export type PrescriptionResult = {
  schema_version: string;
  is_prescription: boolean;
  document_languages: string[];
  overall_confidence: number;
  needs_manual_review: boolean;
  medicines: MedicineResult[];
  tests: string[];
  follow_up: string | null;
  warnings: string[];
};

type UnknownRecord = Record<string, unknown>;

const isRecord = (value: unknown): value is UnknownRecord =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const cleanString = (value: unknown, maxLength: number, fallback = ''): string => {
  if (typeof value !== 'string') return fallback;
  return value.trim().slice(0, maxLength);
};

const cleanNullableString = (value: unknown, maxLength: number): string | null => {
  const cleaned = cleanString(value, maxLength);
  return cleaned.length > 0 ? cleaned : null;
};

const cleanNumber = (value: unknown, fallback = 0): number => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  return Math.min(Math.max(value, 0), 1);
};

const cleanStringArray = (
  value: unknown,
  maxItems: number,
  maxLength: number,
): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, maxItems)
    .map((item) => cleanString(item, maxLength))
    .filter((item) => item.length > 0);
};

export function validateAndSanitizeResult(value: unknown): PrescriptionResult {
  if (!isRecord(value)) throw new Error('AI_RESULT_NOT_OBJECT');

  const isPrescription = value.is_prescription === true;
  const rawMedicines = Array.isArray(value.medicines) ? value.medicines : [];
  const medicines: MedicineResult[] = rawMedicines
    .slice(0, 100)
    .filter(isRecord)
    .map((item) => {
      const rawName = cleanString(item.raw_name, 500, 'Unclear');
      const confidence = cleanNumber(item.confidence);
      const needsReview = item.needs_review === true ||
        confidence < 0.78 ||
        rawName === 'Unclear';
      return {
        raw_name: rawName,
        normalized_name: cleanNullableString(item.normalized_name, 500),
        strength: cleanNullableString(item.strength, 160),
        dosage: cleanNullableString(item.dosage, 300),
        frequency: cleanNullableString(item.frequency, 300),
        route: cleanNullableString(item.route, 120),
        duration: cleanNullableString(item.duration, 200),
        instructions: cleanNullableString(item.instructions, 1000),
        confidence,
        needs_review: needsReview,
      };
    });

  const warnings = cleanStringArray(value.warnings, 50, 500);
  const overallConfidence = cleanNumber(value.overall_confidence);

  if (!isPrescription && !warnings.includes('The image was not recognized as a prescription.')) {
    warnings.push('The image was not recognized as a prescription.');
  }
  if (isPrescription && medicines.length === 0) {
    warnings.push('No medicine names could be read with sufficient confidence.');
  }

  const needsManualReview = value.needs_manual_review === true ||
    !isPrescription ||
    medicines.length === 0 ||
    overallConfidence < 0.8 ||
    medicines.some((medicine) => medicine.needs_review);

  return {
    schema_version: RESPONSE_SCHEMA_VERSION,
    is_prescription: isPrescription,
    document_languages: cleanStringArray(value.document_languages, 10, 20),
    overall_confidence: overallConfidence,
    needs_manual_review: needsManualReview,
    medicines,
    tests: cleanStringArray(value.tests, 50, 500),
    follow_up: cleanNullableString(value.follow_up, 1000),
    warnings,
  };
}
