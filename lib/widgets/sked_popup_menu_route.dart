import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:material_ui/material_ui.dart';

import '../theme/sked_expressive_theme.dart';
import '../theme/sked_menu_style.dart';
import 'sked_menu_surface.dart';

Future<T?> showSkedPopupRoute<T>({
  required BuildContext context,
  required List<PopupMenuEntry<T>> items,
  required PopupMenuPositionBuilder positionBuilder,
  required BoxConstraints constraints,
  required MenuStyle style,
  T? initialValue,
  bool? requestFocus,
  bool useRootNavigator = false,
  String? semanticLabel,
  RouteSettings? routeSettings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final l = MaterialLocalizations.of(context);
  return navigator.push<T>(
    _SkedPopupRoute<T>(
      items: items,
      positionBuilder: positionBuilder,
      constraints: constraints,
      style: style,
      initialValue: initialValue,
      requestFocus: requestFocus,
      semanticLabel: semanticLabel ?? l.popupMenuLabel,
      barrierLabel: l.menuDismissLabel,
      settings: routeSettings,
      motion: SkedMotionPolicy.of(context),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

class _SkedPopupRoute<T> extends PopupRoute<T> {
  _SkedPopupRoute({
    required this.items,
    required this.positionBuilder,
    required this.constraints,
    required this.style,
    required this.motion,
    required this.themes,
    required this.semanticLabel,
    required this.barrierLabel,
    this.initialValue,
    super.settings,
    super.requestFocus,
  }) : super(
         traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
         directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
       );

  final List<PopupMenuEntry<T>> items;
  final PopupMenuPositionBuilder positionBuilder;
  final BoxConstraints constraints;
  final MenuStyle style;
  SkedMotionPolicy motion;
  final CapturedThemes themes;
  final String semanticLabel;
  final T? initialValue;
  bool _disposed = false;

  @override
  final String barrierLabel;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => null;
  @override
  Duration get transitionDuration => SkedMenuMotion.duration(motion);
  @override
  Duration get reverseTransitionDuration =>
      SkedMenuMotion.duration(motion, reverse: true);

  void updateMotion(SkedMotionPolicy next) {
    if (motion.animationsEnabled == next.animationsEnabled &&
        motion.reduceMotion == next.reduceMotion) {
      return;
    }
    motion = next;
    scheduleMicrotask(() {
      if (_disposed) return;
      final current = controller;
      if (current == null) return;
      final closing = current.status == AnimationStatus.reverse;
      current
        ..duration = transitionDuration
        ..reverseDuration = reverseTransitionDuration;
      if (!motion.animationsEnabled) {
        current.value = closing ? 0 : 1;
      } else if (current.isAnimating) {
        unawaited(closing ? current.reverse() : current.forward());
      }
    });
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(_SkedPopupPage<T>(route: this));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _SkedPopupPage<T> extends StatefulWidget {
  const _SkedPopupPage({required this.route});
  final _SkedPopupRoute<T> route;

  @override
  State<_SkedPopupPage<T>> createState() => _SkedPopupPageState<T>();
}

class _SkedPopupPageState<T> extends State<_SkedPopupPage<T>> {
  final _selected = GlobalKey();
  Alignment? _alignment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedContext = _selected.currentContext;
      if (mounted && selectedContext != null) {
        unawaited(Scrollable.ensureVisible(selectedContext, alignment: .5));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.route.updateMotion(SkedMotionPolicy.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final selectedIndex = route.initialValue == null
        ? -1
        : route.items.indexWhere((item) => item.represents(route.initialValue));
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchor = route
            .positionBuilder(context, constraints)
            .toRect(Offset.zero & constraints.biggest);
        return CustomSingleChildLayout(
          delegate: SkedMenuLayoutDelegate(
            anchor: anchor,
            available: SkedMenuStyle.availableRectOf(context),
            textDirection: Directionality.of(context),
            constraints: route.constraints,
            alignToAnchorTop: true,
            preferredAlignment: _alignment,
            onAlignment: (value) {
              if (mounted && _alignment != value) {
                setState(() => _alignment = value);
              }
            },
          ),
          child: SkedMenuSurface(
            animation: route.animation!,
            motion: route.motion,
            alignment: _alignment ?? Alignment.topCenter,
            style: route.style,
            child: IntrinsicWidth(
              child: Semantics(
                role: SemanticsRole.menu,
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: route.semanticLabel,
                child: SingleChildScrollView(
                  primary: false,
                  child: ListBody(
                    children: [
                      for (var i = 0; i < route.items.length; i++)
                        KeyedSubtree(
                          key: i == selectedIndex ? _selected : null,
                          child: route.items[i],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
