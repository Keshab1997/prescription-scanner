import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prescription_scanner/theme.dart';

/// A single staggered entrance: quick fade combined with a soft slide-up.
///
/// Use [delay] to stagger cards in lists, e.g.
/// `Entrance(delay: index * 60ms)`.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 14,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final double distance;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520) + delay,
      curve: curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        // Isolate the painted subtree in its own layer so Opacity composites
        // via a save layer instead of pushing inherited opacity down into
        // clipped/decorated children. On Vulkan/Impeller, the latter triggers
        // "SetInheritedOpacity should never be called when Contents::
        // CanAcceptOpacity returns false" and can blank the tab.
        child: RepaintBoundary(
          child: Transform.translate(
            offset: Offset(0, distance * (1 - value)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A button/card that gently lifts and scales while pressed.
class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final BorderRadius borderRadius;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  void _update(bool pressed) {
    if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => _update(true),
      onTapUp: widget.onTap == null ? null : (_) => _update(false),
      onTapCancel: widget.onTap == null ? null : () => _update(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A shimmer skeleton used while async data loads.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 18,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final slide = _controller.value * 3 - 1;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: AppColors.line),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white,
                AppColors.tealSoft.withValues(alpha: 0.5),
                Colors.white,
              ],
              stops: [
                (slide - 0.5).clamp(0.0, 1.0),
                slide.clamp(0.0, 1.0),
                (slide + 0.5).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Counts from 0 to [value] with an ease-out spring feel.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
    this.decimals = 0,
  });

  final num value;
  final TextStyle style;
  final Duration duration;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (context, v, _) =>
          Text(v.toStringAsFixed(decimals), style: style),
    );
  }
}

/// An animated aurora backdrop: softly drifting coloured orbs behind a
/// gradient. Used on auth and processing screens for a premium feel.
class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({
    super.key,
    required this.child,
    this.palette = const [
      AppColors.tealSoft,
      AppColors.indigoSoft,
      Color(0xFFFFF3E0),
    ],
  });

  final Widget child;
  final List<Color> palette;

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.palette[0], AppColors.canvas, Colors.white],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              children: [
                _Orb(
                  size: 280,
                  color: AppColors.teal.withValues(alpha: 0.16),
                  dx: -120 + 26 * math.sin(t * 2 * math.pi),
                  dy: -40 + 18 * math.cos(t * math.pi),
                ),
                _Orb(
                  size: 240,
                  color: AppColors.indigo.withValues(alpha: 0.14),
                  dx: 160 + 24 * math.cos(t * math.pi * 1.6),
                  dy: 120 + 22 * math.sin(t * math.pi * 1.1),
                ),
                _Orb(
                  size: 200,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  dx: 40 + 30 * math.sin(t * math.pi * 0.9),
                  dy: 360 + 20 * math.cos(t * 2 * math.pi),
                ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.color,
    required this.dx,
    required this.dy,
  });

  final double size;
  final Color color;
  final double dx;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: dx,
      top: dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// A breathing glow behind an icon or CTA, composed of expanding rings.
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.child,
    this.color = AppColors.teal,
    this.pulses = 2,
  });

  final Widget child;
  final Color color;
  final int pulses;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Positioned rings never participate in Stack layout. Their visual
          // growth is paint-only, so the widget always keeps the exact size of
          // [child] throughout the animation.
          for (var i = 0; i < widget.pulses; i++)
            Positioned.fill(
              child: Builder(
                builder: (context) {
                  final phase = (_controller.value - i / widget.pulses) % 1.0;
                  return Transform.scale(
                    scale: 1 + 1.7 * phase,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(
                            alpha: 0.30 * (1 - phase),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          child!,
        ],
      ),
      child: widget.child,
    );
  }
}
