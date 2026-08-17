import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/services/result_store.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final search = TextEditingController();
  String filter = 'all';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerUid = fb.FirebaseAuth.instance.currentUser?.uid ?? guestOwnerUid;
    final items = ResultStore.instance.getAll(ownerUid);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            // Local store is synchronous; just allow the gesture.
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              Entrance(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your records',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    Text(
                      'History',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Saved on this device — available offline. Scanning needs internet.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Entrance(
                delay: const Duration(milliseconds: 90),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by date or status',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(search.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 140),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip('all', 'All', filter, setFilter),
                      _FilterChip('completed', 'Clear', filter, setFilter),
                      _FilterChip(
                        'needs_review',
                        'Needs review',
                        filter,
                        setFilter,
                      ),
                      _FilterChip(
                        'processing',
                        'Processing',
                        filter,
                        setFilter,
                      ),
                      _FilterChip('failed', 'Failed', filter, setFilter),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Builder(
                builder: (context) {
                  final visible = items.where(matches).toList();
                  if (visible.isEmpty) return const _EmptyHistory();
                  return Column(
                    children: [
                      ...visible.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Entrance(
                            delay: Duration(milliseconds: 200 + entry.key * 60),
                            child: _HistoryItem(
                              item: entry.value,
                              onTap: () => openItem(entry.value),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F5F7),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppColors.teal,
                              size: 20,
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Prepared images are deleted from this device after processing. Only account-scoped structured results remain locally.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void setFilter(String value) => setState(() => filter = value);

  bool matches(ExtractedPrescription item) {
    final status = item.isPrescription ? 'completed' : 'failed';
    final normalizedFilter = item.needsManualReview ? 'needs_review' : status;
    if (filter != 'all' && normalizedFilter != filter) return false;
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      DateFormat('d MMM yyyy h:mm a').format(item.createdAt),
      status,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  void openItem(ExtractedPrescription item) {
    context.push('/result?prescriptionId=${Uri.encodeComponent(item.id)}');
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
    this.value,
    this.label,
    this.selectedValue,
    this.onSelected,
  );
  final String value;
  final String label;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ScaleTap(
      onTap: () => onSelected(value),
      pressedScale: 0.94,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          gradient: value == selectedValue
              ? AppColors.brandGradient
              : const LinearGradient(colors: [Colors.white, Colors.white]),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: value == selectedValue ? Colors.transparent : AppColors.line,
          ),
          boxShadow: value == selectedValue
              ? [
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value == selectedValue ? Colors.white : AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.item, required this.onTap});
  final ExtractedPrescription item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final failed = !item.isPrescription;
    final label = failed
        ? 'Failed'
        : item.needsManualReview
        ? 'Review'
        : 'Clear';
    final color = failed
        ? AppColors.danger
        : item.needsManualReview
        ? const Color(0xFFA56100)
        : AppColors.success;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: AppColors.softGradient,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd').format(item.createdAt),
                      style: const TextStyle(
                        color: AppColors.indigo,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(item.createdAt).toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.indigo,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescription · ${DateFormat('h:mm a').format(item.createdAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !item.isPrescription
                          ? 'Not recognized as a prescription'
                          : '${item.medicines.length} medicines extracted',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.muted, size: 44),
          const SizedBox(height: 10),
          const Text(
            'No matching prescriptions',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text('Try another filter or scan a new prescription.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.push('/upload'),
            child: const Text('Scan prescription'),
          ),
        ],
      ),
    ),
  );
}
