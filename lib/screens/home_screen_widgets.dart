part of 'home_screen.dart';

typedef TimetableLiveRefreshTimerFactory =
    Timer Function(Duration delay, VoidCallback callback);

@visibleForTesting
class TimetableLiveRefreshScope extends InheritedWidget {
  const TimetableLiveRefreshScope({
    super.key,
    required this.now,
    required this.createTimer,
    required super.child,
  });

  final DateTime Function() now;
  final TimetableLiveRefreshTimerFactory createTimer;

  static TimetableLiveRefreshScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TimetableLiveRefreshScope>();
  }

  @override
  bool updateShouldNotify(TimetableLiveRefreshScope oldWidget) {
    return now != oldWidget.now || createTimer != oldWidget.createTimer;
  }
}

Timer _createTimetableLiveRefreshTimer(Duration delay, VoidCallback callback) {
  return Timer(delay, callback);
}

class _StudentWorkspaceToolbar extends StatelessWidget {
  const _StudentWorkspaceToolbar({
    required this.timetable,
    required this.week,
    required this.weekNavigationDirection,
    required this.viewMode,
    required this.compactWidth,
    required this.compactHeight,
    required this.interactive,
    required this.showSettings,
    this.settingsFocusNode,
    required this.onOpenTimetablePicker,
    required this.onOpenWeekPicker,
    required this.onJumpToToday,
    required this.onViewChanged,
    required this.onOpenSettings,
  });

  final TimetableData timetable;
  final int week;
  final int weekNavigationDirection;
  final _StudentTimetableView viewMode;
  final bool compactWidth;
  final bool compactHeight;
  final bool interactive;
  final bool showSettings;
  final FocusNode? settingsFocusNode;
  final VoidCallback? onOpenTimetablePicker;
  final VoidCallback? onOpenWeekPicker;
  final VoidCallback? onJumpToToday;
  final ValueChanged<_StudentTimetableView>? onViewChanged;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phoneWidth = compactWidth;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scaledLabelSize = MediaQuery.textScalerOf(
      context,
    ).scale(theme.textTheme.labelLarge?.fontSize ?? 14);
    final compactWeekPicker =
        phoneWidth && (screenWidth < 360 || scaledLabelSize > 18.2);
    final controlShape = skedShapeSchemeOf(context).control;
    final motion = SkedMotionPolicy.of(context);
    final iconButtonStyle = IconButton.styleFrom(
      minimumSize: const Size.square(48),
      padding: const EdgeInsets.all(8),
      iconSize: 20,
    );
    final timetableSelector = TextButton(
      key: const ValueKey('student-timetable-picker-button'),
      onPressed: interactive ? onOpenTimetablePicker : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
        minimumSize: const Size(48, 48),
        shape: controlShape,
        alignment: AlignmentDirectional.centerStart,
        textStyle: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              timetable.config.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ],
      ),
    );
    final viewToggle = IconButton(
      key: const ValueKey('student-view-toggle-button'),
      onPressed: interactive && onViewChanged != null
          ? () => onViewChanged!(
              viewMode == _StudentTimetableView.day
                  ? _StudentTimetableView.week
                  : _StudentTimetableView.day,
            )
          : null,
      style: iconButtonStyle,
      tooltip: viewMode == _StudentTimetableView.day
          ? l10n.viewWeek
          : l10n.viewDay,
      icon: AnimatedSwitcher(
        duration: motion.effects(SkedMotionSpeed.fast),
        switchInCurve: motion.scheme.enterCurve,
        switchOutCurve: motion.scheme.exitCurve,
        child: Icon(
          viewMode == _StudentTimetableView.day
              ? Icons.view_week_outlined
              : Icons.view_day_outlined,
          key: ValueKey(viewMode),
          size: 20,
        ),
      ),
    );
    final weekPicker = Tooltip(
      message: '${l10n.jumpToWeek}; ${l10n.today}',
      child: Semantics(
        key: const ValueKey('student-week-picker-semantics'),
        button: true,
        enabled:
            interactive && (onOpenWeekPicker != null || onJumpToToday != null),
        excludeSemantics: true,
        label: l10n.weekLabel(week),
        hint: '${l10n.jumpToWeek}; ${l10n.today}',
        onTap: onOpenWeekPicker,
        onLongPress: onJumpToToday,
        onTapHint: l10n.jumpToWeek,
        onLongPressHint: l10n.today,
        child: SizedBox(
          width: compactWeekPicker
              ? 56
              : phoneWidth
              ? 96
              : 144,
          child: TextButton(
            key: const ValueKey('student-week-picker-button'),
            onPressed: interactive ? onOpenWeekPicker : null,
            onLongPress: interactive ? onJumpToToday : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              shape: controlShape,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!compactWeekPicker) ...[
                  const Icon(Icons.calendar_month_outlined, size: 18),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: SkedDirectionalTransition(
                    trigger: week,
                    direction: weekNavigationDirection,
                    distance: 12,
                    child: Text(
                      compactWeekPicker ? '$week' : l10n.weekLabel(week),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final settingsAction = IconButton(
      key: const ValueKey('student-settings-button'),
      focusNode: settingsFocusNode,
      onPressed: onOpenSettings,
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.settings,
      style: iconButtonStyle,
    );
    return SkedWorkspaceToolbar(
      key: const ValueKey('student-workspace-toolbar'),
      padding: EdgeInsets.symmetric(
        horizontal: phoneWidth ? 8 : 16,
        vertical: phoneWidth || compactHeight ? 4 : 8,
      ),
      navigationSpacing: 0,
      title: Row(
        children: [
          Expanded(child: timetableSelector),
          viewToggle,
          weekPicker,
          if (showSettings) settingsAction,
        ],
      ),
    );
  }
}

class _StudentDayStrip extends StatefulWidget {
  const _StudentDayStrip({
    required this.weekStart,
    required this.selectedWeekday,
    required this.enabled,
    required this.fitToWidth,
    this.horizontalScrollLocked = false,
    this.onHorizontalPointerDown,
    this.onHorizontalEdgeDrag,
    required this.onSelected,
  });

  final DateTime weekStart;
  final int selectedWeekday;
  final bool enabled;
  final bool fitToWidth;
  final bool horizontalScrollLocked;
  final ValueChanged<int>? onHorizontalPointerDown;
  final ValueChanged<double>? onHorizontalEdgeDrag;
  final ValueChanged<int> onSelected;

  @override
  State<_StudentDayStrip> createState() => _StudentDayStripState();
}

class _StudentDayStripState extends State<_StudentDayStrip> {
  final ScrollController _scrollController = ScrollController();
  _DayStripMetrics? _lastMetrics;

  @override
  void initState() {
    super.initState();
    _scheduleRevealSelected(_lastMetrics);
  }

  @override
  void didUpdateWidget(covariant _StudentDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeekday != widget.selectedWeekday ||
        oldWidget.weekStart != widget.weekStart ||
        oldWidget.fitToWidth != widget.fitToWidth) {
      _scheduleRevealSelected(_lastMetrics);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleRevealSelected(_DayStripMetrics? metrics) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || metrics == null || !_scrollController.hasClients) return;
      if (widget.fitToWidth) {
        if (_scrollController.offset.abs() >= 0.5) {
          _scrollController.jumpTo(0);
        }
        return;
      }
      final position = _scrollController.position;
      final selectedCenter =
          metrics.padding +
          ((widget.selectedWeekday - 1) * metrics.itemExtent) +
          (metrics.itemWidth / 2);
      final target = (selectedCenter - (position.viewportDimension / 2)).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() < 0.5) return;
      final motion = SkedMotionPolicy.of(context);
      final duration = motion.effects(SkedMotionSpeed.fast);
      if (!motion.spatialAnimationsEnabled || duration == Duration.zero) {
        _scrollController.jumpTo(target);
      } else {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: duration,
            curve: motion.scheme.standardCurve,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = SkedMotionPolicy.of(context);
    final shape = skedShapeSchemeOf(context).selectionIndicator;
    final today = DateTime.now();
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    double singleLineHeight(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      return painter.height;
    }

    final localeCode = Localizations.localeOf(context).toLanguageTag();
    final weekdayHeight = List.generate(
      7,
      (index) => singleLineHeight(
        formatWeekdayShortLabel(index + 1, localeCode: localeCode),
        theme.textTheme.labelMedium,
      ),
    ).reduce(math.max);
    final dateHeight = List.generate(
      7,
      (index) => singleLineHeight(
        '${addCalendarDays(widget.weekStart, index).day}',
        theme.textTheme.titleMedium,
      ),
    ).reduce(math.max);
    final stripHeight = math
        .max(60.0, weekdayHeight + dateHeight + 12)
        .ceilToDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _DayStripMetrics.fromWidth(
          constraints.maxWidth,
          fitToWidth: widget.fitToWidth,
        );
        _lastMetrics = metrics;
        _scheduleRevealSelected(metrics);
        final contentWidth =
            metrics.padding * 2 + metrics.itemWidth * 7 + metrics.gap * 6;
        final scrollable = contentWidth > constraints.maxWidth + 0.5;
        final physics = widget.horizontalScrollLocked || !scrollable
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              );
        bool reportHorizontalOverscroll(OverscrollNotification notification) {
          if (notification.metrics.axis != Axis.horizontal ||
              notification.dragDetails == null) {
            return false;
          }
          final delta = notification.dragDetails!.primaryDelta;
          if (delta != null && delta != 0) {
            widget.onHorizontalEdgeDrag?.call(delta);
          }
          return false;
        }

        return SizedBox(
          height: stripHeight,
          child: NotificationListener<OverscrollNotification>(
            onNotification: reportHorizontalOverscroll,
            child: Listener(
              onPointerDown: scrollable
                  ? (event) =>
                        widget.onHorizontalPointerDown?.call(event.pointer)
                  : null,
              onPointerPanZoomStart: scrollable
                  ? (event) =>
                        widget.onHorizontalPointerDown?.call(event.pointer)
                  : null,
              child: ListView.separated(
                key: const ValueKey('student-day-strip'),
                controller: _scrollController,
                physics: physics,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: metrics.padding),
                itemCount: 7,
                separatorBuilder: (_, _) => SizedBox(width: metrics.gap),
                itemBuilder: (context, index) {
                  final weekday = index + 1;
                  final date = addCalendarDays(widget.weekStart, index);
                  final selected = weekday == widget.selectedWeekday;
                  final isToday = DateUtils.isSameDay(date, today);
                  final foreground = selected
                      ? colors.onPrimaryContainer
                      : colors.onSurface;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: MaterialLocalizations.of(
                      context,
                    ).formatFullDate(date),
                    child: AnimatedContainer(
                      key: ValueKey('student-day-$weekday'),
                      duration: motion.effects(SkedMotionSpeed.fast),
                      curve: motion.scheme.standardCurve,
                      width: metrics.itemWidth,
                      decoration: ShapeDecoration(
                        shape: shape.copyWith(
                          side: BorderSide(
                            color: selected || isToday
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                        color: selected
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: shape,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: shape,
                          onTap: widget.enabled
                              ? () => widget.onSelected(weekday)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  formatWeekdayShortLabel(
                                    weekday,
                                    localeCode: Localizations.localeOf(
                                      context,
                                    ).toLanguageTag(),
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: foreground,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                                Text(
                                  '${date.day}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: foreground,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayStripMetrics {
  const _DayStripMetrics({
    required this.itemWidth,
    required this.gap,
    required this.padding,
  });

  final double itemWidth;
  final double gap;
  final double padding;

  double get itemExtent => itemWidth + gap;

  factory _DayStripMetrics.fromWidth(double width, {required bool fitToWidth}) {
    if (!fitToWidth) {
      return const _DayStripMetrics(itemWidth: 54, gap: 4, padding: 4);
    }
    final safeWidth = width.isFinite && width > 0 ? width : 320.0;
    const gap = 2.0;
    const padding = 0.0;
    return _DayStripMetrics(
      itemWidth: math.max(1.0, (safeWidth - gap * 6) / 7),
      gap: gap,
      padding: padding,
    );
  }
}

class _TimetablePickerPanel extends StatefulWidget {
  const _TimetablePickerPanel({
    required this.provider,
    required this.activeTimetable,
    required this.onSwitch,
    required this.onEdit,
    required this.onCreate,
  });

  final TimetableProvider provider;
  final TimetableData activeTimetable;
  final Future<bool> Function(BuildContext context, TimetableData timetable)
  onSwitch;
  final Future<bool> Function(TimetableData timetable) onEdit;
  final Future<bool> Function(BuildContext context) onCreate;

  @override
  State<_TimetablePickerPanel> createState() => _TimetablePickerPanelState();
}

class _TimetablePickerPanelState extends State<_TimetablePickerPanel> {
  bool _busy = false;

  Future<void> _run(
    Future<bool> Function() command, {
    bool showBusy = true,
  }) async {
    if (_busy) return;
    if (showBusy) setState(() => _busy = true);
    final completed = await command();
    if (!mounted) return;
    if (completed) {
      Navigator.of(context).pop();
    } else if (showBusy) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = math.min(MediaQuery.sizeOf(context).height * 0.72, 640.0);
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.multiTimetableSwitch,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: l10n.cancel,
                    ),
                  ],
                ),
              ),
              UiCommandBusyIndicator(
                busy: _busy,
                semanticsKey: const ValueKey('timetable-picker-busy'),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.provider,
                  builder: (context, _) {
                    final selectedId =
                        widget.provider.activeTimetableOrNull?.id ??
                        widget.activeTimetable.id;
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final item in widget.provider.timetables)
                          _TimetableDrawerItem(
                            timetable: item,
                            selected: item.id == selectedId,
                            enabled: !_busy,
                            currentLabel: l10n.currentTimetableWeeks(
                              item.config.totalWeeks,
                            ),
                            switchLabel: l10n.tapToSwitchWeeks(
                              item.config.totalWeeks,
                            ),
                            editTooltip: l10n.editTimetable,
                            onTap: _busy
                                ? null
                                : () => _run(
                                    () => widget.onSwitch(context, item),
                                  ),
                            onEdit: _busy
                                ? null
                                : () => _run(
                                    () => widget.onEdit(item),
                                    showBusy: false,
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => widget.onCreate(context)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.createTimetable),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimetableDrawerItem extends StatelessWidget {
  const _TimetableDrawerItem({
    required this.timetable,
    required this.selected,
    required this.enabled,
    required this.currentLabel,
    required this.switchLabel,
    required this.editTooltip,
    required this.onTap,
    required this.onEdit,
  });

  final TimetableData timetable;
  final bool selected;
  final bool enabled;
  final String currentLabel;
  final String switchLabel;
  final String editTooltip;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentColor = enabled
        ? (selected ? colors.primary : colors.onSurface)
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? (selected ? colors.primary : colors.onSurfaceVariant)
        : colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      key: ValueKey('timetable-picker-item-${timetable.id}'),
      container: true,
      selected: selected,
      enabled: enabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.calendar_view_week,
                    color: secondaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timetable.config.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: contentColor,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected ? currentLabel : switchLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: editTooltip,
                    icon: const Icon(Icons.edit_outlined),
                    color: secondaryColor,
                    onPressed: onEdit,
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

class _TimetableWeekPager extends StatefulWidget {
  const _TimetableWeekPager({
    required this.controller,
    required this.provider,
    required this.timetable,
    required this.config,
    required this.committedWeek,
    required this.active,
    required this.interactive,
    required this.swipeEnabled,
    required this.viewMode,
    required this.selectedWeekday,
    required this.fitDaySelectorToWidth,
    required this.fitWeekColumnsToWidth,
    this.shortcutFocusNode,
    required this.bottomContentInset,
    required this.onPageScrollStateChanged,
    required this.onWeekSettled,
    required this.onWeekdaySelected,
    required this.onJumpWeekBy,
    required this.onCourseTap,
    required this.onEmptySlotTap,
  });

  final PageController controller;
  final TimetableProvider provider;
  final TimetableData timetable;
  final TimetableConfig config;
  final int committedWeek;
  final bool active;
  final bool interactive;
  final bool swipeEnabled;
  final _StudentTimetableView viewMode;
  final int selectedWeekday;
  final bool fitDaySelectorToWidth;
  final bool fitWeekColumnsToWidth;
  final FocusNode? shortcutFocusNode;
  final double bottomContentInset;
  final ValueChanged<bool> onPageScrollStateChanged;
  final Future<void> Function(int week) onWeekSettled;
  final ValueChanged<int> onWeekdaySelected;
  final Future<void> Function(int offset) onJumpWeekBy;
  final ValueChanged<TimetableCourseTapInfo> onCourseTap;
  final ValueChanged<TimetableEmptySlotTapInfo> onEmptySlotTap;

  @override
  State<_TimetableWeekPager> createState() => _TimetableWeekPagerState();
}

class _TimetableWeekPagerState extends State<_TimetableWeekPager>
    with WidgetsBindingObserver {
  Timer? _liveCourseTimer;
  late final FocusNode _shortcutFocusNode;
  DateTime Function() _now = DateTime.now;
  TimetableLiveRefreshTimerFactory _createTimer =
      _createTimetableLiveRefreshTimer;
  bool _isForeground = true;
  bool _tickerEnabled = false;
  bool _manualEdgeDrag = false;
  bool _manualSettleInProgress = false;
  bool _pageScrollReported = false;
  final Set<int> _innerHorizontalPointers = <int>{};
  int? _activePointer;
  int? _manualOriginPage;
  int _manualDirection = 0;
  Offset _pointerTravel = Offset.zero;
  double _manualProgressPixels = 0;
  VelocityTracker? _velocityTracker;

  @override
  void initState() {
    super.initState();
    _shortcutFocusNode =
        widget.shortcutFocusNode ??
        FocusNode(debugLabel: 'Student timetable week shortcuts');
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _restartLiveCourseTimer(refreshImmediately: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timeScope = TimetableLiveRefreshScope.maybeOf(context);
    final nextNow = timeScope?.now ?? DateTime.now;
    final nextCreateTimer =
        timeScope?.createTimer ?? _createTimetableLiveRefreshTimer;
    final nextTickerEnabled = TickerMode.valuesOf(context).enabled;
    final timingChanged = _now != nextNow || _createTimer != nextCreateTimer;
    if (!timingChanged && _tickerEnabled == nextTickerEnabled) return;
    _now = nextNow;
    _createTimer = nextCreateTimer;
    _tickerEnabled = nextTickerEnabled;
    _restartLiveCourseTimer(refreshImmediately: _canRefresh);
  }

  @override
  void didUpdateWidget(covariant _TimetableWeekPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _restartLiveCourseTimer(refreshImmediately: _canRefresh);
    }
    if (oldWidget.swipeEnabled && !widget.swipeEnabled && _manualEdgeDrag) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_finishManualEdgeDrag(0));
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _isForeground;
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground != wasForeground) {
      _restartLiveCourseTimer(refreshImmediately: _canRefresh);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveCourseTimer?.cancel();
    _reportPageScrolling(false);
    if (widget.shortcutFocusNode == null) _shortcutFocusNode.dispose();
    super.dispose();
  }

  bool get _canRefresh =>
      mounted && widget.active && _tickerEnabled && _isForeground;

  bool get _shortcutsEnabled => mounted && widget.active && _tickerEnabled;

  void _restartLiveCourseTimer({required bool refreshImmediately}) {
    _liveCourseTimer?.cancel();
    _liveCourseTimer = null;
    if (!_canRefresh) return;
    if (refreshImmediately) setState(() {});
    _scheduleLiveCourseTimer();
  }

  void _scheduleLiveCourseTimer() {
    if (!_canRefresh) return;
    final now = _now();
    _liveCourseTimer = _createTimer(
      timetableLiveRefreshDelayUntilNextMinute(now),
      () {
        _liveCourseTimer = null;
        if (!_canRefresh) return;
        setState(() {});
        _scheduleLiveCourseTimer();
      },
    );
  }

  void _reportPageScrolling(bool scrolling) {
    if (_pageScrollReported == scrolling) return;
    _pageScrollReported = scrolling;
    widget.onPageScrollStateChanged(scrolling);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.swipeEnabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _pointerTravel = Offset.zero;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _handlePointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (!widget.swipeEnabled || _activePointer != null) return;
    _activePointer = event.pointer;
    _pointerTravel = Offset.zero;
    _velocityTracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, Offset.zero);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _handlePointerDelta(event.pointer, event.delta);
  }

  void _handlePointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.pan);
    _handlePointerDelta(event.pointer, event.panDelta);
  }

  void _handlePointerDelta(int pointer, Offset delta) {
    _pointerTravel += delta;
    if (_manualEdgeDrag) {
      _applyManualPageDelta(delta.dx);
      return;
    }
    if (!_innerHorizontalPointers.contains(pointer) &&
        _pointerTravel.dx.abs() >= kTouchSlop &&
        _pointerTravel.dx.abs() > _pointerTravel.dy.abs() * 1.1) {
      _beginManualPageDrag(_pointerTravel.dx);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _innerHorizontalPointers.remove(event.pointer);
    _activePointer = null;
    _velocityTracker = null;
    _pointerTravel = Offset.zero;
    if (_manualEdgeDrag) {
      unawaited(_finishManualEdgeDrag(velocity));
    }
  }

  void _handlePointerPanZoomEnd(PointerPanZoomEndEvent event) {
    if (event.pointer != _activePointer) return;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
    _innerHorizontalPointers.remove(event.pointer);
    _activePointer = null;
    _velocityTracker = null;
    _pointerTravel = Offset.zero;
    if (_manualEdgeDrag) {
      unawaited(_finishManualEdgeDrag(velocity));
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _innerHorizontalPointers.remove(event.pointer);
    _activePointer = null;
    _velocityTracker = null;
    _pointerTravel = Offset.zero;
    if (_manualEdgeDrag) {
      unawaited(_finishManualEdgeDrag(0));
    }
  }

  void _markInnerHorizontalPointer(int pointer) {
    if (widget.swipeEnabled) _innerHorizontalPointers.add(pointer);
  }

  void _beginManualEdgeDrag(double physicalDelta) {
    _beginManualPageDrag(physicalDelta);
  }

  /// Nested horizontal scrollables consume the gesture first. Once one of
  /// them reports that it has reached an edge, keep the same pointer stream
  /// and move the outer page at the finger's physical delta.
  void _beginManualPageDrag(double physicalDelta) {
    if (_manualEdgeDrag ||
        _manualSettleInProgress ||
        _activePointer == null ||
        !widget.swipeEnabled ||
        widget.config.totalWeeks <= 1 ||
        !widget.controller.hasClients) {
      return;
    }
    final position = widget.controller.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
    final originPage = (widget.controller.page ?? widget.committedWeek - 1)
        .round()
        .clamp(0, widget.config.totalWeeks - 1);
    final adjustedDelta = axisDirectionIsReversed(position.axisDirection)
        ? -physicalDelta
        : physicalDelta;
    final direction = (-adjustedDelta).sign.toInt();
    if (direction == 0) return;

    _manualEdgeDrag = true;
    _manualOriginPage = originPage;
    _manualDirection = direction;
    _manualProgressPixels = 0;
    _reportPageScrolling(true);
    if (mounted) setState(() {});
    _applyManualPageDelta(physicalDelta);
  }

  void _applyManualPageDelta(double physicalDelta) {
    final originPage = _manualOriginPage;
    if (!_manualEdgeDrag ||
        originPage == null ||
        !widget.controller.hasClients) {
      return;
    }
    final position = widget.controller.position;
    if (!position.hasViewportDimension || position.viewportDimension <= 0) {
      return;
    }
    final adjustedDelta = axisDirectionIsReversed(position.axisDirection)
        ? -physicalDelta
        : physicalDelta;
    final originPixels = originPage * position.viewportDimension;
    final destinationPage = (originPage + _manualDirection).clamp(
      0,
      widget.config.totalWeeks - 1,
    );
    final maximumProgress =
        (destinationPage - originPage).abs() * position.viewportDimension;
    final progressDelta = -adjustedDelta * _manualDirection;
    _manualProgressPixels = (_manualProgressPixels + progressDelta).clamp(
      0,
      maximumProgress,
    );
    if (SkedMotionPolicy.of(context).spatialAnimationsEnabled) {
      final nextPixels =
          (originPixels + _manualDirection * _manualProgressPixels).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      if ((nextPixels - position.pixels).abs() >= 0.01) {
        widget.controller.jumpTo(nextPixels);
      }
    }
  }

  Future<void> _finishManualEdgeDrag(double physicalVelocity) async {
    if (!_manualEdgeDrag || _manualSettleInProgress) return;
    final originPage = _manualOriginPage;
    if (originPage == null || !widget.controller.hasClients) {
      _resetManualDrag();
      return;
    }
    _manualEdgeDrag = false;
    _manualSettleInProgress = true;
    if (mounted) setState(() {});

    final position = widget.controller.position;
    final progress = position.viewportDimension <= 0
        ? 0.0
        : _manualProgressPixels / position.viewportDimension;
    final adjustedVelocity = axisDirectionIsReversed(position.axisDirection)
        ? -physicalVelocity
        : physicalVelocity;
    final pageVelocity = -adjustedVelocity * _manualDirection;
    final shouldAdvance =
        progress >= 0.35 || (pageVelocity >= 700 && progress >= 0.05);
    final targetPage = shouldAdvance
        ? (originPage + _manualDirection).clamp(0, widget.config.totalWeeks - 1)
        : originPage;

    try {
      final motion = SkedMotionPolicy.of(context);
      if (!motion.spatialAnimationsEnabled) {
        widget.controller.jumpToPage(targetPage);
      } else {
        await widget.controller.animateToPage(
          targetPage,
          duration: motion.effects(SkedMotionSpeed.standard),
          curve: motion.scheme.standardCurve,
        );
      }
      if (mounted && targetPage != widget.committedWeek - 1) {
        await widget.onWeekSettled(targetPage + 1);
      }
    } finally {
      _resetManualDrag();
    }
  }

  void _resetManualDrag() {
    _manualEdgeDrag = false;
    _manualSettleInProgress = false;
    _manualOriginPage = null;
    _manualDirection = 0;
    _manualProgressPixels = 0;
    _reportPageScrolling(false);
    if (mounted) setState(() {});
  }

  Widget _buildWeekPage(BuildContext context, int index) {
    final pageWeek = index + 1;
    final weekStart = startOfWeekFor(widget.config, pageWeek);
    final realCurrentWeek = currentWeekFor(widget.config);
    final liveCourseTarget = currentOrNextCourseTargetFor(
      timetable: widget.timetable,
      selectedWeek: pageWeek,
      realCurrentWeek: realCurrentWeek,
      now: _now(),
      displayedCourseIdForConflict:
          widget.provider.displayedCourseIdForConflict,
    );
    final liveCourseOutlineColorValue =
        widget.provider.liveCourseOutlineFollowTheme
        ? deriveLiveCourseOutlineColorFromSeed(
            Color(widget.provider.themeSeedColorValue),
          ).toARGB32()
        : widget.provider.liveCourseOutlineColorValue;
    final horizontalHandoffEnabled =
        widget.swipeEnabled &&
        ((widget.viewMode == _StudentTimetableView.day &&
                !widget.fitDaySelectorToWidth) ||
            (widget.viewMode == _StudentTimetableView.week &&
                !widget.fitWeekColumnsToWidth));
    final currentPageInteractive =
        widget.interactive && pageWeek == widget.committedWeek;

    return KeyedSubtree(
      key: ValueKey('student-week-page-$pageWeek'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.viewMode == _StudentTimetableView.day) ...[
            _StudentDayStrip(
              weekStart: weekStart,
              selectedWeekday: widget.selectedWeekday,
              enabled: currentPageInteractive,
              fitToWidth: widget.fitDaySelectorToWidth,
              horizontalScrollLocked:
                  _manualEdgeDrag || _manualSettleInProgress,
              onHorizontalPointerDown: horizontalHandoffEnabled
                  ? _markInnerHorizontalPointer
                  : null,
              onHorizontalEdgeDrag: horizontalHandoffEnabled
                  ? _beginManualEdgeDrag
                  : null,
              onSelected: widget.onWeekdaySelected,
            ),
            const SizedBox(height: 4),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 2, top: 4),
              child: RepaintBoundary(
                child: TimetableGrid(
                  key: ValueKey('student-timetable-grid-$pageWeek'),
                  timetable: widget.timetable,
                  periodTimes: widget.provider.periodTimesForTimetable(
                    widget.timetable,
                  ),
                  weekDateStart: weekStart,
                  selectedWeek: pageWeek,
                  realCurrentWeek: realCurrentWeek,
                  localeCode: widget.provider.localeCode,
                  preserveGaps: widget.provider.preserveTimetableGaps,
                  showPastEndedCourses: widget.provider.showPastEndedCourses,
                  showFutureCourses: widget.provider.showFutureCourses,
                  showGridLines: widget.provider.showTimetableGridLines,
                  themeColorMode: widget.provider.themeColorMode,
                  courseNameColorValues: widget.provider.courseNameColorValues,
                  colorfulCourseTextColorMode:
                      widget.provider.colorfulCourseTextColorMode,
                  colorfulCourseTextColorValue: widget
                      .provider
                      .colorfulUiColorValues[colorfulCourseTextColorKey],
                  displayedCourseIdForConflict:
                      widget.provider.displayedCourseIdForConflict,
                  liveCourseTarget: liveCourseTarget,
                  liveCourseOutlineEnabled:
                      widget.provider.liveCourseOutlineEnabled,
                  liveCourseOutlineMode: widget.provider.liveCourseOutlineMode,
                  liveCourseOutlineColorValue: liveCourseOutlineColorValue,
                  liveCourseOutlineWidth:
                      widget.provider.liveCourseOutlineWidth,
                  visibleWeekdays: widget.viewMode == _StudentTimetableView.day
                      ? [widget.selectedWeekday]
                      : const <int>[1, 2, 3, 4, 5, 6, 7],
                  fitVisibleDaysToWidth:
                      widget.viewMode == _StudentTimetableView.week &&
                      widget.fitWeekColumnsToWidth,
                  showDayHeader: widget.viewMode != _StudentTimetableView.day,
                  bottomContentInset: widget.bottomContentInset,
                  horizontalScrollLocked:
                      _manualEdgeDrag || _manualSettleInProgress,
                  onHorizontalPointerDown:
                      horizontalHandoffEnabled &&
                          widget.viewMode == _StudentTimetableView.week
                      ? _markInnerHorizontalPointer
                      : null,
                  onHorizontalEdgeDrag:
                      horizontalHandoffEnabled &&
                          widget.viewMode == _StudentTimetableView.week
                      ? _beginManualEdgeDrag
                      : null,
                  onCourseTap: currentPageInteractive
                      ? widget.onCourseTap
                      : (_) {},
                  onEmptySlotTap: currentPageInteractive
                      ? widget.onEmptySlotTap
                      : (_) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final pageView = ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        onPointerPanZoomStart: _handlePointerPanZoomStart,
        onPointerPanZoomUpdate: _handlePointerPanZoomUpdate,
        onPointerPanZoomEnd: _handlePointerPanZoomEnd,
        child: PageView.builder(
          key: const ValueKey('student-week-pager'),
          controller: widget.controller,
          physics: const NeverScrollableScrollPhysics(),
          // The manual pointer state machine owns both drag progress and the
          // release animation. Implicit snapping would start a ballistic
          // spring after every jumpTo and fight slow mouse drags.
          pageSnapping: false,
          itemCount: widget.config.totalWeeks,
          itemBuilder: _buildWeekPage,
        ),
      ),
    );
    final horizontalGridMayScroll =
        widget.viewMode == _StudentTimetableView.week &&
        !widget.fitWeekColumnsToWidth &&
        (MediaQuery.sizeOf(context).width < 760 || textScale > 1.3);
    final shortcutsEnabled =
        _shortcutsEnabled && widget.interactive && !horizontalGridMayScroll;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return CallbackShortcuts(
      bindings: shortcutsEnabled
          ? {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                unawaited(widget.onJumpWeekBy(isRtl ? 1 : -1));
              },
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                unawaited(widget.onJumpWeekBy(isRtl ? -1 : 1));
              },
            }
          : const <ShortcutActivator, VoidCallback>{},
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: widget.shortcutFocusNode == null && shortcutsEnabled,
        canRequestFocus: shortcutsEnabled,
        descendantsAreFocusable: shortcutsEnabled,
        descendantsAreTraversable: shortcutsEnabled,
        child: pageView,
      ),
    );
  }
}

@visibleForTesting
Duration timetableLiveRefreshDelayUntilNextMinute(DateTime now) {
  final elapsedInMinute = Duration(
    seconds: now.second,
    milliseconds: now.millisecond,
    microseconds: now.microsecond,
  );
  return const Duration(minutes: 1) - elapsedInMinute;
}

class _EmptyTimetableState extends StatelessWidget {
  const _EmptyTimetableState({
    required this.onCreate,
    required this.onImport,
    required this.onImportFromText,
    required this.onImportFromWeb,
  });

  final Future<void> Function()? onCreate;
  final Future<void> Function()? onImport;
  final Future<void> Function()? onImportFromText;
  final Future<void> Function()? onImportFromWeb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final importEnabled =
        onImport != null || onImportFromText != null || onImportFromWeb != null;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ExpressiveEmptyState(
            icon: Icons.event_busy_outlined,
            title: l10n.noTimetableTitle,
            message: l10n.noTimetableMessage,
            actions: [
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.createTimetable),
              ),
              MenuAnchor(
                key: const ValueKey('empty-timetable-import-menu'),
                menuChildren: [
                  MenuItemButton(
                    onPressed: onImport,
                    leadingIcon: const Icon(Icons.file_download_outlined),
                    child: Text(l10n.importTimetableFiles),
                  ),
                  MenuItemButton(
                    onPressed: onImportFromText,
                    leadingIcon: const Icon(Icons.paste_outlined),
                    child: Text(l10n.importTimetableText),
                  ),
                  MenuItemButton(
                    onPressed: onImportFromWeb,
                    leadingIcon: const Icon(Icons.language_outlined),
                    child: Text(l10n.schoolWebImportEntry),
                  ),
                ],
                builder: (context, controller, child) => OutlinedButton.icon(
                  key: const ValueKey('empty-timetable-import-button'),
                  onPressed: !importEnabled
                      ? null
                      : () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(l10n.importTimetable),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
