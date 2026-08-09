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
    required this.viewMode,
    required this.compactHeight,
    required this.interactive,
    required this.showSettings,
    this.settingsFocusNode,
    required this.onOpenTimetablePicker,
    required this.onOpenWeekPicker,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onToday,
    required this.onViewChanged,
    required this.onOpenDisplaySettings,
    required this.onOpenSettings,
  });

  final TimetableData timetable;
  final int week;
  final _StudentTimetableView viewMode;
  final bool compactHeight;
  final bool interactive;
  final bool showSettings;
  final FocusNode? settingsFocusNode;
  final VoidCallback? onOpenTimetablePicker;
  final VoidCallback? onOpenWeekPicker;
  final VoidCallback? onPreviousWeek;
  final VoidCallback? onNextWeek;
  final VoidCallback? onToday;
  final ValueChanged<_StudentTimetableView>? onViewChanged;
  final VoidCallback? onOpenDisplaySettings;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final controlShape = skedShapeSchemeOf(context).control;
    final titleButtonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: const Size(48, 48),
      shape: controlShape,
      alignment: AlignmentDirectional.centerStart,
      textStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final timetableSelector = TextButton.icon(
      key: const ValueKey('student-timetable-picker-button'),
      onPressed: interactive ? onOpenTimetablePicker : null,
      style: titleButtonStyle,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          timetable.config.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    final displaySettingsAction = IconButton(
      key: const ValueKey('student-display-settings-button'),
      onPressed: onOpenDisplaySettings,
      icon: const Icon(Icons.tune_rounded),
      tooltip: l10n.timetableDisplaySettings,
    );
    final settingsAction = IconButton(
      focusNode: settingsFocusNode,
      onPressed: onOpenSettings,
      icon: const Icon(Icons.settings_outlined),
      tooltip: l10n.settings,
    );
    return SkedWorkspaceToolbar(
      key: const ValueKey('student-workspace-toolbar'),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compactHeight ? 8 : 12,
      ),
      title: compactHeight
          ? Row(
              children: [
                Expanded(child: timetableSelector),
                displaySettingsAction,
                if (showSettings) settingsAction,
              ],
            )
          : timetableSelector,
      actions: compactHeight
          ? const []
          : [displaySettingsAction, if (showSettings) settingsAction],
      navigation: LayoutBuilder(
        builder: (context, constraints) {
          final selector = SkedExpressiveSegmentedButton<_StudentTimetableView>(
            key: const ValueKey('student-day-week-selector'),
            segments: [
              ButtonSegment(
                value: _StudentTimetableView.day,
                icon: compactHeight
                    ? null
                    : const Icon(Icons.view_day_outlined),
                label: Text(l10n.viewDay),
              ),
              ButtonSegment(
                value: _StudentTimetableView.week,
                icon: compactHeight
                    ? null
                    : const Icon(Icons.view_week_outlined),
                label: Text(l10n.viewWeek),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: onViewChanged == null
                ? null
                : (selection) => onViewChanged!(selection.single),
          );
          final weekControls = Wrap(
            spacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('student-previous-week'),
                onPressed: onPreviousWeek,
                icon: Icon(
                  isRtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                ),
                tooltip: l10n.weekLabel(math.max(1, week - 1)),
              ),
              TextButton.icon(
                key: const ValueKey('student-week-picker-button'),
                onPressed: interactive ? onOpenWeekPicker : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: controlShape,
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(l10n.weekLabel(week)),
              ),
              if (compactHeight)
                IconButton(
                  key: const ValueKey('student-today-button'),
                  onPressed: onToday,
                  icon: const Icon(Icons.today_outlined),
                  tooltip: l10n.today,
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('student-today-button'),
                  onPressed: onToday,
                  icon: const Icon(Icons.today_outlined),
                  label: Text(l10n.today),
                ),
              IconButton(
                key: const ValueKey('student-next-week'),
                onPressed: onNextWeek,
                icon: Icon(
                  isRtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
                tooltip: l10n.weekLabel(
                  math.min(timetable.config.totalWeeks, week + 1),
                ),
              ),
            ],
          );
          if (compactHeight) {
            return Wrap(
              key: const ValueKey('student-toolbar-compact-navigation'),
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [selector, weekControls],
            );
          }
          if (constraints.maxWidth < 720) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [selector, weekControls],
            );
          }
          return Row(children: [selector, const Spacer(), weekControls]);
        },
      ),
    );
  }
}

class _StudentDayStrip extends StatefulWidget {
  const _StudentDayStrip({
    required this.weekStart,
    required this.selectedWeekday,
    required this.enabled,
    required this.onSelected,
  });

  final DateTime weekStart;
  final int selectedWeekday;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  State<_StudentDayStrip> createState() => _StudentDayStripState();
}

class _StudentDayStripState extends State<_StudentDayStrip> {
  static const _itemExtent = 64.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleRevealSelected();
  }

  @override
  void didUpdateWidget(covariant _StudentDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeekday != widget.selectedWeekday ||
        oldWidget.weekStart != widget.weekStart) {
      _scheduleRevealSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleRevealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final selectedCenter = ((widget.selectedWeekday - 1) * _itemExtent) + 29;
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
    final stripHeight = math
        .max(68.0, textScaler.scale(40) + 20)
        .ceilToDouble();
    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        key: const ValueKey('student-day-strip'),
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
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
            label: MaterialLocalizations.of(context).formatFullDate(date),
            child: AnimatedContainer(
              key: ValueKey('student-day-$weekday'),
              duration: motion.effects(SkedMotionSpeed.fast),
              curve: motion.scheme.standardCurve,
              width: 58,
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
    required this.active,
    required this.interactive,
    required this.viewMode,
    required this.selectedWeekday,
    this.shortcutFocusNode,
    required this.onJumpWeekBy,
    required this.onCourseTap,
    required this.onEmptySlotTap,
  });

  final PageController controller;
  final TimetableProvider provider;
  final TimetableData timetable;
  final TimetableConfig config;
  final bool active;
  final bool interactive;
  final _StudentTimetableView viewMode;
  final int selectedWeekday;
  final FocusNode? shortcutFocusNode;
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

  @override
  Widget build(BuildContext context) {
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
      child: PageView.builder(
        key: const ValueKey('student-week-pager'),
        controller: widget.controller,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.config.totalWeeks,
        itemBuilder: (context, index) {
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
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 0, AppSpacing.md),
            child: RepaintBoundary(
              child: TimetableGrid(
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
                liveCourseOutlineWidth: widget.provider.liveCourseOutlineWidth,
                visibleWeekdays: widget.viewMode == _StudentTimetableView.day
                    ? [widget.selectedWeekday]
                    : const <int>[1, 2, 3, 4, 5, 6, 7],
                showDayHeader: widget.viewMode != _StudentTimetableView.day,
                onCourseTap: widget.onCourseTap,
                onEmptySlotTap: widget.onEmptySlotTap,
              ),
            ),
          );
        },
      ),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final horizontalGridMayScroll =
        widget.viewMode == _StudentTimetableView.week &&
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
