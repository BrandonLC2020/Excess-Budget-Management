import 'package:flutter/material.dart';

enum ScreenType { compact, medium, expanded }

abstract class Breakpoints {
  static const double compact = 600;
  static const double expanded = 1200;

  static ScreenType getScreenType(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;
    if (width < compact) return ScreenType.compact;
    if (width < expanded) return ScreenType.medium;
    return ScreenType.expanded;
  }
}

extension BreakpointsExtension on BuildContext {
  ScreenType get screenType => Breakpoints.getScreenType(this);
  bool get isCompact => screenType == ScreenType.compact;
  bool get isMedium => screenType == ScreenType.medium;
  bool get isExpanded => screenType == ScreenType.expanded;
}
