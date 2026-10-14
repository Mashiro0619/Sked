import 'package:flutter/foundation.dart' show VoidCallback;

import '../models/timetable_models.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'school_import_secret_controller.dart';
import 'workspace_transactions.dart';
import 'workspace_view_state.dart';

/// Owns workspace availability, mode changes and the editors that must finish
/// before a workspace can close. The shared session remains the data owner.
class WorkspaceCommands {
  WorkspaceCommands({
    required this._session,
    required this._view,
    required this._transactions,
    required this._persistence,
    required this._secrets,
    required this._runtimeMutationLock,
    required this._notifyViewChanged,
  });

  final AppSession _session;
  final WorkspaceViewState _view;
  final WorkspaceTransactions _transactions;
  final AppPersistence _persistence;
  final SchoolImportSecretController _secrets;
  final Future<void> Function(Future<void> Function()) _runtimeMutationLock;
  final VoidCallback _notifyViewChanged;
  final _exitGuards = <AppMode, Set<Future<bool> Function()>>{};

  bool hasExitGuards(AppMode mode) => _exitGuards[mode]?.isNotEmpty ?? false;

  VoidCallback registerExitGuard(AppMode mode, Future<bool> Function() guard) {
    (_exitGuards[mode] ??= {}).add(guard);
    return () => _exitGuards[mode]?.remove(guard);
  }

  Future<bool> prepareExit(AppMode mode) async {
    for (final guard in [...?_exitGuards[mode]]) {
      if (!await guard()) return false;
    }
    return true;
  }

  Future<void> setEnabled(AppMode mode, bool enabled) => _transactions.run((
    transaction,
  ) async {
    if (_session.data.isWorkspaceEnabled(mode) == enabled) return;
    if (!enabled && _session.data.enabledWorkspaces.length == 1) {
      throw StateError('At least one workspace must remain enabled.');
    }
    if (!enabled && !await prepareExit(mode)) return;
    await _runtimeMutationLock(() async {
      // Editor guards and the runtime lock can both await other mutations.
      // Read the current availability again when the commit actually begins.
      if (!enabled && mode == AppMode.student) {
        await _secrets.ensurePersistenceKnown();
      }
      await _commitAvailability(mode, enabled, transaction);
    });
  });

  Future<void> _commitAvailability(
    AppMode changed,
    bool enabled,
    WorkspaceTransaction transaction,
  ) async {
    _session.ensureMutationAllowed();
    final previous = _session.data;
    if (previous.isWorkspaceEnabled(changed) == enabled) return;
    final next = {...previous.enabledWorkspaces};
    enabled ? next.add(changed) : next.remove(changed);
    if (next.isEmpty) {
      throw StateError('At least one workspace must remain enabled.');
    }
    await transaction.commit((commit) async {
      _view.keepPreviousAvailability(previous);
      _session.replaceData(
        _session.data.copyWith(
          enabledWorkspaces: next,
          activeMode: next.contains(previous.activeMode)
              ? previous.activeMode
              : next.single,
          workspaceReminderNotBefore: {
            ...previous.workspaceReminderNotBefore,
            if (enabled) changed: DateTime.now().toUtc(),
          },
        ),
      );
      try {
        await _persistence.saveAndNotify(
          notify: false,
          workspaceCommit: commit,
          rollbackOnFailure: false,
        );
      } catch (_) {
        // A failed availability write must preserve newer edits in other fields.
        _session.restoreData(
          _session.data.copyWith(
            enabledWorkspaces: previous.enabledWorkspaces,
            activeMode: previous.activeMode,
            workspaceReminderNotBefore: previous.workspaceReminderNotBefore,
          ),
        );
        rethrow;
      } finally {
        _view.completeChange();
        if (!_session.isClosed) _notifyViewChanged();
      }
    });
  }

  Future<void> switchMode(AppMode mode) =>
      _transactions.run((transaction) async {
        _session.ensureMutationAllowed();
        if (!_session.data.isWorkspaceEnabled(mode)) {
          throw StateError('Workspace is disabled: ${mode.value}');
        }
        if (_view.activeMode == mode) return;
        final previousMode = _view.activeMode;
        await transaction.commit((commit) async {
          _session.ensureMutationAllowed();
          _view.keepPreviousMode(previousMode);
          _session.replaceData(_session.data.copyWith(activeMode: mode));
          try {
            await _persistence.saveAndNotify(
              notify: false,
              workspaceCommit: commit,
              rollbackOnFailure: false,
            );
          } catch (_) {
            if (_session.data.activeMode != previousMode) {
              _session.restoreData(
                _session.data.copyWith(activeMode: previousMode),
              );
            }
            rethrow;
          } finally {
            // Mode and theme become visible only after the write or rollback settles.
            _view.completeChange();
            if (!_session.isClosed) _notifyViewChanged();
          }
        });
      });
}
