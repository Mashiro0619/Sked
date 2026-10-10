import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'workbench_chrome_metrics.dart';

import 'desktop_window_host.dart';
import '../services/desktop_window_bridge.dart';

import '../theme/sked_expressive_theme.dart';

/// A responsive, context-bearing toolbar primitive for the adaptive shell.
///
/// It has no navigation or business knowledge; callers provide those through
/// slots so both workspaces can share the same hierarchy without sharing data.
class SkedWorkspaceToolbar extends StatelessWidget {
  const SkedWorkspaceToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.navigation,
    this.actions = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.navigationSpacing = 10,
  }) : assert(navigationSpacing >= 0);

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? navigation;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final double navigationSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final captionClearance = DesktopWindowBridge.instance.available
        ? WorkbenchChromeMetrics.of(context).captionWidth
        : 0.0;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: captionClearance),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          // Toolbars own the full width of their surface.  A loose Flexible
          // lets a title slot shrink to its intrinsic width when there are no
          // sibling actions, which leaves dynamically sized navigation rows
          // floating away from the trailing edge (most visible when the global
          // workspace navigation is hidden).  Keep the slot expanded so its
          // caller can align controls against the actual toolbar bounds.
          final titleBlock = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          );
          final actionWrap = Align(
            widthFactor: 1,
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: actions,
            ),
          );
          final header = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 8),
                        ],
                        titleBlock,
                      ],
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      actionWrap,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 8),
                    ],
                    titleBlock,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      // Measure actions at their content width instead of
                      // reserving half of the toolbar for a single button.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(
                            0,
                            (constraints.maxWidth -
                                    padding
                                        .resolve(Directionality.of(context))
                                        .horizontal) *
                                0.4,
                          ),
                        ),
                        child: actionWrap,
                      ),
                    ],
                  ],
                );

          return Semantics(
            container: true,
            child: Material(
              color:
                  WorkbenchChromeMetrics.compactTouch(
                    context,
                    width: constraints.maxWidth,
                  )
                  ? colors.surface
                  : colors.surfaceContainerLow,
              surfaceTintColor: Colors.transparent,
              shape:
                  WorkbenchChromeMetrics.compactTouch(
                    context,
                    width: constraints.maxWidth,
                  )
                  ? null
                  : Border(bottom: BorderSide(color: colors.outlineVariant)),
              child: DesktopDragRegion(
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      header,
                      if (navigation != null) ...[
                        SizedBox(height: navigationSpacing),
                        navigation!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The single primary action affordance used by a Sked workspace.
class SkedPrimaryFab extends StatelessWidget {
  const SkedPrimaryFab({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.tooltip,
    this.heroTag,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? label;
  final String? tooltip;
  final Object? heroTag;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = skedShapeSchemeOf(context).fab;
    final effectiveOnPressed = isLoading ? null : onPressed;
    final loadingIcon = SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: colors.onPrimary,
      ),
    );

    if (label != null || isLoading) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: effectiveOnPressed,
        tooltip: tooltip,
        shape: shape,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: isLoading ? loadingIcon : icon,
        label: label ?? const SizedBox.shrink(),
      );
    }
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: effectiveOnPressed,
      tooltip: tooltip,
      shape: shape,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      child: isLoading ? loadingIcon : icon,
    );
  }
}
