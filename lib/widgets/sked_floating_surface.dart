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

/// A missing/off-screen anchor or insufficient space on both sides centers the
/// task instead of covering its trigger with a partially clamped placement.
Offset positionSkedFloatingPanel({
  required Rect bounds,
  required Size size,
  Rect? anchor,
  bool rtl = false,
}) {
  var position = bounds.center - Offset(size.width / 2, size.height / 2);
  if (anchor != null &&
      anchor.overlaps(
        Rect.fromLTRB(bounds.left, 0, bounds.right, bounds.bottom),
      )) {
    final below = anchor.bottom + SkedFloatingStyle.anchorGap;
    final above = anchor.top - SkedFloatingStyle.anchorGap - size.height;
    final x = rtl ? anchor.right - size.width : anchor.left;
    if (below + size.height <= bounds.bottom) {
      position = Offset(x, below);
    } else if (above >= bounds.top) {
      position = Offset(x, above);
    }
  }
  return boundSkedFloatingPosition(position, size, bounds);
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
