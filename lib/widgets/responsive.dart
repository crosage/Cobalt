import 'package:flutter/material.dart';

class Responsive {
  const Responsive._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) => width(context) < 380;

  static bool isPhone(BuildContext context) => width(context) < 600;

  static double horizontalPadding(BuildContext context) {
    final w = width(context);
    if (w < 360) return 12;
    if (w < 600) return 16;
    return 24;
  }

  static double cardPadding(BuildContext context) {
    return isCompact(context) ? 12 : 16;
  }

  static double appBarExpandedHeight(BuildContext context) {
    return isCompact(context) ? 92 : 110;
  }
}
