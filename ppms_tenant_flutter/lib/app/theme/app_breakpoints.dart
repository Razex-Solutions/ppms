import 'package:flutter/widgets.dart';

enum AppBreakpoint {
  compact,
  medium,
  expanded;
}

extension AppBreakpointX on BuildContext {
  AppBreakpoint get breakpoint {
    final width = MediaQuery.sizeOf(this).width;
    if (width < 700) {
      return AppBreakpoint.compact;
    }
    if (width < 1100) {
      return AppBreakpoint.medium;
    }
    return AppBreakpoint.expanded;
  }
}
