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
  BuildContext anchor,
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
    required this.view,
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
  final GeneralViewState view;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final int syncRevision;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageSettled;
  final void Function(DateTime date, Rect? anchor)? onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;
  final _GeneralOccurrencesTap onMoreOccurrencesTap;
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
        widget.view.data.showWeekends ||
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
                                (widget.view.data.showWeekends ? 7 : 5),
                            fitWeekColumnsToWidth:
                                widget.view.data.fitWeekColumnsToWidth,
                            customDayMinWidth: widget.customRange == null
                                ? null
                                : widget.view.data.customDayMinWidth,
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
                  view: widget.view,
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

class _WeekTimelinePage extends StatefulWidget {
  const _WeekTimelinePage({
    required this.weekStart,
    this.customDayCount,
    required this.viewport,
    required this.viewportActive,
    required this.selectedDate,
    required this.onDaySelected,
    required this.view,
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
  final GeneralViewState view;
  final _GeneralOccurrenceFilter filter;
  final void Function(DateTime date, Rect? anchor)? onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;
  final _GeneralOccurrencesTap onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  State<_WeekTimelinePage> createState() => _WeekTimelinePageState();
}

class _WeekTimelinePageState extends State<_WeekTimelinePage> {
  final _projection = GeneralTimelineProjectionCache();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.view,
    builder: (context, _) => _buildTimeline(context),
  );

  Widget _buildTimeline(BuildContext context) {
    final _WeekTimelinePage(
      :weekStart,
      :customDayCount,
      :viewport,
      :viewportActive,
      :selectedDate,
      :onDaySelected,
      :view,
      :filter,
      :onEmptySlotTap,
      :onOccurrenceTap,
      :onMoreOccurrencesTap,
      :onAllDayCollapsedGroupTap,
      :allDayTimelineCollapsed,
      :onAllDayTimelineCollapsedChanged,
    ) = widget;
    final days = customDayCount == null
        ? _visibleWeekDays(weekStart, view.data.showWeekends)
        : List.generate(customDayCount, (i) => addCalendarDays(weekStart, i));
    final occurrences = view.occurrencesForQuery(
      filter.toQuery(
        startInclusive: weekStart,
        endExclusive: addCalendarDays(weekStart, customDayCount ?? 7),
      ),
    );
    return _CalendarTimeline(
      snapshot: _projection.project(
        occurrences: occurrences,
        days: days,
        startHour: view.data.dayStartHour,
        endHour: view.data.dayEndHour,
      ),
      focusRevision: view.focusRevision,
      enableLongPressAddEvent: view.data.enableLongPressAddEvent,
      viewport: viewport,
      viewportActive: viewportActive,
      selectedDate: selectedDate,
      startHour: view.data.dayStartHour,
      endHour: view.data.dayEndHour,
      gridMinutes: view.data.timeGridMinutes,
      hourHeight: view.data.timeGridHourHeight.toDouble(),
      showHeader: true,
      fitWeekColumnsToWidth: view.data.fitWeekColumnsToWidth,
      customDayMinWidth: customDayCount == null
          ? null
          : view.data.customDayMinWidth,
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
    required this.view,
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
  final GeneralViewState view;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final int syncRevision;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageSettled;
  final void Function(DateTime date, Rect? anchor)? onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;
  final _GeneralOccurrencesTap onMoreOccurrencesTap;
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
    _showWeekends = widget.view.data.showWeekends;
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
    final showWeekendsChanged = _showWeekends != widget.view.data.showWeekends;
    _showWeekends = widget.view.data.showWeekends;
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
    if (widget.view.data.showWeekends) {
      return _generalTimelineInitialPage +
          calendarDaysBetween(_baseDate, selectedDate);
    }
    return _generalTimelineInitialPage +
        _visibleDayDifference(_baseDate, selectedDate);
  }

  DateTime _dayForPage(int page) {
    final deltaDays = page - _generalTimelineInitialPage;
    if (widget.view.data.showWeekends) {
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
    return widget.view.data.showWeekends || date.weekday <= DateTime.friday;
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
          showWeekends: widget.view.data.showWeekends,
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
                  view: widget.view,
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

class _DayTimelinePage extends StatefulWidget {
  const _DayTimelinePage({
    required this.date,
    required this.view,
    required this.filter,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
    required this.onAllDayCollapsedGroupTap,
    required this.allDayTimelineCollapsed,
    required this.onAllDayTimelineCollapsedChanged,
  });

  final DateTime date;
  final GeneralViewState view;
  final _GeneralOccurrenceFilter filter;
  final void Function(DateTime date, Rect? anchor)? onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;
  final _GeneralOccurrencesTap onMoreOccurrencesTap;
  final _AllDayCollapsedGroupTap onAllDayCollapsedGroupTap;
  final bool allDayTimelineCollapsed;
  final ValueChanged<bool> onAllDayTimelineCollapsedChanged;

  @override
  State<_DayTimelinePage> createState() => _DayTimelinePageState();
}

class _DayTimelinePageState extends State<_DayTimelinePage> {
  final _projection = GeneralTimelineProjectionCache();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.view,
    builder: (context, _) => _buildTimeline(context),
  );

  Widget _buildTimeline(BuildContext context) {
    final _DayTimelinePage(
      :date,
      :view,
      :filter,
      :onEmptySlotTap,
      :onOccurrenceTap,
      :onMoreOccurrencesTap,
      :onAllDayCollapsedGroupTap,
      :allDayTimelineCollapsed,
      :onAllDayTimelineCollapsedChanged,
    ) = widget;
    final day = normalizeDateOnly(date);
    final occurrences = view.occurrencesForQuery(
      filter.toQuery(
        startInclusive: day,
        endExclusive: calendarDateEndExclusive(day),
      ),
    );
    return _CalendarTimeline(
      snapshot: _projection.project(
        occurrences: occurrences,
        days: [day],
        startHour: view.data.dayStartHour,
        endHour: view.data.dayEndHour,
      ),
      focusRevision: view.focusRevision,
      enableLongPressAddEvent: view.data.enableLongPressAddEvent,
      selectedDate: day,
      startHour: view.data.dayStartHour,
      endHour: view.data.dayEndHour,
      gridMinutes: view.data.timeGridMinutes,
      hourHeight: view.data.timeGridHourHeight.toDouble(),
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
    required this.snapshot,
    required this.focusRevision,
    required this.enableLongPressAddEvent,
    this.viewport,
    this.viewportActive = true,
    required this.selectedDate,
    required this.startHour,
    required this.endHour,
    required this.gridMinutes,
    required this.hourHeight,
    required this.showHeader,
    this.fitWeekColumnsToWidth = false,
    this.customDayMinWidth,
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
  final GeneralTimelineSnapshot snapshot;
  final int focusRevision;
  final bool enableLongPressAddEvent;
  List<DateTime> get days => snapshot.days;
  final DateTime selectedDate;
  final int startHour;
  final int endHour;
  final int gridMinutes;
  final double hourHeight;
  final bool showHeader;
  final bool fitWeekColumnsToWidth;
  final int? customDayMinWidth;
  final ValueChanged<DateTime>? onDaySelected;
  final void Function(DateTime date, Rect? anchor)? onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;
  final _GeneralOccurrencesTap onMoreOccurrencesTap;
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
    final allDayLayout = _AllDayTimelineLayout(snapshot.allDay);
    final allDayCount = allDayLayout.segments.length;
    final hasAllDayOccurrences = allDayCount > 0;
    final canCollapseAllDay = allDayCount > 1;
    final isAllDayCollapsed = canCollapseAllDay && allDayTimelineCollapsed;
    final timeline = DesktopResizableRegion(
      layoutKey: DesktopLayoutRegion.allDayTimeline,
      axis: Axis.vertical,
      builder: (context, preferred, update, commit, reset) => LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _TimelineMetrics.forViewport(
            context,
            constraints.maxWidth,
            dayCount: days.length,
            fitWeekColumnsToWidth: fitWeekColumnsToWidth,
            customDayMinWidth: customDayMinWidth,
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
          final resizeMaximumHeight = math.max(
            allDayLayout.heightFor(context, collapsed: true),
            constraints.maxHeight - headerHeight - 1 - 96,
          );
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
                focusRevision: focusRevision,
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
                        // The child owns a known-height animation. Keep this
                        // wrapper stable throughout an active mouse gesture.
                        ClipRect(
                          key: const ValueKey('general-all-day-transition'),
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
                            preferredHeight: preferred == null
                                ? null
                                : preferred * textFactor,
                            resizeMaximumHeight: resizeMaximumHeight,
                            onResize:
                                WorkbenchLayoutPolicy.pointerLayout(context)
                                ? (height) => update(height / textFactor)
                                : null,
                            onResizeEnd: commit,
                            onResetSize: reset,
                            collapsed: isAllDayCollapsed,
                            canCollapse: canCollapseAllDay,
                            onToggleCollapsed: canCollapseAllDay
                                ? () => onAllDayTimelineCollapsedChanged(
                                    !isAllDayCollapsed,
                                  )
                                : null,
                            onOccurrenceTap: onOccurrenceTap,
                            onCollapsedGroupTap: (group, anchor) =>
                                onAllDayCollapsedGroupTap(
                                  group.occurrences,
                                  days[group.dayIndex],
                                  anchor,
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
                                for (
                                  var index = 0;
                                  index < days.length;
                                  index++
                                )
                                  PositionedDirectional(
                                    start:
                                        metrics.timeColumnWidth +
                                        index * metrics.dayWidth,
                                    top: labelPadding,
                                    width: metrics.dayWidth,
                                    height: gridHeight,
                                    child: Semantics(
                                      container: true,
                                      label:
                                          onEmptySlotTap != null &&
                                              enableLongPressAddEvent
                                          ? '${MaterialLocalizations.of(context).formatFullDate(days[index])}, ${l10n.addEvent}'
                                          : null,
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
                                                  Rect.fromLTWH(
                                                    details.globalPosition.dx -
                                                        details
                                                            .localPosition
                                                            .dx,
                                                    details.globalPosition.dy -
                                                        details
                                                            .localPosition
                                                            .dy +
                                                        (minutes -
                                                                startMinutes) *
                                                            minuteHeight,
                                                    metrics.dayWidth,
                                                    gridMinutes * minuteHeight,
                                                  ),
                                                );
                                              },
                                        onLongPressStart:
                                            onEmptySlotTap == null ||
                                                !enableLongPressAddEvent
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
                                                  Rect.fromLTWH(
                                                    details.globalPosition.dx -
                                                        details
                                                            .localPosition
                                                            .dx,
                                                    details.globalPosition.dy -
                                                        details
                                                            .localPosition
                                                            .dy +
                                                        (minutes -
                                                                startMinutes) *
                                                            minuteHeight,
                                                    metrics.dayWidth,
                                                    gridMinutes * minuteHeight,
                                                  ),
                                                );
                                              },
                                      ),
                                    ),
                                  ),
                                for (
                                  var index = 0;
                                  index < days.length;
                                  index++
                                )
                                  ..._timedOccurrenceCards(
                                    context: context,
                                    start:
                                        metrics.timeColumnWidth +
                                        index * metrics.dayWidth,
                                    width: metrics.dayWidth,
                                    startMinutes: startMinutes,
                                    minuteHeight: minuteHeight,
                                    topOffset: labelPadding,
                                    groups: snapshot.timedFor(days[index]),
                                  ),
                                for (
                                  var index = 0;
                                  index < days.length;
                                  index++
                                )
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
      ),
    );
    final hasOccurrences =
        hasAllDayOccurrences ||
        snapshot.timedByDate.values.any((groups) => groups.isNotEmpty);
    if (!hasOccurrences) return timeline;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Builder(
            builder: (anchor) => OutlinedButton.icon(
              key: const ValueKey('general-timeline-expand-events'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.view_agenda_outlined),
              label: Text(l10n.expandTimelineEvents),
              onPressed: viewportActive
                  ? () => onMoreOccurrencesTap(
                      _expandedOccurrences(),
                      anchor,
                      timelineDays: days,
                    )
                  : null,
            ),
          ),
        ),
        Expanded(child: timeline),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the new entry in the same short-window escape path as the grid.
        // Its real target must not shrink when landscape or an IME takes space.
        final minimumHeight = 96 + 48 * textFactor + 4;
        if (constraints.maxHeight >= minimumHeight) return content;
        return SingleChildScrollView(
          key: const ValueKey('general-timeline-entry-height-scroll'),
          primary: false,
          child: SizedBox(height: minimumHeight, child: content),
        );
      },
    );
  }

  List<GeneralEventOccurrence> _expandedOccurrences() {
    // Include every displayed overlap column and all-day lane, including those
    // collapsed into a count chip. Distinct recurrence instances stay distinct.
    final unique = <String, GeneralEventOccurrence>{};
    for (final segment in snapshot.allDay.segments) {
      unique[segment.occurrence.occurrenceKey] = segment.occurrence;
    }
    for (final groups in snapshot.timedByDate.values) {
      for (final group in groups) {
        for (final event in group.events) {
          unique[event.span.value.occurrenceKey] = event.span.value;
        }
      }
    }
    return List.unmodifiable(unique.values);
  }

  Iterable<Widget> _timedOccurrenceCards({
    required BuildContext context,
    required List<TimelineEventGroup<GeneralEventOccurrence>> groups,
    required double start,
    required double width,
    required int startMinutes,
    required double minuteHeight,
    required double topOffset,
  }) sync* {
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
          child: Builder(
            builder: (anchor) => _OccurrenceCard(
              occurrence: span.value,
              dense: cardHeight < 52 * textScale,
              narrow: budget.columnWidth < 64 * textScale,
              compactStrip: cardHeight < 18 * textScale,
              overlapping: group.columnCount > 1,
              onTap: () => onOccurrenceTap(span.value, anchor),
            ),
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
          child: Builder(
            builder: (anchor) => _MoreOccurrencesCard(
              occurrence: first.value,
              count: hidden.length,
              compactStrip: badgeHeight < 18 * textScale,
              onTap: () => onMoreOccurrencesTap([
                for (final event in group.events) event.span.value,
              ], anchor),
            ),
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
  const _AllDayTimelineLayout(this.projection);

  final GeneralAllDayProjection projection;
  static const double verticalPadding = 4;
  static const double laneGap = 3;
  List<GeneralAllDaySegment> get segments => projection.segments;
  List<GeneralAllDaySegment> get visibleSegments => projection.visibleSegments;
  List<GeneralAllDayCollapsedGroup> get collapsedGroups =>
      projection.collapsedGroups;
  int get visibleLaneCount => projection.visibleLaneCount;
  int get laneCount => projection.laneCount;
  int get hiddenCount => projection.hiddenCount;

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

typedef _AllDayCollapsedGroup = GeneralAllDayCollapsedGroup;

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
    int? customDayMinWidth,
  }) {
    final scale = WorkbenchLayoutPolicy.textFactor(
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final compact = WorkbenchChromeMetrics.compactTouch(context, width: width);
    final rail = compact
        ? _TimelineTimeRuler.measuredWidth(context)
        : 64 * scale;
    final fit =
        customDayMinWidth == null &&
        compact &&
        fitWeekColumnsToWidth &&
        dayCount <= 7;
    final minimumDayWidth =
        (customDayMinWidth ?? generalCustomDayMinWidthDefault) * scale;
    return _TimelineMetrics.fromWidth(
      fit ? width : math.max(width, rail + dayCount * minimumDayWidth),
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
      // Preserve the fractional leading date, not its old pixel offset. The
      // pinned time rail stays fixed while all three date layers resize together.
      final anchorOffset =
          !replaced &&
              oldWidget.active &&
              widget.active &&
              oldWidget.dayWidth > 0 &&
              _controller.hasClients
          ? _controller.offset / oldWidget.dayWidth * widget.dayWidth
          : null;
      _scheduleReveal(
        resetOffset: replaced || !oldWidget.active,
        anchorOffset: anchorOffset,
      );
    }
  }

  void _scheduleReveal({bool resetOffset = false, double? anchorOffset}) {
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
      if (!resetOffset && anchorOffset != null) {
        final target = anchorOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((target - _controller.offset).abs() > .01) {
          _controller.jumpTo(target);
        }
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
      final scrollView = SingleChildScrollView(
        key: const ValueKey('general-timeline-horizontal-scroll'),
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: overflow
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: widget.child),
      );
      return _TimelineHorizontalScope(
        controller: _controller,
        child: WorkbenchChromeMetrics.of(context).desktop
            ? Scrollbar(
                controller: _controller,
                thumbVisibility: overflow,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: scrollView,
              )
            : ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: scrollView,
              ),
      );
    },
  );
}
