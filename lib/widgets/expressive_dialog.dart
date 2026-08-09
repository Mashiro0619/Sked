import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/sked_expressive_theme.dart';
import 'ui_command.dart';

const double expressiveDialogMaxWidth = 520;

Future<T?> showExpressiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool waitForTransitionComplete = false,
  RouteSettings? routeSettings,
}) async {
  final animationStyle = SkedMotionPolicy.of(
    context,
  ).routeStyle(AppMotion.dialogAnimationStyle);
  final transitionAnchor = waitForTransitionComplete
      ? GlobalKey(debugLabel: 'expressive-dialog-transition-anchor')
      : null;
  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    animationStyle: animationStyle,
    builder: (_) {
      final dialog = UiCommandFeedbackHost(builder: builder);
      return transitionAnchor == null
          ? dialog
          : KeyedSubtree(key: transitionAnchor, child: dialog);
    },
  );
  // showDialog completes when pop begins, before its route leaves the overlay.
  // A caller that immediately chains another modal can opt into waiting for
  // the actual dialog subtree to unmount instead of guessing a duration.
  while (transitionAnchor?.currentContext != null) {
    await WidgetsBinding.instance.endOfFrame;
  }
  return result;
}

class ExpressiveDialogContent extends StatelessWidget {
  const ExpressiveDialogContent({
    super.key,
    required this.child,
    this.maxWidth = expressiveDialogMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableWidth =
        mediaQuery.size.width - mediaQuery.viewPadding.horizontal - 32;
    final width = availableWidth.clamp(0.0, maxWidth).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: width, child: child),
    );
  }
}

class ExpressiveDialogActions extends StatelessWidget {
  const ExpressiveDialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: children,
    );
  }
}

class ExpressiveActionArea extends StatelessWidget {
  const ExpressiveActionArea({super.key, this.leading, required this.actions});

  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionWrap = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: actions,
        );
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

class ExpressiveDialogOption extends StatelessWidget {
  const ExpressiveDialogOption({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final enabledOnSurface = selected ? colors.primary : colors.onSurface;
    final textColor = enabled
        ? enabledOnSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? (selected ? colors.primary : colors.onSurfaceVariant)
        : colors.onSurface.withValues(alpha: 0.38);
    final trailingWidget =
        trailing ??
        (selected
            ? Icon(
                Icons.check_circle,
                color: enabled
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.38),
              )
            : null);

    return Semantics(
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: skedShapeSchemeOf(context).fieldRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: skedShapeSchemeOf(context).fieldRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: contentPadding,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final leadingWidget = leading == null
                      ? null
                      : SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: IconTheme.merge(
                              data: IconThemeData(color: secondaryColor),
                              child: leading!,
                            ),
                          ),
                        );
                  final textContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle.merge(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryColor,
                          ),
                          child: subtitle!,
                        ),
                      ],
                    ],
                  );
                  final trailingContent = trailingWidget == null
                      ? null
                      : IconTheme.merge(
                          data: IconThemeData(color: secondaryColor),
                          child: trailingWidget,
                        );

                  // Keep an edit/action control alongside text whenever a compact
                  // row can still provide a useful text column. Rows with a
                  // leading icon need more room; without one, only very narrow
                  // dialogs fall back to a second line for the trailing control.
                  final stackTrailing =
                      trailingContent != null &&
                      constraints.maxWidth <
                          (leadingWidget == null ? 160 : 300);
                  if (stackTrailing) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (leadingWidget != null) ...[
                              leadingWidget,
                              const SizedBox(width: 12),
                            ],
                            Expanded(child: textContent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: trailingContent,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      if (leadingWidget != null) ...[
                        leadingWidget,
                        const SizedBox(width: 12),
                      ],
                      Expanded(child: textContent),
                      if (trailingContent != null) ...[
                        const SizedBox(width: 10),
                        trailingContent,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
