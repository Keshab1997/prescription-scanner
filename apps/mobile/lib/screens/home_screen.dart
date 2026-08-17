import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/screens/result_screen.dart';
import 'package:prescription_scanner/services/app_prefs.dart';
import 'package:prescription_scanner/models/extracted_prescription.dart';
import 'package:prescription_scanner/services/ads_service.dart';
import 'package:prescription_scanner/services/auth_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/media_permission_gate.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final signedIn = user != null && user.emailVerified;
    final displayName = signedIn ? user.displayName?.trim() : null;
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            const MediaPermissionGate(),
            const _FirstLanguageGate(),
            Entrance(
              child: _HomeHeader(
                firstName: firstName,
                initials: signedIn ? _initials(displayName) : 'G',
                signedIn: signedIn,
              ),
            ),
            const SizedBox(height: 24),
            Entrance(
              delay: const Duration(milliseconds: 100),
              child: _ScanHero(onTap: () => context.push('/upload')),
            ),
            const SizedBox(height: 26),
            Entrance(
              delay: const Duration(milliseconds: 160),
              child: const _SectionTitle("Today's scans"),
            ),
            const SizedBox(height: 10),
            quota.when(
              loading: () => const ShimmerBox(height: 96, radius: 22),
              error: (_, _) => Entrance(
                child: _InlineError(
                  message: 'Could not load scan limits.',
                  onRetry: () => ref.invalidate(quotaProvider),
                ),
              ),
              data: (value) => Entrance(
                delay: const Duration(milliseconds: 200),
                child: _QuotaCard(quota: value),
              ),
            ),
            if (!signedIn)
              Entrance(
                delay: const Duration(milliseconds: 220),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _GuestLoginBanner(onLogin: () => context.go('/login')),
                ),
              ),
            const SizedBox(height: 24),
            Entrance(
              delay: const Duration(milliseconds: 240),
              child: _SectionTitle(
                'Recent prescriptions',
                action: TextButton(
                  onPressed: () => context.go('/history'),
                  child: const Text('View all'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            recent.when(
              loading: () => Column(
                children: const [
                  ShimmerBox(height: 78, radius: 20),
                  SizedBox(height: 10),
                  ShimmerBox(height: 78, radius: 20),
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
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Entrance(
                                delay: Duration(
                                  milliseconds: 300 + entry.key * 70,
                                ),
                                child: _RecentPrescription(
                                  item: entry.value,
                                  onTap: () =>
                                      _openPrescription(context, entry.value),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 6),
            const Entrance(
              delay: Duration(milliseconds: 500),
              child: AdaptiveAdBanner(),
            ),
            const SizedBox(height: 8),
            Text(
              LegalCopy.medicalShort,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPrescription(BuildContext context, ExtractedPrescription item) {
    context.push('/result?prescriptionId=${Uri.encodeComponent(item.id)}');
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

class _FirstLanguageGate extends ConsumerStatefulWidget {
  const _FirstLanguageGate();

  @override
  ConsumerState<_FirstLanguageGate> createState() => _FirstLanguageGateState();
}

class _FirstLanguageGateState extends ConsumerState<_FirstLanguageGate> {
  static bool _askedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeAsk());
    });
  }

  Future<void> _maybeAsk() async {
    if (!mounted || _askedThisSession) return;
    if (!AppPrefs.isReady || AppPrefs.hasChosenLanguage) return;
    _askedThisSession = true;
    final chosen = await showDialog<ResultLanguage>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose summary language'),
        content: const Text(
          'Medicine summaries can be shown in English, বাংলা or हिन्दी. You can change this later on a result.',
        ),
        actions: [
          for (final language in ResultLanguage.values)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, language),
              child: Text(language.label),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    ref.read(resultLanguageProvider.notifier).set(chosen);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.firstName,
    required this.initials,
    required this.signedIn,
  });

  final String? firstName;
  final String initials;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName == null ? greeting : '$greeting, $firstName',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ready to scan?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        ScaleTap(
          onTap: () => context.go(signedIn ? '/profile' : '/login'),
          pressedScale: 0.92,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanHero extends StatefulWidget {
  const _ScanHero({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ScanHero> createState() => _ScanHeroState();
}

class _ScanHeroState extends State<_ScanHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan;

  @override
  void initState() {
    super.initState();
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: widget.onTap,
      pressedScale: 0.98,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.tealBright, AppColors.teal, AppColors.indigo],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x334F46E5),
              blurRadius: 34,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'KeshabStudios AI transcription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Turn a prescription\ninto a clear list.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Only visible details are transcribed. Anything unclear is marked for review.',
                        style: TextStyle(color: Colors.white70, height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: widget.onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.teal,
                          minimumSize: const Size(0, 50),
                        ),
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('Scan prescription'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _HeroPaper(scan: _scan),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPaper extends StatelessWidget {
  const _HeroPaper({required this.scan});
  final Animation<double> scan;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scan,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 104,
            height: 128,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PaperLine(60, color: Color(0xFF8ED0C6)),
                      SizedBox(height: 10),
                      _PaperLine(44, color: AppColors.line),
                      SizedBox(height: 10),
                      _PaperLine(52, color: AppColors.line),
                      SizedBox(height: 10),
                      _PaperLine(38, color: AppColors.line),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -4 + scan.value * (100 - 4),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.9),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaperLine extends StatelessWidget {
  const _PaperLine(this.width, {this.color = AppColors.line});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});
  final ScanQuota quota;

  @override
  Widget build(BuildContext context) {
    final total = quota.dailyLimit + quota.rewardedBonus;
    final progress = total == 0 ? 0.0 : quota.remaining / total;
    final unavailable = !quota.aiEnabled || quota.maintenanceMode;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: unavailable
              ? [AppColors.muted, AppColors.muted.withValues(alpha: 0.85)]
              : [AppColors.ink, AppColors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (unavailable ? AppColors.muted : AppColors.indigo)
                .withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: progress.clamp(0.0, 1.0).toDouble(),
                  ),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => SizedBox(
                    width: 62,
                    height: 62,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 5,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                if (unavailable)
                  const Icon(Icons.cloud_off_rounded, color: Colors.white)
                else
                  AnimatedCount(
                    value: quota.remaining,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch ((unavailable, quota.isGuest, quota.remaining > 0)) {
                    (true, _, _) => 'AI temporarily unavailable',
                    (false, true, true) => 'Free scan available',
                    (false, true, false) => 'Free scan used',
                    _ => '${quota.remaining} scans remaining',
                  },
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  switch ((unavailable, quota.isGuest, quota.remaining > 0)) {
                    (true, _, _) => 'Please try again later',
                    (false, true, true) => 'Sign in for 2 more free scans',
                    (false, true, false) => 'Sign in to unlock 2 more today',
                    _ => '${quota.used} used today · resets daily',
                  },
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPrescription extends StatelessWidget {
  const _RecentPrescription({required this.item, required this.onTap});
  final ExtractedPrescription item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item.needsManualReview
        ? 'Review'
        : item.isPrescription
        ? 'Clear'
        : 'Not a prescription';
    final statusColor = item.needsManualReview
        ? const Color(0xFFA56100)
        : item.isPrescription
        ? AppColors.success
        : AppColors.muted;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 54,
                decoration: const BoxDecoration(
                  gradient: AppColors.softGradient,
                  borderRadius: BorderRadius.all(Radius.circular(13)),
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
                      '${item.medicines.length} medicines extracted',
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

  static const double _cardHeight = 330;
  static const double _illustrationSize = 112;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _cardHeight,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        child: Column(
          children: [
            // The ripple is clipped to a fixed paint area. Neither the circle
            // scale nor its opacity can change this Column or Card's height.
            SizedBox.square(
              dimension: _illustrationSize,
              child: ClipRect(
                child: Center(
                  child: PulseRing(
                    color: AppColors.tealBright,
                    pulses: 1,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.tealSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: AppColors.teal,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No prescriptions yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your structured results will appear here.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/upload'),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Scan the first prescription'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GuestLoginBanner extends StatelessWidget {
  const _GuestLoginBanner({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.tealSoft, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_add_alt_1_rounded, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Unlock more free scans',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(height: 2),
                Text(
                  LegalCopy.guestLimitBody,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}
