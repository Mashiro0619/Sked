import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class SkedPopupMenuButton<T> extends StatelessWidget {
  const SkedPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onOpened,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.enabled = true,
    this.icon,
    this.child,
    this.padding = const EdgeInsets.all(8),
    this.offset = Offset.zero,
    this.position = PopupMenuPosition.under,
    this.constraints,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final VoidCallback? onOpened;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final bool enabled;
  final Widget? icon;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Offset offset;
  final PopupMenuPosition position;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return PopupMenuButton<T>(
      initialValue: initialValue,
      onOpened: onOpened,
      onSelected: onSelected,
      onCanceled: onCanceled,
      tooltip: tooltip,
      enabled: enabled,
      icon: icon,
      padding: padding,
      offset: offset,
      position: position,
      constraints: constraints,
      menuPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: disableAnimations
          ? AnimationStyle.noAnimation
          : AppMotion.menuAnimationStyle,
      itemBuilder: itemBuilder,
      child: child,
    );
  }
}

class SkedPopupMenuItem<T> extends PopupMenuItem<T> {
  const SkedPopupMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled = true,
    super.height = 44,
    super.padding = EdgeInsets.zero,
    super.textStyle,
    super.labelTextStyle,
    super.mouseCursor,
    required super.child,
  });

  @override
  PopupMenuItemState<T, SkedPopupMenuItem<T>> createState() =>
      _SkedPopupMenuItemState<T>();
}

class _SkedPopupMenuItemState<T>
    extends PopupMenuItemState<T, SkedPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final popupMenuTheme = PopupMenuTheme.of(context);
    final states = <WidgetState>{if (!widget.enabled) WidgetState.disabled};
    final fallbackStyle = theme.textTheme.labelLarge?.copyWith(
      color: widget.enabled
          ? colors.onSurface
          : colors.onSurface.withValues(alpha: 0.38),
      fontWeight: FontWeight.w600,
    );
    final style =
        widget.labelTextStyle?.resolve(states) ??
        popupMenuTheme.labelTextStyle?.resolve(states) ??
        widget.textStyle ??
        popupMenuTheme.textStyle ??
        fallbackStyle ??
        DefaultTextStyle.of(context).style;
    final radius = BorderRadius.circular(12);

    Widget item = AnimatedDefaultTextStyle(
      style: style,
      duration: kThemeChangeDuration,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: buildChild(),
          ),
        ),
      ),
    );

    if (!widget.enabled) {
      item = IconTheme.merge(
        data: const IconThemeData(opacity: 0.38),
        child: item,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MergeSemantics(
        child: buildSemantics(
          child: InkWell(
            onTap: widget.enabled ? handleTap : null,
            canRequestFocus: widget.enabled,
            mouseCursor: widget.enabled
                ? widget.mouseCursor ?? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            borderRadius: radius,
            overlayColor: _menuOverlayColor(colors),
            child: ListTileTheme.merge(
              contentPadding: EdgeInsets.zero,
              titleTextStyle: style,
              iconColor: widget.enabled
                  ? colors.onSurfaceVariant
                  : colors.onSurface.withValues(alpha: 0.38),
              child: item,
            ),
          ),
        ),
      ),
    );
  }
}

class SkedPopupMenuDivider<T> extends PopupMenuEntry<T> {
  const SkedPopupMenuDivider({super.key, this.height = 9});

  @override
  final double height;

  @override
  bool represents(T? value) => false;

  @override
  State<SkedPopupMenuDivider<T>> createState() =>
      _SkedPopupMenuDividerState<T>();
}

class _SkedPopupMenuDividerState<T> extends State<SkedPopupMenuDivider<T>> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: Center(
        child: Divider(
          height: 1,
          indent: 12,
          endIndent: 12,
          color: colors.outlineVariant,
        ),
      ),
    );
  }
}

WidgetStateProperty<Color?> _menuOverlayColor(ColorScheme colors) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }
    if (states.contains(WidgetState.pressed)) {
      return colors.primary.withValues(alpha: 0.14);
    }
    if (states.contains(WidgetState.focused)) {
      return colors.primary.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return colors.primary.withValues(alpha: 0.08);
    }
    return null;
  });
}
