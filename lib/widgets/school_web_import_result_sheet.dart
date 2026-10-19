import 'sked_detail_row.dart';
import 'workspace_editor_form.dart';
import 'editor_exit_guard.dart';
import 'sked_task_session.dart';

import 'dart:async';

import '../theme/sked_surface.dart';

import '../widgets/expressive_motion.dart';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'sked_date_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../theme/sked_expressive_theme.dart';
import 'app_modal_sheet.dart';
import 'school_import_replace_confirmation.dart';
import 'period_time_set_picker_dialog.dart';
import 'school_import_week_range_confirmation.dart';
import 'school_import_save_feedback.dart';
import 'sked_task_route.dart';
import 'workspace_route_lifecycle.dart';

class SchoolWebImportResultSheet extends StatefulWidget {
  const SchoolWebImportResultSheet({
    super.key,
    required this.response,
    required this.canReplaceCurrent,
    required this.initialPeriodTimeSetId,
    this.onApply,
  });

  final SchoolImportResponse response;
  final bool canReplaceCurrent;
  final String initialPeriodTimeSetId;

  /// When supplied, persistence runs before returning the configured request.
  /// The task's exit guard protects edited configuration and in-flight writes.
  final Future<void> Function(SchoolImportApplyRequest request)? onApply;

  @override
  State<SchoolWebImportResultSheet> createState() =>
      _SchoolWebImportResultSheetState();
}

class _SchoolWebImportResultSheetState extends State<SchoolWebImportResultSheet>
    with
        WorkspaceRouteLifecycle<SchoolWebImportResultSheet>,
        EditorExitGuard<SchoolWebImportResultSheet> {
  @override
  AppMode get routeWorkspace => AppMode.student;

  @override
  Future<bool> prepareWorkspaceDisable() async => !_blocked;

  @override
  AppMode get editorWorkspace => AppMode.student;

  @override
  bool get exitBlocked => _blocked;

  @override
  String get draftFingerprint =>
      '${_nameController.text}|${_startDate.toIso8601String()}|'
      '$_selectedPeriodTimeSetId|$_importBundledPeriodTimeSet';

  @override
  Widget guardDiscardConfirmation(Widget dialog) => SkedTaskRouteGuard(
    parent: SkedTaskSessionScope.maybeOf(context)?.session,
    maintenance: _maintenance,
    workspaceView: _workspaceView,
    workspaces: _workspaces,
    workspace: AppMode.student,
    isOwnerActive: () => mounted && !_hasPopped,
    child: dialog,
  );

  late StudentViewState _student;
  late SettingsViewState _settings;
  late AppLifecycle _lifecycle;
  late AppDataMaintenance _maintenance;
  late AppDataClearController _dataClear;
  late WorkspaceViewState _workspaceView;
  late WorkspaceCommands _workspaces;
  Listenable? _importChanges;
  bool _draftInitialized = false;

  late final TextEditingController _nameController;
  late DateTime _startDate;
  late String _selectedPeriodTimeSetId;
  late bool _importBundledPeriodTimeSet;
  bool _detailsExpanded = false;
  bool _replaceConfirmationOpen = false;
  bool _weekRangeConfirmationOpen = false;
  bool _hasPopped = false;
  bool _pickerOpen = false;
  bool _isApplying = false;
  Object? _applyError;
  final _startDateAnchor = GlobalKey();
  final _periodTimeSetAnchor = GlobalKey();

  bool get _hasBundledPeriodTimeSet =>
      widget.response.timetable.periodTimeSet.periodTimes.isNotEmpty;

  /// Do not retain a sheet-open-time snapshot here. The picker can create,
  /// edit, or delete sets while this sheet stays open, and its selection has to
  /// resolve against the same source that ultimately validates the import.
  List<PeriodTimeSet> get _periodTimeSets => _student.periodTimeSets;

  bool get _canDiscardBundledPeriodTimeSet => _periodTimeSets.isNotEmpty;

  bool get _canSave => canSaveSchoolImport(
    lifecycle: _lifecycle,
    maintenance: _maintenance,
    dataClear: _dataClear,
    workspaceView: _workspaceView,
  );

  bool get _canSubmitImport =>
      _canSave &&
      widget.response.timetable.courses.isNotEmpty &&
      (_importBundledPeriodTimeSet || _selectedExistingPeriodTimeSet() != null);

  bool get _hasParserDetails =>
      widget.response.meta.pageTitle.trim().isNotEmpty ||
      widget.response.meta.parser.trim().isNotEmpty;

  bool get _blocked =>
      _hasPopped ||
      _pickerOpen ||
      _replaceConfirmationOpen ||
      _weekRangeConfirmationOpen ||
      _isApplying;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.response.timetable.name,
    )..addListener(_handleNameChanged);
    _startDate = normalizeDateOnly(widget.response.timetable.startDate);
    _selectedPeriodTimeSetId = widget.initialPeriodTimeSetId;
    _importBundledPeriodTimeSet = _hasBundledPeriodTimeSet;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final student = context.watch<StudentViewState>();
    final settings = context.watch<SettingsViewState>();
    final lifecycle = context.watch<AppLifecycle>();
    final maintenance = context.watch<AppDataMaintenance>();
    final dataClear = context.watch<AppDataClearController>();
    final workspaceView = context.watch<WorkspaceViewState>();
    final workspaces = context.watch<WorkspaceCommands>();
    if (_importChanges != null &&
        identical(student, _student) &&
        identical(settings, _settings) &&
        identical(lifecycle, _lifecycle) &&
        identical(maintenance, _maintenance) &&
        identical(dataClear, _dataClear) &&
        identical(workspaceView, _workspaceView) &&
        identical(workspaces, _workspaces)) {
      return;
    }
    _importChanges?.removeListener(_handlePeriodTimeSetsChanged);
    _student = student;
    _settings = settings;
    _lifecycle = lifecycle;
    _maintenance = maintenance;
    _dataClear = dataClear;
    _workspaceView = workspaceView;
    _workspaces = workspaces;
    _importChanges = Listenable.merge([
      student,
      settings,
      lifecycle,
      maintenance,
      dataClear,
      workspaceView,
    ])..addListener(_handlePeriodTimeSetsChanged);
    _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(
      _selectedPeriodTimeSetId,
    );
    if (!_draftInitialized) {
      _draftInitialized = true;
      initializeDraftGuard();
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
    _importChanges?.removeListener(_handlePeriodTimeSetsChanged);
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
    if (!routeWorkspaceEnabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final timetable = widget.response.timetable;
    final warnings = widget.response.meta.warnings;
    final selectedPeriodTimeSet = _selectedExistingPeriodTimeSet();
    final existingPeriodTimeSetSelector = _CompactActionRow(
      key: _periodTimeSetAnchor,
      title: l10n.selectPeriodTimeSet,
      subtitle: selectedPeriodTimeSet == null
          ? l10n.noPeriodTimeAvailable
          : l10n.periodTimeSetSummary(
              selectedPeriodTimeSet.name,
              selectedPeriodTimeSet.periodTimes.length,
            ),
      leadingIcon: Icons.schedule_outlined,
      enabled: _periodTimeSets.isNotEmpty && !_blocked && _canSave,
      onTap: _periodTimeSets.isEmpty || _blocked || !_canSave
          ? null
          : () async {
              if (!_canSave) return;
              final result = await _runPicker(
                () => showPeriodTimeSetPickerDialog(
                  context,
                  anchorContext: _periodTimeSetAnchor.currentContext,
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

    return PopScope(
      canPop: _hasPopped,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_blocked) unawaited(requestEditorExit());
      },
      child: AppSheetScaffold.editor(
        onClose: _cancel,
        closeEnabled: !_blocked,
        busy: _isApplying,
        editorActions: SkedEditorActions(
          onCancel: _cancel,
          onSubmit: _canSubmitImport
              ? () => unawaited(_submit(TimetableImportMode.addAsNew))
              : null,
          enabled: !_blocked,
        ),
        title: Text(l10n.schoolWebImportPreview),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SchoolImportSaveFeedback(
              lifecycle: _lifecycle,
              maintenance: _maintenance,
              dataClear: _dataClear,
              isSaving: _isApplying,
              error: _applyError,
              onRecoveryBusyChanged: (busy) =>
                  setState(() => _isApplying = busy),
            ),
            _ImportPreviewActions(
              canReplaceCurrent: widget.canReplaceCurrent,
              canSubmit: _canSubmitImport && !_blocked,
              onCancel: _blocked ? null : _cancel,
              onAddAsNew: _canSubmitImport && !_blocked
                  ? () => _submit(TimetableImportMode.addAsNew)
                  : null,
              onReplace: _canSubmitImport && !_blocked
                  ? _confirmAndSubmitReplacement
                  : null,
            ),
          ],
        ),
        child: FocusScope(
          canRequestFocus: !_blocked,
          child: AbsorbPointer(
            absorbing: _blocked,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkedEditorTextField(
                  label: l10n.timetableName,
                  controller: _nameController,
                  enabled: !_isApplying,
                  minLines: 1,
                  maxLines: 2,
                  icon: Icons.table_chart_outlined,
                  headline: true,
                ),
                const SizedBox(height: 12),
                _ImportFormSummary(
                  date: KeyedSubtree(
                    key: _startDateAnchor,
                    child: _CompactActionRow(
                      key: const ValueKey('school-import-start-date-tile'),
                      title: l10n.semesterStartDate,
                      subtitle: _formatDate(_startDate),
                      leadingIcon: Icons.calendar_today_outlined,
                      enabled: !_blocked,
                      onTap: _blocked ? null : _pickStartDate,
                    ),
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

    final activeId = _student.activePeriodTimeSetOrNull?.id;
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
              : untitledTimetableName(localeCode: _settings.localeCode));
    return importedPeriodTimeSetName(
      timetableName,
      localeCode: _settings.localeCode,
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
      () => showSkedDatePicker(
        context: context,
        workspace: AppMode.student,
        anchorContext: _startDateAnchor.currentContext,
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

  Future<void> _submit(TimetableImportMode mode) async {
    if (_hasPopped ||
        _blocked ||
        widget.response.timetable.courses.isEmpty ||
        !_canSave) {
      return;
    }
    final dataSession = _maintenance.dataSessionToken;
    final replacementId = _student.activeTimetableOrNull?.id;
    setState(() => _weekRangeConfirmationOpen = true);
    bool confirmed;
    try {
      confirmed = await confirmSchoolImportWeekRange(
        context,
        widget.response.timetable,
      );
    } finally {
      if (mounted) setState(() => _weekRangeConfirmationOpen = false);
    }
    if (!mounted ||
        _hasPopped ||
        !routeWorkspaceEnabled ||
        !confirmed ||
        !_canSave ||
        !identical(dataSession, _maintenance.dataSessionToken) ||
        (mode == TimetableImportMode.replaceActive &&
            replacementId != _student.activeTimetableOrNull?.id)) {
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
    final request = SchoolImportApplyRequest(
      response: nextResponse,
      mode: mode,
      importBundledPeriodTimeSet: _importBundledPeriodTimeSet,
      targetPeriodTimeSetId: _importBundledPeriodTimeSet
          ? null
          : selectedPeriodTimeSet!.id,
    );
    final apply = widget.onApply;
    if (apply != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _isApplying = true;
        _applyError = null;
      });
      try {
        await apply(request);
      } catch (error) {
        if (mounted) setState(() => _applyError = error);
        return;
      } finally {
        if (mounted) setState(() => _isApplying = false);
      }
    }
    if (!mounted || _hasPopped || !routeWorkspaceEnabled) return;
    setState(() => _hasPopped = true);
    completeSkedTaskRoute(context, request);
  }

  Future<void> _confirmAndSubmitReplacement() async {
    if (_hasPopped ||
        _blocked ||
        !_canSubmitImport ||
        !widget.canReplaceCurrent) {
      return;
    }
    setState(() => _replaceConfirmationOpen = true);
    bool confirmed;
    try {
      confirmed = await confirmSchoolImportReplacement(context);
    } finally {
      if (mounted) {
        setState(() => _replaceConfirmationOpen = false);
      }
    }
    if (confirmed && mounted && !_hasPopped) {
      await _submit(TimetableImportMode.replaceActive);
    }
  }

  void _cancel() {
    if (!_blocked) unawaited(requestEditorExit());
  }

  @override
  void closeEditor() {
    if (_blocked) {
      return;
    }
    setState(() => _hasPopped = true);
    completeSkedTaskRoute(context);
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
          color: Colors.transparent,
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
            Icon(
              Icons.menu_book_outlined,
              color: skedReadableAccent(
                theme.colorScheme,
                surface: SkedSurface.colorOf(context),
              ),
            ),
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
                            ? skedReadableAccent(
                                colors,
                                surface: colors.primary.withValues(alpha: 0.08),
                              )
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          color: skedReadableAccent(
                            colors,
                            surface: SkedSurface.colorOf(context),
                          ),
                        ),
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
        SkedAnimatedSize(
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
  Widget build(BuildContext context) => SkedDetailRow(
    label: label,
    value: value,
    stacked: true,
    padding: EdgeInsets.zero,
  );
}

class _ImportWarningsGroup extends StatefulWidget {
  const _ImportWarningsGroup({required this.title, required this.warnings});

  final String title;
  final List<String> warnings;

  @override
  State<_ImportWarningsGroup> createState() => _ImportWarningsGroupState();
}

class _ImportWarningsGroupState extends State<_ImportWarningsGroup> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final motion = SkedMotionPolicy.of(context);
    final duration = motion.spatialAnimationsEnabled
        ? motion.effects(SkedMotionSpeed.fast)
        : Duration.zero;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            hint: _expanded
                ? l10n.schoolImportCollapseWarnings
                : l10n.schoolImportExpandWarnings,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
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
          SkedAnimatedSize(
            duration: duration,
            curve: motion.scheme.enterCurve,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < widget.warnings.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 6),
                          _ImportWarningRow(message: widget.warnings[index]),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
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
    this.enabled = true,
    this.onTap,
  });

  final String title, subtitle;
  final IconData leadingIcon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SkedEditorValueField(
    label: title,
    value: subtitle,
    icon: leadingIcon,
    enabled: enabled,
    onPressed: onTap == null ? null : (_) => onTap!(),
  );
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
