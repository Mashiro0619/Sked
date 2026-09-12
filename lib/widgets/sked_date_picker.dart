import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/app_mode.dart';
import '../models/general_date_range.dart';
import 'sked_date_range_controller.dart';
import '../models/general_schedule_data.dart'
    show generalDateLabelFormatLocalized;
import '../utils/date_selection.dart';
import '../utils/calendar_date_utils.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_picker_task.dart';

export '../utils/date_selection.dart' show DateSelectionUnit;
export 'sked_date_range_controller.dart';

enum DatePickerCommitMode { immediate, confirm }

/// Range presentation is independent of ordinary date activation.
enum DateRangeInteraction { none, dragOnly, full }

enum _CalendarPage { days, months, years, input }

class _DatePickerDismissIntent extends Intent {
  const _DatePickerDismissIntent();
}

Future<DateTime?> showSkedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateSelectionUnit selectionUnit = DateSelectionUnit.day,
  DatePickerCommitMode commitMode = DatePickerCommitMode.confirm,
  SelectableDayPredicate? selectableDayPredicate,
  String dateLabelFormat = generalDateLabelFormatLocalized,
  BuildContext? anchorContext,
  AppMode? workspace,
}) => _showDateTask<DateTime>(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  selectionUnit: selectionUnit,
  commitMode: commitMode,
  selectableDayPredicate: selectableDayPredicate,
  dateLabelFormat: dateLabelFormat,
  anchorContext: anchorContext,
  workspace: workspace,
);

Future<DateTimeRange?> showSkedDateRangePicker({
  required BuildContext context,
  required GeneralDateRange initialRange,
  SkedDateRangeController? controller,
  Future<void> Function(GeneralDateRange)? onApply,
  String dateLabelFormat = generalDateLabelFormatLocalized,
  BuildContext? anchorContext,
  AppMode? workspace,
}) async {
  final session =
      controller ??
      SkedDateRangeController(
        initialRange: initialRange,
        onApply: onApply ?? (_) async {},
      );
  try {
    final result = await _showDateTask<DateTimeRange>(
      context: context,
      initialDate: session.start ?? initialRange.start,
      firstDate: GeneralDateRange.firstDate,
      lastDate: GeneralDateRange.lastDate,
      selectionUnit: DateSelectionUnit.week,
      commitMode: DatePickerCommitMode.immediate,
      dateLabelFormat: dateLabelFormat,
      anchorContext: anchorContext,
      workspace: workspace,
      rangeController: session,
    );
    if (result == null) session.cancel();
    return result;
  } finally {
    if (controller == null) session.dispose();
  }
}

/// One route/session; only positioning changes when the window or IME does.
Future<T?> _showDateTask<T>({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateSelectionUnit selectionUnit,
  required DatePickerCommitMode commitMode,
  SelectableDayPredicate? selectableDayPredicate,
  required String dateLabelFormat,
  BuildContext? anchorContext,
  AppMode? workspace,
  SkedDateRangeController? rangeController,
}) async {
  final first = normalizeDateOnly(firstDate),
      last = normalizeDateOnly(lastDate);
  if (last.isBefore(first)) throw ArgumentError('Invalid date picker bounds.');
  return showSkedPickerTask<T>(
    context: context,
    routeName: 'sked-date-picker',
    surfaceKey: const ValueKey('sked-date-picker-surface'),
    anchorContext: anchorContext,
    workspace: workspace,
    preferredSize: (context) {
      final metrics = WorkbenchChromeMetrics.of(context);
      final cell = math.max(
        metrics.desktop ? 32.0 : 48.0,
        18 * metrics.textScale + 12,
      );
      return Size(
        math.max(metrics.desktop ? 320.0 : 360.0, cell * 7 + 24),
        cell * 8 + 80,
      );
    },
    builder: (context, finish, isCurrent) => SkedDatePicker(
      key: const ValueKey('sked-date-picker-content'),
      initialDate: clampPickerDate(initialDate, first, last),
      firstDate: first,
      lastDate: last,
      isSessionCurrent: isCurrent,
      selectionUnit: selectionUnit,
      dateLabelFormat: dateLabelFormat,
      commitMode: commitMode,
      selectableDayPredicate: selectableDayPredicate,
      onSelected: (date) => finish(date as T),
      rangeController: rangeController,
      rangeInteraction: rangeController == null
          ? DateRangeInteraction.none
          : DateRangeInteraction.full,
      onRangeSelected: (range) =>
          finish(DateTimeRange(start: range.start, end: range.end) as T),
      onCancel: () => finish(null),
    ),
  );
}

/// Shared calendar content for the inline navigator and every popup.
/// Browsing/focus is transient; only [onSelected] can change application state.
class SkedDatePicker extends StatefulWidget {
  const SkedDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    this.onCancel,
    this.selectionUnit = DateSelectionUnit.day,
    this.commitMode = DatePickerCommitMode.confirm,
    this.selectableDayPredicate,
    this.embedded = false,
    this.browsedMonth,
    this.onBrowsedMonthChanged,
    this.navigationRevision = 0,
    this.rangeController,
    this.rangeInteraction = DateRangeInteraction.none,
    this.displayRange,
    this.onRangeSelected,
    this.isSessionCurrent,
    this.currentDate,
    this.dateLabelFormat = generalDateLabelFormatLocalized,
  }) : assert(
         rangeInteraction == DateRangeInteraction.none ||
             rangeController != null,
       );
  final DateTime initialDate, firstDate, lastDate;
  final SkedDateRangeController? rangeController;
  final DateRangeInteraction rangeInteraction;
  final GeneralDateRange? displayRange;
  final ValueChanged<GeneralDateRange>? onRangeSelected;
  final bool Function()? isSessionCurrent;
  final DateTime? currentDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback? onCancel;
  final DateSelectionUnit selectionUnit;
  final String dateLabelFormat;
  final DatePickerCommitMode commitMode;
  final SelectableDayPredicate? selectableDayPredicate;
  final bool embedded;
  final DateTime? browsedMonth;
  final ValueChanged<DateTime>? onBrowsedMonthChanged;
  final int navigationRevision;
  @override
  State<SkedDatePicker> createState() => _SkedDatePickerState();
}

class _SkedDatePickerState extends State<SkedDatePicker> {
  late DateTime _selected, _focused, _month;
  late _CalendarPage _page;
  final _gridFocus = FocusNode(debugLabel: 'Date calendar grid');
  final _inputFocus = FocusNode(debugLabel: 'Date input');
  final _endInputFocus = FocusNode(debugLabel: 'Range end input');
  final _input = TextEditingController();
  final _endInput = TextEditingController();
  bool get _rangeMode => widget.rangeInteraction == DateRangeInteraction.full;
  bool get _rangeGestures =>
      widget.rangeInteraction != DateRangeInteraction.none &&
      widget.rangeController != null;
  final _dayGridKey = GlobalKey();
  double _gridCellHeight = 0;
  DateTime? _dragOrigin;
  Rect? _dragBounds;
  bool _ownsDrag = false;
  bool _suppressClick = false;
  bool get _savingRange => widget.rangeController?.saving ?? false;
  void _rangeChanged() {
    if (mounted) setState(() {});
  }

  String? _inputError;
  bool _hasFocus = false;
  bool _submitted = false;
  bool get _confirmed =>
      !_rangeMode && widget.commitMode == DatePickerCommitMode.confirm;
  DateTime get _today =>
      normalizeDateOnly(widget.currentDate ?? DateTime.now());
  DateTime _monthOf(DateTime value) => addCalendarDays(value, 1 - value.day);
  bool _allowed(DateTime value) =>
      !value.isBefore(widget.firstDate) &&
      !value.isAfter(widget.lastDate) &&
      (widget.selectableDayPredicate?.call(value) ?? true);
  DateTime? _resolve(DateTime value, DateSelectionUnit unit) =>
      selectableDateInUnit(
        preferred: value,
        unit: unit,
        firstDate: widget.firstDate,
        lastDate: widget.lastDate,
        selectableDayPredicate: widget.selectableDayPredicate,
      );
  @override
  void initState() {
    super.initState();
    _reset();
    widget.rangeController?.addListener(_rangeChanged);
  }

  void _reset() {
    _selected =
        _resolve(widget.initialDate, widget.selectionUnit) ??
        clampPickerDate(widget.initialDate, widget.firstDate, widget.lastDate);
    _focused = _selected;
    _month = _monthOf(widget.browsedMonth ?? _selected);
    _page = widget.selectionUnit == DateSelectionUnit.month && !widget.embedded
        ? _CalendarPage.months
        : _CalendarPage.days;
  }

  @override
  void didUpdateWidget(SkedDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rangeController != widget.rangeController) {
      oldWidget.rangeController?.removeListener(_rangeChanged);
      widget.rangeController?.addListener(_rangeChanged);
    }
    if (!DateUtils.isSameDay(widget.initialDate, oldWidget.initialDate) ||
        widget.navigationRevision != oldWidget.navigationRevision) {
      _reset();
    }
  }

  @override
  void dispose() {
    _gridFocus.dispose();
    _inputFocus.dispose();
    _endInputFocus.dispose();
    widget.rangeController?.removeListener(_rangeChanged);
    _input.dispose();
    _endInput.dispose();
    super.dispose();
  }

  void _browse(DateTime month) {
    _month = _monthOf(month);
    widget.onBrowsedMonthChanged?.call(_month);
  }

  void _choose(DateTime value, {bool strict = false}) {
    if (_submitted ||
        _suppressClick ||
        _savingRange ||
        widget.isSessionCurrent?.call() == false) {
      return;
    }
    if (_rangeMode) {
      unawaited(_chooseRange(value));
      return;
    }
    final resolved = strict
        ? (_allowed(value) ? value : null)
        : _resolve(value, widget.selectionUnit);
    if (resolved == null) return;
    setState(() {
      _selected = resolved;
      _focused = resolved;
      _inputError = null;
      _browse(resolved);
    });
    if (!_confirmed) _submit();
  }

  Future<void> _chooseRange(DateTime value) async {
    if (!_allowed(value)) return;
    final session = widget.rangeController!;
    setState(() {
      _focused = value;
    });
    if (await session.select(value) && mounted) {
      widget.onRangeSelected?.call(session.applied);
    }
  }

  Future<void> _retryRange() async {
    final session = widget.rangeController!;
    if (await session.retry() && mounted) {
      widget.onRangeSelected?.call(session.applied);
    }
  }

  Rect? get _gridRect {
    final box = _dayGridKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  DateTime? _dateAt(Offset global) {
    final rect = _gridRect;
    if (rect == null || !rect.contains(global) || _gridCellHeight <= 0) {
      return null;
    }
    final hits = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      hits,
      global,
      View.of(context).viewId,
    );
    final box = _dayGridKey.currentContext?.findRenderObject();
    if (!hits.path.any((entry) => identical(entry.target, box))) return null;
    final local = global - rect.topLeft;
    final row = (local.dy / _gridCellHeight).floor() - 1;
    if (row < 0 || row >= 6) return null;
    var col = (local.dx / rect.width * 7).floor().clamp(0, 6);
    if (Directionality.of(context) == TextDirection.rtl) col = 6 - col;
    final day = addCalendarDays(
      startOfCalendarWeek(_month, firstWeekday: DateTime.monday),
      row * 7 + col,
    );
    return day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate)
        ? null
        : day;
  }

  void _startDrag(DragStartDetails details) {
    if (_dragOrigin == null ||
        _savingRange ||
        widget.isSessionCurrent?.call() == false) {
      return;
    }
    widget.rangeController!.beginDrag(_dragOrigin!);
    _ownsDrag = widget.rangeController!.dragging;
    _suppressClick = _ownsDrag;
  }

  void _updateDrag(DragUpdateDetails details) {
    if (!_ownsDrag) return;
    if (_gridRect != _dragBounds) {
      _cancelDrag();
      return;
    }
    widget.rangeController!.preview(_dateAt(details.globalPosition));
  }

  void _releaseClickSuppression() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressClick = false;
    });
  }

  void _cancelDrag() {
    if (_ownsDrag) widget.rangeController?.cancelDrag();
    _ownsDrag = false;
    _dragOrigin = null;
    _releaseClickSuppression();
  }

  Future<void> _endDrag() async {
    if (!_ownsDrag) return;
    _ownsDrag = false;
    _dragOrigin = null;
    _releaseClickSuppression();
    final session = widget.rangeController!;
    if (await session.endDrag() && mounted) {
      widget.onRangeSelected?.call(session.applied);
    }
  }

  Widget _interactiveDayGrid(BuildContext context, double height) {
    _gridCellHeight = height;
    final grid = SizedBox(key: _dayGridKey, child: _dayGrid(context, height));
    if (!_rangeGestures) return grid;
    return MouseRegion(
      onHover: (event) {
        if (_rangeMode && !widget.rangeController!.dragging) {
          widget.rangeController!.preview(_dateAt(event.position));
        }
      },
      onExit: (_) {
        if (!widget.rangeController!.dragging) {
          widget.rangeController!.preview(null);
        }
      },
      child: Listener(
        // An accepted pan may end even for PointerCancelEvent. Cancel the
        // transaction before the recognizer's end callback can publish it.
        onPointerCancel: (_) => _cancelDrag(),
        onPointerUp: (event) {
          if (_ownsDrag) {
            widget.rangeController!.preview(_dateAt(event.position));
          }
        },
        child: GestureDetector(
          supportedDevices: const {PointerDeviceKind.mouse},
          dragStartBehavior: DragStartBehavior.down,
          onPanDown: (details) {
            _dragOrigin = _dateAt(details.globalPosition);
            _dragBounds = _gridRect;
          },
          onPanStart: _startDrag,
          onPanUpdate: _updateDrag,
          onPanEnd: (_) => unawaited(_endDrag()),
          onPanCancel: _cancelDrag,
          child: grid,
        ),
      ),
    );
  }

  void _submit() {
    if (_submitted ||
        !_allowed(_selected) ||
        widget.isSessionCurrent?.call() == false) {
      return;
    }
    if (!widget.embedded) _submitted = true;
    widget.onSelected(_selected);
  }

  void _showInput() {
    setState(() {
      final material = MaterialLocalizations.of(context);
      final range = widget.rangeController;
      _input.text = material.formatCompactDate(
        range?.start ?? range?.editingRange.start ?? _selected,
      );
      final pendingEnd =
          range != null &&
          range.start != null &&
          range.candidate == null &&
          range.editingEndpoint == null;
      _endInput.text = pendingEnd
          ? ''
          : material.formatCompactDate(range?.editingRange.end ?? _selected);
      _inputError = null;
      _page = _CalendarPage.input;
    });
    (_rangeMode && widget.rangeController!.selectingEnd
            ? _endInputFocus
            : _inputFocus)
        .requestFocus();
  }

  void _acceptInput() {
    if (_savingRange ||
        _submitted ||
        widget.isSessionCurrent?.call() == false) {
      return;
    }
    final material = MaterialLocalizations.of(context);
    final parsed = material.parseCompactDate(_input.text.trim());
    if (_rangeMode) {
      final end = material.parseCompactDate(_endInput.text.trim());
      if (parsed == null || end == null) {
        setState(() => _inputError = material.invalidDateFormatLabel);
      } else if (end.isBefore(parsed)) {
        setState(() => _inputError = material.invalidDateRangeLabel);
      } else if (!_allowed(parsed) || !_allowed(end)) {
        setState(() => _inputError = material.dateOutOfRangeLabel);
      } else {
        try {
          final value = GeneralDateRange(parsed, end);
          unawaited(
            widget.rangeController!.apply(value).then((saved) {
              if (saved && mounted) widget.onRangeSelected?.call(value);
            }),
          );
        } on FormatException {
          setState(
            () => _inputError = AppLocalizations.of(context).dateRangeLimit,
          );
        }
      }
      return;
    }
    if (parsed == null || !_allowed(parsed)) {
      setState(
        () => _inputError = parsed == null
            ? material.invalidDateFormatLabel
            : material.dateOutOfRangeLabel,
      );
      return;
    }
    _choose(parsed, strict: true);
    if (_confirmed) _submit();
  }

  void _selectMonth(int month) {
    final preferred = shiftDateMonth(
      _selected,
      (_month.year - _selected.year) * 12 + month - _selected.month,
    );
    final resolved = _resolve(preferred, DateSelectionUnit.month);
    if (resolved == null) return;
    if (widget.selectionUnit == DateSelectionUnit.month && !widget.embedded) {
      _choose(resolved);
    } else {
      setState(() {
        _browse(resolved);
        _focused = resolved;
        _page = _CalendarPage.days;
      });
      _gridFocus.requestFocus();
    }
  }

  int get _yearPageStart => (_month.year ~/ 12) * 12;
  void _step(int delta) {
    if (_savingRange) return;
    setState(() {
      if (_page == _CalendarPage.days) {
        final next = shiftDateMonth(_month, delta);
        _focused = clampPickerDate(
          shiftDateMonth(_focused, delta),
          widget.firstDate,
          widget.lastDate,
        );
        _browse(next);
      } else {
        final next = shiftDateMonth(
          _month,
          delta * (_page == _CalendarPage.years ? 144 : 12),
        );
        _browse(clampPickerDate(next, widget.firstDate, widget.lastDate));
        _focused = clampPickerDate(
          shiftDateMonth(
            _focused,
            delta * (_page == _CalendarPage.years ? 144 : 12),
          ),
          widget.firstDate,
          widget.lastDate,
        );
      }
    });
  }

  bool _canStep(int delta) {
    if (_page == _CalendarPage.years) {
      return delta < 0
          ? _yearPageStart > widget.firstDate.year
          : _yearPageStart + 11 < widget.lastDate.year;
    }
    final next = shiftDateMonth(
      _month,
      delta * (_page == _CalendarPage.months ? 12 : 1),
    );
    return _page == _CalendarPage.months
        ? next.year >= widget.firstDate.year &&
              next.year <= widget.lastDate.year
        : !next.isBefore(_monthOf(widget.firstDate)) &&
              !next.isAfter(_monthOf(widget.lastDate));
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (_savingRange || widget.isSessionCurrent?.call() == false) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (_page == _CalendarPage.days) {
        _choose(_focused);
      } else if (_page == _CalendarPage.months) {
        _selectMonth(_focused.month);
      } else if (_page == _CalendarPage.years) {
        _selectYear(_focused.year);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.pageUp) {
      final delta = key == LogicalKeyboardKey.pageDown ? 1 : -1;
      if (_canStep(delta)) _step(delta);
      return KeyEventResult.handled;
    }
    var step = key == LogicalKeyboardKey.arrowLeft
        ? -1
        : key == LogicalKeyboardKey.arrowRight
        ? 1
        : 0;
    final columns = _page == _CalendarPage.days ? 7 : 3;
    if (key == LogicalKeyboardKey.arrowUp) step = -columns;
    if (key == LogicalKeyboardKey.arrowDown) step = columns;
    if (step == 0) return KeyEventResult.ignored;
    final next = _page == _CalendarPage.days
        ? addCalendarDays(_focused, step)
        : shiftDateMonth(
            _focused,
            step * (_page == _CalendarPage.years ? 12 : 1),
          );
    setState(() {
      _focused = clampPickerDate(next, widget.firstDate, widget.lastDate);
      _browse(_focused);
    });
    if (_rangeMode && _page == _CalendarPage.days) {
      widget.rangeController!.preview(_focused);
    }
    return KeyEventResult.handled;
  }

  void _selectYear(int year) {
    if (year < widget.firstDate.year || year > widget.lastDate.year) return;
    setState(() {
      final next = shiftDateMonth(_focused, (year - _focused.year) * 12);
      _focused = clampPickerDate(next, widget.firstDate, widget.lastDate);
      _browse(_focused);
      _page = _CalendarPage.months;
    });
    _gridFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final theme = Theme.of(context),
        metrics = WorkbenchChromeMetrics.of(context);
    final title = _rangeMode
        ? l.dateRangeTitle
        : switch (widget.selectionUnit) {
            DateSelectionUnit.day => l.pickDate,
            DateSelectionUnit.week => l.datePickerSelectWeek,
            DateSelectionUnit.month => l.datePickerSelectMonth,
          };
    final cellHeight = math.max(
      widget.embedded
          ? 28.0
          : metrics.desktop
          ? 32.0
          : 48.0,
      18 * metrics.textScale + (widget.embedded ? 4 : 12),
    );
    return PopScope(
      canPop: !_savingRange,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape):
              _DatePickerDismissIntent(),
        },
        child: Actions(
          actions: {
            _DatePickerDismissIntent: CallbackAction<_DatePickerDismissIntent>(
              onInvoke: (_) {
                if (_savingRange) return null;
                widget.rangeController?.cancel();
                if (widget.onCancel != null) {
                  widget.onCancel!();
                } else {
                  setState(() => _page = _CalendarPage.days);
                }
                return null;
              },
            ),
          },
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              key: const ValueKey('sked-date-picker-outer-scroll'),
              primary: false,
              child: ConstrainedBox(
                // In a short landscape window the IME must not squeeze the input
                // between fixed chrome. Keep a useful content budget and let the
                // whole task scroll, without reparenting the editor on resize.
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight.isFinite
                      ? math.max(
                          constraints.maxHeight,
                          metrics.iconTarget * 3 + 120 * metrics.textScale,
                        )
                      : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.embedded ? 0 : 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!widget.embedded)
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                hint: _rangeMode
                                    ? (widget.rangeController!.selectingEnd
                                          ? l.dateRangeChooseEnd
                                          : l.dateRangeChooseStart)
                                    : null,
                                child: _headerLabel(
                                  context,
                                  title,
                                  feedback: true,
                                ),
                              ),
                            ),
                            if (_rangeGestures &&
                                widget.rangeController!.saveFailed)
                              IconButton(
                                key: const ValueKey('sked-date-range-retry'),
                                tooltip: l.retrySave,
                                style: metrics.iconStyle,
                                onPressed: () => unawaited(_retryRange()),
                                icon: const Icon(Icons.refresh),
                              ),
                            IconButton(
                              key: const ValueKey('sked-date-picker-close'),
                              tooltip: material.closeButtonLabel,
                              style: metrics.iconStyle,
                              onPressed: _savingRange ? null : widget.onCancel,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      if (_page != _CalendarPage.input) _header(context),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          key: const ValueKey('sked-date-picker-scroll'),
                          child: _page == _CalendarPage.input
                              ? _dateInputs(context)
                              : Focus(
                                  key: const ValueKey('sked-date-grid-focus'),
                                  focusNode: _gridFocus,
                                  autofocus: !widget.embedded,
                                  onKeyEvent: _onGridKey,
                                  onFocusChange: (value) {
                                    if (mounted) {
                                      setState(() => _hasFocus = value);
                                    }
                                  },
                                  child: switch (_page) {
                                    _CalendarPage.days => _interactiveDayGrid(
                                      context,
                                      cellHeight,
                                    ),
                                    _CalendarPage.months => _monthGrid(
                                      context,
                                      cellHeight,
                                    ),
                                    _CalendarPage.years => _yearGrid(
                                      context,
                                      cellHeight,
                                    ),
                                    _CalendarPage.input =>
                                      const SizedBox.shrink(),
                                  },
                                ),
                        ),
                      ),
                      if (!widget.embedded) ...[
                        const SizedBox(height: 8),
                        if (!_rangeMode)
                          Text(
                            formatDateSelection(
                              _selected,
                              widget.selectionUnit,
                              locale: l.localeName,
                              format: widget.dateLabelFormat,
                            ),
                            key: const ValueKey('sked-date-selection-label'),
                            style: theme.textTheme.bodySmall,
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            IconButton(
                              key: const ValueKey('sked-date-input-toggle'),
                              style: metrics.iconStyle,
                              tooltip: _page == _CalendarPage.input
                                  ? material.calendarModeButtonLabel
                                  : material.inputDateModeButtonLabel,
                              onPressed: _savingRange
                                  ? null
                                  : () {
                                      if (_page == _CalendarPage.input) {
                                        setState(
                                          () => _page = _CalendarPage.days,
                                        );
                                        _gridFocus.requestFocus();
                                      } else {
                                        _showInput();
                                      }
                                    },
                              icon: Icon(
                                _page == _CalendarPage.input
                                    ? Icons.calendar_month_outlined
                                    : Icons.edit_calendar_outlined,
                              ),
                            ),
                            if (!_rangeMode || _page != _CalendarPage.input)
                              TextButton(
                                key: const ValueKey('sked-date-today'),
                                onPressed:
                                    _savingRange ||
                                        _resolve(
                                              _today,
                                              widget.selectionUnit,
                                            ) ==
                                            null
                                    ? null
                                    : () => _choose(_today),
                                child: Text(l.today),
                              ),
                            if (_confirmed)
                              TextButton(
                                key: const ValueKey('sked-date-cancel'),
                                onPressed: widget.onCancel,
                                child: Text(material.cancelButtonLabel),
                              ),
                            if (_confirmed || _page == _CalendarPage.input)
                              FilledButton(
                                key: const ValueKey('sked-date-confirm'),
                                onPressed: _savingRange
                                    ? null
                                    : _page == _CalendarPage.input
                                    ? _acceptInput
                                    : _allowed(_selected)
                                    ? _submit
                                    : null,
                                child: Text(material.okButtonLabel),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateInputs(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    Widget field(bool end) => TextField(
      key: ValueKey(end ? 'sked-date-end-input' : 'sked-date-input'),
      controller: end ? _endInput : _input,
      focusNode: end ? _endInputFocus : _inputFocus,
      enabled: !_savingRange,
      keyboardType: TextInputType.datetime,
      textInputAction: _rangeMode && !end
          ? TextInputAction.next
          : TextInputAction.done,
      decoration: InputDecoration(
        labelText: !_rangeMode
            ? material.dateInputLabel
            : end
            ? material.dateRangeEndLabel
            : material.dateRangeStartLabel,
        hintText: material.dateHelpText,
        errorText: _inputError,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        if (_inputError != null) setState(() => _inputError = null);
        final session = widget.rangeController;
        // Edited fields describe a new intent, not the failed snapshot. Do not
        // leave a Retry action that would silently re-apply the old endpoints.
        if (session != null && (session.saveFailed || session.tooLong)) {
          session.cancel();
        }
      },
      onSubmitted: (_) {
        if (end || !_rangeMode) {
          _acceptInput();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field(false),
          if (_rangeMode) ...[const SizedBox(height: 12), field(true)],
        ],
      ),
    );
  }

  /// Normal selection is conveyed by the calendar highlight, not a second
  /// control panel. Errors and saves use the existing header without moving
  /// cells underneath the pointer.
  String? _rangeFeedback(BuildContext context) {
    if (!_rangeGestures) return null;
    final session = widget.rangeController!;
    final l = AppLocalizations.of(context);
    if (session.saving) return l.savingChanges;
    if (session.saveFailed) return l.saveFailedRetry;
    if (session.tooLong) return l.dateRangeLimit;
    if (session.invalidOrder) {
      return MaterialLocalizations.of(context).invalidDateRangeLabel;
    }
    return null;
  }

  Widget _headerLabel(
    BuildContext context,
    String label, {
    bool feedback = false,
  }) {
    final message = feedback ? _rangeFeedback(context) : null;
    final failed = message != null && !_savingRange;
    return Semantics(
      liveRegion: message != null,
      child: Tooltip(
        message: message ?? label,
        excludeFromSemantics: true,
        child: Text(
          message ?? label,
          key: failed ? const ValueKey('sked-date-range-error') : null,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: failed ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l = AppLocalizations.of(context),
        material = MaterialLocalizations.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final feedback = widget.embedded ? _rangeFeedback(context) : null;
    final retry =
        feedback != null && widget.rangeController?.saveFailed == true;
    final label = _page == _CalendarPage.days
        ? DateFormat.yMMMM(l.localeName).format(_month)
        : _page == _CalendarPage.months
        ? DateFormat.y(l.localeName).format(_month)
        : '$_yearPageStart–${_yearPageStart + 11}';
    return Row(
      children: [
        Expanded(
          child: TextButton(
            key: ValueKey(
              retry ? 'sked-date-range-retry' : 'sked-date-month-year',
            ),
            style: TextButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size(0, metrics.iconTarget),
              tapTargetSize: metrics.desktop
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
            onPressed: _savingRange
                ? null
                : retry
                ? () => unawaited(_retryRange())
                : () {
                    setState(
                      () => _page = _page == _CalendarPage.days
                          ? _CalendarPage.months
                          : _page == _CalendarPage.months
                          ? _CalendarPage.years
                          : _CalendarPage.days,
                    );
                  },
            child: Tooltip(
              message: retry
                  ? l.retrySave
                  : feedback ??
                        (_page == _CalendarPage.days
                            ? l.datePickerSelectMonth
                            : _page == _CalendarPage.months
                            ? material.selectYearSemanticsLabel
                            : material.calendarModeButtonLabel),
              child: Row(
                children: [
                  Expanded(
                    child: _headerLabel(
                      context,
                      label,
                      feedback: widget.embedded,
                    ),
                  ),
                  Icon(retry ? Icons.refresh : Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: ValueKey(
            widget.embedded
                ? 'general-resource-previous-month'
                : 'sked-date-previous',
          ),
          tooltip: _page == _CalendarPage.days
              ? l.previousMonth
              : material.previousPageTooltip,
          style: metrics.iconStyle,
          onPressed: !_savingRange && _canStep(-1) ? () => _step(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: ValueKey(
            widget.embedded ? 'general-resource-next-month' : 'sked-date-next',
          ),
          tooltip: _page == _CalendarPage.days
              ? l.nextMonth
              : material.nextPageTooltip,
          style: metrics.iconStyle,
          onPressed: !_savingRange && _canStep(1) ? () => _step(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _dayGrid(BuildContext context, double height) {
    final l = AppLocalizations.of(context),
        material = MaterialLocalizations.of(context);
    final theme = Theme.of(context), c = theme.colorScheme;
    final start = startOfCalendarWeek(_month, firstWeekday: DateTime.monday);
    final range = dateSelectionRange(_selected, widget.selectionUnit);
    final dragPreview = widget.rangeController?.dragging == true;
    final selectedRange = _rangeMode
        ? widget.rangeController?.highlighted
        : dragPreview
        ? widget.rangeController?.previewRange
        : widget.displayRange;
    final pendingStart = _rangeMode || dragPreview
        ? widget.rangeController?.start
        : null;
    final paintRange = _rangeMode || dragPreview || selectedRange != null;
    final week = !paintRange && widget.selectionUnit == DateSelectionUnit.week;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Semantics(
                  label: DateFormat.EEEE(l.localeName)
                      .format(DateTime(2024, 1, i + 1)),
                  excludeSemantics: true,
                  child: SizedBox(
                    height: height,
                    child: Center(
                      child: Text(
                        l.localeName.startsWith('zh')
                            ? const ['一', '二', '三', '四', '五', '六', '日'][i]
                            : material.narrowWeekdays[(i + 1) % 7],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < 6; row++)
          Builder(
            builder: (context) {
              final rowStart = addCalendarDays(start, row * 7);
              final rowSelected =
                  week && DateUtils.isSameDay(rowStart, range.start);
              return DecoratedBox(
                key: ValueKey('sked-date-week-${_key(rowStart)}'),
                decoration: BoxDecoration(
                  color: rowSelected ? c.secondaryContainer : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day = addCalendarDays(rowStart, col);
                            final selected = DateUtils.isSameDay(
                              day,
                              _selected,
                            );
                            final today = DateUtils.isSameDay(day, _today);
                            final focused =
                                _hasFocus && DateUtils.isSameDay(day, _focused);
                            final allowed = !_savingRange && _allowed(day);
                            final inRange = paintRange
                                ? selectedRange?.contains(day) == true ||
                                      DateUtils.isSameDay(day, pendingStart)
                                : week
                                ? rowSelected
                                : selected;
                            final label = [
                              material.formatFullDate(day),
                              if (today) material.currentDateLabel,
                              if (rowSelected)
                                formatDateSelection(
                                  _selected,
                                  DateSelectionUnit.week,
                                  locale: l.localeName,
                                ),
                              if (paintRange &&
                                  inRange &&
                                  selectedRange != null)
                                '${material.formatFullDate(selectedRange.start)} – ${material.formatFullDate(selectedRange.end)}',
                              if (paintRange &&
                                  DateUtils.isSameDay(
                                    day,
                                    selectedRange?.start ?? pendingStart,
                                  ))
                                material.dateRangeStartLabel,
                              if (paintRange &&
                                  DateUtils.isSameDay(day, selectedRange?.end))
                                material.dateRangeEndLabel,
                            ].join(', ');
                            return Semantics(
                              button: true,
                              enabled: allowed,
                              selected: inRange,
                              focused: focused,
                              label: label,
                              excludeSemantics: true,
                              onTap: allowed ? () => _choose(day) : null,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  key: ValueKey('sked-date-${_key(day)}'),
                                  canRequestFocus: false,
                                  onTap: allowed
                                      ? () {
                                          _gridFocus.requestFocus();
                                          _choose(day);
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(5),
                                  child: Container(
                                    height: height,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          (paintRange
                                              ? inRange
                                              : selected && !week)
                                          ? c.secondaryContainer
                                          : null,
                                      borderRadius: paintRange
                                          ? BorderRadius.horizontal(
                                              left: Radius.circular(
                                                col == 0 ||
                                                        DateUtils.isSameDay(
                                                          day,
                                                          selectedRange
                                                                  ?.start ??
                                                              pendingStart,
                                                        )
                                                    ? 5
                                                    : 0,
                                              ),
                                              right: Radius.circular(
                                                col == 6 ||
                                                        DateUtils.isSameDay(
                                                          day,
                                                          selectedRange?.end ??
                                                              pendingStart,
                                                        )
                                                    ? 5
                                                    : 0,
                                              ),
                                            )
                                          : BorderRadius.circular(5),
                                      border:
                                          (paintRange
                                                  ? DateUtils.isSameDay(
                                                          day,
                                                          pendingStart ??
                                                              selectedRange
                                                                  ?.start,
                                                        ) ||
                                                        DateUtils.isSameDay(
                                                          day,
                                                          selectedRange?.end,
                                                        )
                                                  : selected) ||
                                              focused
                                          ? Border.all(
                                              color: focused
                                                  ? c.primary
                                                  : c.outline,
                                              width: focused ? 2 : 1,
                                            )
                                          : null,
                                    ),
                                    child: SizedBox.expand(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              '${day.day}',
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: !allowed
                                                        ? c.onSurface
                                                              .withValues(
                                                                alpha: 0.38,
                                                              )
                                                        : day.month ==
                                                              _month.month
                                                        ? c.onSurface
                                                        : c.onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                          if (today)
                                            Positioned(
                                              bottom: 2,
                                              child: Container(
                                                key: const ValueKey(
                                                  'sked-date-today-marker',
                                                ),
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: c.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                        ],
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
              );
            },
          ),
      ],
    );
  }

  Widget _monthGrid(BuildContext context, double height) => _choiceGrid(
    context,
    height,
    List.generate(12, (i) {
      final date = shiftDateMonth(
        _selected,
        (_month.year - _selected.year) * 12 + i + 1 - _selected.month,
      );
      return (
        key: 'sked-date-month-${_month.year}-${i + 1}',
        label: DateFormat.MMM(AppLocalizations.of(context).localeName)
            .format(date),
        enabled: _resolve(date, DateSelectionUnit.month) != null,
        selected: _selected.year == date.year && _selected.month == date.month,
        focused:
            _hasFocus &&
            _focused.year == date.year &&
            _focused.month == date.month,
        onTap: () => _selectMonth(i + 1),
      );
    }),
  );
  Widget _yearGrid(BuildContext context, double height) => _choiceGrid(
    context,
    height,
    List.generate(12, (i) {
      final year = _yearPageStart + i;
      return (
        key: 'sked-date-year-$year',
        label: '$year',
        enabled: year >= widget.firstDate.year && year <= widget.lastDate.year,
        selected: _selected.year == year,
        focused: _hasFocus && _focused.year == year,
        onTap: () => _selectYear(year),
      );
    }),
  );
  Widget _choiceGrid(
    BuildContext context,
    double height,
    List<
      ({
        String key,
        String label,
        bool enabled,
        bool selected,
        bool focused,
        VoidCallback onTap,
      })
    >
    choices,
  ) {
    final c = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++)
          Row(
            children: [
              for (final choice in choices.skip(row * 3).take(3))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Semantics(
                      button: true,
                      enabled: choice.enabled,
                      selected: choice.selected,
                      focused: choice.focused,
                      child: Material(
                        color: choice.selected
                            ? c.secondaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          key: ValueKey(choice.key),
                          canRequestFocus: false,
                          borderRadius: BorderRadius.circular(6),
                          onTap: choice.enabled
                              ? () {
                                  _gridFocus.requestFocus();
                                  choice.onTap();
                                }
                              : null,
                          child: Container(
                            constraints: BoxConstraints(
                              minHeight: math.max(48, height * 1.5),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: choice.focused
                                  ? Border.all(color: c.primary, width: 2)
                                  : null,
                            ),
                            child: Text(
                              choice.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: choice.enabled
                                    ? c.onSurface
                                    : c.onSurface.withValues(alpha: 0.38),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

String _key(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
