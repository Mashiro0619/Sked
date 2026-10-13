import 'sked_panel_header.dart';

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';
import 'sked_confirmation_dialog.dart';
import 'sked_task_actions.dart';

/// Dialog builders sometimes hold transactional state outside StatefulBuilder.
/// Keep that closure alive across host/viewport rebuilds, just like a route page.
class SkedStableTaskBody extends StatefulWidget {
  const SkedStableTaskBody({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<SkedStableTaskBody> createState() => _SkedStableTaskBodyState();
}

class _SkedStableTaskBodyState extends State<SkedStableTaskBody> {
  Widget? _child;
  @override
  Widget build(BuildContext context) => _child ??= widget.builder(context);
}

class SkedTaskDialogScope extends InheritedWidget {
  const SkedTaskDialogScope({
    super.key,
    this.onDragUpdate,
    this.onClose,
    this.explicitHeight = false,
    required super.child,
  });
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onClose;
  final bool explicitHeight;
  static SkedTaskDialogScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkedTaskDialogScope>();
  @override
  bool updateShouldNotify(SkedTaskDialogScope oldWidget) =>
      onDragUpdate != oldWidget.onDragUpdate ||
      onClose != oldWidget.onClose ||
      explicitHeight != oldWidget.explicitHeight;
}

/// Short tasks share the confirmation shell on touch and panel chrome on desktop.
class SkedTaskDialog extends StatelessWidget {
  const SkedTaskDialog({
    super.key,
    this.title,
    this.titleAction,
    this.titleBottom,
    this.content,
    this.actions,
    this.scrollable = false,
    this.contentOwnsScroll = false,
    this.closeEnabled = true,
    this.constraints,
    this.insetPadding,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.titleTextStyle,
  });
  final Widget? title, content, titleAction, titleBottom;
  final List<Widget>? actions;

  /// Eager form content may share a scroll viewport with its title. Lazy lists
  /// keep their own bounded viewport and must not enter intrinsic sizing.
  final bool scrollable;

  /// Pass bounded space to a lazy list instead of nesting scroll views.
  /// The header can scroll independently when large text consumes its budget.
  final bool contentOwnsScroll;
  final bool closeEnabled;
  final BoxConstraints? constraints;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding, actionsPadding;
  final TextStyle? titleTextStyle;
  @override
  Widget build(BuildContext context) {
    final scope = SkedTaskDialogScope.maybeOf(context);
    if (scope == null) {
      final media = MediaQuery.of(context);
      final effectiveInset =
          insetPadding ??
          DialogTheme.of(context).insetPadding ??
          const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
      final availableHeight = math.max(
        0.0,
        media.size.height -
            media.viewInsets.vertical -
            media.padding.vertical -
            effectiveInset.vertical,
      );
      return SkedConfirmationDialog(
        title: title == null || !contentOwnsScroll
            ? title
            : ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight * .35),
                child: SingleChildScrollView(child: title),
              ),
        content: content,
        actions: actions?.isNotEmpty == true
            ? [SkedActionArea(actions: actions!)]
            : actions,
        scrollable: scrollable && !contentOwnsScroll,
        constraints: constraints,
        insetPadding: insetPadding,
        titlePadding: titlePadding,
        contentPadding: contentPadding,
        actionsPadding: actionsPadding,
        titleTextStyle: titleTextStyle,
      );
    }
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        mainAxisSize: scope.explicitHeight
            ? MainAxisSize.max
            : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              // A wrapped title action is essential chrome, not list content.
              // Let the header take its measured height before compressing the
              // body. Reserve the footer, body padding and a small viewport.
              maxHeight: titleBottom == null
                  ? bounds.maxHeight * .35
                  : (bounds.maxHeight -
                            (actions?.isNotEmpty == true
                                ? bounds.maxHeight * .3
                                : 0) -
                            (content != null ? 32 : 0) -
                            1)
                        .clamp(0.0, double.infinity),
            ),
            child: Padding(
              padding: skedPanelHeaderPadding,
              child: SkedPanelHeader(
                scrollableTitle: true,
                title: title ?? const SizedBox.shrink(),
                action: titleAction,
                bottom: titleBottom,
                bottomGap: 6,
                onDrag:
                    scope.onDragUpdate ??
                    SkedFloatingDragScope.maybeOf(context)?.onDrag,
                dragKey: scope.onDragUpdate != null
                    ? const ValueKey('floating-form-drag-handle')
                    : const ValueKey('sked-picker-drag-handle'),
                showClose: scope.onClose != null,
                closeEnabled: closeEnabled,
                onClose: scope.onClose,
                closeKey: const ValueKey('floating-form-close'),
              ),
            ),
          ),
          const Divider(height: 1),
          if (content != null)
            Flexible(
              fit: scope.explicitHeight ? FlexFit.tight : FlexFit.loose,
              child: contentOwnsScroll
                  ? Padding(padding: const EdgeInsets.all(12), child: content!)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: content!,
                    ),
            ),
          if (actions?.isNotEmpty == true)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * .3),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: SkedActionArea(runSpacing: 4, actions: actions!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
