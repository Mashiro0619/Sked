import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/backup/selective_backup_codec.dart';
import 'package:sked/backup/selective_backup_device_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/device_preferences_store.dart';

import '../support/workspace_harness.dart';

Map<String, Object?> _layout(double width) => {
  'regions': {
    'assistant': {'width': width},
  },
};

SelectiveBackupBundle _source({
  DevicePreferencePlatform platform = DevicePreferencePlatform.windows,
  double width = 520,
  bool? preview = true,
}) {
  final records = buildDeviceBackupRecords(platform, {
    DevicePreferenceGroup.desktopLayout: _layout(width),
    DevicePreferenceGroup.developerUi: {'assistantPreviewEnabled': preview},
  });
  return SelectiveBackupBundle(
    records: records,
    roots: records.map((record) => record.key),
  );
}

const _layoutKey = BackupObjectKey(
  BackupObjectKind.deviceSettings,
  'windows.desktopLayout',
);
const _developerKey = BackupObjectKey(
  BackupObjectKind.deviceSettings,
  'windows.developerUi',
);

class _ObservedDeveloper extends DeveloperUiPreferences {
  _ObservedDeveloper({
    required super.read,
    required super.write,
    required super.remove,
  });
  final frozen = Completer<void>();
  @override
  Future<void> freezeAndDrainForRestore() {
    final result = super.freezeAndDrainForRestore();
    if (!frozen.isCompleted) frozen.complete();
    return result;
  }
}

class _DeviceDisk {
  Object? layout = jsonEncode({'version': 1, ..._layout(280)});
  bool? preview = false;
  int layoutWrites = 0, previewWrites = 0;
  bool failPreviewOnce = false, ignoreLayoutWrite = false;
  bool mutatePreviewAfterLayoutWrite = false;
  Completer<void>? previewGate;
  final previewStarted = Completer<void>();
  late DesktopLayoutPreferences layoutOwner;
  late _ObservedDeveloper developerOwner;

  DevicePreferencesStore open() {
    layoutOwner = DesktopLayoutPreferences(
      read: () async => layout,
      write: (value) async {
        layoutWrites++;
        if (!ignoreLayoutWrite) layout = value;
        if (mutatePreviewAfterLayoutWrite) preview = null;
        return true;
      },
      remove: () async {
        layoutWrites++;
        layout = null;
        return true;
      },
    );
    developerOwner = _ObservedDeveloper(
      read: () async => preview,
      write: (value) async {
        if (!previewStarted.isCompleted) previewStarted.complete();
        await previewGate?.future;
        if (failPreviewOnce) {
          failPreviewOnce = false;
          throw StateError(
            'Interrupted before the second device group was saved',
          );
        }
        previewWrites++;
        preview = value;
        return true;
      },
      remove: () async {
        previewWrites++;
        preview = null;
        return true;
      },
    );
    addTearDown(layoutOwner.dispose);
    addTearDown(developerOwner.dispose);
    return DevicePreferencesStore(
      layout: layoutOwner,
      developerUi: developerOwner,
      platform: DevicePreferencePlatform.windows,
    );
  }
}

class _LostDeviceStage extends MemorySelectiveRestoreJournal {
  bool fail = true;
  @override
  Future<void> write(SelectiveRestoreState state) async {
    if (fail && state.completed == 2) {
      fail = false;
      throw StateError('Lost the device-stage acknowledgement');
    }
    await super.write(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'portable device groups round-trip exact platforms and only known settings',
    () {
      expect(
        DesktopLayoutRegion.values.map((region) => region.name).toSet(),
        deviceLayoutRegionNames,
      );
      const codec = SelectiveBackupCodec();
      final source = _source();
      final decoded = codec.decode(codec.encode(source));
      expect(
        decoded.records.map((record) => record.toJson()),
        source.records.map((record) => record.toJson()),
      );
      expect(
        devicePreferencePlatform(decoded.records.first),
        DevicePreferencePlatform.windows,
      );
      expect(
        decoded.records.every(
          (record) => record.key.owner == BackupOwner.devicePreferences,
        ),
        isTrue,
      );
      final original = source.records.first.data;
      for (final invalid in [
        {...original, 'permission': 'granted'},
        {...original, 'platform': 'other'},
        {...original, 'group': 'nativePermissions'},
        {...original, 'version': 2},
        {
          ...original,
          'values': {
            'regions': {
              'unknown': {'width': 5},
            },
          },
        },
        {
          ...original,
          'values': {
            'regions': {
              'assistant': {'width': -1},
            },
          },
        },
        {
          ...original,
          'values': {
            'regions': {
              'assistant': {'path': 'private'},
            },
          },
        },
      ]) {
        expect(
          () => BackupRecord(key: _layoutKey, label: 'Device', data: invalid),
          throwsA(isA<SelectiveBackupException>()),
        );
      }
      expect(
        () => BackupRecord(
          key: _developerKey,
          label: 'Preview',
          data: {
            ...source.records.last.data,
            'values': {'assistantPreviewEnabled': 'yes'},
          },
        ),
        throwsA(isA<SelectiveBackupException>()),
      );
      expect(
        () =>
            BackupRecord(key: _developerKey, label: 'Mismatch', data: original),
        throwsA(isA<SelectiveBackupException>()),
      );
    },
  );

  test(
    'cross-platform groups remain visible but never mutate local data',
    () async {
      final devices = DevicePreferencesStore.memory(
        platform: DevicePreferencePlatform.android,
      );
      final runtime = await workspaceProvider(devicePreferences: devices);
      addTearDown(runtime.dispose);
      final source = _source();
      final before = runtime.session.committedData.toJson();
      final service = runtime.backups.selective;
      final plan = await service.prepareRestore(
        source,
        BackupSelection.all(source),
      );
      expect(plan.unsupportedGroups.map((record) => record.key), [
        _layoutKey,
        _developerKey,
      ]);
      expect(plan.changes, isEmpty);
      expect(plan.owners, isEmpty);
      await service.restore(plan);
      expect(runtime.session.committedData.toJson(), before);
      expect(await devices.readGroup(DevicePreferenceGroup.desktopLayout), {
        'regions': {},
      });
      expect(await devices.readGroup(DevicePreferenceGroup.developerUi), {
        'assistantPreviewEnabled': false,
      });
      expect(await service.journal.read(), isNull);
    },
  );

  test(
    'an unsupported group is reported even when the UI leaves it unchecked',
    () {
      final source = _source();
      final current = _source(platform: DevicePreferencePlatform.android);
      final plan = const SelectiveBackupPlanner().prepare(
        source: source,
        current: current,
        selection: BackupSelection(),
      );
      expect(plan.unsupportedGroups, hasLength(2));
      expect(plan.changes, isEmpty);
    },
  );

  test(
    'selecting one device group persists it and never writes the other group',
    () async {
      final disk = _DeviceDisk();
      final devices = disk.open();
      final runtime = await workspaceProvider(devicePreferences: devices);
      addTearDown(runtime.dispose);
      final service = runtime.backups.selective;
      final plan = await service.prepareRestore(
        _source(),
        BackupSelection(objects: const [_layoutKey]),
      );
      await service.restore(plan);
      expect(disk.layoutWrites, 1);
      expect(disk.previewWrites, 0);
      expect(disk.preview, isFalse);
      expect(
        devices.layout.preferenceFor(DesktopLayoutRegion.assistant)?.width,
        520,
      );
      expect(
        runtime.session.committedData.applicationLedger!.generation,
        plan.dataGeneration,
      );
      expect(service.recoveryPending, isFalse);
    },
  );

  test(
    'unknown stored device fields fail preflight without admitting a restore',
    () async {
      final disk = _DeviceDisk()
        ..layout = jsonEncode({
          'version': 1,
          'regions': {
            'unknownRole': {'width': 25},
          },
        });
      final runtime = await workspaceProvider(devicePreferences: disk.open());
      addTearDown(runtime.dispose);
      final service = runtime.backups.selective;
      await expectLater(
        service.prepareRestore(
          _source(),
          BackupSelection(objects: const [_layoutKey]),
        ),
        throwsFormatException,
      );
      expect([disk.layoutWrites, disk.previewWrites], [0, 0]);
      expect(await service.journal.read(), isNull);
      expect(runtime.session.canWrite, isTrue);
    },
  );

  test('an accepted unselected preference save is drained before journal admission', () async {
    final disk = _DeviceDisk();
    final devices = disk.open();
    final runtime = await workspaceProvider(devicePreferences: devices);
    addTearDown(runtime.dispose);
    final service = runtime.backups.selective;
    final plan = await service.prepareRestore(
      _source(),
      BackupSelection(objects: const [_layoutKey]),
    );
    await devices.developerUi.load();
    disk.previewGate = Completer<void>();
    final save = devices.developerUi.setAssistantVisible(true);
    await disk.previewStarted.future;
    final restore = service.restore(plan);
    await disk.developerOwner.frozen.future;
    expect(await service.journal.read(), isNull);
    expect(disk.layoutWrites, 0);
    expect(await devices.developerUi.setAssistantVisible(false), isFalse);
    disk.previewGate!.complete();
    expect(await save, isTrue);
    await restore;
    expect(disk.preview, isTrue);
    expect(disk.previewWrites, 1);
    expect(disk.layoutWrites, 1);
  });

  test('restart continues a partially saved device participant using its fixed groups', () async {
    final disk = _DeviceDisk()..failPreviewOnce = true;
    final storage = WorkspaceMemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final journal = MemorySelectiveRestoreJournal();
    debugSetSelectiveRestoreJournalFactory(() => journal);
    final runtime = await workspaceProvider(
      storage: storage,
      devicePreferences: disk.open(),
    );
    final service = runtime.backups.selective;
    final source = _source();
    final plan = await service.prepareRestore(
      source,
      BackupSelection.all(source),
    );
    await expectLater(service.restore(plan), throwsStateError);
    expect(service.recoveryPending, isTrue);
    expect(runtime.session.canWrite, isFalse);
    expect(disk.layoutWrites, 1);
    expect(disk.previewWrites, 0);
    final admitted = await journal.read();
    expect(admitted!.targets.map((target) => target.owner), [
      BackupOwner.mainData,
      BackupOwner.devicePreferences,
    ]);
    runtime.dispose();
    await service.close();
    final restarted = await workspaceProvider(
      storage: storage,
      devicePreferences: disk.open(),
    );
    addTearDown(restarted.dispose);
    expect(restarted.backups.selective.recoveryPending, isFalse);
    expect(restarted.session.canWrite, isTrue);
    expect(
      restarted.session.committedData.applicationLedger!.generation,
      plan.dataGeneration,
    );
    expect(disk.layoutWrites, 1);
    expect(disk.previewWrites, 1);
    expect(disk.preview, isTrue);
    expect(await journal.read(), isNull);
  });

  test('an unexpected later device-group change is never overwritten after an earlier group commits', () async {
    final disk = _DeviceDisk()..mutatePreviewAfterLayoutWrite = true;
    final runtime = await workspaceProvider(devicePreferences: disk.open());
    addTearDown(runtime.dispose);
    final service = runtime.backups.selective;
    final source = _source();
    final plan = await service.prepareRestore(
      source,
      BackupSelection.all(source),
    );
    final conflict = throwsA(
      isA<SelectiveBackupException>().having(
        (error) => error.code,
        'code',
        SelectiveBackupError.conflict,
      ),
    );
    await expectLater(service.restore(plan), conflict);
    expect(disk.preview, isNull);
    expect(disk.previewWrites, 0);
    expect(service.recoveryPending, isTrue);
    await expectLater(service.resume(), conflict);
    expect([disk.layoutWrites, disk.previewWrites], [1, 0]);
  });

  test('lost stage acknowledgement rereads both device stores instead of writing again', () async {
    final disk = _DeviceDisk();
    final journal = _LostDeviceStage();
    debugSetSelectiveRestoreJournalFactory(() => journal);
    final runtime = await workspaceProvider(devicePreferences: disk.open());
    addTearDown(runtime.dispose);
    final service = runtime.backups.selective;
    final source = _source();
    final plan = await service.prepareRestore(
      source,
      BackupSelection.all(source),
    );
    await expectLater(service.restore(plan), throwsStateError);
    expect([disk.layoutWrites, disk.previewWrites], [1, 1]);
    await service.resume();
    expect([disk.layoutWrites, disk.previewWrites], [1, 1]);
    expect(await journal.read(), isNull);
  });

  test(
    'a claimed save without persistent readback cannot complete the restore',
    () async {
      final disk = _DeviceDisk()..ignoreLayoutWrite = true;
      final runtime = await workspaceProvider(devicePreferences: disk.open());
      addTearDown(runtime.dispose);
      final service = runtime.backups.selective;
      final plan = await service.prepareRestore(
        _source(),
        BackupSelection(objects: const [_layoutKey]),
      );
      await expectLater(service.restore(plan), throwsStateError);
      expect(service.recoveryPending, isTrue);
      expect(runtime.session.canWrite, isFalse);
      expect((await service.journal.read())!.isComplete, isFalse);
      disk.ignoreLayoutWrite = false;
      await service.resume();
      expect(service.recoveryPending, isFalse);
      expect(disk.layoutWrites, 2);
      expect(disk.previewWrites, 0);
    },
  );

  test('SharedPreferences values reopen after restoring both groups and explicit defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final devices = DevicePreferencesStore(
      platform: DevicePreferencePlatform.windows,
    );
    final runtime = await workspaceProvider(devicePreferences: devices);
    addTearDown(runtime.dispose);
    final service = runtime.backups.selective;
    final source = _source();
    await service.restore(
      await service.prepareRestore(source, BackupSelection.all(source)),
    );
    final reopened = DevicePreferencesStore(
      platform: DevicePreferencePlatform.windows,
    );
    addTearDown(reopened.dispose);
    expect(
      await reopened.readGroup(DevicePreferenceGroup.desktopLayout),
      _layout(520),
    );
    expect(await reopened.readGroup(DevicePreferenceGroup.developerUi), {
      'assistantPreviewEnabled': true,
    });
    final reset = SelectiveBackupBundle(
      roots: const [_layoutKey, _developerKey],
      records: buildDeviceBackupRecords(DevicePreferencePlatform.windows, {
        DevicePreferenceGroup.desktopLayout: {'regions': {}},
        DevicePreferenceGroup.developerUi: {'assistantPreviewEnabled': null},
      }),
    );
    await service.restore(
      await service.prepareRestore(reset, BackupSelection.all(reset)),
    );
    final stored = await SharedPreferences.getInstance();
    expect(stored.containsKey(DesktopLayoutPreferences.storageKey), isFalse);
    expect(stored.containsKey(DeveloperUiPreferences.storageKey), isFalse);
  });
}
