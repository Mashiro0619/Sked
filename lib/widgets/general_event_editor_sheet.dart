import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../theme/sked_expressive_theme.dart';
import '../utils/general_schedule_colors.dart';
import 'app_modal_sheet.dart';
import 'expressive_dialog.dart';
import 'sked_dropdown_menu.dart';
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
    this.onSave,
    this.onDelete,
  });

  final GeneralEvent? initialEvent;
  final DateTime? initialDate;
  final List<GeneralSchedule> calendars;
  final String? activeCalendarId;
  final Future<void> Function(GeneralEvent)? onSave;
  final Future<void> Function()? onDelete;

  @override
  State<GeneralEventEditorSheet> createState() =>
      _GeneralEventEditorSheetState();
}

class _GeneralEventEditorSheetState extends State<GeneralEventEditorSheet> {
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

  bool get _isEditing => widget.initialEvent != null;
  bool get _showCalendarPicker => _calendarOptions.length > 1;
  bool get _blocked =>
      _hasPopped || _pickerOpen || _selectionDialogOpen || _actionInProgress;

  @override
  void initState() {
    super.initState();
    _calendarOptions = _buildCalendarOptions();
    final event = widget.initialEvent;
    final initial = widget.initialDate ?? DateTime.now();
    final startDt = event != null
        ? tryParseStrictIsoDateTime(event.startDateTimeIso) ?? initial
        : DateTime(
            initial.year,
            initial.month,
            initial.day,
            initial.hour,
            initial.minute,
          );
    final endDt = event != null
        ? tryParseStrictIsoDateTime(event.endDateTimeIso) ??
              startDt.add(const Duration(hours: 1))
        : startDt.add(const Duration(hours: 1));
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
    _reminders =
        event?.reminders.map((item) => item.minutesBefore).toList() ?? const [];
  }

  @override
  void didUpdateWidget(covariant GeneralEventEditorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    if (_sectionsInitialized) return;
    final mediaQuery = MediaQuery.of(context);
    final textScale = mediaQuery.textScaler.scale(16) / 16;
    final hasDetails =
        _notesController.text.trim().isNotEmpty || _colorValue != null;
    // Keep low-frequency fields discoverable on Android portrait and with
    // accessibility text scaling; wider layouts start compact when empty.
    _detailsSectionExpanded =
        hasDetails || textScale > 1.3 || mediaQuery.size.height < 560;
    _sectionsInitialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
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

  DateTime _buildStartDateTime() {
    if (_isAllDay) {
      return normalizeDateOnly(_startDate);
    }
    return DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime _buildEndDateTime() {
    if (_isAllDay) {
      var end = calendarDateEndExclusive(_endDate);
      final start = _buildStartDateTime();
      if (!end.isAfter(start)) {
        end = calendarDateEndExclusive(start);
      }
      return end;
    }
    var end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    final start = _buildStartDateTime();
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    return end;
  }

  Future<void> _save() async {
    if (_blocked) return;
    if (!_formKey.currentState!.validate()) return;
    final startDt = _buildStartDateTime();
    final endDt = _buildEndDateTime();
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
      reminders: [
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
    FocusScope.of(context).unfocus();
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
    if (_blocked) return;
    final result = const GeneralEventEditorResult(delete: true);
    final delete = widget.onDelete;
    if (delete == null) {
      _popOnce(result);
      return;
    }
    FocusScope.of(context).unfocus();
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
    if (_hasPopped) return;
    setState(() => _hasPopped = true);
    Navigator.of(context).pop(result);
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
    );
  }

  String _generateId() => 'evt_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    // A keyboard already reduces the route's usable height. Expanding the
    // sheet to 96% in that state would leave the fixed action bar over the
    // scrollable form on short Android windows.
    final compactSheet =
        mediaQuery.size.height < 700 && mediaQuery.viewInsets.bottom == 0;
    final sheetHeightFactor = mediaQuery.viewInsets.bottom > 0
        ? 1.0
        : compactSheet
        ? 0.96
        : 0.84;
    return PopScope(
      canPop: !_blocked,
      child: Form(
        key: _formKey,
        child: AppSheetScaffold(
          // Android portrait keyboards and short windows need nearly the
          // whole viewport so the fixed action bar does not cover the form.
          heightFactor: sheetHeightFactor,
          contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          title: Text(_isEditing ? l10n.editEvent : l10n.addEvent),
          leading: _isEditing
              ? OutlinedButton.icon(
                  onPressed: _blocked ? null : () => unawaited(_delete()),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.delete),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                )
              : null,
          actions: [
            TextButton(
              onPressed: _blocked ? null : () => _popOnce(),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: _blocked ? null : () => unawaited(_save()),
              icon: const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              UiCommandBusyIndicator(busy: _actionInProgress),
              const SizedBox(height: 8),
              FocusScope(
                canRequestFocus: !_actionInProgress,
                child: AbsorbPointer(
                  absorbing: _actionInProgress,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: l10n.eventTitle,
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.eventTitleRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: l10n.place,
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                      ),
                      if (_showCalendarPicker) ...[
                        const SizedBox(height: 8),
                        SkedDropdownMenu<String>(
                          initialSelection: _calendarId,
                          label: Text(l10n.calendar),
                          leadingIcon: const Icon(
                            Icons.calendar_month_outlined,
                          ),
                          expandedInsets: EdgeInsets.zero,
                          dropdownMenuEntries: [
                            for (final calendar in _calendarOptions)
                              DropdownMenuEntry(
                                value: calendar.id,
                                label: calendar.name,
                                labelWidget: _CalendarDropdownItem(
                                  calendar: calendar,
                                ),
                              ),
                          ],
                          onSelected: (value) {
                            if (value != null) {
                              setState(() => _calendarId = value);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      _EditorSection(
                        icon: Icons.schedule_outlined,
                        title: '${l10n.eventDate} · ${l10n.eventTime}',
                        initiallyExpanded: _timeSectionExpanded,
                        onExpansionChanged: (expanded) =>
                            setState(() => _timeSectionExpanded = expanded),
                        enabled: !_blocked,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EventSwitchRow(
                              icon: Icons.event_available_outlined,
                              title: l10n.allDay,
                              value: _isAllDay,
                              onChanged: (value) => setState(() {
                                _isAllDay = value;
                                if (value && _endDate.isBefore(_startDate)) {
                                  _endDate = _startDate;
                                }
                              }),
                            ),
                            _DateTimeRange(
                              start: _DateTimeRow(
                                icon: Icons.play_arrow_outlined,
                                label: l10n.eventStartTime,
                                date: _startDate,
                                time: _startTime,
                                showTime: !_isAllDay,
                                onPickDate: (_pickerOpen || _hasPopped)
                                    ? null
                                    : () async {
                                        final picked = await _runPicker(
                                          () => _pickDate(context, _startDate),
                                        );
                                        if (!mounted || picked == null) {
                                          return;
                                        }
                                        setState(() {
                                          _startDate = picked;
                                          if (_endDate.isBefore(_startDate)) {
                                            _endDate = _startDate;
                                          }
                                          if (_untilDate?.isBefore(
                                                _startDate,
                                              ) ??
                                              false) {
                                            _untilDate = _startDate;
                                          }
                                        });
                                      },
                                onPickTime: (_pickerOpen || _hasPopped)
                                    ? null
                                    : () async {
                                        final picked = await _runPicker(
                                          () => _pickTime(context, _startTime),
                                        );
                                        if (!mounted || picked == null) {
                                          return;
                                        }
                                        setState(() => _startTime = picked);
                                      },
                              ),
                              end: _DateTimeRow(
                                icon: Icons.stop_outlined,
                                label: l10n.eventEndTime,
                                date: _endDate,
                                time: _endTime,
                                showTime: !_isAllDay,
                                onPickDate: (_pickerOpen || _hasPopped)
                                    ? null
                                    : () async {
                                        final picked = await _runPicker(
                                          () => _pickDate(context, _endDate),
                                        );
                                        if (!mounted || picked == null) {
                                          return;
                                        }
                                        setState(() => _endDate = picked);
                                      },
                                onPickTime: (_pickerOpen || _hasPopped)
                                    ? null
                                    : () async {
                                        final picked = await _runPicker(
                                          () => _pickTime(context, _endTime),
                                        );
                                        if (!mounted || picked == null) {
                                          return;
                                        }
                                        setState(() => _endTime = picked);
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _EditorSection(
                        icon: Icons.tune_outlined,
                        title: '${l10n.eventRecurrence} · ${l10n.reminder}',
                        initiallyExpanded: _optionsSectionExpanded,
                        onExpansionChanged: (expanded) =>
                            setState(() => _optionsSectionExpanded = expanded),
                        enabled: !_blocked,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EventOptionField(
                              key: const ValueKey('event-recurrence-field'),
                              icon: Icons.repeat,
                              label: l10n.eventRecurrence,
                              value: _recurrenceSummary(
                                recurrence: _recurrence,
                                interval: _interval,
                                unit: _customUnit,
                                untilDate: _untilDate,
                                repeatCount: _repeatCount,
                                l10n: l10n,
                              ),
                              onTap: _blocked
                                  ? null
                                  : () => unawaited(_openRecurrenceDialog()),
                            ),
                            const SizedBox(height: 8),
                            _EventOptionField(
                              key: const ValueKey('event-reminder-field'),
                              icon: Icons.notifications_outlined,
                              label: l10n.reminder,
                              value: _reminderSummary(_reminders, l10n),
                              onTap: _blocked
                                  ? null
                                  : () => unawaited(_openReminderDialog()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _EditorSection(
                        icon: Icons.more_horiz,
                        title: '${l10n.eventNotes} · ${l10n.eventColor}',
                        initiallyExpanded: _detailsSectionExpanded,
                        onExpansionChanged: (expanded) =>
                            setState(() => _detailsSectionExpanded = expanded),
                        enabled: !_blocked,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: l10n.eventNotes,
                                prefixIcon: const Icon(Icons.notes_outlined),
                              ),
                              minLines: 2,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.eventColor,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final colorValue in _colorOptions)
                                  _ColorOption(
                                    colorValue: colorValue,
                                    selected: _colorValue == colorValue,
                                    onTap: () => setState(() {
                                      _colorValue = _colorValue == colorValue
                                          ? null
                                          : colorValue;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRecurrenceDialog() async {
    if (_blocked) return;
    FocusScope.of(context).unfocus();
    setState(() => _selectionDialogOpen = true);
    _RecurrenceDialogValue? result;
    try {
      result = await showExpressiveDialog<_RecurrenceDialogValue>(
        context: context,
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
    if (!mounted) return;
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

  Future<void> _openReminderDialog() async {
    if (_blocked) return;
    FocusScope.of(context).unfocus();
    setState(() => _selectionDialogOpen = true);
    List<int>? result;
    try {
      result = await showExpressiveDialog<List<int>>(
        context: context,
        builder: (_) => _ReminderPickerDialog(initialReminders: _reminders),
      );
    } finally {
      if (mounted) {
        setState(() => _selectionDialogOpen = false);
      } else {
        _selectionDialogOpen = false;
      }
    }
    if (!mounted || result == null) return;
    setState(() => _reminders = result!);
  }

  Future<T?> _runPicker<T>(Future<T?> Function() picker) async {
    if (_blocked) {
      return null;
    }
    setState(() => _pickerOpen = true);
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

/// Persistent disclosure container used by the editor's low-frequency groups.
/// Keeping children alive preserves focus, text drafts, and selected colors
/// while a user collapses a section on a small Android screen.
class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.icon,
    required this.title,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.enabled,
    required this.child,
  });

  final IconData icon;
  final String title;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = skedShapeSchemeOf(context).field;
    return Material(
      color: colors.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        maintainState: true,
        enabled: enabled,
        onExpansionChanged: enabled ? onExpansionChanged : null,
        leading: Icon(icon),
        title: Text(title),
        tilePadding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
        shape: shape,
        collapsedShape: shape,
        backgroundColor: colors.surfaceContainerLow,
        collapsedBackgroundColor: colors.surfaceContainerLow,
        children: [child],
      ),
    );
  }
}

class _EventOptionField extends StatelessWidget {
  const _EventOptionField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null;
    final foreground = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondary = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final iconWidget = SizedBox.square(
                      dimension: 40,
                      child: Center(child: Icon(icon, color: secondary)),
                    );
                    final textWidget = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          softWrap: true,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: secondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                    final chevron = Icon(Icons.chevron_right, color: secondary);
                    final stack = constraints.maxWidth < 240 || textScale > 1.3;
                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              iconWidget,
                              const SizedBox(width: 8),
                              Expanded(child: textWidget),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: chevron,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        iconWidget,
                        const SizedBox(width: 8),
                        Expanded(child: textWidget),
                        const SizedBox(width: 8),
                        chevron,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    _interval = initial.interval;
    _unit = initial.unit;
    _untilDate = initial.untilDate;
    _repeatCountController = TextEditingController(
      text: initial.repeatCount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _repeatCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final contentMaxHeight = _eventDialogContentMaxHeight(mediaQuery);
    return PopScope(
      // Keep the recurrence draft modal in place while its date picker is
      // open. A barrier/back dismissal at that point would otherwise leave
      // the nested picker with a stale parent route.
      canPop: !_blocked,
      child: AlertDialog(
        constraints: const BoxConstraints(maxWidth: expressiveDialogMaxWidth),
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

  Future<void> _pickUntilDate() async {
    if (_blocked) return;
    setState(() => _pickerOpen = true);
    try {
      final picked = await _pickDate(
        context,
        _untilDate ?? addCalendarDays(widget.firstDate, 90),
        firstDate: widget.firstDate,
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
    if (_hasPopped) return;
    setState(() => _hasPopped = true);
    Navigator.of(context).pop(value);
  }
}

class _ReminderPickerDialog extends StatefulWidget {
  const _ReminderPickerDialog({required this.initialReminders});

  final List<int> initialReminders;

  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  late Set<int> _reminders;
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    _reminders = widget.initialReminders.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    return PopScope(
      canPop: !_hasPopped,
      child: AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(maxWidth: expressiveDialogMaxWidth),
        insetPadding: _eventDialogInsetPadding(mediaQuery.size.width),
        title: Text(l10n.reminder),
        contentPadding: EdgeInsetsDirectional.fromSTEB(
          mediaQuery.size.width < 480 ? 16 : 24,
          12,
          mediaQuery.size.width < 480 ? 16 : 24,
          0,
        ),
        content: SizedBox(
          width: expressiveDialogMaxWidth,
          child: _ReminderPicker(
            reminders: _reminders.toList()..sort(),
            onOptionChanged: (minutes, selected) => setState(() {
              if (minutes == null) {
                _reminders.clear();
              } else if (selected) {
                _reminders.add(minutes);
              } else {
                _reminders.remove(minutes);
              }
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasPopped ? null : () => _popOnce(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _hasPopped
                ? null
                : () => _popOnce(_reminders.toList()..sort()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _popOnce([List<int>? value]) {
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
  const _DateTimeRange({required this.start, required this.end});

  final Widget start;
  final Widget end;

  @override
  Widget build(BuildContext context) {
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
  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final value = showTime
        ? '${_fmtDate(date)} ${time.format(context)}'
        : _fmtDate(date);
    final actionStyle = IconButton.styleFrom(
      minimumSize: const Size.square(48),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    final actionButtons = [
      IconButton(
        tooltip: l10n.pickDate,
        onPressed: onPickDate,
        style: actionStyle,
        icon: const Icon(Icons.calendar_today_outlined),
      ),
      if (showTime)
        IconButton(
          tooltip: l10n.pickTime,
          onPressed: onPickTime,
          style: actionStyle,
          icon: const Icon(Icons.access_time),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leading = Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Icon(icon, color: colors.primary),
          );
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
                  color: colors.onSurfaceVariant,
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

class _EventSwitchRow extends StatelessWidget {
  const _EventSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Ink(
          decoration: ShapeDecoration(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final iconWidget = SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Icon(icon, color: colors.onSurfaceVariant),
                  ),
                );
                final titleWidget = Text(
                  title,
                  softWrap: true,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                );
                final stack = constraints.maxWidth < 240 || textScale > 1.3;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconWidget,
                          const SizedBox(width: 12),
                          Expanded(child: titleWidget),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Switch(value: value, onChanged: onChanged),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(width: 12),
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    Switch(value: value, onChanged: onChanged),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RepeatOptions extends StatelessWidget {
  const _RepeatOptions({
    required this.recurrence,
    required this.interval,
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
  final GeneralEventRecurrenceUnit customUnit;
  final DateTime? untilDate;
  final TextEditingController repeatCountController;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<GeneralEventRecurrenceUnit> onUnitChanged;
  final VoidCallback? onPickUntil;
  final VoidCallback onClearUntil;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final endDateButton = Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onPickUntil,
            icon: const Icon(Icons.event_repeat_outlined),
            label: Text(
              untilDate == null ? l10n.recurrenceEndDate : _fmtDate(untilDate!),
              overflow: TextOverflow.ellipsis,
            ),
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
          _ResponsiveFormRow(
            breakpoint: 420,
            children: [
              SkedDropdownMenu<int>(
                initialSelection: interval.clamp(1, 30).toInt(),
                label: Text(l10n.recurrenceEvery),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  for (var value = 1; value <= 30; value++)
                    DropdownMenuEntry(value: value, label: '$value'),
                ],
                onSelected: (value) {
                  if (value != null) onIntervalChanged(value);
                },
              ),
              SkedDropdownMenu<GeneralEventRecurrenceUnit>(
                initialSelection: customUnit,
                label: Text(l10n.recurrenceUnit),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
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
        _ResponsiveFormRow(
          breakpoint: 420,
          children: [
            TextFormField(
              controller: repeatCountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.recurrenceRepeatCount,
                hintText: l10n.recurrenceNoLimit,
                prefixIcon: const Icon(Icons.numbers),
              ),
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

class _ReminderPicker extends StatelessWidget {
  const _ReminderPicker({
    required this.reminders,
    required this.onOptionChanged,
  });

  final List<int> reminders;
  final void Function(int? minutes, bool selected) onOptionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(l10n.none),
          selected: reminders.isEmpty,
          onSelected: (selected) => onOptionChanged(null, selected),
        ),
        for (final option in _reminderOptions)
          FilterChip(
            label: Text(_reminderLabel(option, l10n)),
            selected: reminders.contains(option),
            onSelected: (selected) => onOptionChanged(option, selected),
          ),
      ],
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
    return Tooltip(
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

class _ResponsiveFormRow extends StatelessWidget {
  const _ResponsiveFormRow({required this.children, this.breakpoint = 480});

  static const double _spacing = 8;

  final List<Widget> children;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: _spacing),
                children[index],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: _spacing),
              Expanded(child: children[index]),
            ],
          ],
        );
      },
    );
  }
}

class _CalendarDropdownItem extends StatelessWidget {
  const _CalendarDropdownItem({required this.calendar});

  final GeneralSchedule calendar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorDot(color: effectiveGeneralCalendarColor(context, calendar)),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            calendar.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
  return showDatePicker(
    context: context,
    initialDate: boundedInitialDate,
    firstDate: boundedFirstDate,
    lastDate: lastDate,
  );
}

Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initialTime) {
  return showTimePicker(context: context, initialTime: initialTime);
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
      interval.clamp(1, 30).toInt(),
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
