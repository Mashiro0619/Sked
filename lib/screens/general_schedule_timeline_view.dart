part of 'general_schedule_home_screen.dart';

const _generalTimelineInitialPage = 10000;
const _generalWeekPagerKey = ValueKey<String>('general-week-pager');
const _generalDayPagerKey = ValueKey<String>('general-day-pager');
const _generalDayWeekPickerPagerKey = ValueKey<String>(
  'general-day-week-picker-pager',
);
const _generalDayPickerSelectionIndicatorKey = ValueKey<String>(
  'general-day-picker-selection-indicator',
);

typedef _AllDayCollapsedGroupTap = void Function(
  List<GeneralEventOccurrence> occurrences,
  DateTime day,
);

/// Kept by the home task, independent of page indices, range length and view.
class _CalendarViewportSession {
  double horizontalOffset = 0;
  double topMinutes = 0;
  double leadingInset = 0;
  int focusRevision = -1;
}

class _WeekCalendarView extends StatefulWidget {
  const _WeekCalendarView({
    required this.date,
    required this.customRange,
    required this.onRangePageSettled,
    required this.viewport,
    required this.provider,
    required this.filter,
    required this.active,
    required this.syncRevision,
    required this.onDaySelected,
    required this.onPageSettled,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
    required this.onAllDayCollapsedGroupTap,
    required this.allDayTimelineCollapsed,
    required this.onAllDayTimelineCollapsedChanged,
  });

  final DateTime date;
  final GeneralDateRange? customRange;
  final ValueChanged<GeneralDateRange> onRangePageSettled;
  final _CalendarViewportSession viewport;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final int syncRevision;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageSettled;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  State<_WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends State<_WeekCalendarView> {
  late DateTime _baseWeekStart;
  late int _rangeDays;
  int _rangePageCount = 1;
  static const _rangePageRadius = 64;
  int get _originPage =>
      widget.customRange == null ? _generalTimelineInitialPage : 0;
  DateTime get _targetStart =>
      widget.customRange?.start ??
      startOfWeekMonday(_visibleDayForDate(widget.date));
  void _resetOrigin() {
    _rangeDays = widget.customRange?.dayCount ?? 7;
    final start = _targetStart;
    if (widget.customRange == null) {
      _baseWeekStart = start;
      return;
    }
    // A bounded paging window avoids multi-million-pixel offsets and floating
    // point extent errors during resize. Rebase near its ends, never truncate
    // the actual selected range or expose dates outside the supported bounds.
    final before =
        (calendarDaysBetween(GeneralDateRange.firstDate, start) ~/ _rangeDays)
            .clamp(0, _rangePageRadius);
    final after =
        ((calendarDaysBetween(start, GeneralDateRange.lastDate) + 1) ~/
                    _rangeDays -
                1)
            .clamp(0, _rangePageRadius);
    _baseWeekStart = addCalendarDays(start, -before * _rangeDays);
    _rangePageCount = before + 1 + after;
  }

  late final PageController _controller;
  // Provider-synchronized page. PageView may be fractional or on a different
  // provisional page while the user is dragging.
  late int _settledPage;
  int _pageSyncGeneration = 0;
  int? _pendingPage;
  bool _pageScrolling = false;

  @override
  void initState() {
    super.initState();
    _resetOrigin();
    _settledPage = _pageForWeek(_targetStart);
    _controller = PageController(
      initialPage: _settledPage,
      onAttach: (_) {
        final pendingPage = _pendingPage;
        if (pendingPage != null) _schedulePageJump(pendingPage);
      },
    );
    if (widget.active) _syncVisibleSelectedDate();
  }

  @override
  void didUpdateWidget(covariant _WeekCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _syncVisibleSelectedDate();
    final targetIndex = _pageForWeek(_targetStart);
    final range = widget.customRange;
    final changedOrigin =
        oldWidget.customRange?.dayCount != range?.dayCount ||
        (range != null &&
            (calendarDaysBetween(_baseWeekStart, _targetStart) % _rangeDays !=
                    0 ||
                targetIndex < 0 ||
                targetIndex >= _rangePageCount ||
                (targetIndex == 0 && range.shifted(-range.dayCount) != null) ||
                (targetIndex == _rangePageCount - 1 &&
                    range.shifted(range.dayCount) != null)));
    if (changedOrigin) _resetOrigin();
    if (!changedOrigin &&
        oldWidget.customRange == widget.customRange &&
        _sameDay(oldWidget.date, widget.date) &&
        oldWidget.syncRevision == widget.syncRevision) {
      return;
    }
    final targetPage = _pageForWeek(_targetStart);
    if (changedOrigin || targetPage != _settledPage) {
      _schedulePageJump(targetPage);
    }
  }

  void _schedulePageJump(int targetPage) {
    _pendingPage = targetPage;
    final generation = ++_pageSyncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _pageSyncGeneration) return;
      final hasClients = _controller.hasClients;
      if (!hasClients) return;
      if (_pageScrolling) return;
      final currentPage = _controller.page;
      if (currentPage != null && (currentPage - targetPage).abs() < 0.01) {
        _pendingPage = null;
        _settledPage = targetPage;
        return;
      }
      _pendingPage = null;
      _settledPage = targetPage;
      _controller.jumpToPage(targetPage);
    });
  }

  @override
  void dispose() {
    _pageSyncGeneration++;
    _pendingPage = null;
    _controller.dispose();
    super.dispose();
  }

  int _pageForWeek(DateTime weekStart) {
    final deltaDays = calendarDaysBetween(_baseWeekStart, weekStart);
    return _originPage + deltaDays ~/ _rangeDays;
  }

  DateTime _weekStartForPage(int page) {
    final deltaRanges = page - _originPage;
    return addCalendarDays(_baseWeekStart, deltaRanges * _rangeDays);
  }

  bool _isVisibleDay(DateTime date) {
    return widget.customRange != null ||
        widget.provider.generalShowWeekends ||
        date.weekday <= DateTime.friday;
  }

  DateTime _visibleDayForDate(DateTime date) {
    final normalized = normalizeDateOnly(date);
    if (_isVisibleDay(normalized)) {
      return normalized;
    }
    return addCalendarDays(normalized, 8 - normalized.weekday);
  }

  void _syncVisibleSelectedDate() {
    final visibleDate = _visibleDayForDate(widget.date);
    if (_sameDay(visibleDate, widget.date)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        widget.onDaySelected(visibleDate);
      }
    });
  }

  int _selectedWeekdayOffset() {
    final selected = _visibleDayForDate(widget.date);
    return calendarDaysBetween(
      widget.customRange?.start ?? startOfWeekMonday(selected),
      selected,
    ).clamp(0, _rangeDays - 1);
  }

  void _handlePageSettled(ScrollEndNotification notification) {
    if (!_pageScrolling || notification.depth != 0 || !_controller.hasClients) {
      return;
    }
    _pageScrolling = false;
    final page = _controller.page;
    if (page == null || !page.isFinite) return;
    final settledPage = page.round();
    if ((page - settledPage).abs() > 0.01) return;
    _settledPage = settledPage;
    final pendingPage = _pendingPage;
    if (pendingPage != null) {
      if (pendingPage == settledPage) {
        _pendingPage = null;
      } else {
        _schedulePageJump(pendingPage);
      }
      return;
    }
    if (!widget.active) return;
    final nextDate = _weekStartForPage(settledPage);
    if (widget.customRange != null) {
      widget.onRangePageSettled(
        GeneralDateRange(nextDate, addCalendarDays(nextDate, _rangeDays - 1)),
      );
    } else {
      widget.onPageSettled(addCalendarDays(nextDate, _selectedWeekdayOffset()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics is PageMetrics) {
                if (notification.depth == 0 &&
                    notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _pageScrolling = true;
                } else if (_pageScrolling &&
                    notification is ScrollEndNotification) {
                  _handlePageSettled(notification);
                }
              }
              return false;
            },
            child: PageView.builder(
              key: _generalWeekPagerKey,
              controller: _controller,
              itemCount: widget.customRange == null ? null : _rangePageCount,
              physics:
                  widget.active &&
                      _TimelineMetrics.forViewport(
                            context,
                            constraints.maxWidth,
                            dayCount:
                                widget.customRange?.dayCount ??
                                (widget.provider.generalShowWeekends ? 7 : 5),
                            fitWeekColumnsToWidth:
                                widget.provider.generalFitWeekColumnsToWidth,
                          ).totalWidth <=
                          constraints.maxWidth + .5
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final weekStart = _weekStartForPage(index);
                return _WeekTimelinePage(
                  weekStart: weekStart,
                  customDayCount: widget.customRange?.dayCount,
                  viewport: widget.viewport,
                  viewportActive:
                      widget.active && index == _pageForWeek(_targetStart),
                  selectedDate: addCalendarDays(
                    weekStart,
                    _selectedWeekdayOffset(),
                  ),
                  provider: widget.provider,
                  filter: widget.filter,
                  onDaySelected: widget.onDaySelected,
                  onEmptySlotTap: widget.onEmptySlotTap,
                  onOccurrenceTap: widget.onOccurrenceTap,
                  onMoreOccurrencesTap: widget.onMoreOccurrencesTap,
                  onAllDayCollapsedGroupTap: widget.onAllDayCollapsedGroupTap,
                  allDayTimelineCollapsed: widget.allDayTimelineCollapsed,
                  onAllDayTimelineCollapsedChanged:
                      widget.onAllDayTimelineCollapsedChanged,
                );
              },
            ),
          ),
    );
  }
}

class _WeekTimelinePage extends StatelessWidget {
  const _WeekTimelinePage({
    required this.weekStart,
    this.customDayCount,
    required this.viewport,
    required this.viewportActive,
    required this.selectedDate,
    required this.onDaySelected,
    required this.provider,
    required this.filter,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
    required this.onAllDayCollapsedGroupTap,
    required this.allDayTimelineCollapsed,
    required this.onAllDayTimelineCollapsedChanged,
  });

  final DateTime weekStart;
  final int? customDayCount;
  final _CalendarViewportSession viewport;
  final bool viewportActive;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final days = customDayCount == null
        ? _visibleWeekDays(weekStart, provider.generalShowWeekends)
        : List.generate(customDayCount!, (i) => addCalendarDays(weekStart, i));
    final occurrences = provider.generalOccurrencesForQuery(
      filter.toQuery(
        startInclusive: weekStart,
        endExclusive: addCalendarDays(weekStart, customDayCount ?? 7),
      ),
    );
    return _CalendarTimeline(
      days: days,
      viewport: viewport,
      viewportActive: viewportActive,
      selectedDate: selectedDate,
      occurrences: occurrences,
      startHour: provider.generalDayStartHour,
      endHour: provider.generalDayEndHour,
      gridMinutes: provider.generalTimeGridMinutes,
      hourHeight: provider.generalTimeGridHourHeight.toDouble(),
      showHeader: true,
      fitWeekColumnsToWidth: provider.generalFitWeekColumnsToWidth,
      onDaySelected: onDaySelected,
      onEmptySlotTap: onEmptySlotTap,
      onOccurrenceTap: onOccurrenceTap,
      onMoreOccurrencesTap: onMoreOccurrencesTap,
      onAllDayCollapsedGroupTap: onAllDayCollapsedGroupTap,
      allDayTimelineCollapsed: allDayTimelineCollapsed,
      onAllDayTimelineCollapsedChanged: onAllDayTimelineCollapsedChanged,
    );
  }
}

class _DayCalendarView extends StatefulWidget {
  const _DayCalendarView({
    required this.date,
    required this.provider,
    required this.filter,
    required this.active,
    required this.syncRevision,
    required this.onDaySelected,
    required this.onPageSettled,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
    required this.onAllDayCollapsedGroupTap,
    required this.allDayTimelineCollapsed,
    required this.onAllDayTimelineCollapsedChanged,
  });

  final DateTime date;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final int syncRevision;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageSettled;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  State<_DayCalendarView> createState() => _DayCalendarViewState();
}

class _DayCalendarViewState extends State<_DayCalendarView> {
  late final DateTime _baseDate;
  late final DateTime _baseWeekStart;
  late final PageController _dayController;
  late final PageController _weekController;
  // Keep transient PageView positions separate from the last committed pages
  // so an external date change cannot be mistaken for an already-synced drag.
  late int _settledDayPage;
  late int _settledWeekPage;
  bool _syncingWeekPickerFromDay = false;
  int _dayPageSyncGeneration = 0;
  int _weekPageSyncGeneration = 0;
  int? _pendingDayPage;
  int? _pendingWeekPage;
  bool _dayPageScrolling = false;
  bool _weekPageScrolling = false;
  late bool _showWeekends;

  @override
  void initState() {
    super.initState();
    _baseDate = _visibleDayForDate(widget.date);
    _baseWeekStart = startOfWeekMonday(_baseDate);
    _showWeekends = widget.provider.generalShowWeekends;
    _settledDayPage = _generalTimelineInitialPage;
    _settledWeekPage = _generalTimelineInitialPage;
    _dayController = PageController(
      initialPage: _settledDayPage,
      onAttach: (_) {
        final pendingPage = _pendingDayPage;
        if (pendingPage != null) _scheduleDayPageJump(pendingPage);
      },
    );
    _weekController = PageController(
      initialPage: _settledWeekPage,
      onAttach: (_) {
        final pendingPage = _pendingWeekPage;
        if (pendingPage != null) _scheduleWeekPageJump(pendingPage);
      },
    );
    _dayController.addListener(_syncWeekPickerToDayPage);
    if (widget.active) _syncVisibleSelectedDate();
  }

  @override
  void didUpdateWidget(covariant _DayCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _syncVisibleSelectedDate();
    final showWeekendsChanged =
        _showWeekends != widget.provider.generalShowWeekends;
    _showWeekends = widget.provider.generalShowWeekends;
    final becameActive = !oldWidget.active && widget.active;
    if (_sameDay(oldWidget.date, widget.date) &&
        oldWidget.syncRevision == widget.syncRevision &&
        !showWeekendsChanged &&
        !becameActive) {
      return;
    }
    final selectedDate = _visibleDayForDate(widget.date);
    final targetDayPage = _pageForDay(selectedDate);
    if (targetDayPage != _settledDayPage) {
      _scheduleDayPageJump(targetDayPage);
    }
    final targetWeekPage = _pageForWeek(startOfWeekMonday(selectedDate));
    if (targetWeekPage != _settledWeekPage) {
      _scheduleWeekPageJump(targetWeekPage);
    }
  }

  void _scheduleDayPageJump(int targetPage) {
    _pendingDayPage = targetPage;
    final generation = ++_dayPageSyncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _dayPageSyncGeneration) return;
      final hasClients = _dayController.hasClients;
      if (!hasClients) return;
      if (_dayPageScrolling) return;
      final currentPage = _dayController.page;
      if (currentPage != null && (currentPage - targetPage).abs() < 0.01) {
        _pendingDayPage = null;
        _settledDayPage = targetPage;
        return;
      }
      _pendingDayPage = null;
      _settledDayPage = targetPage;
      _dayController.jumpToPage(targetPage);
    });
  }

  void _scheduleWeekPageJump(int targetPage) {
    _pendingWeekPage = targetPage;
    final generation = ++_weekPageSyncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _weekPageSyncGeneration) return;
      final hasClients = _weekController.hasClients;
      if (!hasClients) return;
      if (_weekPageScrolling) return;
      final currentPage = _weekController.page;
      if (currentPage != null && (currentPage - targetPage).abs() < 0.01) {
        _pendingWeekPage = null;
        _settledWeekPage = targetPage;
        return;
      }
      _pendingWeekPage = null;
      _settledWeekPage = targetPage;
      _weekController.jumpToPage(targetPage);
    });
  }

  @override
  void dispose() {
    _dayPageSyncGeneration++;
    _weekPageSyncGeneration++;
    _pendingDayPage = null;
    _pendingWeekPage = null;
    _dayController.removeListener(_syncWeekPickerToDayPage);
    _dayController.dispose();
    _weekController.dispose();
    super.dispose();
  }

  int _pageForDay(DateTime date) {
    final selectedDate = _visibleDayForDate(date);
    if (widget.provider.generalShowWeekends) {
      return _generalTimelineInitialPage +
          calendarDaysBetween(_baseDate, selectedDate);
    }
    return _generalTimelineInitialPage +
        _visibleDayDifference(_baseDate, selectedDate);
  }

  DateTime _dayForPage(int page) {
    final deltaDays = page - _generalTimelineInitialPage;
    if (widget.provider.generalShowWeekends) {
      return addCalendarDays(_baseDate, deltaDays);
    }
    return _addVisibleDays(_baseDate, deltaDays);
  }

  int _pageForWeek(DateTime weekStart) {
    final deltaDays = calendarDaysBetween(_baseWeekStart, weekStart);
    return _generalTimelineInitialPage + deltaDays ~/ 7;
  }

  DateTime _weekStartForPage(int page) {
    final deltaWeeks = page - _generalTimelineInitialPage;
    return addCalendarDays(_baseWeekStart, deltaWeeks * 7);
  }

  double _pageControllerValue(PageController controller, int fallback) {
    if (!controller.hasClients) {
      return fallback.toDouble();
    }
    final page = controller.page;
    if (page == null || !page.isFinite) {
      return fallback.toDouble();
    }
    return page;
  }

  double _weekPageForDayPage(double dayPage) {
    final lowerDayPage = dayPage.floor();
    final upperDayPage = dayPage.ceil();
    final progress = dayPage - lowerDayPage;
    final lowerWeekPage = _pageForWeek(
      startOfWeekMonday(_dayForPage(lowerDayPage)),
    );
    final upperWeekPage = _pageForWeek(
      startOfWeekMonday(_dayForPage(upperDayPage)),
    );
    return lowerWeekPage + (upperWeekPage - lowerWeekPage) * progress;
  }

  void _syncWeekPickerToDayPage() {
    if (!_dayController.hasClients || !_weekController.hasClients) {
      return;
    }
    final position = _weekController.position;
    if (!position.hasViewportDimension) {
      return;
    }
    final viewportWidth = position.viewportDimension;
    if (!viewportWidth.isFinite || viewportWidth <= 0) {
      return;
    }
    final targetPage = _weekPageForDayPage(
      _pageControllerValue(_dayController, _settledDayPage),
    );
    final targetPixels = targetPage * viewportWidth;
    if ((position.pixels - targetPixels).abs() < 0.5) {
      return;
    }
    _syncingWeekPickerFromDay = true;
    try {
      _weekController.jumpTo(targetPixels);
    } finally {
      _syncingWeekPickerFromDay = false;
    }
  }

  int _selectedWeekdayOffset() {
    final selected = _visibleDayForDate(widget.date);
    return calendarDaysBetween(startOfWeekMonday(selected), selected);
  }

  bool _isVisibleDay(DateTime date) {
    return widget.provider.generalShowWeekends ||
        date.weekday <= DateTime.friday;
  }

  DateTime _visibleDayForDate(DateTime date) {
    final normalized = normalizeDateOnly(date);
    if (_isVisibleDay(normalized)) {
      return normalized;
    }
    return addCalendarDays(normalized, 8 - normalized.weekday);
  }

  void _syncVisibleSelectedDate() {
    final visibleDate = _visibleDayForDate(widget.date);
    if (_sameDay(visibleDate, widget.date)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        widget.onDaySelected(visibleDate);
      }
    });
  }

  DateTime _addVisibleDays(DateTime date, int deltaDays) {
    var result = _visibleDayForDate(date);
    final step = deltaDays < 0 ? -1 : 1;
    var remaining = deltaDays.abs();
    while (remaining > 0) {
      result = addCalendarDays(result, step);
      if (_isVisibleDay(result)) {
        remaining -= 1;
      }
    }
    return result;
  }

  int _visibleDayDifference(DateTime start, DateTime end) {
    final from = _visibleDayForDate(start);
    final to = _visibleDayForDate(end);
    var cursor = from;
    var difference = 0;
    final step = to.isBefore(from) ? -1 : 1;
    while (!_sameDay(cursor, to)) {
      cursor = addCalendarDays(cursor, step);
      if (_isVisibleDay(cursor)) {
        difference += step;
      }
    }
    return difference;
  }

  void _handleDayPageScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics is! PageMetrics) return;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dayPageScrolling = true;
    } else if (_dayPageScrolling && notification is ScrollEndNotification) {
      _handleDayPageSettled(notification);
    }
  }

  void _handleWeekPageScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics is! PageMetrics) return;
    if (_syncingWeekPickerFromDay) {
      _weekPageScrolling = false;
      return;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _weekPageScrolling = true;
    } else if (_weekPageScrolling && notification is ScrollEndNotification) {
      _handleWeekPageSettled(notification);
    }
  }

  void _handleDayPageSettled(ScrollEndNotification notification) {
    if (notification.depth != 0 || !_dayController.hasClients) {
      return;
    }
    _dayPageScrolling = false;
    final page = _dayController.page;
    if (page == null || !page.isFinite) return;
    final settledPage = page.round();
    if ((page - settledPage).abs() > 0.01) return;
    _settledDayPage = settledPage;
    final pendingPage = _pendingDayPage;
    if (pendingPage != null) {
      if (pendingPage == settledPage) {
        _pendingDayPage = null;
      } else {
        _scheduleDayPageJump(pendingPage);
      }
      return;
    }
    if (!widget.active) return;
    widget.onPageSettled(_dayForPage(settledPage));
  }

  void _handleWeekPageSettled(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        _syncingWeekPickerFromDay ||
        !_weekController.hasClients) {
      return;
    }
    _weekPageScrolling = false;
    final page = _weekController.page;
    if (page == null || !page.isFinite) return;
    final settledPage = page.round();
    if ((page - settledPage).abs() > 0.01) return;
    _settledWeekPage = settledPage;
    final pendingPage = _pendingWeekPage;
    if (pendingPage != null) {
      if (pendingPage == settledPage) {
        _pendingWeekPage = null;
      } else {
        _scheduleWeekPageJump(pendingPage);
      }
      return;
    }
    if (!widget.active) return;
    final nextDate = _weekStartForPage(settledPage);
    widget.onPageSettled(addCalendarDays(nextDate, _selectedWeekdayOffset()));
  }

  @override
  Widget build(BuildContext context) {
    final day = _visibleDayForDate(widget.date);
    return Column(
      children: [
        _DayWeekPicker(
          controller: _weekController,
          selectionController: _dayController,
          selectedDate: day,
          selectedDayPageFallback: _settledDayPage,
          showWeekends: widget.provider.generalShowWeekends,
          dayPageForDate: _pageForDay,
          weekStartForPage: _weekStartForPage,
          onPageScroll: _handleWeekPageScroll,
          onDaySelected: widget.onDaySelected,
          active: widget.active,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _handleDayPageScroll(notification);
              return false;
            },
            child: PageView.builder(
              key: _generalDayPagerKey,
              controller: _dayController,
              physics: widget.active
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final pageDay = _dayForPage(index);
                return _DayTimelinePage(
                  date: pageDay,
                  provider: widget.provider,
                  filter: widget.filter,
                  onEmptySlotTap: widget.onEmptySlotTap,
                  onOccurrenceTap: widget.onOccurrenceTap,
                  onMoreOccurrencesTap: widget.onMoreOccurrencesTap,
                  onAllDayCollapsedGroupTap: widget.onAllDayCollapsedGroupTap,
                  allDayTimelineCollapsed: widget.allDayTimelineCollapsed,
                  onAllDayTimelineCollapsedChanged:
                      widget.onAllDayTimelineCollapsedChanged,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DayTimelinePage extends StatelessWidget {
  const _DayTimelinePage({
    required this.date,
    required this.provider,
    required this.filter,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
    required this.onAllDayCollapsedGroupTap,
    required this.allDayTimelineCollapsed,
    required this.onAllDayTimelineCollapsedChanged,
  });

  final DateTime date;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final day = normalizeDateOnly(date);
    final occurrences = provider.generalOccurrencesForQuery(
      filter.toQuery(
        startInclusive: day,
        endExclusive: calendarDateEndExclusive(day),
      ),
    );
    return _CalendarTimeline(
      days: [day],
      selectedDate: day,
      occurrences: occurrences,
      startHour: provider.generalDayStartHour,
      endHour: provider.generalDayEndHour,
      gridMinutes: provider.generalTimeGridMinutes,
      hourHeight: provider.generalTimeGridHourHeight.toDouble(),
      showHeader: false,
      onEmptySlotTap: onEmptySlotTap,
      onOccurrenceTap: onOccurrenceTap,
      onMoreOccurrencesTap: onMoreOccurrencesTap,
      onAllDayCollapsedGroupTap: onAllDayCollapsedGroupTap,
      allDayTimelineCollapsed: allDayTimelineCollapsed,
      onAllDayTimelineCollapsedChanged: onAllDayTimelineCollapsedChanged,
    );
  }
}

class _DayWeekPicker extends StatelessWidget {
  const _DayWeekPicker({
    required this.controller,
    required this.selectionController,
    required this.selectedDate,
    required this.selectedDayPageFallback,
    required this.showWeekends,
    required this.dayPageForDate,
    required this.weekStartForPage,
    required this.onPageScroll,
    required this.onDaySelected,
    required this.active,
  });

  final PageController controller;
  final PageController selectionController;
  final DateTime selectedDate;
  final int selectedDayPageFallback;
  final bool showWeekends;
  final int Function(DateTime date) dayPageForDate;
  final DateTime Function(int page) weekStartForPage;
  final ValueChanged<ScrollNotification> onPageScroll;
  final ValueChanged<DateTime> onDaySelected;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: Listenable.merge([controller, selectionController]),
      builder: (context, _) {
        final selectedDayPage = _pageControllerValue(
          selectionController,
          selectedDayPageFallback,
        );
        return Container(
          height:
              66 *
              WorkbenchLayoutPolicy.textFactor(
                MediaQuery.textScalerOf(context).scale(14) / 14,
              ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withAlpha(160),
              ),
            ),
          ),
          child: Row(
            children: [
              _MonthRail(date: selectedDate),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    onPageScroll(notification);
                    return false;
                  },
                  child: PageView.builder(
                    key: _generalDayWeekPickerPagerKey,
                    controller: controller,
                    physics: active
                        ? const PageScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final weekStart = weekStartForPage(index);
                      final days = _visibleWeekDays(weekStart, showWeekends);
                      return _DayWeekPickerRow(
                        days: days,
                        selectedDate: selectedDate,
                        selectedDayPage: selectedDayPage,
                        dayPageForDate: dayPageForDate,
                        onDaySelected: onDaySelected,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _pageControllerValue(PageController controller, int fallback) {
    if (!controller.hasClients) {
      return fallback.toDouble();
    }
    final page = controller.page;
    if (page == null || !page.isFinite) {
      return fallback.toDouble();
    }
    return page;
  }
}

class _DayWeekPickerRow extends StatelessWidget {
  const _DayWeekPickerRow({
    required this.days,
    required this.selectedDate,
    required this.selectedDayPage,
    required this.dayPageForDate,
    required this.onDaySelected,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final double selectedDayPage;
  final int Function(DateTime date) dayPageForDate;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedPosition = _selectedPosition();
    final activeIndex = selectedPosition
        .round()
        .clamp(0, days.length - 1)
        .toInt();
    final showIndicatorKey = days.any((day) => _sameDay(day, selectedDate));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colorScheme = Theme.of(context).colorScheme;
          final cellWidth = constraints.maxWidth / days.length;
          final indicatorLeft = selectedPosition * cellWidth + 2;
          final indicatorWidth = math.max(0.0, cellWidth - 4);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              if (!WorkbenchChromeMetrics.compactTouch(context))
                PositionedDirectional(
                  start: indicatorLeft,
                  top: 0,
                  bottom: 0,
                  width: indicatorWidth,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: showIndicatorKey
                          ? _generalDayPickerSelectionIndicatorKey
                          : null,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (var index = 0; index < days.length; index++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _DayPickerItem(
                          date: days[index],
                          selected: index == activeIndex,
                          onTap: () => onDaySelected(days[index]),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  double _selectedPosition() {
    final firstPage = dayPageForDate(days.first).toDouble();
    final lastPage = dayPageForDate(days.last).toDouble();
    final minPage = math.min(firstPage, lastPage) - 1.0;
    final maxPage = math.max(firstPage, lastPage) + 1.0;
    if (selectedDayPage >= minPage && selectedDayPage <= maxPage) {
      return selectedDayPage - firstPage;
    }
    final sameWeekdayIndex = days.indexWhere(
      (day) => day.weekday == selectedDate.weekday,
    );
    if (sameWeekdayIndex != -1) {
      return sameWeekdayIndex.toDouble();
    }
    return 0;
  }
}

class _DayPickerItem extends StatelessWidget {
  const _DayPickerItem({
    required this.date,
    required this.selected,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _DayHeader(
    date: date,
    width: double.infinity,
    selected: selected,
    onTap: onTap,
  );
}

class _CalendarTimeline extends StatelessWidget {
  const _CalendarTimeline({
    required this.days,
    this.viewport,
    this.viewportActive = true,
    required this.selectedDate,
    required this.occurrences,
    required this.startHour,
    required this.endHour,
    required this.gridMinutes,
    required this.hourHeight,
    required this.showHeader,
    this.fitWeekColumnsToWidth = false,
    this.onDaySelected,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
    required this.onAllDayCollapsedGroupTap,
    required this.allDayTimelineCollapsed,
    required this.onAllDayTimelineCollapsedChanged,
  });

  static const double _timeLabelVerticalPadding = 12;

  final _CalendarViewportSession? viewport;
  final bool viewportActive;
  final List<DateTime> days;
  final DateTime selectedDate;
  final List<GeneralEventOccurrence> occurrences;
  final int startHour;
  final int endHour;
  final int gridMinutes;
  final double hourHeight;
  final bool showHeader;
  final bool fitWeekColumnsToWidth;
  final ValueChanged<DateTime>? onDaySelected;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    final startMinutes = startHour * 60;
    final endMinutes = endHour * 60;
    final textFactor = WorkbenchLayoutPolicy.textFactor(
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final safeHourHeight =
        hourHeight.clamp(
          generalTimeGridHourHeightMin.toDouble(),
          generalTimeGridHourHeightMax.toDouble(),
        ) *
        textFactor;
    final labelPadding = _timeLabelVerticalPadding * textFactor;
    final gridHeight = math.max(1, endHour - startHour) * safeHourHeight;
    final contentHeight = gridHeight + labelPadding * 2;
    final minuteHeight = safeHourHeight / 60;
    final occurrenceIndex = _TimelineOccurrenceIndex.build(occurrences, days);
    final allDayLayout = _AllDayTimelineLayout.build(
      occurrences: occurrences,
      days: days,
    );
    final allDayCount = allDayLayout.segments.length;
    final hasAllDayOccurrences = allDayCount > 0;
    final canCollapseAllDay = allDayCount > 1;
    final isAllDayCollapsed = canCollapseAllDay && allDayTimelineCollapsed;
    final motion = SkedMotionPolicy.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _TimelineMetrics.forViewport(
          context,
          constraints.maxWidth,
          dayCount: days.length,
          fitWeekColumnsToWidth: fitWeekColumnsToWidth,
        );

        final compactTouch = WorkbenchChromeMetrics.compactTouch(
          context,
          width: constraints.maxWidth,
        );
        final headerHeight = !showHeader
            ? 0.0
            : compactTouch
            ? _DayHeader.measuredHeight(context, metrics.dayWidth)
            : (WorkbenchChromeMetrics.of(context).desktop ? 60 : 68) *
                  textFactor;
        final allDayBudget = hasAllDayOccurrences
            ? math.max(
                allDayLayout.laneHeightFor(context),
                math.min(240 * textFactor, constraints.maxHeight * .38),
              )
            : 0.0;
        final minimumHeight = headerHeight + allDayBudget + 1 + 96;
        final short = compactTouch && constraints.maxHeight < minimumHeight;
        // In very short landscape layouts, fixed date/all-day chrome must not
        // overflow or leave a zero-height time viewport. Let that chrome scroll
        // out of the way; the inner timeline keeps its minute-based position.
        return SingleChildScrollView(
          key: const ValueKey('general-timeline-height-scroll'),
          primary: false,
          physics: short
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: short ? minimumHeight : constraints.maxHeight,
            child: _CalendarHorizontalViewport(
              viewportWidth: constraints.maxWidth,
              contentWidth: metrics.totalWidth,
              viewport: viewport,
              active: viewportActive,
              focusRevision: context.select<TimetableProvider, int>(
                (p) => p.generalDateFocusRevision,
              ),
              selectedDay: days.indexWhere(
                (day) => _sameDay(day, selectedDate),
              ),
              dayWidth: metrics.dayWidth,
              railWidth: metrics.timeColumnWidth,
              child: SizedBox(
                width: metrics.totalWidth,
                child: Column(
                  children: [
                    if (showHeader)
                      SizedBox(
                        height: headerHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Row(
                              children: [
                                SizedBox(width: metrics.timeColumnWidth),
                                for (final day in days)
                                  _DayHeader(
                                    date: day,
                                    width: metrics.dayWidth,
                                    selected: _sameDay(day, selectedDate),
                                    onTap: onDaySelected == null
                                        ? null
                                        : () => onDaySelected!(day),
                                  ),
                              ],
                            ),
                            _PinnedTimelineRail(
                              width: metrics.timeColumnWidth,
                              child: _MonthRail(
                                date: selectedDate,
                                width: metrics.timeColumnWidth,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasAllDayOccurrences)
                      SkedAnimatedSize(
                        key: const ValueKey('general-all-day-transition'),
                        alignment: Alignment.topCenter,
                        duration: motion.spatialAnimationsEnabled
                            ? motion.effects(SkedMotionSpeed.standard)
                            : Duration.zero,
                        child: _AllDayTimeline(
                          timeColumnWidth: metrics.timeColumnWidth,
                          dayWidth: metrics.dayWidth,
                          dayCount: days.length,
                          layout: allDayLayout,
                          label: l10n.allDay,
                          maxHeight: math.min(
                            240 * textFactor,
                            constraints.maxHeight * .38,
                          ),
                          collapsed: isAllDayCollapsed,
                          canCollapse: canCollapseAllDay,
                          onToggleCollapsed: canCollapseAllDay
                              ? () => onAllDayTimelineCollapsedChanged(
                                  !isAllDayCollapsed,
                                )
                              : null,
                          onOccurrenceTap: onOccurrenceTap,
                          onCollapsedGroupTap: (group) =>
                              onAllDayCollapsedGroupTap(
                                group.occurrences,
                                days[group.dayIndex],
                              ),
                        ),
                      ),
                    if (hasAllDayOccurrences)
                      const Divider(height: 1)
                    else if (showHeader)
                      const Divider(height: 1)
                    else
                      Container(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                        margin: EdgeInsetsDirectional.only(
                          start: metrics.timeColumnWidth,
                        ),
                      ),
                    Expanded(
                      child: _TimelineVerticalScrollViewport(
                        key: PageStorageKey(
                          showHeader
                              ? 'general-week-timeline-position'
                              : 'timeline-position-${days.length}-${_dateKey(days.first)}',
                        ),
                        hourHeight: safeHourHeight,
                        topOffset: labelPadding,
                        viewport: viewport,
                        active: viewportActive,
                        child: SizedBox(
                          height: contentHeight,
                          child: Stack(
                            key: const ValueKey('general-timeline-grid'),
                            children: [
                              _GridBackground(
                                timeColumnWidth: metrics.timeColumnWidth,
                                dayWidth: metrics.dayWidth,
                                dayCount: days.length,
                                startHour: startHour,
                                endHour: endHour,
                                gridMinutes: gridMinutes,
                                hourHeight: safeHourHeight,
                                topOffset: labelPadding,
                              ),
                              for (var index = 0; index < days.length; index++)
                                PositionedDirectional(
                                  start:
                                      metrics.timeColumnWidth +
                                      index * metrics.dayWidth,
                                  top: labelPadding,
                                  width: metrics.dayWidth,
                                  height: gridHeight,
                                  child: GestureDetector(
                                    key: ValueKey(
                                      'general-timeline-empty-slot-${_dateKey(days[index])}',
                                    ),
                                    behavior: HitTestBehavior.translucent,
                                    onDoubleTapDown:
                                        !WorkbenchLayoutPolicy.pointerLayout(
                                              context,
                                            ) ||
                                            onEmptySlotTap == null
                                        ? null
                                        : (details) {
                                            final minutes =
                                                _snapMinutes(
                                                      startMinutes +
                                                          (details
                                                                      .localPosition
                                                                      .dy /
                                                                  minuteHeight)
                                                              .round(),
                                                      gridMinutes,
                                                    )
                                                    .clamp(
                                                      startMinutes,
                                                      endMinutes - 15,
                                                    )
                                                    .toInt();
                                            onEmptySlotTap!(
                                              DateTime(
                                                days[index].year,
                                                days[index].month,
                                                days[index].day,
                                                minutes ~/ 60,
                                                minutes % 60,
                                              ),
                                            );
                                          },
                                    onLongPressStart:
                                        onEmptySlotTap == null ||
                                            !context
                                                .read<TimetableProvider>()
                                                .enableLongPressAddEvent
                                        ? null
                                        : (details) {
                                            final minutes =
                                                _snapMinutes(
                                                      startMinutes +
                                                          (details
                                                                      .localPosition
                                                                      .dy /
                                                                  minuteHeight)
                                                              .round(),
                                                      gridMinutes,
                                                    )
                                                    .clamp(
                                                      startMinutes,
                                                      endMinutes - 15,
                                                    )
                                                    .toInt();
                                            final day = days[index];
                                            onEmptySlotTap!(
                                              DateTime(
                                                day.year,
                                                day.month,
                                                day.day,
                                                minutes ~/ 60,
                                                minutes % 60,
                                              ),
                                            );
                                          },
                                  ),
                                ),
                              for (var index = 0; index < days.length; index++)
                                ..._timedOccurrenceCards(
                                  context: context,
                                  day: days[index],
                                  start:
                                      metrics.timeColumnWidth +
                                      index * metrics.dayWidth,
                                  width: metrics.dayWidth,
                                  startMinutes: startMinutes,
                                  endMinutes: endMinutes,
                                  minuteHeight: minuteHeight,
                                  topOffset: labelPadding,
                                  dayOccurrences: occurrenceIndex.timedFor(
                                    days[index],
                                  ),
                                ),
                              for (var index = 0; index < days.length; index++)
                                if (_sameDay(days[index], DateTime.now()) &&
                                    _nowMinutes() >= startMinutes &&
                                    _nowMinutes() <= endMinutes)
                                  PositionedDirectional(
                                    start:
                                        metrics.timeColumnWidth +
                                        index * metrics.dayWidth,
                                    top:
                                        labelPadding +
                                        (_nowMinutes() - startMinutes) *
                                            minuteHeight,
                                    width: metrics.dayWidth,
                                    child: const _NowLine(),
                                  ),
                              _PinnedTimelineRail(
                                width: metrics.timeColumnWidth,
                                child: _TimelineTimeRuler(
                                  startHour: startHour,
                                  endHour: endHour,
                                  hourHeight: safeHourHeight,
                                  topOffset: labelPadding,
                                ),
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
        );
      },
    );
  }

  Iterable<Widget> _timedOccurrenceCards({
    required BuildContext context,
    required DateTime day,
    required List<GeneralEventOccurrence> dayOccurrences,
    required double start,
    required double width,
    required int startMinutes,
    required int endMinutes,
    required double minuteHeight,
    required double topOffset,
  }) sync* {
    final dayStart = normalizeDateOnly(day);
    final dayEnd = calendarDateEndExclusive(dayStart);
    final segments = <_TimedOccurrenceSegment>[];
    for (final occurrence in dayOccurrences) {
      final displayStart = occurrence.calendarDisplayStart;
      final displayEnd = occurrence.calendarDisplayEnd;
      if (occurrence.isAllDay || !_sameDay(displayStart, displayEnd)) {
        continue;
      }
      final segmentStart = displayStart.isBefore(dayStart)
          ? dayStart
          : displayStart;
      final segmentEnd = displayEnd.isAfter(dayEnd) ? dayEnd : displayEnd;
      final rawStart = segmentStart.hour * 60 + segmentStart.minute;
      final rawEnd = segmentEnd.hour * 60 + segmentEnd.minute;
      final topMinutes = rawStart.clamp(startMinutes, endMinutes).toInt();
      final bottomMinutes = rawEnd.clamp(startMinutes, endMinutes).toInt();
      if (bottomMinutes <= startMinutes || topMinutes >= endMinutes) {
        continue;
      }
      segments.add(
        _TimedOccurrenceSegment(
          occurrence: occurrence,
          startMinutes: topMinutes,
          endMinutes: bottomMinutes,
        ),
      );
    }
    final groups = layoutTimelineEventColumns([
      for (final segment in segments)
        TimelineEventSpan(
          segment.occurrence,
          segment.startMinutes,
          segment.endMinutes,
        ),
    ]);
    final chrome = WorkbenchChromeMetrics.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    const gap = 2.0;
    const inset = 2.0;
    for (final group in groups) {
      final budget = TimelineColumnBudget.resolve(
        width: width - inset * 2,
        columns: group.columnCount,
        textScale: textScale,
        desktop: chrome.desktop,
      );
      final hidden = group.events
          .where((e) => e.column >= budget.visibleColumns)
          .toList();
      for (final event in group.events.where(
        (e) => e.column < budget.visibleColumns,
      )) {
        final span = event.span;
        final segmentHeight = (span.end - span.start) * minuteHeight;
        final verticalInset = math.min(1.5, segmentHeight / 4);
        final cardHeight = segmentHeight - verticalInset * 2;
        yield PositionedDirectional(
          start: start + inset + event.column * (budget.columnWidth + gap),
          top:
              topOffset +
              (span.start - startMinutes) * minuteHeight +
              verticalInset,
          width: budget.columnWidth,
          height: cardHeight,
          child: _OccurrenceCard(
            occurrence: span.value,
            dense: cardHeight < 52 * textScale,
            narrow: budget.columnWidth < 64 * textScale,
            compactStrip: cardHeight < 18 * textScale,
            overlapping: group.columnCount > 1,
            onTap: () => onOccurrenceTap(span.value),
          ),
        );
      }
      if (hidden.isNotEmpty) {
        final first = hidden.first.span;
        final lastMinute = hidden.fold(
          first.end,
          (end, e) => math.max(end, e.span.end),
        );
        final badgeHeight = math.min(
          (chrome.desktop ? 28.0 : 48.0) * textScale,
          (lastMinute - first.start) * minuteHeight,
        );
        yield PositionedDirectional(
          start: start + width - inset - budget.overflowWidth,
          top: topOffset + (first.start - startMinutes) * minuteHeight + 1,
          width: budget.overflowWidth,
          height: math.max(1, badgeHeight - 2),
          child: _MoreOccurrencesCard(
            occurrence: first.value,
            count: hidden.length,
            compactStrip: badgeHeight < 18 * textScale,
            onTap: () => onMoreOccurrencesTap([
              for (final event in group.events) event.span.value,
            ]),
          ),
        );
      }
    }
  }
}

class _TimelineVerticalScrollViewport extends StatefulWidget {
  const _TimelineVerticalScrollViewport({
    super.key,
    required this.hourHeight,
    required this.topOffset,
    this.viewport,
    this.active = true,
    required this.child,
  });

  final double hourHeight;
  final double topOffset;
  final Widget child;
  final _CalendarViewportSession? viewport;
  final bool active;

  @override
  State<_TimelineVerticalScrollViewport> createState() =>
      _TimelineVerticalScrollViewportState();
}

class _TimelineVerticalScrollViewportState
    extends State<_TimelineVerticalScrollViewport> {
  late final ScrollController _controller;
  int _anchorGeneration = 0;
  double get _sessionOffset =>
      (widget.viewport?.leadingInset ?? 0) +
      (widget.viewport?.topMinutes ?? 0) * widget.hourHeight / 60;
  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: _sessionOffset,
      keepScrollOffset: widget.viewport == null,
    )..addListener(_rememberPosition);
  }

  void _rememberPosition() {
    final session = widget.viewport;
    if (!widget.active || session == null || !_controller.hasClients) return;
    session.leadingInset = math.min(_controller.offset, widget.topOffset);
    session.topMinutes = math.max(
      0,
      (_controller.offset - widget.topOffset) * 60 / widget.hourHeight,
    );
  }

  void _restoreSession() {
    final target = _sessionOffset;
    final generation = ++_anchorGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _anchorGeneration ||
          !_controller.hasClients) {
        return;
      }
      final position = _controller.position;
      _controller.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  void didUpdateWidget(covariant _TimelineVerticalScrollViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport != widget.viewport ||
        (widget.viewport != null && !oldWidget.active && widget.active)) {
      _restoreSession();
      return;
    }
    if (oldWidget.hourHeight == widget.hourHeight || !_controller.hasClients) {
      return;
    }
    final offset = _controller.offset;
    final leadingInset = math.min(offset, oldWidget.topOffset);
    final topMinutes = math.max(
      0.0,
      (offset - oldWidget.topOffset) * 60 / oldWidget.hourHeight,
    );
    final generation = ++_anchorGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _anchorGeneration ||
          !_controller.hasClients) {
        return;
      }
      final position = _controller.position;
      final target = (leadingInset + topMinutes * widget.hourHeight / 60).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _controller.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _anchorGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('general-timeline-scroll-view'),
      controller: _controller,
      padding: EdgeInsets.only(
        bottom: WorkbenchLayoutPolicy.pointerLayout(context) ? 16 : 88,
      ),
      child: widget.child,
    );
  }
}

class _AllDayTimelineLayout {
  const _AllDayTimelineLayout({
    required this.segments,
    required this.visibleSegments,
    required this.collapsedGroups,
    required this.visibleLaneCount,
    required this.laneCount,
  });
  static const int maxVisibleLanes = 2;
  static const double verticalPadding = 4;
  static const double laneGap = 3;
  final List<_AllDaySegment> segments;
  final List<_AllDaySegment> visibleSegments;
  final List<_AllDayCollapsedGroup> collapsedGroups;
  final int visibleLaneCount;
  final int laneCount;
  int get hiddenCount => segments.length - visibleSegments.length;
  factory _AllDayTimelineLayout.build({
    required List<GeneralEventOccurrence> occurrences,
    required List<DateTime> days,
  }) {
    final segments = _layoutAllDaySegments(
      _allDaySegmentsForDays(occurrences, days),
    );
    final lanes = segments.fold<int>(
      0,
      (count, segment) => math.max(count, segment.lane + 1),
    );
    return _AllDayTimelineLayout(
      segments: List.unmodifiable(segments),
      visibleSegments: List.unmodifiable(
        segments.where((s) => s.lane < maxVisibleLanes),
      ),
      collapsedGroups: List.unmodifiable(
        _groupAllDayCollapsedSegments(segments),
      ),
      visibleLaneCount: math.min(lanes, maxVisibleLanes),
      laneCount: lanes,
    );
  }
  double laneHeightFor(BuildContext context) {
    final text = MediaQuery.textScalerOf(context).scale(12);
    return math.max(
      WorkbenchChromeMetrics.of(context).desktop ? 28 : 48,
      text * 1.2 + 8,
    );
  }

  double heightFor(
    BuildContext context, {
    bool collapsed = false,
    bool expanded = false,
  }) {
    final rows = collapsed ? 1 : (expanded ? laneCount : visibleLaneCount);
    if (rows == 0) return 0;
    return math.max(
      WorkbenchChromeMetrics.of(context).iconTarget,
      verticalPadding * 2 +
          rows * laneHeightFor(context) +
          (rows - 1) * laneGap,
    );
  }
}

class _AllDayCollapsedGroup {
  const _AllDayCollapsedGroup({
    required this.dayIndex,
    required this.occurrences,
  });

  final int dayIndex;
  final List<GeneralEventOccurrence> occurrences;
}

class _AllDaySegment {
  const _AllDaySegment({
    required this.occurrence,
    required this.startIndex,
    required this.endIndex,
    this.lane = 0,
  });

  final GeneralEventOccurrence occurrence;
  final int startIndex;
  final int endIndex;
  final int lane;

  _AllDaySegment inLane(int value) => _AllDaySegment(
    occurrence: occurrence,
    startIndex: startIndex,
    endIndex: endIndex,
    lane: value,
  );
}

List<_AllDaySegment> _allDaySegmentsForDays(
  List<GeneralEventOccurrence> occurrences,
  List<DateTime> days,
) {
  if (days.isEmpty) {
    return const [];
  }
  final normalizedDays = [for (final day in days) normalizeDateOnly(day)];
  final segments = <_AllDaySegment>[];
  for (final occurrence in occurrences) {
    final displayStart = occurrence.calendarDisplayStart;
    final displayEnd = occurrence.calendarDisplayEnd;
    // Multi-day timed events keep their existing all-day-lane representation;
    // same-day timed events remain in the hourly grid instead.
    if (!displayEnd.isAfter(displayStart) ||
        (!occurrence.isAllDay && _sameDay(displayStart, displayEnd))) {
      continue;
    }

    final eventStartDay = normalizeDateOnly(displayStart);
    final eventLastDay = normalizeDateOnly(
      displayEnd.subtract(const Duration(microseconds: 1)),
    );
    var startIndex = -1;
    var endIndex = -1;
    for (var index = 0; index < normalizedDays.length; index++) {
      final day = normalizedDays[index];
      final startsOnOrAfterEvent = calendarDaysBetween(eventStartDay, day) >= 0;
      final endsOnOrBeforeEvent = calendarDaysBetween(day, eventLastDay) >= 0;
      if (!startsOnOrAfterEvent || !endsOnOrBeforeEvent) {
        continue;
      }
      startIndex = startIndex == -1 ? index : startIndex;
      endIndex = index;
    }
    if (startIndex == -1 || endIndex < startIndex) {
      continue;
    }
    segments.add(
      _AllDaySegment(
        occurrence: occurrence,
        startIndex: startIndex,
        endIndex: endIndex,
      ),
    );
  }
  return segments;
}

List<_AllDaySegment> _layoutAllDaySegments(List<_AllDaySegment> segments) {
  final sorted = [...segments]
    ..sort((a, b) {
      final startCompare = a.startIndex.compareTo(b.startIndex);
      if (startCompare != 0) return startCompare;
      final spanCompare = b.endIndex.compareTo(a.endIndex);
      if (spanCompare != 0) return spanCompare;
      final startTimeCompare = a.occurrence.start.compareTo(b.occurrence.start);
      if (startTimeCompare != 0) return startTimeCompare;
      final titleCompare = a.occurrence.event.title.compareTo(
        b.occurrence.event.title,
      );
      if (titleCompare != 0) return titleCompare;
      return a.occurrence.event.id.compareTo(b.occurrence.event.id);
    });
  final laneEnds = <int>[];
  final laidOut = <_AllDaySegment>[];
  for (final segment in sorted) {
    var lane = laneEnds.indexWhere((endIndex) => endIndex < segment.startIndex);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(segment.endIndex);
    } else {
      laneEnds[lane] = segment.endIndex;
    }
    laidOut.add(segment.inLane(lane));
  }
  return laidOut;
}

List<_AllDayCollapsedGroup> _groupAllDayCollapsedSegments(
  List<_AllDaySegment> segments,
) {
  if (segments.isEmpty) {
    return const [];
  }
  final grouped = <int, List<GeneralEventOccurrence>>{};
  for (final segment in segments) {
    for (
      var dayIndex = segment.startIndex;
      dayIndex <= segment.endIndex;
      dayIndex++
    ) {
      grouped
          .putIfAbsent(dayIndex, () => <GeneralEventOccurrence>[])
          .add(segment.occurrence);
    }
  }
  return [
    for (final entry in grouped.entries)
      _AllDayCollapsedGroup(
        dayIndex: entry.key,
        occurrences: List.unmodifiable(entry.value),
      ),
  ];
}

class _TimelineOccurrenceIndex {
  const _TimelineOccurrenceIndex({required this.timedByDate});

  final Map<String, List<GeneralEventOccurrence>> timedByDate;

  factory _TimelineOccurrenceIndex.build(
    List<GeneralEventOccurrence> occurrences,
    List<DateTime> days,
  ) {
    final timedByDate = <String, List<GeneralEventOccurrence>>{};
    for (final day in days) {
      final key = _calendarDateKey(day);
      timedByDate[key] = [];
    }
    final firstDay = normalizeDateOnly(days.first);
    final lastDay = normalizeDateOnly(days.last);
    final rangeEndExclusive = calendarDateEndExclusive(lastDay);

    for (final occurrence in occurrences) {
      final displayStart = occurrence.calendarDisplayStart;
      final displayEnd = occurrence.calendarDisplayEnd;
      if (!displayEnd.isAfter(displayStart) ||
          !displayEnd.isAfter(firstDay) ||
          !displayStart.isBefore(rangeEndExclusive)) {
        continue;
      }

      if (occurrence.isAllDay || !_sameDay(displayStart, displayEnd)) {
        continue;
      }

      timedByDate[_calendarDateKey(displayStart)]?.add(occurrence);
    }

    return _TimelineOccurrenceIndex(timedByDate: timedByDate);
  }

  List<GeneralEventOccurrence> timedFor(DateTime day) =>
      timedByDate[_calendarDateKey(day)] ?? const [];
}

class _TimelineMetrics {
  const _TimelineMetrics({
    required this.totalWidth,
    required this.timeColumnWidth,
    required this.dayWidth,
  });

  static const monthRailWidth = 64.0;

  final double totalWidth;
  final double timeColumnWidth;
  final double dayWidth;

  factory _TimelineMetrics.forViewport(
    BuildContext context,
    double width, {
    required int dayCount,
    bool fitWeekColumnsToWidth = false,
  }) {
    final scale = WorkbenchLayoutPolicy.textFactor(
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final compact = WorkbenchChromeMetrics.compactTouch(context, width: width);
    final rail = compact
        ? _TimelineTimeRuler.measuredWidth(context)
        : 64 * scale;
    final fit = compact && fitWeekColumnsToWidth && dayCount <= 7;
    return _TimelineMetrics.fromWidth(
      fit ? width : math.max(width, rail + dayCount * 96 * scale),
      dayCount: dayCount,
      timeColumnWidth: rail,
    );
  }

  factory _TimelineMetrics.fromWidth(
    double width, {
    required int dayCount,
    double timeColumnWidth = 64,
  }) {
    final safeWidth = width.isFinite && width > 0 ? width : 360.0;
    final availableDaysWidth = math.max(safeWidth - timeColumnWidth, 0.0);
    final effectiveDayCount = math.max(dayCount, 1);
    return _TimelineMetrics(
      totalWidth: safeWidth,
      timeColumnWidth: timeColumnWidth,
      dayWidth: availableDaysWidth / effectiveDayCount,
    );
  }
}

class _MonthRail extends StatelessWidget {
  const _MonthRail({
    required this.date,
    this.width = _TimelineMetrics.monthRailWidth,
  });
  final double width;

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          formatMonthLabel(
            date.month,
            localeCode: AppLocalizations.of(context).localeName,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _TimedOccurrenceSegment {
  const _TimedOccurrenceSegment({
    required this.occurrence,
    required this.startMinutes,
    required this.endMinutes,
  });
  final GeneralEventOccurrence occurrence;
  final int startMinutes;
  final int endMinutes;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.width,
    required this.selected,
    this.onTap,
  });
  final DateTime date;
  final double width;
  final bool selected;
  final VoidCallback? onTap;

  static double measuredHeight(BuildContext context, double width) {
    final theme = Theme.of(context);
    final compact = width < 64 * WorkbenchChromeMetrics.of(context).textScale;
    if (WorkbenchChromeMetrics.compactTouch(context)) {
      return SkedCalendarDayLabel.measuredHeight(
        context,
        compact: !width.isFinite || width < 140,
        localeCode: AppLocalizations.of(context).localeName,
      );
    }
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var height = 0.0;
    for (final style in [
      theme.textTheme.labelSmall,
      theme.textTheme.titleMedium?.copyWith(fontSize: compact ? 14 : 18),
    ]) {
      painter.text = TextSpan(text: '28', style: style);
      painter.layout();
      height += painter.height;
    }
    painter.dispose();
    // Scale the text, not an entire fixed-height band. This keeps a short phone
    // landscape usable at large font sizes without compressing the time grid.
    return math.max(48, height + 12).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = _sameDay(date, DateTime.now());
    final phone = WorkbenchChromeMetrics.compactTouch(context);
    final compact = width < 64 * WorkbenchChromeMetrics.of(context).textScale;
    return SizedBox(
      key: ValueKey('general-week-day-header-${_dateKey(date)}'),
      width: width,
      child: Semantics(
        button: true,
        selected: selected,
        label: MaterialLocalizations.of(context).formatFullDate(date),
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: selected && !phone
              ? colors.surfaceContainerHigh.withValues(alpha: .65)
              : colors.surface,
          child: InkWell(
            onTap: onTap,
            child: phone
                ? SkedCalendarDayLabel(
                    date: date,
                    compact: !width.isFinite || width < 140,
                    localeCode: AppLocalizations.of(context).localeName,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekdayLabel(context, date),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 0 : 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: today ? colors.primary : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            date.day.toString(),
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: compact ? 14 : 18,
                              fontWeight: selected || today
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: today
                                  ? colors.onPrimary
                                  : colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(child: Divider(height: 1, thickness: 2, color: color)),
      ],
    );
  }
}

/// Provides the existing horizontal controller without rebuilding the canvas on
/// scroll. Only the three pinned rail surfaces listen to the offset.
class _TimelineHorizontalScope extends InheritedWidget {
  const _TimelineHorizontalScope({
    required this.controller,
    required super.child,
  });
  final ScrollController controller;
  static ScrollController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_TimelineHorizontalScope>()!
      .controller;
  @override
  bool updateShouldNotify(_TimelineHorizontalScope oldWidget) =>
      controller != oldWidget.controller;
}

class _PinnedTimelineRail extends StatelessWidget {
  const _PinnedTimelineRail({required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final controller = _TimelineHorizontalScope.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final colors = Theme.of(context).colorScheme;
    return PositionedDirectional(
      start: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: AnimatedBuilder(
        animation: controller,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: BorderDirectional(
              end: BorderSide(
                color: colors.outlineVariant.withValues(alpha: .42),
              ),
            ),
          ),
          child: child,
        ),
        builder: (context, child) => Transform.translate(
          offset: Offset(
            (controller.hasClients ? controller.offset : 0) * (rtl ? -1 : 1),
            0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// One horizontal offset for the date header, all-day lanes and timed grid.
/// The child stays mounted when overflow starts or stops during a resize.
class _CalendarHorizontalViewport extends StatefulWidget {
  const _CalendarHorizontalViewport({
    required this.viewportWidth,
    required this.contentWidth,
    required this.railWidth,
    required this.dayWidth,
    required this.selectedDay,
    required this.focusRevision,
    required this.active,
    this.viewport,
    required this.child,
  });
  final double viewportWidth, contentWidth, railWidth, dayWidth;
  final int selectedDay, focusRevision;
  final bool active;
  final _CalendarViewportSession? viewport;
  final Widget child;
  @override
  State<_CalendarHorizontalViewport> createState() =>
      _CalendarHorizontalViewportState();
}

class _CalendarHorizontalViewportState
    extends State<_CalendarHorizontalViewport> {
  late final ScrollController _controller;
  int _revealGeneration = 0;
  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.viewport?.horizontalOffset ?? 0,
      keepScrollOffset: widget.viewport == null,
    )..addListener(_rememberOffset);
    _scheduleReveal();
  }

  void _rememberOffset() {
    if (widget.active && _controller.hasClients) {
      widget.viewport?.horizontalOffset = _controller.offset;
    }
  }

  @override
  void didUpdateWidget(_CalendarHorizontalViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final replaced = oldWidget.viewport != widget.viewport;
    final geometryChanged =
        oldWidget.contentWidth != widget.contentWidth ||
        oldWidget.viewportWidth != widget.viewportWidth ||
        oldWidget.dayWidth != widget.dayWidth;
    if (replaced ||
        geometryChanged ||
        (widget.active &&
            (!oldWidget.active ||
                oldWidget.focusRevision != widget.focusRevision))) {
      _scheduleReveal(resetOffset: replaced || !oldWidget.active);
    }
  }

  void _scheduleReveal({bool resetOffset = false}) {
    final generation = ++_revealGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _revealGeneration ||
          !widget.active ||
          !_controller.hasClients ||
          !_controller.position.hasContentDimensions) {
        return;
      }
      final position = _controller.position;
      if (resetOffset && widget.viewport != null) {
        _controller.jumpTo(
          widget.viewport!.horizontalOffset.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
      // Settings/resize may remove horizontal overflow without changing focus.
      // Clamp that axis only; the vertical viewport owns its time anchor.
      final clamped = _controller.offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (clamped != _controller.offset) _controller.jumpTo(clamped);
      _rememberOffset();
      if (widget.selectedDay < 0 ||
          widget.viewport?.focusRevision == widget.focusRevision) {
        return;
      }
      final left = widget.railWidth + widget.selectedDay * widget.dayWidth;
      final right = left + widget.dayWidth;
      var target = _controller.offset;
      if (left < target + widget.railWidth) {
        target = left - widget.railWidth;
      } else if (right > target + widget.viewportWidth) {
        target = right - widget.viewportWidth;
      }
      target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((target - _controller.offset).abs() > .01) _controller.jumpTo(target);
      widget.viewport?.focusRevision = widget.focusRevision;
      _rememberOffset();
    });
  }

  @override
  void dispose() {
    _revealGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final overflow = widget.contentWidth > widget.viewportWidth + .5;
      return _TimelineHorizontalScope(
        controller: _controller,
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: overflow,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            key: const ValueKey('general-timeline-horizontal-scroll'),
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: overflow
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(height: constraints.maxHeight, child: widget.child),
          ),
        ),
      );
    },
  );
}
