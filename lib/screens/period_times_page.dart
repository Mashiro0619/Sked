import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/export_service.dart';
import '../services/text_file_picker.dart';
import '../theme/sked_expressive_theme.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/sked_popup_menu.dart';
import '../widgets/text_transfer_widgets.dart';
import '../widgets/ui_command.dart';

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
    ExportService? exportService,
    this.textFilePicker = TextFilePicker.pickText,
  }) : exportService = exportService ?? const ExportService();

  final String periodTimeSetId;
  final ExportService exportService;
  final PeriodTimesTextPicker textFilePicker;

  @override
  State<PeriodTimesPage> createState() => _PeriodTimesPageState();
}

class _PeriodTimesPageState extends State<PeriodTimesPage>
    with WidgetsBindingObserver {
  static const _autoSaveDelay = Duration(milliseconds: 400);

  late final TextEditingController _nameController;
  late List<CoursePeriodTime> _periodTimes;
  var _loading = true;
  var _timePickerOpen = false;
  var _menuActionInProgress = false;
  var _autoSaveInProgress = false;
  var _isDisposing = false;
  var _allowPop = true;
  var _isHandlingPop = false;
  Timer? _autoSaveDebounce;
  Future<bool>? _autoSaveFlushOperation;
  TimetableProvider? _pendingAutoSaveProvider;
  PeriodTimeSet? _pendingAutoSaveValue;
  var _autoSaveRevision = 0;
  int? _pendingAutoSaveRevision;
  int? _failedAutoSaveRevision;
  var _persistedAutoSaveRevision = 0;

  bool get _interactionBlocked => _menuActionInProgress || _isHandlingPop;

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
    if (_loading) {
      final provider = context.read<TimetableProvider>();
      final periodTimeSet = provider.periodTimeSetForId(widget.periodTimeSetId);
      if (periodTimeSet != null) {
        _nameController.text = periodTimeSet.name;
        _periodTimes = periodTimeSet.periodTimes
            .map((item) => item.copyWith())
            .toList();
      } else {
        _nameController.text = AppLocalizations.of(context).periodTimesTitle;
        _periodTimes = buildPeriodTimesForCount(10);
      }
      _loading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposing = true;
    unawaited(
      _flushPendingAutoSave().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Final period time auto-save failed: $error\n$stackTrace');
        return false;
      }),
    );
    _autoSaveDebounce?.cancel();
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
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final page = Scaffold(
      appBar: AppBar(
        title: Text(l10n.periodTimesTitle),
        actions: [
          IconButton(
            tooltip: l10n.addOnePeriod,
            onPressed: _interactionBlocked ? null : _addPeriod,
            icon: const Icon(Icons.add),
          ),
          SkedPopupMenuButton<_PeriodTimesMenuAction>(
            tooltip: l10n.importExport,
            enabled: !_menuBlocked,
            onSelected: (action) {
              unawaited(_handleMenuAction(action));
            },
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
                child: Text(l10n.deletePeriodTimeSet),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            UiCommandBusyIndicator(
              busy: _menuActionInProgress || _autoSaveInProgress,
              showDelay: const Duration(milliseconds: 250),
            ),
            Expanded(
              child: AbsorbPointer(
                key: const ValueKey('period-times-editor-guard'),
                absorbing: _interactionBlocked,
                child: _buildEditorBody(l10n),
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

  Widget _buildEditorBody(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final availableWidth = (constraints.maxWidth - horizontalPadding * 2)
            .clamp(0.0, double.infinity);
        final useTwoColumns =
            constraints.maxWidth >= 840 &&
            textScale <= 1.3 &&
            (availableWidth - 12) / 2 >= 360;
        final maxContentWidth = useTwoColumns ? 1120.0 : 720.0;

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
          child: ListView(
            key: const ValueKey('period-times-editor-scroll-view'),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              24,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Center(
                child: ConstrainedBox(
                  key: const ValueKey(
                    'responsive-settings-single-column-content',
                  ),
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          onChanged: (_) => _scheduleAutoSave(debounce: true),
                          onSubmitted: (_) {
                            unawaited(_flushPendingAutoSave());
                          },
                          decoration: InputDecoration(
                            labelText: l10n.periodTimeSetName,
                            prefixIcon: const Icon(Icons.schedule_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, gridConstraints) {
                            final cardWidth = useTwoColumns
                                ? (gridConstraints.maxWidth - 12) / 2
                                : gridConstraints.maxWidth;
                            return Wrap(
                              key: const ValueKey('period-times-editor-grid'),
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (
                                  var index = 0;
                                  index < _periodTimes.length;
                                  index++
                                )
                                  SizedBox(
                                    key: ValueKey(
                                      'period-card-${_periodTimes[index].index}',
                                    ),
                                    width: cardWidth,
                                    child: _buildPeriodCard(index),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilledButton.icon(
                            onPressed: _interactionBlocked ? null : _addPeriod,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addOnePeriod),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodCard(int index) {
    final l10n = AppLocalizations.of(context);
    final period = _periodTimes[index];
    final previous = index == 0 ? null : _periodTimes[index - 1];
    final duration = period.endMinutes - period.startMinutes;
    final gap = previous == null
        ? null
        : period.startMinutes - previous.endMinutes;
    final invalid = duration <= 0 || (previous != null && gap! < 0);

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final shapeScheme = Theme.of(context).extension<SkedShapeScheme>();
    final cardShape =
        shapeScheme?.control ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final compactShape =
        shapeScheme?.compact ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Material(
      color: colors.surfaceContainerLow,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: compactShape,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          l10n.periodNumberLabel(period.index),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_periodTimes.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.deleteThisPeriod,
                    onPressed: () => _removePeriod(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _PeriodTimeRange(
              startLabel: l10n.startTime,
              startValue: formatMinutes(period.startMinutes),
              endLabel: l10n.endTime,
              endValue: formatMinutes(period.endMinutes),
              error: invalid,
              enabled: !_timePickerOpen,
              onPickStart: () => _pickPeriodTime(index, isStart: true),
              onPickEnd: () => _pickPeriodTime(index, isStart: false),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _MetaChip(
                  label: l10n.durationMinutes(duration > 0 ? duration : 0),
                  backgroundColor: colors.surfaceContainerHighest,
                  foregroundColor: colors.onSurfaceVariant,
                ),
                if (gap != null)
                  _MetaChip(
                    label: l10n.gapFromPrevious(gap > 0 ? gap : 0),
                    backgroundColor: colors.surfaceContainerHighest,
                    foregroundColor: colors.onSurfaceVariant,
                  ),
              ],
            ),
            if (invalid) ...[
              const SizedBox(height: 6),
              Text(
                duration <= 0
                    ? l10n.endTimeMustBeLater
                    : l10n.periodOverlapPrevious,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.error),
              ),
            ],
          ],
        ),
      ),
    );
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
    setState(() {
      _periodTimes = buildPeriodTimesForCount(
        _periodTimes.length + 1,
        source: _periodTimes,
      );
    });
    _scheduleAutoSave();
  }

  void _removePeriod(int index) {
    if (_interactionBlocked ||
        index < 0 ||
        index >= _periodTimes.length ||
        _periodTimes.length <= 1) {
      return;
    }
    setState(() {
      final next = [..._periodTimes]..removeAt(index);
      _periodTimes = List.generate(
        next.length,
        (itemIndex) => next[itemIndex].copyWith(index: itemIndex + 1),
      );
    });
    _scheduleAutoSave();
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
      if (period.endMinutes <= period.startMinutes) {
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
    if (!mounted || _isDisposing) {
      return;
    }
    _allowPop = false;
    final revision = ++_autoSaveRevision;
    if (_hasInvalidPeriodTimes) {
      _pendingAutoSaveProvider = null;
      _pendingAutoSaveValue = null;
      _pendingAutoSaveRevision = null;
      _failedAutoSaveRevision = null;
      _autoSaveDebounce?.cancel();
      _autoSaveDebounce = null;
      setState(() {});
      return;
    }
    _pendingAutoSaveProvider = context.read<TimetableProvider>();
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
    if (_pendingAutoSaveProvider == null ||
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
        final provider = _pendingAutoSaveProvider;
        final value = _pendingAutoSaveValue;
        final revision = _pendingAutoSaveRevision;
        if (provider == null || value == null || revision == null) {
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

        _pendingAutoSaveProvider = null;
        _pendingAutoSaveValue = null;
        _pendingAutoSaveRevision = null;
        _autoSaveDebounce?.cancel();
        _autoSaveDebounce = null;
        try {
          await provider.updatePeriodTimeSet(value);
          _persistedAutoSaveRevision = math.max(
            _persistedAutoSaveRevision,
            revision,
          );
        } catch (error, stackTrace) {
          debugPrint('Period time auto-save failed: $error\n$stackTrace');
          if (_pendingAutoSaveValue == null && revision == _autoSaveRevision) {
            _pendingAutoSaveProvider = provider;
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
    if (_isHandlingPop || _menuActionInProgress) {
      return;
    }
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isHandlingPop = true);
    FocusScope.of(context).unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    while (mounted) {
      final saved = await _flushPendingAutoSave();
      if (!mounted) {
        return;
      }
      if (saved && _allowPop) {
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && navigator.mounted && route?.isCurrent == true) {
          navigator.pop();
        } else if (mounted) {
          setState(() => _isHandlingPop = false);
        }
        return;
      }

      final canRetry = _pendingAutoSaveRevision != null;
      final action = await _showUnsavedExitDialog(canRetry: canRetry);
      if (!mounted) {
        return;
      }
      switch (action) {
        case _UnsavedPeriodTimesExitAction.retry:
          continue;
        case _UnsavedPeriodTimesExitAction.discard:
          _discardPendingAutoSave();
          setState(() => _allowPop = true);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted && navigator.mounted && route?.isCurrent == true) {
            navigator.pop();
          } else if (mounted) {
            setState(() => _isHandlingPop = false);
          }
          return;
        case _UnsavedPeriodTimesExitAction.keepEditing:
        case null:
          setState(() => _isHandlingPop = false);
          return;
      }
    }
  }

  void _discardPendingAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = null;
    _pendingAutoSaveProvider = null;
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
        return AlertDialog(
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
    final provider = context.read<TimetableProvider>();
    final navigator = Navigator.of(context);
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

        return AlertDialog(
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
      await provider.deletePeriodTimeSet(widget.periodTimeSetId);
      if (mounted) {
        navigator.pop(true);
      }
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _importTemplate() async {
    final provider = context.read<TimetableProvider>();
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
      final imported = provider.importPeriodTimesJson(source);
      final count = imported.length;
      if (count == 0) {
        throw FormatException(
          noPeriodTimesInImportMessage(localeCode: provider.localeCode),
        );
      }
      setState(() {
        _periodTimes = imported;
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextImportPage(
          title: l10n.importPeriodTemplateText,
          onSubmit: (_, content) async {
            if (!mounted) {
              return false;
            }
            final provider = context.read<TimetableProvider>();
            try {
              final imported = provider.importPeriodTimesJson(content);
              final count = imported.length;
              if (count == 0) {
                throw FormatException(
                  noPeriodTimesInImportMessage(localeCode: provider.localeCode),
                );
              }
              if (!mounted) {
                return false;
              }
              setState(() {
                _periodTimes = imported;
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

  Future<void> _saveTemplateToFile() async {
    final l10n = AppLocalizations.of(context);
    final result = await _exportService.saveFile(
      ExportPayload(
        fileName: 'Sked_period_times.json',
        content: encodePeriodTimesEnvelope(_periodTimes),
      ),
    );
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case ExportSaveStatus.saved:
        _showMessage(l10n.savedToPath(result.path ?? 'Sked_period_times.json'));
        return;
      case ExportSaveStatus.cancelled:
        _showMessage(l10n.saveCancelled);
        return;
      case ExportSaveStatus.permissionDenied:
        final retry = await _showPermissionDialog(
          title: l10n.periodFilePermissionTitle,
          message: l10n.androidFilePermissionMessage,
          confirmText: l10n.reauthorize,
        );
        if (retry == true && mounted) {
          await _saveTemplateToFile();
        }
        return;
      case ExportSaveStatus.permissionPermanentlyDenied:
        final openSettings = await _showPermissionDialog(
          title: l10n.permissionPermanentlyDeniedTitle,
          message: l10n.permissionSettingsExportMessage,
          confirmText: l10n.openSettings,
        );
        if (openSettings == true) {
          await _exportService.openSettings();
        }
        return;
      case ExportSaveStatus.unsupported:
        final shouldShare = await _showFailureDialog(
          title: l10n.browserDownloadRestrictedTitle,
          message: l10n.browserDownloadRestrictedMessage,
        );
        if (shouldShare == true) {
          await _shareTemplate();
          _showMessage(l10n.exportSwitchedToShare);
        }
        return;
      case ExportSaveStatus.failed:
        final shouldShare = await _showFailureDialog(
          title: _exportService.usesDesktopFileSaveErrors
              ? l10n.fileSaveFailedTitle
              : l10n.fileSaveRestrictedTitle,
          message: _exportService.usesDesktopFileSaveErrors
              ? l10n.fileSaveFailedWindowsMessage
              : l10n.fileSaveFailedGenericMessage,
        );
        if (shouldShare == true) {
          await _shareTemplate();
          _showMessage(l10n.exportSwitchedToShare);
        } else {
          _showMessage(l10n.saveFailedRetry);
        }
        return;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool?> _showPermissionDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showFailureDialog({
    required String title,
    required String message,
  }) {
    return showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(AppLocalizations.of(context).retryLater),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(AppLocalizations.of(context).switchToShare),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickPeriodTime(int index, {required bool isStart}) async {
    if (_timePickerOpen || index < 0 || index >= _periodTimes.length) {
      return;
    }
    setState(() => _timePickerOpen = true);
    final period = _periodTimes[index];
    final initialMinutes = normalizeMinuteOfDay(
      isStart ? period.startMinutes : period.endMinutes,
    );
    try {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: initialMinutes ~/ 60,
          minute: initialMinutes % 60,
        ),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (!mounted ||
          picked == null ||
          index < 0 ||
          index >= _periodTimes.length) {
        return;
      }
      final minutes = (picked.hour * 60) + picked.minute;
      setState(() {
        final currentPeriod = _periodTimes[index];
        _periodTimes[index] = isStart
            ? currentPeriod.copyWith(startMinutes: minutes)
            : currentPeriod.copyWith(endMinutes: minutes);
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

class _PeriodTimeRange extends StatelessWidget {
  const _PeriodTimeRange({
    required this.startLabel,
    required this.startValue,
    required this.endLabel,
    required this.endValue,
    required this.error,
    required this.enabled,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String startLabel;
  final String startValue;
  final String endLabel;
  final String endValue;
  final bool error;
  final bool enabled;
  final VoidCallback? onPickStart;
  final VoidCallback? onPickEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shapeScheme = theme.extension<SkedShapeScheme>();
    final shape =
        (shapeScheme?.control ??
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))
            .copyWith(
              side: BorderSide(
                color: error ? colors.error : colors.outlineVariant,
                width: error ? 1.2 : 0.8,
              ),
            );
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final textScaler = MediaQuery.textScalerOf(context);
          final textDirection = Directionality.of(context);
          final labelStyle = theme.textTheme.labelMedium;
          final valueStyle = theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          );
          final startWidth = math.max(
            96.0,
            _measurePeriodTimeActionWidth(
              label: startLabel,
              value: startValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
              textScaler: textScaler,
              textDirection: textDirection,
            ),
          );
          final endWidth = math.max(
            96.0,
            _measurePeriodTimeActionWidth(
              label: endLabel,
              value: endValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
              textScaler: textScaler,
              textDirection: textDirection,
            ),
          );
          final stacksVertically =
              textScale > 1.3 ||
              constraints.maxWidth < startWidth + endWidth + 40;
          final start = _PeriodTimeAction(
            key: const ValueKey('period-start-time-action'),
            label: startLabel,
            value: startValue,
            enabled: enabled,
            onTap: onPickStart,
          );
          final end = _PeriodTimeAction(
            key: const ValueKey('period-end-time-action'),
            label: endLabel,
            value: endValue,
            enabled: enabled,
            onTap: onPickEnd,
          );
          if (stacksVertically) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: double.infinity, child: start),
                Divider(height: 1, thickness: 1, color: colors.outlineVariant),
                SizedBox(width: double.infinity, child: end),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: start),
                SizedBox(
                  key: const ValueKey('period-time-range-arrow'),
                  width: 40,
                  child: Center(
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: enabled
                            ? colors.onSurfaceVariant
                            : colors.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ),
                Expanded(child: end),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodTimeAction extends StatelessWidget {
  const _PeriodTimeAction({
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
    return Semantics(
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      label: label,
      value: value,
      onTap: enabled ? onTap : null,
      child: InkWell(
        customBorder:
            theme.extension<SkedShapeScheme>()?.compact ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        excludeFromSemantics: true,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: enabled
                          ? colors.onSurfaceVariant
                          : colors.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: enabled
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.38),
                      fontWeight: FontWeight.w700,
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      excludeSemantics: true,
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28, maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foregroundColor ?? colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

double _measurePeriodTimeActionWidth({
  required String label,
  required String value,
  required TextStyle? labelStyle,
  required TextStyle? valueStyle,
  required TextScaler textScaler,
  required TextDirection textDirection,
}) {
  double measure(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  return math.max(measure(label, labelStyle), measure(value, valueStyle)) + 20;
}
