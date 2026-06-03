import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const short = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 280);
  static const long = Duration(milliseconds: 450);

  static const standard = Curves.easeInOutCubicEmphasized;
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;

  static const themeAnimationStyle = AnimationStyle(
    duration: medium,
    reverseDuration: short,
    curve: emphasized,
    reverseCurve: exit,
  );

  static const sheetAnimationStyle = AnimationStyle(
    duration: long,
    reverseDuration: Duration(milliseconds: 220),
    curve: emphasized,
    reverseCurve: exit,
  );

  static const dialogAnimationStyle = AnimationStyle(
    duration: medium,
    reverseDuration: short,
    curve: emphasized,
    reverseCurve: exit,
  );

  static const menuAnimationStyle = AnimationStyle(
    duration: Duration(milliseconds: 240),
    reverseDuration: Duration(milliseconds: 140),
    curve: enter,
    reverseCurve: exit,
  );
}
