import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Input density is a platform affordance, not a window-size breakpoint.
/// Android keeps touch-sized controls even when a mouse is connected.
class WorkbenchChromeMetrics {
  const WorkbenchChromeMetrics({
    required this.desktop,
    required this.textScale,
  });
  final bool desktop;
  final double textScale;
  static bool isDesktop(TargetPlatform platform) => switch (platform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };
  factory WorkbenchChromeMetrics.of(BuildContext context) =>
      WorkbenchChromeMetrics(
        desktop: isDesktop(Theme.of(context).platform),
        textScale: math.max(1, MediaQuery.textScalerOf(context).scale(14) / 14),
      );
  double get iconTarget => math.max(desktop ? 32 : 48, 20 * textScale + 8);
  double get commandHeight => math.max(desktop ? 36 : 48, 20 * textScale + 8);
  double get toolbarHeight => math.max(desktop ? 48 : 64, iconTarget + 16);
  double get resourceRowHeight =>
      math.max(desktop ? 36 : 48, 20 * textScale + 12);
  double get captionButtonWidth => 46;
  double get captionWidth => captionButtonWidth * 3;
  ButtonStyle get iconStyle => IconButton.styleFrom(
    minimumSize: Size.square(iconTarget),
    maximumSize: Size.square(iconTarget),
    padding: const EdgeInsets.all(6),
    iconSize: desktop ? 18 : 22,
    tapTargetSize: desktop
        ? MaterialTapTargetSize.shrinkWrap
        : MaterialTapTargetSize.padded,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );
}
