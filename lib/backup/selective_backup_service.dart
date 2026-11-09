import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../agent/agent_application.dart';
import '../agent/attachments/attachment_models.dart';
import '../agent/attachments/attachment_storage.dart';
import '../application/data_restore_receipt.dart';
import '../models/application_ledger.dart';
import '../models/agent_settings.dart';
import '../models/school_site_models.dart';
import '../models/timetable_models.dart';
import '../services/device_preferences_store.dart';
import 'backup_staging_storage.dart';
import 'selective_backup_app_data.dart';
import 'selective_backup_agent_data.dart';
import 'selective_backup_agent_store.dart';
import 'selective_backup_codec.dart';
import 'selective_backup_device_data.dart';
import 'selective_backup_models.dart';
import 'selective_backup_planner.dart';
import 'selective_restore_coordinator.dart';
import 'selective_restore_journal.dart';

typedef RestoredBackupInventory = ({
  SelectiveBackupBundle? inventory,
  SelectiveBackupError? refreshError,
});

/// Application-owned entry point shared by settings and Agent tools. UI owns
/// only its selection; all effects use the existing stores under one lease.
class SelectiveBackupService extends ChangeNotifier {
  SelectiveBackupService({
    required this._agent,
    required this._devicePreferences,
    required this._readData,
    required Future<AppData> Function() readOwnedData,
    required this._writeData,
    required this._readSites,
    required this._readOwnedSites,
    required this._writeOwnedSites,
    required this._runExclusive,
    required this._validateOwner,
    required this._onRecoveryChanged,
    SelectiveRestoreJournal? journal,
    AttachmentStorage? staging,
  }) : journal = journal ?? createSelectiveRestoreJournal(),
       _staging = staging ?? createBackupStagingStorage() {
    _coordinator = SelectiveRestoreCoordinator(
      journal: this.journal,
      runExclusive: _withFrozenStores,
      participants: [
        _SnapshotParticipant(
          owner: BackupOwner.mainData,
          read: () async => (await readOwnedData()).toJson(),
          build: (plan, current) async => prepareMainBackupRestore(
            AppData.decodeStorageSnapshot(jsonEncode(current)),
            plan,
          ).target.toJson(),
          buildCompletion: _operationCompletionLedger,
          write: (target) =>
              _writeData(AppData.decodeStorageSnapshot(jsonEncode(target))),
          normalize: (value) =>
              AppData.decodeStorageSnapshot(jsonEncode(value)).toJson(),
        ),
        _SnapshotParticipant(
          owner: BackupOwner.schoolSites,
          read: () async => {
            'sites': (await _readOwnedSites())
                .map((site) => site.toJson())
                .toList(),
          },
          build: (plan, current) async => {
            'sites': mergeSelectedSchoolSites(
              decodeSchoolSitesStrict(jsonEncode(current['sites'])),
              plan,
            ).map((site) => site.toJson()).toList(),
          },
          write: (target) => _writeOwnedSites(
            decodeSchoolSitesStrict(jsonEncode(target['sites'])),
          ),
        ),
        _NativeAgentParticipant(owner: BackupOwner.knowledge, store: _native),
        _NativeAgentParticipant(
          owner: BackupOwner.conversations,
          store: _native,
        ),
        _CredentialParticipant(agent: _agent, readData: _readData),
        _DevicePreferencesParticipant(
          store: _devicePreferences,
          validateOwner: _validateOwner,
        ),
        _AttachmentParticipant(native: _native, staging: _staging),
      ],
    );
  }
  final AgentApplication _agent;
  late final _native = NativeAgentBackupStore(_agent.nativeClient);
  final DevicePreferencesStore _devicePreferences;
  bool supportsDeviceGroup(BackupRecord record) =>
      record.key.kind != BackupObjectKind.deviceSettings ||
      devicePreferencePlatform(record) == _devicePreferences.platform;
  final AppData Function() _readData;
  final Future<void> Function(AppData) _writeData;
  final Future<List<SchoolSite>> Function() _readSites;
  final Future<List<SchoolSite>> Function() _readOwnedSites;
  final Future<void> Function(List<SchoolSite>) _writeOwnedSites;
  final Future<void> Function(Future<void> Function()) _runExclusive;
  OperationReceipt? _restoreOperation;
  final void Function() _validateOwner;
  final void Function(bool) _onRecoveryChanged;
  final AttachmentStorage _staging;
  final SelectiveRestoreJournal journal;
  late final SelectiveRestoreCoordinator _coordinator;
  BackupRestorePlan? _admitting;
  bool _busy = false, _pending = false, _disposed = false;
  bool get isBusy => _busy;
  bool get recoveryPending => _pending;

  Future<bool> refreshRecoveryStatus() async {
    try {
      _pending = await journal.read() != null;
    } catch (_) {
      _pending = true;
      _onRecoveryChanged(true);
      _notify();
      rethrow;
    }
    _onRecoveryChanged(_pending);
    _notify();
    return _pending;
  }

  Future<SelectiveBackupBundle> inventory() async {
    if (_busy || _pending) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unavailable,
        'Finish recovery before selecting backup data.',
      );
    }
    return _inventory();
  }

  Future<SelectiveBackupBundle> _inventory() async {
    await _agent.prepareBackupRead();
    return _inventoryFromStores();
  }

  Future<SelectiveBackupBundle> _inventoryFromStores({
    bool owned = false,
  }) async {
    return buildSelectiveBackupInventory(
      appData: _readData(),
      schoolSites: await (owned ? _readOwnedSites() : _readSites()),
      agentRecords: _agent.platformSupported
          ? nativeAgentBackupRecords(await _native.exportParts())
          : const [],
      devicePreferences: buildDeviceBackupRecords(
        _devicePreferences.platform,
        await _devicePreferences.readAll(),
      ),
    );
  }

  Future<Uint8List> export(
    SelectiveBackupBundle displayed,
    BackupSelection selection, {
    BackupCancellation? cancellation,
  }) async {
    if (_busy || _pending) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unavailable,
        'Finish the current backup operation before exporting.',
      );
    }
    _busy = true;
    _notify();
    try {
      cancellation?.check();
      final current = await _inventory();
      if (current.fingerprint != displayed.fingerprint) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'The backup selection changed. Refresh it before exporting.',
        );
      }
      final bundle = await exportSelectiveBackup(
        inventory: current,
        selection: selection,
        cancellation: cancellation,
        readAttachment: (attachment, token) async {
          token?.check();
          final bytes = await _native.readAttachment(attachment);
          token?.check();
          return bytes;
        },
      );
      return const SelectiveBackupCodec().encode(
        bundle,
        cancellation: cancellation,
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  SelectiveBackupBundle decode(Uint8List bytes) {
    var offset =
        bytes.length >= 3 &&
            bytes[0] == 0xef &&
            bytes[1] == 0xbb &&
            bytes[2] == 0xbf
        ? 3
        : 0;
    while (offset < bytes.length &&
        const [9, 10, 13, 32].contains(bytes[offset])) {
      offset++;
    }
    if (offset < bytes.length &&
        (bytes[offset] == 0x7b || bytes[offset] == 0x5b)) {
      return decodeLegacySelectiveBackup(
        utf8.decode(
          Uint8List.sublistView(bytes, offset),
          allowMalformed: false,
        ),
        localeCode: _readData().localeCode,
      );
    }
    return const SelectiveBackupCodec().decode(bytes);
  }

  /// The tool host supplies only the current conversation's attached metadata.
  /// This method never accepts a filesystem path or searches another chat.
  Future<SelectiveBackupBundle> decodeAttachment(
    ConversationAttachment attachment,
  ) async => decode(await _native.readAttachment(attachment));

  Future<BackupRestorePlan> prepareRestore(
    SelectiveBackupBundle source,
    BackupSelection selection,
  ) => _perform(() async {
    if (_pending) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unavailable,
        'Finish recovery before selecting backup data.',
      );
    }
    final current = await _inventory();
    final plan = const SelectiveBackupPlanner().prepare(
      source: source,
      current: current,
      selection: selection,
    );
    _validateAgentPlatform(plan);
    return plan;
  });

  Future<void> restore(
    BackupRestorePlan plan, {
    BackupCancellation? cancellation,
    OperationReceipt? operationReceipt,
  }) => _perform(
    () => _restorePlan(
      plan,
      cancellation: cancellation,
      operationReceipt: operationReceipt,
    ),
  );

  Future<RestoredBackupInventory> restoreAndReadInventory(
    BackupRestorePlan plan,
  ) => _perform(() async {
    await _restorePlan(plan);
    return _readRestoredInventory();
  });

  Future<void> _restorePlan(
    BackupRestorePlan plan, {
    BackupCancellation? cancellation,
    OperationReceipt? operationReceipt,
  }) async {
    _validateAgentPlatform(plan);
    _admitting = plan;
    _restoreOperation = operationReceipt;
    try {
      await _coordinator.start(plan, cancellation: cancellation);
    } finally {
      _admitting = null;
      _restoreOperation = null;
    }
  }

  void _validateAgentPlatform(BackupRestorePlan plan) {
    if (!_agent.platformSupported &&
        plan.selected.any(
          (key) => const {
            BackupOwner.conversations,
            BackupOwner.knowledge,
            BackupOwner.attachments,
          }.contains(key.owner),
        )) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unavailable,
        'Agent records cannot be restored on this platform.',
      );
    }
  }

  Map<String, Object?>? _operationCompletionLedger(
    BackupRestorePlan plan,
    Map<String, Object?> target,
  ) {
    final pending = _restoreOperation;
    if (pending == null) return null;
    final current = _readData().applicationLedger;
    final arguments = pending.result['arguments'];
    final data = AppData.decodeStorageSnapshot(jsonEncode(target));
    final ledger = data.applicationLedger;
    if (ledger == null || ledger.generation != plan.dataGeneration) {
      backupInvalid('The restore completion needs its fresh data generation.');
    }
    try {
      return buildDataRestoreCompletionLedger(
        current: current,
        target: ledger,
        pending: pending,
        action: 'backups.restore_selected',
        restoreId: plan.id,
        version: plan.fingerprint,
        effectDetails: {
          'selectedObjects': plan.selected.length,
          'skippedDeviceGroups': arguments is Map
              ? arguments['unsupportedGroups'] ?? const []
              : const [],
          'permissionsPreserved': true,
          'secretsImported': false,
        },
      ).toJson();
    } on FormatException catch (error) {
      backupInvalid(error.message);
    }
  }

  Future<void> resume() => _perform(_coordinator.resume);

  Future<RestoredBackupInventory> resumeAndReadInventory() =>
      _perform(() async {
        await _coordinator.resume();
        return _readRestoredInventory();
      });

  Future<RestoredBackupInventory> _readRestoredInventory() async {
    try {
      return (inventory: await _inventory(), refreshError: null);
    } catch (error) {
      // The restore is already durably complete. A later inventory failure
      // must not be reported as an uncommitted restore or invite replay.
      return (
        inventory: null,
        refreshError: error is SelectiveBackupException
            ? error.code
            : SelectiveBackupError.unavailable,
      );
    }
  }

  Future<T> _perform<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unavailable,
        'A backup operation is already active.',
      );
    }
    _busy = true;
    _notify();
    try {
      return await action();
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> _withFrozenStores(Future<void> Function() action) =>
      _runExclusive(() async {
        try {
          await _agent.prepareNativeBackupRestore();
          await _devicePreferences.freezeAndDrain();
          bool completesDataRestore;
          if (_admitting case final plan?) {
            plan.validateCurrent(await _inventoryFromStores(owned: true));
            completesDataRestore = plan.owners.isNotEmpty;
          } else {
            completesDataRestore = await journal.read() != null;
          }
          await action();
          if (completesDataRestore) {
            _validateOwner();
            await _agent.refreshAfterNativeBackupRestore();
            await _agent.completeSuccessfulDataRestore();
          }
        } finally {
          try {
            _pending = await journal.read() != null;
          } catch (_) {
            _pending = true;
          }
          if (!_pending) {
            _devicePreferences.resume();
            _agent.resumeAfterNativeBackupRestore();
          }
          _onRecoveryChanged(_pending);
          _notify();
        }
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> close() async {
    await _coordinator.waitForPendingOperations();
    await _staging.close();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Two preference groups can commit separately. A partial before/target mix
/// is resumable; an unrelated value is a conflict. No group is written twice
/// merely because the participant's stage acknowledgement was interrupted.
class _DevicePreferencesParticipant implements BackupRestoreParticipant {
  _DevicePreferencesParticipant({
    required this.store,
    required this.validateOwner,
  });
  final DevicePreferencesStore store;
  final void Function() validateOwner;
  @override
  BackupOwner get owner => BackupOwner.devicePreferences;

  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    validateOwner();
    final groups = <Map<String, Object?>>[];
    for (final change in plan.changes.where(
      (change) =>
          change.needsWrite &&
          change.after.key.kind == BackupObjectKind.deviceSettings,
    )) {
      final preferences = readDeviceBackupRecord(change.after);
      if (preferences.platform != store.platform) {
        backupInvalid('Device platform changed before restore.');
      }
      groups.add({
        'group': preferences.group.name,
        'before': await store.readGroup(preferences.group),
        'target': preferences.values,
      });
    }
    return BackupPreparedTarget(
      owner: owner,
      restoreId: plan.id,
      descriptor: {
        'version': 1,
        'platform': store.platform.name,
        'groups': groups,
      },
    );
  }

  List<
    ({
      DevicePreferenceGroup group,
      Map<String, Object?> before,
      Map<String, Object?> target,
    })
  >
  _groups(BackupPreparedTarget target) {
    validateOwner();
    final descriptor = backupMap(target.descriptor, {
      'version',
      'platform',
      'groups',
    });
    if (target.owner != owner ||
        descriptor['version'] != 1 ||
        descriptor['platform'] != store.platform.name) {
      backupInvalid('Unsupported device restore participant.');
    }
    final result =
        <
          ({
            DevicePreferenceGroup group,
            Map<String, Object?> before,
            Map<String, Object?> target,
          })
        >[];
    final seen = <DevicePreferenceGroup>{};
    for (final raw in backupList(
      descriptor['groups'],
      max: DevicePreferenceGroup.values.length,
    )) {
      final json = backupMap(raw, {'group', 'before', 'target'});
      final group = DevicePreferenceGroup.values
          .where((group) => group.name == json['group'])
          .firstOrNull;
      if (group == null || !seen.add(group)) {
        backupInvalid('Invalid device restore group.');
      }
      try {
        result.add((
          group: group,
          before: validateDevicePreferenceValues(group, json['before']),
          target: validateDevicePreferenceValues(group, json['target']),
        ));
      } on FormatException {
        backupInvalid('Invalid device restore payload.');
      }
    }
    if (result.isEmpty) backupInvalid('Empty device restore participant.');
    return result;
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    for (final entry in _groups(target)) {
      if (canonicalBackupJson(await store.readGroup(entry.group)) !=
          canonicalBackupJson(entry.before)) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'Device preferences changed during restore preparation.',
        );
      }
    }
  }

  @override
  Future<BackupTargetState> readState(BackupPreparedTarget target) async {
    try {
      var applied = true;
      for (final entry in _groups(target)) {
        final actual = canonicalBackupJson(await store.readGroup(entry.group));
        if (actual == canonicalBackupJson(entry.target)) continue;
        if (actual != canonicalBackupJson(entry.before)) {
          return BackupTargetState.conflict;
        }
        applied = false;
      }
      return applied ? BackupTargetState.applied : BackupTargetState.prepared;
    } catch (_) {
      return BackupTargetState.unknown;
    }
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    // Check every selected group before applying the next one, including on
    // replay, so a conflict never gets hidden by completing another group.
    final state = await readState(target);
    if (state == BackupTargetState.applied) return;
    if (state != BackupTargetState.prepared) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The device restore target cannot be verified.',
      );
    }
    for (final entry in _groups(target)) {
      final current = canonicalBackupJson(await store.readGroup(entry.group));
      if (current == canonicalBackupJson(entry.target)) {
        continue;
      }
      if (current != canonicalBackupJson(entry.before)) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'A device group changed before its restore write.',
        );
      }
      await store.restoreGroup(
        entry.group,
        entry.target,
        validateOwner: validateOwner,
      );
      if (canonicalBackupJson(await store.readGroup(entry.group)) !=
          canonicalBackupJson(entry.target)) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unknown,
          'The restored device preferences could not be confirmed.',
        );
      }
    }
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {}
}

class _NativeAgentParticipant implements BackupRestoreParticipant {
  _NativeAgentParticipant({required this.owner, required this.store});

  @override
  final BackupOwner owner;
  final NativeAgentBackupStore store;

  Future<Map<String, Object?>> _current() => store.exportParts(
    conversationIds: owner == BackupOwner.conversations ? null : const [],
    knowledgeKeys: owner == BackupOwner.knowledge ? null : const [],
  );

  Map<BackupObjectKey, BackupRecord> _records(Map<String, Object?> parts) => {
    for (final record in nativeAgentBackupRecords(parts))
      if (record.key.owner == owner) record.key: record,
  };

  Map<String, Object?> _parts(BackupPreparedTarget target, String name) {
    if (target.descriptor['agentVersion'] !=
            SelectiveBackupCodec.agentVersion ||
        target.descriptor[name] is! Map) {
      backupInvalid('Unsupported native Agent restore target.');
    }
    return Map<String, Object?>.from(target.descriptor[name] as Map);
  }

  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    final selected = [
      for (final change in plan.changes)
        if (change.needsWrite && change.after.key.owner == owner) change.after,
    ];
    final target = nativeArchiveParts(selected);
    // This also validates the native target before any participant writes.
    await store.restored(target, plan.id);
    final keys = selected.map((record) => record.key).toSet();
    final before = nativeArchiveParts(
      _records(await _current()).values
          .where((record) => keys.contains(record.key)),
    );
    return BackupPreparedTarget(
      owner: owner,
      restoreId: plan.id,
      descriptor: {
        'agentVersion': SelectiveBackupCodec.agentVersion,
        'before': before,
        'target': target,
      },
    );
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    final selected = _records(_parts(target, 'target')).keys.toSet();
    final current = nativeArchiveParts(
      _records(await _current()).values
          .where((record) => selected.contains(record.key)),
    );
    if (canonicalBackupJson(current) !=
        canonicalBackupJson(_parts(target, 'before'))) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The native Agent records changed during restore preparation.',
      );
    }
  }

  @override
  Future<BackupTargetState> readState(BackupPreparedTarget target) async {
    try {
      final parts = _parts(target, 'target');
      if (await store.restored(parts, target.restoreId)) {
        return BackupTargetState.applied;
      }
      final current = _records(await _current());
      final before = _records(_parts(target, 'before'));
      for (final record in _records(parts).values) {
        // Conversation imports commit separately. Confirm completed records
        // and compare only the targets that still need their first write.
        if (owner == BackupOwner.conversations &&
            await store.restored(
              nativeArchiveParts([record]),
              target.restoreId,
            )) {
          continue;
        }
        if (canonicalBackupJson(current[record.key]?.data) !=
            canonicalBackupJson(before[record.key]?.data)) {
          return BackupTargetState.conflict;
        }
      }
      return BackupTargetState.prepared;
    } on SelectiveBackupException catch (error) {
      return error.code == SelectiveBackupError.conflict
          ? BackupTargetState.conflict
          : BackupTargetState.unknown;
    } catch (_) {
      return BackupTargetState.unknown;
    }
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    final state = await readState(target);
    if (state == BackupTargetState.applied) return;
    if (state != BackupTargetState.prepared) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The native Agent restore target changed.',
      );
    }
    await store.restore(_parts(target, 'target'), target.restoreId);
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {}
}

class _SnapshotParticipant
    implements BackupRestoreParticipant, BackupRestoreCompletionParticipant {
  _SnapshotParticipant({
    required this.owner,
    required this.read,
    required this.build,
    required this.write,
    this.normalize,
    this.buildCompletion,
  });
  @override
  final BackupOwner owner;
  final Future<Map<String, Object?>> Function() read;
  final Future<Map<String, Object?>> Function(
    BackupRestorePlan,
    Map<String, Object?>,
  )
  build;
  final Future<void> Function(Map<String, Object?>) write;
  final Map<String, Object?> Function(Map<String, Object?> value)? normalize;
  final Map<String, Object?>? Function(
    BackupRestorePlan plan,
    Map<String, Object?> target,
  )?
  buildCompletion;

  Object? _normalized(Object? value) => normalize == null
      ? value
      : normalize!(Map<String, Object?>.from(value as Map));

  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    final before = await read();
    final target = await build(plan, before);
    final completionLedger = buildCompletion?.call(plan, target);
    return BackupPreparedTarget(
      owner: owner,
      restoreId: plan.id,
      descriptor: {
        'before': before,
        'target': target,
        'completionLedger': ?completionLedger,
      },
    );
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    if (canonicalBackupJson(await read()) !=
        canonicalBackupJson(_normalized(target.descriptor['before']))) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'A restore participant changed during preparation.',
      );
    }
  }

  @override
  Future<BackupTargetState> readState(BackupPreparedTarget target) async {
    try {
      final current = canonicalBackupJson(await read());
      if (_completedTarget(target) case final completed?) {
        if (current == canonicalBackupJson(_normalized(completed))) {
          return BackupTargetState.applied;
        }
      }
      if (current ==
          canonicalBackupJson(_normalized(target.descriptor['target']))) {
        return BackupTargetState.applied;
      }
      return current ==
              canonicalBackupJson(_normalized(target.descriptor['before']))
          ? BackupTargetState.prepared
          : BackupTargetState.conflict;
    } catch (_) {
      return BackupTargetState.unknown;
    }
  }

  Map<String, Object?>? _completedTarget(BackupPreparedTarget target) {
    final ledger = target.descriptor['completionLedger'];
    if (ledger is! Map || owner != BackupOwner.mainData) return null;
    return {
      ...Map<String, Object?>.from(target.descriptor['target'] as Map),
      'applicationLedger': ledger,
    };
  }

  @override
  Future<void> complete(BackupPreparedTarget target) async {
    final completed = _completedTarget(target);
    if (completed == null) return;
    final expected = canonicalBackupJson(_normalized(completed));
    final current = canonicalBackupJson(await read());
    if (current == expected) return;
    if (current !=
        canonicalBackupJson(_normalized(target.descriptor['target']))) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The restored data changed before recording its completion.',
      );
    }
    await write(completed);
    if (canonicalBackupJson(await read()) != expected) {
      throw const SelectiveBackupException(
        SelectiveBackupError.unknown,
        'The restore completion receipt was not acknowledged.',
      );
    }
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    await write(Map<String, Object?>.from(target.descriptor['target'] as Map));
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {}
}

class _CredentialParticipant implements BackupRestoreParticipant {
  _CredentialParticipant({required this.agent, required this.readData});
  final AgentApplication agent;
  final AppData Function() readData;
  @override
  BackupOwner get owner => BackupOwner.credentials;
  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    final current = readData();
    final target = prepareMainBackupRestore(current, plan).target.agentSettings;
    return BackupPreparedTarget(
      owner: owner,
      restoreId: plan.id,
      descriptor: {
        'before': current.agentSettings.toJson(),
        'target': target.toJson(),
      },
    );
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    if (canonicalBackupJson(readData().agentSettings.toJson()) !=
        canonicalBackupJson(target.descriptor['before'])) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The connection changed during restore preparation.',
      );
    }
    // Only a selected connection needs the keyring. Read both slots before
    // admitting any business write; an unreadable or future credential format
    // must not first be discovered after the main-data target has committed.
    // A readable unreconciled state is allowed: apply owns that reconciliation.
    await agent.connections.isReconciledForRestore(
      AgentSettings.fromJson(target.descriptor['before']),
    );
  }

  @override
  Future<BackupTargetState> readState(BackupPreparedTarget target) async {
    try {
      final expected = AgentSettings.fromJson(target.descriptor['target']);
      if (canonicalBackupJson(readData().agentSettings.toJson()) !=
          canonicalBackupJson(expected.toJson())) {
        return BackupTargetState.conflict;
      }
      return await agent.connections.isReconciledForRestore(expected)
          ? BackupTargetState.applied
          : BackupTargetState.prepared;
    } catch (_) {
      return BackupTargetState.unknown;
    }
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    final expected = AgentSettings.fromJson(target.descriptor['target']);
    if (canonicalBackupJson(readData().agentSettings.toJson()) !=
        canonicalBackupJson(expected.toJson())) {
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'The fixed connection target is not current.',
      );
    }
    await agent.connections.initialize(migrateLegacy: false);
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {}
}

class _AttachmentParticipant implements BackupRestoreParticipant {
  _AttachmentParticipant({required this.native, required this.staging});
  final NativeAgentBackupStore native;
  final AttachmentStorage staging;
  @override
  BackupOwner get owner => BackupOwner.attachments;

  List<Map<String, Object?>> _files(BackupPreparedTarget target) {
    if (target.descriptor['agentVersion'] !=
        SelectiveBackupCodec.agentVersion) {
      backupInvalid('Unsupported native attachment restore target.');
    }
    return [
      for (final file in backupList(target.descriptor['files']))
        Map<String, Object?>.from(file as Map),
    ];
  }

  Map<String, Object?> _metadata(Map<String, Object?> file) =>
      Map<String, Object?>.from(file['attachment'] as Map);

  ConversationAttachment _staged(
    Map<String, Object?> file,
    ConversationAttachment metadata,
  ) => ConversationAttachment(
    id: file['stageId'] as String,
    name: metadata.name,
    mediaType: metadata.mediaType,
    byteLength: metadata.byteLength,
    digest: metadata.digest,
  );

  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    final files = <Map<String, Object?>>[];
    final stageIds = <String>{};
    try {
      for (final change in plan.changes) {
        if (change.after.key.kind != BackupObjectKind.attachment ||
            !change.needsWrite) {
          continue;
        }
        final data = change.after.data;
        final metadata = nativeBackupAttachment(data);
        final stageId =
            'restore-${backupDigest(utf8.encode(plan.id)).substring(0, 24)}-${metadata.digest}';
        stageIds.add(stageId);
        final existing = await _nativeBlobState(native, data);
        if (existing == BackupTargetState.conflict ||
            existing == BackupTargetState.unknown) {
          throw const SelectiveBackupException(
            SelectiveBackupError.conflict,
            'A stored file conflicts with its restore identity.',
          );
        }
        final file = <String, Object?>{
          'attachment': data,
          'stageId': stageId,
          'wasPresent': existing == BackupTargetState.applied,
        };
        final staged = _staged(file, metadata);
        if (await _blobState(staging, staged) != BackupTargetState.applied) {
          final bytes = plan.source.binaries[change.after.binaryDigest]!;
          await staging.write(stageId, Stream.value(bytes));
          if (await _blobState(staging, staged) != BackupTargetState.applied) {
            throw const SelectiveBackupException(
              SelectiveBackupError.unknown,
              'Backup file staging could not be confirmed.',
            );
          }
        }
        files.add(file);
      }
      return BackupPreparedTarget(
        owner: owner,
        restoreId: plan.id,
        descriptor: {
          'agentVersion': SelectiveBackupCodec.agentVersion,
          'files': files,
        },
      );
    } catch (_) {
      for (final id in stageIds) {
        try {
          await staging.delete(id);
        } catch (_) {
          // Leave recoverable staging bytes if their removal also failed.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    for (final file in _files(target)) {
      final current = await _nativeBlobState(native, _metadata(file));
      if (current !=
          (file['wasPresent'] == true
              ? BackupTargetState.applied
              : BackupTargetState.prepared)) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'A file changed while the restore was prepared.',
        );
      }
    }
  }

  @override
  Future<BackupTargetState> readState(BackupPreparedTarget target) async {
    var pending = false;
    for (final file in _files(target)) {
      final data = _metadata(file);
      final metadata = nativeBackupAttachment(data);
      final current = await _nativeBlobState(native, data);
      if (current == BackupTargetState.conflict ||
          current == BackupTargetState.unknown) {
        return current;
      }
      if (current == BackupTargetState.prepared) {
        if (await _blobState(staging, _staged(file, metadata)) !=
            BackupTargetState.applied) {
          return BackupTargetState.unknown;
        }
        pending = true;
      }
    }
    return pending ? BackupTargetState.prepared : BackupTargetState.applied;
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    for (final file in _files(target)) {
      final data = _metadata(file);
      final current = await _nativeBlobState(native, data);
      if (current == BackupTargetState.applied) continue;
      if (current != BackupTargetState.prepared) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'A file restore target changed.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in staging.read(file['stageId'] as String)) {
        bytes.add(chunk);
      }
      await native.writeAttachment(data, bytes.takeBytes());
      if (await _nativeBlobState(native, data) != BackupTargetState.applied) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unknown,
          'The restored file could not be confirmed.',
        );
      }
    }
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {
    for (final file in _files(target)) {
      await staging.delete(file['stageId'] as String);
    }
  }
}

Future<BackupTargetState> _nativeBlobState(
  NativeAgentBackupStore store,
  Map<String, Object?> metadata,
) async {
  try {
    return await store.attachmentExists(metadata)
        ? BackupTargetState.applied
        : BackupTargetState.prepared;
  } on SelectiveBackupException catch (error) {
    return error.code == SelectiveBackupError.conflict ||
            error.code == SelectiveBackupError.invalid
        ? BackupTargetState.conflict
        : BackupTargetState.unknown;
  } catch (_) {
    return BackupTargetState.unknown;
  }
}

Future<BackupTargetState> _blobState(
  AttachmentStorage storage,
  ConversationAttachment metadata,
) async {
  try {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in storage.read(metadata.id)) {
      if (bytes.length + chunk.length > metadata.byteLength) {
        return BackupTargetState.conflict;
      }
      bytes.add(chunk);
    }
    return bytes.length == metadata.byteLength &&
            backupDigest(bytes.takeBytes()) == metadata.digest
        ? BackupTargetState.applied
        : BackupTargetState.conflict;
  } on AttachmentException catch (error) {
    return error.code == AttachmentError.missing
        ? BackupTargetState.prepared
        : BackupTargetState.unknown;
  } catch (_) {
    return BackupTargetState.unknown;
  }
}
