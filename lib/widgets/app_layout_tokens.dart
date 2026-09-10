import 'package:material_ui/material_ui.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 24.0;
  static const sheet = 28.0;
}

abstract final class AppBreakpoints {
  static const compact = 600.0;
  static const expanded = 840.0;
  static const large = 1200.0;
  static const desktop = expanded;
  static const resourcePane = 224.0;
  static const compactResourcePane = 80.0;
  static const detailPane = 360.0;
  static const assistantPane = 400.0;
  static const pointerCompactResourcePane = 56.0;
  static const minimumWeekCanvas = 800.0;
  static const settingsNavigation = 224.0;
  static const minimumSettingsContent = 520.0;
  static const paneDivider = 1.0;
  static const minimumCanvas = 600.0;
  static const paneGap = 16.0;
}

abstract final class AppInsets {
  static const page = EdgeInsets.all(AppSpacing.xl);
  static const listTile = EdgeInsets.symmetric(horizontal: AppSpacing.lg);
  static const bottomSheet = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.xl,
    AppSpacing.xl,
    AppSpacing.xl,
  );
}
