import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// A compact interval: aligned start/end rows with naturally sized controls.
/// All-day shares the start row, or its label when space requires upper labels.
/// Reflow only changes constraints and offsets, never the eight child slots.
class WorkspaceEditorTimeRows extends MultiChildRenderObjectWidget {
  WorkspaceEditorTimeRows({
    super.key,
    required Widget startLabel,
    required Widget startDate,
    required Widget startTime,
    required Widget allDay,
    required Widget endLabel,
    required Widget endDate,
    required Widget endTime,
    Widget? error,
    required this.showTime,
    required this.textDirection,
    this.minimumDateWidth = 136,
    this.minimumTimeWidth = 104,
  }) : super(
         children: [
           startLabel,
           startDate,
           Offstage(offstage: !showTime, child: startTime),
           allDay,
           endLabel,
           endDate,
           Offstage(offstage: !showTime, child: endTime),
           error ?? const SizedBox.shrink(),
         ],
       );
  final bool showTime;
  final TextDirection textDirection;

  /// Useful control widths, including the caller's text scale.
  final double minimumDateWidth, minimumTimeWidth;
  @override
  RenderObject createRenderObject(BuildContext context) => _TimeRowsRender(
    showTime,
    textDirection,
    minimumDateWidth,
    minimumTimeWidth,
  );
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final rows = renderObject as _TimeRowsRender;
    if (rows.showTime == showTime &&
        rows.direction == textDirection &&
        rows.minimumDateWidth == minimumDateWidth &&
        rows.minimumTimeWidth == minimumTimeWidth) {
      return;
    }
    rows.showTime = showTime;
    rows.direction = textDirection;
    rows.minimumDateWidth = minimumDateWidth;
    rows.minimumTimeWidth = minimumTimeWidth;
    rows.markNeedsLayout();
  }
}

class _TimeRowData extends ContainerBoxParentData<RenderBox> {}

class _TimeRowsRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TimeRowData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TimeRowData> {
  _TimeRowsRender(
    this.showTime,
    this.direction,
    this.minimumDateWidth,
    this.minimumTimeWidth,
  );
  bool showTime;
  TextDirection direction;
  double minimumDateWidth, minimumTimeWidth;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TimeRowData) child.parentData = _TimeRowData();
  }

  Size _layout(BoxConstraints bounds, {required bool dry}) {
    final children = getChildrenAsList();
    final width = bounds.maxWidth;
    const rowGap = 12.0;
    const controlGap = 8.0;
    const labelGap = 6.0;
    double intrinsic(int i) =>
        math.max(0, children[i].getMaxIntrinsicWidth(double.infinity));
    final dateMinimum = math.max(
      minimumDateWidth,
      math.max(intrinsic(1), intrinsic(5)),
    );
    final timeMinimum = math.max(
      minimumTimeWidth,
      math.max(intrinsic(2), intrinsic(6)),
    );
    Size measure(int i, double available, {bool tight = true}) {
      final c = BoxConstraints(
        minWidth: tight ? math.max(0, available) : 0,
        maxWidth: math.max(0, available),
      );
      if (dry) return children[i].getDryLayout(c);
      children[i].layout(c, parentUsesSize: true);
      return children[i].size;
    }

    void place(int i, double x, double y, Size size) {
      if (!dry) {
        (children[i].parentData! as _TimeRowData).offset = Offset(
          direction == TextDirection.rtl ? width - x - size.width : x,
          y,
        );
      }
    }

    // Even at narrow widths, leave label space beside the toggle. Its text can
    // wrap there instead of creating a line containing only the switch.
    final toggle = measure(
      3,
      math.max(0, width - math.min(48, width * .25) - controlGap),
      tight: false,
    );
    final labelsMinimum = math.max(intrinsic(0), intrinsic(4));
    final valuesMinimum =
        dateMinimum + (showTime ? controlGap + timeMinimum : 0);
    final inline =
        labelsMinimum + controlGap + valuesMinimum + rowGap + toggle.width <=
        width;
    final dateWidth = math.min(dateMinimum, width);
    final timeWidth = math.min(timeMinimum, width);
    final stackValues = showTime && valuesMinimum > width;
    final controlsX = inline ? labelsMinimum + controlGap : 0.0;
    double y = 0;
    for (final start in [true, false]) {
      final base = start ? 0 : 4;
      final labelSize = measure(
        base,
        inline
            ? labelsMinimum
            : start
            ? width - toggle.width - controlGap
            : width,
      );
      final date = measure(base + 1, dateWidth);
      // Keep useful constraints even when Offstage hides the retained time.
      final time = measure(base + 2, timeWidth);
      var rowHeight = math.max(
        date.height,
        showTime && !stackValues ? time.height : 0.0,
      );
      double valuesY = y;
      if (inline) {
        rowHeight = math.max(rowHeight, labelSize.height);
        if (start) rowHeight = math.max(rowHeight, toggle.height);
        place(base, 0, y + (rowHeight - labelSize.height) / 2, labelSize);
        if (start) {
          place(
            3,
            controlsX + valuesMinimum + rowGap,
            y + (rowHeight - toggle.height) / 2,
            toggle,
          );
        }
      } else {
        final headerHeight = start
            ? math.max(labelSize.height, toggle.height)
            : labelSize.height;
        place(base, 0, y + (headerHeight - labelSize.height) / 2, labelSize);
        if (start) {
          place(
            3,
            width - toggle.width,
            y + (headerHeight - toggle.height) / 2,
            toggle,
          );
        }
        valuesY += headerHeight + labelGap;
      }
      place(base + 1, controlsX, valuesY + (rowHeight - date.height) / 2, date);
      place(
        base + 2,
        stackValues || !showTime
            ? controlsX
            : controlsX + dateWidth + controlGap,
        stackValues
            ? valuesY + rowHeight + controlGap
            : valuesY + (rowHeight - time.height) / 2,
        time,
      );
      y = valuesY + rowHeight + (stackValues ? controlGap + time.height : 0);
      if (start) {
        y += rowGap;
      } else {
        final error = measure(7, width - controlsX);
        if (error.height > 0) y += labelGap;
        place(7, controlsX, y, error);
        y += error.height;
      }
    }
    return bounds.constrain(Size(width, y));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);
  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
