import 'sked_panel_header.dart';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'workbench_chrome_metrics.dart';

/// Opt-in: ordinary editors and touch tasks retain their existing presentation.
enum WorkspacePanePresentation { standard, view, editor }

class WorkspaceViewTaskScope extends InheritedWidget {
  const WorkspaceViewTaskScope({
    super.key,
    required this.enabled,
    required this.onClose,
    required this.onContentHeight,
    this.showClose = true,
    required super.child,
  });
  final bool enabled;
  final bool showClose;
  final VoidCallback onClose;
  final ValueChanged<double> onContentHeight;
  static WorkspaceViewTaskScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceViewTaskScope>();
  @override
  bool updateShouldNotify(WorkspaceViewTaskScope oldWidget) =>
      enabled != oldWidget.enabled ||
      showClose != oldWidget.showClose ||
      onClose != oldWidget.onClose ||
      onContentHeight != oldWidget.onContentHeight;
}

class WorkspaceViewLayoutScope extends InheritedWidget {
  const WorkspaceViewLayoutScope({
    super.key,
    required this.compact,
    this.onDragUpdate,
    required super.child,
  });
  final bool compact;
  final ValueChanged<Offset>? onDragUpdate;
  static WorkspaceViewLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceViewLayoutScope>();
  static bool compactOf(BuildContext context) =>
      maybeOf(context)?.compact ?? false;
  @override
  bool updateShouldNotify(WorkspaceViewLayoutScope oldWidget) =>
      compact != oldWidget.compact || onDragUpdate != oldWidget.onDragUpdate;
}

/// Shared by desktop viewing tasks and the month view's permanent agenda.
/// Without an enabled task scope there is deliberately no close action.
class WorkspaceViewPanel extends StatelessWidget {
  const WorkspaceViewPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.headerAction,
    this.toolbar,
    this.bodyViewportKey,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
    this.headerPadding = const EdgeInsets.fromLTRB(16, 10, 12, 10),
    this.headerVerticalAlignment = CrossAxisAlignment.start,
    this.inlineHeaderAction,
  });
  final Widget title;
  final Widget? subtitle, headerAction, toolbar;
  final Widget child;
  final Key? bodyViewportKey;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry headerPadding;
  final CrossAxisAlignment headerVerticalAlignment;
  final bool? inlineHeaderAction;

  @override
  Widget build(BuildContext context) {
    final scope = WorkspaceViewTaskScope.maybeOf(context);
    final task = scope?.enabled == true;
    final layout = WorkspaceViewLayoutScope.maybeOf(context);
    final compact = task && layout?.compact == true;
    final onDragUpdate = compact ? layout?.onDragUpdate : null;
    final theme = Theme.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    return Align(
      // Navigator-backed panels are clipped by WorkspaceViewViewport. An
      // adjacent portal instead receives loose constraints and must size
      // its surface to this same content, not fill an empty window-height card.
      heightFactor: compact ? 1 : null,
      alignment: Alignment.topCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inlineAction =
              inlineHeaderAction ??
              constraints.maxWidth >= 360 * metrics.textScale;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle.merge(
                style: theme.textTheme.titleSmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                child: title,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: subtitle!,
                ),
              ],
            ],
          );
          final content = Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Only very short/large-text windows scroll the header itself.
              // Normal panels keep the title and actions outside the body scroll.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .7,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    key: const ValueKey('workspace-view-header'),
                    padding: headerPadding,
                    child: SkedPanelHeader(
                      title:
                          headerVerticalAlignment == CrossAxisAlignment.center
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: metrics.iconTarget,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                heightFactor: 1,
                                child: heading,
                              ),
                            )
                          : heading,
                      verticalAlignment: headerVerticalAlignment,
                      action: headerAction,
                      inlineAction: inlineAction,
                      actionGap: 8,
                      closeGap: 4,
                      onDrag: onDragUpdate,
                      dragKey: const ValueKey('workspace-view-drag-handle'),
                      showClose: task && scope!.showClose,
                      onClose: scope?.onClose,
                      closeKey: const ValueKey('workspace-inspector-close'),
                      toolbar: toolbar,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                fit: compact ? FlexFit.loose : FlexFit.tight,
                child: SizedBox(
                  key: bodyViewportKey,
                  child: SingleChildScrollView(
                    key: const ValueKey('workspace-view-body'),
                    padding: contentPadding,
                    child: child,
                  ),
                ),
              ),
            ],
          );
          return _ReportPanelSize(
            onHeight: task ? scope!.onContentHeight : null,
            child: content,
          );
        },
      ),
    );
  }
}

class _ReportPanelSize extends SingleChildRenderObjectWidget {
  const _ReportPanelSize({required this.onHeight, required super.child});
  final ValueChanged<double>? onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPanelSize(onHeight);
  @override
  void updateRenderObject(BuildContext context, _RenderPanelSize renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderPanelSize extends RenderProxyBox {
  _RenderPanelSize(this.onHeight);
  ValueChanged<double>? onHeight;
  double? _reportedHeight;
  @override
  void performLayout() {
    super.performLayout();
    if (_reportedHeight == size.height) return;
    _reportedHeight = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _reportedHeight == height) onHeight?.call(height);
    });
  }
}

/// The Navigator must keep the full available constraints so a short list can
/// grow again. Only its viewport shrinks: paint, semantics and hit testing are
/// clipped by the owning surface. No route is reparented during a mode change.
class WorkspaceViewViewport extends SingleChildRenderObjectWidget {
  const WorkspaceViewViewport({
    super.key,
    required this.contentHeight,
    required super.child,
  });
  final double? contentHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderViewViewport(contentHeight);
  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderViewViewport).contentHeight = contentHeight;
  }
}

class _RenderViewViewport extends RenderProxyBox {
  _RenderViewViewport(this._contentHeight);
  double? _contentHeight;
  set contentHeight(double? value) {
    if (_contentHeight == value) return;
    _contentHeight = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(
      BoxConstraints.tight(constraints.biggest),
      parentUsesSize: true,
    );
    size = constraints.constrain(
      Size(
        child!.size.width,
        (_contentHeight ?? child!.size.height).clamp(0, child!.size.height),
      ),
    );
  }
}
