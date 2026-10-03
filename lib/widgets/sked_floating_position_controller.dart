import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';

/// Geometry state for one open panel. Host supplies measured coordinates and
/// bounds, and owns notifications. No routes, global settings or persistence.
class SkedFloatingPositionController {
  Offset? manualPosition;
  Offset? lastPosition;
  Size size = Size.zero;
  bool get detached => manualPosition != null;
  Offset? positionOverride({required bool hasAnchor}) =>
      manualPosition ?? (hasAnchor ? null : lastPosition);
  void recordLayout(Offset position, Size measuredSize) {
    lastPosition = position;
    size = measuredSize;
  }

  Offset drag(Offset delta, Rect bounds) {
    final current = boundSkedFloatingPosition(
      manualPosition ?? lastPosition ?? Offset.zero,
      size,
      bounds,
    );
    return manualPosition = boundSkedFloatingPosition(
      current + delta,
      size,
      bounds,
    );
  }

  void reset() {
    manualPosition = null;
    lastPosition = null;
    size = Size.zero;
  }
}
