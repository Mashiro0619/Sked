import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/sked_surface.dart';
import 'workbench_chrome_metrics.dart';

/// Desktop-only floating chrome. Route ownership and modality stay with callers.
abstract final class SkedFloatingStyle {
  static const radius = BorderRadius.all(Radius.circular(8));
  static const margin = 8.0;
  static const anchorGap = 6.0;
  static BorderSide outline(ColorScheme colors) =>
      BorderSide(color: colors.outlineVariant);
  static List<BoxShadow> shadows(ColorScheme colors) => [
    BoxShadow(
      color: colors.shadow.withValues(alpha: .14),
      blurRadius: 16,
      offset: const Offset(-4, 0),
    ),
  ];
}

class SkedFloatingSurface extends StatelessWidget {
  const SkedFloatingSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: SkedFloatingStyle.radius,
      border: Border.fromBorderSide(
        SkedFloatingStyle.outline(Theme.of(context).colorScheme),
      ),
      boxShadow: SkedFloatingStyle.shadows(Theme.of(context).colorScheme),
    ),
    child: ClipRRect(
      borderRadius: SkedFloatingStyle.radius,
      child: SkedSurface(role: SkedSurfaceRole.content, child: child),
    ),
  );
}

/// Only wraps the title, never its sibling buttons, fields or scrolling body.
class SkedFloatingTitleDragHandle extends StatelessWidget {
  const SkedFloatingTitleDragHandle({
    super.key,
    required this.onUpdate,
    required this.child,
  });
  final ValueChanged<Offset> onUpdate;
  final Widget child;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.move,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanUpdate: (details) => onUpdate(details.delta),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: WorkbenchChromeMetrics.of(context).iconTarget,
        ),
        child: Align(alignment: AlignmentDirectional.topStart, child: child),
      ),
    ),
  );
}

Offset boundSkedFloatingPosition(Offset position, Size size, Rect bounds) =>
    Offset(
      position.dx.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - size.width),
      ),
      position.dy.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - size.height),
      ),
    );

enum SkedFloatingPlacement { automatic, left, right, below }

Offset positionSkedFloatingPanel({
  required Rect bounds,
  required Size size,
  Rect? anchor,
  bool rtl = false,
  SkedFloatingPlacement placement = SkedFloatingPlacement.automatic,
}) {
  if (anchor == null ||
      !anchor.overlaps(
        Rect.fromLTRB(bounds.left, 0, bounds.right, bounds.bottom),
      )) {
    return boundSkedFloatingPosition(
      bounds.center - Offset(size.width / 2, size.height / 2),
      size,
      bounds,
    );
  }
  final effective = placement == SkedFloatingPlacement.automatic
      ? anchor.bottom <= bounds.top + 64
            ? SkedFloatingPlacement.below
            : anchor.center.dx > bounds.left + bounds.width * .72
            ? SkedFloatingPlacement.left
            : anchor.center.dx < bounds.left + bounds.width * .24
            ? SkedFloatingPlacement.right
            : SkedFloatingPlacement.below
      : placement;
  final x = rtl ? anchor.right - size.width : anchor.left;
  final candidates = <Offset>[
    Offset(anchor.left - 6 - size.width, anchor.top),
    Offset(anchor.right + 6, anchor.top),
    Offset(x, anchor.bottom + 6),
    Offset(x, anchor.top - 6 - size.height),
  ];
  final order = switch (effective) {
    SkedFloatingPlacement.left => [0, 1, 2, 3],
    SkedFloatingPlacement.right => [1, 0, 2, 3],
    _ => [2, 3, 1, 0],
  };
  final rooms = [
    anchor.left - 6 - bounds.left,
    bounds.right - anchor.right - 6,
    bounds.bottom - anchor.bottom - 6,
    anchor.top - 6 - bounds.top,
  ];
  for (final side in order) {
    if (rooms[side] >= (side < 2 ? size.width : size.height)) {
      return boundSkedFloatingPosition(candidates[side], size, bounds);
    }
  }
  // Keep the closest viable attachment, never jump to the window center.
  var best = order.first;
  var area = -1.0;
  for (final side in order) {
    final available =
        math.max(0, rooms[side]) * (side < 2 ? bounds.height : bounds.width);
    if (available > area) {
      area = available;
      best = side;
    }
  }
  return boundSkedFloatingPosition(candidates[best], size, bounds);
}

/// When no horizontal neighbour can hold the reading width, use the larger
/// vertical space and let the body's existing scroll view absorb overflow.
/// Keep a minimum usable header/footer budget rather than collapsing to a sliver.
double skedFloatingHeightLimit(Rect bounds, Rect? anchor, double width) {
  if (anchor == null ||
      !anchor.overlaps(
        Rect.fromLTRB(bounds.left, 0, bounds.right, bounds.bottom),
      )) {
    return bounds.height;
  }
  if (anchor.left - bounds.left - 6 >= width ||
      bounds.right - anchor.right - 6 >= width) {
    return bounds.height;
  }
  final vertical = math.max(
    anchor.top - bounds.top - 6,
    bounds.bottom - anchor.bottom - 6,
  );
  return vertical >= 240 ? math.min(bounds.height, vertical) : bounds.height;
}

/// Only task titles opt in: controls and body gestures stay outside the handle.
class SkedFloatingDragScope extends InheritedWidget {
  const SkedFloatingDragScope({
    super.key,
    required this.onDrag,
    required super.child,
  });
  final ValueChanged<Offset> onDrag;
  static SkedFloatingDragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkedFloatingDragScope>();
  @override
  bool updateShouldNotify(SkedFloatingDragScope oldWidget) =>
      onDrag != oldWidget.onDrag;
}

class SkedPickerTitle extends StatelessWidget {
  const SkedPickerTitle({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scope = SkedFloatingDragScope.maybeOf(context);
    return scope == null
        ? child
        : SkedFloatingTitleDragHandle(
            key: const ValueKey('sked-picker-drag-handle'),
            onUpdate: scope.onDrag,
            child: child,
          );
  }
}

/// Resolve the persistent trigger, not a disappearing popup item focus node.
FocusNode? skedFloatingAnchorFocus(BuildContext? anchor) {
  if (anchor == null || !anchor.mounted) return null;
  final outer = Focus.maybeOf(anchor, createDependency: false);
  FocusNode? result;
  void visit(Element element) {
    if (result != null) return;
    final node = Focus.maybeOf(element, createDependency: false);
    if (node != null && !identical(node, outer) && node.canRequestFocus) {
      result = node;
    } else {
      element.visitChildElements(visit);
    }
  }

  anchor.visitChildElements(visit);
  return result;
}
