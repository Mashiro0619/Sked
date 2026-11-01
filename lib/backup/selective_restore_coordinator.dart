import 'dart:async';
import 'dart:convert';

import 'selective_backup_models.dart';
import 'selective_backup_planner.dart';

enum BackupTargetState { prepared, applied, conflict, unknown }

/// The participant owns its staged payload (including binary files). The
/// descriptor is a durable identifier or exact bounded target, not an action
/// script. It must remain readable until cleanup after all stages are applied.
class BackupPreparedTarget {
  BackupPreparedTarget({
    required this.owner,
    required this.restoreId,
    required Map<String, Object?> descriptor,
  }) : descriptor = freezeBackupJson(descriptor) as Map<String, Object?> {
    backupText(restoreId, max: 256);
  }
  final BackupOwner owner;
  final String restoreId;
  final Map<String, Object?> descriptor;
  String get fingerprint => backupDigest(
    utf8.encode(
      canonicalBackupJson({
        'owner': owner.name,
        'restoreId': restoreId,
        'descriptor': descriptor,
      }),
    ),
  );
  Map<String, Object?> toJson() => {
    'owner': owner.name,
    'restoreId': restoreId,
    'descriptor': descriptor,
    'digest': fingerprint,
  };
  factory BackupPreparedTarget.fromJson(Object? value) {
    final json = backupMap(value, {
      'owner',
      'restoreId',
      'descriptor',
      'digest',
    });
    final owner = BackupOwner.values
        .where((item) => item.name == json['owner'])
        .firstOrNull;
    if (owner == null || json['descriptor'] is! Map<String, dynamic>) {
      backupInvalid('Invalid restore participant.');
    }
    final result = BackupPreparedTarget(
      owner: owner,
      restoreId: backupText(json['restoreId'], max: 256),
      descriptor: json['descriptor'] as Map<String, dynamic>,
    );
    if (json['digest'] != result.fingerprint) {
      backupInvalid('Restore target checksum mismatch.');
    }
    return result;
  }
}

abstract class BackupRestoreParticipant {
  BackupOwner get owner;
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan);
  Future<void> validate(BackupPreparedTarget target);
  Future<BackupTargetState> readState(BackupPreparedTarget target);
  Future<void> apply(BackupPreparedTarget target);

  /// Idempotent; called only before business effects, or after every participant
  /// has been durably marked applied. It never undoes committed business data.
  Future<void> cleanup(BackupPreparedTarget target);
}

class SelectiveRestoreState {
  SelectiveRestoreState({
    required this.restoreId,
    required this.planFingerprint,
    required Iterable<BackupPreparedTarget> targets,
    this.completed = 0,
    this.started = false,
  }) : targets = List.unmodifiable(targets) {
    backupText(restoreId, max: 256);
    if (!backupDigestIsValid(planFingerprint) ||
        this.targets.isEmpty ||
        this.targets.length > BackupOwner.values.length ||
        this.targets.map((target) => target.owner).toSet().length !=
            this.targets.length ||
        this.targets.any((target) => target.restoreId != restoreId) ||
        completed < 0 ||
        completed > this.targets.length ||
        completed == this.targets.length && started) {
      backupInvalid('Invalid restore progress.');
    }
  }
  final String restoreId;
  final String planFingerprint;
  final List<BackupPreparedTarget> targets;
  final int completed;
  final bool started;
  bool get isComplete => completed == targets.length;
  SelectiveRestoreState markStarted() => SelectiveRestoreState(
    restoreId: restoreId,
    planFingerprint: planFingerprint,
    targets: targets,
    completed: completed,
    started: true,
  );
  SelectiveRestoreState markApplied() => SelectiveRestoreState(
    restoreId: restoreId,
    planFingerprint: planFingerprint,
    targets: targets,
    completed: completed + 1,
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'restoreId': restoreId,
    'planFingerprint': planFingerprint,
    'targets': targets.map((target) => target.toJson()).toList(),
    'completed': completed,
    'started': started,
  };
  factory SelectiveRestoreState.fromJson(Object? value) {
    if (value is Map && value['version'] != 1) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unsupportedVersion,
        'Unsupported restore journal version.',
      );
    }
    final json = backupMap(value, {
      'version',
      'restoreId',
      'planFingerprint',
      'targets',
      'completed',
      'started',
    });
    if (json['started'] is! bool) backupInvalid('Invalid restore phase.');
    return SelectiveRestoreState(
      restoreId: backupText(json['restoreId'], max: 256),
      planFingerprint: backupText(json['planFingerprint'], max: 64),
      targets: backupList(
        json['targets'],
        max: BackupOwner.values.length,
      ).map(BackupPreparedTarget.fromJson),
      completed: backupInteger(
        json['completed'],
        max: BackupOwner.values.length,
      ),
      started: json['started'] as bool,
    );
  }
}

abstract class SelectiveRestoreJournal {
  Future<SelectiveRestoreState?> read();

  /// Returns only after reading back the exact target and progress.
  Future<void> write(SelectiveRestoreState state);

  /// Successful clear must not leave an older pending journal recoverable.
  Future<void> clear();
}

/// The host supplies its maintenance barrier. It must prevent new writes,
/// drain accepted work, keep the barrier while recovery is pending, and exclude
/// the initiating Agent run from waiting for itself.
class SelectiveRestoreCoordinator {
  SelectiveRestoreCoordinator({
    required this.journal,
    required Iterable<BackupRestoreParticipant> participants,
    required this._runExclusive,
  }) : _participants = {
         for (final participant in participants) participant.owner: participant,
       } {
    if (_participants.length != participants.length) {
      backupInvalid('Duplicate restore participant owner.');
    }
  }
  final SelectiveRestoreJournal journal;
  final Map<BackupOwner, BackupRestoreParticipant> _participants;
  final Future<void> Function(Future<void> Function()) _runExclusive;
  Future<void> _tail = Future.value();
  static const _order = [
    BackupOwner.attachments,
    BackupOwner.mainData,
    BackupOwner.credentials,
    BackupOwner.schoolSites,
    BackupOwner.devicePreferences,
    BackupOwner.knowledge,
    BackupOwner.conversations,
  ];

  Future<void> start(
    BackupRestorePlan plan, {
    BackupCancellation? cancellation,
  }) => _serialize(
    () => _runExclusive(() async {
      cancellation?.check();
      if (await journal.read() != null) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'Finish the pending restore before starting another.',
        );
      }
      final owners = plan.owners;
      if (owners.isEmpty) return;
      for (final owner in owners) {
        if (!_participants.containsKey(owner)) {
          throw SelectiveBackupException(
            SelectiveBackupError.unavailable,
            'The ${owner.name} restore participant is unavailable.',
          );
        }
      }
      final targets = <BackupPreparedTarget>[];
      var journalAttempted = false;
      try {
        for (final owner in _order.where(owners.contains)) {
          cancellation?.check();
          final target = await _participants[owner]!.prepare(plan);
          if (target.owner != owner || target.restoreId != plan.id) {
            backupInvalid(
              'The participant prepared a different restore target.',
            );
          }
          targets.add(target);
        }
        for (final target in targets) {
          cancellation?.check();
          await _participants[target.owner]!.validate(target);
        }
        cancellation?.check();
        final state = SelectiveRestoreState(
          restoreId: plan.id,
          planFingerprint: plan.fingerprint,
          targets: targets,
        );
        journalAttempted = true;
        await journal.write(state);
        // After this point cancellation cannot discard a partially applied
        // restore. Recovery always follows this fixed target to completion.
        await _resumeNow(expectedRestoreId: plan.id);
      } catch (_) {
        if (!journalAttempted) {
          for (final target in targets.reversed) {
            try {
              await _participants[target.owner]!.cleanup(target);
            } catch (_) {
              // No business write occurred. The owner retains the stage for its
              // orphan cleanup; do not mask the preparation failure.
            }
          }
        }
        rethrow;
      }
    }),
  );

  Future<void> resume() => _serialize(() => _runExclusive(() => _resumeNow()));

  Future<void> _resumeNow({String? expectedRestoreId}) async {
    final loaded = await journal.read();
    if (loaded == null) {
      if (expectedRestoreId != null) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unknown,
          'The admitted restore journal disappeared.',
        );
      }
      return;
    }
    var state = loaded;
    if (expectedRestoreId != null && state.restoreId != expectedRestoreId) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The admitted restore journal was replaced.',
      );
    }
    for (final target in state.targets) {
      if (!_participants.containsKey(target.owner)) {
        throw SelectiveBackupException(
          SelectiveBackupError.unavailable,
          'The ${target.owner.name} restore participant is unavailable.',
        );
      }
    }
    for (var index = 0; index < state.completed; index++) {
      final target = state.targets[index];
      if (await _participants[target.owner]!.readState(target) !=
          BackupTargetState.applied) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unknown,
          'A completed restore stage no longer matches its confirmed target.',
        );
      }
    }
    while (!state.isComplete) {
      final target = state.targets[state.completed];
      final participant = _participants[target.owner]!;
      var observed = await participant.readState(target);
      if (observed == BackupTargetState.conflict) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'A restore participant no longer matches the fixed target.',
        );
      }
      if (observed == BackupTargetState.unknown) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unknown,
          'A restore participant requires recovery before continuing.',
        );
      }
      if (observed == BackupTargetState.prepared) {
        if (!state.started) {
          state = state.markStarted();
          await journal.write(state);
        }
        await participant.apply(target);
        observed = await participant.readState(target);
        if (observed != BackupTargetState.applied) {
          throw const SelectiveBackupException(
            SelectiveBackupError.unknown,
            'The restored data could not be confirmed.',
          );
        }
      }
      state = state.markApplied();
      await journal.write(state);
    }
    // A completed marker makes cleanup retryable without reading a stage that
    // a preceding cleanup call already removed, or repeating business writes.
    for (final target in state.targets) {
      await _participants[target.owner]!.cleanup(target);
    }
    await journal.clear();
  }

  Future<void> _serialize(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> waitForPendingOperations() => _tail;
}

/// Explicit test storage, never selected as a production fallback.
class MemorySelectiveRestoreJournal implements SelectiveRestoreJournal {
  String? source;
  @override
  Future<SelectiveRestoreState?> read() async => source == null
      ? null
      : SelectiveRestoreState.fromJson(jsonDecode(source!));
  @override
  Future<void> write(SelectiveRestoreState state) async =>
      source = jsonEncode(state.toJson());
  @override
  Future<void> clear() async => source = null;
}
