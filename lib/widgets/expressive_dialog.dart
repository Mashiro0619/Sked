import 'sked_task_session.dart';

import 'dart:async';

import '../theme/sked_surface.dart';
import '../providers/app_scope.dart';

import 'package:material_ui/material_ui.dart';

import '../theme/app_motion.dart';
import '../theme/sked_expressive_theme.dart';
import 'ui_command.dart';
import 'sked_floating_anchor.dart';
import 'sked_floating_dialog.dart';
import 'sked_floating_surface.dart';
import 'sked_task_dialog.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_task_actions.dart';

export 'sked_floating_dialog.dart' show SkedDesktopFloatingDialog;

const double expressiveDialogMaxWidth = 520;

Future<T?> showExpressiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool waitForTransitionComplete = false,
  RouteSettings? routeSettings,
  SkedDesktopFloatingDialog? desktopFloating,
  SkedTaskSession? session,
}) async {
  if (session?.isCurrent == false) return null;
  final scope = AppScope.capture(context);
  final animationStyle = SkedMotionPolicy.of(context)
      .routeStyle(AppMotion.dialogAnimationStyle);
  final transitionAnchor = waitForTransitionComplete
      ? GlobalKey(debugLabel: 'expressive-dialog-transition-anchor')
      : null;
  final floating =
      desktopFloating != null && WorkbenchChromeMetrics.of(context).desktop;
  final returnFocus =
      (floating
          ? skedFloatingAnchorFocus(desktopFloating.anchorContext)
          : null) ??
      FocusManager.instance.primaryFocus;
  final owner = ModalRoute.of(context);
  final anchor = floating
      ? SkedFloatingAnchor.capture(desktopFloating.anchorContext)
      : null;
  final overlayRenderObject = floating
      ? Navigator.of(
          context,
          rootNavigator: useRootNavigator,
        ).overlay?.context.findRenderObject()
      : null;
  ModalRoute<dynamic>? shownRoute;
  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: floating ? Colors.transparent : null,
    useSafeArea: !floating,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    animationStyle: animationStyle,
    builder: (dialogContext) {
      // Ordinary dialogs must not subscribe to route-current changes: some
      // retain selection state in their builder while a nested editor is open.
      if (floating) shownRoute = ModalRoute.of(dialogContext);
      final body = floating
          ? SkedFloatingDialogHost(
              options: desktopFloating,
              anchor: anchor,
              coordinateSpace: overlayRenderObject is RenderBox
                  ? overlayRenderObject
                  : null,
              child: UiCommandFeedbackHost(
                builder: (_) => SkedStableTaskBody(builder: builder),
              ),
            )
          : UiCommandFeedbackHost(builder: builder);
      final dialog = SkedSurfaceScope(
        role: SkedSurfaceRole.content,
        child: session == null
            ? body
            : SkedTaskRouteGuard(parent: session, child: body),
      );
      final scoped = scope?.wrap(dialog) ?? dialog;
      return transitionAnchor == null
          ? scoped
          : KeyedSubtree(key: transitionAnchor, child: scoped);
    },
  );
  // showDialog completes when pop begins, before its route leaves the overlay.
  // A caller that immediately chains another modal can opt into waiting for
  // the actual dialog subtree to unmount instead of guessing a duration.
  while (transitionAnchor?.currentContext != null) {
    await WidgetsBinding.instance.endOfFrame;
  }
  if (floating && shownRoute != null) {
    unawaited(
      shownRoute!.completed.then((_) async {
        // The caller re-enables its trigger after its awaited dialog completes.
        // Wait for that rebuild before checking canRequestFocus.
        await WidgetsBinding.instance.endOfFrame;
        if (session?.isCurrent != false &&
            context.mounted &&
            (owner?.isCurrent ?? true) &&
            returnFocus?.context?.mounted == true &&
            returnFocus!.canRequestFocus) {
          returnFocus.requestFocus();
        }
      }),
    );
  }
  return session?.isCurrent == false ? null : result;
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

class ExpressiveActionArea extends StatelessWidget {
  const ExpressiveActionArea({super.key, this.leading, required this.actions});

  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) =>
      SkedActionArea(leading: leading, actions: actions);
}

class ExpressiveDialogOption extends StatelessWidget {
  const ExpressiveDialogOption({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.unselectedIndicator,
    this.selected = false,
    this.enabled = true,
    this.titleMaxLines = 2,
    this.subtitleMaxLines = 3,
    this.contentPadding,
    this.keepTrailingInline = false,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// An optional selection marker that stays inline, like the selected check.
  final Widget? unselectedIndicator;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final int? titleMaxLines, subtitleMaxLines;
  final EdgeInsetsGeometry? contentPadding;

  /// Independent row actions stay beside the text; their text column wraps.
  final bool keepTrailingInline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final accent = skedReadableAccent(
      colors,
      surface: colors.primary.withValues(alpha: 0.12),
    );
    final enabledOnSurface = selected ? accent : colors.onSurface;
    final textColor = enabled
        ? enabledOnSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? (selected ? accent : colors.onSurfaceVariant)
        : colors.onSurface.withValues(alpha: 0.38);
    final trailingWidget =
        trailing ??
        (selected
            ? Icon(
                Icons.check_circle,
                color: enabled
                    ? accent
                    : colors.onSurface.withValues(alpha: 0.38),
              )
            : unselectedIndicator);

    if (WorkbenchChromeMetrics.of(context).desktop) {
      return ListTile(
        dense: true,
        selected: selected,
        enabled: enabled,
        contentPadding:
            contentPadding ?? const EdgeInsets.symmetric(horizontal: 12),
        minVerticalPadding: 8,
        leading: leading == null
            ? null
            : IconTheme.merge(
                data: IconThemeData(size: 20, color: secondaryColor),
                child: leading!,
              ),
        title: DefaultTextStyle.merge(
          maxLines: titleMaxLines,
          overflow: titleMaxLines == null
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          child: title,
        ),
        subtitle: subtitle == null
            ? null
            : DefaultTextStyle.merge(
                maxLines: subtitleMaxLines,
                overflow: subtitleMaxLines == null
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                child: subtitle!,
              ),
        trailing: trailingWidget,
        onTap: enabled ? onTap : null,
      );
    }

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
              padding:
                  contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        maxLines: titleMaxLines,
                        overflow: titleMaxLines == null
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          maxLines: subtitleMaxLines,
                          overflow: subtitleMaxLines == null
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
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

                  // Only independent trailing actions may move below the text.
                  // Selection markers stay inline so selecting a short option
                  // does not add a second line or move its check to the bottom.
                  final stackTrailing =
                      !keepTrailingInline &&
                      trailing != null &&
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
                    crossAxisAlignment: keepTrailingInline
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
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
