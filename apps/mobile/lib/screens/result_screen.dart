import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/result_store.dart';
import 'package:prescription_scanner/theme.dart';

/// UI language for the patient-friendly summary on the result screen.
enum ResultLanguage {
  en('EN', 'English', 'In plain language'),
  bn('বাং', 'বাংলা', 'সহজ ভাষায়'),
  hi('हि', 'हिन्दी', 'सरल भाषा में');

  const ResultLanguage(this.code, this.label, this.caption);
  final String code;
  final String label;
  final String caption;

  /// Returns the model-provided summary sentence for [medicine] in this
  /// language, falling back to English then to the raw name.
  String pickSummary(Medicine medicine) {
    final byLang = switch (this) {
      ResultLanguage.en => medicine.summaryEn,
      ResultLanguage.bn => medicine.summaryBn,
      ResultLanguage.hi => medicine.summaryHi,
    };
    if (byLang != null && byLang.trim().isNotEmpty) return byLang;
    if (medicine.summaryEn != null && medicine.summaryEn!.trim().isNotEmpty) {
      return medicine.summaryEn!;
    }
    return medicine.name;
  }

  /// Returns the "what it is for" text for [medicine] in this language,
  /// falling back to English then to null.
  String? pickPurpose(Medicine medicine) {
    final byLang = switch (this) {
      ResultLanguage.en => medicine.purposeEn,
      ResultLanguage.bn => medicine.purposeBn,
      ResultLanguage.hi => medicine.purposeHi,
    };
    if (byLang != null && byLang.trim().isNotEmpty) return byLang;
    return medicine.purposeEn?.trim().isNotEmpty == true
        ? medicine.purposeEn
        : null;
  }
}

/// Selected summary language for the result screen.
final resultLanguageProvider =
    NotifierProvider<ResultLanguageNotifier, ResultLanguage>(
      ResultLanguageNotifier.new,
    );

class ResultLanguageNotifier extends Notifier<ResultLanguage> {
  @override
  ResultLanguage build() => ResultLanguage.bn;

  void set(ResultLanguage language) => state = language;
}

class ResultScreen extends ConsumerWidget {
  const ResultScreen({required this.prescriptionId, super.key});

  final String prescriptionId;

  Future<void> deleteHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this history item?'),
        content: const Text(
          'The extracted medicine list and associated operational records will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      ResultStore.instance.delete(prescriptionId);
      if (context.mounted) context.go('/history');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this item.')),
      );
    }
  }

  Future<void> reportIssue(BuildContext context, WidgetRef ref) async {
    var category = 'incorrect_name';
    final details = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report an extraction issue',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Do not include additional private medical information.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Issue type'),
                items: const [
                  DropdownMenuItem(
                    value: 'incorrect_name',
                    child: Text('Medicine name is incorrect'),
                  ),
                  DropdownMenuItem(
                    value: 'incorrect_details',
                    child: Text('Dose or instruction is incorrect'),
                  ),
                  DropdownMenuItem(
                    value: 'missing_medicine',
                    child: Text('A medicine is missing'),
                  ),
                  DropdownMenuItem(
                    value: 'not_prescription',
                    child: Text('This was not a prescription'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other issue')),
                ],
                onChanged: (value) =>
                    setModalState(() => category = value ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Optional details',
                  hintText: 'Describe the extraction problem only',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted == true) {
      // Local-only build: feedback is acknowledged but not persisted to a
      // backend. Wire this to your own endpoint if you add one later.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you. Your report was noted.')),
        );
      }
    }
    details.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (prescriptionId.isEmpty) {
      return const _ResultError(message: 'Prescription ID is missing.');
    }

    final details = ResultStore.instance.get(prescriptionId);
    if (details == null) {
      return const _ResultError(message: 'The result could not be found.');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extraction result'),
        actions: [
          _LanguageToggle(language: ref.watch(resultLanguageProvider)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') deleteHistory(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.danger),
                    SizedBox(width: 9),
                    Text('Delete history'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Results are local; nothing to refresh.
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            _QualityHeader(details: details),
            const SizedBox(height: 14),
            const _MedicalWarning(),
            if (details.imageDeleted) ...[
              const SizedBox(height: 10),
              const _PrivacyNotice(),
            ],
            if (details.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _WarningsCard(warnings: details.warnings),
            ],
            const SizedBox(height: 16),
            if (!details.isPrescription)
              const _EmptyResult(
                icon: Icons.image_not_supported_outlined,
                title: 'Not recognized as a prescription',
                message:
                    'No medicine details were created. Try a clearer prescription image.',
              )
            else if (details.medicines.isEmpty)
              const _EmptyResult(
                icon: Icons.visibility_off_outlined,
                title: 'No medicines could be read',
                message:
                    'The app did not guess unclear handwriting. Try a brighter, closer image.',
              )
            else ...[
              Text(
                '${details.medicines.length} medicine${details.medicines.length == 1 ? '' : 's'} found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              _PatientSummary(
                details: details,
                language: ref.watch(resultLanguageProvider),
              ),
              const SizedBox(height: 12),
              ...details.medicines.map(
                (medicine) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MedicineCard(
                    medicine: medicine,
                    language: ref.watch(resultLanguageProvider),
                  ),
                ),
              ),
            ],
            if (details.tests.isNotEmpty || details.followUp != null) ...[
              const SizedBox(height: 8),
              _OtherVisibleDetails(details: details),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => reportIssue(context, ref),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report an extraction issue'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Done'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Prescription Scanner does not diagnose, treat, cure or prevent any medical condition. Always consult a qualified healthcare professional.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.language});
  final ResultLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: ResultLanguage.values
            .map((lang) => _LangChip(lang: lang, selected: lang == language))
            .toList(),
      ),
    );
  }
}

class _LangChip extends ConsumerWidget {
  const _LangChip({required this.lang, required this.selected});
  final ResultLanguage lang;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => ref.read(resultLanguageProvider.notifier).set(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          lang.code,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.muted,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _PatientSummary extends StatelessWidget {
  const _PatientSummary({required this.details, required this.language});
  final ExtractedPrescription details;
  final ResultLanguage language;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];
    for (var i = 0; i < details.medicines.length; i++) {
      final medicine = details.medicines[i];
      lines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}. ',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.teal,
                ),
              ),
              Expanded(
                child: Text(
                  '${medicine.name}: ${language.pickSummary(medicine)}',
                  style: const TextStyle(height: 1.4, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (details.tests.isNotEmpty) {
      lines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${_extraLabel(language)} ${details.tests.join(', ')}',
            style: const TextStyle(height: 1.4, fontSize: 14),
          ),
        ),
      );
    }
    if (details.followUp != null) {
      lines.add(
        Text(
          '${_followUpLabel(language)} ${details.followUp}',
          style: const TextStyle(height: 1.4, fontSize: 14),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.indigoSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                color: AppColors.indigo,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _headerText(language),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines,
        ],
      ),
    );
  }

  String _headerText(ResultLanguage lang) => switch (lang) {
    ResultLanguage.en =>
      'In this prescription, the following medicines are written:',
    ResultLanguage.bn => 'এই প্রেসক্রিপশনে নিচের ওষুধগুলো লেখা হয়েছে:',
    ResultLanguage.hi =>
      'इस प्रिस्क्रिप्शन में निम्नलिखित दवाइयाँ लिखी गई हैं:',
  };

  String _extraLabel(ResultLanguage lang) => switch (lang) {
    ResultLanguage.en => 'Tests advised:',
    ResultLanguage.bn => 'পরামর্শ দেওয়া টেস্ট:',
    ResultLanguage.hi => 'सुझाई गई जाँच:',
  };

  String _followUpLabel(ResultLanguage lang) => switch (lang) {
    ResultLanguage.en => 'Follow-up:',
    ResultLanguage.bn => 'ফলো-আপ:',
    ResultLanguage.hi => 'फॉलो-अप:',
  };
}

class _QualityHeader extends StatelessWidget {
  const _QualityHeader({required this.details});
  final ExtractedPrescription details;

  @override
  Widget build(BuildContext context) {
    final percentage = (details.overallConfidence * 100).round();
    final label = !details.isPrescription
        ? 'Not recognized'
        : details.needsManualReview
        ? 'Needs review'
        : 'Clear result';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF9F6), AppColors.indigoSoft],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('d MMM yyyy · h:mm a').format(details.createdAt),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: details.overallConfidence,
                  strokeWidth: 6,
                  color: details.needsManualReview
                      ? AppColors.amber
                      : AppColors.teal,
                  backgroundColor: Colors.white70,
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.language});
  final Medicine medicine;
  final ResultLanguage language;

  @override
  Widget build(BuildContext context) {
    final confidence = (medicine.confidence * 100).round();
    final friendly = language.pickSummary(medicine);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showMedicineDetail(context, medicine, language),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: medicine.needsReview
                      ? AppColors.amberSoft
                      : AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  medicine.position.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: medicine.needsReview
                        ? const Color(0xFFA56100)
                        : AppColors.teal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      friendly,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$confidence%',
                    style: TextStyle(
                      color: medicine.needsReview
                          ? const Color(0xFFA56100)
                          : AppColors.success,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMedicineDetail(
  BuildContext context,
  Medicine m,
  ResultLanguage lang,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MedicineDetailSheet(medicine: m, language: lang),
  );
}

class _MedicineDetailSheet extends StatelessWidget {
  const _MedicineDetailSheet({required this.medicine, required this.language});
  final Medicine medicine;
  final ResultLanguage language;

  @override
  Widget build(BuildContext context) {
    final rows = <_DetailRow>[
      _DetailRow(
        icon: Icons.medication_rounded,
        title: 'Medicine',
        value: medicine.name,
        hint: 'This is the medicine identified from the prescription image.',
      ),
      if (language.pickPurpose(medicine) != null)
        _DetailRow(
          icon: Icons.help_outline_rounded,
          title: 'What it is for',
          value: language.pickPurpose(medicine)!,
          hint: 'Why this medicine is given, based on the prescription.',
        ),
      if (medicine.normalizedName != null)
        _DetailRow(
          icon: Icons.check_circle_outline_rounded,
          title: 'Standard name',
          value: medicine.normalizedName!,
          hint: 'The commonly used / generic name for this medicine.',
        ),
      _DetailRow(
        icon: Icons.straighten_rounded,
        title: 'Strength',
        value: medicine.strength ?? 'Not visible',
        hint: 'How strong each dose is (for example 500 mg).',
      ),
      _DetailRow(
        icon: Icons.science_rounded,
        title: 'Dosage',
        value: medicine.dosage ?? 'Not visible',
        hint: 'How much to take at a time (for example 1 tablet).',
      ),
      _DetailRow(
        icon: Icons.repeat_rounded,
        title: 'How often (frequency)',
        value: medicine.frequency ?? 'Not visible',
        hint: 'How many times per day to take it (for example twice a day).',
      ),
      _DetailRow(
        icon: Icons.calendar_today_rounded,
        title: 'For how long (duration)',
        value: medicine.duration ?? 'Not visible',
        hint: 'How many days to continue the medicine.',
      ),
      _DetailRow(
        icon: Icons.route_rounded,
        title: 'Route',
        value: medicine.route ?? 'Not visible',
        hint: 'How it enters the body (for example by mouth).',
      ),
      if (medicine.instructions != null)
        _DetailRow(
          icon: Icons.info_outline_rounded,
          title: 'Instructions',
          value: medicine.instructions!,
          hint: 'Any special note from the prescription.',
        ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 6, bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicine.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.muted,
                ),
              ],
            ),
            if (medicine.needsReview)
              Container(
                margin: const EdgeInsets.only(top: 6, bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFA56100)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This item is uncertain. Please check the original prescription or ask a pharmacist/doctor.',
                        style: TextStyle(
                          color: Color(0xFF805511),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _DetailRowCard(row: rows[i]),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'AI transcription only — not medical advice. Verify with a doctor or pharmacist.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
    this.hint,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? hint;
}

class _DetailRowCard extends StatelessWidget {
  const _DetailRowCard({required this.row});
  final _DetailRow row;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.tealSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(row.icon, color: AppColors.teal, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                row.value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              if (row.hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  row.hint!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _MedicalWarning extends StatelessWidget {
  const _MedicalWarning();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.amberSoft,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFF2D9A2)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.amber),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Verify before use. This is an AI transcription, not medical advice.',
            style: TextStyle(color: Color(0xFF805511), height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.tealSoft,
      borderRadius: BorderRadius.circular(13),
    ),
    child: const Row(
      children: [
        Icon(Icons.delete_sweep_outlined, color: AppColors.teal),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'The original server image has been deleted. Only this structured result remains.',
            style: TextStyle(color: AppColors.teal, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});
  final List<String> warnings;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI review notes',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $warning',
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OtherVisibleDetails extends StatelessWidget {
  const _OtherVisibleDetails({required this.details});
  final ExtractedPrescription details;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Other visible details',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          if (details.tests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Tests: ${details.tests.join(', ')}'),
          ],
          if (details.followUp != null) ...[
            const SizedBox(height: 8),
            Text('Follow-up: ${details.followUp}'),
          ],
        ],
      ),
    ),
  );
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 42),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ResultError extends StatelessWidget {
  const _ResultError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Extraction result')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
