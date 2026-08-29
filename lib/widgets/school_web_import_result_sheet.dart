import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../theme/sked_expressive_theme.dart';
import 'app_modal_sheet.dart';
import 'period_time_set_picker_dialog.dart';

class SchoolWebImportResultSheet extends StatefulWidget {
  const SchoolWebImportResultSheet({
    super.key,
    required this.response,
    required this.canReplaceCurrent,
    required this.initialPeriodTimeSetId,
    required this.provider,
  });

  final SchoolImportResponse response;
  final bool canReplaceCurrent;
  final String initialPeriodTimeSetId;
  final TimetableProvider provider;

  @override
  State<SchoolWebImportResultSheet> createState() =>
      _SchoolWebImportResultSheetState();
}

class _SchoolWebImportResultSheetState
    extends State<SchoolWebImportResultSheet> {
  late final TextEditingController _nameController;
  late DateTime _startDate;
  late String _selectedPeriodTimeSetId;
  late bool _importBundledPeriodTimeSet;
  bool _detailsExpanded = false;
  bool _hasPopped = false;
  bool _pickerOpen = false;

  bool get _hasBundledPeriodTimeSet =>
      widget.response.timetable.periodTimeSet.periodTimes.isNotEmpty;

  /// Do not retain a sheet-open-time snapshot here. The picker can create,
  /// edit, or delete sets while this sheet stays open, and its selection has to
  /// resolve against the same source that ultimately validates the import.
  List<PeriodTimeSet> get _periodTimeSets => widget.provider.periodTimeSets;

  bool get _canDiscardBundledPeriodTimeSet => _periodTimeSets.isNotEmpty;

  bool get _canSubmitImport =>
      widget.response.timetable.courses.isNotEmpty &&
      (_importBundledPeriodTimeSet || _selectedExistingPeriodTimeSet() != null);

  bool get _hasParserDetails =>
      widget.response.meta.pageTitle.trim().isNotEmpty ||
      widget.response.meta.parser.trim().isNotEmpty;

  bool get _blocked => _hasPopped || _pickerOpen;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.response.timetable.name,
    )..addListener(_handleNameChanged);
    _startDate = normalizeDateOnly(widget.response.timetable.startDate);
    _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(
      widget.initialPeriodTimeSetId,
    );
    _importBundledPeriodTimeSet = _hasBundledPeriodTimeSet;
    widget.provider.addListener(_handlePeriodTimeSetsChanged);
  }

  @override
  void didUpdateWidget(covariant SchoolWebImportResultSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider)) {
      oldWidget.provider.removeListener(_handlePeriodTimeSetsChanged);
      widget.provider.addListener(_handlePeriodTimeSetsChanged);
      _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(
        _selectedPeriodTimeSetId,
      );
    }
  }

  void _handleNameChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.provider.removeListener(_handlePeriodTimeSetsChanged);
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _handlePeriodTimeSetsChanged() {
    if (!mounted) {
      return;
    }
    final resolved = _resolvedPeriodTimeSetId(_selectedPeriodTimeSetId);
    setState(() => _selectedPeriodTimeSetId = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timetable = widget.response.timetable;
    final warnings = widget.response.meta.warnings;
    final mediaQuery = MediaQuery.of(context);
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final sheetHeightFactor = keyboardVisible
        ? 1.0
        : mediaQuery.size.height < 700
        ? 0.96
        : 0.84;
    final selectedPeriodTimeSet = _selectedExistingPeriodTimeSet();
    final existingPeriodTimeSetSelector = _CompactActionRow(
      title: Text(l10n.selectPeriodTimeSet),
      subtitle: Text(
        selectedPeriodTimeSet == null
            ? l10n.noPeriodTimeAvailable
            : l10n.periodTimeSetSummary(
                selectedPeriodTimeSet.name,
                selectedPeriodTimeSet.periodTimes.length,
              ),
      ),
      leadingIcon: Icons.schedule_outlined,
      trailingIcon: Icons.keyboard_arrow_down,
      enabled: _periodTimeSets.isNotEmpty && !_blocked,
      onTap: _periodTimeSets.isEmpty || _blocked
          ? null
          : () async {
              final result = await _runPicker(
                () => showPeriodTimeSetPickerDialog(
                  context,
                  provider: widget.provider,
                  selectedPeriodTimeSetId: _selectedPeriodTimeSetId,
                ),
              );
              if (!mounted || result == null) {
                return;
              }
              setState(
                () =>
                    _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(result),
              );
            },
    );
    final periodTimeSetContent = _hasBundledPeriodTimeSet
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PeriodTimeSetImportChoices(
                title: l10n.importPeriodTimeSetDialogTitle,
                importBundled: _importBundledPeriodTimeSet,
                importBundledTitle: l10n.importBundledPeriodTimeSets,
                importBundledSubtitle: l10n.periodTimeSetSummary(
                  _resolvedBundledPeriodTimeSetName(),
                  timetable.periodTimeSet.periodTimes.length,
                ),
                discardTitle: l10n.discardBundledPeriodTimeSets,
                discardSubtitle: _canDiscardBundledPeriodTimeSet
                    ? (selectedPeriodTimeSet == null
                          ? l10n.noPeriodTimeAvailable
                          : l10n.periodTimeSetSummary(
                              selectedPeriodTimeSet.name,
                              selectedPeriodTimeSet.periodTimes.length,
                            ))
                    : l10n.importDiscardPeriodTimeSetUnavailable,
                enabled: !_blocked,
                canDiscard: _canDiscardBundledPeriodTimeSet,
                onImportBundled: () {
                  setState(() => _importBundledPeriodTimeSet = true);
                },
                onDiscardBundled: () {
                  setState(() => _importBundledPeriodTimeSet = false);
                },
              ),
              if (!_importBundledPeriodTimeSet) ...[
                Divider(
                  height: 1,
                  indent: 52,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                existingPeriodTimeSetSelector,
              ],
            ],
          )
        : existingPeriodTimeSetSelector;

    return AppSheetScaffold(
      heightFactor: sheetHeightFactor,
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      title: Text(l10n.schoolWebImportPreview),
      footer: _ImportPreviewActions(
        canReplaceCurrent: widget.canReplaceCurrent,
        canSubmit: _canSubmitImport && !_hasPopped,
        onCancel: _hasPopped ? null : _cancel,
        onAddAsNew: _canSubmitImport && !_hasPopped
            ? () => _submit(TimetableImportMode.addAsNew)
            : null,
        onReplace: _canSubmitImport && !_hasPopped
            ? () => _submit(TimetableImportMode.replaceActive)
            : null,
      ),
      child: FocusScope(
        canRequestFocus: !_blocked,
        child: AbsorbPointer(
          absorbing: _hasPopped,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                minLines: 1,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.timetableName,
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.table_chart_outlined),
                ),
              ),
              const SizedBox(height: 12),
              _ImportFormSummary(
                date: _CompactActionRow(
                  key: const ValueKey('school-import-start-date-tile'),
                  title: Text(l10n.semesterStartDate),
                  subtitle: Text(_formatDate(_startDate)),
                  leadingIcon: Icons.calendar_today_outlined,
                  trailingIcon: Icons.chevron_right,
                  enabled: !_blocked,
                  onTap: _blocked ? null : _pickStartDate,
                ),
                courseCount: l10n.schoolWebImportCourseCount(
                  timetable.courses.length,
                ),
                periodTimeSetContent: periodTimeSetContent,
              ),
              if (_hasParserDetails) ...[
                const SizedBox(height: 20),
                _ParserDetailsDisclosure(
                  expanded: _detailsExpanded,
                  title: l10n.schoolWebImportParserDetails,
                  expandLabel: l10n.schoolWebImportExpandParserDetails,
                  collapseLabel: l10n.schoolWebImportCollapseParserDetails,
                  pageTitleLabel: l10n.schoolWebImportPageTitleLabel,
                  pageTitle: widget.response.meta.pageTitle,
                  parserLabel: l10n.schoolImportParserSourceTitle,
                  parser: widget.response.meta.parser,
                  onChanged: _blocked
                      ? null
                      : (expanded) {
                          setState(() => _detailsExpanded = expanded);
                        },
                ),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 20),
                _ImportWarningsGroup(
                  title: l10n.schoolWebImportWarnings,
                  warnings: warnings,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PeriodTimeSet? _selectedExistingPeriodTimeSet() {
    for (final item in _periodTimeSets) {
      if (item.id == _selectedPeriodTimeSetId) {
        return item;
      }
    }
    return null;
  }

  String _resolvedPeriodTimeSetId(String preferredId) {
    final periodTimeSets = _periodTimeSets;
    if (periodTimeSets.any((item) => item.id == preferredId)) {
      return preferredId;
    }

    final activeId = widget.provider.activePeriodTimeSetOrNull?.id;
    if (activeId != null && periodTimeSets.any((item) => item.id == activeId)) {
      return activeId;
    }

    return periodTimeSets.isEmpty ? '' : periodTimeSets.first.id;
  }

  String _resolvedBundledPeriodTimeSetName() {
    final bundledName = widget.response.timetable.periodTimeSet.name.trim();
    if (bundledName.isNotEmpty) {
      return bundledName;
    }
    final editedTimetableName = _nameController.text.trim();
    final timetableName = editedTimetableName.isNotEmpty
        ? editedTimetableName
        : (widget.response.timetable.name.trim().isNotEmpty
              ? widget.response.timetable.name.trim()
              : untitledTimetableName(localeCode: widget.provider.localeCode));
    return importedPeriodTimeSetName(
      timetableName,
      localeCode: widget.provider.localeCode,
    );
  }

  Future<void> _pickStartDate() async {
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2035);
    final boundedInitialDate = _startDate.isBefore(firstDate)
        ? firstDate
        : _startDate.isAfter(lastDate)
        ? lastDate
        : _startDate;
    final picked = await _runPicker(
      () => showDatePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDate: boundedInitialDate,
      ),
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _startDate = picked);
  }

  Future<T?> _runPicker<T>(Future<T?> Function() picker) async {
    if (_pickerOpen || _hasPopped) {
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

  void _submit(TimetableImportMode mode) {
    if (_hasPopped) {
      return;
    }
    final selectedPeriodTimeSet = _selectedExistingPeriodTimeSet();
    if (!_importBundledPeriodTimeSet && selectedPeriodTimeSet == null) {
      // A period-time-set mutation may arrive between the last build and this
      // tap. Never hand the workflow an ID that no longer exists; repair the
      // local selection and leave the preview open so the user can retry.
      final resolved = _resolvedPeriodTimeSetId(_selectedPeriodTimeSetId);
      if (resolved != _selectedPeriodTimeSetId) {
        setState(() => _selectedPeriodTimeSetId = resolved);
      }
      return;
    }
    final editedName = _nameController.text.trim();
    final nextResponse = widget.response.copyWith(
      timetable: widget.response.timetable.copyWith(
        name: editedName,
        startDate: _startDate,
      ),
    );
    setState(() => _hasPopped = true);
    Navigator.of(context).pop(
      SchoolImportApplyRequest(
        response: nextResponse,
        mode: mode,
        importBundledPeriodTimeSet: _importBundledPeriodTimeSet,
        targetPeriodTimeSetId: _importBundledPeriodTimeSet
            ? null
            : selectedPeriodTimeSet!.id,
      ),
    );
  }

  void _cancel() {
    if (_hasPopped) {
      return;
    }
    setState(() => _hasPopped = true);
    Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _ImportFormSummary extends StatelessWidget {
  const _ImportFormSummary({
    required this.date,
    required this.courseCount,
    required this.periodTimeSetContent,
  });

  final Widget date;
  final String courseCount;
  final Widget periodTimeSetContent;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final courseSummary = _CourseCountSummary(courseCount: courseCount);
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth >= 600 && textScale <= 1.3;
        final summary = useRow
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: date),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colors.outlineVariant,
                    ),
                    Expanded(flex: 2, child: courseSummary),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  date,
                  Divider(height: 1, color: colors.outlineVariant),
                  courseSummary,
                ],
              );

        return Material(
          color: colors.surfaceContainerLow,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              Divider(height: 1, indent: 14, endIndent: 14),
              periodTimeSetContent,
            ],
          ),
        );
      },
    );
  }
}

class _CourseCountSummary extends StatelessWidget {
  const _CourseCountSummary({required this.courseCount});

  final String courseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No Semantics wrapper: the Text below already carries `courseCount`, and a
    // container label with the same string makes screen readers say it twice.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                courseCount,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodTimeSetImportChoices extends StatelessWidget {
  const _PeriodTimeSetImportChoices({
    required this.title,
    required this.importBundled,
    required this.importBundledTitle,
    required this.importBundledSubtitle,
    required this.discardTitle,
    required this.discardSubtitle,
    required this.enabled,
    required this.canDiscard,
    required this.onImportBundled,
    required this.onDiscardBundled,
  });

  final String title;
  final bool importBundled;
  final String importBundledTitle;
  final String importBundledSubtitle;
  final String discardTitle;
  final String discardSubtitle;
  final bool enabled;
  final bool canDiscard;
  final VoidCallback onImportBundled;
  final VoidCallback onDiscardBundled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        _PeriodTimeSetChoiceRow(
          title: importBundledTitle,
          subtitle: importBundledSubtitle,
          selected: importBundled,
          enabled: enabled,
          onTap: onImportBundled,
        ),
        Divider(height: 1, indent: 52, color: colors.outlineVariant),
        _PeriodTimeSetChoiceRow(
          title: discardTitle,
          subtitle: discardSubtitle,
          selected: !importBundled,
          enabled: enabled && canDiscard,
          onTap: onDiscardBundled,
        ),
      ],
    );
  }
}

class _PeriodTimeSetChoiceRow extends StatelessWidget {
  const _PeriodTimeSetChoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled ? colors.onSurface : colors.onSurfaceVariant;
    return Semantics(
      button: enabled,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          color: selected
              ? colors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked_outlined
                            : Icons.radio_button_unchecked_outlined,
                        color: enabled
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: enabled
                                  ? colors.onSurfaceVariant
                                  : colors.onSurfaceVariant.withValues(
                                      alpha: 0.72,
                                    ),
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
      ),
    );
  }
}

class _ParserDetailsDisclosure extends StatelessWidget {
  const _ParserDetailsDisclosure({
    required this.expanded,
    required this.title,
    required this.expandLabel,
    required this.collapseLabel,
    required this.pageTitleLabel,
    required this.pageTitle,
    required this.parserLabel,
    required this.parser,
    required this.onChanged,
  });

  final bool expanded;
  final String title;
  final String expandLabel;
  final String collapseLabel;
  final String pageTitleLabel;
  final String pageTitle;
  final String parserLabel;
  final String parser;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = SkedMotionPolicy.of(context);
    final duration = motion.spatialAnimationsEnabled
        ? motion.effects(SkedMotionSpeed.fast)
        : Duration.zero;
    final pageTitleValue = pageTitle.trim();
    final parserValue = parser.trim();
    final active = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: active,
          expanded: expanded,
          // The title Text is the accessible name and `expanded` already
          // announces the state, so the expand/collapse wording belongs in
          // the hint rather than a label that competes with the title.
          hint: expanded ? collapseLabel : expandLabel,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              child: InkWell(
                onTap: active ? () => onChanged!(!expanded) : null,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.article_outlined, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title, style: theme.textTheme.titleSmall),
                        ),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: duration,
                          curve: motion.scheme.enterCurve,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: colors.onSurfaceVariant,
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
        AnimatedSize(
          duration: duration,
          curve: motion.scheme.enterCurve,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Column(
                    children: [
                      Divider(height: 1, color: colors.outlineVariant),
                      const SizedBox(height: 8),
                      if (pageTitleValue.isNotEmpty)
                        _ParserDetailRow(
                          label: pageTitleLabel,
                          value: pageTitleValue,
                        ),
                      if (pageTitleValue.isNotEmpty && parserValue.isNotEmpty)
                        const SizedBox(height: 8),
                      if (parserValue.isNotEmpty)
                        _ParserDetailRow(
                          label: parserLabel,
                          value: parserValue,
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ParserDetailRow extends StatelessWidget {
  const _ParserDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _ImportWarningsGroup extends StatelessWidget {
  const _ImportWarningsGroup({required this.title, required this.warnings});

  final String title;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < warnings.length; index++) ...[
            if (index > 0) const SizedBox(height: 6),
            _ImportWarningRow(message: warnings[index]),
          ],
        ],
      ),
    );
  }
}

class _ImportWarningRow extends StatelessWidget {
  const _ImportWarningRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    this.trailingIcon,
    this.enabled = true,
    this.onTap,
  });

  final Widget title;
  final Widget subtitle;
  final IconData leadingIcon;
  final IconData? trailingIcon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = enabled && onTap != null;
    // Material's disabled emphasis. Keep every element of the row on the same
    // token so a disabled row reads as disabled at a glance.
    final disabledColor = colors.onSurface.withValues(alpha: 0.38);
    final iconColor = enabled ? colors.primary : disabledColor;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: enabled ? colors.onSurface : disabledColor,
    );
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: enabled ? colors.onSurfaceVariant : disabledColor,
    );
    return Semantics(
      button: active,
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          child: InkWell(
            onTap: active ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(leadingIcon, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: titleStyle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            title,
                            const SizedBox(height: 2),
                            DefaultTextStyle.merge(
                              style: subtitleStyle,
                              child: subtitle,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(
                          trailingIcon,
                          color: enabled
                              ? colors.onSurfaceVariant
                              : disabledColor,
                        ),
                      ),
                    ],
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

class _ImportPreviewActions extends StatelessWidget {
  const _ImportPreviewActions({
    required this.canReplaceCurrent,
    required this.canSubmit,
    required this.onCancel,
    required this.onAddAsNew,
    required this.onReplace,
  });

  final bool canReplaceCurrent;
  final bool canSubmit;
  final VoidCallback? onCancel;
  final VoidCallback? onAddAsNew;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredRowWidth =
            _minimumButtonWidth(context, l10n.cancel) +
            _minimumButtonWidth(context, l10n.importAsNewTimetable) +
            (canReplaceCurrent
                ? _minimumButtonWidth(context, l10n.replaceCurrentTimetable) +
                      16
                : 8);
        final compact =
            textScale > 1.3 || constraints.maxWidth < requiredRowWidth;
        final cancel = TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(l10n.cancel),
        );
        final replace = OutlinedButton(
          onPressed: canSubmit ? onReplace : null,
          child: Text(l10n.replaceCurrentTimetable),
        );
        final addAsNew = FilledButton(
          onPressed: canSubmit ? onAddAsNew : null,
          child: Text(l10n.importAsNewTimetable),
        );
        if (!compact) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              cancel,
              if (canReplaceCurrent) ...[const SizedBox(width: 8), replace],
              const SizedBox(width: 8),
              addAsNew,
            ],
          );
        }
        // All three labels do not share a row, but cancel and replace often
        // still do. Measure that pair before falling back to a full stack, so
        // short-label locales keep the tighter two-row layout and only the
        // genuinely long ones spend a third row.
        final pairedRowWidth =
            _minimumButtonWidth(context, l10n.cancel) +
            8 +
            _minimumButtonWidth(context, l10n.replaceCurrentTimetable);
        final canPairSecondRow =
            canReplaceCurrent && constraints.maxWidth >= pairedRowWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            addAsNew,
            const SizedBox(height: 4),
            if (!canReplaceCurrent)
              Align(alignment: Alignment.centerRight, child: cancel)
            else if (canPairSecondRow)
              Row(
                children: [
                  cancel,
                  const SizedBox(width: 8),
                  // Expanded, not Flexible beside a Spacer: replace takes the
                  // whole remainder instead of being capped at half of it.
                  Expanded(child: replace),
                ],
              )
            else ...[
              replace,
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: cancel),
            ],
          ],
        );
      },
    );
  }

  double _minimumButtonWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // TextPainter owns a native paragraph, and this runs inside a LayoutBuilder
    // that re-measures on every keyboard animation frame. Release it here
    // instead of leaving one behind per measurement.
    final labelWidth = painter.width;
    painter.dispose();
    // Material buttons include the visible label padding and a slightly wider
    // press target. Keep a margin for localized labels rather than assuming a
    // particular sheet width is enough.
    return (labelWidth + 64).clamp(64, double.infinity).toDouble();
  }
}
