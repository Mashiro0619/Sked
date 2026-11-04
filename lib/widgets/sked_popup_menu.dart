import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView, SemanticsRole;

import 'package:material_ui/material_ui.dart';

import 'sked_tooltip.dart';
import 'sked_menu_item_content.dart';
import 'desktop_window_drag_guard.dart';

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
}) => _showSkedMenu<T>(
  context: context,
  items: items,
  position: position,
  positionBuilder: positionBuilder,
  initialValue: initialValue,
  constraints: constraints,
  requestFocus: requestFocus,
  useRootNavigator: useRootNavigator,
  semanticLabel: semanticLabel,
  routeSettings: routeSettings,
  session: _SkedMenuSession(),
);

class _SkedMenuSession {
  bool valid = true;
  VoidCallback? onInvalidated;
  ModalRoute<dynamic>? _route;

  // The route can finish before its Future delivers the result. Keep an
  // unbuilt route open, but do not mistake a popped/removed route for a live
  // menu while its source is temporarily reparented or opens another menu.
  bool get isOpen => _route?.isActive ?? true;

  void invalidate() {
    if (!valid) return;
    valid = false;
    onInvalidated?.call();
  }
}

Future<T?> _showSkedMenu<T>({
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
  required _SkedMenuSession session,
}) {
  assert((position == null) != (positionBuilder == null));
  final menu = SkedMenuStyle.of(context);
  final effectiveConstraints = SkedMenuStyle.constraintsFor(
    context,
    requested: constraints,
  );
  return showMenu<T>(
    context: context,
    items: [
      if (items.isNotEmpty)
        _SkedMenuMetricsGuard<T>(item: items.first, session: session),
      ...items.skip(1),
    ],
    positionBuilder: (layoutContext, layoutConstraints) {
      final anchor =
          positionBuilder?.call(layoutContext, layoutConstraints) ?? position!;
      final overlay = Offset.zero & layoutConstraints.biggest;
      // The source may have been deactivated while remaining mounted during
      // reflow. Only the menu's own live context can resolve its current overlay.
      final available = SkedMenuStyle.availableRectOf(layoutContext);
      final media = MediaQuery.of(Overlay.of(layoutContext).context);
      if (media.viewInsets == EdgeInsets.zero) return anchor;
      final bounds = anchor.toRect(overlay);
      final left = bounds.left.clamp(
        available.left,
        math.max(
          available.left,
          available.right - effectiveConstraints.maxWidth,
        ),
      );
      final top = bounds.top.clamp(
        available.top,
        math.max(
          available.top,
          available.bottom - effectiveConstraints.maxHeight,
        ),
      );
      return RelativeRect.fromRect(
        bounds.shift(Offset(left - bounds.left, top - bounds.top)),
        overlay,
      );
    },
    initialValue: initialValue,
    constraints: effectiveConstraints,
    requestFocus: requestFocus ?? true,
    useRootNavigator: useRootNavigator,
    semanticLabel: semanticLabel,
    routeSettings: menu.desktop
        ? DesktopMenuRouteSettings(context, original: routeSettings)
        : routeSettings,
    color: menu.surface,
    shape: menu.shape,
    elevation: menu.elevation,
    shadowColor: menu.shadow,
    surfaceTintColor: Colors.transparent,
    menuPadding: menu.padding,
    clipBehavior: Clip.antiAlias,
    popUpAnimationStyle: SkedMotionPolicy.of(context)
        .routeStyle(AppMotion.menuAnimationStyle),
  ).then((value) => session.valid ? value : null);
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
    return _SkedPopupMenuButton<T>(
      focusNode: focusNode,
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
      // Keep the caller's bounds. showSkedMenu applies the current overlay's
      // safe area and keyboard geometry when the menu actually opens.
      constraints: constraints,
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

// Keep Material's popup route and selection behavior, while all triggers share
// explicit focus support and the viewport-aware showSkedMenu entry point.
class _SkedPopupMenuButton<T> extends PopupMenuButton<T> {
  const _SkedPopupMenuButton({
    this.focusNode,
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
    super.routeSettings,
    super.child,
  });
  final FocusNode? focusNode;
  @override
  PopupMenuButtonState<T> createState() => _SkedPopupMenuButtonState<T>();
}

class _SkedPopupMenuButtonState<T> extends PopupMenuButtonState<T> {
  bool _expanded = false;
  int _menuGeneration = 0;
  _SkedMenuSession? _menuSession;

  void _invalidateMenu() {
    if (_menuSession?.isOpen == false) return;
    _menuSession?.invalidate();
    _menuSession = null;
    _expanded = false;
    _menuGeneration++;
  }

  @override
  void deactivate() {
    _invalidateMenu();
    super.deactivate();
  }

  @override
  void showButtonMenu() {
    if (!widget.enabled || (_expanded && _menuSession?.isOpen != false)) return;
    final items = widget.itemBuilder(context);
    if (items.isEmpty) return;
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(
              context,
              rootNavigator: widget.useRootNavigator,
            ).overlay?.context.findRenderObject()
            as RenderBox?;
    if (button == null || overlay == null) return;
    final generation = ++_menuGeneration;
    final session = _menuSession = _SkedMenuSession();
    RelativeRect? lastPosition;
    widget.onOpened?.call();
    setState(() => _expanded = true);
    unawaited(
      _showSkedMenu<T>(
        context: context,
        items: items,
        session: session,
        initialValue: widget.initialValue,
        constraints: widget.constraints,
        requestFocus: widget.requestFocus,
        useRootNavigator: widget.useRootNavigator,
        routeSettings: widget.routeSettings,
        positionBuilder: (_, _) {
          if (!session.valid || !button.attached || !overlay.attached) {
            return lastPosition ?? RelativeRect.fill;
          }
          var offset = widget.offset;
          if (widget.position == PopupMenuPosition.under) {
            offset += Offset(0, button.size.height);
            if (widget.child == null) {
              offset -= Offset(0, widget.padding.vertical / 2);
            }
          }
          final origin = button.localToGlobal(offset, ancestor: overlay);
          return lastPosition = RelativeRect.fromRect(
            origin & button.size,
            Offset.zero & overlay.size,
          );
        },
      ).then((value) {
        if (!mounted || generation != _menuGeneration) return;
        _menuSession = null;
        setState(() => _expanded = false);
        if (value == null) {
          widget.onCanceled?.call();
        } else {
          widget.onSelected?.call(value);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = widget as _SkedPopupMenuButton<T>;
    final Widget trigger;
    if (button.child != null) {
      final child = SkedTooltip(
        message:
            button.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          focusNode: button.focusNode,
          onTap: button.enabled ? showButtonMenu : null,
          customBorder: skedShapeSchemeOf(context).selection,
          // Keep the role and state below SkedTooltip's semantic boundary so
          // they merge with InkWell's tap action instead of making a second,
          // unactionable button above the tooltip.
          child: Semantics(
            button: true,
            enabled: button.enabled,
            expanded: _expanded,
            child: button.child,
          ),
        ),
      );
      trigger = button.style?.tapTargetSize == MaterialTapTargetSize.padded
          ? ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: child,
            )
          : child;
    } else {
      trigger = IconButton(
        focusNode: button.focusNode,
        style: button.style,
        iconSize: button.iconSize,
        padding: button.padding,
        tooltip:
            button.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip,
        // IconButton already owns a semantic boundary and its tap action.
        // Put the popup state inside it instead of creating a second button.
        icon: Semantics(
          expanded: _expanded,
          child: button.icon ?? const Icon(Icons.more_horiz),
        ),
        onPressed: button.enabled ? showButtonMenu : null,
      );
    }
    return Semantics(child: trigger);
  }
}

/// Shrinking keyboard occlusion leaves the captured bounds safe and can result
/// from this menu taking focus. Other viewport changes invalidate this session.
/// Never pop a later route above the menu or accept a queued stale selection.
class _SkedMenuMetricsGuard<T> extends PopupMenuEntry<T> {
  const _SkedMenuMetricsGuard({required this.item, required this.session});

  final PopupMenuEntry<T> item;
  final _SkedMenuSession session;
  @override
  double get height => item.height;
  @override
  bool represents(T? value) => item.represents(value);
  @override
  State<_SkedMenuMetricsGuard<T>> createState() =>
      _SkedMenuMetricsGuardState<T>();
}

class _SkedMenuMetricsGuardState<T> extends State<_SkedMenuMetricsGuard<T>>
    with WidgetsBindingObserver {
  FlutterView? _view;
  Size? _physicalSize;
  double? _pixelRatio;
  EdgeInsets? _viewPadding, _viewInsets;
  ModalRoute<T>? _route;
  NavigatorState? _navigator;
  bool _closeScheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.onInvalidated = _closeIfCurrent;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of<T>(context);
    widget.session._route = _route;
    _navigator = Navigator.of(context);
    final view = View.of(context);
    if (!identical(_view, view)) {
      if (_view != null) widget.session.invalidate();
      _view = view;
      _captureMetrics(view);
    }
  }

  void _captureMetrics(FlutterView view) {
    _physicalSize = view.physicalSize;
    _pixelRatio = view.devicePixelRatio;
    _viewPadding = EdgeInsets.fromViewPadding(
      view.viewPadding,
      view.devicePixelRatio,
    );
    _viewInsets = EdgeInsets.fromViewPadding(
      view.viewInsets,
      view.devicePixelRatio,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.onInvalidated = null;
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = _view;
    if (view == null || !widget.session.valid) return;
    final insets = EdgeInsets.fromViewPadding(
      view.viewInsets,
      view.devicePixelRatio,
    );
    final sameGeometry =
        _physicalSize == view.physicalSize &&
        _pixelRatio == view.devicePixelRatio &&
        _viewPadding ==
            EdgeInsets.fromViewPadding(view.viewPadding, view.devicePixelRatio);
    final previousInsets = _viewInsets!;
    final occlusionDidNotGrow =
        insets.left <= previousInsets.left &&
        insets.top <= previousInsets.top &&
        insets.right <= previousInsets.right &&
        insets.bottom <= previousInsets.bottom;
    _captureMetrics(view);
    // An unchanged target view can also receive another view's notification.
    // Keyboard close animations may report several decreasing inset frames.
    if (sameGeometry && occlusionDidNotGrow) return;
    widget.session.invalidate();
  }

  void _closeIfCurrent() {
    if (_closeScheduled) return;
    _closeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _closeScheduled = false;
      if (mounted && _route?.isCurrent == true && _navigator?.mounted == true) {
        _navigator!.pop<T>();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (_route?.isCurrent == true && !widget.session.valid) {
      _closeIfCurrent();
    }
    return IgnorePointer(
      ignoring: !widget.session.valid,
      child: ExcludeFocus(excluding: !widget.session.valid, child: widget.item),
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
    this.description,
    this.leading,
    this.trailing,
  }) : super(selected: checked, child: const SizedBox.shrink());
  final bool checked;
  final String label;
  final String? description;
  final Widget? leading;
  final Widget? trailing;
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
    final menu = SkedMenuStyle.of(context);
    return SkedMenuItemContent(
      leading: item.leading,
      trailing: item.trailing,
      selected: item.checked,
      child: item.description == null
          ? Text(item.label)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.label),
                if (item.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: menu.descriptionStyle({
                      if (!item.enabled) WidgetState.disabled,
                    }, selected: item.checked),
                  ),
                ],
              ],
            ),
    );
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

    final content = Padding(
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
    return menu.desktop ? DesktopMenuWindowGuard(child: content) : content;
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
