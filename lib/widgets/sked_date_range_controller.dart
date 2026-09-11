import 'package:flutter/foundation.dart';

import '../models/general_date_range.dart';

/// The same pending two-click selection is shared by the sidebar and popup.
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
  bool saving = false;
  bool saveFailed = false;
  bool tooLong = false;
  bool _disposed = false;
  int _generation = 0;
  bool get selectingEnd => start != null;
  GeneralDateRange? get highlighted =>
      candidate ?? (start == null ? _applied : null);
  void sync(GeneralDateRange range) {
    if (!isCurrent || saving || _applied == range) return;
    _applied = range;
    start = null;
    candidate = null;
    saveFailed = false;
    tooLong = false;
    _generation++;
  }

  Future<bool> select(DateTime day) async {
    if (saving || !isCurrent) return false;
    day = DateTime(day.year, day.month, day.day);
    if (day.isBefore(GeneralDateRange.firstDate) ||
        day.isAfter(GeneralDateRange.lastDate)) {
      return false;
    }
    if (start == null || candidate != null) {
      start = day;
      candidate = null;
      saveFailed = false;
      tooLong = false;
      notifyListeners();
      return false;
    }
    try {
      final range = day.isBefore(start!)
          ? GeneralDateRange(day, start!)
          : GeneralDateRange(start!, day);
      return await apply(range);
    } on FormatException {
      tooLong = true;
      notifyListeners();
      return false;
    }
  }

  Future<bool> apply(GeneralDateRange range) async {
    if (saving || !isCurrent) return false;
    final generation = ++_generation;
    candidate = range;
    start = range.start;
    tooLong = false;
    saveFailed = false;
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
    start = null;
    candidate = null;
    saveFailed = false;
    tooLong = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
