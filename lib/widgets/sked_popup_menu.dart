import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:material_ui/material_ui.dart';

import 'sked_tooltip.dart';
import 'sked_menu_item_content.dart';

import '../theme/app_motion.dart';
import '../theme/sked_expressive_theme.dart';
import '../theme/sked_menu_style.dart';

/// Anchored action menus share the same surface and motion as button menus.
/// Callers retain ownership of positioning, result handling and route lifetime.
Future<T?> showSkedMenu<T>({
  required BuildContext context,
  required List<PopupMenuEntry<T>> items,
  RelativeRect? position,
  PopupMenuPositionBuilder? positionBuilder,
  T? initialValue,
  BoxConstraints? constraints,
  bool? requestFocus,
  bool useRootNavigator = false,
  String? semanticLabel,
  RouteSettings? routeSettings,
}) {
  final menu = SkedMenuStyle.of(context);
  return showMenu<T>(
    context: context,
    items: items,
    position: position,
    positionBuilder: positionBuilder,
    initialValue: initialValue,
    constraints: constraints ?? SkedMenuStyle.constraints,
    requestFocus: requestFocus,
    useRootNavigator: useRootNavigator,
    semanticLabel: semanticLabel,
    routeSettings: routeSettings,
    color: menu.surface,
    shape: menu.shape,
    elevation: menu.elevation,
    shadowColor: menu.shadow,
    surfaceTintColor: Colors.transparent,
    menuPadding: menu.padding,
    clipBehavior: Clip.antiAlias,
    popUpAnimationStyle: SkedMotionPolicy.of(context)
        .routeStyle(AppMotion.menuAnimationStyle),
  );
}

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
    this.focusNode,
    this.icon,
    this.child,
    this.padding = const EdgeInsets.all(8),
    this.offset = Offset.zero,
    this.position = PopupMenuPosition.under,
    this.constraints,
    this.style,
    this.iconSize,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final VoidCallback? onOpened;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final bool enabled;
  final FocusNode? focusNode;
  final Widget? icon;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final Offset offset;
  final PopupMenuPosition position;
  final BoxConstraints? constraints;
  final ButtonStyle? style;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final motion = SkedMotionPolicy.of(context);
    final menu = SkedMenuStyle.of(context);
    if (focusNode != null) {
      return _FocusedPopupMenuButton<T>(
        focusNode: focusNode!,
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
        constraints: constraints ?? SkedMenuStyle.constraints,
        style: style,
        iconSize: iconSize,
        color: menu.surface,
        shape: menu.shape,
        elevation: menu.elevation,
        shadowColor: menu.shadow,
        surfaceTintColor: Colors.transparent,
        menuPadding: menu.padding,
        clipBehavior: Clip.antiAlias,
        popUpAnimationStyle: motion.routeStyle(AppMotion.menuAnimationStyle),
        itemBuilder: itemBuilder,
        child: child,
      );
    }
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
      constraints: constraints ?? SkedMenuStyle.constraints,
      style: style,
      iconSize: iconSize,
      color: menu.surface,
      shape: menu.shape,
      elevation: menu.elevation,
      shadowColor: menu.shadow,
      surfaceTintColor: Colors.transparent,
      menuPadding: menu.padding,
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: motion.routeStyle(AppMotion.menuAnimationStyle),
      itemBuilder: itemBuilder,
      child: child,
    );
  }
}

// material_ui's PopupMenuButton has no focusNode parameter. Reuse its route
// implementation and supply the same focusable icon control for the shell.
class _FocusedPopupMenuButton<T> extends PopupMenuButton<T> {
  const _FocusedPopupMenuButton({
    required this.focusNode,
    required super.itemBuilder,
    super.initialValue,
    super.onOpened,
    super.onSelected,
    super.onCanceled,
    super.tooltip,
    super.enabled,
    super.icon,
    super.padding,
    super.offset,
    super.position,
    super.constraints,
    super.style,
    super.iconSize,
    super.color,
    super.shape,
    super.elevation,
    super.shadowColor,
    super.surfaceTintColor,
    super.menuPadding,
    super.clipBehavior,
    super.popUpAnimationStyle,
    super.child,
  });
  final FocusNode focusNode;
  @override
  PopupMenuButtonState<T> createState() => _FocusedPopupMenuButtonState<T>();
}

class _FocusedPopupMenuButtonState<T> extends PopupMenuButtonState<T> {
  @override
  Widget build(BuildContext context) {
    final button = widget as _FocusedPopupMenuButton<T>;
    if (button.child != null) {
      return SkedTooltip(
        message:
            button.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          focusNode: button.focusNode,
          onTap: button.enabled ? showButtonMenu : null,
          child: button.child,
        ),
      );
    }
    return IconButton(
      focusNode: button.focusNode,
      style: button.style,
      iconSize: button.iconSize,
      padding: button.padding,
      tooltip:
          button.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
      icon: button.icon ?? const Icon(Icons.more_horiz),
      onPressed: button.enabled ? showButtonMenu : null,
    );
  }
}

class SkedPopupMenuItem<T> extends PopupMenuItem<T> {
  const SkedPopupMenuItem({
    super.key,
    super.value,
    super.onTap,
    super.enabled = true,
    this.selected = false,
    super.height = SkedMenuStyle.minimumItemHeight,
    super.padding,
    super.textStyle,
    super.labelTextStyle,
    super.mouseCursor,
    required super.child,
  });

  final bool selected;

  @override
  PopupMenuItemState<T, SkedPopupMenuItem<T>> createState() =>
      _SkedPopupMenuItemState<T>();
}

/// Uses the same InkWell and shape as ordinary menu items, not Material's
/// rectangular CheckedPopupMenuItem highlight.
class SkedCheckedPopupMenuItem<T> extends SkedPopupMenuItem<T> {
  const SkedCheckedPopupMenuItem({
    super.key,
    required super.value,
    required this.checked,
    super.enabled,
    required this.label,
  }) : super(selected: checked, child: const SizedBox.shrink());
  final bool checked;
  final String label;
  @override
  PopupMenuItemState<T, SkedPopupMenuItem<T>> createState() =>
      _SkedCheckedMenuState<T>();
}

class _SkedCheckedMenuState<T> extends _SkedPopupMenuItemState<T> {
  @override
  Widget buildSemantics({required Widget child}) => Semantics(
    role: SemanticsRole.menuItemCheckbox,
    enabled: widget.enabled,
    checked: selected,
    button: true,
    child: child,
  );

  @override
  Widget buildChild() {
    final item = widget as SkedCheckedPopupMenuItem<T>;
    return SkedMenuItemContent(selected: item.checked, child: Text(item.label));
  }
}

class _SkedPopupMenuItemState<T>
    extends PopupMenuItemState<T, SkedPopupMenuItem<T>> {
  final _states = WidgetStatesController();
  bool get selected => widget.selected;

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = SkedMenuStyle.of(context);
    final popupMenuTheme = PopupMenuTheme.of(context);
    final states = <WidgetState>{
      if (!widget.enabled) WidgetState.disabled,
      if (selected) WidgetState.selected,
    };
    final style =
        widget.labelTextStyle?.resolve(states) ??
        popupMenuTheme.labelTextStyle?.resolve(states) ??
        widget.textStyle ??
        popupMenuTheme.textStyle ??
        menu.labelStyle(states);

    final item = AnimatedDefaultTextStyle(
      style: style,
      duration: SkedMotionPolicy.of(context).effects(SkedMotionSpeed.fast),
      child: ConstrainedBox(
        // Height remains a minimum; touch density and larger labels can grow it.
        constraints: BoxConstraints(
          minHeight: math.max(widget.height, menu.itemHeight),
        ),
        child: Padding(
          padding: widget.padding ?? menu.itemPadding,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: buildChild(),
          ),
        ),
      ),
    );

    return Padding(
      padding: menu.itemMargin,
      child: MergeSemantics(
        child: buildSemantics(
          child: InkWell(
            statesController: _states,
            onTap: widget.enabled ? handleTap : null,
            canRequestFocus: widget.enabled,
            mouseCursor:
                widget.mouseCursor ?? WidgetStateMouseCursor.adaptiveClickable,
            customBorder: menu.itemShape,
            overlayColor: menu.overlayColor,
            splashFactory: NoSplash.splashFactory,
            child: ValueListenableBuilder<Set<WidgetState>>(
              valueListenable: _states,
              builder: (context, interaction, child) => Ink(
                decoration: ShapeDecoration(
                  color: menu.background({...states, ...interaction}),
                  shape: menu.itemShape.copyWith(
                    side: menu.itemBorder({...states, ...interaction}),
                  ),
                ),
                child: child,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: menu.foreground(states),
                  size: menu.iconSize,
                ),
                child: ListTileTheme.merge(
                  contentPadding: EdgeInsets.zero,
                  titleTextStyle: style,
                  iconColor: menu.foreground(states),
                  child: item,
                ),
              ),
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
    final menu = SkedMenuStyle.of(context);
    return SizedBox(
      height: widget.height,
      child: Center(
        child: Divider(
          height: 1,
          indent: menu.itemPadding.left,
          endIndent: menu.itemPadding.right,
          color: menu.desktop ? menu.outline : colors.outlineVariant,
        ),
      ),
    );
  }
}
