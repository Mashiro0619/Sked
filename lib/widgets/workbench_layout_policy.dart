import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_layout_tokens.dart';

/// Budgets describe the task, not a device model. A small viewport still has a
/// usable single canvas; these minima only decide whether another pane can dock.
class WorkbenchLayoutPolicy {
  const WorkbenchLayoutPolicy({
    required this.resources,
    required this.supporting,
    required this.dockedDetail,
    required this.detailWidth,
    this.resourceWidth = AppBreakpoints.resourcePane,
    this.dockedAssistant = false,
    this.assistantWidth = AppBreakpoints.assistantPane,
  });
  final bool resources;
  final bool supporting;
  final bool dockedDetail;
  final double detailWidth;
  final double resourceWidth;
  final bool dockedAssistant;
  final double assistantWidth;
  static const divider = AppBreakpoints.paneDivider;

  static double textFactor(double scale) => math.max(1, scale);
  static bool pointerLayout(BuildContext context) =>
      switch (Theme.of(context).platform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => true,
        _ => false,
      };
  static bool formCanSplit(
    double width,
    double scale, {
    double navigation = AppBreakpoints.settingsNavigation,
    double content = AppBreakpoints.minimumSettingsContent,
  }) => width >= (navigation + content) * textFactor(scale) + divider;

  factory WorkbenchLayoutPolicy.resolve(
    double width,
    double textScale, {
    required bool detailOpen,
    required bool hasSupporting,
    bool resourcesCollapsed = false,
    bool assistantOpen = false,
    bool pointer = false,
    double minimumCanvas = AppBreakpoints.minimumCanvas,
    double preferredDetailWidth = AppBreakpoints.detailPane,
    double preferredAssistantWidth = AppBreakpoints.assistantPane,
  }) {
    final factor = textFactor(textScale);
    final canvas = minimumCanvas * factor;
    final requestedDetail = math.max(
      320 * factor,
      preferredDetailWidth * factor,
    );
    final requestedAssistant = math.max(
      360 * factor,
      preferredAssistantWidth * factor,
    );
    final assistant =
        assistantOpen && width >= canvas + requestedAssistant + divider;
    final assistantSpace = assistant ? requestedAssistant + divider : 0.0;
    final detail =
        detailOpen &&
        width >= canvas + assistantSpace + requestedDetail + divider;
    final supporting =
        hasSupporting &&
        !detailOpen &&
        !assistantOpen &&
        width >= canvas + requestedDetail + divider;
    final sideSpace =
        assistantSpace +
        ((detail || supporting) ? requestedDetail + divider : 0);
    final remaining = width - canvas - sideSpace - divider;
    final full = AppBreakpoints.resourcePane * factor;
    final compact =
        (pointer
            ? AppBreakpoints.pointerCompactResourcePane
            : AppBreakpoints.compactResourcePane) *
        factor;
    final resourceWidth = !resourcesCollapsed && remaining >= full
        ? full
        : compact;
    final overlayTask =
        (detailOpen && !detail) || (assistantOpen && !assistant);
    final allowCompact =
        resourcesCollapsed || detail || assistant || supporting;
    final resources =
        !overlayTask &&
        remaining >= resourceWidth &&
        (resourceWidth == full || allowCompact);
    return WorkbenchLayoutPolicy(
      resources: resources,
      resourceWidth: resourceWidth,
      supporting: supporting,
      dockedDetail: detail,
      detailWidth: detail || supporting ? requestedDetail : width,
      dockedAssistant: assistant,
      assistantWidth: assistant ? requestedAssistant : width,
    );
  }
}
