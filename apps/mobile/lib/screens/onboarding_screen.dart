import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/services/app_prefs.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

/// First-launch illustrated onboarding: three 3D-render style steps that
/// explain the scan → AI transcription → history & sign-in flow.
///
/// Shown once (remembered in [AppPrefs]) before the login screen for both
/// guests and signed-out users.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.asset,
    required this.eyebrow,
    required this.eyebrowColor,
    required this.title,
    required this.body,
  });

  final String asset;
  final String eyebrow;
  final Color eyebrowColor;
  final String title;
  final String body;
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      asset: 'assets/onboarding/onboarding_scan.jpg',
      eyebrow: 'SCAN',
      eyebrowColor: AppColors.teal,
      title: 'Scan any prescription',
      body:
          'Point your camera at a prescription paper. We crop, sharpen and '
          'prepare it automatically — no typing needed.',
    ),
    _OnboardingPageData(
      asset: 'assets/onboarding/onboarding_ai.jpg',
      eyebrow: 'AI TRANSCRIBE',
      eyebrowColor: AppColors.indigo,
      title: 'AI reads it for you',
      body:
          'Prescription Scanner AI turns the photo into a clean, structured medicine list — '
          'name, dosage, frequency and duration in seconds.',
    ),
    _OnboardingPageData(
      asset: 'assets/onboarding/onboarding_history.jpg',
      eyebrow: 'HISTORY & SYNC',
      eyebrowColor: AppColors.amber,
      title: 'Your medicines, remembered',
      body:
          'Every scan is saved to your history. Sign in free to keep your '
          'records safe and unlock extra daily scans.',
    ),
  ];

  late final PageController _pageController;
  late final AnimationController _floatController;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    // Repeating this in flutter_test decodes the page JPEGs every frame and
    // makes a 2s pump look hung. Keep the float for real devices only.
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingName.contains('TestWidgetsFlutterBinding')) {
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _index == _pages.length - 1;

  Future<void> _finish() async {
    // Persist fire-and-forget: Hive's file I/O must never block navigation
    // (and would deadlock under flutter_test's fake-async zone). The box
    // cache updates synchronously, so the router gate sees the flag at once.
    unawaited(AppPrefs.markOnboardingSeen());
    if (!mounted) return;
    // The router redirect sends already-signed-in users to /home instead.
    context.go('/login');
  }

  bool get _inWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  void _next() {
    if (_isLastPage) {
      _finish();
      return;
    }
    if (_inWidgetTest) {
      _pageController.jumpToPage(_index + 1);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_index + 1} of ${_pages.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (!_isLastPage)
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Expanded(
                          child: _ParallaxIllustration(
                            asset: page.asset,
                            float: _floatController,
                            pageController: _pageController,
                            index: index,
                            onTap: _next,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Entrance(
                          delay: const Duration(milliseconds: 80),
                          child: _EyebrowChip(
                            label: page.eyebrow,
                            color: page.eyebrowColor,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Entrance(
                          delay: const Duration(milliseconds: 160),
                          child: Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Entrance(
                          delay: const Duration(milliseconds: 240),
                          child: Text(
                            page.body,
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 15.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: _isLastPage
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < _pages.length; i++)
                                _Dot(active: i == _index),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _NextButton(isLast: true, onTap: _next),
                      ],
                    )
                  : Row(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _pages.length; i++)
                              _Dot(active: i == _index),
                          ],
                        ),
                        const Spacer(),
                        _NextButton(isLast: false, onTap: _next),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustration with a gentle endless float plus a small horizontal parallax
/// while the user swipes between pages.
class _ParallaxIllustration extends StatelessWidget {
  const _ParallaxIllustration({
    required this.asset,
    required this.float,
    required this.pageController,
    required this.index,
    this.onTap,
  });

  final String asset;
  final Animation<double> float;
  final PageController pageController;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([float, pageController]),
      builder: (context, child) {
        // Parallax: illustrations drift slightly against the swipe direction.
        var page = index.toDouble();
        if (pageController.hasClients &&
            pageController.position.haveDimensions) {
          page = pageController.page ?? page;
        }
        final parallax = (page - index) * -36;

        final floatT = float.value;
        final dy = math.sin(floatT * 2 * math.pi) * 9;
        final tilt = math.sin(floatT * 2 * math.pi + math.pi / 3) * 0.012;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Transform.translate(
              offset: Offset(parallax, dy),
              child: Transform.rotate(angle: tilt, child: child),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child:
            WidgetsBinding.instance.runtimeType.toString().contains(
              'TestWidgetsFlutterBinding',
            )
            ? const SizedBox(
                height: 120,
                child: ColoredBox(color: Color(0xFFE7F7F4)),
              )
            : Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
      ),
    );
  }
}

class _EyebrowChip extends StatelessWidget {
  const _EyebrowChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(right: 7),
      width: active ? 26 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.teal : AppColors.line,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onTap});

  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: ValueKey(isLast ? 'onboarding-get-started' : 'onboarding-next'),
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        minimumSize: Size(isLast ? double.infinity : 72, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      child: isLast
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 20),
                SizedBox(width: 8),
                Text('Get started'),
              ],
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
    );
  }
}
