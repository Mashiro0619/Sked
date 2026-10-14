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
    required GeneralMonthGridModel model,
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

typedef _DesktopMonthTextInputs = ({
  ThemeData theme,
  TextStyle defaultStyle,
  TextScaler textScaler,
  TextDirection direction,
  Locale? locale,
  String calendarLocale,
  bool lunar,
});

typedef _DesktopMonthPageShape = (DateTime, DateTime, int, int);

class _DesktopMonthPanelGeometry {
  const _DesktopMonthPanelGeometry({
    required this.columns,
    required this.headerRows,
    required this.labelStyle,
    required this.availableBody,
    required this.headerHeight,
    required this.horizontalOverflow,
  });

  final _DesktopMonthTracks columns, headerRows;
  final TextStyle labelStyle;
  final double availableBody, headerHeight;
  final bool horizontalOverflow;

  factory _DesktopMonthPanelGeometry.resolve(
    BuildContext context, {
    required BoxConstraints constraints,
    required double dpr,
    required int columnCount,
    required bool sharedTopEdge,
    required bool sharedStartEdge,
    required bool sharedEndEdge,
  }) {
    final theme = Theme.of(context);
    final minCellPixels = (_DesktopMonthCellMetrics.minimumWidth(context) * dpr)
        .ceil();
    final minWidth =
        (minCellPixels * columnCount +
            columnCount -
            1 +
            (sharedStartEdge ? 0 : 1) +
            (sharedEndEdge ? 0 : 1)) /
        dpr;
    final columns = _DesktopMonthTracks.forWidth(
      math.max(constraints.maxWidth, minWidth),
      columnCount,
      dpr,
      leadingLine: !sharedStartEdge,
      trailingLine: !sharedEndEdge,
    );
    final labelStyle =
        (theme.textTheme.labelMedium ?? const TextStyle(fontSize: 12)).copyWith(
          color: theme.colorScheme.onSurfaceVariant,
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
    return _DesktopMonthPanelGeometry(
      columns: columns,
      headerRows: headerRows,
      labelStyle: labelStyle,
      availableBody: constraints.hasBoundedHeight
          ? math.max(0.0, constraints.maxHeight - headerRows.extent)
          : double.infinity,
      headerHeight: constraints.hasBoundedHeight
          ? math.min(headerRows.extent, constraints.maxHeight)
          : headerRows.extent,
      horizontalOverflow: columns.extent > constraints.maxWidth + .5 / dpr,
    );
  }
}

class _DesktopMonthCalendarPanel extends StatefulWidget {
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
  final GeneralMonthGridModel model;
  final DateTime selectedDate, today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final TimetableProvider provider;
  final GeneralMonthPage previousPage, nextPage;
  final ValueListenable<double> dragOffset;
  final bool sharedTopEdge, sharedStartEdge, sharedEndEdge;
  final ValueChanged<DateTime> onDaySelected;
  final GestureDragStartCallback onDragStart;
  final void Function(DragUpdateDetails, double) onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  State<_DesktopMonthCalendarPanel> createState() =>
      _DesktopMonthCalendarPanelState();
}

class _DesktopMonthCalendarPanelState
    extends State<_DesktopMonthCalendarPanel> {
  (BoxConstraints, double, _DesktopMonthTextInputs, int, bool, bool, bool)?
  _geometryInputs;
  _DesktopMonthPanelGeometry? _geometry;
  final _pageLayouts =
      <
        (_DesktopMonthPageShape, _DesktopMonthTextInputs),
        _DesktopMonthPageLayout
      >{};

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.dispose();
  }

  void _fontsChanged() => setState(() {
    _geometryInputs = null;
    _pageLayouts.clear();
  });

  _DesktopMonthTextInputs _textInputs(BuildContext context) => (
    theme: Theme.of(context),
    defaultStyle: DefaultTextStyle.of(context).style,
    textScaler: MediaQuery.textScalerOf(context),
    direction: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    calendarLocale: widget.provider.localeCode,
    lunar: _showMonthLunar(widget.provider),
  );

  _DesktopMonthPageShape _pageShape(GeneralMonthGridModel model) => (
    model.queryStart,
    model.queryEndExclusive,
    model.columnCount,
    model.rowCount,
  );

  _DesktopMonthPanelGeometry _geometryFor(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    // Subscribe to per-monitor DPI changes even when logical constraints stay
    // unchanged; reading the mutable FlutterView alone does not rebuild us.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final inputs = (
      constraints,
      dpr,
      _textInputs(context),
      widget.model.columnCount,
      widget.sharedTopEdge,
      widget.sharedStartEdge,
      widget.sharedEndEdge,
    );
    if (_geometryInputs != inputs) {
      _geometryInputs = inputs;
      _pageLayouts.clear();
      _geometry = _DesktopMonthPanelGeometry.resolve(
        context,
        constraints: constraints,
        dpr: dpr,
        columnCount: widget.model.columnCount,
        sharedTopEdge: widget.sharedTopEdge,
        sharedStartEdge: widget.sharedStartEdge,
        sharedEndEdge: widget.sharedEndEdge,
      );
    }
    return _geometry!;
  }

  _DesktopMonthPageLayout _pageLayoutFor(
    BuildContext context,
    GeneralMonthGridModel model,
    _DesktopMonthPanelGeometry geometry,
  ) => _pageLayouts.putIfAbsent(
    // A hidden page can inherit a different Material text style. Keep its
    // measured context in the key before promoting it to the current page.
    (_pageShape(model), _textInputs(context)),
    () => _DesktopMonthPageLayout.resolve(
      context,
      columns: geometry.columns,
      model: model,
      provider: widget.provider,
      availableHeight: geometry.availableBody,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final _DesktopMonthCalendarPanel(
      :model,
      :selectedDate,
      :today,
      :occurrencesByDay,
      :provider,
      :previousPage,
      :nextPage,
      :dragOffset,
      :onDaySelected,
      :onDragStart,
      :onDragUpdate,
      :onDragEnd,
      :onDragCancel,
    ) = widget;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _geometryFor(context, constraints);
        final _DesktopMonthPanelGeometry(
          :columns,
          :headerRows,
          :labelStyle,
          :availableBody,
          :headerHeight,
          :horizontalOverflow,
        ) = geometry;
        final retainedPages = {
          _pageShape(model),
          _pageShape(previousPage.model),
          _pageShape(nextPage.model),
        };
        _pageLayouts.removeWhere((key, _) => !retainedPages.contains(key.$1));
        final dpr = columns.dpr;
        final colors = Theme.of(context).colorScheme;
        final current = _pageLayoutFor(context, model, geometry);
        final bodyHeight = math.min(current.rows.extent, availableBody);
        final rtl = Directionality.of(context) == TextDirection.rtl;
        Widget page(
          GeneralMonthGridModel pageModel,
          DateTime date,
          Map<String, List<GeneralEventOccurrence>> occurrences,
          double position,
        ) => Positioned.fill(
          child: _MonthSlidePage(
            position: position,
            width: columns.extent,
            dragOffset: dragOffset,
            devicePixelRatio: dpr,
            child: Builder(
              builder: (context) => _DesktopMonthDatePage(
                key: ValueKey(
                  'general-month-date-grid-${date.year}-${date.month}',
                ),
                columns: columns,
                layout: position == 0
                    ? current
                    : _pageLayoutFor(context, pageModel, geometry),
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
                                  ),
                                  page(
                                    nextPage.model,
                                    nextPage.date,
                                    nextPage.occurrencesByDay,
                                    1,
                                  ),
                                  page(
                                    model,
                                    selectedDate,
                                    occurrencesByDay,
                                    0,
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
  final GeneralMonthGridModel model;
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
                          occurrencesByDay[_calendarDateKey(
                            model.days[index],
                          )] ??
                          const <GeneralEventOccurrence>[],
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
