import 'package:flutter/foundation.dart';

import '../models/general_date_range.dart';
import '../utils/calendar_date_utils.dart';

enum DateRangeEndpoint { start, end }

typedef _RangeDraft = ({
  DateTime? start,
  GeneralDateRange? candidate,
  DateTime? previewDay,
  DateRangeEndpoint? endpoint,
  GeneralDateRange? editBase,
  bool tooLong,
  bool invalidOrder,
  bool saveFailed,
});

/// Transient selection and preview are separate from the last durable range.
/// Only a successful, awaited command replaces [applied].
class SkedDateRangeController extends ChangeNotifier {
  SkedDateRangeController({
    required GeneralDateRange initialRange,
    required this.onApply,
    this.isSessionCurrent,
  }) : _applied = initialRange;
  final Future<void> Function(GeneralDateRange) onApply;
  final bool Function()? isSessionCurrent;
  bool get isCurrent => !_disposed && (isSessionCurrent?.call() ?? true);
  GeneralDateRange _applied;
  GeneralDateRange get applied => _applied;
  DateTime? start;
  GeneralDateRange? candidate;
  DateTime? _previewDay;
  DateRangeEndpoint? editingEndpoint;
  GeneralDateRange? _editBase;
  _RangeDraft? _beforeDrag;
  bool saving = false;
  bool saveFailed = false;
  bool tooLong = false;
  bool invalidOrder = false;
  bool _disposed = false;
  int _generation = 0;
  GeneralDateRange get editingRange => _editBase ?? candidate ?? _applied;
  bool get dragging => _beforeDrag != null;
  bool get selectingEnd =>
      editingEndpoint == DateRangeEndpoint.end ||
      (editingEndpoint == null && start != null);
  bool get canPreview =>
      candidate == null && (start != null || editingEndpoint != null);
  bool get previewInvalid => _previewDay != null && previewRange == null;
  GeneralDateRange? get previewRange =>
      _previewDay == null ? null : _range(_previewDay!);
  GeneralDateRange? get highlighted =>
      previewRange ?? candidate ?? (start == null ? editingRange : null);

  bool _allowed(DateTime day) =>
      !day.isBefore(GeneralDateRange.firstDate) &&
      !day.isAfter(GeneralDateRange.lastDate);
  ({DateTime start, DateTime end}) _pair(DateTime day) {
    final base = _editBase ?? _applied;
    if (editingEndpoint == DateRangeEndpoint.start) {
      return (start: day, end: base.end);
    }
    if (editingEndpoint == DateRangeEndpoint.end) {
      return (start: base.start, end: day);
    }
    final anchor = start ?? day;
    return day.isBefore(anchor)
        ? (start: day, end: anchor)
        : (start: anchor, end: day);
  }

  GeneralDateRange? _range(DateTime day) {
    final pair = _pair(day);
    try {
      return GeneralDateRange(pair.start, pair.end);
    } on FormatException {
      return null;
    }
  }

  bool get previewTooLong =>
      _previewDay != null &&
      calendarDaysBetween(_pair(_previewDay!).start, _pair(_previewDay!).end) +
              1 >
          GeneralDateRange.maxDays;

  void _reset() {
    start = null;
    candidate = null;
    _previewDay = null;
    editingEndpoint = null;
    _editBase = null;
    _beforeDrag = null;
    saveFailed = false;
    tooLong = false;
    invalidOrder = false;
  }

  void sync(GeneralDateRange range) {
    if (!isCurrent || saving || _applied == range) return;
    _applied = range;
    _reset();
    _generation++;
  }

  void preview(DateTime? day) {
    if (saving || !isCurrent || !canPreview) return;
    final next = day == null ? null : DateTime(day.year, day.month, day.day);
    if (_previewDay == next) return;
    _previewDay = next;
    if (next != null && _range(next) != null) {
      tooLong = false;
      invalidOrder = false;
    }
    notifyListeners();
  }

  void edit(DateRangeEndpoint endpoint) {
    if (saving || !isCurrent) return;
    final base = candidate ?? _applied;
    _reset();
    _editBase = base;
    editingEndpoint = endpoint;
    start = endpoint == DateRangeEndpoint.end ? base.start : null;
    notifyListeners();
  }

  Future<bool> select(DateTime day) async {
    if (saving || dragging || !isCurrent) return false;
    day = DateTime(day.year, day.month, day.day);
    if (!_allowed(day)) return false;
    if (editingEndpoint == null && (start == null || candidate != null)) {
      _reset();
      start = day;
      notifyListeners();
      return false;
    }
    final range = _range(day);
    if (range != null) return apply(range);
    final pair = _pair(day);
    tooLong =
        calendarDaysBetween(pair.start, pair.end) + 1 >
        GeneralDateRange.maxDays;
    invalidOrder = pair.end.isBefore(pair.start);
    _previewDay = day;
    notifyListeners();
    return false;
  }

  void beginDrag(DateTime day) {
    if (saving || dragging || !isCurrent) return;
    day = DateTime(day.year, day.month, day.day);
    if (!_allowed(day)) return;
    final draft = (
      start: start,
      candidate: candidate,
      previewDay: _previewDay,
      endpoint: editingEndpoint,
      editBase: _editBase,
      tooLong: tooLong,
      invalidOrder: invalidOrder,
      saveFailed: saveFailed,
    );
    _reset();
    _beforeDrag = draft;
    start = day;
    _previewDay = day;
    notifyListeners();
  }

  void cancelDrag() {
    final old = _beforeDrag;
    if (old == null || _disposed) return;
    start = old.start;
    candidate = old.candidate;
    _previewDay = old.previewDay;
    editingEndpoint = old.endpoint;
    _editBase = old.editBase;
    tooLong = old.tooLong;
    invalidOrder = old.invalidOrder;
    saveFailed = old.saveFailed;
    _beforeDrag = null;
    notifyListeners();
  }

  Future<bool> endDrag() async {
    if (!dragging || saving || !isCurrent) {
      cancelDrag();
      return false;
    }
    final range = previewRange;
    final overLimit = previewTooLong;
    if (range == null) {
      cancelDrag();
      if (overLimit) {
        tooLong = true;
        notifyListeners();
      }
      return false;
    }
    _beforeDrag = null;
    return apply(range);
  }

  Future<bool> apply(GeneralDateRange range) async {
    if (saving || !isCurrent) return false;
    final generation = ++_generation;
    _reset();
    candidate = range;
    start = range.start;
    saving = true;
    notifyListeners();
    try {
      await onApply(range);
      if (!isCurrent || generation != _generation) return false;
      _applied = range;
      start = null;
      candidate = null;
      return true;
    } catch (error, stack) {
      if (!_disposed && generation == _generation) {
        saveFailed = true;
        debugPrint('Apply date range failed: $error\n$stack');
      }
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        saving = false;
        notifyListeners();
      }
    }
  }

  Future<bool> retry() async =>
      candidate != null && !saving ? apply(candidate!) : false;
  void cancel() {
    if (saving || _disposed) return;
    _generation++;
    _reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
