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
  });

  final TimetableProvider provider;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  State<_ReminderStrip> createState() => _ReminderStripState();
}

class _ReminderStripState extends State<_ReminderStrip>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
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
    final upcoming = items
        .where((item) => item.status == GeneralReminderStatus.upcoming)
        .take(3)
        .toList();
    final inProgress = items
        .where((item) => item.status == GeneralReminderStatus.inProgress)
        .take(3)
        .toList();
    final overdue = items
        .where((item) => item.status == GeneralReminderStatus.overdue)
        .take(3)
        .toList();
    if (upcoming.isEmpty && inProgress.isEmpty && overdue.isEmpty) {
      return const SizedBox(height: 4);
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          for (final item in upcoming)
            _GeneralReminderItemPill(
              item: item,
              statusLabel: l10n.reminderUpcoming,
              color: theme.colorScheme.primary,
              onTap: () => widget.onOccurrenceTap(item.occurrence),
              onDismiss: () =>
                  widget.provider.dismissGeneralReminder(item.occurrence),
            ),
          for (final item in inProgress)
            _GeneralReminderItemPill(
              item: item,
              statusLabel: l10n.reminderInProgress,
              color: theme.colorScheme.tertiary,
              onTap: () => widget.onOccurrenceTap(item.occurrence),
              onDismiss: () =>
                  widget.provider.dismissGeneralReminder(item.occurrence),
            ),
          for (final item in overdue)
            _GeneralReminderItemPill(
              item: item,
              statusLabel: l10n.reminderOverdue,
              color: theme.colorScheme.error,
              onTap: () => widget.onOccurrenceTap(item.occurrence),
              onDismiss: () =>
                  widget.provider.dismissGeneralReminder(item.occurrence),
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

class _GeneralReminderItemPill extends StatelessWidget {
  const _GeneralReminderItemPill({
    required this.item,
    required this.statusLabel,
    required this.color,
    required this.onTap,
    required this.onDismiss,
  });

  final GeneralReminderItem item;
  final String statusLabel;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${item.occurrence.event.title}, $statusLabel',
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(96)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 2),
            child: Row(
              children: [
                Icon(
                  item.status == GeneralReminderStatus.upcoming
                      ? Icons.notifications_active_outlined
                      : item.status == GeneralReminderStatus.inProgress
                      ? Icons.play_circle_outline
                      : Icons.pending_actions_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$statusLabel - ${item.occurrence.event.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color),
                  ),
                ),
                IconButton(
                  tooltip: l10n.markReminderHandled,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.check_circle_outline),
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
