import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import 'expressive_motion.dart';
import 'period_time_set_picker_dialog.dart';

class SchoolWebImportResultSheet extends StatefulWidget {
  const SchoolWebImportResultSheet({
    super.key,
    required this.response,
    required this.canReplaceCurrent,
    required this.periodTimeSets,
    required this.initialPeriodTimeSetId,
    required this.provider,
  });

  final SchoolImportResponse response;
  final bool canReplaceCurrent;
  final List<PeriodTimeSet> periodTimeSets;
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
  bool _hasPopped = false;
  bool _pickerOpen = false;

  bool get _hasBundledPeriodTimeSet =>
      widget.response.timetable.periodTimeSet.periodTimes.isNotEmpty;

  bool get _canDiscardBundledPeriodTimeSet => widget.periodTimeSets.isNotEmpty;

  bool get _canSubmitImport =>
      widget.response.timetable.courses.isNotEmpty &&
      (_importBundledPeriodTimeSet || _selectedPeriodTimeSetId.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.response.timetable.name,
    )..addListener(_handleNameChanged);
    _startDate = normalizeDateOnly(widget.response.timetable.startDate);
    _selectedPeriodTimeSetId =
        widget.periodTimeSets.any(
          (item) => item.id == widget.initialPeriodTimeSetId,
        )
        ? widget.initialPeriodTimeSetId
        : (widget.periodTimeSets.isEmpty ? '' : widget.periodTimeSets.first.id);
    _importBundledPeriodTimeSet = _hasBundledPeriodTimeSet;
  }

  void _handleNameChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timetable = widget.response.timetable;
    final warnings = widget.response.meta.warnings;
    final theme = Theme.of(context);
    final selectedPeriodTimeSet = _selectedExistingPeriodTimeSet();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.schoolWebImportPreview,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.timetableName,
                prefixIcon: const Icon(Icons.table_chart_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _PreviewListTile(
              key: const ValueKey('school-import-start-date-tile'),
              title: Text(l10n.semesterStartDate),
              subtitle: Text(_formatDate(_startDate)),
              leadingIcon: Icons.calendar_today_outlined,
              trailingIcon: Icons.chevron_right,
              enabled: !_pickerOpen && !_hasPopped,
              onTap: (_pickerOpen || _hasPopped) ? null : _pickStartDate,
            ),
            const SizedBox(height: 4),
            _PreviewListTile(
              title: Text(
                _nameController.text.trim().isEmpty
                    ? l10n.none
                    : _nameController.text.trim(),
              ),
              subtitle: Text(
                '${l10n.schoolWebImportCourseCount(timetable.courses.length)} · '
                '${_buildActivePeriodTimeSetSummary(l10n, selectedPeriodTimeSet)}',
              ),
              leadingIcon: Icons.preview_outlined,
            ),
            if (_hasBundledPeriodTimeSet) ...[
              const SizedBox(height: 8),
              Text(
                l10n.importPeriodTimeSetDialogTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _ImportChoiceTile(
                title: l10n.importBundledPeriodTimeSets,
                subtitle: l10n.periodTimeSetSummary(
                  _resolvedBundledPeriodTimeSetName(),
                  timetable.periodTimeSet.periodTimes.length,
                ),
                selected: _importBundledPeriodTimeSet,
                onTap: () {
                  setState(() => _importBundledPeriodTimeSet = true);
                },
              ),
              const SizedBox(height: 8),
              _ImportChoiceTile(
                title: l10n.discardBundledPeriodTimeSets,
                subtitle: _canDiscardBundledPeriodTimeSet
                    ? (selectedPeriodTimeSet == null
                          ? l10n.noPeriodTimeAvailable
                          : l10n.periodTimeSetSummary(
                              selectedPeriodTimeSet.name,
                              selectedPeriodTimeSet.periodTimes.length,
                            ))
                    : l10n.importDiscardPeriodTimeSetUnavailable,
                selected: !_importBundledPeriodTimeSet,
                onTap: _canDiscardBundledPeriodTimeSet
                    ? () {
                        setState(() => _importBundledPeriodTimeSet = false);
                      }
                    : null,
              ),
            ],
            if (!_importBundledPeriodTimeSet) ...[
              const SizedBox(height: 8),
              _PreviewListTile(
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
                enabled:
                    widget.periodTimeSets.isNotEmpty &&
                    !_pickerOpen &&
                    !_hasPopped,
                onTap:
                    widget.periodTimeSets.isEmpty || _pickerOpen || _hasPopped
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
                        setState(() => _selectedPeriodTimeSetId = result);
                      },
              ),
            ],
            if (widget.response.meta.pageTitle.trim().isNotEmpty)
              _PreviewListTile(
                title: Text(l10n.schoolWebImportPageTitleLabel),
                subtitle: Text(widget.response.meta.pageTitle),
                leadingIcon: Icons.title,
              ),
            if (widget.response.meta.parser.trim().isNotEmpty)
              _PreviewListTile(
                title: Text(l10n.schoolImportParserSourceTitle),
                subtitle: Text(widget.response.meta.parser),
                leadingIcon: Icons.smart_toy_outlined,
              ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.schoolWebImportWarnings,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...warnings.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.info_outline, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: _hasPopped ? null : _cancel,
                  child: Text(l10n.cancel),
                ),
                OutlinedButton(
                  onPressed: (_canSubmitImport && !_hasPopped)
                      ? () => _submit(TimetableImportMode.addAsNew)
                      : null,
                  child: Text(l10n.importAsNewTimetable),
                ),
                if (widget.canReplaceCurrent)
                  FilledButton(
                    onPressed: (_canSubmitImport && !_hasPopped)
                        ? () => _submit(TimetableImportMode.replaceActive)
                        : null,
                    child: Text(l10n.replaceCurrentTimetable),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PeriodTimeSet? _selectedExistingPeriodTimeSet() {
    for (final item in widget.periodTimeSets) {
      if (item.id == _selectedPeriodTimeSetId) {
        return item;
      }
    }
    return null;
  }

  String _buildActivePeriodTimeSetSummary(
    AppLocalizations l10n,
    PeriodTimeSet? selectedPeriodTimeSet,
  ) {
    if (_importBundledPeriodTimeSet) {
      return l10n.periodTimeSetSummary(
        _resolvedBundledPeriodTimeSetName(),
        widget.response.timetable.periodTimeSet.periodTimes.length,
      );
    }
    if (selectedPeriodTimeSet == null) {
      return l10n.noPeriodTimeAvailable;
    }
    return l10n.periodTimeSetSummary(
      selectedPeriodTimeSet.name,
      selectedPeriodTimeSet.periodTimes.length,
    );
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
            : _selectedPeriodTimeSetId,
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

class _ImportChoiceTile extends StatelessWidget {
  const _ImportChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = selected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
    return ExpressiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_outlined
                    : Icons.radio_button_unchecked_outlined,
                color: onTap == null
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewListTile extends StatelessWidget {
  const _PreviewListTile({
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
    final iconColor = enabled
        ? colors.primary
        : colors.onSurface.withValues(alpha: 0.38);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: enabled
          ? colors.onSurface
          : colors.onSurface.withValues(alpha: 0.38),
    );
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: enabled
          ? colors.onSurfaceVariant
          : colors.onSurface.withValues(alpha: 0.38),
    );
    final content = Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: ShapeDecoration(
                color: enabled
                    ? colors.primary.withValues(alpha: 0.10)
                    : colors.onSurface.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Icon(leadingIcon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: titleStyle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 3),
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
              Icon(
                trailingIcon,
                color: enabled ? colors.onSurfaceVariant : iconColor,
              ),
            ],
          ],
        ),
      ),
    );
    return ExpressiveTap(
      enabled: active,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
