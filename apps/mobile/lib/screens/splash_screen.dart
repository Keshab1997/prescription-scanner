import 'package:flutter/material.dart';

/// Short branded transition shown after Android's native launch screen.
///
/// The native splash makes cold starts feel immediate. This Flutter layer then
/// adds the expressive document entrance, scanner beam and sparkle without a
/// Lottie/runtime dependency.
class AnimatedLaunchSplash extends StatefulWidget {
  const AnimatedLaunchSplash({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<AnimatedLaunchSplash> createState() => _AnimatedLaunchSplashState();
}

class _AnimatedLaunchSplashState extends State<AnimatedLaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoLift;
  late final Animation<double> _beamPosition;
  late final Animation<double> _copyOpacity;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.22, curve: Curves.easeOut),
    );
    _logoScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(
              begin: 0.72,
              end: 1.06,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 68,
          ),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 32),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: const Interval(0, 0.48)),
        );
    _logoLift = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.35, curve: Curves.easeOutCubic),
      ),
    );
    _beamPosition = Tween<double>(begin: -0.72, end: 0.72).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.72, curve: Curves.easeInOutCubic),
      ),
    );
    _copyOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.58, curve: Curves.easeOut),
    );
    _exitOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 86),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 14,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinished();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _exitOpacity.value,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF4FBFA),
                    Color(0xFFE9F6F5),
                    Color(0xFFF2F3FF),
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Semantics(
                    label: 'Prescription Scanner is opening',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(0, _logoLift.value),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: _AnimatedLogo(
                                beamPosition: _beamPosition.value,
                                beamVisible:
                                    _controller.value >= 0.25 &&
                                    _controller.value <= 0.78,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Opacity(
                          opacity: _copyOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - _copyOpacity.value)),
                            child: const Column(
                              children: [
                                Text(
                                  'Prescription Scanner',
                                  style: TextStyle(
                                    color: Color(0xFF123A45),
                                    fontSize: 25,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Clear medicine details, made simple',
                                  style: TextStyle(
                                    color: Color(0xFF64808A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({required this.beamPosition, required this.beamVisible});

  final double beamPosition;
  final bool beamVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 184,
      height: 184,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(45),
        boxShadow: const [
          BoxShadow(
            color: Color(0x291A6971),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(45),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/brand/app_icon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            if (beamVisible)
              Align(
                alignment: Alignment(0, beamPosition),
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x00B9FFF4),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFC65C),
                        Color(0x00B9FFF4),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xCC8CFFF0),
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
    );
  }
}
