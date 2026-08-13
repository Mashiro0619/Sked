import 'package:material_ui/material_ui.dart';

abstract final class AppMotion {
  // Flutter's official Material motion tokens are the non-spring fallback for
  // components that have not migrated to an Expressive spring API.
  static const short = Durations.short3;
  static const medium = Durations.medium2;
  static const long = Durations.long1;

  static const standard = Easing.standard;
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const enter = Easing.emphasizedDecelerate;
  static const exit = Easing.emphasizedAccelerate;

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
