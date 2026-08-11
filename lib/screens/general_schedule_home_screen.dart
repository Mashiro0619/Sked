import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
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
  DateTime? _dateNavigationTarget;
  int _dateNavigationGeneration = 0;
  int _dateNavigationDirection = 0;
  bool _pagerDateCommitInProgress = false;
  int _pagerSyncRevision = 0;

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
    final snapshot = context.select<TimetableProvider, _GeneralHomeSnapshot>(
      _GeneralHomeSnapshot.from,
    );
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context);
    final selectedDate = snapshot.selectedDate;
    final view = normalizeGeneralView(_view ?? snapshot.defaultView);
    final dateNavigationDirection =
        _dateNavigationTarget != null &&
            _calendarDateKey(_dateNavigationTarget!) ==
                _calendarDateKey(selectedDate)
        ? _dateNavigationDirection
        : 0;
    const filter = _GeneralOccurrenceFilter(query: '', colorValue: null);

    final activeCalendar = provider.activeGeneralScheduleOrNull;
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
              horizontal: width < 600 ? 12 : 16,
              vertical: constraints.maxHeight < 600 ? 8 : 12,
            ),
            navigationSpacing: width < 600 ? 4 : 10,
            // Keep the calendar selector and settings affordance in one
            // title row on narrow screens.  The shared toolbar deliberately
            // does not know about this workspace's action hierarchy.
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _GeneralCalendarSelector(
                    schedule: activeCalendar,
                    disabled: _calendarManagerOpen || !widget.interactive,
                    onPressed: () => _openCalendarManager(context, provider),
                  ),
                ),
                if (widget.showSettingsAction) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('general-settings-button'),
                    focusNode: widget.settingsFocusNode,
                    onPressed: settingsAction,
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: l10n.settings,
                  ),
                ],
              ],
            ),
            actions: const [],
            navigation: _GeneralWorkspaceNavigation(
              view: view,
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
                            onEmptySlotTap: (date) => _openEditor(
                              context,
                              provider,
                              initialDate: date,
                            ),
                            onOccurrenceTap: (occurrence) =>
                                _openDetails(context, provider, occurrence),
                            onMoreOccurrencesTap: (occurrences) =>
                                _openMoreOccurrences(
                                  context,
                                  provider,
                                  occurrences,
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
                            onEmptySlotTap: (date) => _openEditor(
                              context,
                              provider,
                              initialDate: date,
                            ),
                            onOccurrenceTap: (occurrence) =>
                                _openDetails(context, provider, occurrence),
                            onMoreOccurrencesTap: (occurrences) =>
                                _openMoreOccurrences(
                                  context,
                                  provider,
                                  occurrences,
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
    List<GeneralEventOccurrence> occurrences,
  ) async {
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
        maxWidth: 620,
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
    required this.schedule,
    required this.disabled,
    required this.onPressed,
  });

  final GeneralSchedule? schedule;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 240.0;
        final labelWidth = math.max(0.0, math.min(240.0, available - 64.0));
        return Tooltip(
          message: l10n.calendars,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('general-calendar-selector'),
              onPressed: disabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: labelWidth),
                child: Text(
                  schedule?.name ?? l10n.calendars,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GeneralWorkspaceNavigation extends StatelessWidget {
  const _GeneralWorkspaceNavigation({
    required this.view,
    required this.selectedDate,
    required this.dateNavigationDirection,
    required this.interactive,
    required this.viewSwitchBehavior,
    required this.onViewChanged,
    required this.onToday,
    required this.onPickDate,
  });

  final String view;
  final DateTime selectedDate;
  final int dateNavigationDirection;
  final bool interactive;
  final String viewSwitchBehavior;
  final ValueChanged<String> onViewChanged;
  final VoidCallback onToday;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentViewLabel = _generalViewLabel(l10n, view);
    final nextView = _nextGeneralView(view);
    final nextViewLabel = _generalViewLabel(l10n, nextView);
    final selector = _GeneralViewSwitcher(
      key: const ValueKey('general-view-switcher'),
      view: view,
      behavior: viewSwitchBehavior,
      currentLabel: currentViewLabel,
      nextLabel: nextViewLabel,
      interactive: interactive,
      onViewChanged: onViewChanged,
    );
    final dateLabel = _dateNavigationLabel(selectedDate, view, context);
    final fullDateLabel = '${l10n.pickDate}: $dateLabel';
    final dateInteractive = interactive && onPickDate != null;
    final dateButton = Tooltip(
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
        child: OutlinedButton.icon(
          key: const ValueKey('general-date-title-button'),
          onPressed: dateInteractive ? onPickDate : null,
          onLongPress: dateInteractive ? onToday : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.event_outlined),
          label: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SkedDirectionalTransition(
              trigger: dateLabel,
              direction: dateNavigationDirection,
              distance: 16,
              child: Text(
                dateLabel,
                key: ValueKey('general-date-label-$dateLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        selector,
        const SizedBox(width: 4),
        Expanded(child: dateButton),
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
        itemBuilder: (context) => [
          for (final item in _generalViewOptions(l10n))
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
                        ? Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : const SizedBox.square(dimension: 20),
                  ],
                ),
              ),
            ),
        ],
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
            duration: SkedMotionPolicy.of(
              context,
            ).effects(SkedMotionSpeed.fast),
            child: Icon(icon, key: ValueKey(view)),
          ),
        ),
      ),
    );
  }
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
    required this.activeScheduleId,
    required this.schedules,
    required this.reminderAcknowledgements,
    required this.showWeekends,
    required this.showLunarCalendar,
    required this.dayStartHour,
    required this.dayEndHour,
    required this.timeGridMinutes,
  });

  factory _GeneralHomeSnapshot.from(TimetableProvider provider) {
    final data = provider.generalMode;
    return _GeneralHomeSnapshot(
      selectedDate: data.selectedDate,
      defaultView: data.defaultView,
      viewSwitchBehavior: data.viewSwitchBehavior,
      activeScheduleId: data.activeScheduleId,
      schedules: data.schedules,
      reminderAcknowledgements: data.reminderAcknowledgements,
      showWeekends: data.showWeekends,
      showLunarCalendar: data.showLunarCalendar,
      dayStartHour: data.dayStartHour,
      dayEndHour: data.dayEndHour,
      timeGridMinutes: data.timeGridMinutes,
    );
  }

  final DateTime selectedDate;
  final String defaultView;
  final String viewSwitchBehavior;
  final String activeScheduleId;
  final List<GeneralSchedule> schedules;
  final List<GeneralReminderAcknowledgement> reminderAcknowledgements;
  final bool showWeekends;
  final bool showLunarCalendar;
  final int dayStartHour;
  final int dayEndHour;
  final int timeGridMinutes;

  @override
  bool operator ==(Object other) {
    return other is _GeneralHomeSnapshot &&
        _sameDay(other.selectedDate, selectedDate) &&
        other.defaultView == defaultView &&
        other.viewSwitchBehavior == viewSwitchBehavior &&
        other.activeScheduleId == activeScheduleId &&
        identical(other.schedules, schedules) &&
        identical(other.reminderAcknowledgements, reminderAcknowledgements) &&
        other.showWeekends == showWeekends &&
        other.showLunarCalendar == showLunarCalendar &&
        other.dayStartHour == dayStartHour &&
        other.dayEndHour == dayEndHour &&
        other.timeGridMinutes == timeGridMinutes;
  }

  @override
  int get hashCode => Object.hash(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
    defaultView,
    viewSwitchBehavior,
    activeScheduleId,
    identityHashCode(schedules),
    identityHashCode(reminderAcknowledgements),
    showWeekends,
    showLunarCalendar,
    dayStartHour,
    dayEndHour,
    timeGridMinutes,
  );
}

class _MoreGeneralOccurrencesSheet extends StatelessWidget {
  const _MoreGeneralOccurrencesSheet({
    required this.occurrences,
    required this.onOccurrenceTap,
  });

  final List<GeneralEventOccurrence> occurrences;
  final ValueChanged<GeneralEventOccurrence> onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = occurrences.first;
    return AppSheetScaffold(
      title: Text(l10n.monthDayEvents(first.start.day, occurrences.length)),
      subtitle: Text(
        '${_formatDate(first.start)}  ${_formatOccurrenceTime(context, first)}',
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

String _dateNavigationLabel(DateTime date, String view, BuildContext context) {
  if (view == generalViewMonth) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMonthYear(date);
  }
  final localizations = MaterialLocalizations.of(context);
  if (view != generalViewWeek) {
    return localizations.formatShortDate(date);
  }
  final start = startOfWeekMonday(date);
  final end = addCalendarDays(start, 6);
  return '${localizations.formatShortDate(start)} - '
      '${localizations.formatShortDate(end)}';
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

Color _readableColor(Color color) {
  return color.computeLuminance() > 0.42 ? Colors.black87 : Colors.white;
}

int _nextCalendarColor(List<GeneralSchedule> schedules) {
  return generalCalendarSlotColorValues[schedules.length %
      generalCalendarSlotColorValues.length];
}
