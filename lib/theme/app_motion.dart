import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);
  static const shimmerLoop = Duration(milliseconds: 1200);

  static const curveEnter = Curves.easeOutCubic;
  static const curveEmphasis = Curves.easeOutBack;
  static const curveExit = Curves.easeInCubic;
}
