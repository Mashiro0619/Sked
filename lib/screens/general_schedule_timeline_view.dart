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

class _WeekCalendarView extends StatefulWidget {
  const _WeekCalendarView({
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

  @override
  State<_WeekCalendarView> createState() => _WeekCalendarViewState();
}

class _WeekCalendarViewState extends State<_WeekCalendarView> {
  late final DateTime _baseWeekStart;
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
    _baseWeekStart = startOfWeekMonday(_visibleDayForDate(widget.date));
    _settledPage = _generalTimelineInitialPage;
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
    if (_sameDay(oldWidget.date, widget.date) &&
        oldWidget.syncRevision == widget.syncRevision) {
      return;
    }
    final targetPage = _pageForWeek(
      startOfWeekMonday(_visibleDayForDate(widget.date)),
    );
    if (targetPage != _settledPage) {
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
    return _generalTimelineInitialPage + deltaDays ~/ 7;
  }

  DateTime _weekStartForPage(int page) {
    final deltaWeeks = page - _generalTimelineInitialPage;
    return addCalendarDays(_baseWeekStart, deltaWeeks * 7);
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

  int _selectedWeekdayOffset() {
    final selected = _visibleDayForDate(widget.date);
    return calendarDaysBetween(startOfWeekMonday(selected), selected);
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
    widget.onPageSettled(addCalendarDays(nextDate, _selectedWeekdayOffset()));
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics is PageMetrics) {
          if (notification.depth == 0 &&
              notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _pageScrolling = true;
          } else if (_pageScrolling && notification is ScrollEndNotification) {
            _handlePageSettled(notification);
          }
        }
        return false;
      },
      child: PageView.builder(
        key: _generalWeekPagerKey,
        controller: _controller,
        physics: widget.active
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final weekStart = _weekStartForPage(index);
          return _WeekTimelinePage(
            weekStart: weekStart,
            selectedDate: addCalendarDays(weekStart, _selectedWeekdayOffset()),
            provider: widget.provider,
            filter: widget.filter,
            onEmptySlotTap: widget.onEmptySlotTap,
            onOccurrenceTap: widget.onOccurrenceTap,
            onMoreOccurrencesTap: widget.onMoreOccurrencesTap,
          );
        },
      ),
    );
  }
}

class _WeekTimelinePage extends StatelessWidget {
  const _WeekTimelinePage({
    required this.weekStart,
    required this.selectedDate,
    required this.provider,
    required this.filter,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
  });

  final DateTime weekStart;
  final DateTime selectedDate;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;

  @override
  Widget build(BuildContext context) {
    final days = _visibleWeekDays(weekStart, provider.generalShowWeekends);
    final occurrences = provider.generalOccurrencesForQuery(
      filter.toQuery(
        startInclusive: weekStart,
        endExclusive: addCalendarDays(weekStart, 7),
      ),
    );
    return _CalendarTimeline(
      days: days,
      selectedDate: selectedDate,
      occurrences: occurrences,
      startHour: provider.generalDayStartHour,
      endHour: provider.generalDayEndHour,
      gridMinutes: provider.generalTimeGridMinutes,
      hourHeight: provider.generalTimeGridHourHeight.toDouble(),
      showHeader: true,
      onEmptySlotTap: onEmptySlotTap,
      onOccurrenceTap: onOccurrenceTap,
      onMoreOccurrencesTap: onMoreOccurrencesTap,
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
  });

  final DateTime date;
  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;

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
          height: 66,
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
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = _sameDay(date, DateTime.now());
    final background = selected
        ? colorScheme.primary.withValues(alpha: 0.20)
        : isToday
        ? colorScheme.primary.withValues(alpha: 0.14)
        : Colors.transparent;
    final foreground = selected
        ? colorScheme.primary
        : isToday
        ? colorScheme.primary
        : colorScheme.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _weekdayLabel(context, date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date.day.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: selected || isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
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

class _CalendarTimeline extends StatelessWidget {
  const _CalendarTimeline({
    required this.days,
    required this.selectedDate,
    required this.occurrences,
    required this.startHour,
    required this.endHour,
    required this.gridMinutes,
    required this.hourHeight,
    required this.showHeader,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
    required this.onMoreOccurrencesTap,
  });

  static const double _headerHeight = 56;
  static const double _allDayHeight = 74;
  static const double _timeLabelVerticalPadding = 12;

  final List<DateTime> days;
  final DateTime selectedDate;
  final List<GeneralEventOccurrence> occurrences;
  final int startHour;
  final int endHour;
  final int gridMinutes;
  final double hourHeight;
  final bool showHeader;
  final ValueChanged<DateTime>? onEmptySlotTap;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final ValueChanged<List<GeneralEventOccurrence>> onMoreOccurrencesTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    final startMinutes = startHour * 60;
    final endMinutes = endHour * 60;
    final safeHourHeight = hourHeight.clamp(
      generalTimeGridHourHeightMin.toDouble(),
      generalTimeGridHourHeightMax.toDouble(),
    );
    final gridHeight = math.max(1, endHour - startHour) * safeHourHeight;
    final contentHeight = gridHeight + _timeLabelVerticalPadding * 2;
    final minuteHeight = safeHourHeight / 60;
    final occurrenceIndex = _TimelineOccurrenceIndex.build(occurrences, days);
    final allDayOccurrencesByDay = [
      for (final day in days) occurrenceIndex.allDayFor(day),
    ];
    final hasAllDayOccurrences = allDayOccurrencesByDay.any(
      (items) => items.isNotEmpty,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _TimelineMetrics.fromWidth(
          constraints.maxWidth,
          dayCount: days.length,
        );

        return SizedBox(
          width: metrics.totalWidth,
          child: Column(
            children: [
              if (showHeader)
                SizedBox(
                  height: _headerHeight,
                  child: Row(
                    children: [
                      _MonthRail(date: selectedDate),
                      for (final day in days)
                        _DayHeader(
                          date: day,
                          width: metrics.dayWidth,
                          selected: false,
                          onTap: null,
                        ),
                    ],
                  ),
                ),
              if (hasAllDayOccurrences)
                SizedBox(
                  height: _allDayHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TimelineTimeRailLabel(
                        width: metrics.timeColumnWidth,
                        child: Text(
                          l10n.allDay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      for (var index = 0; index < days.length; index++)
                        _AllDayColumn(
                          date: days[index],
                          width: metrics.dayWidth,
                          occurrences: allDayOccurrencesByDay[index],
                          onTap: onOccurrenceTap,
                        ),
                    ],
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
                  hourHeight: safeHourHeight,
                  topOffset: _timeLabelVerticalPadding,
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
                          topOffset: _timeLabelVerticalPadding,
                        ),
                        for (var index = 0; index < days.length; index++)
                          PositionedDirectional(
                            start:
                                metrics.timeColumnWidth +
                                index * metrics.dayWidth,
                            top: _timeLabelVerticalPadding,
                            width: metrics.dayWidth,
                            height: gridHeight,
                            child: GestureDetector(
                              key: ValueKey(
                                'general-timeline-empty-slot-${_dateKey(days[index])}',
                              ),
                              behavior: HitTestBehavior.translucent,
                              onLongPressStart: onEmptySlotTap == null
                                  ? null
                                  : (details) {
                                      final minutes =
                                          _snapMinutes(
                                                startMinutes +
                                                    (details.localPosition.dy /
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
                            topOffset: _timeLabelVerticalPadding,
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
                                  _timeLabelVerticalPadding +
                                  (_nowMinutes() - startMinutes) * minuteHeight,
                              width: metrics.dayWidth,
                              child: const _NowLine(),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
    final layouts = _layoutTimedOccurrenceSegments(
      _collapseCrowdedTimedOccurrenceSegments(segments),
    );
    for (final layout in layouts) {
      final segmentHeight =
          (layout.endMinutes - layout.startMinutes) * minuteHeight;
      if (segmentHeight <= 0) {
        continue;
      }
      final verticalInset = math.min(2.0, segmentHeight / 4);
      // Keep the visual card inside its actual time segment. In particular,
      // do not impose a pixel minimum that could overlap an adjacent event.
      final cardHeight = segmentHeight - verticalInset * 2;
      final compactStrip = cardHeight < 24;
      const laneGap = 2.0;
      final horizontalInset = width < 52 ? 2.0 : 4.0;
      final availableWidth = math.max(1.0, width - horizontalInset * 2);
      final laneWidth = math.max(
        1.0,
        (availableWidth - laneGap * (layout.laneCount - 1)) / layout.laneCount,
      );
      final laneLeftOffset = layout.lane * (laneWidth + laneGap);
      yield PositionedDirectional(
        start: start + horizontalInset + laneLeftOffset,
        top:
            topOffset +
            (layout.startMinutes - startMinutes) * minuteHeight +
            verticalInset,
        width: laneWidth,
        height: cardHeight,
        child: layout.isMore
            ? _MoreOccurrencesCard(
                occurrence: layout.occurrence,
                count: layout.moreCount,
                dense: cardHeight < 56 || laneWidth < 44,
                narrow: laneWidth < 44,
                compactStrip: compactStrip,
                overlapping: layout.laneCount > 1,
                onTap: () => onMoreOccurrencesTap(layout.moreOccurrences!),
              )
            : _OccurrenceCard(
                occurrence: layout.occurrence,
                dense: cardHeight < 56 || laneWidth < 44,
                narrow: laneWidth < 44,
                compactStrip: compactStrip,
                overlapping: layout.laneCount > 1,
                onTap: () => onOccurrenceTap(layout.occurrence),
              ),
      );
    }
  }
}

class _TimelineVerticalScrollViewport extends StatefulWidget {
  const _TimelineVerticalScrollViewport({
    required this.hourHeight,
    required this.topOffset,
    required this.child,
  });

  final double hourHeight;
  final double topOffset;
  final Widget child;

  @override
  State<_TimelineVerticalScrollViewport> createState() =>
      _TimelineVerticalScrollViewportState();
}

class _TimelineVerticalScrollViewportState
    extends State<_TimelineVerticalScrollViewport> {
  final ScrollController _controller = ScrollController();
  int _anchorGeneration = 0;

  @override
  void didUpdateWidget(covariant _TimelineVerticalScrollViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      padding: const EdgeInsets.only(bottom: 96),
      child: widget.child,
    );
  }
}

class _TimelineOccurrenceIndex {
  const _TimelineOccurrenceIndex({
    required this.allDayByDate,
    required this.timedByDate,
  });

  final Map<String, List<GeneralEventOccurrence>> allDayByDate;
  final Map<String, List<GeneralEventOccurrence>> timedByDate;

  factory _TimelineOccurrenceIndex.build(
    List<GeneralEventOccurrence> occurrences,
    List<DateTime> days,
  ) {
    final allDayByDate = <String, List<GeneralEventOccurrence>>{};
    final timedByDate = <String, List<GeneralEventOccurrence>>{};
    if (days.isEmpty) {
      return _TimelineOccurrenceIndex(
        allDayByDate: allDayByDate,
        timedByDate: timedByDate,
      );
    }

    for (final day in days) {
      final key = _calendarDateKey(day);
      allDayByDate[key] = [];
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
        var bucketDay = normalizeDateOnly(displayStart);
        if (bucketDay.isBefore(firstDay)) {
          bucketDay = firstDay;
        }
        var lastBucketDay = normalizeDateOnly(
          displayEnd.subtract(const Duration(microseconds: 1)),
        );
        if (lastBucketDay.isAfter(lastDay)) {
          lastBucketDay = lastDay;
        }
        for (
          var day = bucketDay;
          !day.isAfter(lastBucketDay);
          day = nextCalendarDate(day)
        ) {
          allDayByDate[_calendarDateKey(day)]?.add(occurrence);
        }
        continue;
      }

      timedByDate[_calendarDateKey(displayStart)]?.add(occurrence);
    }

    return _TimelineOccurrenceIndex(
      allDayByDate: allDayByDate,
      timedByDate: timedByDate,
    );
  }

  List<GeneralEventOccurrence> allDayFor(DateTime day) =>
      allDayByDate[_calendarDateKey(day)] ?? const [];

  List<GeneralEventOccurrence> timedFor(DateTime day) =>
      timedByDate[_calendarDateKey(day)] ?? const [];
}

class _TimelineMetrics {
  const _TimelineMetrics({
    required this.totalWidth,
    required this.timeColumnWidth,
    required this.dayWidth,
  });

  static const monthRailWidth = 52.0;

  final double totalWidth;
  final double timeColumnWidth;
  final double dayWidth;

  factory _TimelineMetrics.fromWidth(double width, {required int dayCount}) {
    final safeWidth = width.isFinite && width > 0 ? width : 360.0;
    const timeColumnWidth = monthRailWidth;
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
  const _MonthRail({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _TimelineMetrics.monthRailWidth,
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
  _TimedOccurrenceSegment({
    required this.occurrence,
    required this.startMinutes,
    required this.endMinutes,
  }) : moreOccurrences = null;

  _TimedOccurrenceSegment.more({
    required List<GeneralEventOccurrence> occurrences,
    required this.startMinutes,
    required this.endMinutes,
  }) : occurrence = occurrences.first,
       moreOccurrences = List.unmodifiable(occurrences);

  final GeneralEventOccurrence occurrence;
  final List<GeneralEventOccurrence>? moreOccurrences;
  final int startMinutes;
  final int endMinutes;
  int lane = 0;
  int laneCount = 1;

  bool get isMore => moreOccurrences != null;

  int get moreCount =>
      moreOccurrences == null ? 0 : moreOccurrences!.length - 1;
}

List<_TimedOccurrenceSegment> _collapseCrowdedTimedOccurrenceSegments(
  List<_TimedOccurrenceSegment> segments,
) {
  if (segments.length < 3) {
    return segments;
  }

  final sorted = [...segments]..sort(_compareTimedOccurrenceSegments);
  final groups = <List<_TimedOccurrenceSegment>>[];
  var currentGroup = <_TimedOccurrenceSegment>[];
  var currentGroupEnd = -1;
  for (final segment in sorted) {
    if (currentGroup.isEmpty || segment.startMinutes < currentGroupEnd) {
      currentGroup.add(segment);
      currentGroupEnd = math.max(currentGroupEnd, segment.endMinutes);
    } else {
      groups.add(currentGroup);
      currentGroup = [segment];
      currentGroupEnd = segment.endMinutes;
    }
  }
  if (currentGroup.isNotEmpty) {
    groups.add(currentGroup);
  }

  final collapsed = <_TimedOccurrenceSegment>[];
  for (final group in groups) {
    if (group.length < 3 || _maxConcurrentTimedSegments(group) < 3) {
      collapsed.addAll(group);
      continue;
    }

    final primary = _primaryTimedOccurrenceSegment(group);
    final hidden =
        group.where((segment) => !identical(segment, primary)).toList()
          ..sort(_compareTimedOccurrenceSegments);
    collapsed
      ..add(primary)
      ..add(
        _TimedOccurrenceSegment.more(
          occurrences: [
            primary.occurrence,
            for (final segment in hidden) segment.occurrence,
          ],
          startMinutes: primary.startMinutes,
          endMinutes: primary.endMinutes,
        ),
      );
  }
  return collapsed;
}

int _maxConcurrentTimedSegments(List<_TimedOccurrenceSegment> segments) {
  final points = <int>[];
  for (final segment in segments) {
    points
      ..add(segment.startMinutes * 2 + 1)
      ..add(segment.endMinutes * 2);
  }
  points.sort();

  var active = 0;
  var maxActive = 0;
  for (final point in points) {
    active += point.isOdd ? 1 : -1;
    maxActive = math.max(maxActive, active);
  }
  return maxActive;
}

_TimedOccurrenceSegment _primaryTimedOccurrenceSegment(
  List<_TimedOccurrenceSegment> segments,
) {
  final sorted = [...segments]
    ..sort((a, b) {
      final durationCompare = (b.endMinutes - b.startMinutes).compareTo(
        a.endMinutes - a.startMinutes,
      );
      if (durationCompare != 0) return durationCompare;
      return _compareTimedOccurrenceSegments(a, b);
    });
  return sorted.first;
}

List<_TimedOccurrenceSegment> _layoutTimedOccurrenceSegments(
  List<_TimedOccurrenceSegment> segments,
) {
  if (segments.isEmpty) {
    return segments;
  }
  final sorted = [...segments]..sort(_compareTimedOccurrenceSegments);

  final groups = <List<_TimedOccurrenceSegment>>[];
  var currentGroup = <_TimedOccurrenceSegment>[];
  var currentGroupEnd = -1;
  for (final segment in sorted) {
    if (currentGroup.isEmpty || segment.startMinutes < currentGroupEnd) {
      currentGroup.add(segment);
      currentGroupEnd = math.max(currentGroupEnd, segment.endMinutes);
    } else {
      groups.add(currentGroup);
      currentGroup = [segment];
      currentGroupEnd = segment.endMinutes;
    }
  }
  if (currentGroup.isNotEmpty) {
    groups.add(currentGroup);
  }

  for (final group in groups) {
    final laneEnds = <int>[];
    for (final segment in group) {
      var lane = laneEnds.indexWhere((end) => end <= segment.startMinutes);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(segment.endMinutes);
      } else {
        laneEnds[lane] = segment.endMinutes;
      }
      segment.lane = lane;
    }
    for (final segment in group) {
      segment.laneCount = laneEnds.length;
    }
  }

  return sorted;
}

int _compareTimedOccurrenceSegments(
  _TimedOccurrenceSegment a,
  _TimedOccurrenceSegment b,
) {
  final startCompare = a.startMinutes.compareTo(b.startMinutes);
  if (startCompare != 0) return startCompare;
  final endCompare = a.endMinutes.compareTo(b.endMinutes);
  if (endCompare != 0) return endCompare;
  if (a.isMore != b.isMore) {
    return a.isMore ? 1 : -1;
  }
  final titleCompare = a.occurrence.event.title.compareTo(
    b.occurrence.event.title,
  );
  if (titleCompare != 0) return titleCompare;
  return a.occurrence.event.id.compareTo(b.occurrence.event.id);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = _sameDay(date, DateTime.now());
    final background = selected
        ? colorScheme.primary.withValues(alpha: 0.20)
        : Colors.transparent;
    final foreground = selected
        ? colorScheme.primary
        : isToday
        ? colorScheme.primary
        : colorScheme.onSurface;
    return SizedBox(
      key: ValueKey('general-week-day-header-${_dateKey(date)}'),
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !selected
                  ? Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.52),
                    )
                  : null,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weekdayLabel(context, date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date.day.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected || isToday
                            ? FontWeight.w700
                            : FontWeight.w500,
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
