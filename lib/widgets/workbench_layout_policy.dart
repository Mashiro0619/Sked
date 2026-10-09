import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/workspace_panel_display_mode.dart';
import 'app_layout_tokens.dart';

export '../models/workspace_panel_display_mode.dart';

enum WorkspaceResourcePresentation { hidden, compact, expanded }

/// The base navigation budget never depends on which task is open. A task can
/// borrow calendar space only according to the user's presentation preference.
class WorkbenchLayoutPolicy {
  const WorkbenchLayoutPolicy({
    required this.resources,
    required this.resourcePresentation,
    required this.canExpandResources,
    required this.resourcesAutomaticallyCollapsed,
    required this.supporting,
    required this.dockedDetail,
    required this.detailWidth,
    required this.maximumDetailWidth,
    required this.maximumAssistantWidth,
    this.resourceWidth = AppBreakpoints.resourcePane,
    this.supportingWidth = AppBreakpoints.detailPane,
    this.dockedAssistant = false,
    this.assistantWidth = AppBreakpoints.assistantPane,
    this.detailVisible = false,
    this.assistantVisible = false,
    this.minimumCanvasWidth = AppBreakpoints.minimumCanvas,
    this.canvasEndInset = 0,
    this.canvasObscured = false,
  });
  final bool resources;
  final WorkspaceResourcePresentation resourcePresentation;
  final bool canExpandResources;
  final bool resourcesAutomaticallyCollapsed;
  final bool supporting;
  final bool dockedDetail;
  final double detailWidth;
  final double maximumDetailWidth;
  final double maximumAssistantWidth;
  final double resourceWidth;
  final double supportingWidth;
  final bool dockedAssistant;
  final double assistantWidth;
  final bool detailVisible;
  final bool assistantVisible;
  final double minimumCanvasWidth;

  /// Reserved only below the command bar. A resized pane may cover the canvas
  /// beyond this inset, without releasing its entire slot at the docking limit.
  final double canvasEndInset;
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
    double captionWidth = 0,
    bool shortWindow = false,
    WorkspacePanelDisplayMode panelDisplayMode =
        WorkspacePanelDisplayMode.overlay,
    double minimumCanvas = AppBreakpoints.minimumCanvas,
    bool partialDetailOverlay = false,
    double preferredDetailWidth = AppBreakpoints.detailPane,
    double minimumDetailWidth = AppBreakpoints.minimumDetailPane,
    double preferredAssistantWidth = AppBreakpoints.assistantPane,
  }) {
    final factor = textFactor(textScale);
    final canvas = minimumCanvas * factor;
    final supportingWidth = AppBreakpoints.detailPane * factor;
    final expandedResourceWidth = AppBreakpoints.resourcePane * factor;
    final compactResourceWidth =
        (pointer
            ? AppBreakpoints.pointerCompactResourcePane
            : AppBreakpoints.compactResourcePane) *
        factor;
    final navigationCanvas = pointer
        ? math.max(
            AppBreakpoints.desktopNavigationCanvas * factor,
            AppBreakpoints.desktopCommandContent * factor +
                AppBreakpoints.desktopCommandPadding +
                captionWidth,
          )
        : canvas;
    final canExpandResources =
        !shortWindow &&
        width >= navigationCanvas + expandedResourceWidth + divider;
    final preferCompact = resourcesCollapsed || shortWindow;
    final resourcePresentation = pointer
        ? (!preferCompact && canExpandResources
              ? WorkspaceResourcePresentation.expanded
              : width >=
                    AppBreakpoints.desktopCompactNavigationCanvas * factor +
                        compactResourceWidth +
                        divider
              ? WorkspaceResourcePresentation.compact
              : WorkspaceResourcePresentation.hidden)
        : (width >=
                  canvas +
                      (preferCompact
                          ? compactResourceWidth
                          : expandedResourceWidth) +
                      divider
              ? (preferCompact
                    ? WorkspaceResourcePresentation.compact
                    : WorkspaceResourcePresentation.expanded)
              : WorkspaceResourcePresentation.hidden);
    final resources =
        resourcePresentation != WorkspaceResourcePresentation.hidden;
    final resourceWidth =
        resourcePresentation == WorkspaceResourcePresentation.expanded
        ? expandedResourceWidth
        : compactResourceWidth;
    final resourceSpace = resources ? resourceWidth + divider : 0.0;
    final contentWidth = math.max(0.0, width - resourceSpace);
    // Use the entire sidebar-free work area, including any supporting agenda
    // or other task. Keep default readable widths on small/large-text windows
    // rather than making an unresized pane narrower just to enforce the ratio.
    final fractionalMaximum =
        contentWidth * AppBreakpoints.maximumTaskPaneFraction;
    final maximumDetailWidth = math.min(
      contentWidth,
      math.max(AppBreakpoints.detailPane * factor, fractionalMaximum),
    );
    final maximumAssistantWidth = math.min(
      contentWidth,
      math.max(AppBreakpoints.assistantPane * factor, fractionalMaximum),
    );
    final requestedDetail = math.min(
      maximumDetailWidth,
      math.max(minimumDetailWidth * factor, preferredDetailWidth * factor),
    );
    final requestedAssistant = math.min(
      maximumAssistantWidth,
      math.max(
        AppBreakpoints.minimumAssistantPane * factor,
        preferredAssistantWidth * factor,
      ),
    );
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
    // Hidden tasks stay mounted without receiving input or their own dock.
    // Their open-task reservation is accounted for separately below.
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
    // Docking and canvas reservation are different budgets. Once the calendar
    // reaches its floor, further resizing covers it instead of springing it
    // back to the full work-area width. Pure overlay mode never reserves space.
    // A peer hidden at the two-pane docking limit is still open. Keep its
    // budget until it closes so both resize directions remain continuous.
    final openTaskSpace =
        (detailOpen ? requestedDetail + divider : 0.0) +
        (assistantOpen ? requestedAssistant + divider : 0.0);
    final taskSpace = allowDock
        ? math.min(openTaskSpace, math.max(0.0, contentWidth - dockingCanvas))
        : 0.0;
    // The month agenda belongs to the base view, not to a task's width. An
    // overlay keeps it; a task slot reuses its space instead of reserving both.
    final supporting =
        hasSupporting &&
        taskSpace == 0 &&
        contentWidth >= canvas + supportingWidth + divider;
    return WorkbenchLayoutPolicy(
      resources: resources,
      resourcePresentation: resourcePresentation,
      canExpandResources: canExpandResources,
      resourcesAutomaticallyCollapsed:
          pointer &&
          !resourcesCollapsed &&
          resourcePresentation != WorkspaceResourcePresentation.expanded,
      resourceWidth: resourceWidth,
      supporting: supporting,
      supportingWidth: supportingWidth,
      dockedDetail: detail,
      detailWidth: requestedDetail,
      maximumDetailWidth: maximumDetailWidth,
      maximumAssistantWidth: maximumAssistantWidth,
      dockedAssistant: assistant,
      assistantWidth: requestedAssistant,
      detailVisible: detailVisible,
      assistantVisible: assistantVisible,
      minimumCanvasWidth: taskSpace > 0 ? dockingCanvas : canvas,
      canvasEndInset: taskSpace + (supporting ? supportingWidth + divider : 0),
      canvasObscured:
          (detailVisible &&
              !detail &&
              !partialDetailOverlay &&
              requestedDetail >= contentWidth) ||
          (assistantVisible &&
              !assistant &&
              requestedAssistant >= contentWidth),
    );
  }
}
