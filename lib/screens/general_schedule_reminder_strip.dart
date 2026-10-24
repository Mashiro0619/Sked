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
    required this.view,
    required this.commands,
    required this.filter,
    required this.active,
    required this.onOccurrenceTap,
    required this.pane,
    this.listMode = false,
    this.actionBuilder,
    this.autoClose = false,
    this.isOwnerActive,
  });

  final GeneralViewState view;
  final GeneralCommands commands;
  final _GeneralOccurrenceFilter filter;
  final bool active;
  final _GeneralOccurrenceTap onOccurrenceTap;
  final WorkspacePaneController pane;
  final bool listMode;
  final bool autoClose;
  final bool Function()? isOwnerActive;
  final Widget Function(BuildContext, int, ValueChanged<BuildContext>?)?
  actionBuilder;

  @override
  State<_ReminderStrip> createState() => _ReminderStripState();
}

class _ReminderStripState extends State<_ReminderStrip>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _listOpen = false;
  final Set<String> _handling = {};
  final _rowsViewportKey = GlobalKey();
  static const _pageSize = 100;
  int _pageIndex = 0;
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
    if (oldWidget.filter.query != widget.filter.query ||
        oldWidget.filter.colorValue != widget.filter.colorValue) {
      _pageIndex = 0;
    }
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
    listenable: widget.view,
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
        command: () => widget.commands.dismissReminder(occurrence),
      );
    } finally {
      _handling.remove(key);
      if (mounted) setState(() {});
    }
  }

  void _changePage(int page) {
    final rowContext = _rowsViewportKey.currentContext;
    if (rowContext != null) Scrollable.maybeOf(rowContext)?.position.jumpTo(0);
    setState(() => _pageIndex = page);
  }

  Widget _pageControls(int page, int pageCount, int total) {
    final material = MaterialLocalizations.of(context);
    return Row(
      key: const ValueKey('general-reminder-pagination'),
      children: [
        IconButton(
          key: const ValueKey('general-reminder-first-page'),
          tooltip: material.firstPageTooltip,
          onPressed: page > 0 ? () => _changePage(0) : null,
          icon: const Icon(Icons.first_page),
        ),
        IconButton(
          key: const ValueKey('general-reminder-previous-page'),
          tooltip: material.previousPageTooltip,
          onPressed: page > 0 ? () => _changePage(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            material.pageRowsInfoTitle(
              page * _pageSize + 1,
              math.min((page + 1) * _pageSize, total),
              total,
              false,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          key: const ValueKey('general-reminder-next-page'),
          tooltip: material.nextPageTooltip,
          onPressed: page + 1 < pageCount ? () => _changePage(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          key: const ValueKey('general-reminder-last-page'),
          tooltip: material.lastPageTooltip,
          onPressed: page + 1 < pageCount
              ? () => _changePage(pageCount - 1)
              : null,
          icon: const Icon(Icons.last_page),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final now = _now();
    final reminderFilter = widget.filter.toQuery(
      startInclusive: now.subtract(const Duration(hours: 24)),
      endExclusive: now.add(const Duration(hours: 24)),
    );
    final items = widget.view.reminderItems(
      now: now,
      occurrenceFilter: reminderFilter,
    );
    final l = AppLocalizations.of(context);
    if (!widget.listMode) {
      final ValueChanged<BuildContext>? openReminders =
          !widget.active || _listOpen
          ? null
          : (anchor) async {
              final anchorRect = WorkspaceEditorConfiguration(
                anchorContext: anchor,
              ).initialAnchor;
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
                    view: widget.view,
                    commands: widget.commands,
                    filter: widget.filter,
                    active: true,
                    pane: widget.pane,
                    listMode: true,
                    onOccurrenceTap: widget.onOccurrenceTap,
                    isOwnerActive: widget.isOwnerActive,
                  ),
                  selectionId: 'general-reminders',
                  layoutKey: DesktopLayoutRegion.reminderList,
                  presentation: WorkspacePanePresentation.view,
                  anchorRect: anchorRect,
                );
              } finally {
                if (mounted) setState(() => _listOpen = false);
              }
            };
      if (widget.actionBuilder case final builder?) {
        return builder(context, items.length, openReminders);
      }
      return Builder(
        builder: (anchor) => IconButton(
          key: const ValueKey('general-reminders-action'),
          tooltip: l.reminder,
          onPressed: openReminders == null ? null : () => openReminders(anchor),
          icon: Badge(
            isLabelVisible: items.isNotEmpty,
            label: Text('${items.length}'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      );
    }
    // Variable-height slivers walk intermediate rows during distant jumps.
    // Bound each viewport to a page while retaining every indexed reminder.
    final paged = items is GeneralReminderItems && items.length > _pageSize;
    final pageCount = paged ? (items.length + _pageSize - 1) ~/ _pageSize : 1;
    final page = _pageIndex.clamp(0, pageCount - 1);
    final firstRow = paged ? page * _pageSize : 0;
    final endRow = paged
        ? math.min(firstRow + _pageSize, items.length)
        : items.length;
    final pagination = paged
        ? _pageControls(page, pageCount, items.length)
        : null;
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
            count: items is GeneralReminderItems
                ? items.countForStatus(status)
                : items.where((item) => item.status == status).length,
          ),
      ].where((group) => group.count > 0).toList();
      final groupStarts = <String, int>{};
      var groupOffset = 0;
      for (var index = 0; index < groups.length; index++) {
        final groupEnd = groupOffset + groups[index].count;
        if (firstRow < groupEnd && endRow > groupOffset) {
          groupStarts[items[math.max(groupOffset, firstRow)]
                  .occurrence
                  .occurrenceKey] =
              index;
        }
        groupOffset = groupEnd;
      }
      return _ReminderAutoDismiss(
        enabled: widget.autoClose,
        isOwnerActive: widget.isOwnerActive ?? () => widget.active,
        builder: (context, automatic) => _EventListDetailsBinding(
          builder: (context, host, source) => WorkspaceViewPanel(
            bodyViewportKey: source.bodyKey,
            key: const ValueKey('general-reminders-list'),
            title: Text('${l.reminder} · ${items.length}'),
            toolbar: pagination,
            subtitle: automatic ? Text(l.reminderAutoCloseHint) : null,
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            bodyIsSliver: true,
            semanticChildCount: items.length,
            child: items.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l.noUpcomingEvents),
                    ),
                  )
                // Keep every reminder in one lazy sequence. Separate lists
                // build each group's first row off screen, letting geometric
                // focus traversal jump past unbuilt rows in the current group.
                : _reminderRowsSliver(
                    items,
                    (item) {
                      final row = host.row(
                        item.occurrence,
                        source: source,
                        builder: (activate) => _ReminderSummaryRow(
                          item: item,
                          busy: _handling.contains(
                            item.occurrence.occurrenceKey,
                          ),
                          onOpen: (_) => activate(),
                          onHandle: () {
                            if (host.session.blocked) return;
                            host.session.dismissPreview();
                            unawaited(_handleReminder(item.occurrence));
                          },
                        ),
                      );
                      final groupIndex =
                          groupStarts[item.occurrence.occurrenceKey];
                      final group = groupIndex == null
                          ? null
                          : groups[groupIndex];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (groupIndex != null && groupIndex > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                height: 1,
                                color: colors.outlineVariant,
                              ),
                            ),
                          if (group != null)
                            Padding(
                              key: ValueKey(
                                'general-reminder-group-${group.status.name}',
                              ),
                              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                              child: Row(
                                children: [
                                  Icon(
                                    _reminderStatusIcon(group.status),
                                    size: 16,
                                    color: _reminderStatusColor(
                                      group.status,
                                      colors,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${_reminderStatusLabel(group.status, l)} · ${group.count}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _reminderStatusColor(
                                              group.status,
                                              colors,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          row,
                        ],
                      );
                    },
                    key: _rowsViewportKey,
                    start: firstRow,
                    end: endRow,
                  ),
          ),
        ),
      );
    }
    return AppSheetScaffold(
      key: const ValueKey('general-reminders-list'),
      title: Text(l.reminder),
      bodyIsSliver: true,
      semanticChildCount: items.length,
      footer: pagination,
      child: SliverMainAxisGroup(
        slivers: [
          if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.noUpcomingEvents),
              ),
            ),
          _reminderRowsSliver(
            items,
            (item) => _ReminderSummaryRow(
              item: item,
              busy: _handling.contains(item.occurrence.occurrenceKey),
              onOpen: (anchor) =>
                  widget.onOccurrenceTap(item.occurrence, anchor),
              onHandle: () => unawaited(_handleReminder(item.occurrence)),
            ),
            key: _rowsViewportKey,
            start: firstRow,
            end: endRow,
          ),
        ],
      ),
    );
  }
}

Widget _reminderRowsSliver(
  List<GeneralReminderItem> items,
  Widget Function(GeneralReminderItem) buildRow, {
  Key? key,
  int start = 0,
  int? end,
}) {
  final endIndex = end ?? items.length;
  final indices = items is GeneralReminderItems
      ? null
      : {
          for (var index = start; index < endIndex; index++)
            items[index].occurrence.occurrenceKey: index,
        };
  // Cache rows above the viewport can geometrically overlap the fixed panel
  // header. Traverse this sequence as one group so reverse Tab cannot jump to
  // a header control before reaching the previous reminder.
  return FocusTraversalGroup(
    key: key,
    child: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[start + index];
          return KeyedSubtree(
            key: ValueKey(item.occurrence.occurrenceKey),
            child: buildRow(item),
          );
        },
        childCount: endIndex - start,
        semanticIndexOffset: start,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String>) return null;
          final index = items is GeneralReminderItems
              ? items.indexOfOccurrenceKey(key.value)
              : indices![key.value];
          return index != null && index >= start && index < endIndex
              ? index - start
              : null;
        },
      ),
    ),
  );
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
  final ValueChanged<BuildContext> onOpen;
  final VoidCallback onHandle;
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
    return ExpressiveDialogOption(
      key: ValueKey('general-reminder-${occurrence.occurrenceKey}'),
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
      onTap: () => onOpen(context),
      trailing: _ReminderHandledTooltip(
        message: l.markReminderHandled,
        child: IconButton(
          style: WorkbenchChromeMetrics.of(context).iconStyle,
          // Keep the name inside IconButton's own semantics boundary.
          icon: Semantics(
            tooltip: l.markReminderHandled,
            child: const Icon(Icons.check_circle_outline),
          ),
          onPressed: busy ? null : onHandle,
        ),
      ),
    );
  }
}

/// A lazy row can lose its semantics anchor before RawTooltip's deferred portal
/// finishes an update. Keep Material's presentation and interaction settings,
/// but attach this tooltip directly to the overlay's stable traversal tree.
class _ReminderHandledTooltip extends Tooltip {
  const _ReminderHandledTooltip({
    required String message,
    required Widget child,
  }) : super(message: message, child: child);

  @override
  State<Tooltip> createState() => _ReminderHandledTooltipState();
}

class _ReminderHandledTooltipState extends TooltipState {
  final _overlayKey = GlobalKey<_ReminderOverlayTooltipState>();

  @override
  bool ensureTooltipVisible() =>
      _overlayKey.currentState?.ensureTooltipVisible() ?? false;

  @override
  Widget build(BuildContext context) {
    // Material currently exposes its resolved presentation as RawTooltip.
    // Keep the overlay/semantics regressions when upgrading that SDK contract.
    final material = super.build(context);
    if (material is! RawTooltip) return material;
    return _ReminderOverlayTooltip(key: _overlayKey, configuration: material);
  }
}

class _ReminderOverlayTooltip extends RawTooltip {
  _ReminderOverlayTooltip({super.key, required this.configuration})
    : super(
        semanticsTooltip: configuration.semanticsTooltip,
        tooltipBuilder: configuration.tooltipBuilder,
        child: configuration.child,
      );

  final RawTooltip configuration;

  @override
  State<RawTooltip> createState() => _ReminderOverlayTooltipState();
}

class _ReminderOverlayTooltipState extends State<_ReminderOverlayTooltip>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static _ReminderOverlayTooltipState? _active;
  AnimationController? _backingController;
  CurvedAnimation? _backingAnimation;
  OverlayEntry? _entry;
  Timer? _timer;
  ScrollPosition? _scrollPosition;
  ModalRoute<dynamic>? _route;
  bool _tickerEnabled = true;
  ThemeData? _theme;
  TooltipThemeData? _tooltipTheme;
  CapturedThemes? _themes;
  Offset _target = Offset.zero;
  Size _targetSize = Size.zero;

  RawTooltip get _configuration => widget.configuration;
  bool get _sourceVisible =>
      mounted && _tickerEnabled && (_route?.isCurrent ?? true);

  AnimationController get _controller {
    if (_backingController case final controller?) return controller;
    final style = _configuration.animationStyle;
    return _backingController =
        AnimationController(
          vsync: this,
          duration: style.duration ?? const Duration(milliseconds: 150),
          reverseDuration:
              style.reverseDuration ?? const Duration(milliseconds: 75),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) _removeEntry();
        });
  }

  CurvedAnimation get _animation => _backingAnimation ??= CurvedAnimation(
    parent: _controller,
    curve: _configuration.animationStyle.curve ?? Curves.fastOutSlowIn,
    reverseCurve: _configuration.animationStyle.reverseCurve,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointerEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    final theme = Theme.of(context);
    final tooltipTheme = TooltipTheme.of(context);
    if (!_sourceVisible || _theme != theme || _tooltipTheme != tooltipTheme) {
      _hideImmediately();
    }
    _theme = theme;
    _tooltipTheme = tooltipTheme;
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(_scrollPosition, position)) {
      _scrollPosition?.removeListener(_hideImmediately);
      _scrollPosition = position;
      position?.addListener(_hideImmediately);
    }
  }

  @override
  void didUpdateWidget(_ReminderOverlayTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.semanticsTooltip != widget.semanticsTooltip) {
      _hideImmediately();
    }
  }

  @override
  void didChangeMetrics() => _hideImmediately();

  void _pointerEvent(PointerEvent event) {
    if (event is PointerDownEvent && _configuration.enableTapToDismiss) {
      _hideImmediately();
    }
  }

  void _scheduleShow() {
    _timer?.cancel();
    final delay = _configuration.hoverDelay;
    if (delay == Duration.zero || _entry != null) {
      ensureTooltipVisible();
    } else {
      _timer = Timer(delay, ensureTooltipVisible);
    }
  }

  bool ensureTooltipVisible() {
    _timer?.cancel();
    _timer = null;
    if (!_sourceVisible) return false;
    if (_entry != null) {
      _controller.forward();
      return false;
    }
    final overlay = Overlay.of(context);
    final sourceBox = context.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    if (sourceBox is! RenderBox ||
        overlayBox is! RenderBox ||
        !sourceBox.attached ||
        !sourceBox.hasSize) {
      return false;
    }
    _active?._hideImmediately();
    RawTooltip.dismissAllToolTips();
    _active = this;
    _target = sourceBox.localToGlobal(
      sourceBox.size.center(Offset.zero),
      ancestor: overlayBox,
    );
    _targetSize = sourceBox.size;
    _themes = InheritedTheme.capture(from: context, to: overlay.context);
    _entry = OverlayEntry(builder: _buildEntry);
    overlay.insert(_entry!);
    _controller.forward(from: 0);
    unawaited(SemanticsService.tooltip(_configuration.semanticsTooltip ?? ''));
    return true;
  }

  void _scheduleDismiss(Duration delay) {
    _timer?.cancel();
    _timer = null;
    if (_entry == null) return;
    if (delay == Duration.zero) {
      _controller.reverse();
    } else {
      _timer = Timer(delay, _controller.reverse);
    }
  }

  void _removeEntry() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    if (identical(_active, this)) _active = null;
  }

  void _hideImmediately() {
    _timer?.cancel();
    _timer = null;
    _removeEntry();
    _backingController?.reset();
  }

  Widget _buildEntry(BuildContext context) => _themes!.wrap(
    Positioned.fill(
      bottom: MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0,
      child: CustomSingleChildLayout(
        delegate: _ReminderTooltipPosition(
          target: _target,
          targetSize: _targetSize,
          position: _configuration.positionDelegate,
        ),
        child: IgnorePointer(
          ignoring: _configuration.ignorePointer,
          child: SelectionContainer.disabled(
            child: _configuration.tooltipBuilder(context, _animation),
          ),
        ),
      ),
    ),
  );

  void _longPress() {
    if (_entry == null && _configuration.enableFeedback) {
      unawaited(Feedback.forLongPress(context));
    }
    _configuration.onTriggered?.call();
    ensureTooltipVisible();
  }

  void _tap() {
    if (_entry == null && _configuration.enableFeedback) {
      unawaited(Feedback.forTap(context));
    }
    _configuration.onTriggered?.call();
    ensureTooltipVisible();
    _scheduleDismiss(_configuration.touchDelay);
  }

  @override
  void deactivate() {
    _hideImmediately();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointerEvent);
    _scrollPosition?.removeListener(_hideImmediately);
    _timer?.cancel();
    _removeEntry();
    _backingAnimation?.dispose();
    _backingController?.dispose();
    super.dispose();
  }

  @override
  // The button supplies its own name; an outer annotation would label the row.
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _scheduleShow(),
    onExit: (_) => _scheduleDismiss(_configuration.dismissDelay),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      supportedDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      },
      onLongPress: _configuration.triggerMode == TooltipTriggerMode.longPress
          ? _longPress
          : null,
      onLongPressEnd: _configuration.triggerMode == TooltipTriggerMode.longPress
          ? (_) => _scheduleDismiss(_configuration.touchDelay)
          : null,
      onTap: _configuration.triggerMode == TooltipTriggerMode.tap ? _tap : null,
      child: _configuration.child,
    ),
  );
}

class _ReminderTooltipPosition extends SingleChildLayoutDelegate {
  const _ReminderTooltipPosition({
    required this.target,
    required this.targetSize,
    required this.position,
  });

  final Offset target;
  final Size targetSize;
  final TooltipPositionDelegate? position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      position?.call(
        TooltipPositionContext(
          target: target,
          targetSize: targetSize,
          tooltipSize: childSize,
          overlaySize: size,
          verticalOffset: 24,
        ),
      ) ??
      positionDependentBox(
        size: size,
        childSize: childSize,
        target: target,
        verticalOffset: 24,
        preferBelow: true,
      );

  @override
  bool shouldRelayout(_ReminderTooltipPosition oldDelegate) =>
      target != oldDelegate.target ||
      targetSize != oldDelegate.targetSize ||
      position != oldDelegate.position;
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
  bool _secondaryHover = false;
  void setSecondaryHover(bool value) {
    if (_secondaryHover == value) return;
    _secondaryHover = value;
    if (value) {
      _pause();
    } else {
      _resume();
    }
  }

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
        _secondaryHover ||
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
          !_secondaryHover &&
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
