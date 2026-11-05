import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../agent/agent_application.dart';
import '../agent/attachments/attachment_storage.dart';
import '../agent/conversations/conversation_models.dart';
import '../agent/knowledge/knowledge_models.dart';
import '../models/agent_settings.dart';
import '../models/school_site_models.dart';
import '../models/timetable_models.dart';
import '../services/device_preferences_store.dart';
import 'backup_staging_storage.dart';
import 'selective_backup_app_data.dart';
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
          write: (target) =>
              _writeData(AppData.decodeStorageSnapshot(jsonEncode(target))),
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
        _SnapshotParticipant(
          owner: BackupOwner.knowledge,
          read: () async => _json(
            (await _agent.knowledgeRepository.readFrozenForRestore(
              validateOwner: _validateOwner,
            )).encode(),
          ),
          build: (plan, current) async {
            final selected = _agent.knowledge.normalizeRestoreRecords(
              selectedKnowledgeRestoreRecords(plan),
            );
            return _json(
              _agent.knowledgeRepository
                  .projectFrozenRestore(
                    selected,
                    restoreId: plan.id,
                    validateOwner: _validateOwner,
                  )
                  .encode(),
            );
          },
          write: (target) => _agent.knowledgeRepository.replaceFrozenForRestore(
            KnowledgeArchive.decode(jsonEncode(target)),
            validateOwner: _validateOwner,
          ),
        ),
        _SnapshotParticipant(
          owner: BackupOwner.conversations,
          read: () async => _json(
            (await _agent.conversations.readFrozenForRestore(
              validateOwner: _validateOwner,
            )).encode(),
          ),
          build: (plan, current) async => _json(
            _conversationTarget(
              ConversationArchive.decode(jsonEncode(current)),
              plan,
            ).encode(),
          ),
          write: (target) => _agent.conversations.replaceFrozenForRestore(
            ConversationArchive.decode(jsonEncode(target)),
            validateOwner: _validateOwner,
          ),
        ),
        _CredentialParticipant(agent: _agent, readData: _readData),
        _DevicePreferencesParticipant(
          store: _devicePreferences,
          validateOwner: _validateOwner,
        ),
        _AttachmentParticipant(
          storage: _agent.attachmentStore.storage,
          staging: _staging,
        ),
      ],
    );
  }
  final AgentApplication _agent;
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
    await _agent.initialize();
    await _agent.knowledge.initialize();
    final data = _readData();
    final conversations = List<AgentConversation>.of(
      _agent.conversations.conversations,
    );
    final knowledge = <KnowledgeRecord>[];
    for (final kind in KnowledgeKind.values) {
      knowledge.addAll(
        await _agent.knowledge.exportSelected(
          kind,
          _agent.knowledge.list(kind).map((record) => record.id),
        ),
      );
    }
    return buildSelectiveBackupInventory(
      appData: data,
      schoolSites: await _readSites(),
      knowledge: knowledge,
      conversations: conversations,
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
          final readCancellation = AttachmentCancellation();
          final release = token?.onCancel(readCancellation.cancel);
          try {
            final bytes = await _agent.attachmentStore.readBytes(
              attachment,
              cancellation: readCancellation,
            );
            token?.check();
            return bytes;
          } on AttachmentException catch (error) {
            if (error.code == AttachmentError.cancelled &&
                token?.isCancelled == true) {
              token!.check();
            }
            rethrow;
          } finally {
            release?.call();
          }
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
    if (bytes.length > SelectiveBackupLimits.archiveBytes) {
      backupLimit('The backup file is too large.');
    }
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
  ) async => decode(await _agent.attachmentStore.readBytes(attachment));

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
    return const SelectiveBackupPlanner().prepare(
      source: source,
      current: current,
      selection: selection,
    );
  });

  Future<void> restore(
    BackupRestorePlan plan, {
    BackupCancellation? cancellation,
  }) => _perform(() => _restorePlan(plan, cancellation: cancellation));

  Future<RestoredBackupInventory> restoreAndReadInventory(
    BackupRestorePlan plan,
  ) => _perform(() async {
    await _restorePlan(plan);
    return _readRestoredInventory();
  });

  Future<void> _restorePlan(
    BackupRestorePlan plan, {
    BackupCancellation? cancellation,
  }) async {
    _admitting = plan;
    try {
      await _coordinator.start(plan, cancellation: cancellation);
    } finally {
      _admitting = null;
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
        if (_agent.history.ownsMaintenance ||
            await _agent.conversations.pendingHistoryBatch() != null ||
            _agent.history.ownsMaintenance) {
          throw const SelectiveBackupException(
            SelectiveBackupError.unavailable,
            'Finish the pending history undo before restoring a backup.',
          );
        }
        _agent.conversations.freeze();
        _agent.knowledgeRepository.freeze();
        try {
          await _devicePreferences.freezeAndDrain();
          await _agent.conversations.waitForPendingWrites();
          await _agent.knowledgeRepository.waitForPendingWrites();
          bool completesDataRestore;
          if (_admitting case final plan?) {
            final conversations = await _agent.conversations
                .readFrozenForRestore(validateOwner: _validateOwner);
            await _agent.knowledgeRepository.readFrozenForRestore(
              validateOwner: _validateOwner,
            );
            final current = buildSelectiveBackupInventory(
              appData: _readData(),
              schoolSites: await _readOwnedSites(),
              knowledge: await _agent.knowledge.exportFrozenForRestore(
                validateOwner: _validateOwner,
              ),
              conversations: conversations.conversations,
              devicePreferences: buildDeviceBackupRecords(
                _devicePreferences.platform,
                await _devicePreferences.readAll(),
              ),
            );
            plan.validateCurrent(current);
            completesDataRestore = plan.owners.isNotEmpty;
          } else {
            // A resume with no fixed target is an empty operation. A pending
            // restore can complete without selecting or replacing any chat.
            completesDataRestore = await journal.read() != null;
          }
          await action();
          if (completesDataRestore) {
            _validateOwner();
            _agent.completeSuccessfulDataRestore();
          }
        } finally {
          try {
            _pending = await journal.read() != null;
          } catch (_) {
            _pending = true;
          }
          if (!_pending) {
            _devicePreferences.resume();
            _agent.conversations.resumeAfterMaintenance();
            _agent.knowledgeRepository.resumeAfterMaintenance();
          }
          _onRecoveryChanged(_pending);
          _notify();
        }
      });

  ConversationArchive _conversationTarget(
    ConversationArchive current,
    BackupRestorePlan plan,
  ) {
    final replacements = <String, AgentConversation>{};
    for (final change in plan.changes) {
      if (change.after.key.kind == BackupObjectKind.conversation &&
          change.needsWrite) {
        replacements[change.after.key.id] = restorePortableConversation(
          change.after,
          currentMode: _readData().agentSettings.permissionMode,
        );
      }
    }
    final restoredIds = replacements.keys.toSet();
    final merged = [
      for (final conversation in current.conversations)
        replacements.remove(conversation.id) ?? conversation,
      ...replacements.values,
    ];
    final target = ConversationArchive(
      revision: current.revision + 1,
      conversations: merged,
      selectedId: current.selectedId ?? merged.firstOrNull?.id,
      handoffs: current.handoffs.where(
        (handoff) => !restoredIds.contains(handoff.conversationId),
      ),
      terminatedIds: current.terminatedIds.difference(restoredIds),
    );
    // Individual imported chats can be valid while their merged archive
    // exceeds a quota or violates a shared reference. Reject that target before
    // admitting the journal or applying any other restore participant.
    ConversationArchive.decode(target.encode());
    return target;
  }

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

class _SnapshotParticipant implements BackupRestoreParticipant {
  _SnapshotParticipant({
    required this.owner,
    required this.read,
    required this.build,
    required this.write,
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
  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    final before = await read();
    return BackupPreparedTarget(
      owner: owner,
      restoreId: plan.id,
      descriptor: {'before': before, 'target': await build(plan, before)},
    );
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    if (canonicalBackupJson(await read()) !=
        canonicalBackupJson(target.descriptor['before'])) {
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
      if (current == canonicalBackupJson(target.descriptor['target'])) {
        return BackupTargetState.applied;
      }
      return current == canonicalBackupJson(target.descriptor['before'])
          ? BackupTargetState.prepared
          : BackupTargetState.conflict;
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
        SelectiveBackupError.unknown,
        'The restore precondition cannot be verified.',
      );
    }
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
  _AttachmentParticipant({required this.storage, required this.staging});
  final AttachmentStorage storage, staging;
  @override
  BackupOwner get owner => BackupOwner.attachments;
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
        final metadata = ConversationAttachment.fromJson(change.after.data);
        final stageId =
            'restore-${backupDigest(utf8.encode(plan.id)).substring(0, 24)}-${metadata.digest}';
        stageIds.add(stageId);
        final existing = await _blobState(storage, metadata);
        if (existing == BackupTargetState.conflict ||
            existing == BackupTargetState.unknown) {
          throw const SelectiveBackupException(
            SelectiveBackupError.conflict,
            'A stored file conflicts with its restore identity.',
          );
        }
        final staged = ConversationAttachment(
          id: stageId,
          name: metadata.name,
          mediaType: metadata.mediaType,
          byteLength: metadata.byteLength,
          digest: metadata.digest,
        );
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
        files.add({
          'attachment': metadata.toJson(),
          'stageId': stageId,
          'wasPresent': existing == BackupTargetState.applied,
        });
      }
      return BackupPreparedTarget(
        owner: owner,
        restoreId: plan.id,
        descriptor: {'files': files},
      );
    } catch (_) {
      // Preparation has not admitted any business write. The coordinator has
      // no descriptor for a participant that throws before returning, so this
      // owner must clean its own partially prepared stage.
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
    for (final file in target.descriptor['files'] as List) {
      final metadata = ConversationAttachment.fromJson(file['attachment']);
      final current = await _blobState(storage, metadata);
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
    for (final file in target.descriptor['files'] as List) {
      final metadata = ConversationAttachment.fromJson(file['attachment']);
      final current = await _blobState(storage, metadata);
      if (current == BackupTargetState.conflict ||
          current == BackupTargetState.unknown) {
        return current;
      }
      if (current == BackupTargetState.prepared) {
        final staged = ConversationAttachment(
          id: file['stageId'] as String,
          name: metadata.name,
          mediaType: metadata.mediaType,
          byteLength: metadata.byteLength,
          digest: metadata.digest,
        );
        if (await _blobState(staging, staged) != BackupTargetState.applied) {
          return BackupTargetState.unknown;
        }
        pending = true;
      }
    }
    return pending ? BackupTargetState.prepared : BackupTargetState.applied;
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    for (final file in target.descriptor['files'] as List) {
      final metadata = ConversationAttachment.fromJson(file['attachment']);
      final current = await _blobState(storage, metadata);
      if (current == BackupTargetState.applied) continue;
      if (current != BackupTargetState.prepared) {
        throw const SelectiveBackupException(
          SelectiveBackupError.conflict,
          'A file restore target changed.',
        );
      }
      await storage.write(metadata.id, staging.read(file['stageId'] as String));
      if (await _blobState(storage, metadata) != BackupTargetState.applied) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unknown,
          'The restored file could not be confirmed.',
        );
      }
    }
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {
    for (final file in target.descriptor['files'] as List) {
      await staging.delete(file['stageId'] as String);
    }
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

Map<String, Object?> _json(String source) =>
    Map<String, Object?>.from(jsonDecode(source) as Map);
