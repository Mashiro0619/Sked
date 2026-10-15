import '../widgets/sked_detail_row.dart';
import '../widgets/workspace_editor_form.dart';
import '../theme/sked_surface.dart';

import '../widgets/desktop_window_host.dart';
import '../widgets/adaptive_form_columns.dart';
import '../widgets/school_import_summary_preview.dart';
import '../widgets/school_import_save_feedback.dart';
import '../widgets/school_import_week_range_confirmation.dart';
import '../widgets/sked_task_route.dart';
import '../widgets/workspace_route_lifecycle.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../widgets/sked_tooltip.dart';

import '../widgets/sked_date_picker.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_view_state.dart';
import '../providers/app_scope.dart';
import '../services/school_import_api.dart';
import '../theme/sked_expressive_theme.dart';
import '../widgets/school_import_replace_confirmation.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/period_time_set_picker_dialog.dart';
import 'school_import_result_editor_page.dart';

/// The value returned by [SchoolImportParsePage] after a successful parse.
class SchoolImportParseOutcome {
  const SchoolImportParseOutcome({
    required this.response,
    required this.rawText,
    this.applyRequest,
    this.importApplied = false,
  });

  /// The validated response represented by this outcome.
  final SchoolImportResponse response;

  /// The unmodified (or user-edited) JSON text that produced [response].
  final String rawText;

  /// A configured request when the page was opened with import settings.
  /// Preview-only callers receive [response] without an apply request.
  final SchoolImportApplyRequest? applyRequest;

  /// True only after the page's [SchoolImportParsePage.onApply] completed.
  /// Callers must not apply [applyRequest] a second time in this case.
  final bool importApplied;
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
    this.configureImport = false,
    this.canReplaceCurrent = false,
    this.initialPeriodTimeSetId,
    this.maxPreviewCodeUnits = 4096,
    this.maxEditableCodeUnits = 64 * 1024,
    this.onApply,
  });

  static const int defaultMaxPreviewCodeUnits = 4096;
  static const int defaultMaxEditableCodeUnits = 64 * 1024;

  final Stream<SchoolImportStreamEvent> stream;

  /// Enables the import settings and request result explicitly. A stream
  /// preview remains a preview even when it is inside an application scope.
  /// The surrounding scope supplies typed state; [onApply] controls persistence.
  final bool configureImport;
  final bool canReplaceCurrent;
  final String? initialPeriodTimeSetId;
  final int maxPreviewCodeUnits;
  final int maxEditableCodeUnits;

  /// Keeps the configured draft on this page until persistence succeeds.
  /// Without this callback the original return-a-request contract is retained.
  final Future<void> Function(SchoolImportApplyRequest request)? onApply;

  @override
  State<SchoolImportParsePage> createState() => _SchoolImportParsePageState();
}

class _SchoolImportParsePageState extends State<SchoolImportParsePage>
    with WorkspaceRouteLifecycle<SchoolImportParsePage> {
  @override
  AppMode get routeWorkspace => AppMode.student;
  @override
  void workspaceDisabled() {
    unawaited(_cancelSubscription());
  }

  @override
  Future<bool> prepareWorkspaceDisable() async => !_isApplying;

  static const _followResumeTolerance = 1.0;

  StudentViewState? _student;
  SettingsViewState? _settings;
  AppLifecycle? _lifecycle;
  AppDataMaintenance? _maintenance;
  AppDataClearController? _dataClear;
  WorkspaceViewState? _workspaceView;
  Listenable? _importChanges;

  final _textBuffer = StringBuffer();
  final _scrollController = ScrollController();
  StreamSubscription<SchoolImportStreamEvent>? _subscription;
  TextEditingController? _nameController;
  TextEditingController? _totalWeeksController;

  String _rawText = '';
  String _previewText = '';
  SchoolImportResponse? _response;
  String? _error;
  Object? _applyError;
  bool _isApplying = false;
  bool _isDone = false;
  bool _isOpeningEditor = false;
  bool _replaceConfirmationOpen = false;
  bool _weekRangeConfirmationOpen = false;
  bool _hasPopped = false;
  bool _warningsExpanded = false;
  bool _hasFailed = false;
  bool _followOutput = true;
  bool _scrollAnimationActive = false;
  double _lastUserScrollPixels = 0;
  bool _hasUserScrollBaseline = false;
  DateTime? _startDate;
  String _selectedPeriodTimeSetId = '';
  bool _importBundledPeriodTimeSet = false;
  bool _pickerOpen = false;
  final _startDateAnchor = GlobalKey();
  final _periodTimeSetAnchor = GlobalKey();

  bool get _canEdit =>
      _isDone &&
      _response != null &&
      _rawText.trim().isNotEmpty &&
      _rawText.length <= widget.maxEditableCodeUnits &&
      _editorTextWithImportDraft().length <= widget.maxEditableCodeUnits;

  bool get _isBusy =>
      _isOpeningEditor ||
      _replaceConfirmationOpen ||
      _weekRangeConfirmationOpen ||
      _pickerOpen ||
      _isApplying;

  bool get _hasDirectImportConfiguration => widget.configureImport;

  bool get _hasBundledPeriodTimeSet =>
      _response?.timetable.periodTimeSet.periodTimes.isNotEmpty ?? false;

  List<PeriodTimeSet> get _periodTimeSets =>
      _student?.periodTimeSets ?? const <PeriodTimeSet>[];

  PeriodTimeSet? get _selectedExistingPeriodTimeSet {
    for (final item in _periodTimeSets) {
      if (item.id == _selectedPeriodTimeSetId) return item;
    }
    return null;
  }

  bool get _canSave => canSaveSchoolImport(
    lifecycle: _lifecycle,
    maintenance: _maintenance,
    dataClear: _dataClear,
    workspaceView: _workspaceView,
  );

  bool get _canSubmitConfiguredImport =>
      _canSave &&
      _response?.timetable.courses.isNotEmpty == true &&
      (_importBundledPeriodTimeSet || _selectedExistingPeriodTimeSet != null);

  int get _maxParsedCourseWeek {
    var maximum = 0;
    for (final course in _response?.timetable.courses ?? const []) {
      for (final week in course.semesterWeeks) {
        if (week > maximum) maximum = week;
      }
    }
    return maximum;
  }

  int? get _enteredTotalWeeks {
    final text = _totalWeeksController?.text.trim() ?? '';
    return int.tryParse(text);
  }

  bool get _totalWeeksTooShort {
    final entered = _enteredTotalWeeks;
    final maximum = _maxParsedCourseWeek;
    return entered != null && maximum > 0 && entered < maximum;
  }

  @override
  void initState() {
    super.initState();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindImportState();
  }

  @override
  void didUpdateWidget(covariant SchoolImportParsePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configureImport != widget.configureImport) {
      _bindImportState();
    }
  }

  void _bindImportState() {
    final student = widget.configureImport
        ? context.watch<StudentViewState>()
        : null;
    final settings = widget.configureImport
        ? context.watch<SettingsViewState>()
        : null;
    final lifecycle = widget.configureImport
        ? context.watch<AppLifecycle>()
        : null;
    final maintenance = widget.configureImport
        ? context.watch<AppDataMaintenance>()
        : null;
    final dataClear = widget.configureImport
        ? context.watch<AppDataClearController>()
        : null;
    final workspaceView = widget.configureImport
        ? context.watch<WorkspaceViewState>()
        : null;
    if (identical(student, _student) &&
        identical(settings, _settings) &&
        identical(lifecycle, _lifecycle) &&
        identical(maintenance, _maintenance) &&
        identical(dataClear, _dataClear) &&
        identical(workspaceView, _workspaceView)) {
      return;
    }
    _importChanges?.removeListener(_handlePeriodTimeSetsChanged);
    _student = student;
    _settings = settings;
    _lifecycle = lifecycle;
    _maintenance = maintenance;
    _dataClear = dataClear;
    _workspaceView = workspaceView;
    _importChanges = Listenable.merge([
      student,
      settings,
      lifecycle,
      maintenance,
      dataClear,
      workspaceView,
    ])..addListener(_handlePeriodTimeSetsChanged);
    if (_isDone) {
      _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(
        _selectedPeriodTimeSetId,
      );
    }
  }

  void _handleEvent(SchoolImportStreamEvent event) {
    if (!mounted || _hasPopped || _hasFailed || _isDone) return;
    final wasAtBottom = _isAtBottom();
    final shouldAlignDone =
        _followOutput && (wasAtBottom || !_hasUserScrollBaseline);
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
    if (_isDone && shouldAlignDone) {
      _alignCompletedContent();
    } else {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    unawaited(_cancelSubscription());
    _importChanges?.removeListener(_handlePeriodTimeSetsChanged);
    _nameController?.removeListener(_handleImportNameChanged);
    _totalWeeksController?.removeListener(_handleTotalWeeksChanged);
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
    _totalWeeksController?.removeListener(_handleTotalWeeksChanged);
    _totalWeeksController?.dispose();
    _nameController = TextEditingController(text: response.timetable.name)
      ..addListener(_handleImportNameChanged);
    _totalWeeksController = TextEditingController(
      text: response.timetable.totalWeeks.toString(),
    )..addListener(_handleTotalWeeksChanged);
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

  void _handleTotalWeeksChanged() {
    if (mounted) setState(() {});
  }

  void _handlePeriodTimeSetsChanged() {
    if (!mounted || !_isDone) return;
    final resolved = _resolvedPeriodTimeSetId(_selectedPeriodTimeSetId);
    setState(() => _selectedPeriodTimeSetId = resolved);
  }

  String _resolvedPeriodTimeSetId(String preferredId) {
    if (_periodTimeSets.any((item) => item.id == preferredId)) {
      return preferredId;
    }
    final activeId = _student?.activePeriodTimeSetOrNull?.id;
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
    var retriesRemaining = 8;

    void settle(Duration _) {
      if (!mounted ||
          (_isDone && _hasDirectImportConfiguration) ||
          !_scrollController.hasClients ||
          !_followOutput) {
        return;
      }
      final position = _scrollController.position;
      // A stream event can arrive before the new preview text has laid out.
      // Retry a few frames so the first chunk is followed as reliably as
      // later chunks, without making the user wait for a manual scroll.
      if (position.maxScrollExtent > position.pixels + _followResumeTolerance &&
          !_scrollAnimationActive) {
        unawaited(_animateScrollToBottom());
      }
      if (retriesRemaining-- > 0) {
        WidgetsBinding.instance.addPostFrameCallback(settle);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(settle);
  }

  /// The completed result replaces a streamed preview with a different
  /// amount of content and also adds the result actions. If the user was
  /// following the stream, settle the new layout at its actual bottom after
  /// the switcher and footer have laid out. A few frames are enough for both
  /// the normal route and reduced-motion transitions without disturbing users
  /// who intentionally scrolled away from the end.
  void _alignCompletedContent() {
    var framesRemaining = 24;

    void align(_) {
      if (!mounted ||
          !_isDone ||
          !_followOutput ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      // The structured review starts with editable semester metadata. Pinning
      // its bottom (the old transcript behavior) hides that first step on phones.
      final target = _hasDirectImportConfiguration
          ? position.minScrollExtent
          : position.maxScrollExtent;
      if ((position.pixels - target).abs() > _followResumeTolerance) {
        try {
          position.jumpTo(target);
        } catch (_) {
          return;
        }
      }
      if (framesRemaining-- > 0) {
        WidgetsBinding.instance.addPostFrameCallback(align);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(align);
  }

  Future<void> _animateScrollToBottom() async {
    if (_scrollAnimationActive) return;
    _scrollAnimationActive = true;
    try {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // The controller can be detached while a route is being dismissed.
    } finally {
      _scrollAnimationActive = false;
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

  String _editorTextWithImportDraft() {
    final response = _response;
    if (!_hasDirectImportConfiguration || response == null) return _rawText;
    final timetable = response.timetable;
    final changes = <String, Object>{};
    final name = _nameController?.text;
    if (name != null && name != timetable.name) changes['name'] = name.trim();
    final weeks = _enteredTotalWeeks;
    if (weeks != null &&
        weeks >= 1 &&
        weeks <= maxTimetableWeeks &&
        weeks != timetable.totalWeeks) {
      changes['totalWeeks'] = weeks;
    }
    final startDate = _startDate;
    if (startDate != null &&
        startDate != normalizeDateOnly(timetable.startDate)) {
      changes['startDate'] = _formatDate(startDate);
    }
    // Avoid reformatting the parser's/user's JSON when no form values changed.
    if (changes.isEmpty) return _rawText;

    final json = SchoolImportApi.tryDecodeImportObject(_rawText);
    if (json == null) {
      // Keep malformed model output available for manual repair.
      return _rawText;
    }
    final rawTimetable = json.containsKey('timetable')
        ? json['timetable']
        : json;
    if (rawTimetable is! Map<String, dynamic>) return _rawText;
    // Patch only the edited metadata in the original object, preserving all
    // course data and unknown fields in both supported response shapes.
    rawTimetable.addAll(changes);
    final formatted = const JsonEncoder.withIndent('  ').convert(json);
    return formatted.length <= widget.maxEditableCodeUnits
        ? formatted
        : jsonEncode(json);
  }

  Future<void> _openEditor() async {
    if (!_canEdit || _isBusy || !mounted) return;
    final initialText = _editorTextWithImportDraft();
    final scope = AppScope.capture(context);
    setState(() => _isOpeningEditor = true);
    final result = await Navigator.of(context)
        .push<SchoolImportResultEditorOutcome>(
          MaterialPageRoute(
            builder: (_) {
              final page = SchoolImportResultEditorPage(
                initialText: initialText,
                maxEditableCodeUnits: widget.maxEditableCodeUnits,
              );
              return scope?.wrap(page) ?? page;
            },
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
  }

  Future<void> _cancelAndPop() async {
    if (_hasPopped || _isApplying) return;
    _hasPopped = true;
    // Do not make the visible cancel action or system Back wait for a stream
    // implementation's cancellation future. The workflow closes the HTTP
    // session in its finally block after this route returns, while the
    // subscription itself is still cancelled exactly once.
    unawaited(_cancelSubscription());
    if (mounted) {
      completeSkedTaskRoute(context);
    }
  }

  void _continueImport() {
    if (_hasPopped || !_isDone || _response == null || _isBusy) return;
    _hasPopped = true;
    unawaited(_cancelSubscription());
    completeSkedTaskRoute(
      context,
      SchoolImportParseOutcome(response: _response!, rawText: _rawText),
    );
  }

  Future<void> _pickStartDate() async {
    if (_isBusy || _hasPopped || _startDate == null) return;
    final firstDate = DateTime(2020);
    final lastDate = DateTime(2035);
    final current = _startDate!;
    final initialDate = current.isBefore(firstDate)
        ? firstDate
        : current.isAfter(lastDate)
        ? lastDate
        : current;
    final picked = await _runPicker(
      () => showSkedDatePicker(
        context: context,
        workspace: AppMode.student,
        anchorContext: _startDateAnchor.currentContext,
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
    if (_isBusy || _hasPopped) return null;
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
    if (_student == null || _isBusy || _hasPopped || !_canSave) {
      return;
    }
    final result = await _runPicker(
      () => showPeriodTimeSetPickerDialog(
        context,
        anchorContext: _periodTimeSetAnchor.currentContext,
        selectedPeriodTimeSetId: _selectedPeriodTimeSetId,
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedPeriodTimeSetId = _resolvedPeriodTimeSetId(result));
  }

  Future<void> _submitConfiguredImport(TimetableImportMode mode) async {
    if (_hasPopped ||
        _isBusy ||
        !_isDone ||
        _response == null ||
        _response!.timetable.courses.isEmpty ||
        !_canSave) {
      return;
    }
    final dataSession = _maintenance?.dataSessionToken;
    final replacementId = _student?.activeTimetableOrNull?.id;
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
    setState(() => _weekRangeConfirmationOpen = true);
    bool confirmed;
    try {
      confirmed = await confirmSchoolImportWeekRange(
        context,
        nextResponse.timetable,
      );
    } finally {
      if (mounted) setState(() => _weekRangeConfirmationOpen = false);
    }
    if (!mounted ||
        _hasPopped ||
        !routeWorkspaceEnabled ||
        !confirmed ||
        !_canSave ||
        !identical(dataSession, _maintenance?.dataSessionToken) ||
        (mode == TimetableImportMode.replaceActive &&
            replacementId != _student?.activeTimetableOrNull?.id)) {
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
    final request = SchoolImportApplyRequest(
      response: nextResponse,
      mode: mode,
      importBundledPeriodTimeSet: _importBundledPeriodTimeSet,
      targetPeriodTimeSetId: _importBundledPeriodTimeSet ? null : selected!.id,
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
    _hasPopped = true;
    unawaited(_cancelSubscription());
    completeSkedTaskRoute(
      context,
      SchoolImportParseOutcome(
        response: nextResponse,
        rawText: _rawText,
        applyRequest: request,
        importApplied: apply != null,
      ),
    );
  }

  Future<void> _confirmAndSubmitReplacement() async {
    if (_hasPopped ||
        _isBusy ||
        !_isDone ||
        !_canSubmitConfiguredImport ||
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
    if (!mounted) return;
    if (confirmed && !_hasPopped) {
      await _submitConfiguredImport(TimetableImportMode.replaceActive);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!routeWorkspaceEnabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancelAndPop());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: WorkbenchAppBar(
          title: Text(l10n.schoolImportParsePageTitle),
          leading: IconButton(
            tooltip: l10n.cancel,
            onPressed: _hasPopped || _isApplying
                ? null
                : () => unawaited(_cancelAndPop()),
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
                      AdaptiveFormColumns(
                        secondaryWidth: 380,
                        primary: ExpressiveSwitcher(
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
                        secondary: _isDone && _response != null
                            ? LayoutBuilder(
                                builder: (context, constraints) =>
                                    constraints.maxWidth < 500
                                    ? SchoolImportSummaryPreview(
                                        response: _response!,
                                      )
                                    : const SizedBox.shrink(),
                              )
                            : (_error == null || _previewText.isNotEmpty)
                            ? _buildRawPreview(context, l10n)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isDone && _response != null && !_hasPopped)
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
                color: skedReadableAccent(
                  colors,
                  surface: SkedSurface.colorOf(context),
                ),
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
    final response = _response!;
    final timetable = response.timetable;
    final periodCount = timetable.periodTimeSet.periodTimes.length;
    if (_hasDirectImportConfiguration) {
      return _buildDirectImportConfiguration(context, l10n);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
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
        FocusScope(
          canRequestFocus: !_isBusy && !_hasPopped,
          child: IgnorePointer(
            ignoring: _isBusy || _hasPopped,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (nameController != null)
                  SkedEditorTextField(
                    label: l10n.timetableName,
                    controlKey: const ValueKey(
                      'school-import-parse-timetable-name',
                    ),
                    controller: nameController,
                    enabled: !_isApplying,
                    minLines: 1,
                    maxLines: 2,
                    icon: Icons.table_chart_outlined,
                    headline: true,
                  ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final inline =
                        constraints.maxWidth >= 600 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                    final date = KeyedSubtree(
                      key: _startDateAnchor,
                      child: _ParseImportActionRow(
                        key: const ValueKey('school-import-parse-start-date'),
                        title: l10n.semesterStartDate,
                        subtitle: _formatDate(
                          _startDate ?? timetable.startDate,
                        ),
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickStartDate,
                      ),
                    );
                    final weeks = weeksController == null
                        ? const SizedBox.shrink()
                        : _buildTotalWeeksField(context, l10n, weeksController);
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
                  color: Colors.transparent,
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
    return KeyedSubtree(
      key: _periodTimeSetAnchor,
      child: _ParseImportActionRow(
        key: const ValueKey('school-import-parse-period-time-set'),
        title: l10n.selectPeriodTimeSet,
        subtitle: selected == null
            ? l10n.noPeriodTimeAvailable
            : l10n.periodTimeSetSummary(
                selected.name,
                selected.periodTimes.length,
              ),
        icon: Icons.schedule_outlined,
        onTap: _periodTimeSets.isEmpty || !_canSave ? null : _pickPeriodTimeSet,
      ),
    );
  }

  Widget _buildTotalWeeksField(
    BuildContext context,
    AppLocalizations l10n,
    TextEditingController controller,
  ) {
    final warning = _totalWeeksTooShort;
    final warningText = warning
        ? l10n.schoolImportTotalWeeksTooShort(_maxParsedCourseWeek)
        : null;
    final colors = Theme.of(context).colorScheme;
    return SkedEditorTextField(
      label: l10n.totalWeeks,
      controlKey: const ValueKey('school-import-parse-total-weeks'),
      controller: controller,
      enabled: !_isApplying,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      icon: Icons.date_range_outlined,
      suffixIcon: warning
          ? SkedTooltip(
              message: warningText ?? '',
              child: Semantics(
                label: warningText ?? '',
                liveRegion: true,
                child: Icon(Icons.warning_amber_rounded, color: colors.error),
              ),
            )
          : null,
    );
  }

  String _bundledPeriodTimeSetName() {
    final bundledName = _response?.timetable.periodTimeSet.name.trim() ?? '';
    if (bundledName.isNotEmpty) return bundledName;
    final name = _nameController?.text.trim() ?? '';
    final timetableName = name.isNotEmpty ? name : 'Imported timetable';
    return importedPeriodTimeSetName(
      timetableName,
      localeCode: _settings?.localeCode ?? defaultLocaleCode,
    );
  }

  Widget _buildWarnings(
    BuildContext context,
    AppLocalizations l10n,
    List<String> warnings,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = SkedMotionPolicy.of(context);
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
            expanded: _warningsExpanded,
            hint: _warningsExpanded
                ? l10n.schoolImportCollapseWarnings
                : l10n.schoolImportExpandWarnings,
            child: InkWell(
              onTap: () =>
                  setState(() => _warningsExpanded = !_warningsExpanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.schoolWebImportWarnings,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      AnimatedRotation(
                        turns: _warningsExpanded ? 0.5 : 0,
                        duration: duration,
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SkedAnimatedSize(
            duration: duration,
            curve: motion.scheme.enterCurve,
            alignment: Alignment.topCenter,
            child: _warningsExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var index = 0;
                          index < warnings.length;
                          index++
                        ) ...[
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
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildRawPreview(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = _previewText.isNotEmpty
        ? _previewText
        : l10n.schoolImportParsePageParsing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the actual footer constraint so IME and route animations cannot
        // select a layout from a stale window-size snapshot.
        final availableWidth = constraints.maxWidth;
        final compact =
            availableWidth < 600 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final canEdit = _canEdit && !_hasPopped && !_isBusy;
        final edit = OutlinedButton(
          onPressed: canEdit ? _openEditor : null,
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(l10n.schoolImportResultEditorTitle),
        );

        final Widget content;
        if (_hasDirectImportConfiguration) {
          final canSubmit =
              _canSubmitConfiguredImport && !_hasPopped && !_isBusy;
          final addAsNew = FilledButton(
            onPressed: canSubmit
                ? () => _submitConfiguredImport(TimetableImportMode.addAsNew)
                : null,
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            child: Text(l10n.importAsNewTimetable),
          );
          final replace = OutlinedButton(
            onPressed: canSubmit && widget.canReplaceCurrent
                ? _confirmAndSubmitReplacement
                : null,
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
            child: Text(l10n.replaceCurrentTimetable),
          );
          content = compact
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
                        children: [edit, if (widget.canReplaceCurrent) replace],
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
                      edit,
                      if (widget.canReplaceCurrent) replace,
                      addAsNew,
                    ],
                  ),
                );
        } else {
          final continueButton = FilledButton(
            onPressed: _hasPopped || _isBusy ? null : _continueImport,
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            child: Text(l10n.schoolImportParsePageContinue),
          );
          content = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    edit,
                    const SizedBox(height: 4),
                    SizedBox(width: double.infinity, child: continueButton),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [edit, const SizedBox(width: 8), continueButton],
                );
        }

        return Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
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
                  content,
                ],
              ),
            ),
          ),
        );
      },
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
    this.onTap,
  });

  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SkedEditorValueField(
    label: title,
    value: subtitle,
    icon: icon,
    onPressed: onTap == null ? null : (_) => onTap!(),
  );
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
                    color: enabled
                        ? skedReadableAccent(
                            colors,
                            surface: colors.primary.withValues(alpha: 0.12),
                          )
                        : muted,
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
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: SkedDetailRow(
      icon: icon,
      value: text,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    ),
  );
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
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: SkedDetailRow(
      icon: icon,
      label: label,
      value: value,
      stacked: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
  );
}
