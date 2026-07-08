import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'llc_theme.dart';
import 'motion.dart';

/// The standard "Liquid Glass" surface for LLC Flutter projects
/// (`.claude/context/llc-flutter/refractive-glass.md`).
///
/// Every glass panel costs a `BackdropFilter`, which is one of the more
/// expensive things you can ask Impeller to composite. Two guardrails from
/// `impeller-optimization.md` are enforced here rather than left to
/// discipline at each call site:
///
/// 1. The blur + its content sit inside a [RepaintBoundary] so repainting
///    the rest of the screen (e.g. a list scrolling behind a fixed glass
///    header) doesn't force the blur to re-rasterize.
/// 2. In debug builds, each instance registers itself against the nearest
///    [ModalRoute] and warns if more than
///    [LLCMotion.maxConcurrentGlassLayers] glass surfaces are simultaneously
///    live on the same screen.
class RefractiveGlass extends StatefulWidget {
  const RefractiveGlass({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurSigma = 20.0,
    this.fillOpacity = 0.1,
  }) : assert(
         fillOpacity >= 0.05 && fillOpacity <= 0.15,
         'branding.md: Glass Surface opacity must stay between 0.05 and 0.15.',
       );

  final Widget child;
  final double borderRadius;
  final double blurSigma;

  /// Interpolates between the dark- and light-mode glass fill/border
  /// tokens; 0.1 (the branding.md midpoint) is the default.
  final double fillOpacity;

  @override
  State<RefractiveGlass> createState() => _RefractiveGlassState();
}

class _RefractiveGlassState extends State<RefractiveGlass> {
  static final Map<ModalRoute<dynamic>, int> _liveLayersByRoute =
      <ModalRoute<dynamic>, int>{};

  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _release();
    _route = route;
    if (route != null) {
      final count = (_liveLayersByRoute[route] ?? 0) + 1;
      _liveLayersByRoute[route] = count;
      if (kDebugMode && count > LLCMotion.maxConcurrentGlassLayers) {
        developer.log(
          'RefractiveGlass: $count concurrent BackdropFilter layers on '
          '${route.settings.name ?? route.runtimeType} '
          '(guardrail: ${LLCMotion.maxConcurrentGlassLayers}). '
          'See impeller-optimization.md.',
          name: 'llc.glass',
          level: 900,
        );
      }
    }
  }

  void _release() {
    final route = _route;
    if (route == null) return;
    final count = (_liveLayersByRoute[route] ?? 1) - 1;
    if (count <= 0) {
      _liveLayersByRoute.remove(route);
    } else {
      _liveLayersByRoute[route] = count;
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = (isDark ? Colors.white : Colors.black).withValues(
      alpha: widget.fillOpacity,
    );
    final border = isDark ? LLCColors.glassBorderDark : LLCColors.glassBorderLight;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: border, width: 0.75),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
