import '../widgets/sked_confirmation_dialog.dart';
import '../widgets/workspace_editor_form.dart';
import '../widgets/sked_time_picker.dart';
import '../widgets/desktop_window_host.dart';
import '../widgets/workspace_route_lifecycle.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

import '../widgets/sked_tooltip.dart';

import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/data_transfer_controller.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../providers/app_scope.dart';
import '../services/export_service.dart';
import '../services/text_file_picker.dart';
import '../theme/sked_expressive_theme.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/export_save_flow.dart';
import '../widgets/sked_popup_menu.dart';
import '../widgets/text_transfer_widgets.dart';
import '../widgets/ui_command.dart';
import '../widgets/workbench_chrome_metrics.dart';
import '../widgets/adaptive_navigation_scope.dart';
import '../widgets/expressive_empty_state.dart';
import '../widgets/sked_task_session.dart';

part 'period_times_editor.dart';

enum _PeriodTimesMenuAction {
  importTemplate,
  importTemplateText,
  exportTemplate,
  saveTemplate,
  exportTemplateText,
  deleteSet,
}

enum _UnsavedPeriodTimesExitAction { keepEditing, retry, discard }

typedef PeriodTimesTextPicker = Future<String?> Function({
  required List<String> allowedExtensions,
});

/// 这块单独拆页，不塞进设置弹窗里，不然一口气改多节时间会很难操作。
class PeriodTimesPage extends StatefulWidget {
  const PeriodTimesPage({
    super.key,
    required this.periodTimeSetId,
    this.embedded = false,
    ExportService? exportService,
    this.textFilePicker = TextFilePicker.pickText,
  }) : exportService = exportService ?? const ExportService();

  final String periodTimeSetId;
  final bool embedded;
  final ExportService exportService;
  final PeriodTimesTextPicker textFilePicker;

  @override
  State<PeriodTimesPage> createState() => _PeriodTimesPageState();
}

class _PeriodTimesPageState extends State<PeriodTimesPage>
    with WidgetsBindingObserver, WorkspaceRouteLifecycle<PeriodTimesPage> {
  @override
  AppMode get routeWorkspace => AppMode.student;
  @override
  Future<bool> prepareWorkspaceDisable() => _flushAndExit(retire: true);

  static const _autoSaveDelay = Duration(milliseconds: 400);

  late final TextEditingController _nameController;
  // Replace the list on time edits so unchanged drafts can retain their table.
  late List<CoursePeriodTime> _periodTimes;
  _PeriodEditorTable? _periodTable;
  final _scrollController = ScrollController();
  final _scrollViewportKey = GlobalKey();
  final _periodRowKeys = <GlobalKey>[];
  Object? _layoutSignature;
  int _scrollGeneration = 0;
  var _loading = true;
  var _timePickerOpen = false;
  var _menuActionInProgress = false;
  var _autoSaveInProgress = false;
  var _isDisposing = false;
  var _retired = false;
  var _allowPop = true;
  var _isHandlingPop = false;
  Timer? _autoSaveDebounce;
  Future<bool>? _autoSaveFlushOperation;
  ({StudentViewState view, StudentCommands commands})? _pendingAutoSaveOwner;
  PeriodTimeSet? _pendingAutoSaveValue;
  var _autoSaveRevision = 0;
  int? _pendingAutoSaveRevision;
  int? _failedAutoSaveRevision;
  var _persistedAutoSaveRevision = 0;
  VoidCallback? _unregisterPageExitGuard;
  ModalRoute<dynamic>? _guardedRoute;
  RegisterAdaptivePageExitGuard? _pageExitRegistrar;

  bool get _interactionBlocked =>
      _retired || _menuActionInProgress || _isHandlingPop;

  bool get _menuBlocked => _interactionBlocked || _autoSaveInProgress;

  ExportService get _exportService => widget.exportService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registrar = AdaptiveNavigationScope.maybeOf(context)
        ?.registerPageExitGuard;
    final route = ModalRoute.of(context);
    if (registrar != _pageExitRegistrar || route != _guardedRoute) {
      _unregisterPageExitGuard?.call();
      _pageExitRegistrar = registrar;
      _guardedRoute = route;
      _unregisterPageExitGuard = registrar != null && route != null
          ? registrar(route, _flushAndExit)
          : null;
    }
    if (_loading) {
      final studentView = context.read<StudentViewState>();
      final periodTimeSet = studentView.periodTimeSetForId(
        widget.periodTimeSetId,
      );
      if (periodTimeSet != null) {
        _nameController.text = periodTimeSet.name;
        _periodTimes = periodTimeSet.periodTimes
            .map((item) => item.copyWith())
            .toList();
      } else {
        _periodTimes = [];
      }
      _resetPeriodRowKeys();
      _loading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unregisterPageExitGuard?.call();
    _isDisposing = true;
    unawaited(
      _flushPendingAutoSave().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Final period time auto-save failed: $error\n$stackTrace');
        return false;
      }),
    );
    _autoSaveDebounce?.cancel();
    _scrollGeneration++;
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingAutoSave());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_retired || !routeWorkspaceEnabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exists =
        context.watch<StudentViewState>().periodTimeSetForId(
          widget.periodTimeSetId,
        ) !=
        null;
    if (!exists) {
      return Scaffold(
        appBar: widget.embedded
            ? null
            : WorkbenchAppBar(title: Text(l10n.periodTimesTitle)),
        body: ExpressiveEmptyState(
          icon: Icons.schedule,
          title: l10n.noPeriodTimeAvailable,
        ),
      );
    }

    final page = Scaffold(
      appBar: widget.embedded
          ? null
          : WorkbenchAppBar(
              title: Text(l10n.periodTimesTitle),
              actions: [_buildMenu(l10n)],
            ),
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(
              key: const ValueKey('period-times-editor-guard'),
              absorbing: _interactionBlocked,
              child: _buildEditorBody(l10n),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: UiCommandBusyIndicator(
                busy: _menuActionInProgress || _autoSaveInProgress,
                showDelay: const Duration(milliseconds: 250),
              ),
            ),
          ],
        ),
      ),
    );
    return PopScope<void>(
      canPop: _allowPop && !_menuActionInProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_flushAndPop());
        }
      },
      child: page,
    );
  }

  Widget _buildMenu(AppLocalizations l10n) =>
      SkedPopupMenuButton<_PeriodTimesMenuAction>(
        key: const ValueKey('period-time-set-menu'),
        tooltip: l10n.importExport,
        enabled: !_menuBlocked,
        onSelected: (action) => unawaited(_handleMenuAction(action)),
        itemBuilder: (context) => [
          SkedPopupMenuItem(
            value: _PeriodTimesMenuAction.importTemplate,
            child: Text(l10n.importPeriodTemplate),
          ),
          SkedPopupMenuItem(
            value: _PeriodTimesMenuAction.importTemplateText,
            child: Text(l10n.importPeriodTemplateText),
          ),
          SkedPopupMenuItem(
            value: _PeriodTimesMenuAction.exportTemplate,
            child: Text(l10n.sharePeriodTemplate),
          ),
          SkedPopupMenuItem(
            value: _PeriodTimesMenuAction.saveTemplate,
            child: Text(l10n.saveTemplateToFile),
          ),
          SkedPopupMenuItem(
            value: _PeriodTimesMenuAction.exportTemplateText,
            child: Text(l10n.exportPeriodTemplateText),
          ),
          SkedPopupMenuDivider(),
          SkedPopupMenuItem(
            value: _PeriodTimesMenuAction.deleteSet,
            child: Text(
              l10n.deletePeriodTimeSet,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      );

  _PeriodEditorSaveState get _saveState {
    if (_hasInvalidPeriodTimes) return _PeriodEditorSaveState.invalid;
    if (_failedAutoSaveRevision == _autoSaveRevision) {
      return _PeriodEditorSaveState.failed;
    }
    if (_autoSaveInProgress) return _PeriodEditorSaveState.saving;
    if (_persistedAutoSaveRevision != _autoSaveRevision) {
      return _PeriodEditorSaveState.pending;
    }
    return _PeriodEditorSaveState.saved;
  }

  Widget _buildEditorBody(AppLocalizations l10n) => LayoutBuilder(
    builder: (context, constraints) {
      final signature = (
        constraints.maxWidth,
        MediaQuery.textScalerOf(context).scale(14),
        l10n.localeName,
        Theme.of(context).platform,
      );
      if (_layoutSignature != signature) {
        final anchor = _captureScrollAnchor();
        _layoutSignature = signature;
        if (anchor != null) _restoreScrollAnchor(anchor);
      }
      final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
      final width = math.min(
        800.0,
        math.max(0.0, constraints.maxWidth - padding * 2),
      );
      return ScrollConfiguration(
        behavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
          },
        ),
        child: SizedBox.expand(
          key: _scrollViewportKey,
          child: ListView(
            key: const ValueKey('period-times-editor-scroll-view'),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: SizedBox(
                  key: const ValueKey('period-times-editor-content'),
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PeriodEditorHeading(
                        action: widget.embedded ? _buildMenu(l10n) : null,
                        controller: _nameController,
                        periodCount: _periodTimes.length,
                        saveState: _saveState,
                        onChanged: (_) => _scheduleAutoSave(debounce: true),
                        onSubmitted: (_) => unawaited(_flushPendingAutoSave()),
                        onRetry: _menuBlocked
                            ? null
                            : () => unawaited(_flushPendingAutoSave()),
                      ),
                      const SizedBox(height: 16),
                      _tableForCurrentDraft(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _tableForCurrentDraft() {
    final previous = _periodTable;
    final actionsEnabled = !_interactionBlocked;
    final timeEnabled = actionsEnabled && !_timePickerOpen;
    if (previous == null ||
        !identical(previous.periodTimes, _periodTimes) ||
        previous.actionsEnabled != actionsEnabled ||
        previous.timeEnabled != timeEnabled) {
      _periodTable = _PeriodEditorTable(
        periodTimes: _periodTimes,
        rowKeys: List.unmodifiable(_periodRowKeys),
        actionsEnabled: actionsEnabled,
        timeEnabled: timeEnabled,
        onPickTime: _pickPeriodTime,
        onDelete: _removePeriod,
        onAdd: _addPeriod,
      );
    }
    // Name/save updates still rebuild PopScope, menus and status immediately.
    // Retain only the unrelated table; inherited layout changes reach it normally.
    return _periodTable!;
  }

  void _resetPeriodRowKeys() {
    _periodRowKeys
      ..clear()
      ..addAll(List.generate(_periodTimes.length, (_) => GlobalKey()));
  }

  _PeriodScrollAnchor? _captureScrollAnchor() {
    if (!_scrollController.hasClients || _scrollController.offset <= 0) {
      return null;
    }
    final viewport = _scrollViewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (final key in _periodRowKeys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final leading = box.localToGlobal(Offset.zero).dy - top;
      if (leading + box.size.height > 0 && leading < viewport.size.height) {
        return _PeriodScrollAnchor(key, leading);
      }
    }
    return null;
  }

  void _restoreScrollAnchor(_PeriodScrollAnchor anchor) {
    final generation = ++_scrollGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _scrollGeneration ||
          !_scrollController.hasClients) {
        return;
      }
      final viewport = _scrollViewportKey.currentContext?.findRenderObject();
      final row = anchor.key.currentContext?.findRenderObject();
      if (viewport is! RenderBox || row is! RenderBox || !row.hasSize) return;
      final leading =
          row.localToGlobal(Offset.zero).dy -
          viewport.localToGlobal(Offset.zero).dy;
      final position = _scrollController.position;
      final offset = (position.pixels + leading - anchor.leading).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - offset).abs() > .5) {
        _scrollController.jumpTo(offset);
      }
    });
  }

  void _revealAddedPeriod(GlobalKey key) {
    final generation = ++_scrollGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollGeneration) return;
      final row = key.currentContext;
      if (row == null) return;
      final motion = SkedMotionPolicy.of(context);
      unawaited(
        Scrollable.ensureVisible(
          row,
          alignment: 1,
          duration: motion.spatialAnimationsEnabled
              ? motion.effects(SkedMotionSpeed.fast)
              : Duration.zero,
        ),
      );
    });
  }

  Future<void> _handleMenuAction(_PeriodTimesMenuAction action) async {
    if (_interactionBlocked) {
      return;
    }
    _setMenuActionInProgress(true);
    try {
      final saved = await _flushPendingAutoSave();
      if (!saved || !mounted) {
        return;
      }
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Run period time menu action ${action.name}',
        command: () async {
          switch (action) {
            case _PeriodTimesMenuAction.importTemplate:
              await _importTemplate();
              return;
            case _PeriodTimesMenuAction.importTemplateText:
              await _importTemplateFromText();
              return;
            case _PeriodTimesMenuAction.exportTemplate:
              await _shareTemplate();
              return;
            case _PeriodTimesMenuAction.saveTemplate:
              await _saveTemplateToFile();
              return;
            case _PeriodTimesMenuAction.exportTemplateText:
              await _exportTemplateAsText();
              return;
            case _PeriodTimesMenuAction.deleteSet:
              await _deleteSet();
              return;
          }
        },
      );
    } finally {
      _setMenuActionInProgress(false);
    }
  }

  void _setMenuActionInProgress(bool value) {
    if (mounted) {
      setState(() => _menuActionInProgress = value);
    } else {
      _menuActionInProgress = value;
    }
  }

  void _addPeriod() {
    if (_interactionBlocked) {
      return;
    }
    late List<CoursePeriodTime> next;
    try {
      next = buildPeriodTimesForCount(
        _periodTimes.length + 1,
        source: _periodTimes,
      );
    } on PeriodTimesExceedDayException {
      _showMessage(AppLocalizations.of(context).periodTimesDayFull);
      return;
    } on FormatException {
      _showMessage(AppLocalizations.of(context).periodTimesInvalidExitMessage);
      return;
    }
    setState(() {
      _periodTimes = next;
      _periodRowKeys.add(GlobalKey());
    });
    _scheduleAutoSave();
    _revealAddedPeriod(_periodRowKeys.last);
  }

  void _removePeriod(int index) {
    if (_interactionBlocked ||
        index < 0 ||
        index >= _periodTimes.length ||
        _periodTimes.length <= 1) {
      return;
    }
    var anchor = _captureScrollAnchor();
    if (anchor?.key == _periodRowKeys[index]) {
      final neighbor = index + 1 < _periodRowKeys.length
          ? index + 1
          : index - 1;
      anchor = _PeriodScrollAnchor(_periodRowKeys[neighbor], anchor!.leading);
    }
    setState(() {
      _periodRowKeys.removeAt(index);
      final next = [..._periodTimes]..removeAt(index);
      _periodTimes = List.generate(
        next.length,
        (itemIndex) => next[itemIndex].copyWith(index: itemIndex + 1),
      );
    });
    _scheduleAutoSave();
    if (anchor != null) _restoreScrollAnchor(anchor);
  }

  PeriodTimeSet _currentAutoSaveValue() {
    return PeriodTimeSet(
      id: widget.periodTimeSetId,
      name: _nameController.text.trim(),
      periodTimes: List.generate(
        _periodTimes.length,
        (index) => _periodTimes[index].copyWith(index: index + 1),
      ),
    );
  }

  bool get _hasInvalidPeriodTimes {
    for (var index = 0; index < _periodTimes.length; index++) {
      final period = _periodTimes[index];
      if (period.startMinutes < 0 ||
          period.endMinutes >= 24 * 60 ||
          period.endMinutes <= period.startMinutes) {
        return true;
      }
      if (index > 0 &&
          period.startMinutes < _periodTimes[index - 1].endMinutes) {
        return true;
      }
    }
    return false;
  }

  void _scheduleAutoSave({bool debounce = false}) {
    if (!mounted || _isDisposing || _retired) {
      return;
    }
    _allowPop = false;
    final revision = ++_autoSaveRevision;
    if (_hasInvalidPeriodTimes) {
      _pendingAutoSaveOwner = null;
      _pendingAutoSaveValue = null;
      _pendingAutoSaveRevision = null;
      _failedAutoSaveRevision = null;
      _autoSaveDebounce?.cancel();
      _autoSaveDebounce = null;
      setState(() {});
      return;
    }
    _pendingAutoSaveOwner = (
      view: context.read<StudentViewState>(),
      commands: context.read<StudentCommands>(),
    );
    _pendingAutoSaveValue = _currentAutoSaveValue();
    _pendingAutoSaveRevision = revision;
    _failedAutoSaveRevision = null;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    if (debounce) {
      _autoSaveDebounce = Timer(
        _autoSaveDelay,
        () => unawaited(_flushPendingAutoSave()),
      );
    } else {
      unawaited(_flushPendingAutoSave());
    }
    setState(() {});
  }

  Future<bool> _flushPendingAutoSave() async {
    final pendingOwner = _pendingAutoSaveOwner;
    if (pendingOwner != null &&
        pendingOwner.view.periodTimeSetForId(widget.periodTimeSetId) == null) {
      // A removed shared resource cannot receive this page's delayed draft.
      _discardPendingAutoSave();
      return true;
    }
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    if (_autoSaveFlushOperation == null &&
        _pendingAutoSaveRevision != null &&
        _pendingAutoSaveRevision == _failedAutoSaveRevision) {
      _failedAutoSaveRevision = null;
    }

    while (true) {
      final operation = _autoSaveFlushOperation ?? _startAutoSaveOperation();
      if (operation == null) {
        return true;
      }
      try {
        final saved = await operation;
        if (!saved && _failedAutoSaveRevision == _pendingAutoSaveRevision) {
          return false;
        }
      } catch (error, stackTrace) {
        if (!_isDisposing) {
          debugPrint(
            'Period time auto-save ended unexpectedly: '
            '$error\n$stackTrace',
          );
        }
        return false;
      }
    }
  }

  Future<bool>? _startAutoSaveOperation() {
    if (_pendingAutoSaveOwner == null ||
        _pendingAutoSaveValue == null ||
        _pendingAutoSaveRevision == null ||
        _failedAutoSaveRevision == _pendingAutoSaveRevision) {
      return null;
    }

    late final Future<bool> operation;
    operation = _drainPendingAutoSaves().whenComplete(() {
      if (identical(_autoSaveFlushOperation, operation)) {
        _autoSaveFlushOperation = null;
      }
    });
    _autoSaveFlushOperation = operation;
    return operation;
  }

  Future<bool> _drainPendingAutoSaves() async {
    _setAutoSaveInProgress(true);
    try {
      while (true) {
        final owner = _pendingAutoSaveOwner;
        final value = _pendingAutoSaveValue;
        final revision = _pendingAutoSaveRevision;
        if (owner == null || value == null || revision == null) {
          _failedAutoSaveRevision = null;
          final canPop =
              _persistedAutoSaveRevision == _autoSaveRevision &&
              !_hasInvalidPeriodTimes;
          if (mounted && !_isDisposing) {
            setState(() => _allowPop = canPop);
          } else {
            _allowPop = canPop;
          }
          return true;
        }

        _pendingAutoSaveOwner = null;
        _pendingAutoSaveValue = null;
        _pendingAutoSaveRevision = null;
        _autoSaveDebounce?.cancel();
        _autoSaveDebounce = null;
        try {
          await owner.commands.updatePeriodTimeSet(value);
          _persistedAutoSaveRevision = math.max(
            _persistedAutoSaveRevision,
            revision,
          );
        } catch (error, stackTrace) {
          debugPrint('Period time auto-save failed: $error\n$stackTrace');
          if (_pendingAutoSaveValue == null && revision == _autoSaveRevision) {
            _pendingAutoSaveOwner = owner;
            _pendingAutoSaveValue = value;
            _pendingAutoSaveRevision = revision;
            _failedAutoSaveRevision = revision;
            if (mounted && !_isDisposing && !_isHandlingPop) {
              showUiFailureFeedback(
                context: context,
                message: AppLocalizations.of(context).saveFailedRetry,
              );
            }
            return false;
          }
        }
      }
    } finally {
      _setAutoSaveInProgress(false);
    }
  }

  void _setAutoSaveInProgress(bool value) {
    if (mounted && !_isDisposing) {
      setState(() => _autoSaveInProgress = value);
    } else {
      _autoSaveInProgress = value;
    }
  }

  Future<void> _flushAndPop() async {
    await _flushAndExit();
  }

  Future<bool> _flushAndExit({bool retire = false}) async {
    if (_retired || !mounted) return true;
    if (_isHandlingPop || _menuActionInProgress || _timePickerOpen) {
      return false;
    }
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    var leaving = false;
    setState(() => _isHandlingPop = true);
    FocusScope.of(context).unfocus();
    try {
      await WidgetsBinding.instance.endOfFrame;
      while (mounted) {
        final saved = await _flushPendingAutoSave();
        if (!mounted) return false;
        // An invalid draft has no queued write, but is still unsaved.
        if (saved && _allowPop) break;

        final action = await _showUnsavedExitDialog(
          canRetry: _pendingAutoSaveRevision != null,
        );
        if (!mounted) return false;
        switch (action) {
          case _UnsavedPeriodTimesExitAction.retry:
            continue;
          case _UnsavedPeriodTimesExitAction.discard:
            _discardPendingAutoSave();
            setState(() => _allowPop = true);
          case _UnsavedPeriodTimesExitAction.keepEditing:
          case null:
            return false;
        }
        break;
      }

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !navigator.mounted) return false;
      if (retire) {
        // Window close, workspace disable and backup replacement share this
        // guard. Retire the old draft before replacement data is published,
        // including when another route (such as the restore page) is above it.
        _discardPendingAutoSave();
        setState(() => _retired = true);
        leaving = true;
        if (route != null && route.isActive && !route.isFirst) {
          navigator.removeRoute(route);
        }
        return true;
      }
      if (route?.isCurrent != true) return false;
      leaving = true;
      navigator.pop();
      return true;
    } finally {
      if (!leaving && mounted) setState(() => _isHandlingPop = false);
    }
  }

  void _discardPendingAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    _pendingAutoSaveOwner = null;
    _pendingAutoSaveValue = null;
    _pendingAutoSaveRevision = null;
    _failedAutoSaveRevision = null;
  }

  Future<_UnsavedPeriodTimesExitAction?> _showUnsavedExitDialog({
    required bool canRetry,
  }) {
    return showExpressiveDialog<_UnsavedPeriodTimesExitAction>(
      context: context,
      barrierDismissible: false,
      waitForTransitionComplete: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return SkedConfirmationDialog(
          title: Text(l10n.periodTimesUnsavedExitTitle),
          content: Text(
            canRetry
                ? l10n.periodTimesSaveFailureExitMessage
                : l10n.periodTimesInvalidExitMessage,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(_UnsavedPeriodTimesExitAction.keepEditing),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () =>
                  Navigator.of(context)
                      .pop(_UnsavedPeriodTimesExitAction.discard),
              child: Text(l10n.discardChangesAndExit),
            ),
            if (canRetry)
              FilledButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pop(_UnsavedPeriodTimesExitAction.retry),
                child: Text(l10n.retrySave),
              ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSet() async {
    final studentCommands = context.read<StudentCommands>();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final name = _nameController.text.trim().isEmpty
            ? l10n.currentPeriodTimeSet
            : _nameController.text.trim();
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return SkedConfirmationDialog(
          title: Text(l10n.deletePeriodTimeSetTitle),
          content: Text(l10n.deletePeriodTimeSetMessage(name)),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await studentCommands.deletePeriodTimeSet(widget.periodTimeSetId);
      if (mounted && route?.isCurrent == true) {
        navigator.pop(true);
      }
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _importTemplate() async {
    final transfers = context.read<DataTransferController>();
    final settingsView = context.read<SettingsViewState>();
    final l10n = AppLocalizations.of(context);
    final source = await widget.textFilePicker(
      allowedExtensions: const ['json'],
    );
    if (!mounted) {
      return;
    }
    if (source == null) {
      return;
    }
    try {
      final imported = transfers.importPeriodTimesJson(source);
      final count = imported.length;
      if (count == 0) {
        throw FormatException(
          noPeriodTimesInImportMessage(localeCode: settingsView.localeCode),
        );
      }
      setState(() {
        _periodTimes = imported;
        _resetPeriodRowKeys();
      });
      _scheduleAutoSave();
      _showMessage(l10n.importedPeriodTimesCount(count));
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(l10n.importFailedCheckContent);
    }
  }

  Future<void> _importTemplateFromText() async {
    final l10n = AppLocalizations.of(context);
    final studentView = context.read<StudentViewState>();
    final transfers = context.read<DataTransferController>();
    final settingsView = context.read<SettingsViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    final workspaceView = context.read<WorkspaceViewState>();
    final workspaces = context.read<WorkspaceCommands>();
    final appScope = AppScope.capture(context)!;
    final ownerRoute = ModalRoute.of(context);
    await Navigator.of(context, rootNavigator: widget.embedded).push(
      MaterialPageRoute(
        builder: (_) => appScope.wrap(
          SkedTaskRouteGuard(
            maintenance: maintenance,
            workspaceView: workspaceView,
            workspaces: workspaces,
            targetChanges: studentView,
            workspace: AppMode.student,
            isOwnerActive: () =>
                mounted && !_retired && ownerRoute?.isActive != false,
            isTargetCurrent: () =>
                studentView.periodTimeSetForId(widget.periodTimeSetId) != null,
            child: TextImportPage(
              title: l10n.importPeriodTemplateText,
              onSubmit: (_, content) async {
                if (!mounted || _retired) {
                  return false;
                }
                if (studentView.periodTimeSetForId(widget.periodTimeSetId) ==
                    null) {
                  return false;
                }
                try {
                  final imported = transfers.importPeriodTimesJson(content);
                  final count = imported.length;
                  if (count == 0) {
                    throw FormatException(
                      noPeriodTimesInImportMessage(
                        localeCode: settingsView.localeCode,
                      ),
                    );
                  }
                  if (!mounted) {
                    return false;
                  }
                  setState(() {
                    _periodTimes = imported;
                    _resetPeriodRowKeys();
                  });
                  _scheduleAutoSave();
                  _showMessage(l10n.importedPeriodTimesCount(count));
                  return true;
                } on FormatException catch (error) {
                  _showMessage(error.message);
                  return false;
                } catch (_) {
                  _showMessage(l10n.importFailedCheckContent);
                  return false;
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareTemplate() async {
    await _exportService.shareFile(
      ExportPayload(
        fileName: 'Sked_period_times.json',
        content: encodePeriodTimesEnvelope(_periodTimes),
      ),
    );
  }

  Future<void> _exportTemplateAsText() async {
    final l10n = AppLocalizations.of(context);
    await showTextExportDialog(
      context,
      title: l10n.exportPeriodTemplateText,
      content: encodePeriodTimesEnvelope(_periodTimes),
    );
  }

  Future<void> _saveTemplateToFile() => saveExportWithFeedback(
    context: context,
    service: _exportService,
    payload: ExportPayload(
      fileName: 'Sked_period_times.json',
      content: encodePeriodTimesEnvelope(_periodTimes),
    ),
    isCurrent: () => !_retired && routeWorkspaceEnabled,
  );

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPeriodTime(
    int index, {
    required bool isStart,
    required BuildContext anchorContext,
  }) async {
    if (_interactionBlocked ||
        _timePickerOpen ||
        index < 0 ||
        index >= _periodTimes.length) {
      return;
    }
    setState(() => _timePickerOpen = true);
    final period = _periodTimes[index];
    final rowKey = _periodRowKeys[index];
    final initialMinutes = normalizeMinuteOfDay(
      isStart ? period.startMinutes : period.endMinutes,
    );
    try {
      final picked = await showSkedTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: initialMinutes ~/ 60,
          minute: initialMinutes % 60,
        ),
        anchorContext: anchorContext,
        workspace: AppMode.student,
        alwaysUse24HourFormat: true,
      );
      if (!mounted || _retired || picked == null) return;
      final targetIndex = _periodRowKeys.indexOf(rowKey);
      if (targetIndex < 0) return;
      final minutes = (picked.hour * 60) + picked.minute;
      setState(() {
        final currentPeriod = _periodTimes[targetIndex];
        final next = [..._periodTimes];
        next[targetIndex] = isStart
            ? currentPeriod.copyWith(startMinutes: minutes)
            : currentPeriod.copyWith(endMinutes: minutes);
        _periodTimes = next;
      });
      _scheduleAutoSave();
    } finally {
      if (mounted) {
        setState(() => _timePickerOpen = false);
      } else {
        _timePickerOpen = false;
      }
    }
  }
}
