import '../theme/sked_surface.dart';

import '../widgets/desktop_window_host.dart';
import '../widgets/workbench_chrome_metrics.dart';
import '../widgets/workbench_compact_calendar_bar.dart';
import '../utils/calendar_timeline_layout.dart';
import '../widgets/workbench_resource_widgets.dart';
import '../widgets/sked_date_picker.dart';
import '../widgets/sked_calendar_day_label.dart';
import '../utils/date_selection.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lunar/lunar.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../models/workspace_context_snapshot.dart';
import '../providers/timetable_provider.dart';
import '../utils/general_schedule_colors.dart';
import '../widgets/app_modal_sheet.dart';
import '../widgets/workspace_frame.dart';
import '../widgets/assistant_pane.dart';
import '../widgets/app_layout_tokens.dart';
import '../widgets/editor_exit_guard.dart';
import '../widgets/workspace_route_lifecycle.dart';
import '../widgets/workspace_navigation.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/general_event_details_sheet.dart';
import '../widgets/general_event_editor_sheet.dart';
import '../widgets/sked_expressive_components.dart';
import '../widgets/sked_popup_menu.dart';
import '../widgets/ui_command.dart';
import '../theme/app_motion.dart';
import '../theme/sked_expressive_theme.dart';
import 'settings_page.dart';

part 'general_schedule_list_view.dart';
part 'general_schedule_reminder_strip.dart';
part 'general_schedule_timeline_view.dart';
part 'general_schedule_timeline_components.dart';
part 'general_schedule_calendar_manager.dart';
part 'general_schedule_month_view.dart';

const generalViewCustom = 'custom';

class GeneralScheduleHomeScreen extends StatefulWidget {
  const GeneralScheduleHomeScreen({
    super.key,
    this.embedded = false,
    this.active = true,
    this.interactive = true,
    this.showSettingsAction = true,
    this.settingsEnabled = true,
    this.settingsAction,
    this.settingsFocusNode,
    this.scaffoldKey,
  });

  final bool embedded;
  final bool active;
  final bool interactive;
  final bool showSettingsAction;
  final VoidCallback? settingsAction;
  final bool settingsEnabled;
  final FocusNode? settingsFocusNode;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  State<GeneralScheduleHomeScreen> createState() =>
      _GeneralScheduleHomeScreenState();
}

class _GeneralScheduleHomeScreenState extends State<GeneralScheduleHomeScreen> {
  final _pane = WorkspacePaneController();
  var _calendarViewport = _CalendarViewportSession();
  SkedDateRangeController? _rangeController;
  GeneralDateRange? _rememberedCustomRange;
  Object? _rangeDataSession;
  DateTime? _rangeResumeBoundary;
  bool _navigationBusy = false;
  bool get _dateNavigationBusy =>
      _navigationBusy || (_rangeController?.saving ?? false);

  bool _lastRangeSaving = false;
  void _rangeSessionChanged() {
    // Hover and drag previews rebuild the picker, not the event canvas.
    final saving = _rangeController?.saving ?? false;
    if (mounted && saving != _lastRangeSaving) {
      setState(() => _lastRangeSaving = saving);
    }
  }

  void _observeRangeSession(TimetableProvider provider) {
    final boundary =
        provider.appData.workspaceReminderNotBefore[AppMode.general];
    if (!identical(_rangeDataSession, provider.dataSessionToken) ||
        boundary != _rangeResumeBoundary) {
      _rangeController?.dispose();
      _rangeController = null;
      _lastRangeSaving = false;
      _calendarViewport = _CalendarViewportSession();
      _rememberedCustomRange = null;
      _rangeDataSession = provider.dataSessionToken;
      _rangeResumeBoundary = boundary;
    }
    _rememberedCustomRange =
        provider.customGeneralDateRange ?? _rememberedCustomRange;
  }

  @override
  void dispose() {
    _rangeController?.dispose();
    _pane.dispose();
    super.dispose();
  }

  String? _view;
  bool _initializedView = false;
  bool _datePickerOpen = false;
  DateTime? _resourceBrowsedMonth;
  DateTime? _resourceSelectedDate;
  int _resourceNavigationRevision = 0;
  bool _editorSheetOpen = false;
  bool _detailsSheetOpen = false;
  bool _moreOccurrencesSheetOpen = false;
  bool _calendarManagerOpen = false;
  bool _settingsPageOpen = false;
  bool _allDayCollapseUpdateInProgress = false;
  DateTime? _dateNavigationTarget;
  int _dateNavigationGeneration = 0;
  int _dateNavigationDirection = 0;
  bool _pagerDateCommitInProgress = false;
  int _pagerSyncRevision = 0;
  // The hidden view menu is opened from the More button. Keep a stable anchor
  // so its follow-up menu remains attached to that button after the first
  // popup route closes.
  final GlobalKey _toolbarMoreButtonKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedView) {
      _view = context.read<TimetableProvider>().generalDefaultView;
      _initializedView = true;
      _resumeCustomFocus();
    }
  }

  @override
  void didUpdateWidget(GeneralScheduleHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _resumeCustomFocus();
  }

  void _resumeCustomFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.active ||
          !widget.interactive ||
          _dateNavigationBusy ||
          _datePickerOpen) {
        return;
      }
      final provider = context.read<TimetableProvider>();
      final range = provider.customGeneralDateRange;
      if ((_view ?? provider.generalDefaultView) == generalViewWeek &&
          range != null &&
          !range.contains(provider.selectedGeneralDate)) {
        unawaited(_changeView(provider, generalViewCustom));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = context.select<TimetableProvider, _GeneralHomeSnapshot>(
      _GeneralHomeSnapshot.from,
    );
    final provider = context.read<TimetableProvider>();
    _observeRangeSession(provider);
    final selectedDate = snapshot.selectedDate;
    final baseView = normalizeGeneralView(_view ?? snapshot.defaultView);
    final view = baseView == generalViewWeek && snapshot.customDateRange != null
        ? generalViewCustom
        : baseView;
    final dateNavigationDirection =
        _dateNavigationTarget != null &&
            _calendarDateKey(_dateNavigationTarget!) ==
                _calendarDateKey(selectedDate)
        ? _dateNavigationDirection
        : 0;
    const filter = _GeneralOccurrenceFilter(query: '', colorValue: null);

    final visibleSchedules = snapshot.schedules
        .where((schedule) => schedule.isVisible)
        .toList(growable: false);
    final categoryLabel = switch (visibleSchedules.length) {
      0 => l10n.noVisibleCategories,
      1 => visibleSchedules.single.name,
      _ => l10n.visibleCategoryCount(visibleSchedules.length),
    };
    final settingsAction = !widget.settingsEnabled || !widget.interactive
        ? null
        : widget.settingsAction ??
              (_settingsPageOpen
                  ? null
                  : () => _openSettingsPage(context, provider));
    final body = SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compactTouch = WorkbenchChromeMetrics.compactTouch(
            context,
            width: width,
          );
          final toolbar = WorkbenchChromeMetrics.of(context).desktop
              ? _desktopToolbar(context, provider, snapshot, view)
              : SkedWorkspaceToolbar(
                  key: const ValueKey('general-workspace-toolbar'),
                  actions: compactTouch
                      ? const []
                      : [
                          _ReminderStrip(
                            provider: provider,
                            filter: filter,
                            active: widget.active,
                            pane: _pane,
                            onOccurrenceTap: (item) =>
                                _openDetails(context, provider, item),
                          ),
                          if (needsWorkspaceMenu(context))
                            const WorkspaceModeMenu(),
                          if (view != generalViewList)
                            IconButton(
                              key: const ValueKey('general-day-agenda-toggle'),
                              tooltip: l10n.selectedDayAgenda,
                              onPressed: widget.interactive
                                  ? () => _pane.show<void>(
                                      _buildSelectedDayAgenda,
                                    )
                                  : null,
                              icon: const Icon(Icons.view_agenda_outlined),
                            ),
                          const AssistantPaneToggle(),
                          if (width >= 600 &&
                              snapshot.showAddEventFab &&
                              widget.active &&
                              widget.interactive &&
                              !_editorSheetOpen)
                            Tooltip(
                              message: l10n.addEvent,
                              child: width >= 1000
                                  ? FilledButton.icon(
                                      onPressed: () =>
                                          _openEditor(context, provider),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.addEvent),
                                    )
                                  : IconButton.filled(
                                      onPressed: () =>
                                          _openEditor(context, provider),
                                      icon: const Icon(Icons.add),
                                    ),
                            ),
                        ],
                  padding: EdgeInsets.symmetric(
                    horizontal: compactTouch || constraints.maxWidth < 360
                        ? 8
                        : 12,
                    vertical: compactTouch
                        ? 0
                        : (constraints.maxHeight < 600 ? 6 : 8),
                  ),
                  title: _GeneralToolbarLayout(
                    categoryLabel: categoryLabel,
                    toolbarWidthPolicy: snapshot.toolbarWidthPolicy,
                    dateLabelFormat: snapshot.dateLabelFormat,
                    showSettingsAction:
                        widget.showSettingsAction &&
                        WorkspaceCanvasScope.maybeOf(context)?.resources !=
                            true,
                    settingsFocusNode: widget.settingsFocusNode,
                    settingsAction: settingsAction,
                    settingsLabel: l10n.settings,
                    calendarDisabled:
                        _calendarManagerOpen || !widget.interactive,
                    onOpenCalendar: () =>
                        _openCalendarManager(context, provider),
                    view: view,
                    navigationOrder: snapshot.toolbarNavigationOrder,
                    hiddenNavigationIds: snapshot.hiddenToolbarNavigationIds,
                    hiddenItemsBehavior: snapshot.toolbarHiddenItemsBehavior,
                    moreButtonKey: _toolbarMoreButtonKey,
                    compactMoreButton: compactTouch
                        ? _compactMoreButton(
                            context,
                            provider,
                            snapshot,
                            filter,
                            view,
                          )
                        : null,
                    selectedDate: selectedDate,
                    dateNavigationDirection: dateNavigationDirection,
                    interactive: widget.interactive && !_dateNavigationBusy,
                    viewSwitchBehavior: snapshot.viewSwitchBehavior,
                    onViewChanged: (nextView) =>
                        unawaited(_changeView(provider, nextView)),
                    onStep: (direction) =>
                        unawaited(_stepDate(provider, direction)),
                    onToday: () => unawaited(_goToToday(provider)),
                    onPickDate: _datePickerOpen
                        ? null
                        : () => unawaited(_pickDate(context, provider)),
                  ),
                );
          final selectDate = widget.interactive
              ? (DateTime date) => _selectDate(provider, date)
              : (DateTime _) async {};
          final pagerActive =
              !_dateNavigationBusy &&
              widget.active &&
              widget.interactive &&
              !_pagerDateCommitInProgress;
          final longPressAddEnabled =
              (snapshot.enableLongPressAddEvent ||
                  WorkbenchLayoutPolicy.pointerLayout(context)) &&
              pagerActive &&
              !_editorSheetOpen &&
              !_detailsSheetOpen &&
              !_moreOccurrencesSheetOpen;
          final settleDate = pagerActive
              ? (DateTime date) => _commitSettledPagerDate(provider, date)
              : (DateTime _) async {};
          final content = Column(
            children: [
              toolbar,
              Expanded(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                    },
                  ),
                  child: SkedDirectionalTransition(
                    // Pager gestures own their spatial motion and commit with
                    // direction zero. Toolbar navigation keeps this transition.
                    trigger: _calendarDateKey(selectedDate),
                    direction: dateNavigationDirection,
                    fade: false,
                    scale: false,
                    child: ExpressiveSwitcher(
                      child: KeyedSubtree(
                        key: ValueKey(baseView),
                        child: switch (view) {
                          generalViewDay => _DayCalendarView(
                            date: selectedDate,
                            provider: provider,
                            filter: filter,
                            active: pagerActive,
                            syncRevision: _pagerSyncRevision,
                            onDaySelected: selectDate,
                            onPageSettled: settleDate,
                            onEmptySlotTap: longPressAddEnabled
                                ? (date) => _openEditor(
                                    context,
                                    provider,
                                    initialDate: date,
                                  )
                                : null,
                            onOccurrenceTap: (occurrence) =>
                                _openDetails(context, provider, occurrence),
                            onMoreOccurrencesTap: (occurrences) =>
                                _openMoreOccurrences(
                                  context,
                                  provider,
                                  occurrences,
                                ),
                            onAllDayCollapsedGroupTap: (occurrences, day) =>
                                _openMoreOccurrences(
                                  context,
                                  provider,
                                  occurrences,
                                  contextDate: day,
                                ),
                            allDayTimelineCollapsed:
                                snapshot.allDayTimelineCollapsed,
                            onAllDayTimelineCollapsedChanged: (collapsed) =>
                                unawaited(
                                  _setAllDayTimelineCollapsed(
                                    provider,
                                    collapsed,
                                  ),
                                ),
                          ),
                          generalViewList => _ListCalendarView(
                            date: selectedDate,
                            provider: provider,
                            filter: filter,
                            onOccurrenceTap: (occurrence) =>
                                _openDetails(context, provider, occurrence),
                          ),
                          generalViewMonth => _MonthCalendarView(
                            date: selectedDate,
                            provider: provider,
                            filter: filter,
                            active: pagerActive,
                            onDaySelected: selectDate,
                            onEmptySlotTap: (date) => _openEditor(
                              context,
                              provider,
                              initialDate: date,
                            ),
                            onOccurrenceTap: (occurrence) =>
                                _openDetails(context, provider, occurrence),
                          ),
                          _ => _WeekCalendarView(
                            viewport: _calendarViewport,
                            customRange: snapshot.customDateRange,
                            onRangePageSettled: (range) =>
                                unawaited(_moveRange(provider, range)),
                            date: selectedDate,
                            provider: provider,
                            filter: filter,
                            active: pagerActive,
                            syncRevision: _pagerSyncRevision,
                            onDaySelected: selectDate,
                            onPageSettled: settleDate,
                            onEmptySlotTap: longPressAddEnabled
                                ? (date) => _openEditor(
                                    context,
                                    provider,
                                    initialDate: date,
                                  )
                                : null,
                            onOccurrenceTap: (occurrence) =>
                                _openDetails(context, provider, occurrence),
                            onMoreOccurrencesTap: (occurrences) =>
                                _openMoreOccurrences(
                                  context,
                                  provider,
                                  occurrences,
                                ),
                            onAllDayCollapsedGroupTap: (occurrences, day) =>
                                _openMoreOccurrences(
                                  context,
                                  provider,
                                  occurrences,
                                  contextDate: day,
                                ),
                            allDayTimelineCollapsed:
                                snapshot.allDayTimelineCollapsed,
                            onAllDayTimelineCollapsedChanged: (collapsed) =>
                                unawaited(
                                  _setAllDayTimelineCollapsed(
                                    provider,
                                    collapsed,
                                  ),
                                ),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          final showFab =
              width < 600 &&
              snapshot.showAddEventFab &&
              widget.active &&
              widget.interactive &&
              !_editorSheetOpen &&
              MediaQuery.viewInsetsOf(context).bottom == 0;
          return Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (showFab)
                PositionedDirectional(
                  end: 12,
                  bottom: 16,
                  child: SkedPrimaryFab(
                    heroTag: 'general-add-event',
                    tooltip: l10n.addEvent,
                    onPressed: () => _openEditor(context, provider),
                    icon: const Icon(Icons.add),
                    label: width >= 760 ? Text(l10n.addEvent) : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
    return _wrapStandalone(body);
  }

  GeneralDateRange _effectiveRange(TimetableProvider provider) {
    if (provider.customGeneralDateRange case final range?) return range;
    var first = startOfWeekMonday(provider.selectedGeneralDate);
    if (first.isBefore(GeneralDateRange.firstDate)) {
      first = GeneralDateRange.firstDate;
    }
    final last = addCalendarDays(first, 6);
    return GeneralDateRange(
      first,
      last.isAfter(GeneralDateRange.lastDate)
          ? GeneralDateRange.lastDate
          : last,
    );
  }

  SkedDateRangeController _rangeSession(TimetableProvider provider) {
    _observeRangeSession(provider);
    final range = _effectiveRange(provider);
    final dataSession = provider.dataSessionToken;
    final ownerRoute = ModalRoute.of(context);
    final resumeBoundary =
        provider.appData.workspaceReminderNotBefore[AppMode.general];
    bool isCurrent() =>
        mounted &&
        (ownerRoute?.isActive ?? true) &&
        provider.isWorkspaceEnabled(AppMode.general) &&
        identical(dataSession, provider.dataSessionToken) &&
        resumeBoundary ==
            provider.appData.workspaceReminderNotBefore[AppMode.general];
    final session = _rangeController ??= (SkedDateRangeController(
      initialRange: range,
      isSessionCurrent: isCurrent,
      onApply: (next) async {
        if (!mounted) throw StateError('Date range owner is gone.');
        await provider.setGeneralDateRange(next, isCurrent: isCurrent);
        if (isCurrent()) {
          setState(() {
            _view = generalViewWeek;
            _resourceBrowsedMonth = provider.selectedGeneralDate;
            _resourceNavigationRevision++;
            _pagerSyncRevision++;
          });
        }
      },
    )..addListener(_rangeSessionChanged));
    session.sync(range);
    return session;
  }

  bool _canStepRange(TimetableProvider provider, int direction) {
    final range = provider.customGeneralDateRange;
    return (_view ?? provider.generalDefaultView) != generalViewWeek ||
        range == null ||
        range.shifted(range.dayCount * direction) != null;
  }

  Future<void> _moveRange(
    TimetableProvider provider,
    GeneralDateRange range,
  ) async {
    if (_dateNavigationBusy) return;
    final old = provider.customGeneralDateRange;
    if (old == null) return;
    final offset = calendarDaysBetween(
      old.start,
      provider.selectedGeneralDate,
    ).clamp(0, old.dayCount - 1);
    setState(() => _navigationBusy = true);
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Move date range',
        command: () => provider.setGeneralDateRange(
          range,
          focusedDate: addCalendarDays(range.start, offset),
          revealFocus: false,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _navigationBusy = false;
          _pagerSyncRevision++;
        });
      }
    }
  }

  Future<void> _changeView(
    TimetableProvider provider,
    String view, {
    BuildContext? anchorContext,
  }) async {
    if (_dateNavigationBusy) return;
    final savedRange =
        provider.customGeneralDateRange ?? _rememberedCustomRange;
    if (view == generalViewCustom && savedRange == null) {
      await _pickDate(
        context,
        provider,
        forceRange: true,
        anchorContext: anchorContext,
      );
      return;
    }
    final needsSave =
        (view == generalViewWeek && provider.customGeneralDateRange != null) ||
        (view == generalViewCustom &&
            (provider.customGeneralDateRange == null ||
                !savedRange!.contains(provider.selectedGeneralDate)));
    if (needsSave) {
      setState(() => _navigationBusy = true);
      try {
        final saved = await runUiCommandWithFeedback(
          context: context,
          debugLabel: 'Change calendar view',
          command: () => view == generalViewWeek
              ? provider.clearGeneralDateRange()
              : provider.setGeneralDateRange(
                  savedRange!.containing(provider.selectedGeneralDate),
                  focusedDate: provider.selectedGeneralDate,
                ),
        );
        if (!saved || !mounted) return;
      } finally {
        if (mounted) setState(() => _navigationBusy = false);
      }
    }
    if (!mounted) return;
    _rangeController?.cancel();
    setState(() {
      _view = view == generalViewCustom ? generalViewWeek : view;
      _dateNavigationTarget = null;
      _dateNavigationDirection = 0;
    });
  }

  Future<void> _jumpCalendarMonth(
    TimetableProvider provider,
    int offset,
  ) async {
    final current = _dateNavigationTarget ?? provider.selectedGeneralDate;
    final month = DateTime(current.year, current.month + offset);
    final days = DateTime(month.year, month.month + 1, 0).day;
    await _selectDate(
      provider,
      DateTime(month.year, month.month, current.day.clamp(1, days)),
    );
  }

  Future<void> _stepDate(TimetableProvider provider, int direction) async {
    if (_dateNavigationBusy) return;
    final range = provider.customGeneralDateRange;
    if ((_view ?? provider.generalDefaultView) == generalViewWeek &&
        range != null) {
      final next = range.shifted(direction * range.dayCount);
      if (next != null) await _moveRange(provider, next);
      return;
    }
    final view = _view ?? provider.generalDefaultView;
    if (view == generalViewMonth) {
      return _jumpCalendarMonth(provider, direction);
    }
    final current = _dateNavigationTarget ?? provider.selectedGeneralDate;
    await _selectDate(
      provider,
      addCalendarDays(current, direction * (view == generalViewWeek ? 7 : 1)),
    );
  }

  Future<void> _goToToday(TimetableProvider provider) async {
    if (_dateNavigationBusy) return;
    final date = _visibleGeneralDate(provider, DateTime.now());
    setState(() {
      _resourceBrowsedMonth = date;
      _resourceNavigationRevision++;
    });
    await _selectDate(provider, date);
  }

  Future<void> _selectDate(
    TimetableProvider provider,
    DateTime requestedDate,
  ) async {
    if (_dateNavigationBusy) return;
    final current = normalizeDateOnly(
      _dateNavigationTarget ?? provider.selectedGeneralDate,
    );
    final requested = normalizeDateOnly(requestedDate);
    final requestedDirection = requested.compareTo(current).sign;
    final next = _visibleGeneralDate(
      provider,
      requested,
      direction: requestedDirection < 0 ? -1 : 1,
    );
    final direction = next.compareTo(current).sign;
    if (direction == 0) {
      if (provider.customGeneralDateRange != null &&
          (_view ?? provider.generalDefaultView) == generalViewWeek) {
        await runUiCommandWithFeedback(
          context: context,
          debugLabel: 'Reveal calendar date',
          command: () => provider.setSelectedGeneralDate(next),
        );
      }
      if (mounted) {
        setState(() {
          _resourceBrowsedMonth = next;
          _resourceNavigationRevision++;
        });
      }
      return;
    }
    if (_detailsSheetOpen && !_editorSheetOpen) {
      await _pane.close();
      if (!mounted) return;
    }

    final navigationGeneration = ++_dateNavigationGeneration;
    if (mounted) {
      setState(() {
        _dateNavigationTarget = next;
        _dateNavigationDirection = direction;
      });
    } else {
      _dateNavigationTarget = next;
      _dateNavigationDirection = direction;
    }
    try {
      if (provider.customGeneralDateRange != null) {
        setState(() => _navigationBusy = true);
        await runUiCommandWithFeedback(
          context: context,
          debugLabel: 'Navigate calendar date',
          command: () => provider.setSelectedGeneralDate(
            next,
            moveCustomRange:
                (_view ?? provider.generalDefaultView) == generalViewWeek,
          ),
        );
      } else {
        await provider.setSelectedGeneralDate(next);
      }
    } finally {
      if (mounted && _navigationBusy) setState(() => _navigationBusy = false);
      if (navigationGeneration == _dateNavigationGeneration) {
        if (!mounted) {
          _dateNavigationTarget = null;
          _dateNavigationDirection = 0;
        } else {
          // `setSelectedGeneralDate` publishes its snapshot synchronously.
          // Keep the direction through the first frame so the transition
          // observes the new date before the pending intent is cleared.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || navigationGeneration != _dateNavigationGeneration) {
              return;
            }
            setState(() {
              _dateNavigationTarget = null;
              _dateNavigationDirection = 0;
            });
          });
        }
      }
    }
  }

  Future<void> _commitSettledPagerDate(
    TimetableProvider provider,
    DateTime requestedDate,
  ) async {
    if (_pagerDateCommitInProgress || !mounted) return;
    final next = _visibleGeneralDate(provider, requestedDate);
    if (_sameDay(next, provider.selectedGeneralDate)) return;
    setState(() => _pagerDateCommitInProgress = true);
    var needsPagerResync = false;
    try {
      final saved = await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Persist general schedule pager date',
        command: () async {
          await provider.setSelectedGeneralDate(
            next,
            moveCustomRange:
                (_view ?? provider.generalDefaultView) == generalViewWeek,
          );
          await provider.flushPendingUiStateSaves();
        },
      );
      needsPagerResync = !saved;
    } finally {
      if (mounted) {
        setState(() {
          _pagerDateCommitInProgress = false;
          if (needsPagerResync) _pagerSyncRevision += 1;
        });
      }
    }
  }

  Future<void> _setAllDayTimelineCollapsed(
    TimetableProvider provider,
    bool collapsed,
  ) async {
    if (_allDayCollapseUpdateInProgress ||
        !widget.interactive ||
        provider.allDayTimelineCollapsed == collapsed) {
      return;
    }
    _setUiBusyFlag(() => _allDayCollapseUpdateInProgress = true);
    try {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Persist all-day timeline collapsed state',
        command: () => provider.updateGeneralDisplaySettings(
          allDayTimelineCollapsed: collapsed,
        ),
      );
    } finally {
      _setUiBusyFlag(() => _allDayCollapseUpdateInProgress = false);
    }
  }

  DateTime _visibleGeneralDate(
    TimetableProvider provider,
    DateTime date, {
    int direction = 1,
  }) {
    final normalized = normalizeDateOnly(date);
    if (((_view ?? provider.generalDefaultView) == generalViewWeek &&
            provider.customGeneralDateRange != null) ||
        provider.generalShowWeekends ||
        normalized.weekday <= DateTime.friday) {
      return normalized;
    }
    final unit = _dateUnitForView(_view ?? provider.generalDefaultView);
    if (unit != DateSelectionUnit.day) {
      final range = dateSelectionRange(normalized, unit);
      return selectableDateInUnit(
        preferred: normalized,
        unit: unit,
        firstDate: range.start,
        lastDate: range.end,
        selectableDayPredicate: (day) => day.weekday <= DateTime.friday,
      )!;
    }
    return addCalendarDays(
      normalized,
      direction < 0
          ? DateTime.friday - normalized.weekday
          : 8 - normalized.weekday,
    );
  }

  Widget _wrapStandalone(Widget workspace) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    final date = normalizeDateOnly(provider.selectedGeneralDate);
    if (!DateUtils.isSameDay(date, _resourceSelectedDate)) {
      _resourceSelectedDate = date;
      _resourceBrowsedMonth = date;
    }

    final selectedView = _view ?? provider.generalDefaultView;
    final customRange = selectedView == generalViewWeek
        ? provider.customGeneralDateRange
        : null;
    final rangeStart = selectedView == generalViewWeek
        ? customRange?.start ?? startOfWeekMonday(date)
        : selectedView == generalViewMonth
        ? DateTime(date.year, date.month)
        : date;
    final rangeEnd = selectedView == generalViewWeek
        ? customRange?.end ?? addCalendarDays(rangeStart, 6)
        : selectedView == generalViewMonth
        ? DateTime(date.year, date.month + 1, 0)
        : date;
    final framed = WorkspaceFrame(
      controller: _pane,
      minimumCanvas: (_view ?? provider.generalDefaultView) == generalViewWeek
          ? math
                .min(800, math.max(600, 64 + (customRange?.dayCount ?? 7) * 96))
                .toDouble()
          : 600,
      contextSnapshot: WorkspaceContextSnapshot(
        enabledWorkspaces: provider.enabledWorkspaces,
        mode: AppMode.general,
        view: customRange != null ? generalViewCustom : selectedView,
        resourceId: provider.activeGeneralScheduleOrNull?.id,
        date: rangeStart,
        endDate: rangeEnd,
        selectionId: _pane.selectedId,
      ),
      active: widget.active,
      resourcesCollapsed: provider.homeWorkspaceNavigationCollapsed,
      canvas: workspace,
      resources: WorkspaceResourcePanel(
        title: l10n.calendars,
        onOpenResources: () => _openCalendarManager(context, provider),
        settingsFocusNode: widget.settingsFocusNode,
        onSettings: widget.showSettingsAction && widget.settingsEnabled
            ? widget.settingsAction ??
                  () => _openSettingsPage(context, provider)
            : null,

        headerActions: [
          IconButton(
            key: const ValueKey('general-resource-add'),
            tooltip: l10n.newCalendar,
            onPressed: widget.interactive
                ? () => _openCalendarManager(context, provider, create: true)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
        children: [
          if (WorkbenchChromeMetrics.of(context).desktop)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SkedDatePicker(
                key: const ValueKey('general-resource-date-picker'),
                embedded: true,
                rangeController: _rangeSession(provider),
                rangeInteraction: widget.interactive
                    ? DateRangeInteraction.dragOnly
                    : DateRangeInteraction.none,
                displayRange: selectedView == generalViewWeek
                    ? customRange
                    : null,
                initialDate: date,
                firstDate: DateTime(1970),
                lastDate: DateTime(2100),
                browsedMonth: _resourceBrowsedMonth,
                onBrowsedMonthChanged: (month) => _resourceBrowsedMonth = month,
                navigationRevision: _resourceNavigationRevision,
                selectionUnit: selectedView == generalViewWeek
                    ? DateSelectionUnit.week
                    : DateSelectionUnit.day,
                commitMode: DatePickerCommitMode.immediate,
                selectableDayPredicate: (day) =>
                    widget.interactive &&
                    (selectedView == generalViewWeek ||
                        provider.generalShowWeekends ||
                        day.weekday <= DateTime.friday),
                onSelected: (day) => unawaited(_selectDate(provider, day)),
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(
                formatDateSelection(
                  date,
                  _dateUnitForView(selectedView),
                  customRange: customRange,
                  locale: l10n.localeName,
                  format: provider.generalDateLabelFormat,
                ),
              ),
              onTap: () => _pickDate(context, provider),
            ),
          for (final calendar in provider.generalSchedules)
            CalendarResourceRow(
              key: ValueKey('resource-calendar-${calendar.id}'),
              name: calendar.name,
              color: effectiveGeneralCalendarColor(context, calendar),
              visible: calendar.isVisible,
              onChanged: widget.interactive
                  ? () => unawaited(
                      runUiCommandWithFeedback(
                        context: context,
                        debugLabel: 'Toggle calendar visibility',
                        command: () => provider.updateGeneralScheduleVisibility(
                          calendar.id,
                          !calendar.isVisible,
                        ),
                      ),
                    )
                  : null,
            ),
        ],
      ),
      supporting: (_view ?? provider.generalDefaultView) == generalViewMonth
          ? Builder(builder: _buildSelectedDayAgenda)
          : null,
    );
    if (widget.embedded) return framed;
    return Scaffold(key: widget.scaffoldKey, body: framed);
  }

  Widget _compactMoreButton(
    BuildContext context,
    TimetableProvider provider,
    _GeneralHomeSnapshot snapshot,
    _GeneralOccurrenceFilter filter,
    String view,
  ) {
    final l = AppLocalizations.of(context);
    final navigation = WorkspaceNavigationScope.maybeOf(context);
    final showWorkspaceMenu = needsWorkspaceMenu(context);
    final assistant = AssistantPaneScope.of(context);
    final hidden = snapshot.hiddenToolbarNavigationIds;
    // The adaptive menu is not the user-configurable hidden-shortcut menu.
    // Always retain secondary tasks, but only restore hidden shortcuts when
    // the user chose More and did not explicitly hide that overflow entry.
    final revealHidden =
        snapshot.toolbarHiddenItemsBehavior == toolbarHiddenItemsBehaviorMore &&
        !hidden.contains('more');
    final canNavigate = widget.interactive && !_dateNavigationBusy;
    return _ReminderStrip(
      provider: provider,
      filter: filter,
      active: widget.active && widget.interactive,
      pane: _pane,
      onOccurrenceTap: (item) => _openDetails(context, provider, item),
      actionBuilder: (context, count, openReminders) => KeyedSubtree(
        key: const ValueKey('general-toolbar-more-button'),
        child: SkedPopupMenuButton<String>(
          key: _toolbarMoreButtonKey,
          tooltip: l.more,
          enabled: widget.interactive,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count', semanticsLabel: '${l.reminder}: $count'),
            child: const Icon(Icons.more_horiz),
          ),
          onSelected: (id) {
            if (!mounted || !widget.interactive) return;
            switch (id) {
              case 'reminders':
                openReminders?.call();
              case 'agenda':
                unawaited(_pane.show<void>(_buildSelectedDayAgenda));
              case 'category':
                unawaited(_openCalendarManager(context, provider));
              case 'today':
                unawaited(_goToToday(provider));
              case 'date':
                unawaited(
                  _pickDate(
                    context,
                    provider,
                    anchorContext: _toolbarMoreButtonKey.currentContext,
                  ),
                );
              case 'view':
                if (snapshot.viewSwitchBehavior ==
                    generalViewSwitchBehaviorMenu) {
                  unawaited(
                    _showGeneralViewSelectionMenu(
                      context: context,
                      anchorContext:
                          _toolbarMoreButtonKey.currentContext ?? context,
                      view: view,
                      interactive: canNavigate,
                      onViewChanged: (value) =>
                          unawaited(_changeView(provider, value)),
                    ),
                  );
                } else {
                  unawaited(
                    _changeView(
                      provider,
                      _nextGeneralView(
                        view,
                        hasCustomRange: provider.customGeneralDateRange != null,
                      ),
                    ),
                  );
                }
              case 'assistant':
                if (assistant?.enabled == true && assistant!.interactive) {
                  (assistant.onToggle ?? assistant.controller.toggle)();
                }
              case 'student':
                selectWorkspace(context, AppMode.student);
              case 'general':
                selectWorkspace(context, AppMode.general);
            }
          },
          itemBuilder: (_) => [
            SkedPopupMenuItem<String>(
              key: const ValueKey('general-reminders-action'),
              value: 'reminders',
              enabled: openReminders != null,
              child: Text(count == 0 ? l.reminder : '${l.reminder} · $count'),
            ),
            if (view != generalViewList)
              SkedPopupMenuItem<String>(
                key: const ValueKey('general-day-agenda-toggle'),
                value: 'agenda',
                child: Text(l.selectedDayAgenda),
              ),
            if (!hidden.contains('date') || revealHidden)
              SkedPopupMenuItem<String>(
                value: 'today',
                enabled: canNavigate,
                child: Text(l.today),
              ),
            for (final id in snapshot.toolbarNavigationOrder)
              if (revealHidden &&
                  hidden.contains(id) &&
                  (id == 'date' || id == 'view'))
                SkedPopupMenuItem<String>(
                  value: id,
                  enabled: canNavigate && (id != 'date' || !_datePickerOpen),
                  child: Text(
                    id == 'date' ? l.pickDate : l.toolbarNavigationView,
                  ),
                ),
            const SkedPopupMenuDivider<String>(),
            SkedPopupMenuItem<String>(
              key: const ValueKey('general-calendar-manager-action'),
              value: 'category',
              enabled: !_calendarManagerOpen,
              child: Text(l.calendars),
            ),
            if (showWorkspaceMenu)
              for (final mode in provider.enabledWorkspaces)
                CheckedPopupMenuItem<String>(
                  key: ValueKey('general-more-workspace-${mode.value}'),
                  value: mode.value,
                  checked: provider.activeMode == mode,
                  enabled: navigation?.enabled ?? true,
                  child: Text(
                    mode == AppMode.student
                        ? l.studentTimetable
                        : l.generalSchedule,
                  ),
                ),
            if (assistant?.enabled == true)
              SkedPopupMenuItem<String>(
                key: const ValueKey('assistant-toggle'),
                value: 'assistant',
                enabled: assistant!.interactive,
                child: Text(l.assistantLayoutPreview),
              ),
          ],
        ),
      ),
    );
  }

  Widget _desktopCompactToolbar(
    BuildContext context,
    TimetableProvider provider,
    _GeneralHomeSnapshot snapshot,
    String view,
    String label,
  ) {
    final l = AppLocalizations.of(context);
    final resources = WorkspaceCanvasScope.maybeOf(context)?.resources == true;
    final assistant = AssistantPaneScope.of(context);
    final canNavigate = widget.interactive && !_dateNavigationBusy;
    return _ReminderStrip(
      provider: provider,
      filter: const _GeneralOccurrenceFilter(query: '', colorValue: null),
      active: widget.active && widget.interactive,
      pane: _pane,
      onOccurrenceTap: (item) => _openDetails(context, provider, item),
      actionBuilder: (context, count, openReminders) => WorkbenchCompactCalendarBar(
        id: 'general',
        enabled: widget.interactive,
        moreFocusNode: widget.showSettingsAction && !resources
            ? widget.settingsFocusNode
            : null,
        badgeCount: count,
        date: WorkbenchOverflowAction(
          id: 'general-date-picker',
          label: label,
          tooltip:
              '${_datePickerTitle(l, _dateUnitForView(view))}: ${_accessibleDateNavigationLabel(snapshot.selectedDate, view, context)}',
          icon: _generalViewIcon(view),
          onSelected: canNavigate && !_datePickerOpen
              ? (anchor) => unawaited(
                  _pickDate(context, provider, anchorContext: anchor),
                )
              : null,
        ),
        shortDateLabel: formatDateSelection(
          snapshot.selectedDate,
          _dateUnitForView(view),
          locale: l.localeName,
          format: snapshot.dateLabelFormat,
          compact: true,
          customRange: view == generalViewCustom
              ? snapshot.customDateRange
              : null,
        ),
        previous: WorkbenchOverflowAction(
          id: 'general-previous-period',
          label: MaterialLocalizations.of(context).previousPageTooltip,
          icon: Icons.chevron_left,
          onSelected: canNavigate && _canStepRange(provider, -1)
              ? (_) => unawaited(_stepDate(provider, -1))
              : null,
        ),
        next: WorkbenchOverflowAction(
          id: 'general-next-period',
          label: MaterialLocalizations.of(context).nextPageTooltip,
          icon: Icons.chevron_right,
          onSelected: canNavigate && _canStepRange(provider, 1)
              ? (_) => unawaited(_stepDate(provider, 1))
              : null,
        ),
        today: WorkbenchOverflowAction(
          id: 'general-today',
          label: l.today,
          icon: Icons.today,
          onSelected: canNavigate
              ? (_) => unawaited(_goToToday(provider))
              : null,
        ),
        actions: [
          WorkbenchOverflowAction(
            id: 'general-add-event',
            label: l.addEvent,
            icon: Icons.add,
            dividerBefore: true,
            onSelected: widget.interactive && !_editorSheetOpen
                ? (_) => unawaited(_openEditor(context, provider))
                : null,
          ),
          if (!resources)
            WorkbenchOverflowAction(
              id: 'general-calendar-selector',
              label: l.calendars,
              icon: Icons.view_sidebar_outlined,
              onSelected: (_) =>
                  unawaited(_openCalendarManager(context, provider)),
            ),
          for (final option in _generalViewOptions(l))
            WorkbenchOverflowAction(
              id: 'general-view-choice-${option.value}',
              label: '${l.generalViewSwitchMenuTooltip} · ${option.label}',
              icon: option.icon,
              selected: option.value == view,
              onSelected: canNavigate
                  ? (anchor) => unawaited(
                      _changeView(
                        provider,
                        option.value,
                        anchorContext: anchor,
                      ),
                    )
                  : null,
            ),
          WorkbenchOverflowAction(
            id: 'general-reminders-action',
            label: count == 0 ? l.reminder : '${l.reminder} · $count',
            icon: Icons.notifications_outlined,
            dividerBefore: true,
            onSelected: openReminders == null ? null : (_) => openReminders(),
          ),
          if (view != generalViewList)
            WorkbenchOverflowAction(
              id: 'general-day-agenda-toggle',
              label: l.selectedDayAgenda,
              icon: Icons.view_agenda_outlined,
              onSelected: (_) =>
                  unawaited(_pane.show<void>(_buildSelectedDayAgenda)),
            ),
          if (assistant?.enabled == true)
            WorkbenchOverflowAction(
              id: 'assistant-toggle',
              label: l.assistantLayoutPreview,
              icon: Icons.chat_bubble_outline,
              onSelected: assistant!.interactive
                  ? (_) => (assistant.onToggle ?? assistant.controller.toggle)()
                  : null,
            ),
          if (widget.showSettingsAction && !resources)
            WorkbenchOverflowAction(
              id: 'general-settings-button',
              label: l.settings,
              icon: Icons.settings_outlined,
              onSelected: widget.settingsEnabled
                  ? (_) =>
                        (widget.settingsAction ??
                        () => _openSettingsPage(context, provider))()
                  : null,
            ),
          if (needsWorkspaceMenu(context))
            for (final mode in provider.enabledWorkspaces)
              WorkbenchOverflowAction(
                id: 'workspace-menu-${mode.value}',
                label: mode == AppMode.student
                    ? l.studentTimetable
                    : l.generalSchedule,
                icon: mode == AppMode.student
                    ? Icons.school_outlined
                    : Icons.event_note_outlined,
                selected: provider.activeMode == mode,
                dividerBefore: mode == provider.enabledWorkspaces.first,
                onSelected: (_) => selectWorkspace(context, mode),
              ),
        ],
      ),
    );
  }

  Widget _desktopToolbar(
    BuildContext context,
    TimetableProvider provider,
    _GeneralHomeSnapshot snapshot,
    String view,
  ) {
    final l = AppLocalizations.of(context);
    final date = snapshot.selectedDate;
    final label = formatDateSelection(
      date,
      _dateUnitForView(view),
      locale: l.localeName,
      format: snapshot.dateLabelFormat,
      customRange: view == generalViewCustom ? snapshot.customDateRange : null,
    );
    final resources = WorkspaceCanvasScope.maybeOf(context)?.resources == true;
    return WorkbenchCommandBar(
      key: const ValueKey('general-workspace-toolbar'),
      compactBuilder: (context) =>
          _desktopCompactToolbar(context, provider, snapshot, view, label),
      navigation: [
        if (needsWorkspaceMenu(context)) const WorkspaceModeMenu(),
        if (!resources)
          IconButton(
            key: const ValueKey('general-calendar-selector'),
            tooltip: l.calendars,
            onPressed: () => _openCalendarManager(context, provider),
            icon: const Icon(Icons.view_sidebar_outlined),
          ),
        IconButton(
          key: const ValueKey('general-previous-period'),
          tooltip: MaterialLocalizations.of(context).previousPageTooltip,
          onPressed:
              widget.interactive &&
                  !_dateNavigationBusy &&
                  _canStepRange(provider, -1)
              ? () => _stepDate(provider, -1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const ValueKey('general-next-period'),
          tooltip: MaterialLocalizations.of(context).nextPageTooltip,
          onPressed:
              widget.interactive &&
                  !_dateNavigationBusy &&
                  _canStepRange(provider, 1)
              ? () => _stepDate(provider, 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(
          key: const ValueKey('general-today'),
          onPressed: widget.interactive && !_dateNavigationBusy
              ? () => _goToToday(provider)
              : null,
          child: Text(l.today),
        ),
        Builder(
          builder: (anchorContext) => Tooltip(
            message:
                '${_datePickerTitle(l, _dateUnitForView(view))}: ${_accessibleDateNavigationLabel(date, view, context)}',
            child: TextButton(
              key: const ValueKey('general-date-picker'),
              onPressed:
                  _datePickerOpen || _dateNavigationBusy || !widget.interactive
                  ? null
                  : () => _pickDate(
                      context,
                      provider,
                      anchorContext: anchorContext,
                    ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      ],
      actions: [
        Builder(
          builder: (viewAnchor) => PopupMenuButton<String>(
            key: const ValueKey('general-view-switcher'),
            tooltip: l.defaultView,
            enabled: widget.interactive && !_dateNavigationBusy,
            onSelected: (value) => unawaited(
              _changeView(provider, value, anchorContext: viewAnchor),
            ),
            itemBuilder: (_) => [
              for (final option in _generalViewOptions(l))
                CheckedPopupMenuItem(
                  value: option.value,
                  checked: option.value == view,
                  child: Text(option.label),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Text(
                    _generalViewLabel(
                      l,
                      view,
                      customDays: provider.customGeneralDateRange?.dayCount,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
        ),
        _ReminderStrip(
          provider: provider,
          filter: const _GeneralOccurrenceFilter(query: '', colorValue: null),
          active: widget.active,
          pane: _pane,
          onOccurrenceTap: (item) => _openDetails(context, provider, item),
        ),
        if (view != generalViewList)
          IconButton(
            key: const ValueKey('general-day-agenda-toggle'),
            tooltip: l.selectedDayAgenda,
            onPressed: () => _pane.show<void>(_buildSelectedDayAgenda),
            icon: const Icon(Icons.view_agenda_outlined),
          ),
        const AssistantPaneToggle(),
        if (widget.showSettingsAction && !resources)
          IconButton(
            key: const ValueKey('general-settings-button'),
            tooltip: l.settings,
            focusNode: widget.settingsFocusNode,
            onPressed:
                widget.settingsAction ??
                () => _openSettingsPage(context, provider),
            icon: const Icon(Icons.settings_outlined),
          ),
        FilledButton.icon(
          key: const ValueKey('general-add-event'),
          onPressed: widget.interactive && !_editorSheetOpen
              ? () => _openEditor(context, provider)
              : null,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l.addEvent),
        ),
      ],
    );
  }

  Widget _buildSelectedDayAgenda(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    final date = normalizeDateOnly(provider.selectedGeneralDate);
    final occurrences = provider.generalOccurrencesForRange(
      startInclusive: date,
      endExclusive: addCalendarDays(date, 1),
    );
    return SkedSurface(
      key: const ValueKey('general-selected-day-agenda'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${l10n.selectedDayAgenda} · ${_formatDate(date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final occurrence in occurrences)
                  _GeneralListOccurrenceTile(
                    occurrence: occurrence,
                    onTap: () => _openDetails(context, provider, occurrence),
                  ),
                if (occurrences.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l10n.noUpcomingEvents),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.addEvent),
              onPressed: () =>
                  _openEditor(context, provider, initialDate: date),
            ),
          ),
        ],
      ),
    );
  }

  void _setUiBusyFlag(void Function() update) {
    if (mounted) {
      setState(update);
    } else {
      update();
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    TimetableProvider provider, {
    BuildContext? anchorContext,
    bool forceRange = false,
  }) async {
    if (_datePickerOpen || _dateNavigationBusy || !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _datePickerOpen = true);
    final firstDate = DateTime(1970);
    final lastDate = DateTime(2100);
    try {
      if (forceRange ||
          ((_view ?? provider.generalDefaultView) == generalViewWeek &&
              provider.customGeneralDateRange != null)) {
        final session = _rangeSession(provider);
        await showSkedDateRangePicker(
          context: context,
          anchorContext: anchorContext,
          initialRange: session.applied,
          controller: session,
          workspace: AppMode.general,
          dateLabelFormat: provider.generalDateLabelFormat,
        );
        return;
      }
      final initialDate = _visibleGeneralDate(
        provider,
        _clampDate(provider.selectedGeneralDate, firstDate, lastDate),
      );
      final touchWeek =
          WorkbenchChromeMetrics.compactTouch(context) &&
          (_view ?? provider.generalDefaultView) == generalViewWeek;
      final picked = await showSkedDatePicker(
        context: context,
        anchorContext: anchorContext,
        workspace: AppMode.general,
        dateLabelFormat: provider.generalDateLabelFormat,
        selectionUnit: _dateUnitForView(_view ?? provider.generalDefaultView),
        commitMode: DatePickerCommitMode.immediate,
        // Taps keep ordinary week navigation; only an intentional drag
        // publishes a custom range, using the same guarded save session.
        rangeController: touchWeek ? _rangeSession(provider) : null,
        rangeInteraction: touchWeek
            ? DateRangeInteraction.dragOnly
            : DateRangeInteraction.none,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        selectableDayPredicate: touchWeek || provider.generalShowWeekends
            ? null
            : (date) => date.weekday <= DateTime.friday,
      );
      if (!mounted ||
          !provider.isWorkspaceEnabled(AppMode.general) ||
          picked == null) {
        return;
      }
      await _selectDate(provider, picked);
    } finally {
      _setUiBusyFlag(() => _datePickerOpen = false);
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    TimetableProvider provider, {
    DateTime? initialDate,
    GeneralEvent? event,
  }) async {
    if (_editorSheetOpen || !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _editorSheetOpen = true);
    final canDismiss = provider.closeGeneralEventPopupOnOutsideTap;
    final calendarId = event?.calendarId.isNotEmpty == true
        ? event!.calendarId
        : provider.activeGeneralSchedule.id;
    try {
      await showAppModalSheet<GeneralEventEditorResult>(
        context: context,
        workspacePane: _pane,
        workspace: AppMode.general,
        isSessionCurrent:
            (WorkbenchChromeMetrics.compactTouch(context) ||
                _pane.hasModalTasks)
            ? () => provider.generalSchedules.any(
                (calendar) =>
                    calendar.id == calendarId &&
                    (event == null ||
                        calendar.events.any((item) => item.id == event.id)),
              )
            : null,
        selectionId: event == null
            ? null
            : _pane.selectedId ?? 'event:${event.id}',
        isDismissible: canDismiss,
        enableDrag: false,
        maxWidth: appSheetWidthMedium,
        builder: (sheetContext) => GeneralEventEditorSheet(
          initialEvent: event,
          initialDate: initialDate ?? provider.selectedGeneralDate,
          calendars: provider.generalSchedules,
          activeCalendarId: calendarId,
          defaultReminderMinutesBefore: event == null
              ? provider.generalDefaultMinutesBefore
              : null,
          onSave: provider.saveGeneralEvent,
          onDelete: event == null
              ? null
              : () => provider.deleteGeneralEvent(event.id),
        ),
      );
    } finally {
      _setUiBusyFlag(() => _editorSheetOpen = false);
    }
  }

  Future<void> _openDetails(
    BuildContext context,
    TimetableProvider provider,
    GeneralEventOccurrence occurrence,
  ) async {
    if (!widget.interactive || _editorSheetOpen) return;
    if (_detailsSheetOpen) {
      if (_pane.selectedId == occurrence.occurrenceKey) return;
      await _pane.close();
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !context.mounted || _detailsSheetOpen) return;
    }
    _setUiBusyFlag(() => _detailsSheetOpen = true);
    final canDismiss = provider.closeGeneralEventPopupOnOutsideTap;
    try {
      await showAppModalSheet<void>(
        context: context,
        workspacePane: _pane,
        workspace: AppMode.general,
        isSessionCurrent:
            (WorkbenchChromeMetrics.compactTouch(context) ||
                _pane.hasModalTasks)
            ? () => provider.generalSchedules.any(
                (calendar) => calendar.events.any(
                  (item) => item.id == occurrence.event.id,
                ),
              )
            : null,
        selectionId: occurrence.occurrenceKey,
        isDismissible: canDismiss,
        enableDrag: false,
        maxWidth: appSheetWidthCompact,
        builder: (sheetContext) => GeneralEventDetailsSheet(
          occurrence: occurrence,
          isReminderHandled: provider.isGeneralReminderHandled(occurrence),
          onEdit: () {
            Navigator.of(sheetContext).pop();
            return _openEditor(context, provider, event: occurrence.event);
          },
          onDismissReminder: () async {
            final messenger = ScaffoldMessenger.of(context);
            final message = AppLocalizations.of(context).reminderHandled;
            await provider.dismissGeneralReminder(occurrence);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text(message)));
            }
          },
          onRestoreReminder: () async {
            final messenger = ScaffoldMessenger.of(context);
            final message = AppLocalizations.of(context).reminderRestored;
            await provider.restoreGeneralReminder(occurrence);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text(message)));
            }
          },
          onDuplicate: () async {
            final messenger = ScaffoldMessenger.of(context);
            final message = AppLocalizations.of(context).eventDuplicated;
            await provider.duplicateGeneralOccurrence(occurrence);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            if (mounted) {
              messenger.showSnackBar(SnackBar(content: Text(message)));
            }
          },
          onDeleteThis: () async {
            await provider.deleteGeneralOccurrence(occurrence);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          onDeleteFuture: occurrence.event.recurrenceRule.isRepeating
              ? () async {
                  await provider.deleteFutureGeneralOccurrences(occurrence);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                }
              : null,
          onDeleteAll: () async {
            await provider.deleteGeneralEvent(occurrence.event.id);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
        ),
      );
    } finally {
      _setUiBusyFlag(() => _detailsSheetOpen = false);
    }
  }

  Future<void> _openMoreOccurrences(
    BuildContext context,
    TimetableProvider provider,
    List<GeneralEventOccurrence> occurrences, {
    DateTime? contextDate,
  }) async {
    if (_moreOccurrencesSheetOpen ||
        _editorSheetOpen ||
        occurrences.isEmpty ||
        !widget.interactive) {
      return;
    }
    if (_detailsSheetOpen) {
      await _pane.close();
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !context.mounted || _detailsSheetOpen) return;
    }
    _setUiBusyFlag(() => _moreOccurrencesSheetOpen = true);
    final canDismiss = provider.closeGeneralEventPopupOnOutsideTap;
    try {
      await showAppModalSheet<void>(
        context: context,
        workspacePane: _pane,
        workspace: AppMode.general,
        isDismissible: canDismiss,
        enableDrag: canDismiss,
        maxWidth: appSheetWidthCompact,
        builder: (sheetContext) => _MoreGeneralOccurrencesSheet(
          occurrences: occurrences,
          contextDate: contextDate,
          onOccurrenceTap: (occurrence) =>
              unawaited(_openDetails(context, provider, occurrence)),
        ),
      );
    } finally {
      _setUiBusyFlag(() => _moreOccurrencesSheetOpen = false);
    }
  }

  Future<void> _openCalendarManager(
    BuildContext context,
    TimetableProvider provider, {
    bool create = false,
  }) async {
    if (_calendarManagerOpen || !widget.interactive) return;
    _setUiBusyFlag(() => _calendarManagerOpen = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: UiCommandFeedbackHost(
              builder: (_) => _CalendarManagerPage(createOnOpen: create),
            ),
          ),
        ),
      );
    } finally {
      _setUiBusyFlag(() => _calendarManagerOpen = false);
    }
  }

  Future<void> _openSettingsPage(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_settingsPageOpen || !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _settingsPageOpen = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const SettingsPage(),
          ),
        ),
      );
    } finally {
      _setUiBusyFlag(() => _settingsPageOpen = false);
    }
  }
}

class _GeneralCalendarSelector extends StatelessWidget {
  const _GeneralCalendarSelector({
    required this.label,
    required this.disabled,
    required this.onPressed,
    required this.showIcon,
    this.startAligned = false,
  });

  final String label;
  final bool disabled;
  final VoidCallback onPressed;
  final bool showIcon;
  final bool startAligned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return Tooltip(
      message: l10n.calendars,
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          key: const ValueKey('general-calendar-selector'),
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.symmetric(horizontal: showIcon ? 10 : 8),
            textStyle: labelStyle,
            shape: skedShapeSchemeOf(context).control,
          ),
          child: SizedBox(
            height: math.max(24, labelPainter.height),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Center the label against the whole control.  A leading icon
                // must not shift the visual center toward the trailing edge.
                Align(
                  alignment: startAligned
                      ? AlignmentDirectional.centerStart
                      : Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: showIcon ? 28 : 0,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: startAligned
                          ? TextAlign.start
                          : TextAlign.center,
                    ),
                  ),
                ),
                if (showIcon)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: const Icon(Icons.category_outlined, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralToolbarLayout extends StatelessWidget {
  const _GeneralToolbarLayout({
    required this.categoryLabel,
    required this.toolbarWidthPolicy,
    required this.dateLabelFormat,
    required this.showSettingsAction,
    required this.settingsFocusNode,
    required this.settingsAction,
    required this.settingsLabel,
    required this.calendarDisabled,
    required this.onOpenCalendar,
    required this.view,
    required this.selectedDate,
    required this.dateNavigationDirection,
    required this.interactive,
    required this.viewSwitchBehavior,
    required this.onViewChanged,
    required this.onToday,
    required this.onStep,
    required this.onPickDate,
    required this.navigationOrder,
    required this.hiddenNavigationIds,
    required this.hiddenItemsBehavior,
    required this.moreButtonKey,
    this.compactMoreButton,
  });

  final String categoryLabel;
  final String toolbarWidthPolicy;
  final String dateLabelFormat;
  final bool showSettingsAction;
  final FocusNode? settingsFocusNode;
  final VoidCallback? settingsAction;
  final String settingsLabel;
  final bool calendarDisabled;
  final VoidCallback onOpenCalendar;
  final String view;
  final DateTime selectedDate;
  final int dateNavigationDirection;
  final bool interactive;
  final String viewSwitchBehavior;
  final ValueChanged<String> onViewChanged;
  final VoidCallback onToday;
  final ValueChanged<int> onStep;
  final VoidCallback? onPickDate;
  final List<String> navigationOrder;
  final List<String> hiddenNavigationIds;
  final String hiddenItemsBehavior;
  final GlobalKey moreButtonKey;
  final Widget? compactMoreButton;

  Widget _compact(BuildContext context) {
    final m = WorkbenchChromeMetrics.of(context);
    final hidden = hiddenNavigationIds.toSet()..remove('settings');
    final order = normalizeToolbarNavigationOrder(
      navigationOrder,
      knownIds: generalToolbarNavigationKnownIds,
      defaultOrder: generalToolbarNavigationDefaultOrder,
    );
    final managementIds = [
      for (final id in order)
        if ((id == 'category' && !hidden.contains(id)) ||
            (id == 'settings' && showSettingsAction) ||
            id == 'more')
          id,
      if (!order.contains('more')) 'more',
    ];
    final dateIds = [
      for (final id in order)
        if ((id == 'date' || id == 'view') && !hidden.contains(id)) id,
    ];
    Widget navigation(bool date) => LayoutBuilder(
      builder: (context, constraints) => _GeneralWorkspaceNavigation(
        view: view,
        selectedDate: selectedDate,
        dateNavigationDirection: dateNavigationDirection,
        interactive: interactive,
        dateWidth: constraints.maxWidth,
        dateLabelFormat: dateLabelFormat,
        viewSwitchBehavior: viewSwitchBehavior,
        onViewChanged: onViewChanged,
        onToday: onToday,
        onStep: onStep,
        onPickDate: onPickDate,
        viewSwitcherKey: date ? null : const ValueKey('general-view-switcher'),
        includeDate: date,
        includeView: !date,
        compactTouch: true,
      ),
    );
    final categorySelector = _GeneralCalendarSelector(
      label: categoryLabel,
      disabled: calendarDisabled,
      onPressed: onOpenCalendar,
      showIcon: false,
      startAligned: true,
    );
    final actions = <String, Widget>{
      'category': categorySelector,
      'settings': IconButton(
        key: const ValueKey('general-settings-button'),
        focusNode: settingsFocusNode,
        onPressed: settingsAction,
        icon: const Icon(Icons.settings_outlined),
        tooltip: settingsLabel,
      ),
      'more': compactMoreButton!,
      'date': navigation(true),
      'view': navigation(false),
    };
    final ids = [
      for (final id in order)
        if (managementIds.contains(id) || dateIds.contains(id)) id,
      if (!order.contains('more')) 'more',
    ];
    double textWidth(String label, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final theme = Theme.of(context);
    final desiredCategoryWidth = math
        .max(48.0, textWidth(categoryLabel, theme.textTheme.labelLarge) + 16)
        .ceilToDouble();
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final customRange = view == generalViewCustom
        ? context.read<TimetableProvider>().customGeneralDateRange
        : null;
    final compactDate = _dateNavigationCandidates(
      selectedDate,
      view,
      format: dateLabelFormat,
      localeName: localeName,
      customRange: customRange,
    ).last;
    double dateDemand(String label) => math.max(
      48.0,
      textWidth(label, theme.textTheme.titleSmall) +
          _GeneralToolbarMetrics._dateButtonHorizontalPadding * 2 +
          2,
    );
    final desiredDateWidth = dateDemand(compactDate);
    final yearlessDate = _dateNavigationWithoutYear(
      selectedDate,
      view,
      localeName: localeName,
      customRange: customRange,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasCategory = ids.contains('category');
        final hasDate = ids.contains('date');
        final fixedWidth =
            ids.where((id) => id != 'category' && id != 'date').length *
            m.iconTarget;
        final minimumWidth =
            fixedWidth + (hasCategory ? 48 : 0) + (hasDate ? 48 : 0);
        final contentWidth = math.max(constraints.maxWidth, minimumWidth);
        final labelBudget = contentWidth - fixedWidth;
        // Give up a redundant year before ellipsizing the category, not only
        // after the date slot itself runs out of room. Keep month/day context
        // and the existing minimum touch targets when both labels cannot fit.
        final preferredDateWidth =
            hasCategory &&
                yearlessDate != null &&
                desiredCategoryWidth + desiredDateWidth > labelBudget
            ? math.min(desiredDateWidth, dateDemand(yearlessDate))
            : desiredDateWidth;
        final categoryBudget = hasCategory && hasDate
            ? math.min(desiredCategoryWidth, math.max(48.0, labelBudget * .45))
            : 0.0;
        final dateWidth = !hasDate
            ? 0.0
            : hasCategory
            ? math.min(preferredDateWidth, labelBudget - categoryBudget)
            : labelBudget;
        final categoryWidth = hasCategory ? labelBudget - dateWidth : 0.0;
        // Keep one row on touch layouts. Shorten labels, not touch targets, and
        // preserve the user's order/visibility without persisting layout choices.
        return SingleChildScrollView(
          key: const ValueKey('general-compact-toolbar-scroll'),
          scrollDirection: Axis.horizontal,
          physics: contentWidth > constraints.maxWidth + .5
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: contentWidth,
            child: IconButtonTheme(
              data: IconButtonThemeData(style: m.iconStyle),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: m.commandHeight),
                child: Row(
                  key: const ValueKey('general-compact-toolbar-single-row'),
                  children: [
                    if (!hasCategory && !hasDate) const Spacer(),
                    for (final id in ids)
                      SizedBox(
                        key: id == 'date'
                            ? const ValueKey('general-date-navigation')
                            : null,
                        width: switch (id) {
                          'category' => categoryWidth,
                          'date' => dateWidth,
                          _ => m.iconTarget,
                        },
                        child: actions[id]!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compactMoreButton != null) return _compact(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 0.0;
          // Use the complete toolbar slot.  The allocation policy itself
          // keeps the calendar control bounded; capping the whole group here
          // would leave a misleading empty tail on wide windows.
          final groupWidth = availableWidth;
          final compactToolbar = availableWidth < AppBreakpoints.compact;
          final resourceLayout = WorkspaceCanvasScope.maybeOf(context);
          final categoryInResources =
              resourceLayout?.resources == true &&
              resourceLayout!.resourceWidth >
                  AppBreakpoints.compactResourcePane;
          final categoryVisible =
              !categoryInResources && !hiddenNavigationIds.contains('category');
          final viewVisible = !hiddenNavigationIds.contains('view');
          final extraMore =
              hiddenItemsBehavior == toolbarHiddenItemsBehaviorMore &&
              hiddenNavigationIds.isNotEmpty &&
              !hiddenNavigationIds.contains('more');
          var metrics = _GeneralToolbarMetrics.calculate(
            context: context,
            availableWidth: math.max(0, groupWidth - 52),
            scheduleName: categoryLabel,
            policy: toolbarWidthPolicy,
            showSettingsAction: showSettingsAction,
          );
          if (compactToolbar) {
            final managementActions =
                1 + (showSettingsAction ? 1 : 0) + (extraMore ? 1 : 0);
            metrics = _GeneralToolbarMetrics(
              calendarWidth: math.max(
                48,
                availableWidth - managementActions * 52,
              ),
              dateWidth: math.max(48, availableWidth - (viewVisible ? 52 : 0)),
              calendarShowIcon: availableWidth >= 360,
            );
          } else if (categoryInResources) {
            metrics = _GeneralToolbarMetrics(
              calendarWidth: 0,
              dateWidth: math.min(
                540,
                metrics.dateWidth + metrics.calendarWidth + 4,
              ),
              calendarShowIcon: false,
            );
          }
          final calendar = SizedBox(
            width: metrics.calendarWidth,
            child: _GeneralCalendarSelector(
              label: categoryLabel,
              disabled: calendarDisabled,
              onPressed: onOpenCalendar,
              showIcon: metrics.calendarShowIcon,
            ),
          );
          final dateNavigation = SizedBox(
            key: const ValueKey('general-date-navigation'),
            width: metrics.dateWidth,
            child: _GeneralWorkspaceNavigation(
              view: view,
              selectedDate: selectedDate,
              dateNavigationDirection: dateNavigationDirection,
              interactive: interactive,
              dateWidth: metrics.dateWidth,
              dateLabelFormat: dateLabelFormat,
              viewSwitchBehavior: viewSwitchBehavior,
              onViewChanged: onViewChanged,
              onStep: onStep,
              onToday: onToday,
              onPickDate: onPickDate,
              viewSwitcherKey: null,
              includeDate: true,
              includeView: false,
            ),
          );
          final viewNavigation = SizedBox.square(
            dimension: 48,
            child: _GeneralWorkspaceNavigation(
              view: view,
              selectedDate: selectedDate,
              dateNavigationDirection: dateNavigationDirection,
              interactive: interactive,
              dateWidth: metrics.dateWidth,
              dateLabelFormat: dateLabelFormat,
              viewSwitchBehavior: viewSwitchBehavior,
              onViewChanged: onViewChanged,
              onStep: onStep,
              onToday: onToday,
              onPickDate: onPickDate,
              includeDate: false,
              includeView: true,
            ),
          );
          final settings = showSettingsAction
              ? SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    key: const ValueKey('general-settings-button'),
                    focusNode: settingsFocusNode,
                    onPressed: settingsAction,
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: settingsLabel,
                  ),
                )
              : null;
          // Keep rendering safe even if a transient/manual snapshot bypasses
          // model normalization. Settings is always the recovery entry.
          final hidden = hiddenNavigationIds
              .where(generalToolbarNavigationKnownIds.contains)
              .where((id) => id != 'settings')
              .toSet();
          final order = normalizeToolbarNavigationOrder(
            navigationOrder,
            knownIds: generalToolbarNavigationKnownIds,
            defaultOrder: generalToolbarNavigationDefaultOrder,
          );
          final canShowMore =
              hiddenItemsBehavior == toolbarHiddenItemsBehaviorMore &&
              hidden.isNotEmpty &&
              !hidden.contains('more');
          final actionById = <String, Widget>{
            if (categoryVisible) 'category': calendar,
            'date': dateNavigation,
            'view': viewNavigation,
            if (canShowMore)
              'more': KeyedSubtree(
                key: const ValueKey('general-toolbar-more-button'),
                child: SkedPopupMenuButton<String>(
                  key: moreButtonKey,
                  icon: const Icon(Icons.more_horiz),
                  tooltip: l10n.more,
                  enabled: interactive,
                  onSelected: (id) {
                    switch (id) {
                      case 'category':
                        onOpenCalendar();
                      case 'date':
                        onPickDate?.call();
                      case 'today':
                        onToday();
                      case 'view':
                        if (viewSwitchBehavior ==
                            generalViewSwitchBehaviorMenu) {
                          // PopupMenuButton invokes onSelected after its
                          // route has completed, so the second menu can be
                          // opened directly without racing the first route's
                          // reverse animation.
                          unawaited(
                            _showGeneralViewSelectionMenu(
                              context: context,
                              anchorContext:
                                  moreButtonKey.currentContext ?? context,
                              view: view,
                              interactive: interactive,
                              onViewChanged: onViewChanged,
                            ),
                          );
                        } else {
                          onViewChanged(
                            _nextGeneralView(
                              view,
                              hasCustomRange:
                                  context
                                      .read<TimetableProvider>()
                                      .customGeneralDateRange !=
                                  null,
                            ),
                          );
                        }
                    }
                  },
                  itemBuilder: (context) => [
                    for (final id in order)
                      if (hidden.contains(id) && id != 'settings')
                        SkedPopupMenuItem<String>(
                          value: id,
                          child: Text(switch (id) {
                            'category' => l10n.calendars,
                            'date' => l10n.pickDate,
                            'view' => l10n.toolbarNavigationView,
                            _ => id,
                          }),
                        ),
                    if (hidden.contains('date'))
                      SkedPopupMenuItem<String>(
                        value: 'today',
                        child: Text(l10n.today),
                      ),
                  ],
                ),
              ),
          };
          if (settings != null) actionById['settings'] = settings;
          final hiddenActions = <String>{...hidden};
          final orderedIds = <String>[];
          for (final id in order) {
            if (!hiddenActions.contains(id) && actionById.containsKey(id)) {
              orderedIds.add(id);
            }
          }
          if (canShowMore && !orderedIds.contains('more')) {
            orderedIds.add('more');
          }
          if (settings != null && !orderedIds.contains('settings')) {
            orderedIds.add('settings');
          }
          if (compactToolbar &&
              order.join(',') !=
                  generalToolbarNavigationDefaultOrder.join(',')) {
            return Wrap(
              spacing: 4,
              runSpacing: 8,
              children: [for (final id in orderedIds) actionById[id]!],
            );
          }
          if (compactToolbar && availableWidth >= 240) {
            final managementIds = orderedIds
                .where((id) => id != 'date' && id != 'view')
                .toList();
            final dateIds = orderedIds
                .where((id) => id == 'date' || id == 'view')
                .toList();
            Widget row(List<String> ids) => Row(
              children: [
                for (var i = 0; i < ids.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  actionById[ids[i]]!,
                ],
              ],
            );
            return Column(
              key: const ValueKey('general-compact-toolbar-rows'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                row(managementIds),
                if (dateIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  row(dateIds),
                ],
              ],
            );
          }
          final widths = <String, double>{
            'category': metrics.calendarWidth,
            'date': metrics.dateWidth,
            'view': 48,
            'settings': 48,
            'more': 48,
          };
          final contentWidth =
              orderedIds.fold<double>(
                0,
                (sum, id) => sum + (widths[id] ?? 48),
              ) +
              math.max(0, orderedIds.length - 1) * 4;
          final children = [
            for (var i = 0; i < orderedIds.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              actionById[orderedIds[i]]!,
            ],
          ];
          final navigation = contentWidth > availableWidth + 0.5
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(children: children),
                )
              : children.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
                  width: availableWidth,
                  child: Row(
                    children: [
                      children.first,
                      if (children.length > 1) ...[
                        const Spacer(),
                        ...children.skip(1),
                      ],
                    ],
                  ),
                );
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(width: groupWidth, child: navigation),
          );
        },
      ),
    );
  }
}

class _GeneralToolbarMetrics {
  const _GeneralToolbarMetrics({
    required this.calendarWidth,
    required this.dateWidth,
    required this.calendarShowIcon,
  });

  static const _calendarSoftMin = 96.0;
  static const _dateSoftMin = 72.0;
  static const _hardMin = 48.0;
  static const _calendarMax = 280.0;
  static const _dateButtonHorizontalPadding = 8.0;

  final double calendarWidth;
  final double dateWidth;
  final bool calendarShowIcon;

  static _GeneralToolbarMetrics calculate({
    required BuildContext context,
    required double availableWidth,
    required String scheduleName,
    required String policy,
    required bool showSettingsAction,
  }) {
    final fixedWidth =
        48 + (showSettingsAction ? 48 : 0) + (showSettingsAction ? 3 : 2) * 4;
    final budget = math.max(0.0, availableWidth - fixedWidth);
    final minima = _minimumSlotWidths(budget);
    final calendarMin = minima.$1;
    final dateMin = minima.$2;
    final style =
        Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final painter = TextPainter(
      text: TextSpan(text: scheduleName, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final scale = scaler.scale(style.fontSize ?? 14) / (style.fontSize ?? 14);
    final iconAllowed = scale <= 1.3;
    final textOnlyDemand = painter.width + 16;
    // The centered label reserves 28dp on both sides so the leading icon
    // cannot shift it, plus the button's 10dp padding on each side.
    final iconDemand = painter.width + 76;
    // Only reserve the leading icon when the bounded content slot can
    // actually contain it.  Otherwise the calendar slot is sized to the
    // text-only demand instead of retaining an invisible icon's width.
    final contentMax = math.max(
      calendarMin,
      math.min(
        math.min(_calendarMax, budget * 0.4),
        math.max(0, budget - dateMin),
      ),
    );
    final contentDemand = iconAllowed && iconDemand <= contentMax
        ? iconDemand
        : textOnlyDemand;

    final desiredCalendar = (switch (normalizeGeneralToolbarWidthPolicy(
      policy,
    )) {
      generalToolbarWidthPolicyBalanced => budget / 2,
      generalToolbarWidthPolicyCalendarPriority => budget * 3 / 5,
      generalToolbarWidthPolicyDatePriority => budget * 2 / 5,
      _ => contentDemand.clamp(
        calendarMin,
        math.max(
          calendarMin,
          math.min(
            _calendarMax,
            math.min(budget * 0.4, math.max(0, budget - dateMin)),
          ),
        ),
      ),
    }).toDouble();
    final calendarWidth = _clampSlot(
      desiredCalendar,
      min: calendarMin,
      max: math.max(calendarMin, budget - dateMin),
      budget: budget,
    );
    final dateWidth = math.max(0.0, budget - calendarWidth);
    final showIcon = iconAllowed && calendarWidth >= iconDemand;
    return _GeneralToolbarMetrics(
      calendarWidth: calendarWidth,
      dateWidth: dateWidth,
      calendarShowIcon: showIcon,
    );
  }

  /// Returns the minimum calendar/date widths for the current flexible
  /// budget.  Between the soft and hard totals the two minima shrink
  /// continuously, preserving their relative amount of optional space.
  static (double, double) _minimumSlotWidths(double budget) {
    const hardTotal = _hardMin * 2;
    const softTotal = _calendarSoftMin + _dateSoftMin;
    if (budget >= softTotal) {
      return (_calendarSoftMin, _dateSoftMin);
    }
    if (budget <= hardTotal) {
      // A physical window this narrow cannot fit four 48dp controls and the
      // required gaps at all.  Keep the hard touch targets; normal Android
      // windows are wider than this lower bound.
      return (_hardMin, _hardMin);
    }
    final progress = (budget - hardTotal) / (softTotal - hardTotal);
    return (
      _hardMin + (_calendarSoftMin - _hardMin) * progress,
      _hardMin + (_dateSoftMin - _hardMin) * progress,
    );
  }

  static double _clampSlot(
    double value, {
    required double min,
    required double max,
    required double budget,
  }) {
    if (budget <= 0) return 0;
    // If the flexible budget is narrower than two hard touch targets, keep
    // the row inside its parent rather than creating an overflow. Standard
    // Android widths never reach this fallback, but it keeps desktop
    // split-view and test surfaces deterministic.
    final roomForCalendar = math.max(0.0, budget - _hardMin);
    final safeMin = math.min(min, roomForCalendar);
    final safeMax = math.min(math.max(safeMin, max), roomForCalendar);
    return value.clamp(safeMin, safeMax).toDouble();
  }
}

class _GeneralWorkspaceNavigation extends StatelessWidget {
  const _GeneralWorkspaceNavigation({
    required this.view,
    required this.selectedDate,
    required this.dateNavigationDirection,
    required this.interactive,
    required this.dateWidth,
    required this.dateLabelFormat,
    required this.viewSwitchBehavior,
    required this.onViewChanged,
    required this.onToday,
    required this.onStep,
    required this.onPickDate,
    this.viewSwitcherKey = const ValueKey('general-view-switcher'),
    this.includeDate = true,
    this.includeView = true,
    this.compactTouch = false,
  });

  final String view;
  final DateTime selectedDate;
  final int dateNavigationDirection;
  final bool interactive;
  final double dateWidth;
  final String dateLabelFormat;
  final String viewSwitchBehavior;
  final ValueChanged<String> onViewChanged;
  final VoidCallback onToday;
  final ValueChanged<int> onStep;
  final VoidCallback? onPickDate;
  final Key? viewSwitcherKey;
  final bool includeDate;
  final bool includeView;
  final bool compactTouch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final customRange = context.select<TimetableProvider, GeneralDateRange?>(
      (p) => p.customGeneralDateRange,
    );
    final currentViewLabel = _generalViewLabel(
      l10n,
      view,
      customDays: customRange?.dayCount,
    );
    final nextView = _nextGeneralView(
      view,
      hasCustomRange: customRange != null,
    );
    final nextViewLabel = _generalViewLabel(
      l10n,
      nextView,
      customDays: customRange?.dayCount,
    );
    final selector = includeView
        ? _GeneralViewSwitcher(
            key: viewSwitcherKey,
            view: view,
            behavior: viewSwitchBehavior,
            currentLabel: currentViewLabel,
            nextLabel: nextViewLabel,
            interactive: interactive,
            onViewChanged: onViewChanged,
          )
        : null;
    final textFactor = WorkbenchLayoutPolicy.textFactor(
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final showSteps =
        includeDate && !compactTouch && dateWidth >= 192 * textFactor;
    final showToday =
        !compactTouch && showSteps && dateWidth >= 320 * textFactor;
    final labelWidth = dateWidth - (showSteps ? 96 : 0) - (showToday ? 48 : 0);
    final dateLabel = _dateNavigationLabelForWidth(
      context,
      selectedDate,
      view,
      labelWidth,
      format: dateLabelFormat,
      compactToolbar: compactTouch,
    );
    final accessibleDateLabel = _accessibleDateNavigationLabel(
      selectedDate,
      view,
      context,
    );
    final fullDateLabel =
        '${view == generalViewCustom ? '$currentViewLabel, ' : ''}${_datePickerTitle(l10n, _dateUnitForView(view))}: $accessibleDateLabel';
    final dateInteractive = interactive && onPickDate != null;
    final dateButton = SizedBox(
      width: labelWidth,
      child: Tooltip(
        excludeFromSemantics: true,
        message: fullDateLabel,
        child: Semantics(
          button: true,
          enabled: dateInteractive,
          label: fullDateLabel,
          hint: l10n.generalViewLongPressTodayHint,
          onTap: dateInteractive ? onPickDate : null,
          onLongPress: dateInteractive ? onToday : null,
          excludeSemantics: true,
          child: OutlinedButton(
            key: const ValueKey('general-date-title-button'),
            onPressed: dateInteractive ? onPickDate : null,
            onLongPress: dateInteractive ? onToday : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(
                horizontal: _GeneralToolbarMetrics._dateButtonHorizontalPadding,
              ),
              side: BorderSide.none,
              alignment: compactTouch ? AlignmentDirectional.centerStart : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: Theme.of(context).textTheme.titleSmall,
            ),
            child: ClipRect(
              child: SkedDirectionalTransition(
                trigger: dateLabel,
                direction: dateNavigationDirection,
                distance: 16,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: compactTouch
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      if (view == generalViewCustom && !compactTouch)
                        Text(
                          currentViewLabel,
                          key: const ValueKey('general-custom-range-label'),
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        dateLabel,
                        key: ValueKey('general-date-label-$dateLabel'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showSteps)
          IconButton(
            key: const ValueKey('general-previous-period'),
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            onPressed:
                interactive &&
                    (view != generalViewCustom ||
                        customRange?.shifted(-(customRange.dayCount)) != null)
                ? () => onStep(-1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
        if (includeDate) Expanded(child: dateButton),
        if (showToday)
          IconButton(
            key: const ValueKey('general-go-today'),
            tooltip: l10n.today,
            onPressed: interactive ? onToday : null,
            icon: const Icon(Icons.today_outlined),
          ),
        if (showSteps)
          IconButton(
            key: const ValueKey('general-next-period'),
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            onPressed:
                interactive &&
                    (view != generalViewCustom ||
                        customRange?.shifted(customRange.dayCount) != null)
                ? () => onStep(1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        if (includeDate && includeView) const SizedBox(width: 4),
        if (selector != null) SizedBox.square(dimension: 48, child: selector),
      ],
    );
  }
}

class _GeneralViewSwitcher extends StatelessWidget {
  const _GeneralViewSwitcher({
    super.key,
    required this.view,
    required this.behavior,
    required this.currentLabel,
    required this.nextLabel,
    required this.interactive,
    required this.onViewChanged,
  });

  final String view;
  final String behavior;
  final String currentLabel;
  final String nextLabel;
  final bool interactive;
  final ValueChanged<String> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final icon =
        view == generalViewCustom &&
            WorkbenchChromeMetrics.compactTouch(context)
        ? Icons.date_range_outlined
        : _generalViewIcon(view);
    final enabled = interactive;
    if (behavior == generalViewSwitchBehaviorMenu) {
      final tooltip = '${l10n.generalViewSwitchMenuTooltip}: $currentLabel';
      return SkedPopupMenuButton<String>(
        icon: AnimatedSwitcher(
          duration: SkedMotionPolicy.of(context).effects(SkedMotionSpeed.fast),
          child: Icon(icon, key: ValueKey(view)),
        ),
        tooltip: tooltip,
        enabled: interactive,
        onSelected: (next) {
          if (next != view) onViewChanged(next);
        },
        itemBuilder: (context) => _generalViewMenuItems(context, view),
      );
    }

    final tooltip =
        '${l10n.generalViewSwitchTooltip}: $currentLabel -> $nextLabel';
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        excludeFromSemantics: true,
        message: tooltip,
        child: IconButton(
          onPressed: enabled
              ? () => onViewChanged(
                  _nextGeneralView(
                    view,
                    hasCustomRange:
                        context
                            .read<TimetableProvider>()
                            .customGeneralDateRange !=
                        null,
                  ),
                )
              : null,
          icon: AnimatedSwitcher(
            duration: SkedMotionPolicy.of(context)
                .effects(SkedMotionSpeed.fast),
            child: Icon(icon, key: ValueKey(view)),
          ),
        ),
      ),
    );
  }
}

List<PopupMenuEntry<String>> _generalViewMenuItems(
  BuildContext context,
  String view,
) {
  final colors = Theme.of(context).colorScheme;
  return [
    for (final item in _generalViewOptions(AppLocalizations.of(context)))
      SkedPopupMenuItem<String>(
        value: item.value,
        child: Semantics(
          selected: item.value == view,
          child: Row(
            children: [
              Icon(item.icon, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label)),
              item.value == view
                  ? Icon(Icons.check_rounded, size: 20, color: colors.primary)
                  : const SizedBox.square(dimension: 20),
            ],
          ),
        ),
      ),
  ];
}

Future<void> _showGeneralViewSelectionMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  required String view,
  required bool interactive,
  required ValueChanged<String> onViewChanged,
}) async {
  if (!interactive) return;
  final anchor = anchorContext.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (anchor is! RenderBox ||
      overlay is! RenderBox ||
      !anchor.attached ||
      !overlay.attached) {
    return;
  }

  final anchorRect = Rect.fromPoints(
    anchor.localToGlobal(Offset.zero, ancestor: overlay),
    anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    ),
  );
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size),
    menuPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    clipBehavior: Clip.antiAlias,
    popUpAnimationStyle: SkedMotionPolicy.of(context)
        .routeStyle(AppMotion.menuAnimationStyle),
    items: _generalViewMenuItems(context, view),
  );
  if (selected != null && selected != view) onViewChanged(selected);
}

class _GeneralViewOption {
  const _GeneralViewOption(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

List<_GeneralViewOption> _generalViewOptions(AppLocalizations l10n) => [
  _GeneralViewOption(generalViewWeek, l10n.viewWeek, Icons.view_week_outlined),
  _GeneralViewOption(
    generalViewCustom,
    l10n.dateRangeCustom,
    Icons.date_range_outlined,
  ),
  _GeneralViewOption(generalViewDay, l10n.viewDay, Icons.view_day_outlined),
  _GeneralViewOption(generalViewList, l10n.viewList, Icons.list_alt_outlined),
  _GeneralViewOption(
    generalViewMonth,
    l10n.viewMonth,
    Icons.calendar_view_month_outlined,
  ),
];

IconData _generalViewIcon(String view) {
  return switch (view) {
    generalViewDay => Icons.view_day_outlined,
    generalViewList => Icons.list_alt_outlined,
    generalViewMonth => Icons.calendar_view_month_outlined,
    _ => Icons.view_week_outlined,
  };
}

String _generalViewLabel(
  AppLocalizations l10n,
  String view, {
  int? customDays,
}) {
  return switch (view) {
    generalViewDay => l10n.viewDay,
    generalViewList => l10n.viewList,
    generalViewMonth => l10n.viewMonth,
    generalViewCustom => l10n.dateRangeCustomDays(customDays ?? 7),
    _ => l10n.viewWeek,
  };
}

String _nextGeneralView(String view, {bool hasCustomRange = false}) {
  return switch (view) {
    generalViewWeek || generalViewCustom => generalViewDay,
    generalViewDay => generalViewList,
    generalViewList => generalViewMonth,
    _ => hasCustomRange ? generalViewCustom : generalViewWeek,
  };
}

class _GeneralHomeSnapshot {
  const _GeneralHomeSnapshot({
    required this.selectedDate,
    required this.customDateRange,
    required this.defaultView,
    required this.viewSwitchBehavior,
    required this.dateLabelFormat,
    required this.enableLongPressAddEvent,
    required this.allDayTimelineCollapsed,
    required this.showAddEventFab,
    required this.toolbarWidthPolicy,
    required this.activeScheduleId,
    required this.schedules,
    required this.reminderAcknowledgements,
    required this.fitWeekColumnsToWidth,
    required this.customDayMinWidth,
    required this.showWeekends,
    required this.showLunarCalendar,
    required this.dayStartHour,
    required this.dayEndHour,
    required this.timeGridMinutes,
    required this.timeGridHourHeight,
    required this.toolbarNavigationOrder,
    required this.hiddenToolbarNavigationIds,
    required this.toolbarHiddenItemsBehavior,
  });

  factory _GeneralHomeSnapshot.from(TimetableProvider provider) {
    final data = provider.generalMode;
    return _GeneralHomeSnapshot(
      selectedDate: data.selectedDate,
      customDateRange: data.customDateRange,
      defaultView: data.defaultView,
      viewSwitchBehavior: data.viewSwitchBehavior,
      toolbarWidthPolicy: data.toolbarWidthPolicy,
      dateLabelFormat: data.dateLabelFormat,
      enableLongPressAddEvent: data.enableLongPressAddEvent,
      allDayTimelineCollapsed: data.allDayTimelineCollapsed,
      showAddEventFab: data.showAddEventFab,
      activeScheduleId: data.activeScheduleId,
      schedules: data.schedules,
      reminderAcknowledgements: data.reminderAcknowledgements,
      fitWeekColumnsToWidth: data.fitWeekColumnsToWidth,
      customDayMinWidth: data.customDayMinWidth,
      showWeekends: data.showWeekends,
      showLunarCalendar: data.showLunarCalendar,
      dayStartHour: data.dayStartHour,
      dayEndHour: data.dayEndHour,
      timeGridMinutes: data.timeGridMinutes,
      timeGridHourHeight: data.timeGridHourHeight,
      toolbarNavigationOrder: data.toolbarNavigationOrder,
      hiddenToolbarNavigationIds: data.hiddenToolbarNavigationIds,
      toolbarHiddenItemsBehavior: data.toolbarHiddenItemsBehavior,
    );
  }

  final DateTime selectedDate;
  final GeneralDateRange? customDateRange;
  final String defaultView;
  final String viewSwitchBehavior;
  final String toolbarWidthPolicy;
  final String dateLabelFormat;
  final bool enableLongPressAddEvent;
  final bool allDayTimelineCollapsed;
  final bool showAddEventFab;
  final String activeScheduleId;
  final List<GeneralSchedule> schedules;
  final List<GeneralReminderAcknowledgement> reminderAcknowledgements;
  final bool fitWeekColumnsToWidth;
  final int? customDayMinWidth;
  final bool showWeekends;
  final bool showLunarCalendar;
  final int dayStartHour;
  final int dayEndHour;
  final int timeGridMinutes;
  final int timeGridHourHeight;
  final List<String> toolbarNavigationOrder;
  final List<String> hiddenToolbarNavigationIds;
  final String toolbarHiddenItemsBehavior;

  @override
  bool operator ==(Object other) {
    return other is _GeneralHomeSnapshot &&
        _sameDay(other.selectedDate, selectedDate) &&
        other.defaultView == defaultView &&
        other.viewSwitchBehavior == viewSwitchBehavior &&
        other.toolbarWidthPolicy == toolbarWidthPolicy &&
        other.customDateRange == customDateRange &&
        other.dateLabelFormat == dateLabelFormat &&
        other.enableLongPressAddEvent == enableLongPressAddEvent &&
        other.allDayTimelineCollapsed == allDayTimelineCollapsed &&
        other.showAddEventFab == showAddEventFab &&
        other.activeScheduleId == activeScheduleId &&
        identical(other.schedules, schedules) &&
        identical(other.reminderAcknowledgements, reminderAcknowledgements) &&
        other.fitWeekColumnsToWidth == fitWeekColumnsToWidth &&
        other.customDayMinWidth == customDayMinWidth &&
        other.showWeekends == showWeekends &&
        other.showLunarCalendar == showLunarCalendar &&
        other.dayStartHour == dayStartHour &&
        other.dayEndHour == dayEndHour &&
        other.timeGridMinutes == timeGridMinutes &&
        other.timeGridHourHeight == timeGridHourHeight &&
        _stringListEquals(
          other.toolbarNavigationOrder,
          toolbarNavigationOrder,
        ) &&
        _stringListEquals(
          other.hiddenToolbarNavigationIds,
          hiddenToolbarNavigationIds,
        ) &&
        other.toolbarHiddenItemsBehavior == toolbarHiddenItemsBehavior;
  }

  @override
  int get hashCode => Object.hashAll([
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    defaultView,
    customDateRange,
    viewSwitchBehavior,
    toolbarWidthPolicy,
    dateLabelFormat,
    enableLongPressAddEvent,
    allDayTimelineCollapsed,
    showAddEventFab,
    activeScheduleId,
    identityHashCode(schedules),
    identityHashCode(reminderAcknowledgements),
    fitWeekColumnsToWidth,
    customDayMinWidth,
    showWeekends,
    showLunarCalendar,
    dayStartHour,
    dayEndHour,
    timeGridMinutes,
    timeGridHourHeight,
    Object.hashAll(toolbarNavigationOrder),
    Object.hashAll(hiddenToolbarNavigationIds),
    toolbarHiddenItemsBehavior,
  ]);
}

bool _stringListEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _MoreGeneralOccurrencesSheet extends StatelessWidget {
  const _MoreGeneralOccurrencesSheet({
    required this.occurrences,
    this.contextDate,
    required this.onOccurrenceTap,
  });

  final List<GeneralEventOccurrence> occurrences;
  final DateTime? contextDate;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = occurrences.first;
    final headingDate = contextDate ?? first.start;
    return AppSheetScaffold(
      key: const ValueKey('general-more-occurrences-sheet'),
      title: Text(l10n.monthDayEvents(headingDate.day, occurrences.length)),
      subtitle: Text(
        contextDate == null
            ? '${_formatDate(first.start)}  '
                  '${_formatOccurrenceTime(context, first)}'
            : '${_formatDate(headingDate)}  '
                  '${_weekdayLabel(context, headingDate)}',
      ),
      heightFactor: occurrences.length > 5 ? 0.72 : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final occurrence in occurrences)
            _GeneralListOccurrenceTile(
              occurrence: occurrence,
              onTap: () => onOccurrenceTap(occurrence),
            ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
    );
  }
}

List<DateTime> _visibleWeekDays(DateTime weekStart, bool showWeekends) {
  return [
    for (var i = 0; i < 7; i++)
      if (showWeekends || i < 5) addCalendarDays(weekStart, i),
  ];
}

class _GeneralOccurrenceFilter {
  const _GeneralOccurrenceFilter({
    required this.query,
    required this.colorValue,
  });

  final String query;
  final int? colorValue;

  bool get isActive => query.trim().isNotEmpty || colorValue != null;

  GeneralOccurrenceQuery toQuery({
    required DateTime startInclusive,
    required DateTime endExclusive,
    bool onlyVisibleCalendars = true,
  }) {
    return GeneralOccurrenceQuery(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      onlyVisibleCalendars: onlyVisibleCalendars,
      searchQuery: query,
      colorValue: colorValue,
    );
  }
}

String? _dateNavigationWithoutYear(
  DateTime date,
  String view, {
  required String localeName,
  GeneralDateRange? customRange,
}) {
  final unit = _dateUnitForView(view);
  final range = customRange == null
      ? dateSelectionRange(date, unit)
      : (start: customRange.start, end: customRange.end);
  final first = range.start, last = range.end;
  // Cross-year ranges need both years to retain their meaning.
  if (first.year != last.year) return null;
  if (unit == DateSelectionUnit.month) {
    return intl.DateFormat.MMM(localeName).format(first);
  }
  final start = intl.DateFormat.Md(localeName).format(first);
  final end = first.month == last.month
      ? '${last.day}'
      : intl.DateFormat.Md(localeName).format(last);
  return _sameDay(first, last) ? start : '$start–$end';
}

String _dateNavigationLabelForWidth(
  BuildContext context,
  DateTime date,
  String view,
  double width, {
  required String format,
  bool compactToolbar = false,
}) {
  final theme = Theme.of(context);
  final style =
      (compactToolbar
          ? theme.textTheme.titleSmall
          : theme.textTheme.labelLarge) ??
      const TextStyle(fontSize: 14);
  final scaler = MediaQuery.textScalerOf(context);
  final maxTextWidth = math.max(
    0.0,
    width - (_GeneralToolbarMetrics._dateButtonHorizontalPadding * 2),
  );
  final candidates = _dateNavigationCandidates(
    date,
    view,
    format: format,
    localeName: Localizations.localeOf(context).toLanguageTag(),
    customRange: view == generalViewCustom
        ? context.read<TimetableProvider>().customGeneralDateRange
        : null,
  );
  if (compactToolbar) {
    final custom = view == generalViewCustom
        ? context.read<TimetableProvider>().customGeneralDateRange
        : null;
    final range = custom == null
        ? dateSelectionRange(date, _dateUnitForView(view))
        : (start: custom.start, end: custom.end);
    final first = range.start, last = range.end;
    final yearless = _dateNavigationWithoutYear(
      date,
      view,
      localeName: Localizations.localeOf(context).toLanguageTag(),
      customRange: custom,
    );
    if (yearless != null) candidates.add(yearless);
    if (_dateUnitForView(view) != DateSelectionUnit.month &&
        first.year == last.year) {
      // Full dates remain in the tooltip/semantics and picker. Only the
      // compact label elides redundant years; saved formatting is unchanged.
      if (first.month == last.month) {
        candidates.add(
          _sameDay(first, last) ? '${first.day}' : '${first.day}–${last.day}',
        );
      }
    }
  }
  for (final candidate in candidates) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxTextWidth;
    painter.dispose();
    if (fits) {
      return candidate;
    }
  }
  return candidates.last;
}

DateSelectionUnit _dateUnitForView(String view) => switch (view) {
  generalViewWeek || generalViewCustom => DateSelectionUnit.week,
  generalViewMonth => DateSelectionUnit.month,
  _ => DateSelectionUnit.day,
};

String _datePickerTitle(AppLocalizations l, DateSelectionUnit unit) =>
    switch (unit) {
      DateSelectionUnit.week => l.dateRangeTitle,
      DateSelectionUnit.month => l.datePickerSelectMonth,
      DateSelectionUnit.day => l.pickDate,
    };

List<String> _dateNavigationCandidates(
  DateTime date,
  String view, {
  required String format,
  required String localeName,
  GeneralDateRange? customRange,
}) => [
  formatDateSelection(
    date,
    _dateUnitForView(view),
    locale: localeName,
    format: format,
    customRange: customRange,
  ),
  formatDateSelection(
    date,
    _dateUnitForView(view),
    locale: localeName,
    format: format,
    customRange: customRange,
    compact: true,
  ),
];

String _accessibleDateNavigationLabel(
  DateTime date,
  String view,
  BuildContext context,
) {
  final localizations = MaterialLocalizations.of(context);
  if (view == generalViewMonth) {
    return localizations.formatMonthYear(date);
  }
  if (view != generalViewWeek && view != generalViewCustom) {
    return localizations.formatFullDate(date);
  }
  final range = view == generalViewCustom
      ? context.read<TimetableProvider>().customGeneralDateRange
      : null;
  final start = range?.start ?? startOfWeekMonday(date);
  final end = range?.end ?? addCalendarDays(start, 6);
  return '${localizations.formatFullDate(start)} - '
      '${localizations.formatFullDate(end)}';
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
  if (date.isBefore(firstDate)) {
    return firstDate;
  }
  if (date.isAfter(lastDate)) {
    return lastDate;
  }
  return date;
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _formatOccurrenceTime(
  BuildContext context,
  GeneralEventOccurrence occurrence,
) {
  if (occurrence.isAllDay) {
    return AppLocalizations.of(context).allDay;
  }
  final displayStart = occurrence.calendarDisplayStart;
  final displayEnd = occurrence.calendarDisplayEnd;
  if (!_sameDay(displayStart, displayEnd)) {
    return '${_formatDate(displayStart)} ${_formatTime(displayStart)} - ${_formatDate(displayEnd)} ${_formatTime(displayEnd)}';
  }
  return '${_formatTime(displayStart)} - ${_formatTime(displayEnd)}';
}

String _weekdayLabel(BuildContext context, DateTime date) {
  final l10n = AppLocalizations.of(context);
  return switch (date.weekday) {
    DateTime.monday => l10n.weekdayShortMonday,
    DateTime.tuesday => l10n.weekdayShortTuesday,
    DateTime.wednesday => l10n.weekdayShortWednesday,
    DateTime.thursday => l10n.weekdayShortThursday,
    DateTime.friday => l10n.weekdayShortFriday,
    DateTime.saturday => l10n.weekdayShortSaturday,
    _ => l10n.weekdayShortSunday,
  };
}

String _dateKey(DateTime date) => normalizeDateOnly(date).toIso8601String();

String _calendarDateKey(DateTime date) =>
    normalizeDateOnly(date).toIso8601String().split('T').first;

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _nowMinutes() {
  final now = DateTime.now();
  return now.hour * 60 + now.minute;
}

int _snapMinutes(int minutes, int gridMinutes) {
  final step = gridMinutes.clamp(15, 60).toInt();
  return (minutes / step).round() * step;
}

int _nextCalendarColor(List<GeneralSchedule> schedules) {
  return generalCalendarSlotColorValues[schedules.length %
      generalCalendarSlotColorValues.length];
}
