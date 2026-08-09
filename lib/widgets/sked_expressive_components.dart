import 'package:flutter/material.dart';

import '../theme/sked_expressive_theme.dart';

/// An official [SegmentedButton] styled with Sked's expressive shape, motion,
/// and Material 48 dp touch sizing.
///
/// Flutter owns each segment's semantics and interaction behavior. Its
/// implementation intentionally replaces per-segment shapes, so moving shape
/// indicators belong to the concrete workspace selector rather than this
/// general wrapper.
class SkedExpressiveSegmentedButton<T> extends StatelessWidget {
  const SkedExpressiveSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelectionEnabled = false,
    this.emptySelectionAllowed = false,
    this.expandedInsets,
    this.style,
    this.showSelectedIcon = false,
    this.selectedIcon,
    this.direction = Axis.horizontal,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>>? onSelectionChanged;
  final bool multiSelectionEnabled;
  final bool emptySelectionAllowed;
  final EdgeInsets? expandedInsets;
  final ButtonStyle? style;
  final bool showSelectedIcon;
  final Widget? selectedIcon;
  final Axis direction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes = skedShapeSchemeOf(context);
    final motion = SkedMotionPolicy.of(context);
    final effectiveStyle =
        ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              shape: WidgetStatePropertyAll(shapes.selectionIndicator),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                final selected = states.contains(WidgetState.selected);
                return BorderSide(
                  color: selected ? colors.primary : colors.outlineVariant,
                );
              }),
              animationDuration: motion.effects(SkedMotionSpeed.fast),
            )
            .merge(style)
            .copyWith(
              // A caller may customize colors and typography, but the global motion
              // policy must remain authoritative when animations are disabled.
              animationDuration: motion.effects(SkedMotionSpeed.fast),
            );

    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      multiSelectionEnabled: multiSelectionEnabled,
      emptySelectionAllowed: emptySelectionAllowed,
      expandedInsets: expandedInsets,
      style: effectiveStyle,
      showSelectedIcon: showSelectedIcon,
      selectedIcon: selectedIcon,
      direction: direction,
    );
  }
}

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
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? navigation;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = skedShapeSchemeOf(context).toolbar;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final titleBlock = Flexible(
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
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  titleBlock,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Flexible(child: actionWrap),
                  ],
                ],
              );

        return Semantics(
          container: true,
          child: Material(
            color: colors.surfaceContainerLow,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  if (navigation != null) ...[
                    const SizedBox(height: 10),
                    navigation!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
    final shape = skedShapeSchemeOf(context).fab;
    final effectiveOnPressed = isLoading ? null : onPressed;
    final loadingIcon = SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );

    if (label != null || isLoading) {
      return FloatingActionButton.extended(
        heroTag: heroTag,
        onPressed: effectiveOnPressed,
        tooltip: tooltip,
        shape: shape,
        icon: isLoading ? loadingIcon : icon,
        label: label ?? const SizedBox.shrink(),
      );
    }
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: effectiveOnPressed,
      tooltip: tooltip,
      shape: shape,
      child: isLoading ? loadingIcon : icon,
    );
  }
}
