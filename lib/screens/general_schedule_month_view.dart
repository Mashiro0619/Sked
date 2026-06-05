part of 'general_schedule_home_screen.dart';

const _monthCalendarPanelMaxWidth = 940.0;
const _monthCalendarPanelMaxHeight = 600.0;
const _monthCalendarPanelFillHeightThreshold = 560.0;
const _monthGridSpacing = 1.0;
const _generalMonthCompactSelectedDayFeedbackKey = ValueKey<String>(
  'general-month-compact-selected-day-feedback',
);

double _monthCellHeightForWidth(double cellWidth, {required bool compact}) {
  final preferred = cellWidth * (compact ? 0.58 : 0.62);
  final minHeight = compact ? 48.0 : 64.0;
  final maxHeight = compact ? 64.0 : 82.0;
  return preferred.clamp(minHeight, maxHeight).toDouble();
}

class _MonthCalendarView extends StatefulWidget {
  const _MonthCalendarView({
    required this.date,
    required this.provider,
    required this.filter,
    required this.onDaySelected,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  State<_MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends State<_MonthCalendarView> {
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  DateTime _visibleDayForDate(DateTime date) {
    final normalized = normalizeDateOnly(date);
    if (widget.provider.generalShowWeekends ||
        normalized.weekday <= DateTime.friday) {
      return normalized;
    }
    return normalized.add(Duration(days: 8 - normalized.weekday));
  }

  void _selectDay(DateTime nextDate) {
    widget.onDaySelected(_visibleDayForDate(nextDate));
  }

  DateTime _monthWithDay(DateTime baseDate, int year, int month) {
    final target = DateTime(
      year,
      month,
      baseDate.day.clamp(1, _daysInMonth(year, month)),
    );
    return _visibleDayForDate(target);
  }

  void _goToPreviousMonth() {
    final selectedDate = _visibleDayForDate(widget.date);
    final prevMonth = widget.date.month == 1 ? 12 : widget.date.month - 1;
    final prevYear = widget.date.month == 1
        ? widget.date.year - 1
        : widget.date.year;
    _selectDay(_monthWithDay(selectedDate, prevYear, prevMonth));
  }

  void _goToNextMonth() {
    final selectedDate = _visibleDayForDate(widget.date);
    final nextMonth = widget.date.month == 12 ? 1 : widget.date.month + 1;
    final nextYear = widget.date.month == 12
        ? widget.date.year + 1
        : widget.date.year;
    _selectDay(_monthWithDay(selectedDate, nextYear, nextMonth));
  }

  @override
  Widget build(BuildContext context) {
    final today = normalizeDateOnly(DateTime.now());
    final requestedDate = normalizeDateOnly(widget.date);
    final selectedDate = _visibleDayForDate(requestedDate);
    if (!_sameDay(selectedDate, requestedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDaySelected(selectedDate);
      });
    }
    final model = _MonthGridModel.build(
      monthDate: selectedDate,
      showWeekends: widget.provider.generalShowWeekends,
    );
    final occurrences = widget.provider.generalOccurrencesForQuery(
      widget.filter.toQuery(
        startInclusive: model.queryStart,
        endExclusive: model.queryEndExclusive,
      ),
    );
    final occurrencesByDay = _groupOccurrencesByDay(occurrences, model.days);
    final selectedOccurrences =
        (occurrencesByDay[_dateKey(selectedDate)] ?? const [])
            .sortedForAgenda();

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 760;
        final calendar = _MonthCalendarPanel(
          model: model,
          selectedDate: selectedDate,
          today: today,
          occurrencesByDay: occurrencesByDay,
          provider: widget.provider,
          filter: widget.filter,
          onPreviousMonth: _goToPreviousMonth,
          onNextMonth: _goToNextMonth,
          onToday: () => _selectDay(today),
          onDaySelected: _selectDay,
        );
        final agenda = _MonthAgendaPanel(
          date: selectedDate,
          occurrences: selectedOccurrences,
          filtered: widget.filter.isActive,
          onAddEvent: () => widget.onEmptySlotTap(selectedDate),
          onOccurrenceTap: widget.onOccurrenceTap,
        );

        if (sideBySide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _monthCalendarPanelMaxWidth,
                        maxHeight: _monthCalendarPanelMaxHeight,
                      ),
                      child: calendar,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 280,
                      maxWidth: 320,
                    ),
                    child: agenda,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 88),
          children: [
            calendar,
            const SizedBox(height: 10),
            SizedBox(height: 188, child: agenda),
          ],
        );
      },
    );
  }
}

class _MonthGridModel {
  const _MonthGridModel({
    required this.days,
    required this.columnCount,
    required this.rowCount,
    required this.queryStart,
    required this.queryEndExclusive,
  });

  final List<DateTime> days;
  final int columnCount;
  final int rowCount;
  final DateTime queryStart;
  final DateTime queryEndExclusive;

  static _MonthGridModel build({
    required DateTime monthDate,
    required bool showWeekends,
  }) {
    final firstOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final gridStart = showWeekends
        ? startOfWeekSunday(firstOfMonth)
        : startOfWeekMonday(firstOfMonth);
    final gridEnd =
        (showWeekends
                ? startOfWeekSunday(lastOfMonth)
                : startOfWeekMonday(lastOfMonth))
            .add(Duration(days: showWeekends ? 6 : 4));
    final days = <DateTime>[];
    for (
      var d = gridStart;
      !d.isAfter(gridEnd);
      d = d.add(const Duration(days: 1))
    ) {
      if (showWeekends || d.weekday <= DateTime.friday) {
        days.add(d);
      }
    }
    final columnCount = showWeekends ? 7 : 5;
    return _MonthGridModel(
      days: days,
      columnCount: columnCount,
      rowCount: days.length ~/ columnCount,
      queryStart: days.first,
      queryEndExclusive: days.last.add(const Duration(days: 1)),
    );
  }
}

class _MonthCalendarPanel extends StatefulWidget {
  const _MonthCalendarPanel({
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.provider,
    required this.filter,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onDaySelected,
  });

  final _MonthGridModel model;
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<_MonthCalendarPanel> createState() => _MonthCalendarPanelState();
}

class _MonthCalendarPanelState extends State<_MonthCalendarPanel>
    with SingleTickerProviderStateMixin {
  static const _pageAnimationDuration = Duration(milliseconds: 260);

  late final AnimationController _dragController;
  late Animation<double> _dragAnimation;
  late _MonthGridPageData _previousPage;
  late _MonthGridPageData _nextPage;
  double _dragOffset = 0;
  bool _isDragging = false;
  int _settleDirection = 0;

  @override
  void initState() {
    super.initState();
    _dragController =
        AnimationController(vsync: this, duration: _pageAnimationDuration)
          ..addListener(() {
            setState(() => _dragOffset = _dragAnimation.value);
          });
    _dragAnimation = AlwaysStoppedAnimation(_dragOffset);
    _refreshAdjacentPages();
  }

  @override
  void didUpdateWidget(covariant _MonthCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldRefreshAdjacentPages(oldWidget)) {
      _refreshAdjacentPages();
    }

    final monthChanged = !_sameMonth(
      widget.selectedDate,
      oldWidget.selectedDate,
    );
    if (!monthChanged) return;

    if (_settleDirection != 0) {
      _dragController.stop();
      _dragOffset = 0;
      _isDragging = false;
      _settleDirection = 0;
      return;
    }

    if (!_isDragging) {
      final direction = _compareMonth(
        widget.selectedDate,
        oldWidget.selectedDate,
      );
      _animateExternalMonthChange(direction);
    }
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  int _compareMonth(DateTime a, DateTime b) {
    final aMonth = a.year * 12 + a.month;
    final bMonth = b.year * 12 + b.month;
    if (aMonth == bMonth) return 0;
    return aMonth > bMonth ? 1 : -1;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  bool _sameModel(_MonthGridModel a, _MonthGridModel b) {
    return a.columnCount == b.columnCount &&
        a.rowCount == b.rowCount &&
        _sameDay(a.queryStart, b.queryStart) &&
        _sameDay(a.queryEndExclusive, b.queryEndExclusive);
  }

  bool _sameFilter(_GeneralOccurrenceFilter a, _GeneralOccurrenceFilter b) {
    return a.query == b.query && a.colorValue == b.colorValue;
  }

  bool _shouldRefreshAdjacentPages(_MonthCalendarPanel oldWidget) {
    return !identical(widget.provider, oldWidget.provider) ||
        !identical(widget.occurrencesByDay, oldWidget.occurrencesByDay) ||
        !_sameDay(widget.selectedDate, oldWidget.selectedDate) ||
        !_sameModel(widget.model, oldWidget.model) ||
        !_sameFilter(widget.filter, oldWidget.filter);
  }

  DateTime _visibleDayForDate(DateTime date) {
    final normalized = normalizeDateOnly(date);
    if (widget.provider.generalShowWeekends ||
        normalized.weekday <= DateTime.friday) {
      return normalized;
    }
    return normalized.add(Duration(days: 8 - normalized.weekday));
  }

  DateTime _adjacentMonthDate(int monthOffset) {
    final baseDate = widget.selectedDate;
    final monthStart = DateTime(baseDate.year, baseDate.month + monthOffset);
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    return _visibleDayForDate(
      DateTime(
        monthStart.year,
        monthStart.month,
        baseDate.day.clamp(1, daysInMonth),
      ),
    );
  }

  Map<String, List<GeneralEventOccurrence>> _occurrencesByDayForModel(
    _MonthGridModel model,
  ) {
    final occurrences = widget.provider.generalOccurrencesForQuery(
      widget.filter.toQuery(
        startInclusive: model.queryStart,
        endExclusive: model.queryEndExclusive,
      ),
    );
    return _groupOccurrencesByDay(occurrences, model.days);
  }

  _MonthGridPageData _pageDataForAdjacentMonth(int monthOffset) {
    final date = _adjacentMonthDate(monthOffset);
    final model = _MonthGridModel.build(
      monthDate: date,
      showWeekends: widget.provider.generalShowWeekends,
    );
    return _MonthGridPageData(
      date: date,
      model: model,
      occurrencesByDay: _occurrencesByDayForModel(model),
    );
  }

  void _refreshAdjacentPages() {
    _previousPage = _pageDataForAdjacentMonth(-1);
    _nextPage = _pageDataForAdjacentMonth(1);
  }

  void _animateToOffset(
    double target, {
    VoidCallback? onCompleted,
    Duration duration = _pageAnimationDuration,
  }) {
    _dragController.stop();
    _dragController.duration = duration;
    _dragAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _dragController, curve: Curves.easeOutCubic),
    );
    _dragController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      onCompleted?.call();
    });
  }

  void _animateExternalMonthChange(int direction) {
    if (direction == 0) {
      _dragOffset = 0;
      return;
    }
    _dragController.stop();
    _dragOffset = direction.toDouble();
    _animateToOffset(0, duration: const Duration(milliseconds: 240));
  }

  void _handleDragStart(DragStartDetails details) {
    _dragController.stop();
    setState(() {
      _isDragging = true;
      _settleDirection = 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    final delta = details.primaryDelta;
    if (delta == null || width <= 0) return;
    setState(() {
      _dragOffset = (_dragOffset + delta / width).clamp(-1.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const velocityThreshold = 520.0;
    const distanceThreshold = 0.22;
    final goNext =
        velocity < -velocityThreshold || _dragOffset < -distanceThreshold;
    final goPrevious =
        velocity > velocityThreshold || _dragOffset > distanceThreshold;

    if (goNext) {
      _settleDirection = 1;
      _animateToOffset(
        -1,
        onCompleted: () {
          if (!mounted) return;
          _isDragging = false;
          widget.onNextMonth();
        },
      );
    } else if (goPrevious) {
      _settleDirection = -1;
      _animateToOffset(
        1,
        onCompleted: () {
          if (!mounted) return;
          _isDragging = false;
          widget.onPreviousMonth();
        },
      );
    } else {
      _settleDirection = 0;
      _animateToOffset(
        0,
        onCompleted: () {
          if (!mounted) return;
          setState(() => _isDragging = false);
        },
      );
    }
  }

  void _handleDragCancel() {
    _settleDirection = 0;
    _animateToOffset(
      0,
      onCompleted: () {
        if (!mounted) return;
        setState(() => _isDragging = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final monthLabel = MaterialLocalizations.of(
      context,
    ).formatMonthYear(widget.selectedDate);
    final compact = MediaQuery.sizeOf(context).width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fillsHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final shouldFillHeight =
            fillsHeight &&
            constraints.maxHeight < _monthCalendarPanelFillHeightThreshold;
        final grid = _DraggableMonthGrid(
          model: widget.model,
          selectedDate: widget.selectedDate,
          today: widget.today,
          occurrencesByDay: widget.occurrencesByDay,
          provider: widget.provider,
          compact: compact,
          dragOffset: _dragOffset,
          previousPage: _previousPage,
          nextPage: _nextPage,
          onDaySelected: widget.onDaySelected,
          onDragStart: _handleDragStart,
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
          onDragCancel: _handleDragCancel,
        );

        return Material(
          key: const ValueKey('general-month-calendar-panel'),
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: shouldFillHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: l10n.previousMonth,
                      onPressed: widget.onPreviousMonth,
                    ),
                    Expanded(
                      child: Text(
                        monthLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (!_sameDay(
                      DateTime(
                        widget.selectedDate.year,
                        widget.selectedDate.month,
                      ),
                      DateTime(widget.today.year, widget.today.month),
                    ))
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: widget.onToday,
                        child: Text(l10n.today),
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: l10n.nextMonth,
                      onPressed: widget.onNextMonth,
                    ),
                  ],
                ),
              ),
              _MonthWeekdayHeaderRow(
                showWeekends: widget.provider.generalShowWeekends,
              ),
              if (shouldFillHeight)
                Flexible(fit: FlexFit.loose, child: grid)
              else
                grid,
            ],
          ),
        );
      },
    );
  }
}

class _MonthGridPageData {
  const _MonthGridPageData({
    required this.date,
    required this.model,
    required this.occurrencesByDay,
  });

  final DateTime date;
  final _MonthGridModel model;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
}

class _DraggableMonthGrid extends StatelessWidget {
  const _DraggableMonthGrid({
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.provider,
    required this.compact,
    required this.dragOffset,
    required this.previousPage,
    required this.nextPage,
    required this.onDaySelected,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final _MonthGridModel model;
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final TimetableProvider provider;
  final bool compact;
  final double dragOffset;
  final _MonthGridPageData previousPage;
  final _MonthGridPageData nextPage;
  final ValueChanged<DateTime> onDaySelected;
  final GestureDragStartCallback onDragStart;
  final void Function(DragUpdateDetails details, double width) onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  double _gridHeight(
    _MonthGridModel model,
    BoxConstraints constraints,
    double width,
  ) {
    final cellWidth = width / model.columnCount;
    final preferredCellHeight = _monthCellHeightForWidth(
      cellWidth,
      compact: compact,
    );
    final totalSpacing = (model.rowCount - 1) * _monthGridSpacing;
    final preferredGridHeight =
        model.rowCount * preferredCellHeight + totalSpacing;
    if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
      return math.min(preferredGridHeight, constraints.maxHeight);
    }
    return preferredGridHeight;
  }

  Widget _page({
    required double position,
    required double width,
    required double height,
    required DateTime date,
    required _MonthGridModel model,
    required Map<String, List<GeneralEventOccurrence>> occurrences,
    required bool active,
  }) {
    return Transform.translate(
      offset: Offset((position + dragOffset) * width, 0),
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          child: active
              ? SizedBox(
                  width: width,
                  height: height,
                  child: _MonthDateGrid(
                    model: model,
                    selectedDate: date,
                    today: today,
                    occurrencesByDay: occurrences,
                    provider: provider,
                    compact: compact,
                    onDaySelected: onDaySelected,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth);
        final height = _gridHeight(model, constraints, width);
        final showPreviousPage = dragOffset > 0;
        final showNextPage = dragOffset < 0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: onDragStart,
          onHorizontalDragUpdate: (details) => onDragUpdate(details, width),
          onHorizontalDragEnd: onDragEnd,
          onHorizontalDragCancel: onDragCancel,
          child: ClipRect(
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                children: [
                  _page(
                    position: -1,
                    width: width,
                    height: height,
                    date: previousPage.date,
                    model: previousPage.model,
                    occurrences: previousPage.occurrencesByDay,
                    active: showPreviousPage,
                  ),
                  _page(
                    position: 1,
                    width: width,
                    height: height,
                    date: nextPage.date,
                    model: nextPage.model,
                    occurrences: nextPage.occurrencesByDay,
                    active: showNextPage,
                  ),
                  _page(
                    position: 0,
                    width: width,
                    height: height,
                    date: selectedDate,
                    model: model,
                    occurrences: occurrencesByDay,
                    active: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthDateGrid extends StatelessWidget {
  const _MonthDateGrid({
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.provider,
    required this.compact,
    required this.onDaySelected,
  });

  final _MonthGridModel model;
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final TimetableProvider provider;
  final bool compact;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final cellWidth = constraints.maxWidth / model.columnCount;
        final preferredHeight = _monthCellHeightForWidth(
          cellWidth,
          compact: compact,
        );
        final totalSpacing = (model.rowCount - 1) * _monthGridSpacing;
        final preferredGridHeight =
            model.rowCount * preferredHeight + totalSpacing;
        final height = boundedHeight
            ? math.min(preferredGridHeight, constraints.maxHeight)
            : preferredGridHeight;
        final targetHeight = math.max(
          1.0,
          (height - totalSpacing) / model.rowCount,
        );
        final gridCompact = compact || targetHeight < 64;

        return SizedBox(
          height: height,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: model.columnCount,
              mainAxisSpacing: _monthGridSpacing,
              crossAxisSpacing: _monthGridSpacing,
              childAspectRatio: cellWidth / math.max(targetHeight, 1.0),
            ),
            itemCount: model.days.length,
            itemBuilder: (context, index) {
              final day = model.days[index];
              final dayOccurrences =
                  occurrencesByDay[_dateKey(day)] ?? const [];
              return LayoutBuilder(
                builder: (context, cellConstraints) {
                  final cellCompact =
                      gridCompact || cellConstraints.maxHeight < 64;
                  return _MonthDayCell(
                    date: day,
                    month: selectedDate.month,
                    isToday: _sameDay(day, today),
                    isSelected: _sameDay(day, selectedDate),
                    occurrences: dayOccurrences.sortedForAgenda(),
                    localeCode: provider.localeCode,
                    showLunarCalendar: provider.generalShowLunarCalendar,
                    cellWidth: cellWidth,
                    cellHeight: cellConstraints.maxHeight,
                    compact: cellCompact,
                    onTap: () => onDaySelected(day),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

Map<String, List<GeneralEventOccurrence>> _groupOccurrencesByDay(
  List<GeneralEventOccurrence> occurrences,
  List<DateTime> days,
) {
  final daySet = days.map(_dateKey).toSet();
  final result = <String, List<GeneralEventOccurrence>>{};
  for (final key in daySet) {
    result[key] = [];
  }
  for (final occurrence in occurrences) {
    for (final day in days) {
      if (_occurrenceIntersectsDay(occurrence, day)) {
        final key = _dateKey(day);
        result[key]?.add(occurrence);
      }
    }
  }
  return result;
}

class _MonthWeekdayHeaderRow extends StatelessWidget {
  const _MonthWeekdayHeaderRow({required this.showWeekends});

  final bool showWeekends;

  static final _referenceMonday = DateTime(2026, 1, 5);

  @override
  Widget build(BuildContext context) {
    final weekdays = showWeekends
        ? [
            DateTime.sunday,
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
          ]
        : [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ];
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: Row(
        children: [
          for (final weekday in weekdays)
            Expanded(
              child: Center(
                child: Text(
                  _weekdayLabel(
                    context,
                    _referenceMonday.add(
                      Duration(days: weekday - DateTime.monday),
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: labelStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.date,
    required this.month,
    required this.isToday,
    required this.isSelected,
    required this.occurrences,
    required this.localeCode,
    required this.showLunarCalendar,
    required this.cellWidth,
    required this.cellHeight,
    required this.compact,
    required this.onTap,
  });

  final DateTime date;
  final int month;
  final bool isToday;
  final bool isSelected;
  final List<GeneralEventOccurrence> occurrences;
  final String localeCode;
  final bool showLunarCalendar;
  final double cellWidth;
  final double cellHeight;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCurrentMonth = date.month == month;
    final baseColor = isCurrentMonth
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withAlpha(130);
    final hasEventMarker = occurrences.isNotEmpty;
    final dayFillColor = isToday ? colorScheme.primary : Colors.transparent;
    final standardTextColor = isToday ? colorScheme.onPrimary : baseColor;
    final standardBackgroundColor = !compact && isSelected
        ? colorScheme.primary.withValues(alpha: 0.10)
        : Colors.transparent;
    final standardBorderColor = !compact && isSelected
        ? colorScheme.primary
        : Colors.transparent;
    final compactTextColor = isSelected
        ? colorScheme.primary
        : isToday
        ? colorScheme.primary
        : baseColor;
    final compactTileSize = math.max(
      34.0,
      math.min(math.min(cellWidth, cellHeight) - 4, 56.0),
    );
    final compactButtonSize = hasEventMarker
        ? math.max(28.0, compactTileSize - 10)
        : compactTileSize;
    final compactDateStyle = theme.textTheme.titleLarge?.copyWith(
      height: 1.0,
      color: compactTextColor,
      fontWeight: FontWeight.w700,
      fontSize: math.max(15.0, math.min(22.0, compactButtonSize * 0.48)),
    );
    final compactLunarWidget = showLunarCalendar
        ? _LunarDateLabel(
            date: date,
            colorScheme: colorScheme,
            localeCode: localeCode,
            enabled: showLunarCalendar,
            overrideColor: compactTextColor,
          )
        : const SizedBox.shrink();
    final hasCompactEventMarker = hasEventMarker;
    final compactEventMarker = AnimatedOpacity(
      opacity: hasCompactEventMarker ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
    final standardEventMarker = AnimatedOpacity(
      opacity: hasEventMarker ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
    final standardDateContent = SizedBox(
      width: double.infinity,
      height: 46,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dayFillColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              date.day.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.0,
                color: standardTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            width: double.infinity,
            child: _LunarDateLabel(
              date: date,
              colorScheme: colorScheme,
              localeCode: localeCode,
              enabled: showLunarCalendar,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
    final standardDateStack = Center(
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            standardDateContent,
            if (hasEventMarker) const SizedBox(height: 4),
            if (hasEventMarker) standardEventMarker,
          ],
        ),
      ),
    );
    final compactButtonBackground = isSelected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    final compactDateContent = Center(
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: compactButtonSize,
              height: compactButtonSize,
              child: Material(
                key: isSelected
                    ? _generalMonthCompactSelectedDayFeedbackKey
                    : null,
                color: compactButtonBackground,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: compactDateStyle,
                        ),
                        if (showLunarCalendar) const SizedBox(height: 1),
                        if (showLunarCalendar) compactLunarWidget,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (hasCompactEventMarker) const SizedBox(height: 2),
            if (hasCompactEventMarker) compactEventMarker,
          ],
        ),
      ),
    );
    final semanticsLabel = occurrences.isNotEmpty
        ? AppLocalizations.of(
            context,
          ).monthDayEvents(date.day, occurrences.length)
        : '${date.day}';

    if (compact) {
      return Semantics(
        button: true,
        selected: isSelected,
        label: semanticsLabel,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: compactDateContent,
        ),
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: Material(
        color: standardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: standardBorderColor,
            width: isSelected ? 1.4 : 0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: standardDateStack,
          ),
        ),
      ),
    );
  }
}

class _MonthAgendaPanel extends StatelessWidget {
  const _MonthAgendaPanel({
    required this.date,
    required this.occurrences,
    required this.filtered,
    required this.onAddEvent,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final List<GeneralEventOccurrence> occurrences;
  final bool filtered;
  final VoidCallback onAddEvent;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_formatDate(date)}  ${_weekdayLabel(context, date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        occurrences.isEmpty
                            ? (filtered
                                  ? l10n.noMatchingEvents
                                  : l10n.noUpcomingEvents)
                            : l10n.monthDayEvents(date.day, occurrences.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.addEvent,
                  onPressed: onAddEvent,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: occurrences.isEmpty
                ? _MonthAgendaEmptyState(
                    filtered: filtered,
                    onAddEvent: onAddEvent,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    itemCount: occurrences.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final occurrence = occurrences[index];
                      return _MonthAgendaTile(
                        occurrence: occurrence,
                        onTap: () => onOccurrenceTap(occurrence),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MonthAgendaEmptyState extends StatelessWidget {
  const _MonthAgendaEmptyState({
    required this.filtered,
    required this.onAddEvent,
  });

  final bool filtered;
  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filtered
                    ? Icons.event_busy_outlined
                    : Icons.event_available_outlined,
                size: 28,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                filtered ? l10n.noMatchingEvents : l10n.noUpcomingEvents,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              if (!filtered) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onAddEvent,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addEvent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthAgendaTile extends StatelessWidget {
  const _MonthAgendaTile({required this.occurrence, required this.onTap});

  final GeneralEventOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = effectiveGeneralOccurrenceColor(context, occurrence);
    final subtitle = [
      _formatOccurrenceTime(context, occurrence),
      if (occurrence.event.location.isNotEmpty) occurrence.event.location,
      occurrence.calendar.name,
    ].join('  |  ');
    final repeatIcon = occurrence.event.recurrenceRule.isRepeating
        ? Icon(Icons.repeat, color: colors.primary, size: 18)
        : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      occurrence.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (repeatIcon != null) ...[const SizedBox(width: 6), repeatIcon],
            ],
          ),
        ),
      ),
    );
  }
}

class _LunarDateLabel extends StatelessWidget {
  const _LunarDateLabel({
    required this.date,
    required this.colorScheme,
    required this.localeCode,
    required this.enabled,
    this.overrideColor,
    this.fontSize = 9.5,
  });

  final DateTime date;
  final ColorScheme colorScheme;
  final String localeCode;
  final bool enabled;
  final Color? overrideColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (!enabled || (localeCode != 'zh' && localeCode != 'zh-Hant')) {
      return const SizedBox.shrink();
    }
    final lunar = Lunar.fromDate(date);
    final festivals = lunar.getFestivals();
    if (festivals.isNotEmpty) {
      return _LunarText(
        text: festivals.first,
        color: effectiveGeneralFestivalTextColor(context, colorScheme.primary),
        fontSize: fontSize,
      );
    }
    final jieQi = lunar.getJieQi();
    if (jieQi.isNotEmpty) {
      return _LunarText(
        text: jieQi,
        color: effectiveGeneralSolarTermTextColor(
          context,
          colorScheme.tertiary,
        ),
        fontSize: fontSize,
      );
    }
    return _LunarText(
      text: lunar.getDayInChinese(),
      color: effectiveGeneralLunarTextColor(
        context,
        overrideColor ?? colorScheme.onSurfaceVariant,
      ),
      fontSize: fontSize,
    );
  }
}

class _LunarText extends StatelessWidget {
  const _LunarText({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.05,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

extension on List<GeneralEventOccurrence> {
  List<GeneralEventOccurrence> sortedForAgenda() {
    return toList()..sort((a, b) {
      if (a.isAllDay && !b.isAllDay) return -1;
      if (!a.isAllDay && b.isAllDay) return 1;
      return a.start.compareTo(b.start);
    });
  }
}
