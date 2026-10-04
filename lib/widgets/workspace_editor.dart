import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';
import 'sked_panel_header.dart';
import 'workbench_chrome_metrics.dart';

/// Captured before a menu or details route closes; never looks up a dead context.
class WorkspaceEditorConfiguration {
  WorkspaceEditorConfiguration({
    BuildContext? anchorContext,
    Rect? anchorRect,
    this.placement = SkedFloatingPlacement.automatic,
  }) : anchorBox = _box(anchorContext),
       initialAnchor = anchorRect ?? _rect(_box(anchorContext));
  final RenderBox? anchorBox;
  final Rect? initialAnchor;
  final SkedFloatingPlacement placement;
  static RenderBox? _box(BuildContext? context) {
    if (context?.mounted != true) return null;
    final render = context!.findRenderObject();
    return render is RenderBox && render.attached && render.hasSize
        ? render
        : null;
  }

  static Rect? _rect(RenderBox? box) =>
      box != null && box.attached && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  Rect? get liveAnchor => _rect(anchorBox);
}

/// Host-owned geometry and chrome. The editor owns validation and user exits.
class WorkspaceEditorScope extends InheritedWidget {
  const WorkspaceEditorScope({
    super.key,
    required this.enabled,
    required this.floating,
    required this.onHeight,
    this.onDrag,
    required super.child,
  });
  final bool enabled, floating;
  final ValueChanged<double> onHeight;
  final ValueChanged<Offset>? onDrag;
  static WorkspaceEditorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceEditorScope>();
  @override
  bool updateShouldNotify(WorkspaceEditorScope old) =>
      enabled != old.enabled ||
      floating != old.floating ||
      onDrag != old.onDrag ||
      onHeight != old.onHeight;
}

class WorkspaceEditorScaffold extends StatelessWidget {
  const WorkspaceEditorScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    required this.closeEnabled,
    required this.actions,
    this.leading,
  });
  final Widget title, child;
  final Widget? leading;
  final VoidCallback onClose;
  final bool closeEnabled;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final scope = WorkspaceEditorScope.maybeOf(context)!;
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: scope.floating ? 1 : null,
      child: LayoutBuilder(
        builder: (context, bounds) => _EditorSize(
          onHeight: scope.onHeight,
          child: Column(
            mainAxisSize: scope.floating ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: bounds.maxHeight * .3),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: SkedPanelHeader(
                        verticalAlignment: CrossAxisAlignment.center,
                        title: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: WorkbenchChromeMetrics.of(context)
                                .iconTarget,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            heightFactor: 1,
                            child: DefaultTextStyle.merge(
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                              child: title,
                            ),
                          ),
                        ),
                        onDrag: scope.floating ? scope.onDrag : null,
                        dragKey: const ValueKey('workspace-editor-drag'),
                        onClose: onClose,
                        closeEnabled: closeEnabled,
                        closeKey: const ValueKey('workspace-editor-close'),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                fit: scope.floating ? FlexFit.loose : FlexFit.tight,
                child: SingleChildScrollView(
                  key: const PageStorageKey('workspace-editor-body'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: child,
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: bounds.maxHeight * .35),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final trailing = Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: actions,
                        );
                        return constraints.maxWidth >=
                                420 * MediaQuery.textScalerOf(context).scale(1)
                            ? Row(
                                children: [
                                  ?leading,
                                  Expanded(
                                    child: Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      heightFactor: 1,
                                      child: trailing,
                                    ),
                                  ),
                                ],
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                alignment: WrapAlignment.end,
                                children: [?leading, ...actions],
                              );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorSize extends SingleChildRenderObjectWidget {
  const _EditorSize({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EditorSizeRender(onHeight);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _EditorSizeRender renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _EditorSizeRender extends RenderProxyBox {
  _EditorSizeRender(this.onHeight);
  ValueChanged<double> onHeight;
  double? last;
  @override
  void performLayout() {
    super.performLayout();
    if (last == size.height) return;
    last = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && last == height) onHeight(height);
    });
  }
}

/// Stable wrap layout: resizing changes widths without moving fields to a new tree.
class WorkspaceEditorFieldsRow extends StatelessWidget {
  const WorkspaceEditorFieldsRow({
    super.key,
    required this.children,
    this.minimumWidth = 180,
  });
  final List<Widget> children;
  final double minimumWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final columns =
          bounds.maxWidth >=
              minimumWidth *
                      MediaQuery.textScalerOf(context).scale(1) *
                      children.length +
                  12 * (children.length - 1)
          ? children.length
          : 1;
      final width = (bounds.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(key: ValueKey(i), width: width, child: children[i]),
        ],
      );
    },
  );
}
