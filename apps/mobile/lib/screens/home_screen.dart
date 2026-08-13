import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider)?.currentUser;
    final displayName = user?.userMetadata?['display_name']?.toString().trim();
    final nameParts =
        displayName
            ?.split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList() ??
        const <String>[];
    final firstName = nameParts.isEmpty ? null : nameParts.first;
    final quota = ref.watch(quotaProvider);
    final recent = ref.watch(recentPrescriptionsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(quotaProvider);
            ref.invalidate(recentPrescriptionsProvider);
            await Future.wait([
              ref.read(quotaProvider.future),
              ref.read(recentPrescriptionsProvider.future),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName == null
                              ? 'Good to see you'
                              : 'Good to see you, $firstName',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          'Ready to scan?',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.teal, AppColors.indigo],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _initials(displayName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _ScanHero(onTap: () => context.push('/upload')),
              const SizedBox(height: 24),
              const _SectionTitle("Today's scans"),
              const SizedBox(height: 10),
              quota.when(
                loading: () => const _LoadingCard(height: 78),
                error: (_, _) => _InlineError(
                  message: 'Could not load scan limits.',
                  onRetry: () => ref.invalidate(quotaProvider),
                ),
                data: (value) => _QuotaCard(quota: value),
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                'Recent prescriptions',
                action: TextButton(
                  onPressed: () => context.go('/history'),
                  child: const Text('View all'),
                ),
              ),
              const SizedBox(height: 8),
              recent.when(
                loading: () => const Column(
                  children: [
                    _LoadingCard(height: 78),
                    SizedBox(height: 10),
                    _LoadingCard(height: 78),
                  ],
                ),
                error: (_, _) => _InlineError(
                  message: 'Could not load recent prescriptions.',
                  onRetry: () => ref.invalidate(recentPrescriptionsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyRecent()
                    : Column(
                        children: items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RecentPrescription(
                                  item: item,
                                  onTap: () => _openPrescription(context, item),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.line),
                ),
                child: const Text(
                  'ADAPTIVE BANNER · CONSENT REQUIRED',
                  style: TextStyle(
                    color: Color(0xFF9AA7B3),
                    fontSize: 9,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPrescription(BuildContext context, PrescriptionSummary item) {
    if (item.isProcessing || item.isFailed) {
      context.push(
        '/processing?prescriptionId=${Uri.encodeComponent(item.id)}',
      );
    } else {
      context.push('/result?prescriptionId=${Uri.encodeComponent(item.id)}');
    }
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return 'PS';
    return name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.teal, AppColors.indigo],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x334F46E5),
          blurRadius: 30,
          offset: Offset(0, 16),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text(
                'Gemini-powered transcription',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Turn a prescription\ninto a clear list.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Only visible details are transcribed. Anything unclear is marked for review.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.teal,
          ),
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Scan prescription'),
        ),
      ],
    ),
  );
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});
  final ScanQuota quota;

  @override
  Widget build(BuildContext context) {
    final total = quota.dailyLimit + quota.rewardedBonus;
    final progress = total == 0 ? 0.0 : quota.remaining / total;
    final unavailable = !quota.aiEnabled || quota.maintenanceMode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    strokeWidth: 5,
                    color: unavailable ? AppColors.muted : AppColors.teal,
                    backgroundColor: AppColors.tealSoft,
                  ),
                  Text(
                    unavailable ? '—' : '${quota.remaining}',
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unavailable
                        ? 'AI temporarily unavailable'
                        : '${quota.remaining} scans remaining',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    unavailable
                        ? 'Please try again later'
                        : '${quota.used} used today · resets daily',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!unavailable)
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Rewarded ads arrive in the monetization phase.',
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('+1'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentPrescription extends StatelessWidget {
  const _RecentPrescription({required this.item, required this.onTap});
  final PrescriptionSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item.isFailed
        ? 'Failed'
        : item.isProcessing
        ? 'Processing'
        : item.needsReview
        ? 'Review'
        : 'Clear';
    final statusColor = item.isFailed
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
                width: 48,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.tealSoft, AppColors.indigoSoft],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMM · h:mm a').format(item.createdAt),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      item.isFailed
                          ? 'Tap to retry processing'
                          : '${item.medicineCount} medicines extracted',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      ?action,
    ],
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: AppColors.danger),
      title: Text(message),
      trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
    ),
  );
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppColors.muted,
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text(
            'No prescriptions yet',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text('Your structured results will appear here.'),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.push('/upload'),
            child: const Text('Scan the first prescription'),
          ),
        ],
      ),
    ),
  );
}
