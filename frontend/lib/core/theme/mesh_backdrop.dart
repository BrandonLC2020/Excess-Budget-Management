import 'package:flutter/material.dart';

import 'llc_theme.dart';

/// The ambient surface every screen sits on. `RefractiveGlass` blurs
/// whatever is behind it; a flat scaffold color blurs into the same flat
/// color, which defeats the "Refractive Depth" premise entirely
/// (branding.md: "Depth is not just a shadow; it is the distortion of
/// space behind a physical lens"). impeller-optimization.md points at
/// exactly this: "CustomPainter with mesh-gradients for low-cost
/// refraction effects, avoiding heavy fragment shaders" — so this paints a
/// few soft, static radial gradients once, cheaply, instead of a flat
/// fill. Wired in behind the whole app in `main.dart` via
/// `MaterialApp.router(builder: ...)`; every `Scaffold` uses a transparent
/// background so this shows through and glass panels have texture to
/// refract.
class MeshBackdrop extends StatelessWidget {
  const MeshBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: isDark ? LLCColors.voidBlack : LLCColors.mist),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _MeshPainter(isDark: isDark)),
          ),
        ),
        child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  const _MeshPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = isDark
        ? const [
            (Alignment(-0.9, -1.0), LLCColors.instrumentCyanDeep, 0.22),
            (Alignment(1.0, -0.6), LLCColors.thermalCore, 0.10),
            (Alignment(0.6, 1.0), LLCColors.affirmMintDeep, 0.12),
          ]
        : const [
            (Alignment(-0.9, -1.0), LLCColors.instrumentCyan, 0.16),
            (Alignment(1.0, -0.6), LLCColors.thermalCorona, 0.08),
            (Alignment(0.6, 1.0), LLCColors.affirmMint, 0.10),
          ];

    for (final (alignment, color, alpha) in spots) {
      final center = alignment.alongSize(size);
      final radius = size.longestSide * 0.75;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
