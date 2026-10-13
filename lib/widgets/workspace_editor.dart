import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_floating_anchor.dart';
import 'sked_floating_surface.dart';
import 'sked_panel_header.dart';
import 'workspace_editor_form.dart';
import 'sked_task_actions.dart';
import 'sked_task_body.dart';

/// Captured before a menu or details route closes; never looks up a dead context.
class WorkspaceEditorConfiguration {
  WorkspaceEditorConfiguration({
    BuildContext? anchorContext,
    Rect? anchorRect,
    this.placement = SkedFloatingPlacement.automatic,
    this.preferredWidth = 440,
  }) : _anchor = anchorRect == null
           ? SkedFloatingAnchor.capture(anchorContext)
           : SkedFloatingAnchor.fromRect(anchorRect);

  WorkspaceEditorConfiguration._withAnchor(
    this._anchor, {
    required this.placement,
    required this.preferredWidth,
  });

  final SkedFloatingAnchor _anchor;
  final SkedFloatingPlacement placement;
  final double preferredWidth;
  Rect? get initialAnchor => _anchor.initialRect;
  Rect? get liveAnchor => _anchor.globalRect;
  Rect? anchorIn(RenderBox coordinateSpace) => _anchor.rectIn(coordinateSpace);

  /// Adjust opening geometry without recapturing or freezing the live trigger.
  WorkspaceEditorConfiguration withPreferredWidth(double width) =>
      width == preferredWidth
      ? this
      : WorkspaceEditorConfiguration._withAnchor(
          _anchor,
          placement: placement,
          preferredWidth: width,
        );

  /// A details-to-editor transition reuses the same moving Navigator. Freeze
  /// its outgoing control rather than following a position changed by this task.
  WorkspaceEditorConfiguration snapshotIfInside(RenderObject? host) =>
      host != null && _anchor.isInSubtreeOf(host)
      ? WorkspaceEditorConfiguration(
          anchorRect: initialAnchor ?? liveAnchor,
          placement: placement,
          preferredWidth: preferredWidth,
        )
      : this;
}

/// Host-owned geometry and chrome. The editor owns validation and user exits.
class WorkspaceEditorScope extends InheritedWidget {
  const WorkspaceEditorScope({
    super.key,
    required this.enabled,
    required this.floating,
    required this.onHeight,
    this.onDrag,
    this.explicitHeight = false,
    required super.child,
  });
  final bool enabled, floating;
  final bool explicitHeight;
  final ValueChanged<double> onHeight;
  final ValueChanged<Offset>? onDrag;
  static WorkspaceEditorScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceEditorScope>();
  @override
  bool updateShouldNotify(WorkspaceEditorScope old) =>
      enabled != old.enabled ||
      floating != old.floating ||
      explicitHeight != old.explicitHeight ||
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
    this.subtitle,
    this.footer,
    this.status,
  });
  final Widget title, child;
  final Widget? leading, subtitle, footer, status;
  final VoidCallback onClose;
  final bool closeEnabled;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final scope = WorkspaceEditorScope.maybeOf(context);
    final naturalHeight =
        scope == null || (scope.floating && !scope.explicitHeight);
    final body = SkedTaskBody(
      status: status,
      fillHeight: !naturalHeight,
      divider: true,
      bodyKey: const PageStorageKey('workspace-editor-body'),
      headerPadding: skedPanelHeaderPadding,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      footerPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      header: SkedPanelHeader(
        title: title,
        subtitle: subtitle,
        onDrag: scope?.floating == true ? scope?.onDrag : null,
        dragKey: const ValueKey('workspace-editor-drag'),
        onClose: onClose,
        closeEnabled: closeEnabled,
        closeKey: const ValueKey('workspace-editor-close'),
      ),
      footer:
          footer ??
          SkedActionArea(leading: leading, actions: actions, runSpacing: 4),
      child: child,
    );
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: naturalHeight ? 1 : null,
      child: scope == null
          ? body
          : _EditorSize(onHeight: scope.onHeight, child: body),
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

/// Natural single-line widths for a desktop field's label and selected value.
/// Omit [value] for free-text fields so typing cannot rearrange the form.
double workspaceEditorMinimumFieldWidth(
  BuildContext context, {
  required String label,
  String? value,
  double valuePadding = 44,
  double minimumWidth = WorkspaceEditorFormMetrics.minimumColumnWidth,
}) {
  final textScaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final locale = Localizations.maybeLocaleOf(context);
  double measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  final labelWidth = math.max(
    minimumWidth * textScaler.scale(14) / 14,
    measure(label, workspaceEditorLabelStyle(context)),
  );
  return value == null
      ? labelWidth
      : math.max(
          labelWidth,
          measure(value, workspaceEditorContentStyle(context)) + valuePadding,
        );
}

/// Stable wrap layout: resizing changes widths without moving fields to a new tree.
class WorkspaceEditorFieldsRow extends StatelessWidget {
  const WorkspaceEditorFieldsRow({
    super.key,
    required this.children,
    this.minimumWidth = 0,
    this.minimumChildWidths = const [],
    this.flexes = const [],
  });
  final List<Widget> children;
  final double minimumWidth;

  /// Natural widths already measured with the current text scale. Empty uses
  /// the compact field baseline; otherwise provide one width for each child.
  final List<double> minimumChildWidths;

  /// Only flexible inputs share spare width; short selectors keep their width.
  /// Empty keeps every child compact. Otherwise provide one flex per child.
  final List<int> flexes;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      assert(
        minimumChildWidths.isEmpty ||
            minimumChildWidths.length == children.length,
      );
      assert(flexes.isEmpty || flexes.length == children.length);
      assert(flexes.every((flex) => flex >= 0));
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final naturalWidths = List<double>.generate(
        children.length,
        (index) => math.max(
          minimumWidth * textScale,
          minimumChildWidths.isEmpty
              ? WorkspaceEditorFormMetrics.minimumColumnWidth * textScale
              : minimumChildWidths[index],
        ),
      );
      final naturalWidth =
          naturalWidths.fold(0.0, (sum, width) => sum + width) +
          WorkspaceEditorFormMetrics.fieldGap *
              math.max(0, children.length - 1);
      final available = bounds.hasBoundedWidth ? bounds.maxWidth : naturalWidth;
      final fits = naturalWidth <= available;
      final totalFlex = flexes.fold(0, (sum, flex) => sum + flex);
      final spareWidth = math.max(0.0, available - naturalWidth);
      double childWidth(int index) {
        final flex = flexes.isEmpty ? 0 : flexes[index];
        if (!fits) {
          return flex > 0
              ? available
              : math.min(available, naturalWidths[index]);
        }
        return naturalWidths[index] +
            (totalFlex == 0 ? 0 : spareWidth * flex / totalFlex);
      }

      return Wrap(
        spacing: WorkspaceEditorFormMetrics.fieldGap,
        runSpacing: WorkspaceEditorFormMetrics.fieldGap,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(
              key: ValueKey(i),
              width: fits ? childWidth(i) : available,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                heightFactor: 1,
                child: SizedBox(width: childWidth(i), child: children[i]),
              ),
            ),
        ],
      );
    },
  );
}
