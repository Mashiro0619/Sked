import 'package:flutter/foundation.dart' show VoidCallback;

import '../models/timetable_models.dart';
import '../services/general_calendar_service.dart';
import 'app_data_maintenance.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'general_view_state.dart';
import 'workspace_transactions.dart';

/// Commits date/range navigation independently of event commands. Transient
/// focus and the previous visible date remain owned by [GeneralViewState].
class GeneralNavigationController {
  GeneralNavigationController({
    required this._session,
    required this._view,
    required this._transactions,
    required this._persistence,
    required this._maintenance,
    required this._notifyViewChanged,
  });

  static const _calendar = GeneralCalendarService();
  final AppSession _session;
  final GeneralViewState _view;
  final WorkspaceTransactions _transactions;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final VoidCallback _notifyViewChanged;

  Future<void> setDateRange(
    GeneralDateRange range, {
    DateTime? focusedDate,
    bool Function()? isCurrent,
    bool revealFocus = true,
  }) => _commit(
    (data) {
      final focus = focusedDate ?? data.selectedDate;
      return data.copyWith(
        customDateRange: range,
        selectedDateIso: (range.contains(focus) ? focus : range.start)
            .toIso8601String()
            .split('T')
            .first,
      );
    },
    isCurrent: isCurrent,
    revealFocus: revealFocus,
  );

  Future<void> clearDateRange() => _commit((data) {
    final date = data.selectedDate;
    final focus = !data.showWeekends && date.weekday > DateTime.friday
        ? DateTime(
            date.year,
            date.month,
            date.day - date.weekday + DateTime.friday,
          )
        : date;
    return _calendar
        .setSelectedDate(data, focus)
        .copyWith(customDateRange: null);
  });

  Future<void> setSelectedDate(
    DateTime date, {
    bool moveCustomRange = true,
  }) async {
    _requireNavigationAllowed();
    if (_view.navigationPending ||
        _session.data.generalMode.customDateRange != null) {
      await _commit(
        (data) => _calendar
            .setSelectedDate(data, date)
            .copyWith(
              customDateRange: moveCustomRange
                  ? data.customDateRange?.containing(date)
                  : data.customDateRange,
            ),
      );
      return;
    }
    final previous = _session.data.generalMode;
    final next = _calendar.setSelectedDate(previous, date);
    if (identical(next, previous) ||
        _sameDate(next.selectedDate, previous.selectedDate)) {
      return;
    }
    _requireNavigationAllowed();
    _session.replaceData(_session.data.copyWith(generalMode: next));
    _view.revealFocus();
    _notifyViewChanged();
    _persistence.scheduleUiStateSave();
  }

  void _requireNavigationAllowed() {
    // Keep the maintenance exception for callers outside the active lease.
    _session.ensureMutationAllowed();
    if (!_session.data.isWorkspaceEnabled(AppMode.general)) {
      throw StateError('Workspace is disabled: general');
    }
    if (_session.isClosed || _maintenance.isReserved) {
      throw StateError('Date navigation session is no longer active.');
    }
  }

  Future<void> _commit(
    GeneralScheduleData Function(GeneralScheduleData) change, {
    bool Function()? isCurrent,
    bool revealFocus = true,
  }) async {
    final sessionToken = _maintenance.dataSessionToken;
    final resumeBoundary =
        _session.data.workspaceReminderNotBefore[AppMode.general];
    void validateSession() {
      _requireNavigationAllowed();
      if (!identical(sessionToken, _maintenance.dataSessionToken) ||
          isCurrent?.call() == false ||
          resumeBoundary !=
              _session.data.workspaceReminderNotBefore[AppMode.general]) {
        throw StateError('Date navigation session is no longer active.');
      }
    }

    validateSession();
    await _transactions.run((transaction) async {
      validateSession();
      _view.navigationPending = true;
      try {
        await _persistence.flushPendingUiStateSaves();
        // Date changes share the transaction/write queue, but do not wait for
        // native notification projection or side-store reconciliation.
        validateSession();
        final previous = _session.data.generalMode;
        final next = change(previous);
        if (next.customDateRange == previous.customDateRange &&
            next.selectedDateIso == previous.selectedDateIso) {
          if (revealFocus) {
            _view.revealFocus();
            _notifyViewChanged();
          }
          return;
        }
        await transaction.commit((commit) async {
          _view.keepPreviousNavigation(previous);
          _session.replaceData(_session.data.copyWith(generalMode: next));
          try {
            await _persistence.saveAndNotify(
              notify: false,
              workspaceCommit: commit,
              rollbackOnFailure: false,
              emitCommit: false,
            );
            if (revealFocus) _view.revealFocus();
          } catch (_) {
            _session.restoreData(
              _session.data.copyWith(
                generalMode: _session.data.generalMode.copyWith(
                  customDateRange: previous.customDateRange,
                  selectedDateIso: previous.selectedDateIso,
                ),
              ),
            );
            rethrow;
          } finally {
            _view.completeNavigation();
            if (!_session.isClosed) _notifyViewChanged();
          }
        });
      } finally {
        _view.navigationPending = false;
      }
    });
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
