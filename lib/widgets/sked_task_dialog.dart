import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';
import 'workbench_chrome_metrics.dart';

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
    required super.child,
  });
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onClose;
  static SkedTaskDialogScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkedTaskDialogScope>();
  @override
  bool updateShouldNotify(SkedTaskDialogScope oldWidget) =>
      onDragUpdate != oldWidget.onDragUpdate || onClose != oldWidget.onClose;
}

/// The original AlertDialog remains untouched unless a desktop host opts in.
class SkedTaskDialog extends StatelessWidget {
  const SkedTaskDialog({
    super.key,
    this.title,
    this.titleAction,
    this.titleBottom,
    this.content,
    this.actions,
    this.scrollable = false,
    this.desktopContentOwnsScroll = false,
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
  final bool scrollable;

  /// Pass bounded space to a desktop list instead of nesting scroll views.
  /// Touch AlertDialog behavior is unaffected.
  final bool desktopContentOwnsScroll;
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
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
        constraints: constraints,
        insetPadding: insetPadding,
        titlePadding: titlePadding,
        contentPadding: contentPadding,
        actionsPadding: actionsPadding,
        titleTextStyle: titleTextStyle,
      );
    }
    final metrics = WorkbenchChromeMetrics.of(context);
    final heading = DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.titleMedium!
          .copyWith(fontWeight: FontWeight.w600),
      child: title ?? const SizedBox.shrink(),
    );
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        mainAxisSize: MainAxisSize.min,
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
            child: SingleChildScrollView(
              physics:
                  titleBottom == null &&
                      (scope.onDragUpdate != null ||
                          SkedFloatingDragScope.maybeOf(context) != null)
                  ? const NeverScrollableScrollPhysics()
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: scope.onDragUpdate == null
                              ? SkedPickerTitle(child: heading)
                              : SkedFloatingTitleDragHandle(
                                  key: const ValueKey(
                                    'floating-form-drag-handle',
                                  ),
                                  onUpdate: scope.onDragUpdate!,
                                  child: heading,
                                ),
                        ),
                        ?titleAction,
                        if (scope.onClose != null)
                          IconButton(
                            key: const ValueKey('floating-form-close'),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            style: metrics.iconStyle,
                            onPressed: closeEnabled ? scope.onClose : null,
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    if (titleBottom != null) ...[
                      const SizedBox(height: 6),
                      titleBottom!,
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          if (content != null)
            Flexible(
              fit: FlexFit.loose,
              child: desktopContentOwnsScroll
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
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: actions!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
