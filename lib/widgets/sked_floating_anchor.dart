import 'package:material_ui/material_ui.dart';

/// Captures a trigger before its popup or row can leave the render tree.
/// Only the render object is retained; layouts never revisit its old Element.
class SkedFloatingAnchor {
  SkedFloatingAnchor._(this._renderBox) {
    _updateGlobalRect();
    initialRect = _lastGlobalRect;
  }

  /// A fixed global rectangle, for example a canvas pointer-down location.
  SkedFloatingAnchor.fromRect(Rect? rect) : _renderBox = null {
    initialRect = rect?.isFinite == true ? rect : null;
    _lastGlobalRect = initialRect;
  }

  factory SkedFloatingAnchor.capture(BuildContext? context) {
    final render = context?.mounted == true
        ? context!.findRenderObject()
        : null;
    return SkedFloatingAnchor._(render is RenderBox ? render : null);
  }

  final RenderBox? _renderBox;
  Rect? _lastGlobalRect;

  /// The global rectangle at capture time, unaffected by later trigger layout.
  late final Rect? initialRect;

  /// A new task must not follow controls inside the host it is about to move.
  bool isInSubtreeOf(RenderObject ancestor) {
    for (
      RenderObject? render = _renderBox;
      render != null;
      render = render.parent
    ) {
      if (identical(render, ancestor)) return true;
    }
    return false;
  }

  /// Follow a live trigger, retaining its last measured rectangle after removal.
  Rect? get globalRect {
    _updateGlobalRect();
    return _lastGlobalRect;
  }

  void _updateGlobalRect() {
    final render = _renderBox;
    if (render == null || !render.attached || !render.hasSize) return;
    final rect = MatrixUtils.transformRect(
      render.getTransformTo(null),
      Offset.zero & render.size,
    );
    if (rect.isFinite && !rect.isEmpty) _lastGlobalRect = rect;
  }

  /// Resolve in the host's coordinates, including an offset or scaled overlay.
  /// A route should pass its Navigator overlay, which exists before first layout.
  Rect? rectIn(RenderBox coordinateSpace) {
    final rect = globalRect;
    if (rect == null || !coordinateSpace.attached) return null;
    final transform = coordinateSpace.getTransformTo(null);
    if (transform.invert() == 0) return null;
    final local = MatrixUtils.transformRect(transform, rect);
    return local.isFinite ? local : null;
  }
}
