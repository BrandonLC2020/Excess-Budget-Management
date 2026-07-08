import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/llc_theme.dart';
import 'package:frontend/core/theme/mesh_backdrop.dart';
import 'package:frontend/core/theme/refractive_glass.dart';
import 'package:frontend/core/theme/thermal_glow.dart';

void main() {
  Widget harness(Widget child, {Brightness brightness = Brightness.dark}) {
    return MaterialApp(
      theme: brightness == Brightness.dark
          ? LLCTheme.dark()
          : LLCTheme.light(),
      builder: (context, builtChild) =>
          MeshBackdrop(child: builtChild ?? const SizedBox.shrink()),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('RefractiveGlass renders over MeshBackdrop without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const RefractiveGlass(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Glass panel'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Glass panel'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RefractiveGlass renders in light mode too', (tester) async {
    await tester.pumpWidget(
      harness(
        const RefractiveGlass(child: SizedBox(width: 100, height: 100)),
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ThermalGlow drives press-spring and glow through a full tap cycle',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        harness(
          ThermalGlow(
            onTap: () => tapped = true,
            child: Container(
              width: 120,
              height: 48,
              color: Colors.transparent,
              child: const Center(child: Text('Accept')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Accept')),
      );
      // Excitation phase (50ms) then partway through dissipation (300ms).
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ThermalGlow with disableAnimations skips spring/glow', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: harness(
          ThermalGlow(
            onTap: () => tapped = true,
            child: const SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ThermalGlow));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
