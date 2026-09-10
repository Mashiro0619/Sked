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
  });

  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;
  final WorkspacePaneController pane;
  final bool listMode;

  @override
  State<_ReminderStrip> createState() => _ReminderStripState();
}

class _ReminderStripState extends State<_ReminderStrip>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _listOpen = false;
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
  Widget build(BuildContext context) {
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
      return IconButton(
        key: const ValueKey('general-reminders-action'),
        tooltip: l.reminder,
        onPressed: !widget.active || _listOpen
            ? null
            : () async {
                setState(() => _listOpen = true);
                try {
                  await widget.pane.show<void>(
                    (context) => _ReminderStrip(
                      provider: widget.provider,
                      filter: widget.filter,
                      active: true,
                      pane: widget.pane,
                      listMode: true,
                      onOccurrenceTap: widget.onOccurrenceTap,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _listOpen = false);
                }
              },
        icon: Badge(
          isLabelVisible: items.isNotEmpty,
          label: Text('${items.length}'),
          child: const Icon(Icons.notifications_outlined),
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
                  GeneralReminderStatus.overdue => l.reminderOverdue,
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
