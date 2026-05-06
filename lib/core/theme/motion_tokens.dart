import 'package:flutter/animation.dart';

class MotionTokens {
  MotionTokens._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve smoothOut = Curves.easeOutCubic;
  static const Curve smoothInOut = Curves.easeInOutCubic;

  static SpringDescription springSnappy() {
    return const SpringDescription(mass: 0.9, stiffness: 310, damping: 22);
  }
}
