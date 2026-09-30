import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_floating_surface.dart';
import 'sked_task_dialog.dart';
import 'workbench_chrome_metrics.dart';

/// Opt-in desktop presentation; ordinary dialogs and touch platforms ignore it.
class SkedDesktopFloatingDialog {
  const SkedDesktopFloatingDialog({
    this.anchorContext,
    this.preferredWidth = 360,
    this.maxWidth = 440,
    this.draggable = true,
  });
  final BuildContext? anchorContext;
  final double preferredWidth, maxWidth;
  final bool draggable;
}

class _FloatingDismissIntent extends Intent {
  const _FloatingDismissIntent();
}

class SkedFloatingDialogHost extends StatefulWidget {
  const SkedFloatingDialogHost({
    super.key,
    required this.options,
    required this.child,
  });
  final SkedDesktopFloatingDialog options;
  final Widget child;
  @override
  State<SkedFloatingDialogHost> createState() => _SkedFloatingDialogHostState();
}

class _SkedFloatingDialogHostState extends State<SkedFloatingDialogHost> {
  final _layoutKey = GlobalKey();
  Offset? _manualPosition;
  Offset _visiblePosition = Offset.zero;
  Size _childSize = Size.zero;
  Rect _bounds = Rect.zero;

  void _drag(Offset delta) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      final current = boundSkedFloatingPosition(
        _manualPosition ?? _visiblePosition,
        _childSize,
        _bounds,
      );
      _manualPosition = boundSkedFloatingPosition(
        current + delta,
        _childSize,
        _bounds,
      );
    });
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
      Rect? anchor;
      final anchorBox = widget.options.anchorContext?.mounted == true
          ? widget.options.anchorContext!.findRenderObject()
          : null;
      final layoutBox = _layoutKey.currentContext?.findRenderObject();
      if (anchorBox is RenderBox && anchorBox.attached && anchorBox.hasSize) {
        final origin = layoutBox is RenderBox && layoutBox.attached
            ? layoutBox.localToGlobal(Offset.zero)
            : Offset.zero;
        anchor =
            (anchorBox.localToGlobal(Offset.zero) - origin) & anchorBox.size;
      }
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
            key: _layoutKey,
            delegate: _FloatingDialogPosition(
              bounds: _bounds,
              anchor: anchor,
              manualPosition: _manualPosition,
              width: math.min(
                _bounds.width,
                math.min(
                  widget.options.maxWidth,
                  widget.options.preferredWidth * metrics.textScale,
                ),
              ),
              rtl: Directionality.of(context) == TextDirection.rtl,
              onLayout: (position, size) {
                _visiblePosition = position;
                _childSize = size;
              },
            ),
            child: SkedFloatingSurface(
              key: const ValueKey('floating-form-surface'),
              child: SkedTaskDialogScope(
                onDragUpdate: widget.options.draggable ? _drag : null,
                onClose: () => Navigator.of(context).maybePop(),
                child: widget.child,
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
    required this.anchor,
    required this.manualPosition,
    required this.width,
    required this.rtl,
    required this.onLayout,
  });
  final Rect bounds;
  final Rect? anchor;
  final Offset? manualPosition;
  final double width;
  final bool rtl;
  final void Function(Offset, Size) onLayout;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: bounds.height,
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final position = manualPosition == null
        ? positionSkedFloatingPanel(
            bounds: bounds,
            size: childSize,
            anchor: anchor,
            rtl: rtl,
          )
        : boundSkedFloatingPosition(manualPosition!, childSize, bounds);
    onLayout(position, childSize);
    return position;
  }

  @override
  bool shouldRelayout(_FloatingDialogPosition oldDelegate) => true;
}
