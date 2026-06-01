import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

const double appSheetWidthCompact = 560;
const double appSheetWidthMedium = 680;
const double appSheetWidthExpanded = 920;

Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = appSheetWidthMedium,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: true,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    constraints: BoxConstraints(maxWidth: maxWidth),
    sheetAnimationStyle: AppMotion.sheetAnimationStyle,
    builder: builder,
  );
}

class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.leading,
    this.subtitle,
    this.heightFactor,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.actionPadding,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget child;
  final Widget? leading;
  final List<Widget> actions;
  final double? heightFactor;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry? actionPadding;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final body = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: subtitle!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
          Padding(
            padding:
                actionPadding ??
                EdgeInsets.fromLTRB(16, 8, 16, viewInsets.bottom + 16),
            child: _AppSheetActions(leading: leading, actions: actions),
          ),
        ],
      ),
    );

    if (heightFactor == null) {
      return body;
    }
    return FractionallySizedBox(heightFactor: heightFactor, child: body);
  }
}

class _AppSheetActions extends StatelessWidget {
  const _AppSheetActions({required this.actions, this.leading});

  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final actionWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (leading != null && constraints.maxWidth >= 420) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading!,
              const Spacer(),
              Flexible(child: actionWrap),
            ],
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [?leading, ...actions],
        );
      },
    );
  }
}
