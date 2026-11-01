import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_codec.dart';
import 'package:sked/backup/selective_backup_device_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_layout_preferences.dart';

import '../agent/acceptance/acceptance_harness.dart';

class _ControlledReadStorage extends MemoryAttachmentStorage {
  bool stall = false;
  final entered = Completer<void>();
  final cancelled = Completer<void>();
  StreamController<List<int>>? _stalled;

  @override
  Stream<List<int>> read(String id) {
    if (!stall) return super.read(id);
    _stalled ??= StreamController<List<int>>(
      onListen: entered.complete,
      onCancel: cancelled.complete,
    );
    return _stalled!.stream;
  }

  @override
  Future<void> close() async {
    await _stalled?.close();
  }
}

class _FailAfterMainJournal extends MemorySelectiveRestoreJournal {
  bool fail = false;
  final attempts = <SelectiveRestoreState>[];
  SelectiveRestoreState? failedState;

  @override
  Future<void> write(SelectiveRestoreState state) async {
    attempts.add(state);
    if (fail && state.completed == 1) {
      fail = false;
      failedState = state;
      throw StateError('Stopped after the main store committed.');
    }
    await super.write(state);
  }
}

AppData _incomingRestore(AppData current) => current.copyWith(
  studentMode: current.studentMode.copyWith(
    timetables: [
      for (final table in current.studentMode.timetables)
        table.copyWith(config: table.config.copyWith(name: 'Do not import')),
    ],
  ),
  generalMode: current.generalMode.copyWith(
    schedules: [
      for (final calendar in current.generalMode.schedules)
        calendar.copyWith(
          name: calendar.id == 'visible'
              ? 'Restored visible calendar'
              : 'Do not import hidden calendar',
        ),
    ],
  ),
);

Future<void> _attachRestore(AcceptanceHarness h) => h.attach(
  'restore-source',
  'structured_file',
  encodeAppBackup(_incomingRestore(h.saved), const []),
);

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

Future<String> _attachBytes(AcceptanceHarness h, Uint8List bytes) async {
  final file = await h.app.agent.attachmentStore.put(
    id: 'selected-backup-source',
    name: 'selected.zip',
    mediaType: 'application/zip',
    byteLength: bytes.length,
    openRead: () => Stream.value(bytes),
  );
  await h.app.agent.conversations.update(
    h.conversationId,
    (current) => current.copyWith(
      attachments: [...current.attachments, file],
      draftAttachmentIds: [...current.draftAttachmentIds, file.id],
    ),
  );
  return file.id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AcceptanceHarness h;
  late _ControlledReadStorage blobs;
  late _FailAfterMainJournal journal;
  setUp(() async {
    h = AcceptanceHarness();
    blobs = _ControlledReadStorage();
    journal = _FailAfterMainJournal();
    await h.initialize(
      attachmentStorage: blobs,
      selectiveRestoreJournal: journal,
    );
  });
  tearDown(() => h.close());

  test('Agent inspects, generates and saves only selected backup objects through the normal permission gate', () async {
    await h.run(() async {
      final description = await h.call('backups.inspect', {'limit': 1});
      expect(description['objects'], hasLength(1));
      expect(description['nextOffset'], 1);
      final artifact = await h.call('exports.prepare', {
        'format': 'backup_zip',
        'objects': [
          {'kind': 'calendar', 'id': 'hidden'},
        ],
      });
      expect(artifact['mimeType'], 'application/zip');
      expect(h.writtenArtifacts, isEmpty);
      final plan = await h.call('exports.write', {
        'artifactId': artifact['artifactId'],
      });
      h.scope.policy.update(mode: AgentPermissionMode.plan);
      await expectLater(
        h.externalCommit(plan),
        throwsA(isA<OperationProblem>()),
      );
      expect(h.writtenArtifacts, isEmpty);
      h.scope.policy.update(mode: AgentPermissionMode.full);
      final accepted = await h.call('exports.write', {
        'artifactId': artifact['artifactId'],
      });
      final result = await h.externalCommit(accepted);
      expect(result['effectStatus'], 'applied');
      final archive = const SelectiveBackupCodec().decode(
        h.writtenArtifacts.single.binaryBytes!,
      );
      expect(archive.records.map((record) => record.key), [
        const BackupObjectKey(BackupObjectKind.calendar, 'hidden'),
      ]);
    }, skill: 'export-and-backup');
  });

  test(
    'Agent exports the same device preferences edited by its live UI owner',
    () async {
      await h.layout.load();
      h.layout.setPreferredSize(
        DesktopLayoutRegion.assistant,
        const PreferredRegionSize(width: 460),
      );
      expect(await h.layout.flush(), isTrue);
      await h.run(() async {
        final inspection = await h.call('backups.inspect', {'limit': 100});
        final device = (inspection['objects'] as List).singleWhere(
          (object) =>
              object['kind'] == 'deviceSettings' &&
              object['group'] == 'desktopLayout',
        ) as Map;
        expect(device['supportedOnThisPlatform'], isTrue);
        final artifact = await h.call('exports.prepare', {
          'format': 'backup_zip',
          'objects': [
            {'kind': 'deviceSettings', 'id': device['id']},
          ],
        });
        final plan = await h.call('exports.write', {
          'artifactId': artifact['artifactId'],
        });
        await h.externalCommit(plan);
        final archive = const SelectiveBackupCodec().decode(
          h.writtenArtifacts.single.binaryBytes!,
        );
        final restored = readDeviceBackupRecord(archive.records.single);
        expect(restored.values, {
          'regions': {
            'assistant': {'width': 460.0},
          },
        });
      }, skill: 'export-and-backup');
    },
  );

  test(
    'Agent previews skipped device groups and keeps the local values',
    () async {
      final inventory = await h.app.backups.selective.inventory();
      final calendar = inventory.records.firstWhere(
        (record) =>
            record.key ==
            const BackupObjectKey(BackupObjectKind.calendar, 'visible'),
      );
      final selectedCalendar = BackupRecord(
        key: calendar.key,
        label: 'Restored calendar',
        data: {
          ...calendar.data,
          'entity': {
            ...(calendar.data['entity'] as Map).cast<String, Object?>(),
            'name': 'Restored calendar',
          },
        },
      );
      final foreignPlatform =
          h.app.devicePreferences.platform == DevicePreferencePlatform.web
          ? DevicePreferencePlatform.windows
          : DevicePreferencePlatform.web;
      final unsupported = deviceBackupRecord(
        PortableDevicePreferences(
          platform: foreignPlatform,
          group: DevicePreferenceGroup.desktopLayout,
          values: const {
            'regions': {
              'assistant': {'width': 999.0},
            },
          },
        ),
      );
      final source = SelectiveBackupBundle(
        records: [selectedCalendar, unsupported],
        roots: [selectedCalendar.key, unsupported.key],
      );
      final sourceId = await _attachBytes(
        h,
        const SelectiveBackupCodec().encode(source),
      );
      final originalDeviceValues = await h.app.devicePreferences.readAll();
      await h.run(() async {
        final inspection = await h.call('backups.inspect', {
          'sourceId': sourceId,
        });
        final device = (inspection['objects'] as List).singleWhere(
          (object) => object['kind'] == 'deviceSettings',
        ) as Map;
        expect(device['supportedOnThisPlatform'], isFalse);
        final prepared = await h.call('backups.prepare_restore', {
          'sourceId': sourceId,
          'objects': [selectedCalendar.key.toJson(), unsupported.key.toJson()],
        });
        expect(prepared['unsupportedGroups'], hasLength(1));
        expect(
          (prepared['unsupportedGroups'] as List).single['id'],
          unsupported.key.id,
        );
        final result = await h.externalCommit(prepared);
        expect(result['effectStatus'], 'applied');
        expect(
          result['effectResult'],
          containsPair('skippedDeviceGroups', hasLength(1)),
        );
        expect(h.saved.generalMode.schedules.first.name, 'Restored calendar');
        expect(await h.app.devicePreferences.readAll(), originalDeviceValues);
      }, skill: 'restore-and-clear');
    },
  );

  test('stopping Agent aborts a stalled backup read without publishing an artifact', () async {
    final fileId = await _attachBytes(h, Uint8List.fromList([1, 2, 3]));
    blobs.stall = true;
    await h.run(() async {
      final exporting = h.call('exports.prepare', {
        'format': 'backup_zip',
        'objects': [
          {'kind': 'conversation', 'id': h.conversationId},
        ],
        'attachmentIds': [fileId],
      });
      final rejected = expectLater(
        exporting,
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.cancelled,
          ),
        ),
      );
      await blobs.entered.future;
      h.scope.cancel();
      await rejected.timeout(const Duration(seconds: 5));
      await blobs.cancelled.future;
      expect(h.app.backups.selective.isBusy, isFalse);
      expect(h.writtenArtifacts, isEmpty);
      expect(blobs.values, contains(fileId));
    }, skill: 'export-and-backup');
  });

  test(
    'Agent selective restore drains other work without waiting on its own run',
    () async {
      final original = h.saved;
      final incoming = original.copyWith(
        generalMode: original.generalMode.withSchedule(
          original.generalMode.schedules.first.copyWith(
            name: 'Restored visible calendar',
          ),
        ),
      );
      await h.attach(
        'source',
        'structured_file',
        encodeAppBackup(incoming, const []),
      );
      await h.run(() async {
        final inspection = await h.call('backups.inspect', {
          'sourceId': 'source',
          'limit': 100,
        });
        expect(
          (inspection['objects'] as List).where(
            (object) => object['kind'] == 'calendar',
          ),
          hasLength(2),
        );
        final prepared = await h.call('backups.prepare_restore', {
          'sourceId': 'source',
          'objects': [
            {'kind': 'calendar', 'id': 'visible'},
          ],
          'attachmentIds': <String>[],
        });
        await h.externalCommit(prepared);
        expect(
          h.saved.generalMode.schedules.first.name,
          'Restored visible calendar',
        );
        expect(
          h.saved.generalMode.schedules.last.toJson(),
          original.generalMode.schedules.last.toJson(),
        );
        expect(h.saved.studentMode.toJson(), original.studentMode.toJson());
        expect(h.saved.agentSettings.toJson(), original.agentSettings.toJson());
        expect(h.app.backups.selective.recoveryPending, isFalse);
      }, skill: 'restore-and-clear');
    },
  );

  for (final invalid in <String, Object?>{
    'non-list selection': {'kind': 'calendar', 'id': 'visible'},
    'empty selection': <Object?>[],
    'unknown object kind': [
      {'kind': 'not-a-kind', 'id': 'visible'},
    ],
    'duplicate objects': [
      {'kind': 'calendar', 'id': 'visible'},
      {'kind': 'calendar', 'id': 'visible'},
    ],
    'absent selected object': [
      {'kind': 'calendar', 'id': 'missing-calendar'},
    ],
    'attachment selected as an object': [
      {'kind': 'attachment', 'id': 'missing-file'},
    ],
  }.entries) {
    test('selective restore rejects ${invalid.key} before admission', () async {
      await _attachRestore(h);
      await h.run(() async {
        final before = h.saved.encode();
        await expectLater(
          h.call('backups.prepare_restore', {
            'sourceId': 'restore-source',
            'objects': invalid.value,
          }),
          throwsA(_problem(OperationErrorCode.invalidArgument)),
        );
        expect(h.saved.encode(), before);
        expect(journal.attempts, isEmpty);
        expect(await journal.read(), isNull);
        expect(h.app.backups.selective.recoveryPending, isFalse);
        expect(h.app.session.canWrite, isTrue);
        expect(h.writtenArtifacts, isEmpty);
      });
    });
  }

  test(
    'selective restore cannot borrow a source from another conversation',
    () async {
      final foreign = await h.app.agent.conversations.create(
        title: 'Other chat',
      );
      await h.app.agent.conversations.update(
        foreign.id,
        (current) => current.copyWith(
          sources: [
            ConversationSource(
              id: 'foreign-restore',
              kind: 'structured_file',
              text: encodeAppBackup(_incomingRestore(h.saved), const []),
            ),
          ],
        ),
      );
      await h.run(() async {
        final before = h.saved.encode();
        await expectLater(
          h.call('backups.prepare_restore', {
            'sourceId': 'foreign-restore',
            'objects': [
              {'kind': 'calendar', 'id': 'visible'},
            ],
          }),
          throwsA(_problem(OperationErrorCode.notFound)),
        );
        expect(h.saved.encode(), before);
        expect(journal.attempts, isEmpty);
        expect(h.app.backups.selective.recoveryPending, isFalse);
      });
    },
  );

  test('manual target edit after preparation rejects the restore before a journal write', () async {
    await _attachRestore(h);
    await h.run(() async {
      final prepared = await h.call('backups.prepare_restore', {
        'sourceId': 'restore-source',
        'objects': [
          {'kind': 'calendar', 'id': 'visible'},
        ],
      });
      await h.app.generalCommands.renameSchedule('visible', 'Manual name');
      final manual = h.saved.encode();
      await expectLater(
        h.externalCommit(prepared),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(h.saved.encode(), manual);
      expect(journal.attempts, isEmpty);
      expect(await journal.read(), isNull);
      expect(h.app.backups.selective.recoveryPending, isFalse);
      expect(h.app.session.canWrite, isTrue);
    });
  });

  test('a side-store target edited before restore is a confirmed refusal, not an unknown effect', () async {
    await h.layout.load();
    h.layout.setPreferredSize(
      DesktopLayoutRegion.assistant,
      const PreferredRegionSize(width: 400),
    );
    expect(await h.layout.flush(), isTrue);
    final target = deviceBackupRecord(
      PortableDevicePreferences(
        platform: h.app.devicePreferences.platform,
        group: DevicePreferenceGroup.desktopLayout,
        values: const {
          'regions': {
            'assistant': {'width': 480.0},
          },
        },
      ),
    );
    final sourceId = await _attachBytes(
      h,
      const SelectiveBackupCodec().encode(
        SelectiveBackupBundle(records: [target], roots: [target.key]),
      ),
    );
    await h.run(() async {
      final prepared = await h.call('backups.prepare_restore', {
        'sourceId': sourceId,
        'objects': [target.key.toJson()],
      });
      final before = h.saved.encode();
      h.layout.setPreferredSize(
        DesktopLayoutRegion.assistant,
        const PreferredRegionSize(width: 540),
      );
      expect(await h.layout.flush(), isTrue);
      expect(h.saved.encode(), before);
      final result = await h.externalCommit(prepared);
      expect(result['effectStatus'], 'failed');
      expect(result['dataStatus'], 'unchanged');
      expect(result['receiptFinalized'], isTrue);
      expect(result['recoveryRequired'], isFalse);
      expect(result['effectResult'], containsPair('code', 'conflict'));
      expect(result['effectResult'], containsPair('effectStarted', false));
      expect(
        h.layout.preferenceFor(DesktopLayoutRegion.assistant),
        const PreferredRegionSize(width: 540),
      );
      expect(journal.attempts, isEmpty);
      expect(await journal.read(), isNull);
      expect(h.app.backups.selective.recoveryPending, isFalse);
      expect(h.app.session.canWrite, isTrue);
    });
  });

  test('a lost phase write after main data remains unknown and lifecycle resumes its fixed targets', () async {
    final before = h.saved;
    final source = buildSelectiveBackupInventory(
      appData: _incomingRestore(before),
      knowledge: [
        KnowledgeRecord(
          kind: KnowledgeKind.memory,
          id: 'restored-note',
          title: 'Restored note',
          body: 'Synthetic content restored after the main phase.',
        ),
      ],
    );
    final sourceId = await _attachBytes(
      h,
      const SelectiveBackupCodec().encode(source),
    );
    journal.fail = true;
    Map<String, Object?>? result;
    late String restoreId;
    try {
      await h.run(() async {
        final prepared = await h.call('backups.prepare_restore', {
          'sourceId': sourceId,
          'objects': [
            {'kind': 'calendar', 'id': 'visible'},
            {'kind': 'memory', 'id': 'restored-note'},
          ],
        });
        restoreId =
            h.app.agent.external
                    .plan(prepared['planId'] as String)!
                    .operation
                    .arguments['restoreId']
                as String;
        result = await h.externalCommit(prepared);
      });
    } on ConversationStorageException {
      // A pending restore may freeze the terminal host-message save. Its tool
      // result must still be captured as unknown, never converted to success.
    }
    expect(result, isNotNull);
    expect(result!['effectStatus'], 'unknown');
    expect(result!['dataStatus'], 'unknown');
    expect(result!['recoveryRequired'], isTrue);
    expect(journal.failedState, isNotNull);
    expect(journal.failedState!.restoreId, restoreId);
    final pending = (await journal.read())!;
    expect(pending.restoreId, restoreId);
    expect(pending.completed, 0);
    expect(pending.started, isTrue);
    final mainTarget = pending.targets.singleWhere(
      (target) => target.owner == BackupOwner.mainData,
    );
    final targetData = AppData.decodeStorageSnapshot(
      jsonEncode(mainTarget.descriptor['target']),
    );
    final generation = targetData.applicationLedger!.generation;
    final fixedTargets = pending.targets
        .map((target) => target.fingerprint)
        .toList();
    expect(h.saved.applicationLedger!.generation, generation);
    expect(h.app.backups.selective.recoveryPending, isTrue);
    expect(h.app.session.canWrite, isFalse);
    expect(
      h.saved.generalMode.schedules.first.name,
      'Restored visible calendar',
    );
    expect(
      h.saved.generalMode.schedules.last.toJson(),
      before.generalMode.schedules.last.toJson(),
    );
    expect(h.saved.studentMode.toJson(), before.studentMode.toJson());
    expect(
      h.app.agent.knowledgeRepository.find('memory:restored-note'),
      isNull,
    );

    await h.app.lifecycle.retryStorageLoad();
    expect(await journal.read(), isNull);
    expect(h.app.backups.selective.recoveryPending, isFalse);
    expect(h.app.session.canWrite, isTrue);
    expect(h.saved.applicationLedger!.generation, generation);
    expect(
      h.saved.generalMode.schedules.first.name,
      'Restored visible calendar',
    );
    expect(
      h.saved.generalMode.schedules.last.toJson(),
      before.generalMode.schedules.last.toJson(),
    );
    expect(h.saved.studentMode.toJson(), before.studentMode.toJson());
    expect(
      h.app.agent.knowledgeRepository.find('memory:restored-note')!.body,
      'Synthetic content restored after the main phase.',
    );
    for (final state in journal.attempts) {
      expect(state.restoreId, restoreId);
      expect(state.planFingerprint, pending.planFingerprint);
      expect(
        state.targets.map((target) => target.fingerprint).toList(),
        fixedTargets,
      );
    }
    expect(result!['effectStatus'], 'unknown');
  });
}
