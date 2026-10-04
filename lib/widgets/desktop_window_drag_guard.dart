import 'dart:async';

import 'package:flutter/gestures.dart';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../services/desktop_window_bridge.dart';

/// Per-window registry. Probing a region's original subtree performs hit testing
/// only; it never dispatches an event through the editor's modal barrier.
class DesktopWindowDragController extends ChangeNotifier {
  final _regions = <_DragAreaRender>{};
  final _editors = <Object, bool Function()>{};
  bool _scheduled = false, _disposed = false;
  bool get protectsEditor =>
      !_disposed && _editors.values.any((visible) => visible());
  void changed() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  bool canDrag(Offset globalPosition) {
    if (!protectsEditor) return false;
    for (final region in _regions.toList().reversed) {
      if (!_paintedAt(region, globalPosition)) continue;
      final result = BoxHitTestResult();
      if (region.hitTest(
        result,
        position: region.globalToLocal(globalPosition),
      )) {
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
    super.dispose();
  }
}

bool _paintedAt(RenderObject? object, Offset? point) {
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
      _DragAreaRender(controller);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) => (renderObject as _DragAreaRender).owner = controller;
}

class _DragAreaRender extends RenderProxyBox {
  _DragAreaRender(this._owner);
  DesktopWindowDragController? _owner;
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

/// Above all app routes, below OS caption buttons. Non-blank taps are consumed.
class DesktopEditorCaptionProtection extends StatefulWidget {
  const DesktopEditorCaptionProtection({super.key, required this.controller});
  final DesktopWindowDragController controller;
  @override
  State<DesktopEditorCaptionProtection> createState() =>
      _CaptionProtectionState();
}

class _CaptionProtectionState extends State<DesktopEditorCaptionProtection> {
  bool _panAllowed = false, _doubleTapAllowed = false;
  @override
  Widget build(BuildContext context) => _CaptionHitGate(
    controller: widget.controller,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      supportedDevices: const {PointerDeviceKind.mouse},
      onTap: () {},
      onPanDown: (details) =>
          _panAllowed = widget.controller.canDrag(details.globalPosition),
      onPanStart: (_) {
        if (_panAllowed && widget.controller.protectsEditor) {
          unawaited(DesktopWindowBridge.instance.command('startDrag'));
        }
      },
      onPanEnd: (_) => _panAllowed = false,
      onPanCancel: () => _panAllowed = false,
      onDoubleTapDown: (details) =>
          _doubleTapAllowed = widget.controller.canDrag(details.globalPosition),
      onDoubleTap: () {
        if (_doubleTapAllowed && widget.controller.protectsEditor) {
          unawaited(DesktopWindowBridge.instance.command('toggleMaximize'));
        }
        _doubleTapAllowed = false;
      },
      onDoubleTapCancel: () => _doubleTapAllowed = false,
      onSecondaryTapUp: (details) {
        if (widget.controller.canDrag(details.globalPosition)) {
          unawaited(DesktopWindowBridge.instance.command('systemMenu'));
        }
      },
      child: const SizedBox.expand(),
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
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      controller.protectsEditor && super.hitTest(result, position: position);
}
