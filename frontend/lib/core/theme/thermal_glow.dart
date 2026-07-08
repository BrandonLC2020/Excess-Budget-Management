import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'llc_theme.dart';
import 'motion.dart';

/// The LLC "Thermal Glow" interaction (`interaction-physics.md`): a
/// two-phase energy transfer — a 50ms excitation strike from the contact
/// point, then a 300ms cool/fade dissipation — layered on top of a
/// spring-driven press displacement ("Mass & Inertia", `branding.md`).
///
/// Wrap any tappable surface (a card, a button's content) in [ThermalGlow]
/// instead of relying on Material's default `InkWell` splash; the splash
/// is a flat wash of one color; this is a directional, physically-motivated
/// glow anchored to the actual touch point.
class ThermalGlow extends StatefulWidget {
  const ThermalGlow({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  State<ThermalGlow> createState() => _ThermalGlowState();
}

class _ThermalGlowState extends State<ThermalGlow>
    with TickerProviderStateMixin {
  late final AnimationController _glow;
  late final Animation<double> _glowIntensity;
  AnimationController? _spring;
  Offset _origin = Offset.zero;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: LLCMotion.thermalExcitation + LLCMotion.thermalDissipation,
    );
    _glowIntensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: LLCMotion.thermalExcitation.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: LLCMotion.easeOutQuart)),
        weight: LLCMotion.thermalDissipation.inMilliseconds.toDouble(),
      ),
    ]).animate(_glow);
  }

  @override
  void dispose() {
    _glow.dispose();
    _spring?.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    final previous = _spring;
    final controller = AnimationController.unbounded(vsync: this)
      ..value = _scale;
    _spring = controller;
    controller.addListener(() {
      if (!mounted) return;
      setState(() => _scale = controller.value);
    });
    controller.animateWith(
      SpringSimulation(LLCMotion.spring, _scale, target, 0),
    );
    previous?.dispose();
  }

  void _onDown(TapDownDetails details) {
    _origin = details.localPosition;
    _glow.forward(from: 0);
    _springTo(0.97);
  }

  void _onUp([TapUpDetails? _]) => _springTo(1.0);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion = mediaQuery?.disableAnimations ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: reduceMotion ? null : _onDown,
      onTapUp: reduceMotion ? null : _onUp,
      onTapCancel: reduceMotion ? null : _onUp,
      child: Transform.scale(
        scale: reduceMotion ? 1.0 : _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              widget.child,
              if (!reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _glowIntensity,
                      builder: (context, _) {
                        if (_glowIntensity.value <= 0) {
                          return const SizedBox.shrink();
                        }
                        return CustomPaint(
                          painter: _ThermalGlowPainter(
                            origin: _origin,
                            intensity: _glowIntensity.value,
                          ),
                        );
                      },
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

/// Paints the Core -> Corona radial gradient anchored at the touch point,
/// using `BlendMode.plus` as the closest Skia/Impeller equivalent of the
/// CSS `plus-lighter` blend specified in branding.md.
class _ThermalGlowPainter extends CustomPainter {
  const _ThermalGlowPainter({required this.origin, required this.intensity});

  final Offset origin;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.longestSide * 0.6 * intensity;
    if (radius <= 0) return;
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          LLCColors.thermalCore.withValues(alpha: 0.55 * intensity),
          LLCColors.thermalCorona.withValues(alpha: 0.25 * intensity),
          LLCColors.thermalCorona.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: origin, radius: radius));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ThermalGlowPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.origin != origin;
}
