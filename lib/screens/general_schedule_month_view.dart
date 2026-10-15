part of 'general_schedule_home_screen.dart';

bool workspaceMonthCanSplit(BuildContext context, double width) =>
    WorkspaceCanvasScope.maybeOf(context) == null &&
    WorkbenchLayoutPolicy.formCanSplit(
      width,
      MediaQuery.textScalerOf(context).scale(14) / 14,
      navigation: 320,
      content: 600,
    );

const _monthGridSpacing = 1.0;

const _generalMonthCompactSelectedDayFeedbackKey = ValueKey<String>(
  'general-month-compact-selected-day-feedback',
);
const _generalMonthCompactAgendaKey = ValueKey<String>(
  'general-month-compact-agenda',
);

double _monthCellHeightForWidth(double cellWidth, {required bool compact}) {
  final preferred = cellWidth * (compact ? 0.58 : 0.62);
  final minHeight = compact ? 48.0 : 64.0;
  final maxHeight = compact ? 64.0 : 82.0;
  return preferred.clamp(minHeight, maxHeight).toDouble();
}

TextStyle _compactMonthDateStyle(BuildContext context) =>
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 16))
        .copyWith(height: 1.2, fontWeight: FontWeight.w500);

double _monthTextHeight(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

int _compactMonthLunarLines(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(11) > 11 * 1.3 ? 2 : 1;

double _compactMonthDateStackHeight(BuildContext context, bool lunar) =>
    _monthTextHeight(context, '28', _compactMonthDateStyle(context)) +
    (lunar
        ? 1 +
              _compactMonthLunarLines(context) *
                  _monthTextHeight(
                    context,
                    '廿八',
                    const TextStyle(
                      fontSize: 11,
                      height: 1.05,
                      fontWeight: FontWeight.w500,
                    ),
                  )
        : 0);

double _monthMinimumCellHeight(
  BuildContext context, {
  required bool showLunarCalendar,
  bool compact = false,
}) {
  if (!compact) {
    final scale = WorkbenchLayoutPolicy.textFactor(
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    return (showLunarCalendar ? 72.0 : 68.0) * scale;
  }
  // Date/lunar text, selection padding and a reserved marker row share one
  // measured budget. Large fonts grow the row, never shrink the glyphs.
  return math.max(
    showLunarCalendar ? 56 : 48,
    _compactMonthDateStackHeight(context, showLunarCalendar) + 18,
  );
}

class _MonthCalendarSource extends StatefulWidget {
  const _MonthCalendarSource({
    required this.date,
    required this.view,
    required this.localeCode,
    required this.filter,
    required this.active,
    required this.onDaySelected,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final GeneralViewState view;
  final String localeCode;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final ValueChanged<DateTime> onDaySelected;
  final void Function(DateTime date, Rect? anchor) onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;

  @override
  State<_MonthCalendarSource> createState() => _MonthCalendarSourceState();
}

class _MonthCalendarSourceState extends State<_MonthCalendarSource> {
  final _projection = GeneralMonthProjectionCache();

  @override
  void didUpdateWidget(covariant _MonthCalendarSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.view, oldWidget.view)) _projection.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.view,
    builder: (context, _) => _buildSnapshot(context),
  );

  Widget _buildSnapshot(BuildContext context) {
    final data = widget.view.data;
    var selectedDate = normalizeDateOnly(widget.date);
    if (!data.showWeekends && selectedDate.weekday > DateTime.friday) {
      selectedDate = addCalendarDays(selectedDate, 8 - selectedDate.weekday);
    }
    return _MonthCalendarView(
      date: widget.date,
      snapshot: GeneralMonthViewSnapshot(
        filtered: widget.filter.isActive,
        pages: _projection.project(
          data: data,
          selectedDate: selectedDate,
          queryOccurrences: widget.view.occurrencesForQuery,
          searchQuery: widget.filter.query,
          colorValue: widget.filter.colorValue,
        ),
        display: GeneralMonthDisplaySettings(
          showWeekends: data.showWeekends,
          showLunarCalendar:
              data.showLunarCalendar && widget.localeCode.startsWith('zh'),
          localeCode: widget.localeCode,
        ),
      ),
      active: widget.active,
      onDaySelected: widget.onDaySelected,
      onEmptySlotTap: widget.onEmptySlotTap,
      onOccurrenceTap: widget.onOccurrenceTap,
    );
  }
}

class _MonthCalendarView extends StatefulWidget {
  const _MonthCalendarView({
    required this.date,
    required this.snapshot,
    required this.active,
    required this.onDaySelected,
    required this.onEmptySlotTap,
    required this.onOccurrenceTap,
  });

  final DateTime date;
  final GeneralMonthViewSnapshot snapshot;
  GeneralMonthDisplaySettings get display => snapshot.display;
  final bool active;
  final ValueChanged<DateTime> onDaySelected;
  final void Function(DateTime date, Rect? anchor) onEmptySlotTap;
  final _GeneralOccurrenceTap onOccurrenceTap;

  @override
  State<_MonthCalendarView> createState() => _MonthCalendarViewState();
}

class _MonthCalendarViewState extends State<_MonthCalendarView> {
  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
  final ScrollController _compactScrollController = ScrollController();
  bool _calendarRevealScheduled = false;

  @override
  void dispose() {
    _compactScrollController.dispose();
    super.dispose();
  }

  DateTime _visibleDayForDate(DateTime date, {int direction = 1}) {
    final normalized = normalizeDateOnly(date);
    if (widget.display.showWeekends || normalized.weekday <= DateTime.friday) {
      return normalized;
    }
    return addCalendarDays(
      normalized,
      direction < 0
          ? DateTime.friday - normalized.weekday
          : 8 - normalized.weekday,
    );
  }

  void _selectDay(DateTime nextDate) {
    final selectedDate = _visibleDayForDate(nextDate);
    widget.onDaySelected(selectedDate);
  }

  void _scheduleCalendarReveal() {
    if (!widget.active || _calendarRevealScheduled) return;
    final workspace = WorkspaceCanvasScope.maybeOf(context);
    if (workspace?.supporting == true ||
        workspace?.dockedDetail == true ||
        workspace?.dockedAssistant == true) {
      return;
    }
    _calendarRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calendarRevealScheduled = false;
      if (!mounted || !widget.active || !_compactScrollController.hasClients) {
        return;
      }
      // Only month navigation reveals the calendar. Selecting another day in
      // the same month must not pull the agenda away from the user's viewport.
      unawaited(
        _compactScrollController.animateTo(
          _compactScrollController.position.minScrollExtent,
          duration: SkedMotionPolicy.of(context).effects(SkedMotionSpeed.fast),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant _MonthCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active &&
        (widget.date.year != oldWidget.date.year ||
            widget.date.month != oldWidget.date.month)) {
      _scheduleCalendarReveal();
    }
  }

  DateTime _monthWithDay(
    DateTime baseDate,
    int year,
    int month, {
    int direction = 1,
  }) {
    final target = DateTime(
      year,
      month,
      baseDate.day.clamp(1, _daysInMonth(year, month)),
    );
    return _visibleDayForDate(target, direction: direction);
  }

  void _goToPreviousMonth() {
    final selectedDate = _visibleDayForDate(widget.date);
    final prevMonth = selectedDate.month == 1 ? 12 : selectedDate.month - 1;
    final prevYear = selectedDate.month == 1
        ? selectedDate.year - 1
        : selectedDate.year;
    _selectDay(_monthWithDay(selectedDate, prevYear, prevMonth, direction: -1));
  }

  void _goToNextMonth() {
    final selectedDate = _visibleDayForDate(widget.date);
    final nextMonth = selectedDate.month == 12 ? 1 : selectedDate.month + 1;
    final nextYear = selectedDate.month == 12
        ? selectedDate.year + 1
        : selectedDate.year;
    _selectDay(_monthWithDay(selectedDate, nextYear, nextMonth, direction: 1));
  }

  @override
  Widget build(BuildContext context) {
    final today = normalizeDateOnly(DateTime.now());
    final requestedDate = normalizeDateOnly(widget.date);
    final selectedDate = _visibleDayForDate(requestedDate);
    if (widget.active && !_sameDay(selectedDate, requestedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) widget.onDaySelected(selectedDate);
      });
    }
    final pages = widget.snapshot.pages;
    final model = pages.current.model;
    final occurrencesByDay = pages.current.occurrencesByDay;
    final selectedOccurrences =
        occurrencesByDay[_calendarDateKey(selectedDate)] ?? const [];

    return DesktopResizableRegion(
      layoutKey: DesktopLayoutRegion.monthAgenda,
      builder:
          (
            context,
            preferredWidth,
            updateWidth,
            commitWidth,
            resetWidth,
          ) => DesktopResizableRegion(
            layoutKey: DesktopLayoutRegion.monthAgendaBottom,
            axis: Axis.vertical,
            builder:
                (
                  context,
                  preferredHeight,
                  updateHeight,
                  commitHeight,
                  resetHeight,
                ) => LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = WorkbenchChromeMetrics.of(context);
                    final textScale = metrics.textScale;
                    final sideBySide = workspaceMonthCanSplit(
                      context,
                      constraints.maxWidth,
                    );
                    final workspace = WorkspaceCanvasScope.maybeOf(context);
                    Widget calendar({bool inset = false, bool split = false}) =>
                        _MonthCalendarPanel(
                          sharedTopEdge: !inset && workspace != null,
                          sharedStartEdge:
                              !inset && workspace?.resources == true,
                          // The legacy split supplies a real VerticalDivider; task panes
                          // only reserve space, so the calendar owns its trailing outline.
                          sharedEndEdge: !inset && split,
                          model: model,
                          selectedDate: selectedDate,
                          today: today,
                          occurrencesByDay: occurrencesByDay,
                          display: widget.display,
                          previousPage: pages.previous,
                          nextPage: pages.next,
                          onPreviousMonth: _goToPreviousMonth,
                          onNextMonth: _goToNextMonth,
                          onDaySelected: _selectDay,
                        );
                    final agenda = _MonthAgendaPanel(
                      date: selectedDate,
                      occurrences: selectedOccurrences,
                      filtered: widget.snapshot.filtered,
                      onAddEvent: (anchor) => widget.onEmptySlotTap(
                        selectedDate,
                        WorkspaceEditorConfiguration(anchorContext: anchor)
                            .initialAnchor,
                      ),
                      onOccurrenceTap: widget.onOccurrenceTap,
                    );

                    if (workspace?.supporting == true ||
                        workspace?.dockedDetail == true) {
                      return calendar();
                    }
                    if (sideBySide) {
                      final maximumWidth = math.max(
                        AppBreakpoints.minimumDetailPane * textScale,
                        constraints.maxWidth -
                            AppBreakpoints.minimumCanvas * textScale -
                            1,
                      );
                      final agendaWidth = ((preferredWidth ?? 320) * textScale)
                          .clamp(
                            AppBreakpoints.minimumDetailPane * textScale,
                            maximumWidth,
                          );
                      return Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: calendar(split: true)),
                              const VerticalDivider(width: 1),
                              SizedBox(width: agendaWidth, child: agenda),
                            ],
                          ),
                          if (metrics.desktop)
                            PositionedDirectional(
                              end: agendaWidth - 4,
                              top: 0,
                              bottom: 0,
                              width: 9,
                              child: SkedExtentResizeHandle(
                                key: const ValueKey(
                                  'general-month-agenda-resize',
                                ),
                                reverse: true,
                                extent: agendaWidth,
                                minExtent:
                                    AppBreakpoints.minimumDetailPane *
                                    textScale,
                                maxExtent: maximumWidth,
                                onChanged: (extent) =>
                                    updateWidth(extent / textScale),
                                onEnd: commitWidth,
                                onReset: resetWidth,
                              ),
                            ),
                        ],
                      );
                    }

                    final minimumAgendaHeight = metrics.desktop
                        ? metrics.toolbarHeight + 2 * metrics.resourceRowHeight
                        : 240.0 * textScale;
                    final minimumCalendarHeight =
                        model.rowCount *
                            _monthMinimumCellHeight(
                              context,
                              showLunarCalendar:
                                  widget.display.showLunarCalendar,
                            ) +
                        48 * textScale;
                    if (constraints.hasBoundedHeight &&
                        constraints.maxWidth >= AppBreakpoints.minimumCanvas &&
                        constraints.maxHeight >=
                            minimumCalendarHeight + minimumAgendaHeight + 1) {
                      final maximumAgendaHeight =
                          constraints.maxHeight - minimumCalendarHeight - 1;
                      final agendaHeight =
                          ((preferredHeight ?? 240) * textScale).clamp(
                            minimumAgendaHeight,
                            maximumAgendaHeight,
                          );
                      // A portrait workbench has enough height for a real month canvas
                      // even when it cannot dock an agenda beside it. Do not leave half
                      // of that viewport unused by sizing the calendar like a phone card.
                      return Stack(
                        children: [
                          Column(
                            children: [
                              Expanded(child: calendar()),
                              const Divider(height: 1),
                              SizedBox(
                                key: const ValueKey(
                                  'general-month-stacked-agenda',
                                ),
                                height: agendaHeight,
                                child: agenda,
                              ),
                            ],
                          ),
                          if (metrics.desktop)
                            Positioned(
                              bottom: agendaHeight - 4,
                              left: 0,
                              right: 0,
                              height: 9,
                              child: SkedExtentResizeHandle(
                                key: const ValueKey(
                                  'general-month-agenda-height-resize',
                                ),
                                axis: Axis.vertical,
                                reverse: true,
                                extent: agendaHeight,
                                minExtent: minimumAgendaHeight,
                                maxExtent: maximumAgendaHeight,
                                onChanged: (extent) =>
                                    updateHeight(extent / textScale),
                                onEnd: commitHeight,
                                onReset: resetHeight,
                              ),
                            ),
                        ],
                      );
                    }

                    final l = AppLocalizations.of(context);
                    return CustomScrollView(
                      key: const ValueKey('general-month-compact-scroll'),
                      controller: _compactScrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                          sliver: SliverToBoxAdapter(
                            child: calendar(inset: true),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              SliverToBoxAdapter(
                                child: _MonthAgendaHeader(
                                  key: _generalMonthCompactAgendaKey,
                                  date: selectedDate,
                                  count: selectedOccurrences.length,
                                  filtered: widget.snapshot.filtered,
                                  compact: true,
                                  onAddEvent: (anchor) => widget.onEmptySlotTap(
                                    selectedDate,
                                    WorkspaceEditorConfiguration(
                                      anchorContext: anchor,
                                    ).initialAnchor,
                                  ),
                                ),
                              ),
                              if (selectedOccurrences.isEmpty)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      0,
                                      4,
                                      12,
                                    ),
                                    child: Text(
                                      widget.snapshot.filtered
                                          ? l.noMatchingEvents
                                          : l.monthNoEvents,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )
                              else
                                SliverList.builder(
                                  itemCount: selectedOccurrences.length,
                                  itemBuilder: (context, index) => Builder(
                                    builder: (anchor) => _MonthAgendaTile(
                                      occurrence: selectedOccurrences[index],
                                      onTap: () => widget.onOccurrenceTap(
                                        selectedOccurrences[index],
                                        anchor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 88)),
                      ],
                    );
                  },
                ),
          ),
    );
  }
}

class _MonthCalendarPanel extends StatefulWidget {
  const _MonthCalendarPanel({
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.display,
    required this.previousPage,
    required this.nextPage,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
    this.sharedTopEdge = false,
    this.sharedStartEdge = false,
    this.sharedEndEdge = false,
  });

  final GeneralMonthGridModel model;
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final GeneralMonthDisplaySettings display;
  final GeneralMonthPage previousPage, nextPage;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;
  final bool sharedTopEdge, sharedStartEdge, sharedEndEdge;

  @override
  State<_MonthCalendarPanel> createState() => _MonthCalendarPanelState();
}

class _MonthCalendarPanelState extends State<_MonthCalendarPanel>
    with SingleTickerProviderStateMixin {
  static const _pageAnimationDuration = Duration(milliseconds: 260);

  late final AnimationController _dragController;
  late Animation<double> _dragAnimation;
  final _dragPosition = ValueNotifier<double>(0);
  double get _dragOffset => _dragPosition.value;
  set _dragOffset(double value) => _dragPosition.value = value;
  bool _isDragging = false;
  int _settleDirection = 0;

  @override
  void initState() {
    super.initState();
    _dragController =
        AnimationController(vsync: this, duration: _pageAnimationDuration)
          ..addListener(() {
            _dragOffset = _dragAnimation.value;
          });
    _dragAnimation = AlwaysStoppedAnimation(_dragOffset);
  }

  @override
  void didUpdateWidget(covariant _MonthCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _dragPosition.dispose();
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
    unawaited(
      _dragController.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        onCompleted?.call();
      }),
    );
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
    _isDragging = true;
    _settleDirection = 0;
  }

  void _handleDragUpdate(DragUpdateDetails details, double width) {
    final delta = details.primaryDelta;
    if (delta == null || width <= 0) return;
    _dragOffset = (_dragOffset + delta / width).clamp(-1.0, 1.0);
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
          _isDragging = false;
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
        _isDragging = false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return _DesktopMonthCalendarPanel(
        model: widget.model,
        selectedDate: widget.selectedDate,
        today: widget.today,
        occurrencesByDay: widget.occurrencesByDay,
        display: widget.display,
        previousPage: widget.previousPage,
        nextPage: widget.nextPage,
        dragOffset: _dragPosition,
        sharedTopEdge: widget.sharedTopEdge,
        sharedStartEdge: widget.sharedStartEdge,
        sharedEndEdge: widget.sharedEndEdge,
        onDaySelected: widget.onDaySelected,
        onDragStart: _handleDragStart,
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _handleDragEnd,
        onDragCancel: _handleDragCancel,
      );
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final fillsHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final shouldFillHeight = fillsHeight;
        final grid = _DraggableMonthGrid(
          model: widget.model,
          selectedDate: widget.selectedDate,
          today: widget.today,
          occurrencesByDay: widget.occurrencesByDay,
          display: widget.display,
          compact: compact,
          dragOffset: _dragPosition,
          previousPage: widget.previousPage,
          nextPage: widget.nextPage,
          onDaySelected: widget.onDaySelected,
          onDragStart: _handleDragStart,
          onDragUpdate: _handleDragUpdate,
          onDragEnd: _handleDragEnd,
          onDragCancel: _handleDragCancel,
        );

        return Material(
          key: const ValueKey('general-month-calendar-panel'),
          color: colorScheme.surface,
          shape: compact
              ? RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(24),
                )
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: .55),
                ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: shouldFillHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              _MonthWeekdayHeaderRow(
                showWeekends: widget.display.showWeekends,
                compact: compact,
              ),
              if (shouldFillHeight) Expanded(child: grid) else grid,
            ],
          ),
        );
      },
    );
  }
}

/// A slide changes only the transform. The date grid remains the same child
/// throughout the drag and settle animation; hidden neighbors mount on demand.
class _MonthSlidePage extends StatelessWidget {
  const _MonthSlidePage({
    required this.position,
    required this.width,
    required this.dragOffset,
    required this.child,
    this.devicePixelRatio,
  });

  final double position, width;
  final ValueListenable<double> dragOffset;
  final Widget child;
  final double? devicePixelRatio;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: dragOffset,
    child: child,
    builder: (context, offset, child) {
      final visible =
          position == 0 ||
          (position < 0 && offset > 0) ||
          (position > 0 && offset < 0);
      final dx = (position + offset) * width;
      final dpr = devicePixelRatio;
      // Desktop scroll viewports are repaint boundaries. Move their retained
      // pixels by whole physical pixels, matching the grid's paint/hit snap.
      final translation = dpr == null ? dx : (dx * dpr).round() / dpr;
      return Transform.translate(
        offset: Offset(translation, 0),
        child: IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(
            excluding: !visible,
            child: visible ? child! : const SizedBox.shrink(),
          ),
        ),
      );
    },
  );
}

class _DraggableMonthGrid extends StatelessWidget {
  const _DraggableMonthGrid({
    required this.model,
    required this.selectedDate,
    required this.today,
    required this.occurrencesByDay,
    required this.display,
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

  final GeneralMonthGridModel model;
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final GeneralMonthDisplaySettings display;
  final bool compact;
  final ValueListenable<double> dragOffset;
  final GeneralMonthPage previousPage;
  final GeneralMonthPage nextPage;
  final ValueChanged<DateTime> onDaySelected;
  final GestureDragStartCallback onDragStart;
  final void Function(DragUpdateDetails details, double width) onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  double _gridHeight(
    BuildContext context,
    GeneralMonthGridModel model,
    BoxConstraints constraints,
    double width,
    double textScale,
  ) {
    final cellWidth = math.max(
      1.0,
      (width - (model.columnCount - 1) * _monthGridSpacing) / model.columnCount,
    );
    // In an unbounded phone list, expand the whole month rather than creating
    // a second vertical scroller inside it. Use the same font and lunar-label
    // budget as the date grid so the final week remains reachable.
    final preferredCellHeight = math.max(
      _monthCellHeightForWidth(cellWidth, compact: compact) * textScale,
      _monthMinimumCellHeight(
        context,
        compact: compact,
        showLunarCalendar: display.showLunarCalendar,
      ),
    );
    final totalSpacing = (model.rowCount - 1) * _monthGridSpacing;
    final preferredGridHeight =
        model.rowCount * preferredCellHeight + totalSpacing;
    if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
      return constraints.maxHeight;
    }
    return preferredGridHeight;
  }

  Widget _page({
    required double position,
    required double width,
    required double height,
    required DateTime date,
    required GeneralMonthGridModel model,
    required Map<String, List<GeneralEventOccurrence>> occurrences,
  }) {
    return _MonthSlidePage(
      position: position,
      width: width,
      dragOffset: dragOffset,
      child: SizedBox(
        width: width,
        height: height,
        child: _MonthDateGrid(
          model: model,
          selectedDate: date,
          today: today,
          occurrencesByDay: occurrences,
          display: display,
          compact: compact,
          onDaySelected: onDaySelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth);
        final textScale = math.max(
          1.0,
          MediaQuery.textScalerOf(context).scale(14) / 14,
        );
        final height = _gridHeight(
          context,
          model,
          constraints,
          width,
          textScale,
        );
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
                  ),
                  _page(
                    position: 1,
                    width: width,
                    height: height,
                    date: nextPage.date,
                    model: nextPage.model,
                    occurrences: nextPage.occurrencesByDay,
                  ),
                  _page(
                    position: 0,
                    width: width,
                    height: height,
                    date: selectedDate,
                    model: model,
                    occurrences: occurrencesByDay,
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
    required this.display,
    required this.compact,
    required this.onDaySelected,
  });

  final GeneralMonthGridModel model;
  final DateTime selectedDate;
  final DateTime today;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
  final GeneralMonthDisplaySettings display;
  final bool compact;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final cellWidth = math.max(
          1.0,
          (constraints.maxWidth - (model.columnCount - 1) * _monthGridSpacing) /
              model.columnCount,
        );
        final textScale = math.max(
          1.0,
          MediaQuery.textScalerOf(context).scale(14) / 14,
        );
        final preferredHeight =
            _monthCellHeightForWidth(cellWidth, compact: compact) * textScale;
        final totalSpacing = (model.rowCount - 1) * _monthGridSpacing;
        final preferredGridHeight =
            model.rowCount * preferredHeight + totalSpacing;
        final minimumCellHeight = _monthMinimumCellHeight(
          context,
          compact: compact,
          showLunarCalendar: display.showLunarCalendar,
        );
        final minimumGridHeight =
            model.rowCount * minimumCellHeight + totalSpacing;
        final height = boundedHeight
            ? constraints.maxHeight
            : math.max(preferredGridHeight, minimumGridHeight);
        final contentHeight = math.max(
          height,
          model.rowCount * minimumCellHeight + totalSpacing,
        );
        final targetHeight = (contentHeight - totalSpacing) / model.rowCount;
        final viewportCellHeight = (height - totalSpacing) / model.rowCount;
        final gridCompact = compact || viewportCellHeight < 64;

        return SizedBox(
          key: ValueKey(
            'general-month-date-grid-${selectedDate.year}-${selectedDate.month}',
          ),
          height: height,
          child: GridView.builder(
            physics: contentHeight > height + 1
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
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
                  occurrencesByDay[_calendarDateKey(day)] ?? const [];
              return LayoutBuilder(
                builder: (context, cellConstraints) {
                  final cellCompact =
                      gridCompact || cellConstraints.maxHeight < 64;
                  return KeyedSubtree(
                    key: ValueKey(
                      'general-month-day-cell-${day.year}-${day.month}-${day.day}',
                    ),
                    child: _MonthDayCell(
                      date: day,
                      month: selectedDate.month,
                      isToday: _sameDay(day, today),
                      isSelected: _sameDay(day, selectedDate),
                      occurrences: dayOccurrences,
                      localeCode: display.localeCode,
                      showLunarCalendar: display.showLunarCalendar,
                      cellWidth: cellWidth,
                      cellHeight: cellConstraints.maxHeight,
                      compact: cellCompact,
                      onTap: () => onDaySelected(day),
                    ),
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

class _MonthWeekdayHeaderRow extends StatelessWidget {
  const _MonthWeekdayHeaderRow({
    required this.showWeekends,
    this.compact = false,
  });

  final bool showWeekends;
  final bool compact;

  static final _referenceMonday = DateTime(2026, 1, 5);

  @override
  Widget build(BuildContext context) {
    final weekdays = showWeekends
        ? [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
            DateTime.sunday,
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
    // Keep the header's tracks identical to the date grid below.  Padding the
    // whole row made each weekday center drift by a few pixels at wide sizes;
    // visual breathing room belongs inside each cell instead.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = _monthGridSpacing;
        final cellWidth = math.max(
          0.0,
          (constraints.maxWidth - (weekdays.length - 1) * gap) /
              weekdays.length,
        );
        return ConstrainedBox(
          key: const ValueKey('general-month-weekday-header'),
          constraints: BoxConstraints(minHeight: compact ? 36 : 40),
          child: Row(
            children: [
              for (var index = 0; index < weekdays.length; index++) ...[
                SizedBox(
                  width: cellWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        _weekdayLabel(
                          context,
                          addCalendarDays(
                            _referenceMonday,
                            weekdays[index] - DateTime.monday,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
                if (index < weekdays.length - 1) SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
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
    final compactAccent = skedReadableAccent(colorScheme);
    final compactTextColor = isSelected || isToday ? compactAccent : baseColor;
    final compactButtonSize = math.min(cellWidth - 4, 48.0);
    final compactButtonHeight = math.max(
      32.0,
      _compactMonthDateStackHeight(context, showLunarCalendar) + 6,
    );
    final compactDateStyle = _compactMonthDateStyle(context).copyWith(
      color: compactTextColor,
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
    );
    final compactLunarWidget = showLunarCalendar
        ? _LunarDateLabel(
            date: date,
            colorScheme: colorScheme,
            localeCode: localeCode,
            enabled: showLunarCalendar,
            overrideColor: compactTextColor,
            fontSize: 11,
            maxLines: _compactMonthLunarLines(context),
            overflow: TextOverflow.fade,
          )
        : const SizedBox.shrink();
    final compactEventMarker = AnimatedOpacity(
      opacity: hasEventMarker ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: compactAccent, shape: BoxShape.circle),
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
    final dateScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final dateDimension = math.max(
      28.0,
      (theme.textTheme.titleMedium?.fontSize ?? 16) * dateScale * 1.35,
    );
    final dateStackHeight = math.max(
      46.0,
      dateDimension + (showLunarCalendar ? 11 * dateScale * 1.6 + 1 : 0) + 4,
    );
    final standardDateContent = SizedBox(
      width: double.infinity,
      height: dateStackHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: dateDimension,
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
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final showEventTitles =
        !compact && cellWidth >= 88 && cellHeight >= 90 * textScale;
    double lineHeight(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final eventRowHeight = math.max(
      20.0 * textScale,
      lineHeight('Ag', theme.textTheme.labelSmall) + 3,
    );
    final headerLineHeight = math.max(
      lineHeight(date.day.toString(), theme.textTheme.titleSmall),
      showLunarCalendar
          ? lineHeight('节日', theme.textTheme.labelSmall?.copyWith(fontSize: 11))
          : 0,
    );
    // Reserve the real font line box, the cell's padding and the overflow row.
    // The number badge cannot consume space already budgeted for event titles.
    final rows = math.max(
      0,
      ((cellHeight - 10 - headerLineHeight - 6) / eventRowHeight).floor(),
    );
    final titleLimit = math.min(
      4,
      math.max(
        0,
        rows - (occurrences.length > rows || occurrences.length > 4 ? 1 : 0),
      ),
    );
    final detailedDate = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isToday
                    ? skedReadableAccent(
                        colorScheme,
                        surface: SkedSurface.colorOf(context),
                      )
                    : baseColor,
              ),
            ),
            const SizedBox(width: 6),
            if (showLunarCalendar)
              Expanded(
                child: _LunarDateLabel(
                  date: date,
                  colorScheme: colorScheme,
                  localeCode: localeCode,
                  enabled: true,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final occurrence in occurrences.take(titleLimit))
          SizedBox(
            height: eventRowHeight,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                occurrence.event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: baseColor),
              ),
            ),
          ),
        if (occurrences.length > titleLimit)
          Text(
            AppLocalizations.of(context)
                .moreEvents(occurrences.length - titleLimit),
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: skedReadableAccent(
                colorScheme,
                surface: SkedSurface.colorOf(context),
              ),
            ),
          ),
      ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: compactButtonHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: compactButtonSize,
                  height: compactButtonHeight,
                  child: Material(
                    key: isSelected
                        ? _generalMonthCompactSelectedDayFeedbackKey
                        : null,
                    color: compactButtonBackground,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                // The decorative selection must not constrain or ellipsize a date.
                // Use the entire cell for glyphs; large lunar labels may wrap.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                          style: compactDateStyle,
                        ),
                        if (showLunarCalendar) const SizedBox(height: 1),
                        if (showLunarCalendar) compactLunarWidget,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          compactEventMarker,
        ],
      ),
    );
    final semanticsLabel = occurrences.isNotEmpty
        ? AppLocalizations.of(context)
              .monthDayEvents(date.day, occurrences.length)
        : '${date.day}';

    if (compact) {
      return Semantics(
        button: true,
        selected: isSelected,
        label: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: compactDateContent,
            ),
          ),
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
            child: showEventTitles ? detailedDate : standardDateStack,
          ),
        ),
      ),
    );
  }
}

class _MonthAgendaHeader extends StatelessWidget {
  const _MonthAgendaHeader({
    super.key,
    required this.date,
    required this.count,
    required this.filtered,
    required this.onAddEvent,
    this.compact = false,
  });
  final DateTime date;
  final int count;
  final bool filtered, compact;
  final ValueChanged<BuildContext> onAddEvent;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Padding(
      padding: compact
          ? const EdgeInsets.only(left: 4)
          : const EdgeInsets.fromLTRB(14, 10, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_formatDate(date)}  ${_weekdayLabel(context, date)}',
                  maxLines: compact ? null : 1,
                  overflow: compact ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!compact || count > 0)
                  Text(
                    count == 0
                        ? (filtered ? l.noMatchingEvents : l.noUpcomingEvents)
                        : l.monthDayEvents(date.day, count),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Builder(
            builder: (anchor) => IconButton(
              key: const ValueKey('general-month-agenda-add'),
              icon: const Icon(Icons.add),
              tooltip: l.addEvent,
              onPressed: () => onAddEvent(anchor),
            ),
          ),
        ],
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
  final ValueChanged<BuildContext> onAddEvent;
  final _GeneralOccurrenceTap onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    if (!WorkbenchChromeMetrics.of(context).desktop) {
      return _buildPanel(context);
    }
    return _EventListDetailsBinding(
      contextToken: normalizeDateOnly(date),
      builder: (context, host, source) =>
          _buildPanel(context, host: host, source: source),
    );
  }

  Widget _buildPanel(
    BuildContext context, {
    _EventListDetailsHostState? host,
    _EventListDetailsBindingState? source,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      key: const ValueKey('general-month-agenda'),
      color: colorScheme.surface,
      shape: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: .55),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _MonthAgendaHeader(
            date: date,
            count: occurrences.length,
            filtered: filtered,
            onAddEvent: onAddEvent,
          ),
          const Divider(height: 1),
          Expanded(
            child: SizedBox(
              key: source?.bodyKey,
              child: occurrences.isEmpty
                  ? _MonthAgendaEmptyState(filtered: filtered)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      itemCount: occurrences.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final occurrence = occurrences[index];
                        if (host != null && source != null) {
                          return host.row(
                            occurrence,
                            source: source,
                            builder: (activate) => KeyedSubtree(
                              key: ValueKey(
                                'general-agenda-${occurrence.occurrenceKey}',
                              ),
                              child: _MonthAgendaTile(
                                occurrence: occurrence,
                                onTap: activate,
                              ),
                            ),
                          );
                        }
                        return Builder(
                          builder: (anchor) => _MonthAgendaTile(
                            occurrence: occurrence,
                            onTap: () => onOccurrenceTap(occurrence, anchor),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthAgendaEmptyState extends StatelessWidget {
  const _MonthAgendaEmptyState({required this.filtered});

  final bool filtered;

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
                color: skedReadableAccent(
                  theme.colorScheme,
                  surface: SkedSurface.colorOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                filtered ? l10n.noMatchingEvents : l10n.noUpcomingEvents,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
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
        ? Icon(
            Icons.repeat,
            color: skedReadableAccent(
              colors,
              surface: SkedSurface.colorOf(context),
            ),
            size: 18,
          )
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
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final DateTime date;
  final ColorScheme colorScheme;
  final String localeCode;
  final bool enabled;
  final Color? overrideColor;
  final double fontSize;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    if (!enabled || (localeCode != 'zh' && localeCode != 'zh-Hant')) {
      return const SizedBox.shrink();
    }
    final label = _cachedLunarLabelFor(date, localeCode);
    final color = switch (label.kind) {
      _LunarLabelKind.festival => effectiveGeneralFestivalTextColor(
        context,
        colorScheme.primary,
      ),
      _LunarLabelKind.solarTerm => effectiveGeneralSolarTermTextColor(
        context,
        colorScheme.tertiary,
      ),
      _LunarLabelKind.day => effectiveGeneralLunarTextColor(
        context,
        overrideColor ?? colorScheme.onSurfaceVariant,
      ),
    };
    return _LunarText(
      text: label.text,
      color: color,
      fontSize: fontSize,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

enum _LunarLabelKind { festival, solarTerm, day }

class _CachedLunarLabel {
  const _CachedLunarLabel({required this.text, required this.kind});

  final String text;
  final _LunarLabelKind kind;
}

const _maxLunarLabelCacheEntries = 512;
final _lunarLabelCache = <String, _CachedLunarLabel>{};

_CachedLunarLabel _cachedLunarLabelFor(DateTime date, String localeCode) {
  final key = '${_dateKey(date)}|$localeCode';
  final cached = _lunarLabelCache[key];
  if (cached != null) {
    return cached;
  }

  final lunar = Lunar.fromDate(date);
  final festivals = lunar.getFestivals();
  final label = festivals.isNotEmpty
      ? _CachedLunarLabel(text: festivals.first, kind: _LunarLabelKind.festival)
      : lunar.getJieQi().isNotEmpty
      ? _CachedLunarLabel(
          text: lunar.getJieQi(),
          kind: _LunarLabelKind.solarTerm,
        )
      : _CachedLunarLabel(
          text: lunar.getDayInChinese(),
          kind: _LunarLabelKind.day,
        );
  if (_lunarLabelCache.length >= _maxLunarLabelCacheEntries) {
    _lunarLabelCache.remove(_lunarLabelCache.keys.first);
  }
  _lunarLabelCache[key] = label;
  return label;
}

class _LunarText extends StatelessWidget {
  const _LunarText({
    required this.text,
    required this.color,
    required this.fontSize,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final Color color;
  final double fontSize;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
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
