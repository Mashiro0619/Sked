part of 'general_schedule_home_screen.dart';

typedef GeneralReminderTimerFactory = Timer Function(
  Duration delay,
  VoidCallback callback,
);

@visibleForTesting
class GeneralReminderTimeScope extends InheritedWidget {
  const GeneralReminderTimeScope({
    super.key,
    required this.now,
    required this.createTimer,
    required super.child,
  });

  final DateTime Function() now;
  final GeneralReminderTimerFactory createTimer;

  static GeneralReminderTimeScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GeneralReminderTimeScope>();
  }

  @override
  bool updateShouldNotify(GeneralReminderTimeScope oldWidget) {
    return now != oldWidget.now || createTimer != oldWidget.createTimer;
  }
}

Timer _createGeneralReminderTimer(Duration delay, VoidCallback callback) {
  return Timer(delay, callback);
}

class _ReminderStrip extends StatefulWidget {
  const _ReminderStrip({
    required this.provider,
    required this.filter,
    required this.active,
    required this.onOccurrenceTap,
    required this.pane,
    this.listMode = false,
    this.actionBuilder,
    this.autoClose = false,
    this.isOwnerActive,
  });

  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final WorkspacePaneController pane;
  final bool listMode;
  final bool autoClose;
  final bool Function()? isOwnerActive;
  final Widget Function(BuildContext, int, VoidCallback?)? actionBuilder;

  @override
  State<_ReminderStrip> createState() => _ReminderStripState();
}

class _ReminderStripState extends State<_ReminderStrip>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _listOpen = false;
  final Set<String> _handling = {};
  DateTime Function() _now = DateTime.now;
  GeneralReminderTimerFactory _createTimer = _createGeneralReminderTimer;
  bool _isForeground = true;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timeScope = GeneralReminderTimeScope.maybeOf(context);
    final nextNow = timeScope?.now ?? DateTime.now;
    final nextCreateTimer =
        timeScope?.createTimer ?? _createGeneralReminderTimer;
    if (_now != nextNow || _createTimer != nextCreateTimer) {
      _now = nextNow;
      _createTimer = nextCreateTimer;
    }
    final wasTickerEnabled = _tickerEnabled;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _restartRefreshTimer(
      refreshImmediately: !wasTickerEnabled && _tickerEnabled && _canRefresh,
    );
  }

  @override
  void didUpdateWidget(covariant _ReminderStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _restartRefreshTimer(refreshImmediately: _canRefresh);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _refreshNow();
      return;
    }
    _isForeground = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshNow() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!_canRefresh) {
      return;
    }
    setState(() {});
    _scheduleRefreshTimer();
  }

  void _restartRefreshTimer({bool refreshImmediately = false}) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (refreshImmediately && _canRefresh) setState(() {});
    _scheduleRefreshTimer();
  }

  bool get _canRefresh =>
      mounted && widget.active && _tickerEnabled && _isForeground;

  void _scheduleRefreshTimer() {
    if (!_canRefresh) {
      return;
    }
    _refreshTimer = _createTimer(_delayUntilNextMinute(_now()), () {
      _refreshTimer = null;
      if (!_canRefresh) {
        return;
      }
      setState(() {});
      _scheduleRefreshTimer();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, _) => _buildContent(context),
  );

  Future<void> _handleReminder(GeneralEventOccurrence occurrence) async {
    final key = occurrence.occurrenceKey;
    if (!_handling.add(key)) return;
    setState(() {});
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Dismiss reminder',
        command: () => widget.provider.dismissGeneralReminder(occurrence),
      );
    } finally {
      _handling.remove(key);
      if (mounted) setState(() {});
    }
  }

  Widget _buildContent(BuildContext context) {
    final now = _now();
    final reminderFilter = widget.filter.toQuery(
      startInclusive: now.subtract(const Duration(hours: 24)),
      endExclusive: now.add(const Duration(hours: 24)),
    );
    final items = widget.provider.generalReminderItems(
      now: now,
      occurrenceFilter: reminderFilter,
    );
    final l = AppLocalizations.of(context);
    if (!widget.listMode) {
      final VoidCallback? openReminders = !widget.active || _listOpen
          ? null
          : () async {
              setState(() => _listOpen = true);
              try {
                // A manual activation replaces the startup preview with an
                // untimed task instead of stacking a duplicate reminder list.
                if (widget.pane.selectedId == 'general-reminders') {
                  await widget.pane.close();
                  await WidgetsBinding.instance.endOfFrame;
                  if (!mounted ||
                      widget.pane.selectedId == 'general-reminders') {
                    return;
                  }
                }
                await widget.pane.show<void>(
                  (context) => _ReminderStrip(
                    provider: widget.provider,
                    filter: widget.filter,
                    active: true,
                    pane: widget.pane,
                    listMode: true,
                    onOccurrenceTap: widget.onOccurrenceTap,
                  ),
                  selectionId: 'general-reminders',
                  presentation: WorkspacePanePresentation.view,
                );
              } finally {
                if (mounted) setState(() => _listOpen = false);
              }
            };
      if (widget.actionBuilder case final builder?) {
        return builder(context, items.length, openReminders);
      }
      return IconButton(
        key: const ValueKey('general-reminders-action'),
        tooltip: l.reminder,
        onPressed: openReminders,
        icon: Badge(
          isLabelVisible: items.isNotEmpty,
          label: Text('${items.length}'),
          child: const Icon(Icons.notifications_outlined),
        ),
      );
    }
    if (WorkbenchChromeMetrics.of(context).desktop) {
      final colors = Theme.of(context).colorScheme;
      final groups = [
        for (final status in [
          GeneralReminderStatus.inProgress,
          GeneralReminderStatus.upcoming,
          GeneralReminderStatus.overdue,
        ])
          (
            status: status,
            items: items.where((item) => item.status == status).toList(),
          ),
      ].where((group) => group.items.isNotEmpty).toList();
      return _ReminderAutoDismiss(
        enabled: widget.autoClose,
        isOwnerActive: widget.isOwnerActive ?? () => widget.active,
        builder: (context, automatic) => WorkspaceViewPanel(
          key: const ValueKey('general-reminders-list'),
          title: Text('${l.reminder} · ${items.length}'),
          subtitle: automatic ? Text(l.reminderAutoCloseHint) : null,
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l.noUpcomingEvents),
                ),
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: colors.outlineVariant),
                  ),
                Padding(
                  key: ValueKey(
                    'general-reminder-group-${groups[i].status.name}',
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: Row(
                    children: [
                      Icon(
                        _reminderStatusIcon(groups[i].status),
                        size: 16,
                        color: _reminderStatusColor(groups[i].status, colors),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_reminderStatusLabel(groups[i].status, l)} · ${groups[i].items.length}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _reminderStatusColor(
                                  groups[i].status,
                                  colors,
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final item in groups[i].items)
                  _ReminderSummaryRow(
                    item: item,
                    busy: _handling.contains(item.occurrence.occurrenceKey),
                    onOpen: () => widget.onOccurrenceTap(item.occurrence),
                    onHandle: () => unawaited(_handleReminder(item.occurrence)),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    return AppSheetScaffold(
      key: const ValueKey('general-reminders-list'),
      title: Text(l.reminder),
      child: Column(
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.noUpcomingEvents),
            ),
          for (final item in items)
            ListTile(
              title: Text(item.occurrence.event.title),
              subtitle: Text(
                '${switch (item.status) {
                  GeneralReminderStatus.upcoming => l.reminderUpcoming,
                  GeneralReminderStatus.inProgress => l.reminderInProgress,
                  GeneralReminderStatus.overdue => l.reminderEnded,
                }} · ${intl.DateFormat.MMMd(l.localeName).add_Hm().format(item.occurrence.start)}',
              ),
              onTap: () => widget.onOccurrenceTap(item.occurrence),
              trailing: IconButton(
                tooltip: l.markReminderHandled,
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => unawaited(
                  runUiCommandWithFeedback(
                    context: context,
                    debugLabel: 'Dismiss reminder',
                    command: () =>
                        widget.provider.dismissGeneralReminder(item.occurrence),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Duration _delayUntilNextMinute(DateTime now) {
  final elapsedInMinute = Duration(
    seconds: now.second,
    milliseconds: now.millisecond,
    microseconds: now.microsecond,
  );
  return const Duration(minutes: 1) - elapsedInMinute;
}

String _reminderStatusLabel(GeneralReminderStatus status, AppLocalizations l) =>
    switch (status) {
      GeneralReminderStatus.inProgress => l.reminderInProgress,
      GeneralReminderStatus.upcoming => l.reminderUpcoming,
      GeneralReminderStatus.overdue => l.reminderEnded,
    };
Color _reminderStatusColor(GeneralReminderStatus status, ColorScheme colors) =>
    switch (status) {
      GeneralReminderStatus.inProgress => skedReadableAccent(colors),
      GeneralReminderStatus.upcoming => colors.tertiary,
      GeneralReminderStatus.overdue => colors.onSurfaceVariant,
    };
IconData _reminderStatusIcon(GeneralReminderStatus status) => switch (status) {
  GeneralReminderStatus.inProgress => Icons.timelapse,
  GeneralReminderStatus.upcoming => Icons.schedule,
  GeneralReminderStatus.overdue => Icons.history,
};

class _ReminderSummaryRow extends StatelessWidget {
  const _ReminderSummaryRow({
    required this.item,
    required this.busy,
    required this.onOpen,
    required this.onHandle,
  });
  final GeneralReminderItem item;
  final bool busy;
  final VoidCallback onOpen, onHandle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final occurrence = item.occurrence;
    final start = occurrence.calendarDisplayStart;
    final end = occurrence.calendarDisplayEnd;
    final date = intl.DateFormat.MMMd(l.localeName);
    String time(DateTime value) =>
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(value),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
    final endDay = occurrence.isAllDay ? addCalendarDays(end, -1) : end;
    final sameDay = DateUtils.isSameDay(start, endDay);
    final dateLabel = sameDay
        ? date.format(start)
        : '${date.format(start)} – ${date.format(endDay)}';
    final timeLabel = occurrence.isAllDay
        ? l.allDay
        : sameDay
        ? '${time(start)} – ${time(end)}'
        : '${date.format(start)} ${time(start)} – ${date.format(end)} ${time(end)}';
    return ListTile(
      key: ValueKey('general-reminder-${occurrence.occurrenceKey}'),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      minVerticalPadding: 8,
      title: Text(
        occurrence.event.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              _reminderStatusLabel(item.status, l),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: _reminderStatusColor(item.status, theme.colorScheme),
              ),
            ),
            Text(
              occurrence.isAllDay || sameDay
                  ? '$dateLabel · $timeLabel'
                  : timeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      onTap: onOpen,
      trailing: IconButton(
        tooltip: l.markReminderHandled,
        style: WorkbenchChromeMetrics.of(context).iconStyle,
        icon: const Icon(Icons.check_circle_outline),
        onPressed: busy ? null : onHandle,
      ),
    );
  }
}

/// Runtime-only, owned by the app shell rather than a toolbar or resized page.
/// Explicit injection keeps standalone previews and manual panels independent.
class GeneralReminderStartupSession {
  GeneralReminderStartupSession({bool eligible = true}) : _checked = !eligible;
  bool _checked;
}

class _ReminderAutoDismiss extends StatefulWidget {
  const _ReminderAutoDismiss({
    required this.enabled,
    required this.isOwnerActive,
    required this.builder,
  });
  final bool enabled;
  final bool Function() isOwnerActive;
  final Widget Function(BuildContext, bool automatic) builder;
  @override
  State<_ReminderAutoDismiss> createState() => _ReminderAutoDismissState();
}

class _ReminderAutoDismissState extends State<_ReminderAutoDismiss>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _startedAt;
  Duration _remaining = const Duration(seconds: 10);
  late bool _automatic = widget.enabled;
  bool _hovering = false;
  bool _foreground = true;
  bool _visible = true;
  DateTime Function() _now = DateTime.now;
  GeneralReminderTimerFactory _createTimer = _createGeneralReminderTimer;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pause();
    final scope = GeneralReminderTimeScope.maybeOf(context);
    _now = scope?.now ?? DateTime.now;
    _createTimer = scope?.createTimer ?? _createGeneralReminderTimer;
    _route = ModalRoute.of(context);
    _visible = TickerMode.valuesOf(context).enabled;
    _resume();
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (_startedAt case final started?) {
      final elapsed = _now().difference(started);
      if (elapsed > Duration.zero) {
        _remaining -= elapsed;
        if (_remaining < Duration.zero) _remaining = Duration.zero;
      }
    }
    _startedAt = null;
  }

  void _resume() {
    if (!_automatic ||
        _hovering ||
        !_foreground ||
        !_visible ||
        _route?.isCurrent != true ||
        !widget.isOwnerActive() ||
        _timer != null) {
      return;
    }
    _startedAt = _now();
    _timer = _createTimer(_remaining, () {
      _timer = null;
      _startedAt = null;
      if (!mounted || !_automatic) return;
      // Never close whatever a controller now calls "top": this exact route
      // must still own focus/input, with no newer root dialog or child task.
      if (!_hovering &&
          _foreground &&
          _visible &&
          _route?.isCurrent == true &&
          widget.isOwnerActive()) {
        unawaited(_route!.navigator!.maybePop());
      }
      _keepOpen();
    });
  }

  void _keepOpen() {
    if (!_automatic) return;
    _pause();
    setState(() => _automatic = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _pause();
    _foreground = state == AppLifecycleState.resumed;
    _resume();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) {
      _hovering = true;
      _pause();
    },
    onExit: (_) {
      _hovering = false;
      _resume();
    },
    child: Listener(
      onPointerDown: (_) => _keepOpen(),
      onPointerSignal: (_) => _keepOpen(),
      onPointerPanZoomStart: (_) => _keepOpen(),
      child: Focus(
        autofocus: widget.enabled,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: (_, _) {
          _keepOpen();
          return KeyEventResult.ignored;
        },
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (_) {
            _keepOpen();
            return false;
          },
          child: widget.builder(context, _automatic),
        ),
      ),
    ),
  );
}
