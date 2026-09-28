part of 'general_schedule_home_screen.dart';

/// Integer physical-pixel tracks shared by layout, hit regions and painting.
/// Rounding cumulative positions distributes the remainder across the grid.
class _DesktopMonthTracks {
  _DesktopMonthTracks({
    required this.count,
    required int contentPixels,
    required this.dpr,
    this.leadingLine = false,
    this.trailingLine = false,
  }) : contentPixels = math.max(count, contentPixels);

  final int count, contentPixels;
  final double dpr;
  final bool leadingLine, trailingLine;
  int get pixels =>
      contentPixels +
      count -
      1 +
      (leadingLine ? 1 : 0) +
      (trailingLine ? 1 : 0);
  double get extent => pixels / dpr;
  double get minimumCellExtent => (contentPixels ~/ count) / dpr;
  int _contentEdge(int index) => (contentPixels * index / count).round();
  double start(int index) =>
      ((leadingLine ? 1 : 0) + index + _contentEdge(index)) / dpr;
  double end(int index) =>
      ((leadingLine ? 1 : 0) + index + _contentEdge(index + 1)) / dpr;
  Iterable<double> get lines sync* {
    if (leadingLine) yield 0;
    for (var index = 0; index < count - 1; index++) {
      yield end(index);
    }
    if (trailingLine) yield end(count - 1);
  }

  factory _DesktopMonthTracks.forWidth(
    double width,
    int count,
    double dpr, {
    required bool leadingLine,
    required bool trailingLine,
  }) => _DesktopMonthTracks(
    count: count,
    contentPixels:
        (width * dpr + .000001).floor() -
        count +
        1 -
        (leadingLine ? 1 : 0) -
        (trailingLine ? 1 : 0),
    dpr: dpr,
    leadingLine: leadingLine,
    trailingLine: trailingLine,
  );
}

/// Snap the whole set of integer tracks, not each widget independently. The
/// translation is recomputed at paint/hit-test time, so scrolling and the month
/// slide animation cannot move the grid back onto fractional physical pixels.
class _DesktopMonthPixelSnap extends SingleChildRenderObjectWidget {
  const _DesktopMonthPixelSnap({required this.dpr, required super.child});
  final double dpr;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderDesktopMonthPixelSnap(dpr);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDesktopMonthPixelSnap renderObject,
  ) {
    renderObject.dpr = dpr;
  }
}

class _RenderDesktopMonthPixelSnap extends RenderProxyBox {
  _RenderDesktopMonthPixelSnap(this._dpr);
  double _dpr;
  set dpr(double value) {
    if (value == _dpr) return;
    _dpr = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Offset get _delta {
    final origin = localToGlobal(Offset.zero);
    return Offset(
      (origin.dx * _dpr).round() / _dpr - origin.dx,
      (origin.dy * _dpr).round() / _dpr - origin.dy,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      super.paint(context, offset + _delta);
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final delta = _delta;
    transform.translateByDouble(delta.dx, delta.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: _delta,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );
}

class _DesktopMonthGridPainter extends CustomPainter {
  const _DesktopMonthGridPainter({
    required this.columns,
    required this.rows,
    required this.color,
  });
  final _DesktopMonthTracks columns, rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pixel = 1 / columns.dpr;
    final lines = Path();
    for (final x in columns.lines) {
      lines.addRect(Rect.fromLTWH(x, 0, pixel, rows.extent));
    }
    for (final y in rows.lines) {
      lines.addRect(Rect.fromLTWH(0, y, columns.extent, pixel));
    }
    // One fill pass also prevents translucent custom colors from accumulating
    // at intersections. There are no independently stroked cell borders.
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    canvas.drawPath(lines, paint);
  }

  @override
  bool shouldRepaint(_DesktopMonthGridPainter oldDelegate) =>
      columns != oldDelegate.columns ||
      rows != oldDelegate.rows ||
      color != oldDelegate.color;
}

class _DesktopMonthPageLayout {
  _DesktopMonthPageLayout({required this.rows, required this.metrics});
  final _DesktopMonthTracks rows;
  final _DesktopMonthCellMetrics metrics;

  factory _DesktopMonthPageLayout.resolve(
    BuildContext context, {
    required _DesktopMonthTracks columns,
    required _MonthGridModel model,
    required TimetableProvider provider,
    required double availableHeight,
  }) {
    final metrics = _DesktopMonthCellMetrics.forGrid(
      context,
      cellWidth: columns.minimumCellExtent,
      days: model.days,
      lunar: _showMonthLunar(provider),
      locale: provider.localeCode,
    );
    final minimum =
        (metrics.minimumHeight * columns.dpr).ceil() * model.rowCount;
    final naturalHeight =
        (columns.minimumCellExtent * columns.dpr).round() * model.rowCount;
    final available = availableHeight.isFinite
        ? math.max(0, (availableHeight * columns.dpr).floor() - model.rowCount)
        : naturalHeight;
    return _DesktopMonthPageLayout(
      rows: _DesktopMonthTracks(
        count: model.rowCount,
        dpr: columns.dpr,
        contentPixels: math.max(minimum, available),
        trailingLine: true,
      ),
      metrics: metrics,
    );
  }
}

class _DesktopMonthCalendarPanel extends StatelessWidget {
  const _DesktopMonthCalendarPanel({
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.provider,
    required this.previousPage,
    required this.nextPage,
    required this.dragOffset,
    required this.sharedTopEdge,
    required this.sharedStartEdge,
    required this.sharedEndEdge,
    required this.onDaySelected,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });
  final _MonthGridModel model;
  final DateTime selectedDate, today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final TimetableProvider provider;
  final _MonthGridPageData previousPage, nextPage;
  final double dragOffset;
  final bool sharedTopEdge, sharedStartEdge, sharedEndEdge;
  final ValueChanged<DateTime> onDaySelected;
  final GestureDragStartCallback onDragStart;
  final void Function(DragUpdateDetails, double) onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dpr = View.of(context).devicePixelRatio;
      final colors = Theme.of(context).colorScheme;
      final minCellPixels =
          (_DesktopMonthCellMetrics.minimumWidth(context) * dpr).ceil();
      final minWidth =
          (minCellPixels * model.columnCount +
              model.columnCount -
              1 +
              (sharedStartEdge ? 0 : 1) +
              (sharedEndEdge ? 0 : 1)) /
          dpr;
      final columns = _DesktopMonthTracks.forWidth(
        math.max(constraints.maxWidth, minWidth),
        model.columnCount,
        dpr,
        leadingLine: !sharedStartEdge,
        trailingLine: !sharedEndEdge,
      );
      final horizontalOverflow =
          columns.extent > constraints.maxWidth + .5 / dpr;
      final labelStyle =
          (Theme.of(context).textTheme.labelMedium ??
                  const TextStyle(fontSize: 12))
              .copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              );
      final headerRows = _DesktopMonthTracks(
        count: 1,
        dpr: dpr,
        contentPixels:
            (math.max(40, _monthTextHeight(context, 'Ag星期', labelStyle) + 16) *
                    dpr)
                .ceil(),
        leadingLine: !sharedTopEdge,
        trailingLine: true,
      );
      final availableBody = constraints.hasBoundedHeight
          ? math.max(0.0, constraints.maxHeight - headerRows.extent)
          : double.infinity;
      final current = _DesktopMonthPageLayout.resolve(
        context,
        columns: columns,
        model: model,
        provider: provider,
        availableHeight: availableBody,
      );
      final bodyHeight = math.min(current.rows.extent, availableBody);
      final headerHeight = constraints.hasBoundedHeight
          ? math.min(headerRows.extent, constraints.maxHeight)
          : headerRows.extent;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      Widget page(
        _MonthGridModel pageModel,
        DateTime date,
        Map<String, List<GeneralEventOccurrence>> occurrences,
        double position,
        bool visible,
      ) => Positioned.fill(
        child: Transform.translate(
          offset: Offset((position + dragOffset) * columns.extent, 0),
          child: IgnorePointer(
            ignoring: !visible,
            child: ExcludeSemantics(
              excluding: !visible,
              child: !visible
                  ? const SizedBox.shrink()
                  : _DesktopMonthDatePage(
                      key: ValueKey(
                        'general-month-date-grid-${date.year}-${date.month}',
                      ),
                      columns: columns,
                      layout: position == 0
                          ? current
                          : _DesktopMonthPageLayout.resolve(
                              context,
                              columns: columns,
                              model: pageModel,
                              provider: provider,
                              availableHeight: availableBody,
                            ),
                      model: pageModel,
                      selectedDate: date,
                      today: today,
                      occurrencesByDay: occurrences,
                      provider: provider,
                      rtl: rtl,
                      onDaySelected: onDaySelected,
                    ),
            ),
          ),
        ),
      );
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          height: headerHeight + bodyHeight,
          child: SingleChildScrollView(
            key: const ValueKey('desktop-month-horizontal-scroll'),
            scrollDirection: Axis.horizontal,
            physics: horizontalOverflow
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: _DesktopMonthPixelSnap(
              dpr: dpr,
              child: Material(
                key: const ValueKey('general-month-calendar-panel'),
                color: colors.surface,
                child: SizedBox(
                  width: columns.extent,
                  height: headerHeight + bodyHeight,
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: ClipRect(
                          child: _DesktopMonthPixelSnap(
                            dpr: dpr,
                            child: CustomPaint(
                              foregroundPainter: _DesktopMonthGridPainter(
                                columns: columns,
                                rows: headerRows,
                                color: colors.outlineVariant,
                              ),
                              child: SizedBox(
                                key: const ValueKey(
                                  'general-month-weekday-header',
                                ),
                                width: columns.extent,
                                height: headerRows.extent,
                                child: Stack(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < columns.count;
                                      index++
                                    )
                                      Positioned.fromRect(
                                        rect: Rect.fromLTRB(
                                          columns.start(
                                            rtl
                                                ? columns.count - index - 1
                                                : index,
                                          ),
                                          headerRows.start(0),
                                          columns.end(
                                            rtl
                                                ? columns.count - index - 1
                                                : index,
                                          ),
                                          headerRows.end(0),
                                        ),
                                        child: ColoredBox(
                                          key: ValueKey(
                                            'desktop-month-weekday-${model.days[index].weekday}',
                                          ),
                                          color: colors.surfaceContainerLow,
                                          child: Center(
                                            child: Text(
                                              _weekdayLabel(
                                                context,
                                                model.days[index],
                                              ),
                                              style: labelStyle,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: bodyHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: horizontalOverflow
                              ? null
                              : onDragStart,
                          onHorizontalDragUpdate: horizontalOverflow
                              ? null
                              : (details) =>
                                    onDragUpdate(details, columns.extent),
                          onHorizontalDragEnd: horizontalOverflow
                              ? null
                              : onDragEnd,
                          onHorizontalDragCancel: horizontalOverflow
                              ? null
                              : onDragCancel,
                          child: ClipRect(
                            child: Stack(
                              children: [
                                page(
                                  previousPage.model,
                                  previousPage.date,
                                  previousPage.occurrencesByDay,
                                  -1,
                                  dragOffset > 0,
                                ),
                                page(
                                  nextPage.model,
                                  nextPage.date,
                                  nextPage.occurrencesByDay,
                                  1,
                                  dragOffset < 0,
                                ),
                                page(
                                  model,
                                  selectedDate,
                                  occurrencesByDay,
                                  0,
                                  true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DesktopMonthDatePage extends StatelessWidget {
  const _DesktopMonthDatePage({
    super.key,
    required this.columns,
    required this.layout,
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.provider,
    required this.rtl,
    required this.onDaySelected,
  });
  final _DesktopMonthTracks columns;
  final _DesktopMonthPageLayout layout;
  final _MonthGridModel model;
  final DateTime selectedDate, today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final TimetableProvider provider;
  final bool rtl;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final rows = layout.rows;
    Rect cellRect(int index) {
      var column = index % columns.count;
      if (rtl) column = columns.count - column - 1;
      final row = index ~/ columns.count;
      return Rect.fromLTRB(
        columns.start(column),
        rows.start(row),
        columns.end(column),
        rows.end(row),
      );
    }

    final selected = model.days.indexWhere(
      (date) => _sameDay(date, selectedDate),
    );
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      key: const ValueKey('desktop-month-vertical-scroll'),
      child: _DesktopMonthPixelSnap(
        dpr: columns.dpr,
        child: CustomPaint(
          key: const ValueKey('desktop-month-grid-lines'),
          foregroundPainter: _DesktopMonthGridPainter(
            columns: columns,
            rows: rows,
            color: colors.outlineVariant,
          ),
          child: SizedBox(
            width: columns.extent,
            height: rows.extent,
            child: Stack(
              children: [
                for (var index = 0; index < model.days.length; index++)
                  Positioned.fromRect(
                    rect: cellRect(index),
                    child: _DesktopMonthDayCell(
                      key: ValueKey(
                        'general-month-day-cell-${model.days[index].year}-${model.days[index].month}-${model.days[index].day}',
                      ),
                      date: model.days[index],
                      month: selectedDate.month,
                      isToday: _sameDay(model.days[index], today),
                      isSelected: index == selected,
                      occurrences:
                          (occurrencesByDay[_calendarDateKey(
                                    model.days[index],
                                  )] ??
                                  const <GeneralEventOccurrence>[])
                              .sortedForAgenda(),
                      locale: provider.localeCode,
                      showLunar: _showMonthLunar(provider),
                      height: cellRect(index).height,
                      metrics: layout.metrics,
                      onTap: () => onDaySelected(model.days[index]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
