import 'package:flutter/animation.dart';

/// Motion constants for the LLC "Technical Luxury" interaction system.
///
/// Values are taken verbatim from
/// `.claude/context/llc-standards/interaction-physics.md`. Every
/// spring-driven displacement (press/drag recoil) and every eased
/// transition in the app should route through these constants so the
/// whole interface shares one physical language.
abstract final class LLCMotion {
  /// High-precision friction applied to draggable elements on glass
  /// surfaces (sheets, dismissibles, sliders).
  static const double dragResistance = 0.15;

  /// Sharp, authoritative return-to-neutral stiffness.
  static const double springStiffness = 180;

  /// Minimal oscillation, dead-stop accuracy.
  static const double springDamping = 12;

  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: springStiffness,
    damping: springDamping,
  );

  /// All non-spring animations use a decelerating curve: velocity highest
  /// at the start, trailing off with sophisticated elegance.
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve easeOutQuint = Curves.easeOutQuint;

  /// Thermal Glow phase durations (interaction-physics.md).
  static const Duration thermalExcitation = Duration(milliseconds: 50);
  static const Duration thermalDissipation = Duration(milliseconds: 300);

  /// impeller-optimization.md GPU guardrail: at most 2 concurrent
  /// BackdropFilter layers per screen.
  static const int maxConcurrentGlassLayers = 2;
}
