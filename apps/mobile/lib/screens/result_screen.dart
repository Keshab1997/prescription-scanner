import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/result_store.dart';
import 'package:prescription_scanner/theme.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete this item.')));
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
                ...details.medicines.map(
                  (medicine) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MedicineCard(medicine: medicine),
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
  const _MedicineCard({required this.medicine});
  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final confidence = (medicine.confidence * 100).round();
    final details = <(String, String?)>[
      ('Strength', medicine.strength),
      ('Dosage', medicine.dosage),
      ('Frequency', medicine.frequency),
      ('Route', medicine.route),
      ('Duration', medicine.duration),
      ('Instructions', medicine.instructions),
    ];
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
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
        title: Text(
          medicine.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          [
                medicine.strength,
                medicine.frequency,
              ].whereType<String>().join(' · ').isEmpty
              ? 'Tap to view visible details'
              : [
                  medicine.strength,
                  medicine.frequency,
                ].whereType<String>().join(' · '),
        ),
        trailing: Text(
          '$confidence%',
          style: TextStyle(
            color: medicine.needsReview
                ? const Color(0xFFA56100)
                : AppColors.success,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          if (medicine.needsReview)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'This item is uncertain. Check the original prescription or ask a qualified pharmacist/doctor.',
                style: TextStyle(color: Color(0xFF805511), fontSize: 12),
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.15,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: details
                .map(
                  (item) =>
                      _Datum(label: item.$1, value: item.$2 ?? 'Not visible'),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Datum extends StatelessWidget {
  const _Datum({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ],
      ),
    );
  }
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
