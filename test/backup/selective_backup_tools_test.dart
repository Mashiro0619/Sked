import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_backup_codec.dart';
import 'package:sked/backup/selective_backup_device_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
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
  setUp(() async {
    h = AcceptanceHarness();
    blobs = _ControlledReadStorage();
    await h.initialize(attachmentStorage: blobs);
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
}
