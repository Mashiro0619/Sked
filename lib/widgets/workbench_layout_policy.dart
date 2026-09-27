import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/workspace_panel_display_mode.dart';
import 'app_layout_tokens.dart';

export '../models/workspace_panel_display_mode.dart';

/// The base navigation budget never depends on which task is open. A task can
/// borrow calendar space only according to the user's presentation preference.
class WorkbenchLayoutPolicy {
  const WorkbenchLayoutPolicy({
    required this.resources,
    required this.supporting,
    required this.dockedDetail,
    required this.detailWidth,
    this.resourceWidth = AppBreakpoints.resourcePane,
    this.supportingWidth = AppBreakpoints.detailPane,
    this.dockedAssistant = false,
    this.assistantWidth = AppBreakpoints.assistantPane,
    this.detailVisible = false,
    this.assistantVisible = false,
    this.minimumCanvasWidth = AppBreakpoints.minimumCanvas,
    this.canvasObscured = false,
  });
  final bool resources;
  final bool supporting;
  final bool dockedDetail;
  final double detailWidth;
  final double resourceWidth;
  final double supportingWidth;
  final bool dockedAssistant;
  final double assistantWidth;
  final bool detailVisible;
  final bool assistantVisible;
  final double minimumCanvasWidth;
  final bool canvasObscured;
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
    bool assistantActive = false,
    bool pointer = false,
    WorkspacePanelDisplayMode panelDisplayMode =
        WorkspacePanelDisplayMode.overlay,
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
    final supportingWidth = AppBreakpoints.detailPane * factor;
    final resourceWidth =
        (resourcesCollapsed
            ? (pointer
                  ? AppBreakpoints.pointerCompactResourcePane
                  : AppBreakpoints.compactResourcePane)
            : AppBreakpoints.resourcePane) *
        factor;
    final resources = width >= canvas + resourceWidth + divider;
    final resourceSpace = resources ? resourceWidth + divider : 0.0;
    final contentWidth = math.max(0.0, width - resourceSpace);
    final dockingCanvas =
        panelDisplayMode == WorkspacePanelDisplayMode.sideBySide
        ? AppBreakpoints.minimumSideBySideCanvas * factor
        : canvas;
    final allowDock = panelDisplayMode != WorkspacePanelDisplayMode.overlay;
    final bothDock =
        allowDock &&
        detailOpen &&
        assistantOpen &&
        contentWidth >=
            dockingCanvas + requestedDetail + requestedAssistant + 2 * divider;
    // Hidden tasks stay mounted but neither take space nor receive input.
    final detailVisible =
        detailOpen && (!assistantOpen || bothDock || !assistantActive);
    final assistantVisible =
        assistantOpen && (!detailOpen || bothDock || assistantActive);
    final detail =
        detailVisible &&
        allowDock &&
        (bothDock || contentWidth >= dockingCanvas + requestedDetail + divider);
    final assistant =
        assistantVisible &&
        allowDock &&
        (bothDock ||
            contentWidth >= dockingCanvas + requestedAssistant + divider);
    // The month agenda belongs to the base view, not to a task's width. An
    // overlay must not remove it and thereby resize the calendar underneath.
    final supporting =
        hasSupporting &&
        !detail &&
        !assistant &&
        contentWidth >= canvas + supportingWidth + divider;
    return WorkbenchLayoutPolicy(
      resources: resources,
      resourceWidth: resourceWidth,
      supporting: supporting,
      supportingWidth: supportingWidth,
      dockedDetail: detail,
      detailWidth: detail
          ? requestedDetail
          : math.min(requestedDetail, contentWidth),
      dockedAssistant: assistant,
      assistantWidth: assistant
          ? requestedAssistant
          : math.min(requestedAssistant, contentWidth),
      detailVisible: detailVisible,
      assistantVisible: assistantVisible,
      minimumCanvasWidth: detail || assistant ? dockingCanvas : canvas,
      canvasObscured:
          (detailVisible && !detail && requestedDetail >= contentWidth) ||
          (assistantVisible &&
              !assistant &&
              requestedAssistant >= contentWidth),
    );
  }
}
