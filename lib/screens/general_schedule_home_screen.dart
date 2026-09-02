import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart' as intl;
import 'package:lunar/lunar.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../utils/general_schedule_colors.dart';
import '../widgets/app_modal_sheet.dart';
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
  String? _view;
  bool _initializedView = false;
  bool _datePickerOpen = false;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = context.select<TimetableProvider, _GeneralHomeSnapshot>(
      _GeneralHomeSnapshot.from,
    );
    final provider = context.read<TimetableProvider>();
    final selectedDate = snapshot.selectedDate;
    final view = normalizeGeneralView(_view ?? snapshot.defaultView);
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
          final toolbar = SkedWorkspaceToolbar(
            key: const ValueKey('general-workspace-toolbar'),
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 360 ? 8 : 12,
              vertical: constraints.maxHeight < 600 ? 6 : 8,
            ),
            title: _GeneralToolbarLayout(
              categoryLabel: categoryLabel,
              toolbarWidthPolicy: snapshot.toolbarWidthPolicy,
              dateLabelFormat: snapshot.dateLabelFormat,
              showSettingsAction: widget.showSettingsAction,
              settingsFocusNode: widget.settingsFocusNode,
              settingsAction: settingsAction,
              settingsLabel: l10n.settings,
              calendarDisabled: _calendarManagerOpen || !widget.interactive,
              onOpenCalendar: () => _openCalendarManager(context, provider),
              view: view,
              navigationOrder: snapshot.toolbarNavigationOrder,
              hiddenNavigationIds: snapshot.hiddenToolbarNavigationIds,
              hiddenItemsBehavior: snapshot.toolbarHiddenItemsBehavior,
              moreButtonKey: _toolbarMoreButtonKey,
              selectedDate: selectedDate,
              dateNavigationDirection: dateNavigationDirection,
              interactive: widget.interactive,
              viewSwitchBehavior: snapshot.viewSwitchBehavior,
              onViewChanged: (nextView) => setState(() {
                _view = nextView;
                _dateNavigationTarget = null;
                _dateNavigationDirection = 0;
              }),
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
              widget.active &&
              widget.interactive &&
              !_pagerDateCommitInProgress;
          final longPressAddEnabled =
              snapshot.enableLongPressAddEvent &&
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
              _ReminderStrip(
                provider: provider,
                filter: filter,
                active: widget.active,
                onOccurrenceTap: (occurrence) =>
                    _openDetails(context, provider, occurrence),
              ),
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
                        key: ValueKey(view),
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

  Future<void> _goToToday(TimetableProvider provider) async {
    await _selectDate(provider, _visibleGeneralDate(provider, DateTime.now()));
  }

  Future<void> _selectDate(
    TimetableProvider provider,
    DateTime requestedDate,
  ) async {
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
    if (direction == 0) return;

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
      await provider.setSelectedGeneralDate(next);
    } finally {
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
          await provider.setSelectedGeneralDate(next);
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
    if (provider.generalShowWeekends || normalized.weekday <= DateTime.friday) {
      return normalized;
    }
    return addCalendarDays(
      normalized,
      direction < 0
          ? DateTime.friday - normalized.weekday
          : 8 - normalized.weekday,
    );
  }

  Widget _wrapStandalone(Widget workspace) {
    if (widget.embedded) return workspace;
    return Scaffold(key: widget.scaffoldKey, body: workspace);
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
    TimetableProvider provider,
  ) async {
    if (_datePickerOpen || !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _datePickerOpen = true);
    final firstDate = DateTime(1970);
    final lastDate = DateTime(2100);
    try {
      final initialDate = _visibleGeneralDate(
        provider,
        _clampDate(provider.selectedGeneralDate, firstDate, lastDate),
      );
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        selectableDayPredicate: provider.generalShowWeekends
            ? null
            : (date) => date.weekday <= DateTime.friday,
      );
      if (!mounted || picked == null) {
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
    try {
      await showAppModalSheet<GeneralEventEditorResult>(
        context: context,
        isDismissible: canDismiss,
        enableDrag: false,
        maxWidth: appSheetWidthMedium,
        builder: (sheetContext) => GeneralEventEditorSheet(
          initialEvent: event,
          initialDate: initialDate ?? provider.selectedGeneralDate,
          calendars: provider.generalSchedules,
          activeCalendarId: provider.activeGeneralSchedule.id,
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
    if (_detailsSheetOpen || !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _detailsSheetOpen = true);
    final canDismiss = provider.closeGeneralEventPopupOnOutsideTap;
    try {
      await showAppModalSheet<void>(
        context: context,
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
        occurrences.isEmpty ||
        !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _moreOccurrencesSheetOpen = true);
    final canDismiss = provider.closeGeneralEventPopupOnOutsideTap;
    GeneralEventOccurrence? selectedOccurrence;
    try {
      selectedOccurrence = await showAppModalSheet<GeneralEventOccurrence>(
        context: context,
        isDismissible: canDismiss,
        enableDrag: canDismiss,
        maxWidth: appSheetWidthCompact,
        builder: (sheetContext) => _MoreGeneralOccurrencesSheet(
          occurrences: occurrences,
          contextDate: contextDate,
          onOccurrenceTap: (occurrence) =>
              Navigator.of(sheetContext).pop(occurrence),
        ),
      );
    } finally {
      _setUiBusyFlag(() => _moreOccurrencesSheetOpen = false);
    }
    if (selectedOccurrence != null && mounted && context.mounted) {
      await _openDetails(context, provider, selectedOccurrence);
    }
  }

  Future<void> _openCalendarManager(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    if (_calendarManagerOpen || !widget.interactive) {
      return;
    }
    _setUiBusyFlag(() => _calendarManagerOpen = true);
    final canDismiss = provider.closeGeneralEventPopupOnOutsideTap;
    try {
      await showAppModalSheet<void>(
        context: context,
        isDismissible: canDismiss,
        enableDrag: false,
        maxWidth: appSheetWidthCompact,
        builder: (sheetContext) =>
            ChangeNotifierProvider<TimetableProvider>.value(
              value: provider,
              child: const _CalendarManagerSheet(),
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
  });

  final String label;
  final bool disabled;
  final VoidCallback onPressed;
  final bool showIcon;

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
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: showIcon ? 28 : 0,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
    required this.onPickDate,
    required this.navigationOrder,
    required this.hiddenNavigationIds,
    required this.hiddenItemsBehavior,
    required this.moreButtonKey,
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
  final VoidCallback? onPickDate;
  final List<String> navigationOrder;
  final List<String> hiddenNavigationIds;
  final String hiddenItemsBehavior;
  final GlobalKey moreButtonKey;

  @override
  Widget build(BuildContext context) {
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
          final metrics = _GeneralToolbarMetrics.calculate(
            context: context,
            availableWidth: groupWidth,
            scheduleName: categoryLabel,
            policy: toolbarWidthPolicy,
            showSettingsAction: showSettingsAction,
          );
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
            'category': calendar,
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
                          onViewChanged(_nextGeneralView(view));
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
    required this.onPickDate,
    this.viewSwitcherKey = const ValueKey('general-view-switcher'),
    this.includeDate = true,
    this.includeView = true,
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
  final VoidCallback? onPickDate;
  final Key? viewSwitcherKey;
  final bool includeDate;
  final bool includeView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentViewLabel = _generalViewLabel(l10n, view);
    final nextView = _nextGeneralView(view);
    final nextViewLabel = _generalViewLabel(l10n, nextView);
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
    final dateLabel = _dateNavigationLabelForWidth(
      context,
      selectedDate,
      view,
      dateWidth,
      format: dateLabelFormat,
    );
    final accessibleDateLabel = _accessibleDateNavigationLabel(
      selectedDate,
      view,
      context,
    );
    final fullDateLabel = '${l10n.pickDate}: $accessibleDateLabel';
    final dateInteractive = interactive && onPickDate != null;
    final dateButton = SizedBox(
      width: dateWidth,
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
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            child: ClipRect(
              child: SkedDirectionalTransition(
                trigger: dateLabel,
                direction: dateNavigationDirection,
                distance: 16,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    dateLabel,
                    key: ValueKey('general-date-label-$dateLabel'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
        if (includeDate) Expanded(child: dateButton),
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
    final icon = _generalViewIcon(view);
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
              ? () => onViewChanged(_nextGeneralView(view))
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

String _generalViewLabel(AppLocalizations l10n, String view) {
  return switch (view) {
    generalViewDay => l10n.viewDay,
    generalViewList => l10n.viewList,
    generalViewMonth => l10n.viewMonth,
    _ => l10n.viewWeek,
  };
}

String _nextGeneralView(String view) {
  return switch (view) {
    generalViewWeek => generalViewDay,
    generalViewDay => generalViewList,
    generalViewList => generalViewMonth,
    _ => generalViewWeek,
  };
}

class _GeneralHomeSnapshot {
  const _GeneralHomeSnapshot({
    required this.selectedDate,
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
        other.dateLabelFormat == dateLabelFormat &&
        other.enableLongPressAddEvent == enableLongPressAddEvent &&
        other.allDayTimelineCollapsed == allDayTimelineCollapsed &&
        other.showAddEventFab == showAddEventFab &&
        other.activeScheduleId == activeScheduleId &&
        identical(other.schedules, schedules) &&
        identical(other.reminderAcknowledgements, reminderAcknowledgements) &&
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
    viewSwitchBehavior,
    toolbarWidthPolicy,
    dateLabelFormat,
    enableLongPressAddEvent,
    allDayTimelineCollapsed,
    showAddEventFab,
    activeScheduleId,
    identityHashCode(schedules),
    identityHashCode(reminderAcknowledgements),
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

String _dateNavigationLabelForWidth(
  BuildContext context,
  DateTime date,
  String view,
  double width, {
  required String format,
}) {
  final style =
      Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
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
  );
  for (final candidate in candidates) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width <= maxTextWidth) {
      return candidate;
    }
  }
  return candidates.last;
}

List<String> _dateNavigationCandidates(
  DateTime date,
  String view, {
  required String format,
  required String localeName,
}) {
  if (format == generalDateLabelFormatLocalized) {
    return _localizedDateNavigationCandidates(date, view, localeName);
  }
  final year = date.year;
  final shortYear = _shortYear(year);
  final separator = format == generalDateLabelFormatIso ? '-' : '/';
  final month = format == generalDateLabelFormatIso
      ? date.month.toString().padLeft(2, '0')
      : date.month.toString();
  final day = format == generalDateLabelFormatIso
      ? date.day.toString().padLeft(2, '0')
      : date.day.toString();
  String datePart(DateTime value, {bool short = false}) {
    final y = short ? _shortYear(value.year) : value.year.toString();
    final m = format == generalDateLabelFormatIso
        ? value.month.toString().padLeft(2, '0')
        : value.month.toString();
    final d = format == generalDateLabelFormatIso
        ? value.day.toString().padLeft(2, '0')
        : value.day.toString();
    return '$y$separator$m$separator$d';
  }

  if (view == generalViewMonth) {
    final fullMonth = format == generalDateLabelFormatIso
        ? '$year$separator$month'
        : '$year$separator${date.month}';
    final shortMonth = format == generalDateLabelFormatIso
        ? '$shortYear$separator$month'
        : '$shortYear$separator${date.month}';
    return [fullMonth, shortMonth, '${date.month}'];
  }
  if (view != generalViewWeek) {
    return [
      datePart(date),
      datePart(date, short: true),
      '$month$separator$day',
    ];
  }

  final start = startOfWeekMonday(date);
  final end = addCalendarDays(start, 6);
  String monthDayPart(DateTime value) {
    final month = format == generalDateLabelFormatIso
        ? value.month.toString().padLeft(2, '0')
        : value.month.toString();
    final day = format == generalDateLabelFormatIso
        ? value.day.toString().padLeft(2, '0')
        : value.day.toString();
    return '$month$separator$day';
  }

  if (start.year != end.year) {
    return [
      '${datePart(start)}\u2013${datePart(end)}',
      '${datePart(start, short: true)}\u2013${datePart(end, short: true)}',
      '${monthDayPart(start)}\u2013${monthDayPart(end)}',
      '${start.day.toString().padLeft(format == generalDateLabelFormatIso ? 2 : 1, '0')}\u2013${monthDayPart(end)}',
    ];
  }
  if (start.month != end.month) {
    return [
      '${datePart(start)}\u2013${datePart(end)}',
      '${datePart(start)}\u2013${monthDayPart(end)}',
      '${datePart(start, short: true)}\u2013${monthDayPart(end)}',
      '${monthDayPart(start)}\u2013${monthDayPart(end)}',
      '${start.day.toString().padLeft(format == generalDateLabelFormatIso ? 2 : 1, '0')}\u2013${monthDayPart(end)}',
    ];
  }
  return [
    '${datePart(start)}\u2013${datePart(end)}',
    '${datePart(start)}\u2013${monthDayPart(end)}',
    '${datePart(start)}\u2013${end.day.toString().padLeft(format == generalDateLabelFormatIso ? 2 : 1, '0')}',
    '${datePart(start, short: true)}\u2013${end.day.toString().padLeft(format == generalDateLabelFormatIso ? 2 : 1, '0')}',
    '${monthDayPart(start)}\u2013${end.day.toString().padLeft(format == generalDateLabelFormatIso ? 2 : 1, '0')}',
  ];
}

List<String> _localizedDateNavigationCandidates(
  DateTime date,
  String view,
  String localeName,
) {
  final locale = localeName.replaceAll('_', '-');
  final fullDate = intl.DateFormat.yMd(locale).format(date);
  final shortDate = intl.DateFormat.Md(locale).format(date);
  final fullMonth = intl.DateFormat.yMMM(locale).format(date);
  final shortMonth = intl.DateFormat.MMM(locale).format(date);
  if (view == generalViewMonth) {
    return [fullMonth, shortMonth, date.month.toString()];
  }
  if (view != generalViewWeek) {
    return [fullDate, shortDate, shortDate];
  }
  final start = startOfWeekMonday(date);
  final end = addCalendarDays(start, 6);
  final startFull = intl.DateFormat.yMd(locale).format(start);
  final endFull = intl.DateFormat.yMd(locale).format(end);
  final startShort = intl.DateFormat.Md(locale).format(start);
  final endShort = intl.DateFormat.Md(locale).format(end);
  final candidates = <String>['$startFull\u2013$endFull'];
  if (start.year == end.year) {
    candidates.add('$startFull\u2013$endShort');
  }
  candidates.add('$startShort\u2013$endShort');
  candidates.add('${start.day}\u2013$endShort');
  return candidates;
}

String _shortYear(int year) => (year % 100).toString().padLeft(2, '0');

String _accessibleDateNavigationLabel(
  DateTime date,
  String view,
  BuildContext context,
) {
  final localizations = MaterialLocalizations.of(context);
  if (view == generalViewMonth) {
    return localizations.formatMonthYear(date);
  }
  if (view != generalViewWeek) {
    return localizations.formatFullDate(date);
  }
  final start = startOfWeekMonday(date);
  final end = addCalendarDays(start, 6);
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
