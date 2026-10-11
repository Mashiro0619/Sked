import 'sked_floating_position_controller.dart';

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/desktop_layout_preferences.dart';
import 'sked_floating_anchor.dart';
import 'sked_floating_surface.dart';
import 'sked_resizable.dart';
import 'sked_task_dialog.dart';
import 'workbench_chrome_metrics.dart';

/// Opt-in desktop presentation; ordinary dialogs and touch platforms ignore it.
class SkedDesktopFloatingDialog {
  const SkedDesktopFloatingDialog({
    this.anchorContext,
    this.preferredWidth = 360,
    this.maxWidth = 360,
    this.draggable = true,
    this.placement = SkedFloatingPlacement.below,
    this.layoutKey,
  });
  final BuildContext? anchorContext;
  final double preferredWidth, maxWidth;
  final bool draggable;
  final SkedFloatingPlacement placement;
  final DesktopLayoutRegion? layoutKey;
}

class _FloatingDismissIntent extends Intent {
  const _FloatingDismissIntent();
}

class SkedFloatingDialogHost extends StatefulWidget {
  const SkedFloatingDialogHost({
    super.key,
    required this.options,
    this.anchor,
    this.coordinateSpace,
    required this.child,
  });
  final SkedDesktopFloatingDialog options;
  final SkedFloatingAnchor? anchor;
  final RenderBox? coordinateSpace;
  final Widget child;
  @override
  State<SkedFloatingDialogHost> createState() => _SkedFloatingDialogHostState();
}

class _SkedFloatingDialogHostState extends State<SkedFloatingDialogHost> {
  final _position = SkedFloatingPositionController();
  Rect _bounds = Rect.zero;
  DesktopLayoutPreferences? _preferences;
  double? _preferredWidth, _preferredHeight;
  bool _loadedPreferences = false, _resizeChanged = false;

  bool get _canResize =>
      mounted &&
      widget.options.layoutKey != null &&
      ModalRoute.of(context)?.isCurrent == true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedPreferences) return;
    _loadedPreferences = true;
    _preferences = Provider.of<DesktopLayoutPreferences?>(
      context,
      listen: false,
    );
    _restorePreferredSize();
  }

  @override
  void didUpdateWidget(SkedFloatingDialogHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.layoutKey != widget.options.layoutKey) {
      _restorePreferredSize();
    }
  }

  void _restorePreferredSize() {
    final region = widget.options.layoutKey;
    final stored = region == null ? null : _preferences?.preferenceFor(region);
    _preferredWidth = stored?.width;
    _preferredHeight = stored?.height;
    _resizeChanged = false;
  }

  void _startResize() {
    if (!_canResize || _position.size.isEmpty) return;
    _resizeChanged = false;
    _position.manualPosition = _position.lastPosition;
  }

  void _resize(SkedResizeEdge edge, Offset delta) {
    if (!_canResize || _position.size.isEmpty || _bounds.isEmpty) return;
    final rect =
        (_position.lastPosition ?? _position.manualPosition ?? Offset.zero) &
        _position.size;
    final resized = resizeSkedFloatingRect(
      rect: rect,
      delta: delta,
      edge: edge,
      bounds: _bounds,
      minimumSize: Size(
        320,
        120 * WorkbenchChromeMetrics.of(context).textScale,
      ),
    );
    setState(() {
      if (edge.horizontal) _preferredWidth = resized.width;
      if (edge.vertical) _preferredHeight = resized.height;
      _position.manualPosition = resized.topLeft;
      _position.recordLayout(resized.topLeft, resized.size);
      _resizeChanged = true;
    });
  }

  void _storePreferredSize() {
    final region = widget.options.layoutKey;
    if (region == null) return;
    final previous = _preferences?.preferenceFor(region);
    _preferences?.setPreferredSize(
      region,
      PreferredRegionSize(
        width: _preferredWidth,
        height: _preferredHeight,
        dockedWidth: previous?.dockedWidth,
      ),
    );
  }

  void _finishResize() {
    if (!_resizeChanged) return;
    _resizeChanged = false;
    _storePreferredSize();
  }

  void _resetSize() {
    if (!_canResize) return;
    setState(() {
      _preferredWidth = _preferredHeight = null;
      _resizeChanged = false;
    });
    _storePreferredSize();
  }

  void _drag(Offset delta) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _position.drag(delta, _bounds));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final metrics = WorkbenchChromeMetrics.of(context);
      final left = media.padding.left + SkedFloatingStyle.margin;
      final top =
          media.padding.top + metrics.toolbarHeight + SkedFloatingStyle.margin;
      _bounds = Rect.fromLTRB(
        left,
        top,
        math.max(
          left,
          constraints.maxWidth - media.padding.right - SkedFloatingStyle.margin,
        ),
        math.max(
          top,
          constraints.maxHeight -
              math.max(media.padding.bottom, media.viewInsets.bottom) -
              SkedFloatingStyle.margin,
        ),
      );
      final viewport = Offset.zero & constraints.biggest;
      final space = widget.coordinateSpace;
      final measuredAnchor = space == null
          ? null
          : widget.anchor?.rectIn(space);
      final anchor = measuredAnchor?.overlaps(viewport) == true
          ? measuredAnchor
          : null;
      final width = _preferredWidth == null
          ? math.min(
              _bounds.width,
              math.min(
                widget.options.maxWidth,
                widget.options.preferredWidth * metrics.textScale,
              ),
            )
          : _preferredWidth!
                .clamp(math.min(320.0, _bounds.width), _bounds.width)
                .toDouble();
      final height = _preferredHeight
          ?.clamp(
            math.min(120 * metrics.textScale, _bounds.height),
            _bounds.height,
          )
          .toDouble();
      return Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _FloatingDismissIntent(),
        },
        child: Actions(
          actions: {
            _FloatingDismissIntent: CallbackAction<_FloatingDismissIntent>(
              onInvoke: (_) {
                Navigator.of(context).maybePop();
                return null;
              },
            ),
          },
          child: CustomSingleChildLayout(
            delegate: _FloatingDialogPosition(
              bounds: _bounds,
              anchorBounds: viewport,
              anchor: anchor,
              manualPosition: _position.positionOverride(
                hasAnchor: anchor != null,
              ),
              width: width,
              height: height,
              rtl: Directionality.of(context) == TextDirection.rtl,
              placement: widget.options.placement,
              onLayout: _position.recordLayout,
            ),
            child: SkedResizableFrame(
              keyPrefix: 'floating-form-resize',
              enabled: _canResize,
              onStart: _startResize,
              onResize: _resize,
              onEnd: _finishResize,
              onReset: _resetSize,
              child: SkedFloatingSurface(
                key: const ValueKey('floating-form-surface'),
                child: SkedTaskDialogScope(
                  explicitHeight: height != null,
                  onDragUpdate: widget.options.draggable ? _drag : null,
                  onClose: () => Navigator.of(context).maybePop(),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FloatingDialogPosition extends SingleChildLayoutDelegate {
  const _FloatingDialogPosition({
    required this.bounds,
    required this.anchorBounds,
    required this.anchor,
    required this.manualPosition,
    required this.width,
    this.height,
    required this.rtl,
    required this.placement,
    required this.onLayout,
  });
  final Rect bounds;
  final Rect anchorBounds;
  final Rect? anchor;
  final Offset? manualPosition;
  final double width;
  final double? height;
  final bool rtl;
  final SkedFloatingPlacement placement;
  final void Function(Offset, Size) onLayout;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: height ?? 0,
        maxHeight:
            height ??
            skedFloatingHeightLimit(
              bounds,
              anchor,
              width,
              anchorBounds: anchorBounds,
            ),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final position = manualPosition == null
        ? positionSkedFloatingPanel(
            bounds: bounds,
            size: childSize,
            anchor: anchor,
            anchorBounds: anchorBounds,
            rtl: rtl,
            placement: placement,
          )
        : boundSkedFloatingPosition(manualPosition!, childSize, bounds);
    onLayout(position, childSize);
    return position;
  }

  @override
  bool shouldRelayout(_FloatingDialogPosition oldDelegate) => true;
}
