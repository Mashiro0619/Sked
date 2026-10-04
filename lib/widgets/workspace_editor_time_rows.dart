import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Measures both rows together so dates/times stay aligned and the all-day
/// switch uses the space it actually needs. The child list never changes when
/// wrapping; labels, values and focus nodes stay in the same element slots.
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
    required this.labelWidth,
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
  final double labelWidth;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _TimeRowsRender(showTime, textDirection, labelWidth);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final rows = renderObject as _TimeRowsRender;
    if (rows.showTime == showTime &&
        rows.direction == textDirection &&
        rows.labelWidth == labelWidth) {
      return;
    }
    rows.showTime = showTime;
    rows.direction = textDirection;
    rows.labelWidth = labelWidth;
    rows.markNeedsLayout();
  }
}

class _TimeRowData extends ContainerBoxParentData<RenderBox> {}

class _TimeRowsRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TimeRowData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TimeRowData> {
  _TimeRowsRender(this.showTime, this.direction, this.labelWidth);
  bool showTime;
  TextDirection direction;
  double labelWidth;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TimeRowData) child.parentData = _TimeRowData();
  }

  Size _layout(BoxConstraints bounds, {required bool dry}) {
    final children = getChildrenAsList();
    final width = bounds.maxWidth;
    const gap = 8.0;
    double intrinsic(int i) =>
        children[i].getMaxIntrinsicWidth(double.infinity).clamp(0, width);
    final label = math.min(labelWidth, math.max(intrinsic(0), intrinsic(4)));
    final dateMin = math.max(intrinsic(1), intrinsic(5));
    final timeMin = showTime ? math.max(intrinsic(2), intrinsic(6)) : 0.0;
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

    final toggle = measure(3, width, tight: false);
    final valuesMin = dateMin + (showTime ? gap + timeMin : 0);
    final inline = label + gap + valuesMin + gap + toggle.width <= width;
    final labelsInline = label + gap + valuesMin <= width;
    final controlsX = labelsInline ? label + gap : 0.0;
    final controlsWidth = width - controlsX - (inline ? toggle.width + gap : 0);
    final stackValues = showTime && controlsWidth < dateMin + gap + timeMin;
    final extra = math.max(0.0, controlsWidth - valuesMin);
    final dateWidth = !showTime || stackValues
        ? controlsWidth
        : dateMin + extra * .55;
    final timeWidth = showTime
        ? (stackValues ? controlsWidth : controlsWidth - dateWidth - gap)
        : 0.0;
    double y = 0;
    for (final start in [true, false]) {
      final base = start ? 0 : 4;
      final labelSize = measure(base, labelsInline ? label : width);
      if (!labelsInline) {
        place(base, 0, y, labelSize);
        y += labelSize.height + 4;
      }
      final date = measure(base + 1, dateWidth);
      final time = measure(base + 2, timeWidth);
      final rowHeight = math.max(
        labelsInline ? labelSize.height : 0.0,
        math.max(
          date.height,
          math.max(
            stackValues ? 0.0 : time.height,
            inline && start ? toggle.height : 0.0,
          ),
        ),
      );
      if (labelsInline) {
        place(base, 0, y + (rowHeight - labelSize.height) / 2, labelSize);
      }
      place(base + 1, controlsX, y + (rowHeight - date.height) / 2, date);
      place(
        base + 2,
        stackValues ? controlsX : controlsX + dateWidth + (showTime ? gap : 0),
        stackValues ? y + rowHeight + gap : y + (rowHeight - time.height) / 2,
        time,
      );
      if (start && inline) {
        place(
          3,
          width - toggle.width,
          y + (rowHeight - toggle.height) / 2,
          toggle,
        );
      }
      y += rowHeight + (stackValues ? gap + time.height : 0);
      if (start && !inline) {
        y += 4;
        place(3, width - toggle.width, y, toggle);
        y += toggle.height;
      }
      if (start) y += gap;
    }
    final error = measure(7, width - controlsX);
    if (error.height > 0) y += 4;
    place(7, controlsX, y, error);
    y += error.height;
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
