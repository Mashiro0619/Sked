import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/desktop_layout_preferences.dart';
import 'workbench_chrome_metrics.dart';

enum SkedResizeEdge {
  left,
  top,
  right,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  bool get movesLeft => this == left || this == topLeft || this == bottomLeft;
  bool get movesRight =>
      this == right || this == topRight || this == bottomRight;
  bool get movesTop => this == top || this == topLeft || this == topRight;
  bool get movesBottom =>
      this == bottom || this == bottomLeft || this == bottomRight;
  bool get horizontal => movesLeft || movesRight;
  bool get vertical => movesTop || movesBottom;
}

/// Apply each delta to the displayed rectangle, so reversing at a limit responds
/// immediately. Physical edges deliberately do not change meaning in RTL.
Rect resizeSkedFloatingRect({
  required Rect rect,
  required Offset delta,
  required SkedResizeEdge edge,
  required Rect bounds,
  required Size minimumSize,
}) {
  final width = math.min(rect.width, math.max(0.0, bounds.width));
  final height = math.min(rect.height, math.max(0.0, bounds.height));
  var left = rect.left.clamp(
    bounds.left,
    math.max(bounds.left, bounds.right - width),
  );
  var top = rect.top.clamp(
    bounds.top,
    math.max(bounds.top, bounds.bottom - height),
  );
  var right = left + width;
  var bottom = top + height;
  final minWidth = minimumSize.width.clamp(0.0, bounds.width);
  final minHeight = minimumSize.height.clamp(0.0, bounds.height);
  if (edge.movesLeft) {
    left = (left + delta.dx).clamp(
      bounds.left,
      math.max(bounds.left, right - minWidth),
    );
  } else if (edge.movesRight) {
    right = (right + delta.dx).clamp(
      math.min(bounds.right, left + minWidth),
      bounds.right,
    );
  }
  if (edge.movesTop) {
    top = (top + delta.dy).clamp(
      bounds.top,
      math.max(bounds.top, bottom - minHeight),
    );
  } else if (edge.movesBottom) {
    bottom = (bottom + delta.dy).clamp(
      math.min(bounds.bottom, top + minHeight),
      bounds.bottom,
    );
  }
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

/// A divider owns only its hit area. The host keeps its existing one-pixel gap
/// and overlays this widget there without taking space from either child.
class SkedResizeHandle extends StatelessWidget {
  const SkedResizeHandle({
    super.key,
    this.axis = Axis.horizontal,
    required this.onDelta,
    this.onStart,
    this.onEnd,
    this.onReset,
    this.reverse = false,
    this.directional = true,
    this.increaseReversed = false,
    this.focusNode,
  });
  final Axis axis;
  final ValueChanged<double> onDelta;
  final VoidCallback? onStart, onEnd, onReset;
  final bool reverse, directional;
  final bool increaseReversed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final rtl =
        directional &&
        axis == Axis.horizontal &&
        Directionality.of(context) == TextDirection.rtl;
    return TextFieldTapRegion(
      child: _ResizeTarget(
        focusNode: focusNode,
        horizontal: axis == Axis.horizontal,
        vertical: axis == Axis.vertical,
        cursor: axis == Axis.horizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        semanticIncrease: axis == Axis.horizontal
            ? Offset(
                24.0 * (increaseReversed ? -1 : 1) * (rtl != reverse ? -1 : 1),
                0,
              )
            : Offset(0, 24.0 * (increaseReversed != reverse ? -1 : 1)),
        onDelta: (delta) {
          final value = axis == Axis.horizontal ? delta.dx : delta.dy;
          onDelta(value * (rtl != reverse ? -1 : 1));
        },
        onStart: onStart,
        onEnd: onEnd,
        onReset: onReset,
      ),
    );
  }
}

/// An extent-based divider accumulates every input event before the next frame.
/// The host supplies its displayed extent and bounds in the same units, then
/// converts [onChanged] values to any persisted logical size.
class SkedExtentResizeHandle extends StatefulWidget {
  const SkedExtentResizeHandle({
    super.key,
    required this.extent,
    required this.minExtent,
    required this.maxExtent,
    required this.onChanged,
    this.axis = Axis.horizontal,
    this.onStart,
    this.onEnd,
    this.onReset,
    this.reverse = false,
    this.directional = true,
    this.increaseReversed = false,
    this.focusNode,
  }) : assert(minExtent <= maxExtent);

  final double extent, minExtent, maxExtent;
  final ValueChanged<double> onChanged;
  final Axis axis;
  final VoidCallback? onStart, onEnd, onReset;
  final bool reverse, directional, increaseReversed;
  final FocusNode? focusNode;

  @override
  State<SkedExtentResizeHandle> createState() => _SkedExtentResizeHandleState();
}

class _SkedExtentResizeHandleState extends State<SkedExtentResizeHandle> {
  late double _extent;

  double _clamp(double value) =>
      value.clamp(widget.minExtent, widget.maxExtent);

  @override
  void initState() {
    super.initState();
    _extent = _clamp(widget.extent);
  }

  @override
  void didUpdateWidget(SkedExtentResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A viewport or content change can cap the displayed size. Adopt that
    // geometry without persisting the cap as a new user preference.
    _extent = _clamp(widget.extent);
  }

  void _resize(double delta) {
    final next = _clamp(_extent + delta);
    if (next == _extent) return;
    _extent = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => SkedResizeHandle(
    axis: widget.axis,
    reverse: widget.reverse,
    directional: widget.directional,
    increaseReversed: widget.increaseReversed,
    focusNode: widget.focusNode,
    onDelta: _resize,
    onStart: widget.onStart,
    onEnd: widget.onEnd,
    onReset: widget.onReset,
  );
}

/// Opt-in frame for a measured floating surface; it never owns a route or size.
class SkedResizableFrame extends StatelessWidget {
  const SkedResizableFrame({
    super.key,
    required this.child,
    required this.onResize,
    this.onStart,
    this.onEnd,
    this.onReset,
    this.keyPrefix = 'floating-resize',
    this.leadingHandleKey,
    this.leadingFocusNode,
    this.enabled = true,
    this.reserveResizeSpace = true,
  });
  final Widget child;
  final void Function(SkedResizeEdge, Offset) onResize;
  final VoidCallback? onStart, onEnd, onReset;
  final String keyPrefix;
  final Key? leadingHandleKey;
  final FocusNode? leadingFocusNode;
  final bool enabled;

  /// Keep the viewport stable when a child task temporarily disables resizing.
  /// Docked hosts can opt out when they use their own divider instead.
  final bool reserveResizeSpace;

  static const contentInset = 9.0;
  static const _edgeExtent = contentInset;
  static const _cornerExtent = 18.0;

  @override
  Widget build(BuildContext context) {
    final leading = Directionality.of(context) == TextDirection.rtl
        ? SkedResizeEdge.right
        : SkedResizeEdge.left;
    Widget target(SkedResizeEdge edge) => TextFieldTapRegion(
      child: _ResizeTarget(
        focusNode: edge == leading ? leadingFocusNode : null,
        key: edge == leading && leadingHandleKey != null
            ? leadingHandleKey
            : ValueKey('$keyPrefix-${edge.name}'),
        horizontal: edge.horizontal,
        vertical: edge.vertical,
        semanticIncrease: Offset(
          edge.movesLeft
              ? -24
              : edge.movesRight
              ? 24
              : 0,
          edge.movesTop
              ? -24
              : edge.movesBottom
              ? 24
              : 0,
        ),
        cursor: switch (edge) {
          SkedResizeEdge.left ||
          SkedResizeEdge.right => SystemMouseCursors.resizeLeftRight,
          SkedResizeEdge.top ||
          SkedResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
          SkedResizeEdge.topLeft || SkedResizeEdge.bottomRight =>
            SystemMouseCursors.resizeUpLeftDownRight,
          _ => SystemMouseCursors.resizeUpRightDownLeft,
        },
        onDelta: (delta) => onResize(edge, delta),
        onStart: onStart,
        onEnd: onEnd,
        onReset: onReset,
      ),
    );
    Widget corner(SkedResizeEdge edge) => ClipPath(
      clipper: _ResizeCornerClipper(edge, _edgeExtent),
      child: target(edge),
    );
    // Keep this Stack and child slot even while docked or covered by a picker.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Reserve space outside the entire viewport, not just its content or
        // scrollbar thumb. Scrollbar tracks must not intercept resize gestures,
        // and resizing must not intercept scrollbars or controls at the edge.
        Padding(
          padding: EdgeInsets.all(reserveResizeSpace ? contentInset : 0),
          child: child,
        ),
        if (enabled) ...[
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _edgeExtent,
            child: target(SkedResizeEdge.left),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _edgeExtent,
            child: target(SkedResizeEdge.right),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _edgeExtent,
            child: target(SkedResizeEdge.top),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _edgeExtent,
            child: target(SkedResizeEdge.bottom),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: _cornerExtent,
            height: _cornerExtent,
            child: corner(SkedResizeEdge.topLeft),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: _cornerExtent,
            height: _cornerExtent,
            child: corner(SkedResizeEdge.topRight),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            width: _cornerExtent,
            height: _cornerExtent,
            child: corner(SkedResizeEdge.bottomLeft),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            width: _cornerExtent,
            height: _cornerExtent,
            child: corner(SkedResizeEdge.bottomRight),
          ),
        ],
      ],
    );
  }
}

/// Keep diagonal resize targets in the outer gutter, including at scroll ends.
/// The inner square belongs to the viewport and its scrollbar track.
class _ResizeCornerClipper extends CustomClipper<Path> {
  const _ResizeCornerClipper(this.edge, this.gutter);

  final SkedResizeEdge edge;
  final double gutter;

  @override
  Path getClip(Size size) {
    final inset = Rect.fromLTWH(
      edge.movesLeft ? gutter : 0,
      edge.movesTop ? gutter : 0,
      math.max(0, size.width - gutter),
      math.max(0, size.height - gutter),
    );
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(inset);
  }

  @override
  bool shouldReclip(_ResizeCornerClipper oldClipper) =>
      edge != oldClipper.edge || gutter != oldClipper.gutter;
}

class _ResizeTarget extends StatefulWidget {
  const _ResizeTarget({
    super.key,
    required this.horizontal,
    required this.vertical,
    required this.cursor,
    required this.onDelta,
    this.semanticIncrease,
    this.focusNode,
    this.onStart,
    this.onEnd,
    this.onReset,
  });
  final bool horizontal, vertical;
  final MouseCursor cursor;
  final ValueChanged<Offset> onDelta;
  final Offset? semanticIncrease;
  final FocusNode? focusNode;
  final VoidCallback? onStart, onEnd, onReset;
  @override
  State<_ResizeTarget> createState() => _ResizeTargetState();
}

class _ResizeTargetState extends State<_ResizeTarget> {
  bool _hovered = false, _focused = false, _dragging = false;

  void _step(Offset delta) {
    widget.onStart?.call();
    widget.onDelta(delta);
    // The preference service coalesces disk writes. Commit the user intent now
    // so leaving this page immediately after a key press cannot lose it.
    widget.onEnd?.call();
  }

  void _finish() {
    if (mounted) setState(() => _dragging = false);
    widget.onEnd?.call();
  }

  void _reset() {
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).resizePanel,
    onIncrease: () => _step(
      widget.semanticIncrease ??
          Offset(widget.horizontal ? 24 : 0, widget.vertical ? 24 : 0),
    ),
    onDecrease: () => _step(
      -(widget.semanticIncrease ??
          Offset(widget.horizontal ? 24 : 0, widget.vertical ? 24 : 0)),
    ),
    child: Focus(
      focusNode: widget.focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.home && widget.onReset != null) {
          _reset();
          return KeyEventResult.handled;
        }
        final dx = widget.horizontal
            ? (key == LogicalKeyboardKey.arrowLeft
                  ? -24.0
                  : key == LogicalKeyboardKey.arrowRight
                  ? 24.0
                  : 0.0)
            : 0.0;
        final dy = widget.vertical
            ? (key == LogicalKeyboardKey.arrowUp
                  ? -24.0
                  : key == LogicalKeyboardKey.arrowDown
                  ? 24.0
                  : 0.0)
            : 0.0;
        if (dx == 0 && dy == 0) return KeyEventResult.ignored;
        _step(Offset(dx, dy));
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: widget.cursor,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanDown: (_) => widget.onStart?.call(),
          onPanStart: (_) => setState(() => _dragging = true),
          onPanUpdate: (details) => widget.onDelta(
            Offset(
              widget.horizontal ? details.delta.dx : 0,
              widget.vertical ? details.delta.dy : 0,
            ),
          ),
          onPanEnd: (_) => _finish(),
          onPanCancel: _finish,
          onDoubleTap: widget.onReset == null ? null : _reset,
          child: ColoredBox(
            color: _hovered || _focused || _dragging
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .14)
                : Colors.transparent,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

typedef DesktopResizableRegionBuilder = Widget Function(
  BuildContext context,
  double? preferredExtent,
  ValueChanged<double> update,
  VoidCallback commit,
  VoidCallback reset,
);

/// A single mounted region owns the live drag. Peers read persisted dimensions
/// on their next mount, rather than following another open instance's gesture.
class DesktopResizableRegion extends StatefulWidget {
  const DesktopResizableRegion({
    super.key,
    required this.layoutKey,
    required this.builder,
    this.axis = Axis.horizontal,
  });
  final DesktopLayoutRegion layoutKey;
  final DesktopResizableRegionBuilder builder;
  final Axis axis;
  @override
  State<DesktopResizableRegion> createState() => _DesktopResizableRegionState();
}

class _DesktopResizableRegionState extends State<DesktopResizableRegion> {
  DesktopLayoutPreferences? _preferences;
  double? _extent;
  bool _loaded = false, _changed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preferences = Provider.of<DesktopLayoutPreferences?>(context);
    if (!_loaded && _preferences?.ready == true) {
      if (!_changed) {
        final size = _preferences!.preferenceFor(widget.layoutKey);
        _extent = widget.axis == Axis.horizontal ? size?.width : size?.height;
      }
      _loaded = true;
    }
  }

  @override
  void didUpdateWidget(DesktopResizableRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutKey != widget.layoutKey ||
        oldWidget.axis != widget.axis) {
      final size = _preferences?.preferenceFor(widget.layoutKey);
      _extent = widget.axis == Axis.horizontal ? size?.width : size?.height;
      _loaded = _preferences?.ready == true;
      _changed = false;
    }
  }

  void _update(double extent) {
    if (!extent.isFinite || extent <= 0 || _extent == extent) return;
    setState(() {
      _extent = extent;
      _changed = true;
    });
  }

  void _commit() {
    if (!_changed) return;
    final previous = _preferences?.preferenceFor(widget.layoutKey);
    _preferences?.setPreferredSize(
      widget.layoutKey,
      PreferredRegionSize(
        width: widget.axis == Axis.horizontal ? _extent : previous?.width,
        height: widget.axis == Axis.vertical ? _extent : previous?.height,
        dockedWidth: previous?.dockedWidth,
      ),
    );
    _changed = false;
  }

  void _reset() {
    setState(() {
      _extent = null;
      _changed = true;
    });
    _commit();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    WorkbenchChromeMetrics.of(context).desktop ? _extent : null,
    _update,
    _commit,
    _reset,
  );
}
