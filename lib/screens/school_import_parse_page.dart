import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/school_import_api.dart';
import '../theme/sked_expressive_theme.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/period_time_set_picker_dialog.dart';
import 'school_import_result_editor_page.dart';

/// The value returned by [SchoolImportParsePage] after a successful parse.
///
/// It extends [SchoolImportResponse] so callers that still use the original
/// `Future<SchoolImportResponse?>` presenter contract remain source compatible,
/// while newer callers can inspect [rawText] and preserve the exact edited
/// response text.
class SchoolImportParseOutcome extends SchoolImportResponse {
  SchoolImportParseOutcome({
    required SchoolImportResponse response,
    required this.rawText,
    this.applyRequest,
  }) : response = response,
       super(meta: response.meta, timetable: response.timetable);

  /// The validated response represented by this outcome.
  final SchoolImportResponse response;

  /// The unmodified (or user-edited) JSON text that produced [response].
  final String rawText;

  /// A fully configured import request when the page was opened as the modern
  /// end-to-end import flow. Legacy callers can leave this null and continue
  /// using [response] only.
  final SchoolImportApplyRequest? applyRequest;
}

/// Full-screen presentation for a streaming school timetable parse.
///
/// The page owns the stream subscription and always cancels it when the page
/// is dismissed.  A result is popped at most once, which keeps route chaining
/// safe when a user taps an action repeatedly or the stream emits a late
/// event while the route is leaving.
class SchoolImportParsePage extends StatefulWidget {
  const SchoolImportParsePage({
    super.key,
    required this.stream,
    this.provider,
    this.canReplaceCurrent = false,
    this.initialPeriodTimeSetId,
    this.maxPreviewCodeUnits = 4096,
    this.maxEditableCodeUnits = 64 * 1024,
    this.returnResponseOnly = false,
    this.autoPopAfterEditor = false,
  });

  static const int defaultMaxPreviewCodeUnits = 4096;
  static const int defaultMaxEditableCodeUnits = 64 * 1024;

  final Stream<SchoolImportStreamEvent> stream;
  final TimetableProvider? provider;
  final bool canReplaceCurrent;
  final String? initialPeriodTimeSetId;
  final int maxPreviewCodeUnits;
  final int maxEditableCodeUnits;

  /// Keeps the pre-page presenter contract for legacy wrappers. New callers
  /// should use the default and receive [SchoolImportParseOutcome].
  final bool returnResponseOnly;

  /// Legacy wrappers used to close as soon as the JSON editor was confirmed.
  /// The full-screen flow leaves the result page open so users can review it.
  final bool autoPopAfterEditor;

  @override
  State<SchoolImportParsePage> createState() => _SchoolImportParsePageState();
}

class _SchoolImportParsePageState extends State<SchoolImportParsePage> {
  static const _followResumeTolerance = 1.0;

  final _textBuffer = StringBuffer();
  final _scrollController = ScrollController();
  StreamSubscription<SchoolImportStreamEvent>? _subscription;
  TextEditingController? _nameController;
  TextEditingController? _totalWeeksController;

  String _rawText = '';
  String _previewText = '';
  SchoolImportResponse? _response;
  String? _error;
  bool _isDone = false;
  bool _isOpeningEditor = false;
  bool _hasPopped = false;
  bool _rawExpanded = false;
  bool _hasFailed = false;
  bool _followOutput = true;
  double _lastUserScrollPixels = 0;
  bool _hasUserScrollBaseline = false;
  DateTime? _startDate;
  String _selectedPeriodTimeSetId = '';
  bool _importBundledPeriodTimeSet = false;
  bool _pickerOpen = false;

  bool get _canEdit =>
      _isDone &&
      _response != null &&
      _rawText.trim().isNotEmpty &&
      _rawText.length <= widget.maxEditableCodeUnits;

  bool get _isBusy => _isOpeningEditor;

  bool get _hasDirectImportConfiguration => widget.provider != null;

  bool get _hasBundledPeriodTimeSet =>
      _response?.timetable.periodTimeSet.periodTimes.isNotEmpty ?? false;

  List<PeriodTimeSet> get _periodTimeSets =>
      widget.provider?.periodTimeSets ?? const <PeriodTimeSet>[];

  PeriodTimeSet? get _selectedExistingPeriodTimeSet {
    for (final item in _periodTimeSets) {
      if (item.id == _selectedPeriodTimeSetId) return item;
    }
    return null;
  }

  bool get _canSubmitConfiguredImport =>
      _response?.timetable.courses.isNotEmpty == true &&
      (_importBundledPeriodTimeSet || _selectedExistingPeriodTimeSet != null);

  @override
  void initState() {
    super.initState();
    widget.provider?.addListener(_handlePeriodTimeSetsChanged);
    _subscription = widget.stream.listen(
      _handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || _hasPopped || _isDone || _hasFailed) return;
        _hasFailed = true;
        unawaited(_cancelSubscription());
        setState(() => _error = '$error');
      },
      cancelOnError: false,
    );
  }

  void _handleEvent(SchoolImportStreamEvent event) {
    if (!mounted || _hasPopped || _hasFailed || _isDone) return;
    final wasAtBottom = _isAtBottom();
    switch (event) {
      case ParseDelta(:final text):
        _textBuffer.write(text);
        _rawText = _textBuffer.toString();
        _appendPreview(text);
      case ParseDone(:final response):
        _response = response;
        _rawText = _textBuffer.toString();
        _error = null;
        _isDone = true;
        _initializeImportConfiguration(response);
        // There should be no more events after ParseDone. Cancelling here
        // prevents a late stream error from replacing the completed result.
        unawaited(_cancelSubscription());
      case ParseError(:final message):
        if (_isDone || _hasFailed) return;
        _hasFailed = true;
        _error = message;
        unawaited(_cancelSubscription());
    }
    if (wasAtBottom) {
      // The user has deliberately returned to the end of the transcript. Do
      // this before the new chunk changes maxScrollExtent so a just-arrived
      // delta cannot make an already-bottom position appear far from the end.
      _followOutput = true;
    }
    setState(() {});
    _scrollToBottom();
  }

  @override
  void dispose() {
    unawaited(_cancelSubscription());
    widget.provider?.removeListener(_handlePeriodTimeSetsChanged);
    _nameController?.removeListener(_handleImportNameChanged);
    _nameController?.dispose();
    _totalWeeksController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeImportConfiguration(
    SchoolImportResponse response, {
    bool preservePeriodChoice = false,
  }) {
    final previousSelection = _selectedPeriodTimeSetId;
    final previousBundledChoice = _importBundledPeriodTimeSet;
    _nameController?.removeListener(_handleImportNameChanged);
    _nameController?.dispose();
    _totalWeeksController?.dispose();
    _nameController = TextEditingController(text: response.timetable.name)
      ..addListener(_handleImportNameChanged);
    _totalWeeksController = TextEditingController(
      text: response.timetable.totalWeeks.toString(),
    );
    _startDate = normalizeDateOnly(response.timetable.startDate);
    _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(
      preservePeriodChoice
          ? previousSelection
          : (widget.initialPeriodTimeSetId ?? ''),
    );
    _importBundledPeriodTimeSet = preservePeriodChoice
        ? _hasBundledPeriodTimeSet && previousBundledChoice
        : _hasBundledPeriodTimeSet;
  }

  void _handleImportNameChanged() {
    if (mounted) setState(() {});
  }

  void _handlePeriodTimeSetsChanged() {
    if (!mounted || !_isDone) return;
    final resolved = _resolvedPeriodTimeSetId(_selectedPeriodTimeSetId);
    if (resolved != _selectedPeriodTimeSetId) {
      setState(() => _selectedPeriodTimeSetId = resolved);
    }
  }

  String _resolvedPeriodTimeSetId(String preferredId) {
    if (_periodTimeSets.any((item) => item.id == preferredId)) {
      return preferredId;
    }
    final activeId = widget.provider?.activePeriodTimeSetOrNull?.id;
    if (activeId != null &&
        _periodTimeSets.any((item) => item.id == activeId)) {
      return activeId;
    }
    return _periodTimeSets.isEmpty ? '' : _periodTimeSets.first.id;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Only user-originated notifications may change the follow state. A plain
    // ScrollController listener also sees viewport changes caused by the IME,
    // route transitions, and text re-layout; treating those as an upward user
    // gesture would unexpectedly stop the stream from following the output.
    final metrics = notification.metrics;
    final distanceFromBottom = metrics.maxScrollExtent - metrics.pixels;
    if (notification is ScrollEndNotification) {
      // A drag can finish at the physical end without producing a final
      // ScrollUpdateNotification with drag details (notably for mouse wheels
      // and some touchpad paths). The settled position is authoritative.
      if (distanceFromBottom <= _followResumeTolerance) {
        _followOutput = true;
      }
      return false;
    }

    final isUserNotification =
        notification is UserScrollNotification ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) ||
        (notification is OverscrollNotification &&
            notification.dragDetails != null);
    if (!isUserNotification) return false;

    final pixels = metrics.pixels;
    final direction = notification is UserScrollNotification
        ? notification.direction
        : ScrollDirection.idle;
    if (direction == ScrollDirection.forward ||
        (_hasUserScrollBaseline && pixels < _lastUserScrollPixels - 1)) {
      _followOutput = false;
    } else if (distanceFromBottom <= _followResumeTolerance &&
        (direction == ScrollDirection.reverse ||
            direction == ScrollDirection.idle)) {
      // Scrolling back to the end explicitly opts back into following future
      // chunks, including mouse-wheel and keyboard scrolling.
      _followOutput = true;
    }
    _lastUserScrollPixels = pixels;
    _hasUserScrollBaseline = true;
    return false;
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= _followResumeTolerance;
  }

  Future<void> _cancelSubscription() async {
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (error, stackTrace) {
      debugPrint(
        'School import parse stream cancellation failed: '
        '$error\n$stackTrace',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          _isDone ||
          !_followOutput) {
        return;
      }
      unawaited(_animateScrollToBottom());
    });
  }

  Future<void> _animateScrollToBottom() async {
    try {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // The controller can be detached while a route is being dismissed.
    }
  }

  void _appendPreview(String text) {
    if (text.isEmpty) return;
    final limit = widget.maxPreviewCodeUnits;
    if (limit <= 0) {
      _previewText = '';
      return;
    }
    if (text.length >= limit) {
      _previewText = text.substring(_safeTailStart(text, text.length - limit));
      return;
    }
    final overflow = _previewText.length + text.length - limit;
    final retainedPreview = overflow > 0
        ? _previewText.substring(_safeTailStart(_previewText, overflow))
        : _previewText;
    _previewText = '$retainedPreview$text';
  }

  int _safeTailStart(String value, int start) {
    if (start <= 0) return 0;
    if (start >= value.length) return value.length;
    final codeUnit = value.codeUnitAt(start);
    return codeUnit >= 0xdc00 && codeUnit <= 0xdfff ? start + 1 : start;
  }

  Future<void> _openEditor() async {
    if (!_canEdit || _isBusy || !mounted) return;
    setState(() => _isOpeningEditor = true);
    final result = await Navigator.of(context)
        .push<SchoolImportResultEditorOutcome>(
          MaterialPageRoute(
            builder: (_) => SchoolImportResultEditorPage(
              initialText: _rawText,
              maxEditableCodeUnits: widget.maxEditableCodeUnits,
            ),
          ),
        );
    if (!mounted) return;
    setState(() => _isOpeningEditor = false);
    if (result == null || _hasPopped) return;

    _rawText = result.rawText;
    _textBuffer
      ..clear()
      ..write(_rawText);
    _previewText = '';
    _appendPreview(_rawText);
    _response = result.response;
    _initializeImportConfiguration(result.response, preservePeriodChoice: true);
    setState(() {});
    if (widget.autoPopAfterEditor) {
      _hasPopped = true;
      unawaited(_cancelSubscription());
      Navigator.of(context).pop(
        widget.returnResponseOnly
            ? result.response
            : SchoolImportParseOutcome(
                response: result.response,
                rawText: result.rawText,
              ),
      );
    }
  }

  Future<void> _cancelAndPop() async {
    if (_hasPopped) return;
    _hasPopped = true;
    // Do not make the visible cancel action or system Back wait for a stream
    // implementation's cancellation future. The workflow closes the HTTP
    // session in its finally block after this route returns, while the
    // subscription itself is still cancelled exactly once.
    unawaited(_cancelSubscription());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _continueImport() {
    if (_hasPopped || !_isDone || _response == null || _isBusy) return;
    _hasPopped = true;
    unawaited(_cancelSubscription());
    Navigator.of(context).pop(
      widget.returnResponseOnly
          ? _response
          : SchoolImportParseOutcome(response: _response!, rawText: _rawText),
    );
  }

  Future<void> _pickStartDate() async {
    if (_pickerOpen || _hasPopped || _startDate == null) return;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2035);
    final current = _startDate!;
    final initialDate = current.isBefore(firstDate)
        ? firstDate
        : current.isAfter(lastDate)
        ? lastDate
        : current;
    final picked = await _runPicker(
      () => showDatePicker(
        context: context,
        firstDate: firstDate,
        lastDate: lastDate,
        initialDate: initialDate,
      ),
    );
    if (mounted && picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<T?> _runPicker<T>(Future<T?> Function() picker) async {
    if (_pickerOpen || _hasPopped) return null;
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

  Future<void> _pickPeriodTimeSet() async {
    final provider = widget.provider;
    if (provider == null || _pickerOpen || _hasPopped) return;
    final result = await _runPicker(
      () => showPeriodTimeSetPickerDialog(
        context,
        provider: provider,
        selectedPeriodTimeSetId: _selectedPeriodTimeSetId,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(result));
  }

  void _submitConfiguredImport(TimetableImportMode mode) {
    if (_hasPopped || _isBusy || !_isDone || _response == null) {
      return;
    }
    final selected = _selectedExistingPeriodTimeSet;
    if (!_importBundledPeriodTimeSet && selected == null) {
      final resolved = _resolvedPeriodTimeSetId(_selectedPeriodTimeSetId);
      if (resolved != _selectedPeriodTimeSetId) {
        setState(() => _selectedPeriodTimeSetId = resolved);
      }
      return;
    }
    final name = _nameController?.text.trim() ?? _response!.timetable.name;
    final parsedWeeks = int.tryParse(_totalWeeksController?.text.trim() ?? '');
    final totalWeeks = normalizeTimetableWeeks(
      parsedWeeks ?? _response!.timetable.totalWeeks,
    );
    final nextResponse = _response!.copyWith(
      timetable: _response!.timetable.copyWith(
        name: name,
        startDate: _startDate ?? _response!.timetable.startDate,
        totalWeeks: totalWeeks,
      ),
    );
    final request = SchoolImportApplyRequest(
      response: nextResponse,
      mode: mode,
      importBundledPeriodTimeSet: _importBundledPeriodTimeSet,
      targetPeriodTimeSetId: _importBundledPeriodTimeSet ? null : selected!.id,
    );
    _hasPopped = true;
    unawaited(_cancelSubscription());
    Navigator.of(context).pop(
      widget.returnResponseOnly
          ? nextResponse
          : SchoolImportParseOutcome(
              response: nextResponse,
              rawText: _rawText,
              applyRequest: request,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final motion = SkedMotionPolicy.of(context);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancelAndPop());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(l10n.schoolImportParsePageTitle),
          leading: IconButton(
            tooltip: l10n.cancel,
            onPressed: _hasPopped ? null : () => unawaited(_cancelAndPop()),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      ExpressiveSwitcher(
                        child: KeyedSubtree(
                          key: ValueKey(
                            _error != null
                                ? 'error'
                                : _isDone
                                ? 'done'
                                : 'parsing',
                          ),
                          child: _error != null
                              ? _buildErrorState(context, l10n)
                              : _isDone
                              ? _buildDoneState(context, l10n)
                              : _buildParsingState(context, l10n),
                        ),
                      ),
                      if (_error == null && !_isDone) ...[
                        const SizedBox(height: 16),
                        _buildRawPreview(context, l10n),
                      ],
                      if (_error != null && _previewText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildRawPreview(context, l10n),
                      ],
                      if (_isDone) ...[
                        const SizedBox(height: 16),
                        _buildRawDisclosure(context, l10n, motion),
                      ],
                    ],
                  ),
                ),
              ),
              _buildActions(context, l10n, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParsingState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.schoolImportParsePageParsing,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.schoolHtmlImportParsingMayTakeLong,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.schoolImportParsePageFailed,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final response = _response!;
    final timetable = response.timetable;
    final periodCount = timetable.periodTimeSet.periodTimes.length;
    if (_hasDirectImportConfiguration) {
      return _buildDirectImportConfiguration(context, l10n);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.schoolImportParsePageComplete,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SummaryRow(
                icon: Icons.table_chart_outlined,
                label: l10n.timetableName,
                value: timetable.name,
              ),
              const Divider(height: 1),
              _SummaryRow(
                icon: Icons.calendar_today_outlined,
                label: l10n.semesterStartDate,
                value: _formatDate(timetable.startDate),
              ),
              const Divider(height: 1),
              _SummaryRow(
                icon: Icons.date_range_outlined,
                label: l10n.totalWeeks,
                value: '${timetable.totalWeeks}',
              ),
              const Divider(height: 1),
              _SummaryRow(
                icon: Icons.menu_book_outlined,
                label: l10n.schoolWebImportCourseCount(
                  timetable.courses.length,
                ),
                value: '',
              ),
              if (periodCount > 0) ...[
                const Divider(height: 1),
                _SummaryRow(
                  icon: Icons.schedule_outlined,
                  label: l10n.schoolWebImportPeriodCount(periodCount),
                  value: timetable.periodTimeSet.name,
                ),
              ],
            ],
          ),
        ),
        if (response.meta.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildWarnings(context, l10n, response.meta.warnings),
        ],
      ],
    );
  }

  Widget _buildDirectImportConfiguration(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final response = _response!;
    final timetable = response.timetable;
    final selected = _selectedExistingPeriodTimeSet;
    final nameController = _nameController;
    final weeksController = _totalWeeksController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.schoolImportParsePageComplete,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FocusScope(
          canRequestFocus: !_pickerOpen && !_hasPopped,
          child: IgnorePointer(
            ignoring: _pickerOpen || _hasPopped,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (nameController != null)
                  TextField(
                    key: const ValueKey('school-import-parse-timetable-name'),
                    controller: nameController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l10n.timetableName,
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.table_chart_outlined),
                    ),
                  ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final inline =
                        constraints.maxWidth >= 600 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                    final date = _ParseImportActionRow(
                      key: const ValueKey('school-import-parse-start-date'),
                      title: l10n.semesterStartDate,
                      subtitle: _formatDate(_startDate ?? timetable.startDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickStartDate,
                    );
                    final weeks = weeksController == null
                        ? const SizedBox.shrink()
                        : TextField(
                            key: const ValueKey(
                              'school-import-parse-total-weeks',
                            ),
                            controller: weeksController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: l10n.totalWeeks,
                              prefixIcon: const Icon(Icons.date_range_outlined),
                            ),
                          );
                    if (!inline) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [date, const SizedBox(height: 12), weeks],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: date),
                        const SizedBox(width: 12),
                        Expanded(child: weeks),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Material(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Text(
                          l10n.importPeriodTimeSetDialogTitle,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_hasBundledPeriodTimeSet) ...[
                        _ParseImportChoiceRow(
                          title: l10n.importBundledPeriodTimeSets,
                          subtitle: l10n.periodTimeSetSummary(
                            _bundledPeriodTimeSetName(),
                            timetable.periodTimeSet.periodTimes.length,
                          ),
                          selected: _importBundledPeriodTimeSet,
                          enabled: true,
                          onTap: () => setState(
                            () => _importBundledPeriodTimeSet = true,
                          ),
                        ),
                        Divider(
                          height: 1,
                          indent: 52,
                          color: colors.outlineVariant,
                        ),
                        _ParseImportChoiceRow(
                          title: l10n.discardBundledPeriodTimeSets,
                          subtitle: selected == null
                              ? l10n.noPeriodTimeAvailable
                              : l10n.periodTimeSetSummary(
                                  selected.name,
                                  selected.periodTimes.length,
                                ),
                          selected: !_importBundledPeriodTimeSet,
                          enabled: _periodTimeSets.isNotEmpty,
                          onTap: () => setState(
                            () => _importBundledPeriodTimeSet = false,
                          ),
                        ),
                        if (!_importBundledPeriodTimeSet) ...[
                          Divider(
                            height: 1,
                            indent: 52,
                            color: colors.outlineVariant,
                          ),
                          _buildPeriodTimeSetSelector(l10n),
                        ],
                      ] else
                        _buildPeriodTimeSetSelector(l10n),
                      Divider(
                        height: 1,
                        indent: 52,
                        color: colors.outlineVariant,
                      ),
                      _ParseImportInfoRow(
                        icon: Icons.menu_book_outlined,
                        text: l10n.schoolWebImportCourseCount(
                          timetable.courses.length,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (response.meta.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildWarnings(context, l10n, response.meta.warnings),
        ],
      ],
    );
  }

  Widget _buildPeriodTimeSetSelector(AppLocalizations l10n) {
    final selected = _selectedExistingPeriodTimeSet;
    return _ParseImportActionRow(
      key: const ValueKey('school-import-parse-period-time-set'),
      title: l10n.selectPeriodTimeSet,
      subtitle: selected == null
          ? l10n.noPeriodTimeAvailable
          : l10n.periodTimeSetSummary(
              selected.name,
              selected.periodTimes.length,
            ),
      icon: Icons.schedule_outlined,
      trailing: Icons.keyboard_arrow_down,
      onTap: _periodTimeSets.isEmpty ? null : _pickPeriodTimeSet,
    );
  }

  String _bundledPeriodTimeSetName() {
    final bundledName = _response?.timetable.periodTimeSet.name.trim() ?? '';
    if (bundledName.isNotEmpty) return bundledName;
    final name = _nameController?.text.trim() ?? '';
    final timetableName = name.isNotEmpty ? name : 'Imported timetable';
    return importedPeriodTimeSetName(
      timetableName,
      localeCode: widget.provider?.localeCode ?? defaultLocaleCode,
    );
  }

  Widget _buildWarnings(
    BuildContext context,
    AppLocalizations l10n,
    List<String> warnings,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.schoolWebImportWarnings,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < warnings.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(warnings[index])),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRawDisclosure(
    BuildContext context,
    AppLocalizations l10n,
    SkedMotionPolicy motion,
  ) {
    final colors = Theme.of(context).colorScheme;
    final duration = motion.spatialAnimationsEnabled
        ? motion.effects(SkedMotionSpeed.fast)
        : Duration.zero;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _rawExpanded,
            hint: _rawExpanded
                ? l10n.schoolImportParsePageCollapseRaw
                : l10n.schoolImportParsePageExpandRaw,
            child: InkWell(
              onTap: () => setState(() => _rawExpanded = !_rawExpanded),
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.data_object_outlined, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.schoolImportParsePageRawContent),
                      ),
                      AnimatedRotation(
                        turns: _rawExpanded ? 0.5 : 0,
                        duration: duration,
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: motion.scheme.enterCurve,
            alignment: Alignment.topCenter,
            child: _rawExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: _buildRawPreview(context, l10n, embedded: true),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRawPreview(
    BuildContext context,
    AppLocalizations l10n, {
    bool embedded = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = embedded && _rawText.isNotEmpty
        ? _rawText
        : _previewText.isNotEmpty
        ? _previewText
        : l10n.schoolImportParsePageParsing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: embedded
            ? colors.surfaceContainerHighest
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final compact =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final canContinue = _isDone && _response != null && !_hasPopped && !_isBusy;
    final canEdit = _canEdit && !_hasPopped && !_isBusy;
    final cancel = TextButton(
      onPressed: _hasPopped ? null : () => unawaited(_cancelAndPop()),
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
      child: Text(l10n.cancel),
    );
    final edit = OutlinedButton(
      onPressed: canEdit ? _openEditor : null,
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
      child: Text(l10n.schoolImportResultEditorTitle),
    );
    final continueButton = FilledButton(
      onPressed: canContinue ? _continueImport : null,
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      child: Text(l10n.schoolImportParsePageContinue),
    );
    if (_hasDirectImportConfiguration) {
      final canSubmit = _canSubmitConfiguredImport && !_hasPopped && !_isBusy;
      final addAsNew = FilledButton(
        onPressed: canSubmit
            ? () => _submitConfiguredImport(TimetableImportMode.addAsNew)
            : null,
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
        child: Text(l10n.importAsNewTimetable),
      );
      final replace = OutlinedButton(
        onPressed: canSubmit && widget.canReplaceCurrent
            ? () => _submitConfiguredImport(TimetableImportMode.replaceActive)
            : null,
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
        child: Text(l10n.replaceCurrentTimetable),
      );
      return Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: double.infinity, child: addAsNew),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          runSpacing: 0,
                          children: [
                            edit,
                            if (widget.canReplaceCurrent) replace,
                            cancel,
                          ],
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        cancel,
                        edit,
                        if (widget.canReplaceCurrent) replace,
                        addAsNew,
                      ],
                    ),
                  ),
          ),
        ),
      );
    }
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isDone) ...[
                      edit,
                      const SizedBox(height: 4),
                      SizedBox(width: double.infinity, child: continueButton),
                    ],
                    Align(alignment: Alignment.centerRight, child: cancel),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    cancel,
                    if (_isDone) ...[const SizedBox(width: 8), edit],
                    if (_isDone) ...[const SizedBox(width: 8), continueButton],
                  ],
                ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ParseImportActionRow extends StatelessWidget {
  const _ParseImportActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null;
    final muted = colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '$title, $subtitle',
      container: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
              child: Row(
                children: [
                  Icon(icon, color: enabled ? colors.primary : muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: enabled ? colors.onSurface : muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: enabled ? colors.onSurfaceVariant : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Icon(
                      trailing,
                      color: enabled ? colors.onSurfaceVariant : muted,
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

class _ParseImportChoiceRow extends StatelessWidget {
  const _ParseImportChoiceRow({
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
    final muted = colors.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: enabled,
      selected: selected,
      enabled: enabled,
      label: '$title, $subtitle',
      container: true,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_outlined
                        : Icons.radio_button_unchecked_outlined,
                    color: enabled ? colors.primary : muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: enabled ? colors.onSurface : muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: enabled ? colors.onSurfaceVariant : muted,
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

class _ParseImportInfoRow extends StatelessWidget {
  const _ParseImportInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (value.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(value),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
