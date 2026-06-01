import 'package:flutter/material.dart';

import '../l10n/app_locale.dart' as app_locale;
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import 'expressive_dialog.dart';

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
  });

  final List<CoursePeriodTime> periodTimes;
  final int totalWeeks;
  final int dayOfWeek;
  final CourseItem? initialCourse;
  final int? initialStartMinutes;
  final int? initialEndMinutes;
  final List<int>? initialPeriods;

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

  late int _selectedDayOfWeek;
  late List<int> _selectedSemesterWeeks;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<int> _selectedPeriods;
  bool _hasPopped = false;
  bool _pickerOpen = false;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _creditController.dispose();
    _remarksController.dispose();
    _customFieldsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final linkedPeriods = _selectedPeriods;
    final linkedPeriodsLabel = _formatPeriodsLabel(linkedPeriods, l10n);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.66,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.initialCourse == null
                            ? l10n.addCourseTitle
                            : l10n.editCourseTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsiveFormRow(
                        flexes: const [2, 1],
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: l10n.courseName,
                              prefixIcon: const Icon(Icons.book_outlined),
                            ),
                          ),
                          TextField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              labelText: l10n.location,
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveFormRow(
                        breakpoint: 520,
                        children: [
                          _SelectionTile(
                            title: l10n.dayOfWeek,
                            subtitle: formatDayOfWeekLabel(
                              _selectedDayOfWeek,
                              localeCode: app_locale.localeCodeFromLocale(
                                Localizations.localeOf(context),
                              ),
                            ),
                            icon: Icons.today_outlined,
                            enabled: !_pickerOpen && !_hasPopped,
                            onTap: (_pickerOpen || _hasPopped)
                                ? null
                                : _pickDayOfWeek,
                          ),
                          _SelectionTile(
                            title: l10n.semesterWeeks,
                            subtitle: formatSemesterWeeksLabel(
                              _selectedSemesterWeeks,
                              totalWeeks: widget.totalWeeks,
                              localeCode: app_locale.localeCodeFromLocale(
                                Localizations.localeOf(context),
                              ),
                            ),
                            icon: Icons.edit_calendar,
                            enabled: !_pickerOpen && !_hasPopped,
                            onTap: (_pickerOpen || _hasPopped)
                                ? null
                                : _pickSemesterWeeks,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ResponsiveFormRow(
                        breakpoint: 520,
                        children: [
                          _SelectionTile(
                            title: l10n.startTime,
                            subtitle: _formatTimeOfDay(_startTime),
                            icon: Icons.schedule,
                            enabled: !_pickerOpen && !_hasPopped,
                            onTap: (_pickerOpen || _hasPopped)
                                ? null
                                : () => _pickTime(isStart: true),
                          ),
                          _SelectionTile(
                            title: l10n.endTime,
                            subtitle: _formatTimeOfDay(_endTime),
                            icon: Icons.schedule,
                            enabled: !_pickerOpen && !_hasPopped,
                            onTap: (_pickerOpen || _hasPopped)
                                ? null
                                : () => _pickTime(isStart: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SelectionTile(
                        title: l10n.linkedPeriods,
                        subtitle: linkedPeriods.isEmpty
                            ? l10n.linkedPeriodsUnmatched
                            : linkedPeriodsLabel,
                        icon: Icons.tune,
                        enabled: !_pickerOpen && !_hasPopped,
                        onTap: (_pickerOpen || _hasPopped)
                            ? null
                            : _pickPeriods,
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveFormRow(
                        children: [
                          TextField(
                            controller: _teacherController,
                            decoration: InputDecoration(
                              labelText: l10n.teacherName,
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                          ),
                          TextField(
                            controller: _creditController,
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
                        decoration: InputDecoration(
                          labelText: l10n.remarks,
                          prefixIcon: const Icon(Icons.notes_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customFieldsController,
                        decoration: InputDecoration(
                          labelText: l10n.customFields,
                          hintText: l10n.customFieldsHint,
                          prefixIcon: const Icon(Icons.data_object_outlined),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExpressiveActionArea(
                leading: widget.initialCourse == null
                    ? null
                    : TextButton(
                        onPressed: _hasPopped
                            ? null
                            : () => _confirmDelete(context),
                        child: Text(l10n.delete),
                      ),
                actions: [
                  TextButton(
                    onPressed: _hasPopped ? null : () => _popOnce(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: _hasPopped ? null : _submit,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    if (_pickerOpen || _hasPopped) {
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

          return AlertDialog(
            title: Text(AppLocalizations.of(context).selectDayOfWeek),
            content: ExpressiveDialogContent(
              maxWidth: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < 7; index++)
                    ExpressiveDialogOption(
                      title: Text(
                        formatDayOfWeekLabel(
                          index + 1,
                          localeCode: app_locale.localeCodeFromLocale(
                            Localizations.localeOf(context),
                          ),
                        ),
                      ),
                      leading: const Icon(Icons.calendar_today_outlined),
                      selected: index + 1 == _selectedDayOfWeek,
                      onTap: () => popWith(index + 1),
                    ),
                ],
              ),
            ),
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
    if (_pickerOpen || _hasPopped) {
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
                                childAspectRatio: 1.6,
                              ),
                          itemBuilder: (context, index) {
                            final week = index + 1;
                            final selected = draft.contains(week);
                            final colorScheme = Theme.of(context).colorScheme;
                            return Material(
                              color: selected
                                  ? colorScheme.primary.withValues(alpha: 0.12)
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
                                              : colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
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
    if (_pickerOpen || _hasPopped) {
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
    if (_pickerOpen || _hasPopped) {
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

  void _submit() {
    final startMinutes = _minutesFromTimeOfDay(_startTime);
    final endMinutes = _minutesFromTimeOfDay(_endTime);
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty || startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _nameController.text.trim().isEmpty
                ? l10n.eventTitleRequired
                : l10n.endTimeMustBeLater,
          ),
          duration: const Duration(seconds: 2),
        ),
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
    );
    _popOnce(CourseEditorResult.save(course));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCourseTitle),
        content: Text(l10n.deleteCourseMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && !_hasPopped) {
      _popOnce(const CourseEditorResult.delete());
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
              Container(
                width: 42,
                height: 42,
                decoration: ShapeDecoration(
                  color: colors.primary.withValues(
                    alpha: enabled ? 0.10 : 0.05,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Icon(
                  icon,
                  color: enabled ? colors.primary : secondaryColor,
                ),
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
