import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/sked_expressive_theme.dart';
import 'sked_spring_builder.dart';

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
    this.movingIndicator = false,
    this.movingIndicatorFillsSegment = false,
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

  /// Paints one shared selection shape that travels between segments.
  ///
  /// The official [SegmentedButton] remains the interaction and semantics
  /// owner. This opt-in layer is used only for the two primary workspace
  /// selectors; multi-select callers retain the stock rendering.
  final bool movingIndicator;

  /// Lets the moving indicator fill its segment. The outer control clips the
  /// first and last segments, so internal boundaries stay square.
  final bool movingIndicatorFillsSegment;

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

    final segmentedButton = SegmentedButton<T>(
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

    if (!movingIndicator ||
        multiSelectionEnabled ||
        selected.length > 1 ||
        segments.length < 2) {
      return segmentedButton;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final axisExtent = direction == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        if (!axisExtent.isFinite || axisExtent <= 0) {
          return segmentedButton;
        }
        final selectedIndex = selected.isEmpty
            ? -1
            : segments.indexWhere(
                (segment) => selected.contains(segment.value),
              );
        if (selectedIndex < 0) return segmentedButton;

        final indicatorColor = colors.primary.withValues(alpha: 0.12);
        final indicator = SkedSpringBuilder(
          key: const ValueKey('sked-segmented-selection-spring'),
          value: selectedIndex.toDouble(),
          speed: SkedMotionSpeed.standard,
          builder: (context, value, child) {
            final index = value.clamp(0.0, segments.length - 1.0);
            final alignment = direction == Axis.horizontal
                ? AlignmentDirectional(
                    segments.length == 1
                        ? 0
                        : -1 + 2 * index / (segments.length - 1),
                    0,
                  )
                : Alignment(
                    0,
                    segments.length == 1
                        ? 0
                        : -1 + 2 * index / (segments.length - 1),
                  );
            return Align(
              alignment: alignment,
              child: FractionallySizedBox(
                widthFactor: direction == Axis.horizontal
                    ? 1 / segments.length
                    : 1,
                heightFactor: direction == Axis.vertical
                    ? 1 / segments.length
                    : 1,
                child: movingIndicatorFillsSegment
                    ? ColoredBox(
                        key: const ValueKey(
                          'sked-segmented-selection-indicator',
                        ),
                        color: indicatorColor,
                        child: child,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(2),
                        child: DecoratedBox(
                          key: const ValueKey(
                            'sked-segmented-selection-indicator',
                          ),
                          decoration: ShapeDecoration(
                            color: indicatorColor,
                            shape: shapes.selectionIndicator,
                          ),
                          child: child,
                        ),
                      ),
              ),
            );
          },
          child: const SizedBox.expand(),
        );

        final movingStyle = effectiveStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.transparent;
            }
            return Colors.transparent;
          }),
        );
        final movingButton = SegmentedButton<T>(
          segments: segments,
          selected: selected,
          onSelectionChanged: onSelectionChanged,
          multiSelectionEnabled: multiSelectionEnabled,
          emptySelectionAllowed: emptySelectionAllowed,
          expandedInsets: expandedInsets,
          style: movingStyle,
          showSelectedIcon: showSelectedIcon,
          selectedIcon: selectedIcon,
          direction: direction,
        );
        final tapTargetVerticalPadding = _segmentedTapTargetVerticalPadding(
          context,
          style: effectiveStyle,
          selected: selected.isNotEmpty,
          enabled: onSelectionChanged != null,
        );
        final visualInsets = (expandedInsets ?? EdgeInsets.zero).add(
          EdgeInsets.symmetric(vertical: tapTargetVerticalPadding / 2),
        );
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: visualInsets,
                  child: ClipPath(
                    key: const ValueKey('sked-segmented-control-clip'),
                    clipper: ShapeBorderClipper(
                      shape: shapes.selectionIndicator,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ColoredBox(
                      color: colors.surfaceContainerLow,
                      child: IgnorePointer(
                        child: ExcludeSemantics(child: indicator),
                      ),
                    ),
                  ),
                ),
              ),
              movingButton,
            ],
          ),
        );
      },
    );
  }
}

double _segmentedTapTargetVerticalPadding(
  BuildContext context, {
  required ButtonStyle style,
  required bool selected,
  required bool enabled,
}) {
  final theme = Theme.of(context);
  final themeStyle = SegmentedButtonTheme.of(context).style;
  final states = <WidgetState>{
    if (selected) WidgetState.selected,
    if (!enabled) WidgetState.disabled,
  };
  final resolvedPadding =
      style.padding?.resolve(states) ??
      themeStyle?.padding?.resolve(states) ??
      EdgeInsets.zero;
  final visualDensity =
      style.visualDensity ?? themeStyle?.visualDensity ?? theme.visualDensity;
  final tapTargetSize =
      style.tapTargetSize ??
      themeStyle?.tapTargetSize ??
      theme.materialTapTargetSize;
  final fontSize =
      style.textStyle?.resolve(states)?.fontSize ??
      themeStyle?.textStyle?.resolve(states)?.fontSize ??
      theme.textTheme.labelLarge?.fontSize ??
      20;
  final densityAdjustment = visualDensity.baseSizeAdjustment;
  const textButtonMinHeight = 40.0;
  final adjustedButtonMinHeight = textButtonMinHeight + densityAdjustment.dy;
  final effectiveVerticalPadding =
      resolvedPadding.vertical + densityAdjustment.dy * 2;
  final buttonHeight = math.max(
    fontSize + effectiveVerticalPadding,
    adjustedButtonMinHeight,
  );
  return switch (tapTargetSize) {
    MaterialTapTargetSize.shrinkWrap => 0,
    MaterialTapTargetSize.padded => math.max(
      0,
      kMinInteractiveDimension + densityAdjustment.dy - buttonHeight,
    ),
  };
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
    final shape = skedShapeSchemeOf(context).toolbar;
    return LayoutBuilder(
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
                    SizedBox(height: navigationSpacing),
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
