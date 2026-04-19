import 'package:flutter/material.dart';
import '../breakpoints.dart';

/// A layout widget that displays a master widget (e.g., a list) and an optional
/// detail widget side-by-side on Medium and Expanded screens.
///
/// On Compact screens, only the [master] widget is displayed.
class MasterDetailLayout extends StatelessWidget {
  /// The widget to display on the left (master) pane.
  final Widget master;

  /// The widget to display on the right (detail) pane.
  final Widget? detail;

  const MasterDetailLayout({super.key, required this.master, this.detail});

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return master;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 400, child: master),
        const VerticalDivider(width: 1),
        Expanded(
          child:
              detail ??
              const Center(child: Text('Select an item to view details')),
        ),
      ],
    );
  }
}
