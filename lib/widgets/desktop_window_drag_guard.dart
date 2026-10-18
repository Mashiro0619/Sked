import 'dart:async';

import 'package:flutter/gestures.dart';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../services/desktop_window_bridge.dart';

/// Only app menus opt into moving the window through their dismissal barrier.
/// Keep the caller's route metadata and the pages that own its caption regions.
class DesktopMenuRouteSettings extends RouteSettings {
  DesktopMenuRouteSettings(BuildContext source, {RouteSettings? original})
    : source = source,
      owners = _ownerRoutes(source),
      super(name: original?.name, arguments: original?.arguments);

  final BuildContext source;
  final List<ModalRoute<dynamic>> owners;

  static List<ModalRoute<dynamic>> _ownerRoutes(BuildContext context) {
    final result = <ModalRoute<dynamic>>[];
    for (
      ModalRoute<dynamic>? route = ModalRoute.of(context);
      route != null && !result.contains(route);
      route = route.navigator == null
          ? null
          : ModalRoute.of(route.navigator!.context)
    ) {
      result.add(route);
    }
    return result;
  }
}

class _MenuWindowLease {
  const _MenuWindowLease(this.route, this.settings);
  final PopupRoute<dynamic> route;
  final DesktopMenuRouteSettings settings;

  bool get active {
    final navigator = route.navigator;
    if (navigator == null ||
        !route.isCurrent ||
        route.offstage ||
        navigator.userGestureInProgress ||
        route.animation?.status == AnimationStatus.reverse ||
        route.animation?.status == AnimationStatus.dismissed ||
        !settings.source.mounted ||
        settings.owners.isEmpty ||
        !_paintedAt(
          settings.source.findRenderObject(),
          null,
          interactive: true,
        )) {
      return false;
    }
    return settings.owners.every(
      (owner) =>
          owner.isActive &&
          !owner.offstage &&
          owner.animation?.status != AnimationStatus.reverse &&
          owner.navigator?.userGestureInProgress == false &&
          (owner.navigator == navigator || owner.isCurrent),
    );
  }

  bool hitTest(Offset position) {
    // The page subtree excludes the route's full-screen barrier. Its own box
    // fills the window, so test its children, not just its rectangle.
    final page = route.subtreeContext?.findRenderObject();
    return page is RenderBox &&
        _paintedAt(page, position, interactive: true) &&
        page.hitTest(
          BoxHitTestResult(),
          position: page.globalToLocal(position),
        );
  }

  void dismiss() {
    if (active) route.navigator!.pop();
  }
}

/// Per-window registry. Probing a region's original subtree performs hit testing
/// only; it never dispatches an event through the editor's modal barrier.
class DesktopWindowDragController extends ChangeNotifier {
  final _regions = <_DragAreaRender>{};
  final _editors = <Object, bool Function()>{};
  final _menus = <Object, _MenuWindowLease>{};
  bool _scheduled = false, _disposed = false;
  bool get protectsEditor =>
      !_disposed && _editors.values.any((visible) => visible());
  _MenuWindowLease? get _activeMenu {
    if (_disposed) return null;
    for (final menu in _menus.values.toList().reversed) {
      if (menu.active) return menu;
    }
    return null;
  }

  void changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  bool canDrag(Offset globalPosition) {
    final menu = _activeMenu;
    final editor = protectsEditor;
    if (!editor && menu == null) return false;
    if (menu?.hitTest(globalPosition) ?? false) return false;
    // Editor leases already allow caption gestures through their own barrier.
    // Ordinary menus must additionally respect the source page's other controls.
    final inspectPage = menu != null && !editor;
    for (final region in _regions.toList().reversed) {
      if (!_paintedAt(region, globalPosition, interactive: inspectPage)) {
        continue;
      }
      if (inspectPage && !menu.settings.owners.contains(region.route)) {
        continue;
      }
      final result = BoxHitTestResult();
      if (region.hitTest(
        result,
        position: region.globalToLocal(globalPosition),
      )) {
        if (inspectPage) {
          // AppBar actions are siblings above flexibleSpace's drag region.
          // Probe the whole owning page so those controls retain hit priority.
          final page = region.route?.subtreeContext?.findRenderObject();
          if (page is! RenderBox ||
              !_paintedAt(page, globalPosition, interactive: true)) {
            return false;
          }
          final pageResult = BoxHitTestResult();
          page.hitTest(
            pageResult,
            position: page.globalToLocal(globalPosition),
          );
          return pageResult.path.any((entry) => entry.target == region) &&
              pageResult.path.any((entry) => entry.target is _DragBlankRender);
        }
        return result.path.any((entry) => entry.target is _DragBlankRender);
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _regions.clear();
    _editors.clear();
    _menus.clear();
    super.dispose();
  }
}

bool _paintedAt(
  RenderObject? object,
  Offset? point, {
  bool interactive = false,
}) {
  if (object is! RenderBox || !object.attached || !object.hasSize) return false;
  RenderObject? child;
  for (
    RenderObject? current = object;
    current != null;
    current = current.parent
  ) {
    if (current is RenderOffstage && current.offstage) return false;
    if (current is RenderOpacity && current.opacity == 0) return false;
    if (current is RenderAnimatedOpacity && current.opacity.value == 0) {
      return false;
    }
    if (interactive) {
      if (current is RenderIgnorePointer && current.ignoring) return false;
      if (current is RenderAbsorbPointer && current.absorbing) return false;
      if (current is RenderIndexedStack && child != null) {
        final index = current.index;
        if (index == null || current.getChildrenAsList()[index] != child) {
          return false;
        }
      }
    }
    if (point != null && child != null && current is RenderBox) {
      final clip = current.describeApproximatePaintClip(child);
      if (clip != null && !clip.contains(current.globalToLocal(point))) {
        return false;
      }
    }
    child = current;
  }
  return true;
}

class DesktopWindowDragScope extends InheritedWidget {
  const DesktopWindowDragScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final DesktopWindowDragController controller;
  static DesktopWindowDragController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesktopWindowDragScope>()
      ?.controller;
  @override
  bool updateShouldNotify(DesktopWindowDragScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Item lifetime registers the shared popup in the window that owns it, also
/// for menus hosted by nested Navigators. This adds no paint or hit-test layer.
class DesktopMenuWindowGuard extends StatefulWidget {
  const DesktopMenuWindowGuard({super.key, required this.child});
  final Widget child;

  @override
  State<DesktopMenuWindowGuard> createState() => _DesktopMenuWindowGuardState();
}

class _DesktopMenuWindowGuardState extends State<DesktopMenuWindowGuard> {
  DesktopWindowDragController? _owner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = DesktopWindowDragScope.maybeOf(context);
    final route = ModalRoute.of(context);
    _owner?._menus.remove(this);
    _owner = owner;
    final settings = route?.settings;
    if (route is PopupRoute<dynamic> && settings is DesktopMenuRouteSettings) {
      owner?._menus[this] = _MenuWindowLease(route, settings);
    }
  }

  @override
  void dispose() {
    _owner?._menus.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A lease belongs to one visible floating editor, including its nested tasks.
class DesktopEditorWindowGuard extends StatefulWidget {
  const DesktopEditorWindowGuard({
    super.key,
    required this.active,
    required this.child,
  });
  final bool active;
  final Widget child;
  @override
  State<DesktopEditorWindowGuard> createState() =>
      _DesktopEditorWindowGuardState();
}

class _DesktopEditorWindowGuardState extends State<DesktopEditorWindowGuard> {
  DesktopWindowDragController? _owner;
  bool _visible() =>
      mounted && widget.active && _paintedAt(context.findRenderObject(), null);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = DesktopWindowDragScope.maybeOf(context);
    if (identical(next, _owner)) return;
    _owner?._editors.remove(this);
    _owner?.changed();
    _owner = next;
    next?._editors[this] = _visible;
    next?.changed();
  }

  @override
  void didUpdateWidget(DesktopEditorWindowGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _owner?.changed();
  }

  @override
  void dispose() {
    _owner?._editors.remove(this);
    _owner?.changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class DesktopRegisteredDragArea extends SingleChildRenderObjectWidget {
  const DesktopRegisteredDragArea({
    super.key,
    required this.controller,
    required super.child,
  });
  final DesktopWindowDragController? controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _DragAreaRender(controller, ModalRoute.of(context));
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final region = renderObject as _DragAreaRender;
    region.owner = controller;
    region.route = ModalRoute.of(context);
  }
}

class _DragAreaRender extends RenderProxyBox {
  _DragAreaRender(this._owner, this.route);
  DesktopWindowDragController? _owner;
  ModalRoute<dynamic>? route;
  set owner(DesktopWindowDragController? value) {
    if (identical(value, _owner)) return;
    _owner?._regions.remove(this);
    _owner = value;
    if (attached) _owner?._regions.add(this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _owner?._regions.add(this);
  }

  @override
  void detach() {
    _owner?._regions.remove(this);
    super.detach();
  }
}

class DesktopDragBlank extends SingleChildRenderObjectWidget {
  const DesktopDragBlank({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _DragBlankRender();
}

class _DragBlankRender extends RenderProxyBox {}

/// Editors protect background controls. Menus allow their owner's blank caption
/// gestures while their own surface and ordinary outside taps retain priority.
class DesktopEditorCaptionProtection extends StatefulWidget {
  const DesktopEditorCaptionProtection({super.key, required this.controller});
  final DesktopWindowDragController controller;
  @override
  State<DesktopEditorCaptionProtection> createState() =>
      _CaptionProtectionState();
}

class _CaptionProtectionState extends State<DesktopEditorCaptionProtection> {
  bool _panAllowed = false, _doubleTapAllowed = false;
  bool _tapAllowed = false, _secondaryAllowed = false;
  _MenuWindowLease? _panMenu, _doubleTapMenu;
  _MenuWindowLease? _tapMenu, _secondaryMenu;

  bool _stillAllowed(_MenuWindowLease? menu) => menu == null
      ? widget.controller.protectsEditor &&
            widget.controller._activeMenu == null
      : menu.active && widget.controller._activeMenu?.route == menu.route;

  @override
  Widget build(BuildContext context) => _CaptionHitGate(
    controller: widget.controller,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      supportedDevices: const {PointerDeviceKind.mouse},
      onTapUp: (_) {
        if (_tapAllowed && _stillAllowed(_tapMenu)) {
          _tapMenu?.dismiss();
        }
        _tapAllowed = false;
        _tapMenu = null;
      },
      onTapCancel: () {
        _tapAllowed = false;
        _tapMenu = null;
      },
      onPanStart: (_) {
        if (_panAllowed && _stillAllowed(_panMenu)) {
          unawaited(DesktopWindowBridge.instance.command('startDrag'));
        }
      },
      onPanEnd: (_) {
        _panAllowed = false;
        _panMenu = null;
      },
      onPanCancel: () {
        _panAllowed = false;
        _panMenu = null;
      },
      onDoubleTap: () {
        if (_doubleTapAllowed && _stillAllowed(_doubleTapMenu)) {
          _doubleTapMenu?.dismiss();
          unawaited(DesktopWindowBridge.instance.command('toggleMaximize'));
        }
        _doubleTapAllowed = false;
        _doubleTapMenu = null;
      },
      onDoubleTapCancel: () {
        _doubleTapAllowed = false;
        _doubleTapMenu = null;
      },
      onSecondaryTapUp: (_) {
        if (_secondaryAllowed && _stillAllowed(_secondaryMenu)) {
          _secondaryMenu?.dismiss();
          unawaited(DesktopWindowBridge.instance.command('systemMenu'));
        }
        _secondaryAllowed = false;
        _secondaryMenu = null;
      },
      onSecondaryTapCancel: () {
        _secondaryAllowed = false;
        _secondaryMenu = null;
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.kind != PointerDeviceKind.mouse) return;
          // Capture before gesture recognition's tap deadline. Replacing a
          // menu during a held press must not transfer that press to the new one.
          final menu = widget.controller._activeMenu;
          final allowed = widget.controller.canDrag(event.position);
          if (event.buttons & kPrimaryMouseButton != 0) {
            _tapMenu = _panMenu = _doubleTapMenu = menu;
            _tapAllowed = _panAllowed = _doubleTapAllowed = allowed;
          }
          if (event.buttons & kSecondaryMouseButton != 0) {
            _secondaryMenu = menu;
            _secondaryAllowed = allowed;
          }
        },
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _CaptionHitGate extends SingleChildRenderObjectWidget {
  const _CaptionHitGate({required this.controller, required super.child});
  final DesktopWindowDragController controller;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CaptionHitRender(controller);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _CaptionHitRender renderObject,
  ) => renderObject.controller = controller;
}

class _CaptionHitRender extends RenderProxyBox {
  _CaptionHitRender(this.controller);
  DesktopWindowDragController controller;
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final globalPosition = localToGlobal(position);
    if (controller._activeMenu?.hitTest(globalPosition) ?? false) return false;
    return (controller.protectsEditor || controller.canDrag(globalPosition)) &&
        super.hitTest(result, position: position);
  }
}
