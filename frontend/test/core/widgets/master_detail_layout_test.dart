import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/master_detail_layout.dart';

void main() {
  Widget createWidget(double width, {Widget? detail}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: MasterDetailLayout(
              master: const Text('Master View'),
              detail: detail,
            ),
          ),
        ),
      ),
    );
  }

  group('MasterDetailLayout', () {
    testWidgets('displays only master view on compact screen', (tester) async {
      // Set surface size to simulate compact screen
      tester.view.physicalSize = const Size(500 * 3.0, 600 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(createWidget(500));

      expect(find.text('Master View'), findsOneWidget);
      expect(find.text('Select an item to view details'), findsNothing);

      // Reset view
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('displays both master and detail on medium screen', (
      tester,
    ) async {
      // Set surface size to simulate medium screen width 800 (600 <= 800 < 1200)
      tester.view.physicalSize = const Size(800 * 3.0, 600 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(createWidget(800));

      expect(find.text('Master View'), findsOneWidget);
      expect(find.text('Select an item to view details'), findsOneWidget);

      // Reset view
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('displays custom detail widget on medium screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800 * 3.0, 600 * 3.0);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        createWidget(800, detail: const Text('Custom Detail')),
      );

      expect(find.text('Master View'), findsOneWidget);
      expect(find.text('Custom Detail'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
