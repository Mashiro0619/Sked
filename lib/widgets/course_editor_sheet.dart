import '../theme/sked_surface.dart';

import 'workspace_editor.dart';
import 'workspace_editor_form.dart';
import 'sked_task_session.dart';
import 'sked_mutation_confirmation_dialog.dart';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show listEquals;

import 'sked_floating_surface.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_time_picker.dart';

import 'dart:convert';

import 'editor_exit_guard.dart';
import 'course_system_reminder_field.dart';

import 'dart:async';

import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';

import 'sked_tooltip.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../previews/sked_preview_support.dart';
import '../theme/sked_expressive_theme.dart';
import '../utils/course_custom_fields_draft.dart';
import 'app_modal_sheet.dart';
import 'expressive_dialog.dart';
import 'sked_task_dialog.dart';
import 'sked_adaptive_picker_dialog.dart';
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

class _CourseEditorSheetState extends State<CourseEditorSheet>
    with EditorExitGuard<CourseEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _locationController;
  late final TextEditingController _creditController;
  late final TextEditingController _remarksController;
  late final TextEditingController _customFieldsController;
  late final CourseCustomFieldsDraft _customFieldsDraft;
  final _customFieldsFocus = FocusNode();
  bool _customFieldsInvalid = false;
  late final TextEditingController _reminderMinutesController;

  late int _selectedDayOfWeek;
  late List<int> _selectedSemesterWeeks;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<int> _selectedPeriods;
  late ({int startMinutes, int endMinutes}) _initialDisplayRange;
  late List<int> _initialPeriodSelection;
  late List<int> _initialWeekSelection;
  bool _hasPopped = false;
  bool _pickerOpen = false;
  bool _actionInProgress = false;
  late bool _scheduleSectionExpanded;
  late bool _detailsSectionExpanded;
  late CourseReminderBehavior _reminderBehavior;
  final _detailsExpansion = ExpansibleController();
  final _reminderMinutesFocus = FocusNode();
  bool _reminderMinutesInvalid = false;

  bool _desktopInitialized = false;
  SkedTaskSession? _editorSession;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _editorSession ??= SkedTaskSessionScope.maybeOf(context)?.session;
    if (!_desktopInitialized && WorkbenchChromeMetrics.of(context).desktop) {
      _desktopInitialized = true;
      if (_reminderBehavior != CourseReminderBehavior.inherit) {
        _detailsSectionExpanded = true;
      }
    }
  }

  @override
  Widget guardDiscardConfirmation(Widget dialog) => _editorSession == null
      ? dialog
      : SkedTaskRouteGuard(parent: _editorSession, child: dialog);

  @override
  String get draftFingerprint => jsonEncode([
    _nameController.text,
    _teacherController.text,
    _locationController.text,
    _creditController.text,
    _remarksController.text,
    _customFieldsController.text,
    _reminderMinutesController.text,
    _selectedDayOfWeek,
    _selectedSemesterWeeks,
    _selectedPeriods,
    _startTime.toString(),
    _endTime.toString(),
    _reminderBehavior.name,
  ]);
  @override
  bool get exitBlocked => _blocked;
  @override
  AppMode get editorWorkspace => AppMode.student;
  @override
  void closeEditor() => _popOnce();

  bool get _blocked => _hasPopped || _pickerOpen || _actionInProgress;

  bool get _timeDraftChanged =>
      _minutesFromTimeOfDay(_startTime) != _initialDisplayRange.startMinutes ||
      _minutesFromTimeOfDay(_endTime) != _initialDisplayRange.endMinutes ||
      !listEquals(_selectedPeriods, _initialPeriodSelection);

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
    _customFieldsDraft = CourseCustomFieldsDraft(initial?.customFields ?? {});
    _customFieldsController = TextEditingController(
      text: _customFieldsDraft.initialText,
    );
    final reminder =
        initial?.reminderSettings ?? const CourseReminderSettings();
    _reminderBehavior = reminder.behavior;
    _reminderMinutesController = TextEditingController(
      text: reminder.minutesBefore?.toString() ?? '10',
    );
    _selectedDayOfWeek = initial?.dayOfWeek ?? widget.dayOfWeek;
    _selectedSemesterWeeks = normalizeSemesterWeeks(
      initial == null || initial.semesterWeeks.isEmpty
          ? buildAllSemesterWeeks(widget.totalWeeks)
          : initial.semesterWeeks,
    );
    final initialRange = initial == null
        ? null
        : resolveCourseTimeRange(initial, widget.periodTimes);
    _startTime = _timeOfDayFromMinutes(
      initialRange?.startMinutes ??
          initial?.startMinutes ??
          defaultStartMinutes,
    );
    _endTime = _timeOfDayFromMinutes(
      initialRange?.endMinutes ?? initial?.endMinutes ?? defaultEndMinutes,
    );
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
    _initialDisplayRange = (
      startMinutes: _minutesFromTimeOfDay(_startTime),
      endMinutes: _minutesFromTimeOfDay(_endTime),
    );
    _initialPeriodSelection = List.of(_selectedPeriods);
    _initialWeekSelection = List.of(_selectedSemesterWeeks);
    _scheduleSectionExpanded = true;
    _detailsSectionExpanded =
        _teacherController.text.trim().isNotEmpty ||
        _creditController.text.trim().isNotEmpty ||
        _remarksController.text.trim().isNotEmpty ||
        _customFieldsController.text.trim().isNotEmpty;
    initializeDraftGuard();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _creditController.dispose();
    _remarksController.dispose();
    _customFieldsController.dispose();
    _customFieldsFocus.dispose();
    _reminderMinutesController.dispose();
    _detailsExpansion.dispose();
    _reminderMinutesFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _hasPopped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_blocked) unawaited(requestEditorExit());
      },
      child: AppSheetScaffold.editor(
        onClose: () => unawaited(requestEditorExit()),
        closeEnabled: !_blocked,
        busy: _actionInProgress,
        title: Text(
          widget.initialCourse == null
              ? l10n.addCourseTitle
              : l10n.editCourseTitle,
        ),
        editorActions: SkedEditorActions(
          enabled: !_blocked,
          busy: _actionInProgress,
          onCancel: () => unawaited(requestEditorExit()),
          onSubmit: () => unawaited(_submit()),
          showDelete: widget.initialCourse != null,
          onDelete: widget.initialCourse == null
              ? null
              : () => unawaited(_confirmDelete()),
        ),
        child: _buildFields(l10n),
      ),
    );
  }

  Widget _buildFields(AppLocalizations l10n) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final linkedPeriodsLabel = _formatPeriodsLabel(_selectedPeriods, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ResponsiveEditorFormRow(
          breakpoint: desktop ? double.infinity : 480,
          flexes: const [2, 1],
          children: [
            SkedEditorTextField(
              controlKey: const ValueKey('course-desktop-title'),
              label: l10n.courseName,
              controller: _nameController,
              enabled: !_blocked,
              icon: Icons.book_outlined,
              headline: true,
            ),
            SkedEditorTextField(
              label: l10n.location,
              controller: _locationController,
              enabled: !_blocked,
              icon: Icons.location_on_outlined,
            ),
          ],
        ),
        SizedBox(height: desktop ? 16 : 12),
        if (desktop)
          _buildScheduleFields(l10n)
        else
          WorkspaceEditorDisclosure(
            icon: Icons.event_note_outlined,
            title: '${l10n.dayOfWeek} · ${l10n.time}',
            subtitle: _selectedPeriods.isEmpty
                ? l10n.linkedPeriodsUnmatched
                : linkedPeriodsLabel,
            initiallyExpanded: _scheduleSectionExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _scheduleSectionExpanded = expanded),
            enabled: !_blocked,
            child: _buildScheduleFields(l10n),
          ),
        SizedBox(height: desktop ? 16 : 8),
        WorkspaceEditorDisclosure(
          key: const ValueKey('course-details-section'),
          controller: _detailsExpansion,
          compact: desktop,
          icon: Icons.notes_outlined,
          title: l10n.more,
          subtitle: desktop || _detailsSectionExpanded
              ? null
              : '${l10n.courseSystemReminder} · ${_reminderSummary(l10n)}',
          initiallyExpanded: _detailsSectionExpanded,
          onExpansionChanged: (expanded) =>
              setState(() => _detailsSectionExpanded = expanded),
          enabled: !_blocked,
          child: _buildDetailsFields(l10n),
        ),
      ],
    );
  }

  Widget _buildScheduleFields(AppLocalizations l10n) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final localeCode = app_locale.localeCodeFromLocale(
      Localizations.localeOf(context),
    );
    final weekdayLabel = formatDayOfWeekLabel(
      _selectedDayOfWeek,
      localeCode: localeCode,
    );
    final weeksLabel = formatSemesterWeeksLabel(
      _selectedSemesterWeeks,
      totalWeeks: widget.totalWeeks,
      localeCode: localeCode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkedEditorFormRow(
          breakpoint: 520,
          minimumChildWidths: desktop
              ? [
                  workspaceEditorMinimumFieldWidth(
                    context,
                    label: l10n.dayOfWeek,
                    value: weekdayLabel,
                    minimumWidth: 136,
                  ),
                  workspaceEditorMinimumFieldWidth(
                    context,
                    label: l10n.semesterWeeks,
                    value: weeksLabel,
                    minimumWidth: 176,
                  ),
                ]
              : const [],
          children: [
            SkedEditorValueField(
              key: _weekdayAnchor,
              label: l10n.dayOfWeek,
              value: weekdayLabel,
              icon: Icons.today_outlined,
              enabled: !_blocked,
              onPressed: _blocked ? null : (_) => _pickDayOfWeek(),
            ),
            SkedEditorValueField(
              key: _weeksAnchor,
              label: l10n.semesterWeeks,
              value: weeksLabel,
              icon: Icons.edit_calendar,
              enabled: !_blocked,
              onPressed: _blocked ? null : (_) => _pickSemesterWeeks(),
            ),
          ],
        ),
        SizedBox(height: desktop ? 12 : 8),
        _CourseTimeRange(
          startLabel: l10n.startTime,
          startValue: _formatTimeOfDay(_startTime),
          endLabel: l10n.endTime,
          endValue: _formatTimeOfDay(_endTime),
          enabled: !_blocked,
          onPickStart: _blocked
              ? null
              : (anchor) => _pickTime(isStart: true, anchorContext: anchor),
          onPickEnd: _blocked
              ? null
              : (anchor) => _pickTime(isStart: false, anchorContext: anchor),
        ),
        SizedBox(height: desktop ? 12 : 8),
        if (desktop)
          WorkspaceEditorFieldsRow(
            minimumChildWidths: [
              workspaceEditorMinimumFieldWidth(
                context,
                label: l10n.linkedPeriods,
                value: _selectedPeriods.isEmpty
                    ? l10n.linkedPeriodsUnmatched
                    : _formatPeriodsLabel(_selectedPeriods, l10n),
                minimumWidth: 176,
              ),
            ],
            children: [_buildPeriodsField(l10n)],
          )
        else
          _buildPeriodsField(l10n),
      ],
    );
  }

  Widget _buildPeriodsField(AppLocalizations l10n) => SkedEditorValueField(
    key: _periodsAnchor,
    label: l10n.linkedPeriods,
    value: _selectedPeriods.isEmpty
        ? l10n.linkedPeriodsUnmatched
        : _formatPeriodsLabel(_selectedPeriods, l10n),
    icon: Icons.tune,
    enabled: !_blocked,
    onPressed: _blocked ? null : (_) => _pickPeriods(),
  );

  String _reminderSummary(AppLocalizations l10n) => switch (_reminderBehavior) {
    CourseReminderBehavior.inherit => l10n.courseReminderUseDefault,
    CourseReminderBehavior.disabled => l10n.notificationReminderOff,
    CourseReminderBehavior.custom => switch (int.tryParse(
      _reminderMinutesController.text.trim(),
    )) {
      final int minutes when minutes >= 0 => l10n.notificationReminderCustom(
        minutes,
      ),
      _ => l10n.recurrenceCustom,
    },
  };

  Widget _buildDetailsFields(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SkedEditorFormRow(
        flexes: const [1, 0],
        minimumChildWidths: [
          workspaceEditorMinimumFieldWidth(
            context,
            label: l10n.teacherName,
            minimumWidth: 160,
          ),
          workspaceEditorMinimumFieldWidth(
            context,
            label: l10n.credits,
            minimumWidth: 96,
          ),
        ],
        children: [
          SkedEditorTextField(
            label: l10n.teacherName,
            controller: _teacherController,
            enabled: !_blocked,
            icon: Icons.badge_outlined,
          ),
          SkedEditorTextField(
            label: l10n.credits,
            controller: _creditController,
            enabled: !_blocked,
            icon: Icons.payments_outlined,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SkedEditorTextField(
        label: l10n.remarks,
        controller: _remarksController,
        enabled: !_blocked,
        icon: Icons.notes_outlined,
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      _buildCustomFieldsField(l10n),
      const SizedBox(height: 16),
      _buildReminderField(l10n),
    ],
  );

  Widget _buildCustomFieldsField(AppLocalizations l10n) {
    final desktop = WorkbenchChromeMetrics.of(context).desktop;
    final usesJson = _customFieldsDraft.usesJson;
    return SkedEditorTextField(
      controlKey: const ValueKey('course-custom-fields'),
      label: l10n.customFields,
      controller: _customFieldsController,
      focusNode: _customFieldsFocus,
      enabled: !_blocked,
      icon: Icons.data_object_outlined,
      maxLines: usesJson ? 6 : (desktop ? 2 : 3),
      onChanged: (_) {
        if (_customFieldsInvalid) setState(() => _customFieldsInvalid = false);
      },
      hintText: usesJson ? null : l10n.customFieldsHint,
      helperText: usesJson ? l10n.jsonContent : null,
      helperMaxLines: 2,
      error: _customFieldsInvalid ? Text(l10n.customFieldsInvalidJson) : null,
    );
  }

  Widget _buildReminderField(AppLocalizations l10n) =>
      CourseSystemReminderField(
        key: const ValueKey('course-reminder-section'),
        behavior: _reminderBehavior,
        minutesController: _reminderMinutesController,
        minutesFocusNode: _reminderMinutesFocus,
        minutesError: _reminderMinutesInvalid
            ? l10n.courseReminderInvalidMinutes
            : null,
        onMinutesChanged: (_) =>
            setState(() => _reminderMinutesInvalid = false),
        enabled: !_blocked,
        onChanged: (value) => setState(() {
          _reminderBehavior = value;
          _reminderMinutesInvalid = false;
        }),
      );

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

  final _weekdayAnchor = GlobalKey();
  final _weeksAnchor = GlobalKey();
  final _periodsAnchor = GlobalKey();

  Future<void> _pickDayOfWeek() async {
    if (_blocked) {
      return;
    }
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    try {
      final result = await showSkedAdaptivePickerDialog<int>(
        context: context,
        routeName: 'course-DayOfWeek-picker',
        anchorContext: _weekdayAnchor.currentContext,
        preferredWidth: 300,
        workspace: AppMode.student,
        placement: SkedFloatingPlacement.left,
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
      final result = await showSkedAdaptivePickerDialog<List<int>>(
        context: context,
        routeName: 'course-SemesterWeeks-picker',
        anchorContext: _weeksAnchor.currentContext,
        preferredWidth: 340,
        workspace: AppMode.student,
        placement: SkedFloatingPlacement.left,
        builder: (context) {
          var popped = false;
          return StatefulBuilder(
            builder: (context, setState) {
              final l10n = AppLocalizations.of(context);
              final desktop = WorkbenchChromeMetrics.of(context).desktop;
              void popWith(List<int>? value) {
                if (popped) return;
                popped = true;
                Navigator.of(context).pop(value);
              }

              return SkedTaskDialog(
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
                            if (desktop)
                              for (final parity in [1, 0])
                                TextButton(
                                  onPressed: () => setState(() {
                                    draft
                                      ..clear()
                                      ..addAll(
                                        buildAllSemesterWeeks(
                                          widget.totalWeeks,
                                        ).where((week) => week % 2 == parity),
                                      );
                                  }),
                                  child: Text(
                                    parity == 1 ? '1, 3, 5…' : '2, 4, 6…',
                                  ),
                                ),
                            TextButton(
                              onPressed: () => setState(() => draft.clear()),
                              child: Text(l10n.clear),
                            ),
                          ],
                        ),
                      ),
                      if (desktop)
                        Text('${draft.length} / ${widget.totalWeeks}'),
                      if (draft.isEmpty)
                        Text(
                          l10n.selectAtLeastOneWeek,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: GridView.builder(
                          shrinkWrap: true,
                          itemCount: widget.totalWeeks,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: desktop ? 5 : 4,
                                mainAxisSpacing: desktop ? 4 : 8,
                                crossAxisSpacing: desktop ? 4 : 8,
                                mainAxisExtent: desktop
                                    ? 36 *
                                          WorkbenchChromeMetrics.of(context)
                                              .textScale
                                    : 48,
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
                                      : desktop
                                      ? Colors.transparent
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                    desktop ? 6 : 12,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      desktop ? 6 : 12,
                                    ),
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
                                                  ? skedReadableAccent(
                                                      colorScheme,
                                                      surface: colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                    )
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
                    onPressed: draft.isEmpty
                        ? null
                        : () => popWith(normalizeSemesterWeeks(draft.toList())),
                    child: Text(l10n.confirm),
                  ),
                ],
              );
            },
          );
        },
      );
      if (!mounted || result == null || result.isEmpty) {
        return;
      }
      setState(() {
        _selectedSemesterWeeks = result;
      });
    } finally {
      _setPickerOpen(false);
    }
  }

  Future<void> _pickTime({
    required bool isStart,
    required BuildContext anchorContext,
  }) async {
    if (_blocked) {
      return;
    }
    _setPickerOpen(true);
    _dismissActiveInputFocus();
    try {
      final initialTime = isStart ? _startTime : _endTime;
      final picked = await showSkedTimePicker(
        context: context,
        initialTime: initialTime,
        anchorContext: anchorContext,
        workspace: AppMode.student,
        alwaysUse24HourFormat: true,
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
      final result = await showSkedAdaptivePickerDialog<List<int>>(
        context: context,
        routeName: 'course-Periods-picker',
        anchorContext: _periodsAnchor.currentContext,
        preferredWidth: 320,
        workspace: AppMode.student,
        placement: SkedFloatingPlacement.left,
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

              return SkedTaskDialog(
                insetPadding: _editorDialogInsetPadding(context),
                title: Text(l10n.selectLinkedPeriods),
                content: ExpressiveDialogContent(
                  maxWidth: 360,
                  child: WorkbenchChromeMetrics.of(context).desktop
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final period in widget.periodTimes)
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    title: Text(
                                      l10n.periodNumberLabel(period.index),
                                    ),
                                    subtitle: Text(
                                      '${_formatTimeOfDay(TimeOfDay(hour: period.startMinutes ~/ 60, minute: period.startMinutes % 60))} – ${_formatTimeOfDay(TimeOfDay(hour: period.endMinutes ~/ 60, minute: period.endMinutes % 60))}',
                                    ),
                                    value: draft.contains(period.index),
                                    onChanged: (_) => setState(() {
                                      final next = _togglePeriodSelection(
                                        draft,
                                        period.index,
                                      );
                                      draft
                                        ..clear()
                                        ..addAll(next);
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final period in widget.periodTimes)
                              ChoiceChip(
                                label: Text(
                                  l10n.periodNumberLabel(period.index),
                                ),
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
    final initial = widget.initialCourse;
    final preserveInitialTime = initial != null && !_timeDraftChanged;
    final startMinutes = preserveInitialTime
        ? initial.startMinutes
        : _minutesFromTimeOfDay(_startTime);
    final endMinutes = preserveInitialTime
        ? initial.endMinutes
        : _minutesFromTimeOfDay(_endTime);
    final preserveUnknownTime =
        preserveInitialTime && startMinutes == 0 && endMinutes == 0;
    final l10n = AppLocalizations.of(context);
    if (_selectedSemesterWeeks.isEmpty) {
      showUiFailureFeedback(
        context: context,
        message: l10n.selectAtLeastOneWeek,
      );
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        (!preserveUnknownTime && startMinutes >= endMinutes)) {
      showUiFailureFeedback(
        context: context,
        message: _nameController.text.trim().isEmpty
            ? l10n.eventTitleRequired
            : l10n.endTimeMustBeLater,
      );
      return;
    }

    final Map<String, dynamic> customFields;
    try {
      customFields = _customFieldsDraft.parse(_customFieldsController.text);
    } on FormatException {
      setState(() => _customFieldsInvalid = true);
      _detailsExpansion.expand();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _blocked) return;
        _customFieldsFocus.requestFocus();
        final fieldContext = _customFieldsFocus.context;
        if (fieldContext != null) {
          unawaited(
            Scrollable.ensureVisible(
              fieldContext,
              alignment: 0.5,
              duration: SkedMotionPolicy.of(context)
                  .effects(SkedMotionSpeed.fast),
            ),
          );
        }
      });
      return;
    }

    final reminderMinutes = int.tryParse(
      _reminderMinutesController.text.trim(),
    );
    if (_reminderBehavior == CourseReminderBehavior.custom &&
        (reminderMinutes == null || reminderMinutes < 0)) {
      setState(() => _reminderMinutesInvalid = true);
      _detailsExpansion.expand();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _blocked) return;
        _reminderMinutesFocus.requestFocus();
        final fieldContext = _reminderMinutesFocus.context;
        if (fieldContext != null) {
          unawaited(
            Scrollable.ensureVisible(
              fieldContext,
              alignment: 0.5,
              duration: SkedMotionPolicy.of(context)
                  .effects(SkedMotionSpeed.fast),
            ),
          );
        }
      });
      return;
    }

    final periods = preserveInitialTime
        ? initial.periods
        : _normalizeSelectedPeriods(_selectedPeriods);
    final course = CourseItem(
      id:
          widget.initialCourse?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      teacher: _teacherController.text.trim(),
      location: _locationController.text.trim(),
      dayOfWeek: _selectedDayOfWeek,
      semesterWeeks:
          initial != null &&
              listEquals(_selectedSemesterWeeks, _initialWeekSelection)
          ? initial.semesterWeeks
          : normalizeSemesterWeeks(_selectedSemesterWeeks),
      periods: periods,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      timeRange: preserveInitialTime
          ? initial.timeRange
          : buildTimeRange(startMinutes, endMinutes),
      credit: _parseCredit(_creditController.text),
      remarks: _remarksController.text.trim(),
      customFields: customFields,
      reminderSettings: _courseReminderSettings,
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
    // _submit validates before constructing a course, even while More is folded.
    final minutes = int.parse(_reminderMinutesController.text.trim());
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
        session: _editorSession,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return SkedMutationConfirmationDialog(
            workspace: AppMode.student,
            title: l10n.deleteCourseTitle,
            message: l10n.deleteCourseMessage,
            confirmLabel: l10n.delete,
            debugLabel: 'Delete course',
            onConfirm: widget.onDelete,
            filledConfirmButton: false,
            insetPadding: _editorDialogInsetPadding(dialogContext),
          );
        },
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
    if (!mounted || _hasPopped) return;
    setState(() => _hasPopped = true);
    completeEditorRoute(context, result);
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

    if (SkedTaskDialogScope.maybeOf(context) != null) {
      return SkedTaskDialog(
        title: Text(l10n.selectDayOfWeek),
        content: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = (constraints.maxWidth / (36 * scale)).floor().clamp(
              1,
              7,
            );
            final width = constraints.maxWidth / columns;
            return Focus(
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key != LogicalKeyboardKey.arrowLeft &&
                    key != LogicalKeyboardKey.arrowRight &&
                    key != LogicalKeyboardKey.arrowUp &&
                    key != LogicalKeyboardKey.arrowDown) {
                  return KeyEventResult.ignored;
                }
                final rtl = Directionality.of(context) == TextDirection.rtl;
                final forward =
                    key == LogicalKeyboardKey.arrowDown ||
                    key ==
                        (rtl
                            ? LogicalKeyboardKey.arrowLeft
                            : LogicalKeyboardKey.arrowRight);
                if (forward) {
                  FocusManager.instance.primaryFocus?.nextFocus();
                } else {
                  FocusManager.instance.primaryFocus?.previousFocus();
                }
                return KeyEventResult.handled;
              },
              child: Wrap(
                children: [
                  for (var day = 1; day <= 7; day++)
                    SizedBox(
                      width: width,
                      height: 40 * scale,
                      child: SkedTooltip(
                        message: formatDayOfWeekLabel(
                          day,
                          localeCode: localeCode,
                        ),
                        child: SkedEditorOption(
                          compact: true,
                          selected: day == selectedDay,
                          label: formatWeekdayShortLabel(
                            day,
                            localeCode: localeCode,
                          ),
                          semanticLabel: formatDayOfWeekLabel(
                            day,
                            localeCode: localeCode,
                          ),
                          onPressed: () => onSelect(day),
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
    return SkedTaskDialog(
      insetPadding: _editorDialogInsetPadding(context),
      title: Text(l10n.selectDayOfWeek),
      scrollable: true,
      // Responsive option rows need a real width before native dialog layout.
      // The route's available width still narrows this on small screens.
      constraints: const BoxConstraints(minWidth: 352, maxWidth: 352),
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
  Widget build(BuildContext context) => SkedEditorOption(
    label: label,
    leading: ExcludeSemantics(child: Text(shortLabel)),
    selected: selected,
    onPressed: onTap,
  );
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

  final String startLabel, startValue, endLabel, endValue;
  final bool enabled;
  final ValueChanged<BuildContext>? onPickStart, onPickEnd;

  @override
  Widget build(BuildContext context) {
    final start = SkedEditorValueAction(
      key: const ValueKey('course-start-time-action'),
      label: startLabel,
      value: startValue,
      enabled: enabled,
      onPressed: onPickStart,
    );
    final end = SkedEditorValueAction(
      key: const ValueKey('course-end-time-action'),
      label: endLabel,
      value: endValue,
      enabled: enabled,
      onPressed: onPickEnd,
    );
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return SkedEditorFormRow(
        minimumChildWidths: [
          workspaceEditorMinimumFieldWidth(
            context,
            label: startLabel,
            value: startValue,
            minimumWidth: 112,
          ),
          workspaceEditorMinimumFieldWidth(
            context,
            label: endLabel,
            value: endValue,
            minimumWidth: 112,
          ),
        ],
        children: [
          WorkspaceEditorField(label: startLabel, child: start),
          WorkspaceEditorField(label: endLabel, child: end),
        ],
      );
    }
    final colors = Theme.of(context).colorScheme;
    final leadingIcon = ExcludeSemantics(
      child: SkedEditorSelectionIcon(
        key: const ValueKey('course-time-range-icon-background'),
        icon: Icons.schedule_outlined,
        enabled: enabled,
      ),
    );
    return Material(
      key: const ValueKey('course-time-range'),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stacksVertically =
              constraints.maxWidth < 280 || textScale > 1.3;
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
                                color: enabled
                                    ? colors.onSurfaceVariant
                                    : colors.onSurface.withValues(alpha: .38),
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

/// Keep secondary editor dialogs usable on Android's narrow portrait widths.
/// The platform AlertDialog default inset is 40dp, which leaves only 240dp on
/// a 320dp viewport before content padding and trailing actions are measured.
EdgeInsets _editorDialogInsetPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return EdgeInsets.symmetric(horizontal: width < 480 ? 16 : 40, vertical: 24);
}
