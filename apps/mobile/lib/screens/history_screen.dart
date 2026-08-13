import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/theme.dart';

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
    final history = ref.watch(prescriptionHistoryProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(prescriptionHistoryProvider);
            await ref.read(prescriptionHistoryProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              const Text('Your records', style: TextStyle(color: AppColors.muted)),
              Text('History', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              TextField(
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
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip('all', 'All', filter, setFilter),
                    _FilterChip('completed', 'Clear', filter, setFilter),
                    _FilterChip('needs_review', 'Needs review', filter, setFilter),
                    _FilterChip('processing', 'Processing', filter, setFilter),
                    _FilterChip('failed', 'Failed', filter, setFilter),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              history.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => _HistoryError(
                  onRetry: () => ref.invalidate(prescriptionHistoryProvider),
                ),
                data: (items) {
                  final visible = items.where(matches).toList();
                  if (visible.isEmpty) return const _EmptyHistory();
                  return Column(
                    children: [
                      ...visible.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryItem(
                            item: item,
                            onTap: () => openItem(item),
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
                            Icon(Icons.shield_outlined, color: AppColors.teal, size: 20),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Successful scans keep only structured results. Original server images are deleted.',
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

  bool matches(PrescriptionSummary item) {
    final normalizedFilter = item.isProcessing ? 'processing' : item.status;
    if (filter != 'all' && normalizedFilter != filter) return false;
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      DateFormat('d MMM yyyy h:mm a').format(item.createdAt),
      item.status,
      item.errorCode ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  void openItem(PrescriptionSummary item) {
    if (item.isProcessing || item.isFailed) {
      context.push('/processing?prescriptionId=${Uri.encodeComponent(item.id)}');
    } else {
      context.push('/result?prescriptionId=${Uri.encodeComponent(item.id)}');
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.value, this.label, this.selectedValue, this.onSelected);
  final String value;
  final String label;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(label),
          selected: value == selectedValue,
          onSelected: (_) => onSelected(value),
        ),
      );
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.item, required this.onTap});
  final PrescriptionSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = item.isFailed
        ? 'Failed'
        : item.isProcessing
            ? 'Processing'
            : item.needsReview
                ? 'Review'
                : 'Clear';
    final color = item.isFailed
        ? AppColors.danger
        : item.isProcessing
            ? AppColors.indigo
            : item.needsReview
                ? const Color(0xFFA56100)
                : AppColors.success;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.indigoSoft,
                  borderRadius: BorderRadius.circular(13),
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
                      item.isFailed
                          ? 'Tap to retry'
                          : item.isProcessing
                              ? 'AI processing in progress'
                              : '${item.medicineCount} medicines extracted',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
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
              const Text('No matching prescriptions', style: TextStyle(fontWeight: FontWeight.w900)),
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

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: AppColors.danger),
          title: const Text('History could not be loaded.'),
          trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ),
      );
}
