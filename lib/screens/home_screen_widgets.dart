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

class _StudentHomeAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _StudentHomeAppBar({
    required this.provider,
    required this.timetable,
    required this.week,
    required this.showModeSwitch,
    required this.showSettings,
    this.settingsFocusNode,
    required this.onTitleTap,
    required this.onAddCourse,
    required this.onOpenSettings,
  });

  final TimetableProvider provider;
  final TimetableData timetable;
  final int week;
  final bool showModeSwitch;
  final bool showSettings;
  final FocusNode? settingsFocusNode;
  final VoidCallback? onTitleTap;
  final VoidCallback? onAddCourse;
  final VoidCallback? onOpenSettings;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      titleSpacing: AppSpacing.md,
      title: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTitleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.weekLabel(week),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                timetable.config.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (showModeSwitch) const ModeSwitchAction(),
        IconButton(
          onPressed: onAddCourse,
          icon: const Icon(Icons.add),
          tooltip: l10n.addCourse,
        ),
        if (showSettings)
          IconButton(
            focusNode: settingsFocusNode,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
          ),
      ],
    );
  }
}

class _TimetableDrawer extends StatelessWidget {
  const _TimetableDrawer({
    required this.provider,
    required this.activeTimetable,
    required this.switchingTimetable,
    required this.onSwitchTimetable,
    required this.onEditTimetable,
    required this.onCreateTimetable,
  });

  final TimetableProvider provider;
  final TimetableData activeTimetable;
  final bool switchingTimetable;
  final void Function(BuildContext context, TimetableData timetable)?
  onSwitchTimetable;
  final ValueChanged<TimetableData>? onEditTimetable;
  final Future<void> Function()? onCreateTimetable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.multiTimetableSwitch,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in provider.timetables)
                    _TimetableDrawerItem(
                      timetable: item,
                      selected: item.id == activeTimetable.id,
                      enabled: !switchingTimetable,
                      currentLabel: l10n.currentTimetableWeeks(
                        item.config.totalWeeks,
                      ),
                      switchLabel: l10n.tapToSwitchWeeks(
                        item.config.totalWeeks,
                      ),
                      editTooltip: l10n.editTimetable,
                      onEdit: onEditTimetable == null || switchingTimetable
                          ? null
                          : () => onEditTimetable!(item),
                      onTap: switchingTimetable || onSwitchTimetable == null
                          ? null
                          : () => onSwitchTimetable!(context, item),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FilledButton.icon(
                onPressed: onCreateTimetable,
                icon: const Icon(Icons.add),
                label: Text(l10n.createTimetable),
              ),
            ),
          ],
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
    return Padding(
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
        itemCount: widget.config.totalWeeks,
        onPageChanged: (index) {
          if (widget.active && widget.interactive) {
            unawaited(widget.provider.setSelectedWeek(index + 1));
          }
        },
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
                onCourseTap: widget.onCourseTap,
                onEmptySlotTap: widget.onEmptySlotTap,
              ),
            ),
          );
        },
      ),
    );
    final shortcutsEnabled = _shortcutsEnabled && widget.interactive;
    return CallbackShortcuts(
      bindings: shortcutsEnabled
          ? {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                unawaited(widget.onJumpWeekBy(-1));
              },
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                unawaited(widget.onJumpWeekBy(1));
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
    return ExpressiveEmptyState(
      icon: Icons.event_busy_outlined,
      title: l10n.noTimetableTitle,
      message: l10n.noTimetableMessage,
      actions: [
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: Text(l10n.createTimetable),
        ),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(l10n.importTimetable),
        ),
        OutlinedButton.icon(
          onPressed: onImportFromText,
          icon: const Icon(Icons.paste_outlined),
          label: Text(l10n.importTimetableText),
        ),
        OutlinedButton.icon(
          onPressed: onImportFromWeb,
          icon: const Icon(Icons.language_outlined),
          label: Text(l10n.schoolWebImportEntry),
        ),
      ],
    );
  }
}
