import 'workspace_editor.dart';
import 'workspace_editor_form.dart';
import 'workspace_editor_time_rows.dart';
import 'general_event_edit_flow.dart';
import 'sked_task_session.dart';
import 'sked_confirmation_dialog.dart';
import 'sked_time_picker.dart';

import 'dart:convert';

import 'editor_exit_guard.dart';

import 'dart:async';

import '../theme/sked_expressive_theme.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_tooltip.dart';

import 'sked_date_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../utils/general_schedule_colors.dart';
import 'app_modal_sheet.dart';
import 'expressive_dialog.dart';
import 'sked_adaptive_picker_dialog.dart';
import 'sked_task_dialog.dart';
import 'sked_floating_surface.dart';
import 'workbench_chrome_metrics.dart';
import 'ui_command.dart';

class GeneralEventEditorResult {
  const GeneralEventEditorResult({this.event, this.delete = false});
  final GeneralEvent? event;
  final bool delete;
}

class GeneralEventEditorSheet extends StatefulWidget {
  const GeneralEventEditorSheet({
    super.key,
    this.initialEvent,
    this.initialDate,
    this.calendars = const [],
    this.activeCalendarId,
    this.defaultReminderMinutesBefore,
    this.editScope,
    this.onSave,
    this.onDelete,
  });

  final GeneralEvent? initialEvent;
  final DateTime? initialDate;
  final List<GeneralSchedule> calendars;
  final String? activeCalendarId;

  /// Live preview for inherited reminders; never copied into a saved override.
  final int? defaultReminderMinutesBefore;
  final GeneralEventEditScope? editScope;
  final Future<void> Function(GeneralEvent)? onSave;
  final Future<void> Function()? onDelete;

  @override
  State<GeneralEventEditorSheet> createState() =>
      _GeneralEventEditorSheetState();
}

class _GeneralEventEditorSheetState extends State<GeneralEventEditorSheet>
    with EditorExitGuard<GeneralEventEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  late String _calendarId;
  late GeneralEventRecurrence _recurrence;
  late GeneralEventRecurrenceUnit _customUnit;
  late int _interval;
  DateTime? _untilDate;
  int? _repeatCount;
  int? _colorValue;
  late List<int> _reminders;
  late GeneralEventReminderBehavior _reminderBehavior;
  late final ValueNotifier<int?> _defaultReminderPreview;
  late List<GeneralSchedule> _calendarOptions;
  bool _hasPopped = false;
  bool _pickerOpen = false;
  bool _selectionDialogOpen = false;
  bool _actionInProgress = false;
  bool _timeSectionExpanded = true;
  bool _optionsSectionExpanded = true;
  bool _detailsSectionExpanded = false;
  bool _sectionsInitialized = false;

  final _formKey = GlobalKey<FormState>();
  final _timeExpansion = ExpansibleController();
  final _timeErrorKey = GlobalKey();
  Timer? _timeErrorReveal;

  bool get _isEditing => widget.initialEvent != null;
  GeneralSchedule get _selectedCalendar =>
      _calendarOptions.firstWhere((item) => item.id == _calendarId);
  bool get _showCalendarPicker =>
      _calendarOptions.length > 1 || !_selectedCalendar.isVisible;
  SkedTaskSession? _editorSession;

  @override
  Widget guardDiscardConfirmation(Widget dialog) => _editorSession == null
      ? dialog
      : SkedTaskRouteGuard(parent: _editorSession, child: dialog);

  @override
  String get draftFingerprint => jsonEncode([
    _titleController.text,
    _locationController.text,
    _notesController.text,
    _startDate.toIso8601String(),
    _endDate.toIso8601String(),
    _startTime.toString(),
    _endTime.toString(),
    _isAllDay,
    _calendarId,
    _recurrence.name,
    _customUnit.name,
    _interval,
    _untilDate?.toIso8601String(),
    _repeatCount,
    _colorValue,
    _reminders,
    _reminderBehavior.name,
  ]);
  @override
  bool get exitBlocked => _blocked;
  @override
  AppMode get editorWorkspace => AppMode.general;
  @override
  void closeEditor() => _popOnce();

  bool get _blocked =>
      _hasPopped || _pickerOpen || _selectionDialogOpen || _actionInProgress;

  @override
  void initState() {
    super.initState();
    _defaultReminderPreview = ValueNotifier(
      widget.defaultReminderMinutesBefore,
    );
    _calendarOptions = _buildCalendarOptions();
    final event = widget.initialEvent;
    final initial = widget.initialDate ?? DateTime.now();
    final rawStartDt = event != null
        ? tryParseStrictIsoDateTime(event.startDateTimeIso) ?? initial
        : DateTime(
            initial.year,
            initial.month,
            initial.day,
            initial.hour,
            initial.minute,
          );
    final rawEndDt = event != null
        ? tryParseStrictIsoDateTime(event.endDateTimeIso) ??
              rawStartDt.add(const Duration(hours: 1))
        : rawStartDt.add(const Duration(hours: 1));
    final startDt = event?.isAllDay == true ? rawStartDt : rawStartDt.toLocal();
    final endDt = event?.isAllDay == true ? rawEndDt : rawEndDt.toLocal();
    var displayEndDt = event?.isAllDay == true
        ? previousCalendarDate(endDt)
        : endDt;
    if (displayEndDt.isBefore(startDt)) {
      displayEndDt = startDt;
    }
    final rule = event?.recurrenceRule ?? const GeneralEventRecurrenceRule();

    _titleController = TextEditingController(text: event?.title ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');
    _notesController = TextEditingController(text: event?.notes ?? '');
    _repeatCount = rule.count;
    _startDate = normalizeDateOnly(startDt);
    _endDate = normalizeDateOnly(displayEndDt);
    _startTime = TimeOfDay(hour: startDt.hour, minute: startDt.minute);
    _endTime = TimeOfDay(hour: endDt.hour, minute: endDt.minute);
    _isAllDay = event?.isAllDay ?? false;
    _calendarId = _resolveCalendarId(event?.calendarId);
    _recurrence = rule.type;
    _customUnit = rule.unit;
    _interval = rule.normalizedInterval;
    _untilDate = rule.untilDateIso == null
        ? null
        : tryParseStrictIsoDate(rule.untilDateIso!);
    if (_untilDate?.isBefore(_startDate) ?? false) {
      _untilDate = _startDate;
    }
    _colorValue = event?.colorValue;
    _reminderBehavior =
        event?.reminderBehavior ?? GeneralEventReminderBehavior.inherit;
    _reminders =
        event?.reminders.map((item) => item.minutesBefore).toList() ?? [];
    initializeDraftGuard();
  }

  @override
  void didUpdateWidget(covariant GeneralEventEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_defaultReminderPreview.value != widget.defaultReminderMinutesBefore) {
      // The open picker is a sibling route, so notify after this build rather
      // than marking that route dirty while its owner is rebuilding.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _defaultReminderPreview.value = widget.defaultReminderMinutesBefore;
        }
      });
    }
    if (oldWidget.calendars == widget.calendars &&
        oldWidget.activeCalendarId == widget.activeCalendarId) {
      return;
    }
    _calendarOptions = _buildCalendarOptions();
    if (!_calendarOptions.any((calendar) => calendar.id == _calendarId)) {
      _calendarId = _resolveCalendarId(widget.initialEvent?.calendarId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _editorSession ??= SkedTaskSessionScope.maybeOf(context)?.session;
    if (_sectionsInitialized) return;
    final mediaQuery = MediaQuery.of(context);
    final textScale = mediaQuery.textScaler.scale(16) / 16;
    final hasDetails =
        _notesController.text.trim().isNotEmpty || _colorValue != null;
    // Keep low-frequency fields discoverable on Android portrait and with
    // accessibility text scaling; wider layouts start compact when empty.
    _detailsSectionExpanded =
        hasDetails ||
        (!WorkbenchChromeMetrics.of(context).desktop &&
            (textScale > 1.3 || mediaQuery.size.height < 560));
    _sectionsInitialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _defaultReminderPreview.dispose();
    _timeErrorReveal?.cancel();
    _timeExpansion.dispose();
    super.dispose();
  }

  List<GeneralSchedule> _buildCalendarOptions() {
    if (widget.calendars.isNotEmpty) {
      return List<GeneralSchedule>.unmodifiable(widget.calendars);
    }
    return [
      createDefaultGeneralSchedule(
        name: 'My calendar',
        colorValue: defaultGeneralCalendarColorValue,
      ),
    ];
  }

  String _resolveCalendarId(String? eventCalendarId) {
    final ids = _calendarOptions.map((item) => item.id).toSet();
    final normalizedEventCalendarId = eventCalendarId?.trim() ?? '';
    if (ids.contains(normalizedEventCalendarId)) {
      return normalizedEventCalendarId;
    }
    final active = widget.activeCalendarId;
    if (active != null && ids.contains(active)) {
      return active;
    }
    return _calendarOptions.first.id;
  }

  bool get _preserveUtc =>
      tryParseStrictIsoDateTime(widget.initialEvent?.startDateTimeIso)?.isUtc ??
      false;

  DateTime _buildDateTime(DateTime date, [TimeOfDay? time]) {
    if (time == null) {
      return _preserveUtc
          ? DateTime.utc(date.year, date.month, date.day)
          : DateTime(date.year, date.month, date.day);
    }
    final local = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return _preserveUtc ? local.toUtc() : local;
  }

  DateTime _buildStartDateTime() =>
      _buildDateTime(_startDate, _isAllDay ? null : _startTime);

  DateTime _buildEndDateTime() => _isAllDay
      ? _buildDateTime(nextCalendarDate(_endDate))
      : _buildDateTime(_endDate, _endTime);

  bool get _hasInvalidTimeRange =>
      !_buildEndDateTime().isAfter(_buildStartDateTime());

  Future<void> _save() async {
    if (_blocked) return;
    if (!_formKey.currentState!.validate()) return;
    final startDt = _buildStartDateTime();
    final endDt = _buildEndDateTime();
    if (!endDt.isAfter(startDt)) {
      _dismissActiveInputFocus();
      final expansionDuration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Theme.of(context)
                    .expansionTileTheme
                    .expansionAnimationStyle
                    ?.duration ??
                const Duration(milliseconds: 200);
      final inlineTime = WorkbenchChromeMetrics.of(context).desktop;
      if (!inlineTime) _timeExpansion.expand();
      _timeErrorReveal?.cancel();
      // Start after the first expanded frame, then measure the final transform.
      // Measuring during expansion scrolls short with accessibility text sizes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _blocked) return;
        _timeErrorReveal?.cancel();
        _timeErrorReveal = Timer(expansionDuration, () async {
          _timeErrorReveal = null;
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted ||
              _blocked ||
              !_hasInvalidTimeRange ||
              (!inlineTime && !_timeExpansion.isExpanded)) {
            return;
          }
          final errorContext = _timeErrorKey.currentContext;
          if (errorContext != null && errorContext.mounted) {
            unawaited(
              Scrollable.ensureVisible(
                errorContext,
                alignment: 1,
                duration: SkedMotionPolicy.of(context)
                    .effects(SkedMotionSpeed.fast),
              ),
            );
          }
        });
      });
      return;
    }
    final now = DateTime.now().toIso8601String();
    final rule = _buildRecurrenceRule(_repeatCount);
    final event = GeneralEvent(
      id: widget.initialEvent?.id ?? _generateId(),
      calendarId: _calendarId,
      title: _titleController.text.trim(),
      startDateTimeIso: startDt.toIso8601String(),
      endDateTimeIso: endDt.toIso8601String(),
      isAllDay: _isAllDay,
      recurrenceRule: rule,
      recurrenceExceptionDateIso:
          widget.initialEvent?.recurrenceExceptionDateIso ?? const [],
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      colorValue: _colorValue,
      reminderBehavior: _reminderBehavior,
      reminders: [
        if (_reminderBehavior == GeneralEventReminderBehavior.custom)
          for (final minutes in _reminders.toSet().toList()..sort())
            GeneralEventReminder(minutesBefore: minutes),
      ],
      createdAtIso: widget.initialEvent?.createdAtIso ?? now,
      updatedAtIso: now,
    );
    final result = GeneralEventEditorResult(event: event);
    final save = widget.onSave;
    if (save == null) {
      _popOnce(result);
      return;
    }
    _dismissActiveInputFocus();
    setState(() => _actionInProgress = true);
    final saved = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Save general event',
      command: () => save(event),
    );
    if (!mounted) return;
    if (saved) {
      _popOnce(result);
    } else {
      setState(() => _actionInProgress = false);
    }
  }

  Future<void> _delete() async {
    final event = widget.initialEvent;
    if (_blocked || event == null) return;
    final l = AppLocalizations.of(context);
    // Deletion targets the saved series, even if its recurrence was changed
    // in the unsaved draft currently shown by the editor.
    final repeating = event.recurrenceRule.isRepeating;
    _dismissActiveInputFocus();
    setState(() => _selectionDialogOpen = true);
    bool? confirmed;
    try {
      confirmed = await showExpressiveDialog<bool>(
        context: context,
        session: _editorSession,
        waitForTransitionComplete: true,
        builder: (dialogContext) => SkedConfirmationDialog(
          key: const ValueKey('editor-delete-confirmation'),
          title: Text(switch (widget.editScope) {
            GeneralEventEditScope.thisOccurrence => l.deleteThisOccurrence,
            GeneralEventEditScope.thisAndFollowing => l.deleteFutureOccurrences,
            _ => repeating ? l.deleteAllOccurrences : l.deleteEventTitle,
          }),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.deleteEventConfirmation),
              const SizedBox(height: 8),
              Text(
                event.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(dialogContext).textTheme.titleSmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => completeEditorRoute(dialogContext, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => completeEditorRoute(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              child: Text(repeating ? l.deleteAllOccurrences : l.delete),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _selectionDialogOpen = false);
    }
    if (!mounted || confirmed != true || _editorSession?.isCurrent == false) {
      return;
    }
    final result = const GeneralEventEditorResult(delete: true);
    final delete = widget.onDelete;
    if (delete == null) {
      _popOnce(result);
      return;
    }
    _dismissActiveInputFocus();
    setState(() => _actionInProgress = true);
    final deleted = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Delete general event',
      command: delete,
    );
    if (!mounted) return;
    if (deleted) {
      _popOnce(result);
    } else {
      setState(() => _actionInProgress = false);
    }
  }

  void _popOnce([GeneralEventEditorResult? result]) {
    if (!mounted || _hasPopped) return;
    setState(() => _hasPopped = true);
    completeEditorRoute(context, result);
  }

  GeneralEventRecurrenceRule _buildRecurrenceRule(int? repeatCount) {
    if (_recurrence == GeneralEventRecurrence.none) {
      return const GeneralEventRecurrenceRule();
    }
    return GeneralEventRecurrenceRule(
      type: _recurrence,
      interval: _recurrence == GeneralEventRecurrence.custom ? _interval : 1,
      unit: switch (_recurrence) {
        GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
        GeneralEventRecurrence.weekly => GeneralEventRecurrenceUnit.week,
        GeneralEventRecurrence.monthly => GeneralEventRecurrenceUnit.month,
        GeneralEventRecurrence.custom => _customUnit,
        GeneralEventRecurrence.none => _customUnit,
      },
      untilDateIso: _untilDate == null
          ? null
          : normalizeDateOnly(_untilDate!).toIso8601String().split('T').first,
      count: repeatCount == null || repeatCount < 1 ? null : repeatCount,
      monthlyAnchorDay: _retainedMonthlyAnchorDay,
    );
  }

  int? get _retainedMonthlyAnchorDay {
    final initial = widget.initialEvent;
    if (initial == null) return null;
    final originalStart = tryParseStrictIsoDateTime(initial.startDateTimeIso);
    final monthly =
        _recurrence == GeneralEventRecurrence.monthly ||
        (_recurrence == GeneralEventRecurrence.custom &&
            _customUnit == GeneralEventRecurrenceUnit.month);
    if (!monthly ||
        originalStart == null ||
        !DateUtils.isSameDay(
          initial.isAllDay ? originalStart : originalStart.toLocal(),
          _startDate,
        )) {
      return null;
    }
    return initial.recurrenceRule.monthlyAnchorDay;
  }

  String _currentReminderSummary(AppLocalizations l10n) =>
      _reminderBehavior == GeneralEventReminderBehavior.inherit
      ? l10n.courseReminderInherit(
          widget.defaultReminderMinutesBefore == null
              ? l10n.none
              : _reminderLabel(widget.defaultReminderMinutesBefore!, l10n),
        )
      : _reminderSummary(
          _reminderBehavior == GeneralEventReminderBehavior.disabled
              ? const []
              : _reminders,
          l10n,
        );

  String _generateId() => 'evt_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: _hasPopped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_blocked) unawaited(requestEditorExit());
      },
      child: Form(
        key: _formKey,
        child: AppSheetScaffold.editor(
          onClose: () => unawaited(requestEditorExit()),
          closeEnabled: !_blocked,
          busy: _actionInProgress,
          title: Text(_isEditing ? l10n.editEvent : l10n.addEvent),
          editorActions: SkedEditorActions(
            enabled: !_blocked,
            busy: _actionInProgress,
            onCancel: () => unawaited(requestEditorExit()),
            onSubmit: () => unawaited(_save()),
            showDelete: _isEditing,
            onDelete: _isEditing ? () => unawaited(_delete()) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.editScope != null) ...[
                Text(
                  generalEventEditScopeLabel(widget.editScope!, l10n),
                  key: const ValueKey('event-editor-edit-scope'),
                  style: theme.textTheme.labelLarge,
                ),
                if (widget.editScope == GeneralEventEditScope.entireSeries &&
                    widget.initialEvent?.recurrenceRule.isRepeating == true)
                  Text(
                    l10n.eventEditEntireSeriesHint,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
              ],
              FocusScope(
                canRequestFocus: !_blocked,
                child: AbsorbPointer(
                  absorbing: _actionInProgress,
                  child: _buildFields(l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFields(AppLocalizations l10n) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final options = SkedEditorFormRow(
      breakpoint: double.infinity,
      minimumChildWidths: [
        workspaceEditorMinimumFieldWidth(
          context,
          label: l10n.eventRecurrence,
          value: _currentRecurrenceSummary(l10n),
          minimumWidth: 144,
        ),
        workspaceEditorMinimumFieldWidth(
          context,
          label: l10n.reminder,
          value: _currentReminderSummary(l10n),
          minimumWidth: 160,
        ),
      ],
      children: [_buildRecurrenceField(l10n), _buildReminderField(l10n)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkedEditorTextField(
          controlKey: const ValueKey('event-desktop-title'),
          label: l10n.eventTitle,
          controller: _titleController,
          enabled: !_blocked,
          icon: Icons.title,
          headline: true,
          formField: true,
          validator: (value) => value == null || value.trim().isEmpty
              ? l10n.eventTitleRequired
              : null,
        ),
        SizedBox(height: desktop ? 12 : 8),
        SkedEditorFormRow(
          breakpoint: double.infinity,
          flexes: [1, if (_showCalendarPicker) 0],
          minimumChildWidths: [
            workspaceEditorMinimumFieldWidth(
              context,
              label: l10n.place,
              minimumWidth: 180,
            ),
            if (_showCalendarPicker)
              workspaceEditorMinimumFieldWidth(
                context,
                label: l10n.calendar,
                value: _calendarOptions
                    .firstWhere((calendar) => calendar.id == _calendarId)
                    .name,
                valuePadding: 74,
                minimumWidth: 144,
              ),
          ],
          children: [
            SkedEditorTextField(
              controlKey: const ValueKey('event-desktop-location'),
              label: l10n.place,
              controller: _locationController,
              enabled: !_blocked,
              icon: Icons.location_on_outlined,
              formField: true,
            ),
            if (_showCalendarPicker) _buildCalendarField(l10n),
          ],
        ),
        SizedBox(height: desktop ? 16 : 8),
        if (desktop)
          _buildTimeRange(l10n)
        else
          WorkspaceEditorDisclosure(
            controller: _timeExpansion,
            icon: Icons.schedule_outlined,
            title: '${l10n.eventDate} · ${l10n.eventTime}',
            initiallyExpanded: _timeSectionExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _timeSectionExpanded = expanded),
            enabled: !_blocked,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_buildAllDayField(l10n), _buildTimeRange(l10n)],
            ),
          ),
        SizedBox(height: desktop ? 16 : 8),
        if (desktop)
          options
        else
          WorkspaceEditorDisclosure(
            icon: Icons.tune_outlined,
            title: '${l10n.eventRecurrence} · ${l10n.reminder}',
            initiallyExpanded: _optionsSectionExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _optionsSectionExpanded = expanded),
            enabled: !_blocked,
            child: options,
          ),
        SizedBox(height: desktop ? 16 : 8),
        WorkspaceEditorDisclosure(
          compact: desktop,
          icon: Icons.more_horiz,
          title: desktop
              ? l10n.more
              : '${l10n.eventNotes} · ${l10n.eventColor}',
          initiallyExpanded: _detailsSectionExpanded,
          onExpansionChanged: (expanded) =>
              setState(() => _detailsSectionExpanded = expanded),
          enabled: !_blocked,
          child: _buildDetailsFields(l10n),
        ),
      ],
    );
  }

  Widget _buildTimeRange(AppLocalizations l10n) => _DateTimeRange(
    allDay: _buildAllDayField(l10n),
    start: _DateTimeRow(
      icon: Icons.play_arrow_outlined,
      label: l10n.eventStartTime,
      date: _startDate,
      time: _startTime,
      showTime: !_isAllDay,
      onPickDate: (_pickerOpen || _hasPopped)
          ? null
          : (anchorContext) async {
              final picked = await _runPicker(
                () => _pickDate(
                  context,
                  _startDate,
                  anchorContext: anchorContext,
                ),
              );
              if (!mounted || picked == null) {
                return;
              }
              setState(() {
                _startDate = picked;
                if (_endDate.isBefore(_startDate)) {
                  _endDate = _startDate;
                }
                if (_untilDate?.isBefore(_startDate) ?? false) {
                  _untilDate = _startDate;
                }
              });
            },
      onPickTime: (_pickerOpen || _hasPopped)
          ? null
          : (anchorContext) async {
              final picked = await _runPicker(
                () => _pickTime(context, _startTime, anchorContext),
              );
              if (!mounted || picked == null) {
                return;
              }
              setState(() => _startTime = picked);
            },
    ),
    end: _DateTimeRow(
      errorKey: _timeErrorKey,
      errorText: _hasInvalidTimeRange ? l10n.endTimeMustBeLater : null,
      icon: Icons.stop_outlined,
      label: l10n.eventEndTime,
      date: _endDate,
      time: _endTime,
      showTime: !_isAllDay,
      onPickDate: (_pickerOpen || _hasPopped)
          ? null
          : (anchorContext) async {
              final picked = await _runPicker(
                () =>
                    _pickDate(context, _endDate, anchorContext: anchorContext),
              );
              if (!mounted || picked == null) {
                return;
              }
              setState(() => _endDate = picked);
            },
      onPickTime: (_pickerOpen || _hasPopped)
          ? null
          : (anchorContext) async {
              final picked = await _runPicker(
                () => _pickTime(context, _endTime, anchorContext),
              );
              if (!mounted || picked == null) {
                return;
              }
              setState(() => _endTime = picked);
            },
    ),
  );

  String _currentRecurrenceSummary(AppLocalizations l10n) => _recurrenceSummary(
    recurrence: _recurrence,
    interval: _interval,
    unit: _customUnit,
    untilDate: _untilDate,
    repeatCount: _repeatCount,
    l10n: l10n,
  );

  Widget _buildRecurrenceField(AppLocalizations l10n) => SkedEditorValueField(
    key: const ValueKey('event-recurrence-field'),
    icon: Icons.repeat,
    label: l10n.eventRecurrence,
    value: _currentRecurrenceSummary(l10n),
    onPressed:
        _blocked || widget.editScope == GeneralEventEditScope.thisOccurrence
        ? null
        : (anchor) => unawaited(_openRecurrenceDialog(anchor)),
  );

  Widget _buildReminderField(AppLocalizations l10n) => SkedEditorValueField(
    key: const ValueKey('event-reminder-field'),
    icon: Icons.notifications_outlined,
    label: l10n.reminder,
    value: _currentReminderSummary(l10n),
    onPressed: _blocked
        ? null
        : (anchor) => unawaited(_openReminderDialog(anchor)),
  );

  Widget _buildAllDayField(AppLocalizations l10n) => SkedEditorSwitchField(
    icon: Icons.event_available_outlined,
    label: l10n.allDay,
    value: _isAllDay,
    onChanged: _blocked
        ? null
        : (value) => setState(() {
            _isAllDay = value;
            if (value && _endDate.isBefore(_startDate)) {
              _endDate = _startDate;
            }
          }),
  );

  Widget _buildCalendarField(AppLocalizations l10n) =>
      SkedEditorChoiceField<String>(
        label: l10n.calendar,
        icon: Icons.calendar_month_outlined,
        enabled: !_blocked,
        initialSelection: _calendarId,
        entries: [
          for (final calendar in _calendarOptions)
            DropdownMenuEntry(
              value: calendar.id,
              label: calendar.isVisible
                  ? calendar.name
                  : '${calendar.name} · ${l10n.categoryHidden}',
              labelWidget: _CalendarDropdownItem(calendar: calendar),
            ),
        ],
        onSelected: (value) {
          if (value != null) setState(() => _calendarId = value);
        },
      );
  Widget _buildDetailsFields(AppLocalizations l10n) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final palette = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final colorValue in _colorOptions)
          _ColorOption(
            colorValue: colorValue,
            selected: _colorValue == colorValue,
            onTap: () => setState(() {
              _colorValue = _colorValue == colorValue ? null : colorValue;
            }),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkedEditorTextField(
          label: l10n.eventNotes,
          controller: _notesController,
          enabled: !_blocked,
          icon: Icons.notes_outlined,
          formField: true,
          minLines: 2,
          maxLines: 4,
        ),
        SizedBox(height: desktop ? 12 : 8),
        if (desktop)
          WorkspaceEditorField(label: l10n.eventColor, child: palette)
        else ...[
          Text(l10n.eventColor, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          palette,
        ],
      ],
    );
  }

  Future<void> _openRecurrenceDialog(BuildContext anchorContext) async {
    if (_blocked) return;
    final sourceId = widget.initialEvent?.id;
    final sourceCalendar = _calendarId;
    bool sessionCurrent() =>
        mounted &&
        !_hasPopped &&
        widget.initialEvent?.id == sourceId &&
        _calendarId == sourceCalendar;
    setState(() => _selectionDialogOpen = true);
    _dismissActiveInputFocus();
    _RecurrenceDialogValue? result;
    try {
      result = await showSkedAdaptivePickerDialog<_RecurrenceDialogValue>(
        context: context,
        routeName: 'general-recurrence-picker',
        anchorContext: anchorContext,
        placement: SkedFloatingPlacement.left,
        preferredWidth: 360,
        workspace: AppMode.general,
        isSessionCurrent: sessionCurrent,
        waitForTransitionComplete: true,
        builder: (_) => _RecurrencePickerDialog(
          initialValue: _RecurrenceDialogValue(
            recurrence: _recurrence,
            interval: _interval,
            unit: _customUnit,
            untilDate: _untilDate,
            repeatCount: _repeatCount,
          ),
          firstDate: _startDate,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _selectionDialogOpen = false);
      } else {
        _selectionDialogOpen = false;
      }
    }
    if (!sessionCurrent()) return;
    final selected = result;
    if (selected == null) return;
    setState(() {
      _recurrence = selected.recurrence;
      _interval = selected.interval;
      _customUnit = selected.unit;
      _untilDate = selected.untilDate;
      _repeatCount = selected.repeatCount;
    });
  }

  Future<void> _openReminderDialog(BuildContext anchorContext) async {
    if (_blocked) return;
    final sourceId = widget.initialEvent?.id;
    final sourceCalendar = _calendarId;
    bool sessionCurrent() =>
        mounted &&
        !_hasPopped &&
        widget.initialEvent?.id == sourceId &&
        _calendarId == sourceCalendar;
    setState(() => _selectionDialogOpen = true);
    _dismissActiveInputFocus();
    _ReminderDialogValue? result;
    try {
      result = await showSkedAdaptivePickerDialog<_ReminderDialogValue>(
        context: context,
        routeName: 'general-reminder-picker',
        anchorContext: anchorContext,
        placement: SkedFloatingPlacement.left,
        preferredWidth: 320,
        workspace: AppMode.general,
        isSessionCurrent: sessionCurrent,
        waitForTransitionComplete: true,
        builder: (_) => ValueListenableBuilder<int?>(
          valueListenable: _defaultReminderPreview,
          builder: (_, currentDefault, _) => _ReminderPickerDialog(
            initialReminders: _reminders,
            initialBehavior: _reminderBehavior,
            defaultMinutesBefore: currentDefault,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _selectionDialogOpen = false);
      } else {
        _selectionDialogOpen = false;
      }
    }
    if (!sessionCurrent() || result == null) return;
    setState(() {
      _reminders = result!.reminders;
      _reminderBehavior = result.behavior;
    });
  }

  Future<T?> _runPicker<T>(Future<T?> Function() picker) async {
    if (_blocked) {
      return null;
    }
    setState(() => _pickerOpen = true);
    _dismissActiveInputFocus();
    try {
      return await picker();
    } finally {
      if (mounted) {
        setState(() => _pickerOpen = false);
      } else {
        _pickerOpen = false;
      }
    }
  }
}

/// Desktop option cells use measured text widths, a single selection surface,
/// and one keyboard/semantics target. This is not the touch dialog list.
class _DesktopEventChoice extends StatelessWidget {
  const _DesktopEventChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      SkedEditorOption(label: label, selected: selected, onPressed: onPressed);
}

class _DesktopEventChoiceGrid extends StatelessWidget {
  const _DesktopEventChoiceGrid({
    required this.maxColumns,
    required this.choices,
  });
  final int maxColumns;
  final List<_DesktopEventChoice> choices;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = WorkbenchChromeMetrics.of(context);
      var minimumWidth = 80.0;
      for (final choice in choices) {
        final painter = TextPainter(
          text: TextSpan(
            text: choice.label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width =
            painter.width + 38; // padding, gap and the stable check slot
        if (width > minimumWidth) minimumWidth = width;
        painter.dispose();
      }
      const gap = 4.0;
      final columns = metrics.textScale > 1.3 || constraints.maxWidth < 280
          ? 1
          : ((constraints.maxWidth + gap) / (minimumWidth + gap)).floor().clamp(
              1,
              maxColumns,
            );
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return FocusTraversalGroup(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final choice in choices) SizedBox(width: width, child: choice),
          ],
        ),
      );
    },
  );
}

class _RecurrenceDialogValue {
  const _RecurrenceDialogValue({
    required this.recurrence,
    required this.interval,
    required this.unit,
    required this.untilDate,
    required this.repeatCount,
  });

  final GeneralEventRecurrence recurrence;
  final int interval;
  final GeneralEventRecurrenceUnit unit;
  final DateTime? untilDate;
  final int? repeatCount;
}

class _RecurrencePickerDialog extends StatefulWidget {
  const _RecurrencePickerDialog({
    required this.initialValue,
    required this.firstDate,
  });

  final _RecurrenceDialogValue initialValue;
  final DateTime firstDate;

  @override
  State<_RecurrencePickerDialog> createState() =>
      _RecurrencePickerDialogState();
}

class _RecurrencePickerDialogState extends State<_RecurrencePickerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _intervalController;
  late final TextEditingController _repeatCountController;
  late GeneralEventRecurrence _recurrence;
  late int _interval;
  late GeneralEventRecurrenceUnit _unit;
  DateTime? _untilDate;
  bool _pickerOpen = false;
  bool _hasPopped = false;

  bool get _blocked => _pickerOpen || _hasPopped;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _recurrence = initial.recurrence;
    _interval = initial.interval
        .clamp(_minimumRecurrenceInterval, _maximumRecurrenceInterval)
        .toInt();
    _unit = initial.unit;
    _untilDate = initial.untilDate;
    _intervalController = TextEditingController(text: '$_interval');
    _repeatCountController = TextEditingController(
      text: initial.repeatCount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _repeatCountController.dispose();
    super.dispose();
  }

  Widget _desktopPanel(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_blocked,
      child: SkedTaskDialog(
        key: const ValueKey('general-recurrence-panel'),
        title: Text(l.eventRecurrence),
        closeEnabled: !_blocked,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            key: const ValueKey('general-recurrence-body'),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DesktopEventChoiceGrid(
                    maxColumns: 3,
                    choices: [
                      for (final option in GeneralEventRecurrence.values)
                        _DesktopEventChoice(
                          key: ValueKey(
                            'general-recurrence-choice-${option.name}',
                          ),
                          label: _recurrenceOptionLabel(option, l),
                          selected: _recurrence == option,
                          onPressed: _blocked
                              ? null
                              : () => setState(() => _recurrence = option),
                        ),
                    ],
                  ),
                  if (_recurrence != GeneralEventRecurrence.none) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ExcludeFocus(
                      excluding: _blocked,
                      child: AbsorbPointer(
                        absorbing: _blocked,
                        child: _RepeatOptions(
                          recurrence: _recurrence,
                          interval: _interval,
                          intervalController: _intervalController,
                          customUnit: _unit,
                          untilDate: _untilDate,
                          repeatCountController: _repeatCountController,
                          onIntervalChanged: (value) =>
                              setState(() => _interval = value),
                          onUnitChanged: (value) =>
                              setState(() => _unit = value),
                          onPickUntil: _blocked ? null : _pickUntilDate,
                          onClearUntil: () {
                            if (!_blocked) setState(() => _untilDate = null);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('general-recurrence-cancel'),
            onPressed: _blocked ? null : () => _popOnce(),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('general-recurrence-confirm'),
            onPressed: _blocked ? null : _submit,
            child: Text(l.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (SkedTaskDialogScope.maybeOf(context) != null) {
      return _desktopPanel(context);
    }
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final contentMaxHeight = _eventDialogContentMaxHeight(mediaQuery);
    return PopScope(
      // Keep the recurrence draft modal in place while its date picker is
      // open. A barrier/back dismissal at that point would otherwise leave
      // the nested picker with a stale parent route.
      canPop: !_blocked,
      child: SkedConfirmationDialog(
        scrollable: true,
        // A bounded width lets the scrollable title/body lay out responsive
        // options without asking their LayoutBuilders for intrinsic sizes.
        constraints: const BoxConstraints(
          minWidth: expressiveDialogMaxWidth,
          maxWidth: expressiveDialogMaxWidth,
        ),
        insetPadding: _eventDialogInsetPadding(mediaQuery.size.width),
        title: Text(l10n.eventRecurrence),
        contentPadding: EdgeInsetsDirectional.fromSTEB(
          mediaQuery.size.width < 480 ? 16 : 24,
          12,
          mediaQuery.size.width < 480 ? 16 : 24,
          0,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: contentMaxHeight),
          child: SizedBox(
            width: expressiveDialogMaxWidth,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final option in GeneralEventRecurrence.values) ...[
                      ExpressiveDialogOption(
                        title: Text(_recurrenceOptionLabel(option, l10n)),
                        selected: _recurrence == option,
                        enabled: !_blocked,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onTap: () => setState(() => _recurrence = option),
                      ),
                      if (option != GeneralEventRecurrence.values.last)
                        const SizedBox(height: 4),
                    ],
                    if (_recurrence != GeneralEventRecurrence.none) ...[
                      const SizedBox(height: 12),
                      Divider(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      _RepeatOptions(
                        recurrence: _recurrence,
                        interval: _interval,
                        intervalController: _intervalController,
                        customUnit: _unit,
                        untilDate: _untilDate,
                        repeatCountController: _repeatCountController,
                        onIntervalChanged: (value) =>
                            setState(() => _interval = value),
                        onUnitChanged: (value) => setState(() => _unit = value),
                        onPickUntil: _blocked ? null : _pickUntilDate,
                        onClearUntil: () => setState(() => _untilDate = null),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _blocked ? null : () => _popOnce(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _blocked ? null : _submit,
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _pickUntilDate(BuildContext anchorContext) async {
    if (_blocked) return;
    setState(() => _pickerOpen = true);
    _dismissActiveInputFocus();
    try {
      final picked = await _pickDate(
        context,
        _untilDate ?? addCalendarDays(widget.firstDate, 90),
        firstDate: widget.firstDate,
        anchorContext: anchorContext,
      );
      if (mounted && picked != null) {
        setState(() => _untilDate = picked);
      }
    } finally {
      if (mounted) {
        setState(() => _pickerOpen = false);
      } else {
        _pickerOpen = false;
      }
    }
  }

  void _submit() {
    if (_blocked) return;
    if (_recurrence != GeneralEventRecurrence.none &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final countText = _repeatCountController.text.trim();
    _popOnce(
      _RecurrenceDialogValue(
        recurrence: _recurrence,
        interval: _interval,
        unit: _unit,
        untilDate: _untilDate,
        repeatCount: countText.isEmpty ? null : int.tryParse(countText),
      ),
    );
  }

  void _popOnce([_RecurrenceDialogValue? value]) {
    if (_blocked) return;
    setState(() => _hasPopped = true);
    Navigator.of(context).pop(value);
  }
}

class _ReminderDialogValue {
  const _ReminderDialogValue(this.behavior, this.reminders);
  final GeneralEventReminderBehavior behavior;
  final List<int> reminders;
}

class _ReminderPickerDialog extends StatefulWidget {
  const _ReminderPickerDialog({
    required this.initialReminders,
    required this.initialBehavior,
    this.defaultMinutesBefore,
  });
  final List<int> initialReminders;
  final GeneralEventReminderBehavior initialBehavior;
  final int? defaultMinutesBefore;
  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  late Set<int> _reminders;
  late GeneralEventReminderBehavior _behavior;
  bool _hasPopped = false;
  @override
  void initState() {
    super.initState();
    _reminders = widget.initialReminders.toSet();
    _behavior = widget.initialBehavior;
  }

  void _selectBehavior(GeneralEventReminderBehavior value) => setState(() {
    _behavior = value;
    if (value == GeneralEventReminderBehavior.custom && _reminders.isEmpty) {
      _reminders.add(widget.defaultMinutesBefore ?? 0);
    }
  });

  void _toggle(int minutes) => setState(() {
    if (!_reminders.add(minutes)) _reminders.remove(minutes);
    _behavior = _reminders.isEmpty
        ? GeneralEventReminderBehavior.disabled
        : GeneralEventReminderBehavior.custom;
  });

  Widget _body(BuildContext context, bool desktop) {
    final l = AppLocalizations.of(context);
    final options = {
      ..._reminderOptions,
      ...widget.initialReminders,
      ..._reminders,
    }.toList()..sort();
    final modes = [
      (
        GeneralEventReminderBehavior.inherit,
        'inherit',
        l.courseReminderInherit(
          widget.defaultMinutesBefore == null
              ? l.none
              : _reminderLabel(widget.defaultMinutesBefore!, l),
        ),
      ),
      (GeneralEventReminderBehavior.disabled, 'none', l.none),
      (GeneralEventReminderBehavior.custom, 'custom', l.generalReminderCustom),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final mode in modes)
          SkedEditorOption(
            key: ValueKey('general-reminder-${mode.$2}'),
            label: mode.$3,
            selected: _behavior == mode.$1,
            onPressed: _hasPopped ? null : () => _selectBehavior(mode.$1),
          ),
        if (_behavior == GeneralEventReminderBehavior.custom) ...[
          const SizedBox(height: 8),
          if (desktop)
            _DesktopEventChoiceGrid(
              maxColumns: 2,
              choices: [
                for (final minutes in options)
                  _DesktopEventChoice(
                    key: ValueKey('general-reminder-choice-$minutes'),
                    label: _reminderLabel(minutes, l),
                    selected: _reminders.contains(minutes),
                    onPressed: _hasPopped ? null : () => _toggle(minutes),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in options)
                  FilterChip(
                    key: ValueKey('general-reminder-choice-$minutes'),
                    label: Text(_reminderLabel(minutes, l)),
                    selected: _reminders.contains(minutes),
                    onSelected: _hasPopped ? null : (_) => _toggle(minutes),
                  ),
              ],
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final desktop = SkedTaskDialogScope.maybeOf(context) != null;
    final actions = [
      TextButton(
        key: const ValueKey('general-reminder-cancel'),
        onPressed: _hasPopped ? null : () => _popOnce(),
        child: Text(l.cancel),
      ),
      FilledButton(
        key: const ValueKey('general-reminder-confirm'),
        onPressed: _hasPopped
            ? null
            : () => _popOnce(
                _ReminderDialogValue(
                  _behavior,
                  _behavior == GeneralEventReminderBehavior.custom
                      ? (_reminders.toList()..sort())
                      : const [],
                ),
              ),
        child: Text(l.confirm),
      ),
    ];
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        key: const ValueKey('general-reminder-body'),
        child: _body(context, desktop),
      ),
    );
    return PopScope(
      canPop: !_hasPopped,
      child: desktop
          ? SkedTaskDialog(
              key: const ValueKey('general-reminder-panel'),
              title: Text(l.reminder),
              closeEnabled: !_hasPopped,
              content: content,
              actions: actions,
            )
          : SkedConfirmationDialog(
              title: Text(l.reminder),
              scrollable: true,
              constraints: const BoxConstraints(
                minWidth: expressiveDialogMaxWidth,
                maxWidth: expressiveDialogMaxWidth,
              ),
              insetPadding: _eventDialogInsetPadding(
                MediaQuery.sizeOf(context).width,
              ),
              content: SizedBox(
                width: expressiveDialogMaxWidth,
                child: content,
              ),
              actions: actions,
            ),
    );
  }

  void _popOnce([_ReminderDialogValue? value]) {
    if (_hasPopped) return;
    setState(() => _hasPopped = true);
    Navigator.of(context).pop(value);
  }
}

EdgeInsets _eventDialogInsetPadding(double width) =>
    EdgeInsets.symmetric(horizontal: width < 480 ? 16 : 40, vertical: 24);

double _eventDialogContentMaxHeight(MediaQueryData mediaQuery) {
  final available =
      mediaQuery.size.height -
      mediaQuery.viewInsets.bottom -
      mediaQuery.viewPadding.vertical -
      180;
  return available.clamp(180.0, 640.0).toDouble();
}

class _DateTimeRange extends StatelessWidget {
  const _DateTimeRange({
    required this.start,
    required this.end,
    required this.allDay,
  });

  final _DateTimeRow start, end;
  final Widget allDay;

  @override
  Widget build(BuildContext context) {
    if (WorkbenchChromeMetrics.of(context).desktop) {
      final theme = Theme.of(context);
      Widget label(String text) =>
          Text(text, style: workspaceEditorLabelStyle(context));
      return WorkspaceEditorTimeRows(
        showTime: start.showTime,
        textDirection: Directionality.of(context),
        minimumDateWidth: 136 * MediaQuery.textScalerOf(context).scale(14) / 14,
        minimumTimeWidth: 104 * MediaQuery.textScalerOf(context).scale(14) / 14,
        startLabel: label(start.label),
        endLabel: label(end.label),
        startDate: start.dateControl(context),
        startTime: start.timeControl(context),
        endDate: end.dateControl(context),
        endTime: end.timeControl(context),
        allDay: allDay,
        error: end.errorText == null
            ? null
            : Semantics(
                key: end.errorKey,
                liveRegion: true,
                child: Text(
                  end.errorText!,
                  key: const ValueKey('event-time-range-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            start,
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 68, end: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: colors.outlineVariant,
              ),
            ),
            end,
          ],
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    this.errorKey,
    this.errorText,
    required this.icon,
    required this.label,
    required this.date,
    required this.time,
    required this.showTime,
    required this.onPickDate,
    required this.onPickTime,
  });

  final IconData icon;
  final String label;
  final DateTime date;
  final TimeOfDay time;
  final bool showTime;
  final String? errorText;
  final Key? errorKey;
  final ValueChanged<BuildContext>? onPickDate;
  final ValueChanged<BuildContext>? onPickTime;

  Widget dateControl(BuildContext context) => SkedEditorValueAction(
    label: '$label · ${AppLocalizations.of(context).pickDate}',
    tooltip: AppLocalizations.of(context).pickDate,
    value: _fmtDate(date),
    icon: Icons.calendar_today_outlined,
    iconOnlyOnTouch: true,
    onPressed: onPickDate,
  );

  Widget timeControl(BuildContext context) => SkedEditorValueAction(
    label: '$label · ${AppLocalizations.of(context).pickTime}',
    tooltip: AppLocalizations.of(context).pickTime,
    value: time.format(context),
    icon: Icons.access_time,
    iconOnlyOnTouch: true,
    onPressed: onPickTime,
  );
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final value = showTime
        ? '${_fmtDate(date)} ${time.format(context)}'
        : _fmtDate(date);
    final actionButtons = [
      dateControl(context),
      if (showTime) timeControl(context),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leading = SkedEditorSelectionIcon(icon: icon);
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                softWrap: true,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                softWrap: true,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: errorText == null
                      ? colors.onSurfaceVariant
                      : colors.error,
                ),
              ),
              if (errorText != null)
                Padding(
                  key: errorKey,
                  padding: const EdgeInsets.only(top: 4),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      errorText!,
                      key: const ValueKey('event-time-range-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                ),
            ],
          );
          final actions = Wrap(
            spacing: 2,
            runSpacing: 2,
            children: actionButtons,
          );

          final bodyFontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;
          final usesLargeText =
              MediaQuery.textScalerOf(context).scale(bodyFontSize) >
              bodyFontSize * 1.3;
          if (actionButtons.length > 1 &&
              (constraints.maxWidth < 280 || usesLargeText)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: text),
              const SizedBox(width: 8),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _RepeatOptions extends StatelessWidget {
  const _RepeatOptions({
    required this.recurrence,
    required this.interval,
    required this.intervalController,
    required this.customUnit,
    required this.untilDate,
    required this.repeatCountController,
    required this.onIntervalChanged,
    required this.onUnitChanged,
    required this.onPickUntil,
    required this.onClearUntil,
  });

  final GeneralEventRecurrence recurrence;
  final int interval;
  final TextEditingController intervalController;
  final GeneralEventRecurrenceUnit customUnit;
  final DateTime? untilDate;
  final TextEditingController repeatCountController;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<GeneralEventRecurrenceUnit> onUnitChanged;
  final ValueChanged<BuildContext>? onPickUntil;
  final VoidCallback onClearUntil;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final endDateButton = Row(
      children: [
        Expanded(
          child: SkedEditorValueField(
            label: l10n.recurrenceEndDate,
            value: untilDate == null
                ? l10n.recurrenceNoLimit
                : _fmtDate(untilDate!),
            icon: Icons.event_repeat_outlined,
            onPressed: onPickUntil,
          ),
        ),
        if (untilDate != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.clearEndDate,
            onPressed: onClearUntil,
            icon: const Icon(Icons.clear),
          ),
        ],
      ],
    );
    return Column(
      children: [
        if (recurrence == GeneralEventRecurrence.custom)
          ResponsiveEditorFormRow(
            spacing: 8,
            breakpoint:
                desktop && WorkbenchChromeMetrics.of(context).textScale <= 1.3
                ? 320
                : 420,
            children: [
              _RecurrenceIntervalStepper(
                value: interval,
                controller: intervalController,
                unit: customUnit,
                onChanged: onIntervalChanged,
              ),
              SkedEditorChoiceField<GeneralEventRecurrenceUnit>(
                initialSelection: customUnit,
                label: l10n.recurrenceUnit,
                workspace: AppMode.general,
                entries: [
                  DropdownMenuEntry(
                    value: GeneralEventRecurrenceUnit.day,
                    label: l10n.recurrenceDays,
                  ),
                  DropdownMenuEntry(
                    value: GeneralEventRecurrenceUnit.week,
                    label: l10n.recurrenceWeeks,
                  ),
                  DropdownMenuEntry(
                    value: GeneralEventRecurrenceUnit.month,
                    label: l10n.recurrenceMonths,
                  ),
                ],
                onSelected: (value) {
                  if (value != null) onUnitChanged(value);
                },
              ),
            ],
          ),
        if (recurrence == GeneralEventRecurrence.custom)
          const SizedBox(height: 8),
        ResponsiveEditorFormRow(
          spacing: 8,
          breakpoint: 420,
          children: [
            SkedEditorTextField(
              controller: repeatCountController,
              keyboardType: TextInputType.number,
              label: l10n.recurrenceRepeatCount,
              hintText: l10n.recurrenceNoLimit,
              icon: Icons.numbers,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final parsed = int.tryParse(text);
                if (parsed == null || parsed < 1) {
                  return l10n.recurrencePositiveNumber;
                }
                return null;
              },
            ),
            endDateButton,
          ],
        ),
      ],
    );
  }
}

const int _minimumRecurrenceInterval = 1;
const int _maximumRecurrenceInterval = 999;

class _RecurrenceIntervalStepper extends StatefulWidget {
  const _RecurrenceIntervalStepper({
    required this.value,
    required this.controller,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final TextEditingController controller;
  final GeneralEventRecurrenceUnit unit;
  final ValueChanged<int> onChanged;

  @override
  State<_RecurrenceIntervalStepper> createState() =>
      _RecurrenceIntervalStepperState();
}

class _RecurrenceIntervalStepperState
    extends State<_RecurrenceIntervalStepper> {
  late final FocusNode _valueFocusNode;

  int get _value => widget.value
      .clamp(_minimumRecurrenceInterval, _maximumRecurrenceInterval)
      .toInt();

  int? get _enteredValue {
    final parsed = int.tryParse(widget.controller.text);
    if (parsed == null ||
        parsed < _minimumRecurrenceInterval ||
        parsed > _maximumRecurrenceInterval) {
      return null;
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    _valueFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _valueFocusNode.dispose();
    super.dispose();
  }

  void _setValue(int value, FormFieldState<int> field) {
    final next = value
        .clamp(_minimumRecurrenceInterval, _maximumRecurrenceInterval)
        .toInt();
    final text = '$next';
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    field.didChange(next);
    widget.onChanged(next);
  }

  void _handleTextChanged(String text, FormFieldState<int> field) {
    final parsed = int.tryParse(text);
    final valid =
        parsed != null &&
        parsed >= _minimumRecurrenceInterval &&
        parsed <= _maximumRecurrenceInterval;
    field.didChange(valid ? parsed : null);
    if (valid) widget.onChanged(parsed);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unitLabel = _recurrenceUnitLabel(widget.unit, l10n);
    final value = _value;

    String destinationLabel(int destination) =>
        l10n.repeatsEvery(destination, unitLabel);

    final actionStyle = WorkbenchChromeMetrics.of(context).iconStyle;

    return FormField<int>(
      key: const ValueKey('recurrence-interval-stepper'),
      initialValue: _enteredValue,
      validator: (current) =>
          current == null ? l10n.recurrencePositiveNumber : null,
      builder: (field) => SkedEditorTextField(
        controlKey: const ValueKey('recurrence-interval-value'),
        label: l10n.recurrenceEvery,
        controller: widget.controller,
        focusNode: _valueFocusNode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        textAlign: TextAlign.center,
        errorText: field.errorText,
        prefixIcon: IconButton(
          key: const ValueKey('recurrence-interval-decrement'),
          tooltip: destinationLabel(
            value > _minimumRecurrenceInterval
                ? value - 1
                : _minimumRecurrenceInterval,
          ),
          onPressed: value > _minimumRecurrenceInterval
              ? () => _setValue(value - 1, field)
              : null,
          style: actionStyle,
          icon: const Icon(Icons.remove),
        ),
        suffixIcon: IconButton(
          key: const ValueKey('recurrence-interval-increment'),
          tooltip: destinationLabel(
            value < _maximumRecurrenceInterval
                ? value + 1
                : _maximumRecurrenceInterval,
          ),
          onPressed: value < _maximumRecurrenceInterval
              ? () => _setValue(value + 1, field)
              : null,
          style: actionStyle,
          icon: const Icon(Icons.add),
        ),
        onChanged: (text) => _handleTextChanged(text, field),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SkedTooltip(
      message: '#${colorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    width: selected ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDropdownItem extends StatelessWidget {
  const _CalendarDropdownItem({required this.calendar});

  final GeneralSchedule calendar;

  @override
  Widget build(BuildContext context) {
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(calendar.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (!calendar.isVisible)
          Text(
            AppLocalizations.of(context).categoryHidden,
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorDot(color: effectiveGeneralCalendarColor(context, calendar)),
        const SizedBox(width: 8),
        if (WorkbenchChromeMetrics.of(context).desktop)
          Flexible(child: label)
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: label,
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Future<DateTime?> _pickDate(
  BuildContext context,
  DateTime initialDate, {
  DateTime? firstDate,
  BuildContext? anchorContext,
}) {
  final supportedFirstDate = DateTime(1970);
  final lastDate = DateTime(2100);
  final boundedFirstDate =
      firstDate == null || firstDate.isBefore(supportedFirstDate)
      ? supportedFirstDate
      : firstDate.isAfter(lastDate)
      ? lastDate
      : firstDate;
  final boundedInitialDate = initialDate.isBefore(boundedFirstDate)
      ? boundedFirstDate
      : initialDate.isAfter(lastDate)
      ? lastDate
      : initialDate;
  return showSkedDatePicker(
    context: context,
    workspace: AppMode.general,
    anchorContext: anchorContext,
    initialDate: boundedInitialDate,
    firstDate: boundedFirstDate,
    lastDate: lastDate,
  );
}

Future<TimeOfDay?> _pickTime(
  BuildContext context,
  TimeOfDay initialTime,
  BuildContext anchorContext,
) {
  return showSkedTimePicker(
    context: context,
    initialTime: initialTime,
    anchorContext: anchorContext,
    workspace: AppMode.general,
  );
}

void _dismissActiveInputFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
}

String _fmtDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _recurrenceOptionLabel(
  GeneralEventRecurrence recurrence,
  AppLocalizations l10n,
) {
  return switch (recurrence) {
    GeneralEventRecurrence.none => l10n.recurrenceNone,
    GeneralEventRecurrence.daily => l10n.recurrenceDaily,
    GeneralEventRecurrence.weekly => l10n.recurrenceWeekly,
    GeneralEventRecurrence.monthly => l10n.recurrenceMonthly,
    GeneralEventRecurrence.custom => l10n.recurrenceCustom,
  };
}

String _recurrenceSummary({
  required GeneralEventRecurrence recurrence,
  required int interval,
  required GeneralEventRecurrenceUnit unit,
  required DateTime? untilDate,
  required int? repeatCount,
  required AppLocalizations l10n,
}) {
  if (recurrence == GeneralEventRecurrence.none) {
    return l10n.recurrenceNone;
  }
  final base = switch (recurrence) {
    GeneralEventRecurrence.daily => l10n.repeatsDaily,
    GeneralEventRecurrence.weekly => l10n.repeatsWeekly,
    GeneralEventRecurrence.monthly => l10n.repeatsMonthly,
    GeneralEventRecurrence.custom => l10n.repeatsEvery(
      interval
          .clamp(_minimumRecurrenceInterval, _maximumRecurrenceInterval)
          .toInt(),
      _recurrenceUnitLabel(unit, l10n),
    ),
    GeneralEventRecurrence.none => l10n.recurrenceNone,
  };
  final suffix = [
    if (untilDate != null) l10n.recurrenceUntil(_fmtDate(untilDate)),
    if (repeatCount != null && repeatCount > 0)
      l10n.recurrenceCountTimes(repeatCount),
  ].join(', ');
  return suffix.isEmpty ? base : '$base, $suffix';
}

String _recurrenceUnitLabel(
  GeneralEventRecurrenceUnit unit,
  AppLocalizations l10n,
) {
  return switch (unit) {
    GeneralEventRecurrenceUnit.day => l10n.recurrenceDays,
    GeneralEventRecurrenceUnit.week => l10n.recurrenceWeeks,
    GeneralEventRecurrenceUnit.month => l10n.recurrenceMonths,
  };
}

String _reminderSummary(List<int> reminders, AppLocalizations l10n) {
  if (reminders.isEmpty) return l10n.none;
  final sorted = reminders.toSet().toList()..sort();
  return sorted.map((minutes) => _reminderLabel(minutes, l10n)).join(', ');
}

String _reminderLabel(int minutes, AppLocalizations l10n) {
  return switch (minutes) {
    0 => l10n.reminderAtStart,
    60 => l10n.reminderHourBefore,
    1440 => l10n.reminderDayBefore,
    _ => l10n.reminderMinutesBefore(minutes),
  };
}

const _reminderOptions = [0, 5, 10, 30, 60, 1440];

const _colorOptions = <int>[
  0xFFE57373,
  0xFFF06292,
  0xFFBA68C8,
  0xFF9575CD,
  0xFF7986CB,
  0xFF64B5F6,
  0xFF4FC3F7,
  0xFF4DD0E1,
  0xFF4DB6AC,
  0xFF81C784,
  0xFFAED581,
  0xFFFFD54F,
  0xFFFFB74D,
  0xFFFF8A65,
  0xFFA1887F,
  0xFF90A4AE,
];
