import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Measures the start/end groups together, below a trailing all-day switch.
/// Both groups fit side by side only when their labels and date/time controls
/// fit at their natural widths. The child list never changes when wrapping;
/// labels, values and focus nodes stay in the same element slots.
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
    this.minimumGroupWidth = 240,
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

  /// Minimum width of each group, including the caller's text scale.
  final double minimumGroupWidth;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _TimeRowsRender(showTime, textDirection, minimumGroupWidth);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    final rows = renderObject as _TimeRowsRender;
    if (rows.showTime == showTime &&
        rows.direction == textDirection &&
        rows.minimumGroupWidth == minimumGroupWidth) {
      return;
    }
    rows.showTime = showTime;
    rows.direction = textDirection;
    rows.minimumGroupWidth = minimumGroupWidth;
    rows.markNeedsLayout();
  }
}

class _TimeRowData extends ContainerBoxParentData<RenderBox> {}

class _TimeRowsRender extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TimeRowData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TimeRowData> {
  _TimeRowsRender(this.showTime, this.direction, this.minimumGroupWidth);
  bool showTime;
  TextDirection direction;
  double minimumGroupWidth;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TimeRowData) child.parentData = _TimeRowData();
  }

  Size _layout(BoxConstraints bounds, {required bool dry}) {
    final children = getChildrenAsList();
    final width = bounds.maxWidth;
    const gap = 12.0;
    const labelGap = 6.0;
    double intrinsic(int i) =>
        math.max(0, children[i].getMaxIntrinsicWidth(double.infinity));
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
    place(3, width - toggle.width, 0, toggle);
    final valuesMin = dateMin + (showTime ? gap + timeMin : 0);
    final groupMin = math.max(
      minimumGroupWidth,
      math.max(valuesMin, math.max(intrinsic(0), intrinsic(4))),
    );
    final paired = groupMin * 2 + gap <= width;
    final groupWidth = paired ? (width - gap) / 2 : width;
    final stackValues = showTime && groupWidth < valuesMin;
    final extra = math.max(0.0, groupWidth - valuesMin);
    final dateWidth = !showTime || stackValues
        ? groupWidth
        : dateMin + extra * .55;
    final timeWidth = showTime
        ? (stackValues ? groupWidth : groupWidth - dateWidth - gap)
        : groupWidth;
    final startLabel = measure(0, groupWidth);
    final endLabel = measure(4, groupWidth);
    final pairedLabelHeight = math.max(startLabel.height, endLabel.height);
    final groupsY = toggle.height + gap;
    double y = groupsY;
    double startBottom = groupsY;
    for (final start in [true, false]) {
      final base = start ? 0 : 4;
      final x = !start && paired ? groupWidth + gap : 0.0;
      final labelSize = start ? startLabel : endLabel;
      place(base, x, y, labelSize);
      final valuesY =
          y + (paired ? pairedLabelHeight : labelSize.height) + labelGap;
      final date = measure(base + 1, dateWidth);
      // Hidden time controls keep useful constraints as well as their element
      // slots; a zero-width layout would overflow their retained child rows.
      final time = measure(base + 2, timeWidth);
      final rowHeight = math.max(
        date.height,
        showTime && !stackValues ? time.height : 0.0,
      );
      place(base + 1, x, valuesY + (rowHeight - date.height) / 2, date);
      place(
        base + 2,
        stackValues || !showTime ? x : x + dateWidth + gap,
        stackValues
            ? valuesY + rowHeight + gap
            : valuesY + (rowHeight - time.height) / 2,
        time,
      );
      final bottom =
          valuesY + rowHeight + (stackValues ? gap + time.height : 0);
      if (start) {
        startBottom = bottom;
        y = paired ? groupsY : bottom + gap;
      } else {
        final error = measure(7, groupWidth);
        final errorY = bottom + (error.height > 0 ? labelGap : 0);
        place(7, x, errorY, error);
        y = math.max(startBottom, errorY + error.height);
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
