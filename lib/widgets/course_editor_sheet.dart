import 'dart:async';

import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../previews/sked_preview_support.dart';
import '../theme/sked_expressive_theme.dart';
import 'app_modal_sheet.dart';
import 'expressive_dialog.dart';
import 'ui_command.dart';

part '../previews/course_editor_previews.dart';

/// delete 单独保留成一个标记，避免和“只是点了取消”共用同一种空值语义。
class CourseEditorResult {
  const CourseEditorResult.save(this.course) : delete = false;
  const CourseEditorResult.delete() : course = null, delete = true;

  final CourseItem? course;
  final bool delete;
}

/// 周次选择单独放二级弹窗，不然编辑页一长起来，在手机上会很挤。
class CourseEditorSheet extends StatefulWidget {
  const CourseEditorSheet({
    super.key,
    required this.periodTimes,
    required this.totalWeeks,
    required this.dayOfWeek,
    this.initialCourse,
    this.initialStartMinutes,
    this.initialEndMinutes,
    this.initialPeriods,
    this.onSave,
    this.onDelete,
  });

  final List<CoursePeriodTime> periodTimes;
  final int totalWeeks;
  final int dayOfWeek;
  final CourseItem? initialCourse;
  final int? initialStartMinutes;
  final int? initialEndMinutes;
  final List<int>? initialPeriods;
  final Future<void> Function(CourseItem)? onSave;
  final Future<void> Function()? onDelete;

  @override
  State<CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<CourseEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _locationController;
  late final TextEditingController _creditController;
  late final TextEditingController _remarksController;
  late final TextEditingController _customFieldsController;
  late final TextEditingController _reminderMinutesController;

  late int _selectedDayOfWeek;
  late List<int> _selectedSemesterWeeks;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<int> _selectedPeriods;
  bool _hasPopped = false;
  bool _pickerOpen = false;
  bool _actionInProgress = false;
  late bool _scheduleSectionExpanded;
  late bool _dateExceptionsSectionExpanded;
  late bool _detailsSectionExpanded;
  late bool _reminderSectionExpanded;
  late CourseReminderBehavior _reminderBehavior;
  late List<CourseDateException> _dateExceptions;

  bool get _blocked => _hasPopped || _pickerOpen || _actionInProgress;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCourse;
    final defaultStartMinutes =
        widget.initialStartMinutes ??
        (widget.periodTimes.isNotEmpty
            ? widget.periodTimes.first.startMinutes
            : 8 * 60);
    final defaultEndMinutes =
        widget.initialEndMinutes ??
        (widget.periodTimes.length > 1
            ? widget.periodTimes[1].endMinutes
            : widget.periodTimes.isNotEmpty
            ? widget.periodTimes.first.endMinutes
            : (8 * 60) + 45);

    _nameController = TextEditingController(text: initial?.name ?? '');
    _teacherController = TextEditingController(text: initial?.teacher ?? '');
    _locationController = TextEditingController(text: initial?.location ?? '');
    _creditController = TextEditingController(
      text: initial == null || initial.credit == 0
          ? ''
          : initial.credit.toString(),
    );
    _remarksController = TextEditingController(text: initial?.remarks ?? '');
    _customFieldsController = TextEditingController(
      text: initial == null
          ? ''
          : initial.customFields.entries
                .map((entry) => '${entry.key}:${entry.value}')
                .join('\n'),
    );
    final reminder =
        initial?.reminderSettings ?? const CourseReminderSettings();
    _reminderBehavior = reminder.behavior;
    _reminderMinutesController = TextEditingController(
      text: reminder.minutesBefore?.toString() ?? '10',
    );
    _selectedDayOfWeek = initial?.dayOfWeek ?? widget.dayOfWeek;
    _selectedSemesterWeeks = normalizeSemesterWeeks(
      initial?.semesterWeeks ?? buildAllSemesterWeeks(widget.totalWeeks),
    );
    _startTime = _timeOfDayFromMinutes(
      initial?.startMinutes ?? defaultStartMinutes,
    );
    _endTime = _timeOfDayFromMinutes(initial?.endMinutes ?? defaultEndMinutes);
    _selectedPeriods = _normalizeSelectedPeriods(
      initial?.periods.isNotEmpty == true
          ? initial!.periods
          : widget.initialPeriods != null
          ? widget.initialPeriods!
          : matchPeriodsForTimeRange(
              widget.periodTimes,
              initial?.startMinutes ?? defaultStartMinutes,
              initial?.endMinutes ?? defaultEndMinutes,
            ),
    );
    _scheduleSectionExpanded = true;
    _dateExceptions = _sortDateExceptions(initial?.dateExceptions ?? const []);
    _dateExceptionsSectionExpanded = _dateExceptions.isNotEmpty;
    _detailsSectionExpanded =
        _teacherController.text.trim().isNotEmpty ||
        _creditController.text.trim().isNotEmpty ||
        _remarksController.text.trim().isNotEmpty ||
        _customFieldsController.text.trim().isNotEmpty;
    _reminderSectionExpanded =
        reminder.behavior != CourseReminderBehavior.inherit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _creditController.dispose();
    _remarksController.dispose();
    _customFieldsController.dispose();
    _reminderMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final linkedPeriods = _selectedPeriods;
    final linkedPeriodsLabel = _formatPeriodsLabel(linkedPeriods, l10n);
    final mediaQuery = MediaQuery.of(context);
    final compactSheet =
        mediaQuery.size.height < 700 && mediaQuery.viewInsets.bottom == 0;
    final sheetHeightFactor = mediaQuery.viewInsets.bottom > 0
        ? 1.0
        : compactSheet
        ? 0.96
        : 0.72;

    return PopScope(
      canPop: !_actionInProgress && !_pickerOpen && !_hasPopped,
      child: AppSheetScaffold(
        // Short Android windows and the IME need enough room for both the
        // fixed action area and a useful scrollable form viewport.
        heightFactor: sheetHeightFactor,
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        title: Text(
          widget.initialCourse == null
              ? l10n.addCourseTitle
              : l10n.editCourseTitle,
        ),
        leading: widget.initialCourse == null
            ? null
            : TextButton.icon(
                onPressed: _blocked ? null : () => unawaited(_confirmDelete()),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.delete),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
        actions: [
          TextButton(
            onPressed: _blocked ? null : () => _popOnce(),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: _blocked ? null : () => unawaited(_submit()),
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
            _ResponsiveFormRow(
              flexes: const [2, 1],
              children: [
                TextField(
                  controller: _nameController,
                  enabled: !_blocked,
                  decoration: InputDecoration(
                    labelText: l10n.courseName,
                    prefixIcon: const Icon(Icons.book_outlined),
                  ),
                ),
                TextField(
                  controller: _locationController,
                  enabled: !_blocked,
                  decoration: InputDecoration(
                    labelText: l10n.location,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EditorSection(
              icon: Icons.event_note_outlined,
              title: '${l10n.dayOfWeek} · ${l10n.time}',
              subtitle: linkedPeriods.isEmpty
                  ? l10n.linkedPeriodsUnmatched
                  : linkedPeriodsLabel,
              initiallyExpanded: _scheduleSectionExpanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _scheduleSectionExpanded = expanded),
              enabled: !_blocked,
              child: _buildScheduleFields(l10n),
            ),
            const SizedBox(height: 8),
            _EditorSection(
              key: const ValueKey('course-date-exceptions-section'),
              icon: Icons.event_repeat_outlined,
              title: l10n.courseDateExceptions,
              subtitle: _dateExceptions.isEmpty
                  ? l10n.courseDateExceptionsEmpty
                  : l10n.courseDateExceptionsCount(_dateExceptions.length),
              initiallyExpanded: _dateExceptionsSectionExpanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _dateExceptionsSectionExpanded = expanded),
              enabled: !_blocked,
              child: _buildDateExceptionFields(l10n),
            ),
            const SizedBox(height: 8),
            _EditorSection(
              icon: Icons.notes_outlined,
              title: l10n.more,
              initiallyExpanded: _detailsSectionExpanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _detailsSectionExpanded = expanded),
              enabled: !_blocked,
              child: _buildDetailsFields(l10n),
            ),
            const SizedBox(height: 8),
            _EditorSection(
              key: const ValueKey('course-reminder-section'),
              icon: Icons.notifications_outlined,
              title: l10n.reminder,
              initiallyExpanded: _reminderSectionExpanded,
              onExpansionChanged: (expanded) =>
                  setState(() => _reminderSectionExpanded = expanded),
              enabled: !_blocked,
              child: _buildReminderFields(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleFields(AppLocalizations l10n) {
    final localeCode = app_locale.localeCodeFromLocale(
      Localizations.localeOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponsiveFormRow(
          breakpoint: 520,
          children: [
            _SelectionTile(
              title: l10n.dayOfWeek,
              subtitle: formatDayOfWeekLabel(
                _selectedDayOfWeek,
                localeCode: localeCode,
              ),
              icon: Icons.today_outlined,
              enabled: !_blocked,
              onTap: _blocked ? null : _pickDayOfWeek,
            ),
            _SelectionTile(
              title: l10n.semesterWeeks,
              subtitle: formatSemesterWeeksLabel(
                _selectedSemesterWeeks,
                totalWeeks: widget.totalWeeks,
                localeCode: localeCode,
              ),
              icon: Icons.edit_calendar,
              enabled: !_blocked,
              onTap: _blocked ? null : _pickSemesterWeeks,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _CourseTimeRange(
          startLabel: l10n.startTime,
          startValue: _formatTimeOfDay(_startTime),
          endLabel: l10n.endTime,
          endValue: _formatTimeOfDay(_endTime),
          enabled: !_blocked,
          onPickStart: _blocked ? null : () => _pickTime(isStart: true),
          onPickEnd: _blocked ? null : () => _pickTime(isStart: false),
        ),
        const SizedBox(height: 8),
        _SelectionTile(
          title: l10n.linkedPeriods,
          subtitle: _selectedPeriods.isEmpty
              ? l10n.linkedPeriodsUnmatched
              : _formatPeriodsLabel(_selectedPeriods, l10n),
          icon: Icons.tune,
          enabled: !_blocked,
          onTap: _blocked ? null : _pickPeriods,
        ),
      ],
    );
  }

  Widget _buildDetailsFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResponsiveFormRow(
          children: [
            TextField(
              controller: _teacherController,
              enabled: !_blocked,
              decoration: InputDecoration(
                labelText: l10n.teacherName,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            TextField(
              controller: _creditController,
              enabled: !_blocked,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l10n.credits,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _remarksController,
          enabled: !_blocked,
          decoration: InputDecoration(
            labelText: l10n.remarks,
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customFieldsController,
          enabled: !_blocked,
          decoration: InputDecoration(
            labelText: l10n.customFields,
            hintText: l10n.customFieldsHint,
            prefixIcon: const Icon(Icons.data_object_outlined),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildReminderFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.reminder, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _VerticalChoiceList<CourseReminderBehavior>(
          key: const ValueKey('course-reminder-behavior'),
          selected: {_reminderBehavior},
          onChanged: _blocked
              ? null
              : (value) => setState(() => _reminderBehavior = value),
          options: [
            _VerticalChoiceOption(
              value: CourseReminderBehavior.inherit,
              label: Text(l10n.notificationCourseDefaultReminder),
              icon: const Icon(Icons.settings_backup_restore_outlined),
            ),
            _VerticalChoiceOption(
              value: CourseReminderBehavior.disabled,
              label: Text(l10n.notificationReminderOff),
              icon: const Icon(Icons.notifications_off_outlined),
            ),
            _VerticalChoiceOption(
              value: CourseReminderBehavior.custom,
              label: Text(l10n.recurrenceCustom),
              icon: const Icon(Icons.tune_outlined),
            ),
          ],
        ),
        if (_reminderBehavior == CourseReminderBehavior.custom) ...[
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('course-reminder-custom-minutes'),
            controller: _reminderMinutesController,
            enabled: !_blocked,
            keyboardType: const TextInputType.numberWithOptions(),
            decoration: InputDecoration(
              labelText: l10n.notificationReminderCustom(5),
              prefixIcon: const Icon(Icons.schedule_outlined),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateExceptionFields(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_dateExceptions.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
            child: Text(
              l10n.courseDateExceptionsEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var index = 0; index < _dateExceptions.length; index++)
            _CourseDateExceptionRow(
              key: ValueKey(
                'course-date-exception-${_dateExceptions[index].dateIso}',
              ),
              dateLabel: _formatDateExceptionDate(_dateExceptions[index]),
              summary: _formatDateExceptionSummary(
                _dateExceptions[index],
                l10n,
              ),
              cancelled: _dateExceptions[index].cancelled,
              enabled: !_blocked,
              isLast: index == _dateExceptions.length - 1,
              deleteLabel: l10n.delete,
              onEdit: _blocked
                  ? null
                  : () => unawaited(_editDateException(_dateExceptions[index])),
              onDelete: _blocked
                  ? null
                  : () => _removeDateException(_dateExceptions[index]),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('course-date-exception-add'),
          onPressed: _blocked ? null : () => unawaited(_editDateException()),
          icon: const Icon(Icons.add),
          label: Text(l10n.courseDateExceptionAdd),
        ),
      ],
    );
  }

  String _formatDateExceptionDate(CourseDateException exception) {
    final date = tryParseStrictIsoDate(exception.dateIso);
    if (date == null) return exception.dateIso;
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatDateExceptionSummary(
    CourseDateException exception,
    AppLocalizations l10n,
  ) {
    if (exception.cancelled) return l10n.courseDateExceptionCancelled;
    final start = exception.startMinutes;
    final end = exception.endMinutes;
    if (start == null || end == null) {
      return l10n.courseDateExceptionTimeOverride;
    }
    return '${l10n.courseDateExceptionTimeOverride} \u00b7 '
        '${formatMinutes(start)} - ${formatMinutes(end)}';
  }

  Future<void> _editDateException([CourseDateException? current]) async {
    if (_blocked) return;
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    try {
      final result = await showExpressiveDialog<CourseDateException>(
        context: context,
        builder: (_) => _CourseDateExceptionEditorDialog(
          initialException: current,
          dayOfWeek: _selectedDayOfWeek,
          fallbackStartMinutes: _minutesFromTimeOfDay(_startTime),
          fallbackEndMinutes: _minutesFromTimeOfDay(_endTime),
        ),
      );
      if (!mounted || result == null) return;
      setState(() {
        final next =
            _dateExceptions
                .where(
                  (item) =>
                      !identical(item, current) &&
                      item.dateIso != result.dateIso,
                )
                .toList()
              ..add(result);
        _dateExceptions = _sortDateExceptions(next);
      });
    } finally {
      _setPickerOpen(false);
    }
  }

  void _removeDateException(CourseDateException exception) {
    if (_blocked) return;
    setState(() {
      _dateExceptions = _dateExceptions
          .where((item) => item.dateIso != exception.dateIso)
          .toList();
    });
  }

  List<CourseDateException> _sortDateExceptions(
    Iterable<CourseDateException> exceptions,
  ) {
    final sorted = List<CourseDateException>.from(exceptions);
    sorted.sort((left, right) => left.dateIso.compareTo(right.dateIso));
    return sorted;
  }

  List<int> get _matchedPeriods => matchPeriodsForTimeRange(
    widget.periodTimes,
    _minutesFromTimeOfDay(_startTime),
    _minutesFromTimeOfDay(_endTime),
  );

  void _dismissActiveInputFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _setPickerOpen(bool value) {
    if (mounted) {
      setState(() => _pickerOpen = value);
    } else {
      _pickerOpen = value;
    }
  }

  Future<void> _pickDayOfWeek() async {
    if (_blocked) {
      return;
    }
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    try {
      final result = await showExpressiveDialog<int>(
        context: context,
        builder: (context) {
          var popped = false;
          void popWith(int day) {
            if (popped) return;
            popped = true;
            Navigator.of(context).pop(day);
          }

          return _WeekdayPickerDialog(
            selectedDay: _selectedDayOfWeek,
            onSelect: popWith,
          );
        },
      );
      if (!mounted || result == null) {
        return;
      }
      setState(() => _selectedDayOfWeek = result);
    } finally {
      _setPickerOpen(false);
    }
  }

  Future<void> _pickSemesterWeeks() async {
    if (_blocked) {
      return;
    }
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    final draft = {..._selectedSemesterWeeks};
    try {
      final result = await showExpressiveDialog<List<int>>(
        context: context,
        builder: (context) {
          var popped = false;
          return StatefulBuilder(
            builder: (context, setState) {
              final l10n = AppLocalizations.of(context);
              void popWith(List<int>? value) {
                if (popped) return;
                popped = true;
                Navigator.of(context).pop(value);
              }

              return AlertDialog(
                insetPadding: _editorDialogInsetPadding(context),
                title: Text(l10n.selectSemesterWeeks),
                content: ExpressiveDialogContent(
                  maxWidth: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                draft
                                  ..clear()
                                  ..addAll(
                                    buildAllSemesterWeeks(widget.totalWeeks),
                                  );
                              }),
                              child: Text(l10n.selectAll),
                            ),
                            TextButton(
                              onPressed: () => setState(() => draft.clear()),
                              child: Text(l10n.clear),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: GridView.builder(
                          shrinkWrap: true,
                          itemCount: widget.totalWeeks,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                mainAxisExtent: 48,
                              ),
                          itemBuilder: (context, index) {
                            final week = index + 1;
                            final selected = draft.contains(week);
                            final colorScheme = Theme.of(context).colorScheme;
                            return Semantics(
                              key: ValueKey('course-semester-week-$week'),
                              button: true,
                              selected: selected,
                              label: l10n.weekLabel(week),
                              child: ExcludeSemantics(
                                child: Material(
                                  color: selected
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.12,
                                        )
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setState(() {
                                        if (selected) {
                                          draft.remove(week);
                                        } else {
                                          draft.add(week);
                                        }
                                      });
                                    },
                                    child: Center(
                                      child: Text(
                                        '$week',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: selected
                                                  ? colorScheme.primary
                                                  : colorScheme
                                                        .onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => popWith(null),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () =>
                        popWith(normalizeSemesterWeeks(draft.toList())),
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || result == null) {
        return;
      }
      setState(() {
        _selectedSemesterWeeks = result.isEmpty
            ? buildAllSemesterWeeks(widget.totalWeeks)
            : result;
      });
    } finally {
      _setPickerOpen(false);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    if (_blocked) {
      return;
    }
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    try {
      final initialTime = isStart ? _startTime : _endTime;
      final picked = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _selectedPeriods = _matchedPeriods;
      });
    } finally {
      _setPickerOpen(false);
    }
  }

  Future<void> _pickPeriods() async {
    if (_blocked) {
      return;
    }
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    final draft = List<int>.from(_selectedPeriods);
    try {
      final result = await showExpressiveDialog<List<int>>(
        context: context,
        builder: (context) {
          var popped = false;
          return StatefulBuilder(
            builder: (context, setState) {
              final l10n = AppLocalizations.of(context);
              void popWith(List<int>? value) {
                if (popped) return;
                popped = true;
                Navigator.of(context).pop(value);
              }

              return AlertDialog(
                insetPadding: _editorDialogInsetPadding(context),
                title: Text(l10n.selectLinkedPeriods),
                content: ExpressiveDialogContent(
                  maxWidth: 360,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final period in widget.periodTimes)
                        ChoiceChip(
                          label: Text(l10n.periodNumberLabel(period.index)),
                          selected: draft.contains(period.index),
                          onSelected: (_) {
                            setState(() {
                              final next = _togglePeriodSelection(
                                draft,
                                period.index,
                              );
                              draft
                                ..clear()
                                ..addAll(next);
                            });
                          },
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => setState(draft.clear),
                    child: Text(l10n.clear),
                  ),
                  TextButton(
                    onPressed: () => popWith(null),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => popWith(List<int>.from(draft)),
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || result == null) {
        return;
      }
      setState(() {
        _selectedPeriods = _normalizeSelectedPeriods(result);
        if (_selectedPeriods.isNotEmpty) {
          final selectedTimes =
              widget.periodTimes
                  .where((item) => _selectedPeriods.contains(item.index))
                  .toList()
                ..sort((a, b) => a.index.compareTo(b.index));
          if (selectedTimes.isNotEmpty) {
            _startTime = _timeOfDayFromMinutes(
              selectedTimes.first.startMinutes,
            );
            _endTime = _timeOfDayFromMinutes(selectedTimes.last.endMinutes);
          }
        }
      });
    } finally {
      _setPickerOpen(false);
    }
  }

  Future<void> _submit() async {
    if (_blocked) return;
    final startMinutes = _minutesFromTimeOfDay(_startTime);
    final endMinutes = _minutesFromTimeOfDay(_endTime);
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty || startMinutes >= endMinutes) {
      showUiFailureFeedback(
        context: context,
        message: _nameController.text.trim().isEmpty
            ? l10n.eventTitleRequired
            : l10n.endTimeMustBeLater,
      );
      return;
    }

    final periods = _normalizeSelectedPeriods(
      _selectedPeriods.isEmpty ? _matchedPeriods : _selectedPeriods,
    );
    final course = CourseItem(
      id:
          widget.initialCourse?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      teacher: _teacherController.text.trim(),
      location: _locationController.text.trim(),
      dayOfWeek: _selectedDayOfWeek,
      semesterWeeks: normalizeSemesterWeeks(_selectedSemesterWeeks),
      periods: periods,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      timeRange: buildTimeRange(startMinutes, endMinutes),
      credit: _parseCredit(_creditController.text),
      remarks: _remarksController.text.trim(),
      customFields: _parseCustomFields(_customFieldsController.text),
      reminderSettings: _courseReminderSettings,
      dateExceptions: List.unmodifiable(_dateExceptions),
    );
    final result = CourseEditorResult.save(course);
    final save = widget.onSave;
    if (save == null) {
      _popOnce(result);
      return;
    }
    setState(() => _actionInProgress = true);
    final saved = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Save course',
      command: () => save(course),
    );
    if (!mounted) return;
    if (saved) {
      _popOnce(result);
    } else {
      setState(() => _actionInProgress = false);
    }
  }

  CourseReminderSettings get _courseReminderSettings {
    if (_reminderBehavior != CourseReminderBehavior.custom) {
      return CourseReminderSettings(behavior: _reminderBehavior);
    }
    final minutes = int.tryParse(_reminderMinutesController.text.trim());
    if (minutes == null || minutes < 0) {
      return const CourseReminderSettings();
    }
    return CourseReminderSettings(
      behavior: CourseReminderBehavior.custom,
      minutesBefore: minutes,
    );
  }

  Future<void> _confirmDelete() async {
    if (_blocked) return;
    setState(() => _pickerOpen = true);
    try {
      final confirmed = await showExpressiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _DeleteCourseConfirmationDialog(onDelete: widget.onDelete),
      );
      if (confirmed == true && mounted && !_hasPopped) {
        _popOnce(const CourseEditorResult.delete());
      }
    } finally {
      if (mounted && !_hasPopped) {
        setState(() => _pickerOpen = false);
      } else {
        _pickerOpen = false;
      }
    }
  }

  void _popOnce([CourseEditorResult? result]) {
    if (_hasPopped) return;
    setState(() => _hasPopped = true);
    Navigator.of(context).pop(result);
  }

  List<int> _togglePeriodSelection(List<int> current, int periodIndex) {
    final next = <int>{...current};
    if (next.contains(periodIndex)) {
      next.remove(periodIndex);
    } else {
      next.add(periodIndex);
    }
    if (next.isEmpty) {
      return const [];
    }
    final sorted = next.toList()..sort();
    final contiguous = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] != sorted[i - 1] + 1) {
        return [periodIndex];
      }
      contiguous.add(sorted[i]);
    }
    return contiguous;
  }

  List<int> _normalizeSelectedPeriods(Iterable<int> periods) {
    final validIndices = widget.periodTimes.map((item) => item.index).toSet();
    final normalized =
        periods
            .where((period) => period > 0)
            .where(
              (period) => validIndices.isEmpty || validIndices.contains(period),
            )
            .toSet()
            .toList()
          ..sort();
    return normalized;
  }

  double _parseCredit(String value) {
    final parsed = double.tryParse(value.trim());
    return parsed == null || !parsed.isFinite ? 0 : parsed;
  }

  TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final normalized = normalizeMinuteOfDay(minutes);
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  int _minutesFromTimeOfDay(TimeOfDay time) => (time.hour * 60) + time.minute;

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatPeriodsLabel(List<int> periods, AppLocalizations l10n) {
    if (periods.isEmpty) {
      return '';
    }
    final sorted = [...periods]..sort();
    if (sorted.first == sorted.last) {
      return l10n.periodNumberLabel(sorted.first);
    }
    return l10n.periodRangeLabel(sorted.first, sorted.last);
  }

  Map<String, dynamic> _parseCustomFields(String value) {
    final result = <String, dynamic>{};
    for (final line in value.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final separator = trimmed.indexOf(':');
      if (separator <= 0) {
        result[trimmed] = '';
        continue;
      }
      final key = trimmed.substring(0, separator).trim();
      final content = trimmed.substring(separator + 1).trim();
      result[key] = content;
    }
    return result;
  }
}

class _CourseDateExceptionRow extends StatelessWidget {
  const _CourseDateExceptionRow({
    super.key,
    required this.dateLabel,
    required this.summary,
    required this.cancelled,
    required this.enabled,
    required this.isLast,
    required this.deleteLabel,
    required this.onEdit,
    required this.onDelete,
  });

  final String dateLabel;
  final String summary;
  final bool cancelled;
  final bool enabled;
  final bool isLast;
  final String deleteLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondary = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    final icon = cancelled
        ? Icons.event_busy_outlined
        : Icons.schedule_outlined;

    return Material(
      color: colors.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  enabled: enabled,
                  label: dateLabel,
                  value: summary,
                  onTap: enabled ? onEdit : null,
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: enabled ? onEdit : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            12,
                            8,
                            4,
                            8,
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: secondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: foreground,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      summary,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: secondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: deleteLabel,
                child: IconButton(
                  onPressed: enabled ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                  color: enabled ? colors.onSurfaceVariant : secondary,
                  tooltip: deleteLabel,
                ),
              ),
            ],
          ),
          if (!isLast) Divider(height: 1, color: colors.outlineVariant),
        ],
      ),
    );
  }
}

enum _CourseDateExceptionMode { cancelled, timeOverride }

class _CourseDateExceptionEditorDialog extends StatefulWidget {
  const _CourseDateExceptionEditorDialog({
    required this.initialException,
    required this.dayOfWeek,
    required this.fallbackStartMinutes,
    required this.fallbackEndMinutes,
  });

  final CourseDateException? initialException;
  final int dayOfWeek;
  final int fallbackStartMinutes;
  final int fallbackEndMinutes;

  @override
  State<_CourseDateExceptionEditorDialog> createState() =>
      _CourseDateExceptionEditorDialogState();
}

class _CourseDateExceptionEditorDialogState
    extends State<_CourseDateExceptionEditorDialog> {
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late _CourseDateExceptionMode _mode;
  var _timePickerOpen = false;
  var _hasPopped = false;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    final current = widget.initialException;
    final initialDate = tryParseStrictIsoDate(current?.dateIso);
    _date = _dateOnWeekday(
      initialDate ?? normalizeDateOnly(DateTime.now()),
      widget.dayOfWeek,
    );
    _mode = current == null || current.cancelled
        ? _CourseDateExceptionMode.cancelled
        : _CourseDateExceptionMode.timeOverride;
    _startTime = _timeFromMinutes(
      current?.startMinutes ?? widget.fallbackStartMinutes,
    );
    _endTime = _timeFromMinutes(
      current?.endMinutes ?? widget.fallbackEndMinutes,
    );
  }

  Future<void> _pickDate() async {
    if (_timePickerOpen || _hasPopped) return;
    _timePickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final result = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        selectableDayPredicate: (date) => date.weekday == widget.dayOfWeek,
      );
      if (!mounted || result == null) return;
      setState(() => _date = normalizeDateOnly(result));
    } finally {
      _timePickerOpen = false;
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    if (_timePickerOpen || _hasPopped) return;
    _timePickerOpen = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final picked = await showTimePicker(
        context: context,
        initialTime: isStart ? _startTime : _endTime,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (!mounted || picked == null) return;
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _timeError = null;
      });
    } finally {
      _timePickerOpen = false;
    }
  }

  void _save() {
    if (_timePickerOpen || _hasPopped) return;
    final startMinutes = _minutesFromTime(_startTime);
    final endMinutes = _minutesFromTime(_endTime);
    if (_mode == _CourseDateExceptionMode.timeOverride &&
        endMinutes <= startMinutes) {
      setState(
        () => _timeError = AppLocalizations.of(context).endTimeMustBeLater,
      );
      return;
    }

    _hasPopped = true;
    Navigator.of(context).pop(
      CourseDateException(
        dateIso: _dateIso(_date),
        cancelled: _mode == _CourseDateExceptionMode.cancelled,
        startMinutes: _mode == _CourseDateExceptionMode.timeOverride
            ? startMinutes
            : null,
        endMinutes: _mode == _CourseDateExceptionMode.timeOverride
            ? endMinutes
            : null,
      ),
    );
  }

  void _cancel() {
    if (_timePickerOpen || _hasPopped) return;
    _hasPopped = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(_date);
    final timeOverride = _mode == _CourseDateExceptionMode.timeOverride;

    return PopScope(
      canPop: !_timePickerOpen && !_hasPopped,
      child: AlertDialog(
        key: const ValueKey('course-date-exception-editor-dialog'),
        insetPadding: _editorDialogInsetPadding(context),
        title: Text(
          widget.initialException == null
              ? l10n.courseDateExceptionAdd
              : l10n.courseDateExceptionEdit,
        ),
        content: ExpressiveDialogContent(
          maxWidth: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CourseDateExceptionAction(
                  key: const ValueKey('course-date-exception-date'),
                  label: l10n.eventDate,
                  value: dateLabel,
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                _VerticalChoiceList<_CourseDateExceptionMode>(
                  key: const ValueKey('course-date-exception-mode'),
                  selected: {_mode},
                  onChanged: (value) {
                    setState(() {
                      _mode = value;
                      _timeError = null;
                    });
                  },
                  options: [
                    _VerticalChoiceOption(
                      value: _CourseDateExceptionMode.cancelled,
                      icon: const Icon(Icons.event_busy_outlined),
                      label: Text(l10n.courseDateExceptionCancelClass),
                    ),
                    _VerticalChoiceOption(
                      value: _CourseDateExceptionMode.timeOverride,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(l10n.courseDateExceptionTimeOverride),
                    ),
                  ],
                ),
                if (timeOverride) ...[
                  const SizedBox(height: 12),
                  _CourseDateExceptionTimeRange(
                    startLabel: l10n.startTime,
                    startValue: _formatTime(_startTime),
                    endLabel: l10n.endTime,
                    endValue: _formatTime(_endTime),
                    onPickStart: () => unawaited(_pickTime(isStart: true)),
                    onPickEnd: () => unawaited(_pickTime(isStart: false)),
                  ),
                  if (_timeError != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _timeError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
          FilledButton(
            key: const ValueKey('course-date-exception-save'),
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _CourseDateExceptionAction extends StatelessWidget {
  const _CourseDateExceptionAction({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Semantics(
      button: true,
      label: label,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceContainerLow,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(icon, color: colors.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseDateExceptionTimeRange extends StatelessWidget {
  const _CourseDateExceptionTimeRange({
    required this.startLabel,
    required this.startValue,
    required this.endLabel,
    required this.endValue,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String startLabel;
  final String startValue;
  final String endLabel;
  final String endValue;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Material(
      color: colors.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical =
              constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final start = _CourseDateExceptionTimeAction(
            key: const ValueKey('course-date-exception-start-time'),
            label: startLabel,
            value: startValue,
            onTap: onPickStart,
          );
          final end = _CourseDateExceptionTimeAction(
            key: const ValueKey('course-date-exception-end-time'),
            label: endLabel,
            value: endValue,
            onTap: onPickEnd,
          );
          if (vertical) {
            return Column(
              children: [
                start,
                Divider(height: 1, color: colors.outlineVariant),
                end,
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: start),
                VerticalDivider(width: 1, color: colors.outlineVariant),
                Expanded(child: end),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CourseDateExceptionTimeAction extends StatelessWidget {
  const _CourseDateExceptionTimeAction({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      button: true,
      label: label,
      value: value,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _dateOnWeekday(DateTime date, int weekday) {
  final normalized = normalizeDateOnly(date);
  final targetWeekday = normalizeDayOfWeek(weekday);
  final offset = (targetWeekday - normalized.weekday + 7) % 7;
  return addCalendarDays(normalized, offset);
}

TimeOfDay _timeFromMinutes(int minutes) {
  final normalized = normalizeMinuteOfDay(minutes);
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

int _minutesFromTime(TimeOfDay time) => (time.hour * 60) + time.minute;

String _formatTime(TimeOfDay time) => formatMinutes(_minutesFromTime(time));

String _dateIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _DeleteCourseConfirmationDialog extends StatefulWidget {
  const _DeleteCourseConfirmationDialog({this.onDelete});

  final Future<void> Function()? onDelete;

  @override
  State<_DeleteCourseConfirmationDialog> createState() =>
      _DeleteCourseConfirmationDialogState();
}

class _DeleteCourseConfirmationDialogState
    extends State<_DeleteCourseConfirmationDialog> {
  var _busy = false;
  var _popped = false;

  Future<void> _delete() async {
    if (_busy || _popped) return;
    final delete = widget.onDelete;
    if (delete == null) {
      _popped = true;
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = true);
    final deleted = await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Delete course',
      command: delete,
    );
    if (!mounted) return;
    if (deleted) {
      _popped = true;
      Navigator.of(context).pop(true);
    } else {
      setState(() => _busy = false);
    }
  }

  void _cancel() {
    if (_busy || _popped) return;
    _popped = true;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy && !_popped,
      child: AlertDialog(
        insetPadding: _editorDialogInsetPadding(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            UiCommandBusyIndicator(busy: _busy),
            const SizedBox(height: 16),
            Text(l10n.deleteCourseTitle),
          ],
        ),
        content: Text(l10n.deleteCourseMessage),
        actions: [
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: _busy ? null : () => unawaited(_delete()),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _WeekdayPickerDialog extends StatelessWidget {
  const _WeekdayPickerDialog({
    required this.selectedDay,
    required this.onSelect,
  });

  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = app_locale.localeCodeFromLocale(
      Localizations.localeOf(context),
    );

    return AlertDialog(
      insetPadding: _editorDialogInsetPadding(context),
      title: Text(l10n.selectDayOfWeek),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      content: ExpressiveDialogContent(
        maxWidth: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var day = DateTime.monday; day <= DateTime.sunday; day++)
              _WeekdayChoiceRow(
                label: formatDayOfWeekLabel(day, localeCode: localeCode),
                shortLabel: formatWeekdayShortLabel(
                  day,
                  localeCode: localeCode,
                ),
                selected: day == selectedDay,
                onTap: () => onSelect(day),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayChoiceRow extends StatelessWidget {
  const _WeekdayChoiceRow({
    required this.label,
    required this.shortLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String shortLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fillColor = selected ? colors.primaryContainer : Colors.transparent;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    final indicatorColor = selected
        ? colors.onPrimaryContainer
        : Colors.transparent;
    final badgeFill = selected ? colors.primary : colors.surfaceContainerHigh;
    final badgeForeground = selected
        ? colors.onPrimary
        : colors.onSurfaceVariant;
    final borderColor = selected
        ? colors.primary.withValues(alpha: 0.46)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: fillColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 10, 0),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: badgeFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: badgeForeground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.check_rounded, color: indicatorColor, size: 24),
                  ],
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
  const _ResponsiveFormRow({
    required this.children,
    this.flexes,
    this.breakpoint = 480,
  });

  static const double _spacing = 12;

  final List<Widget> children;
  final List<int>? flexes;
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
              Expanded(
                flex: flexes == null || index >= flexes!.length
                    ? 1
                    : flexes![index],
                child: children[index],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A persistent, keyboard-friendly disclosure section for the course sheet.
/// ExpansionTile keeps its children alive so collapsing a section never clears
/// a text controller or a pending picker selection.
class _EditorSection extends StatelessWidget {
  const _EditorSection({
    super.key,
    required this.icon,
    required this.title,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.enabled,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
        subtitle: subtitle == null ? null : Text(subtitle!),
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

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _SelectionIcon(
                icon: icon,
                enabled: enabled,
                disabledColor: secondaryColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: contentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              Icon(Icons.chevron_right, color: secondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIcon extends StatelessWidget {
  const _SelectionIcon({
    super.key,
    required this.icon,
    required this.enabled,
    required this.disabledColor,
  });

  final IconData icon;
  final bool enabled;
  final Color disabledColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: ShapeDecoration(
        color: colors.primary.withValues(alpha: enabled ? 0.10 : 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Icon(icon, color: enabled ? colors.primary : disabledColor),
    );
  }
}

/// A finite-height alternative to a vertical [SegmentedButton].  The
/// material_ui implementation currently asks for an infinite height when it
/// is placed inside a scrolling bottom sheet.  These connected rows preserve
/// the same single-choice semantics while allowing translated labels to wrap
/// naturally at large text scales.
class _VerticalChoiceList<T> extends StatelessWidget {
  const _VerticalChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_VerticalChoiceOption<T>> options;
  final Set<T> selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedValue = selected.isEmpty ? null : selected.first;
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: colors.outlineVariant),
            _VerticalChoiceRow<T>(
              option: options[index],
              selected: options[index].value == selectedValue,
              enabled: onChanged != null,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(options[index].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerticalChoiceOption<T> {
  const _VerticalChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final Widget label;
  final Widget icon;
}

class _VerticalChoiceRow<T> extends StatelessWidget {
  const _VerticalChoiceRow({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _VerticalChoiceOption<T> option;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled
        ? (selected ? colors.onPrimaryContainer : colors.onSurface)
        : colors.onSurface.withValues(alpha: 0.38);
    final secondary = enabled
        ? (selected ? colors.onPrimaryContainer : colors.onSurfaceVariant)
        : colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
                child: Row(
                  children: [
                    IconTheme(
                      data: IconThemeData(color: secondary, size: 22),
                      child: option.icon,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: foreground,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                        child: option.label,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? colors.primary : secondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseTimeRange extends StatelessWidget {
  const _CourseTimeRange({
    required this.startLabel,
    required this.startValue,
    required this.endLabel,
    required this.endValue,
    required this.enabled,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String startLabel;
  final String startValue;
  final String endLabel;
  final String endValue;
  final bool enabled;
  final VoidCallback? onPickStart;
  final VoidCallback? onPickEnd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Material(
      key: const ValueKey('course-time-range'),
      color: colors.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stacksVertically =
              constraints.maxWidth < 280 || textScale > 1.3;
          final start = _CourseTimeAction(
            key: const ValueKey('course-start-time-action'),
            label: startLabel,
            value: startValue,
            enabled: enabled,
            onTap: onPickStart,
          );
          final end = _CourseTimeAction(
            key: const ValueKey('course-end-time-action'),
            label: endLabel,
            value: endValue,
            enabled: enabled,
            onTap: onPickEnd,
          );
          final secondaryColor = enabled
              ? colors.onSurfaceVariant
              : colors.onSurface.withValues(alpha: 0.38);
          final leadingIcon = ExcludeSemantics(
            child: _SelectionIcon(
              key: const ValueKey('course-time-range-icon-background'),
              icon: Icons.schedule_outlined,
              enabled: enabled,
              disabledColor: secondaryColor,
            ),
          );

          if (stacksVertically) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: leadingIcon,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        start,
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colors.outlineVariant,
                        ),
                        end,
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                leadingIcon,
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    key: const ValueKey('course-time-range-content'),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: start),
                          SizedBox(
                            width: 40,
                            child: Center(
                              child: Icon(
                                Icons.arrow_forward,
                                key: const ValueKey('course-time-range-arrow'),
                                size: 20,
                                color: secondaryColor,
                              ),
                            ),
                          ),
                          Expanded(child: end),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CourseTimeAction extends StatelessWidget {
  const _CourseTimeAction({
    super.key,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final contentColor = enabled
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.38);
    final secondaryColor = enabled
        ? colors.onSurfaceVariant
        : colors.onSurface.withValues(alpha: 0.38);
    final effectiveOnTap = enabled ? onTap : null;
    final interactionShape = skedShapeSchemeOf(context).compact;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: value,
      onTap: effectiveOnTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: effectiveOnTap,
          customBorder: interactionShape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: contentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keep secondary editor dialogs usable on Android's narrow portrait widths.
/// The platform AlertDialog default inset is 40dp, which leaves only 240dp on
/// a 320dp viewport before content padding and trailing actions are measured.
EdgeInsets _editorDialogInsetPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return EdgeInsets.symmetric(horizontal: width < 480 ? 16 : 40, vertical: 24);
}
