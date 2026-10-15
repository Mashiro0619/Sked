import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/providers/workspace_theme_target.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart'
    show AppImportMode, WorkspaceChangeCancelledException;

import '../support/workspace_harness.dart';

class _Storage implements TimetableStorage {
  AppData data = buildInitialAppData(buildDefaultPeriodTimes());
  Object? error;
  Completer<void>? gate;
  @override
  Future<String?> filePath() async => 'memory://workspaces';
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData next) async {
    await gate?.future;
    if (error != null) {
      final failure = error!;
      error = null;
      throw failure;
    }
    data = next;
  }
}

void main() {
  test('explicit theme target writes colors without switching the current workspace', () async {
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final general = WorkspaceThemeTarget(
      settings: p.settingsView,
      settingsCommands: p.settingsCommands,
      general: p.generalView,
      generalCommands: p.generalCommands,
      activeMode: AppMode.general,
    );
    await general.updateThemeColorMode(themeColorModeColorful);
    final calendar = p.generalView.schedules.first;
    await general.updateGeneralScheduleColor(calendar.id, 0xff123456);
    final student = WorkspaceThemeTarget(
      settings: p.settingsView,
      settingsCommands: p.settingsCommands,
      general: p.generalView,
      generalCommands: p.generalCommands,
      activeMode: AppMode.student,
    );
    final courseName = p.studentView.timetables
        .expand((table) => table.courses)
        .first
        .name;
    await student.updateCourseNameColorValue(courseName, 0xff654321);
    expect(p.workspaceView.activeMode, AppMode.student);
    expect(general.themeColorMode, themeColorModeColorful);
    expect(general.generalSchedules.first.colorValue, 0xff123456);
    expect(
      student.courseNameColorValues[normalizeCourseColorName(courseName)],
      0xff654321,
    );
  });

  test(
    'full replacement protects drafts in workspaces that remain enabled',
    () async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final before = p.workspaceView.data;
      final backup = encodeAppBackup(before, []);
      final unregister = p.workspaces.registerExitGuard(
        AppMode.student,
        () async => false,
      );
      await expectLater(
        p.backups.importJson(backup, mode: AppImportMode.replaceAll),
        throwsA(isA<WorkspaceChangeCancelledException>()),
      );
      expect(p.workspaceView.data, same(before));
      unregister();
    },
  );
  test('native close flushes state but respects draft veto', () async {
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final unregister = p.workspaces.registerExitGuard(
      AppMode.general,
      () async => false,
    );
    expect(await p.shutdown.prepareForWindowClose(), isFalse);
    unregister();
    expect(await p.shutdown.prepareForWindowClose(), isTrue);
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  test('full backup retains disabled data and restores its availability without secrets', () async {
    final p = await workspaceProvider(mode: AppMode.general);
    addTearDown(p.dispose);
    await p.schoolImportSecrets.update('never-in-a-backup');
    final student = p.studentView.data.toJson();
    await p.workspaces.setEnabled(AppMode.student, false);
    final backup = await p.backups.exportJson();
    expect(backup, isNot(contains('never-in-a-backup')));
    expect(decodeAppBackup(backup).appData.enabledWorkspaces, {
      AppMode.general,
    });
    expect(decodeAppBackup(backup).appData.studentMode.toJson(), student);
    await p.workspaces.setEnabled(AppMode.student, true);
    await p.settingsCommands.updateThemeSeedColorValue(
      0xff123456,
      workspace: AppMode.student,
    );
    await p.backups.importJson(backup, mode: AppImportMode.replaceAll);
    expect(p.workspaceView.enabledWorkspaces, {AppMode.general});
    expect(p.workspaceView.activeMode, AppMode.general);
    expect(p.studentView.data.toJson(), student);
    expect(p.settingsView.customSchoolImportApiKey, isEmpty);
  });

  test(
    'backup cannot disable a workspace when its draft guard declines',
    () async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final backup = encodeAppBackup(
        p.workspaceView.data.copyWith(
          enabledWorkspaces: {AppMode.general},
          activeMode: AppMode.general,
        ),
        [],
      );
      final unregister = p.workspaces.registerExitGuard(
        AppMode.student,
        () async => false,
      );
      addTearDown(unregister);
      await expectLater(
        p.backups.importJson(backup, mode: AppImportMode.replaceAll),
        throwsA(isA<WorkspaceChangeCancelledException>()),
      );
      expect(p.workspaceView.enabledWorkspaces, AppMode.values.toSet());
      expect(p.workspaceView.activeMode, AppMode.student);
    },
  );

  Future<(AppRuntime, _Storage)> setup() async {
    final storage = _Storage();
    final provider = AppRuntime(
      storage: storage,
      systemLocaleCodeResolver: () => 'en',
    );
    await provider.lifecycle.load();
    addTearDown(provider.dispose);
    return (provider, storage);
  }

  test(
    'disable switches atomically and re-enable preserves both workspaces',
    () async {
      final (provider, storage) = await setup();
      final student = storage.data.studentMode.toJson();
      final general = storage.data.generalMode.toJson();
      storage.gate = Completer<void>();
      final operation = provider.workspaces.setEnabled(AppMode.student, false);
      await Future<void>.delayed(Duration.zero);
      expect(provider.workspaceView.activeMode, AppMode.student);
      expect(provider.workspaceView.enabledWorkspaces, AppMode.values.toSet());
      storage.gate!.complete();
      await operation;
      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.workspaceView.enabledWorkspaces, {AppMode.general});
      await expectLater(
        provider.workspaces.switchMode(AppMode.student),
        throwsStateError,
      );
      await expectLater(
        provider.workspaces.setEnabled(AppMode.general, false),
        throwsStateError,
      );
      await provider.workspaces.setEnabled(AppMode.student, true);
      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(storage.data.studentMode.toJson(), student);
      expect(storage.data.generalMode.toJson(), general);
      expect(
        storage.data.workspaceReminderNotBefore[AppMode.student],
        isNotNull,
      );
    },
  );
  test(
    'durable reader excludes queued availability and ordinary writes',
    () async {
      final (provider, storage) = await setup();
      storage.gate = Completer<void>();
      final original = provider.session.committedData;
      // An ordinary preference write is optimistic in AppRepository.current.
      final write = provider.settingsCommands.updateThemeMode('dark');
      await Future<void>.delayed(Duration.zero);
      expect(provider.session.committedData, same(original));
      storage.gate!.complete();
      await write;
      expect(provider.session.committedData, same(storage.data));

      storage.gate = Completer<void>();
      final disable = provider.workspaces.setEnabled(AppMode.student, false);
      await Future<void>.delayed(Duration.zero);
      expect(
        provider.session.committedData.enabledWorkspaces,
        AppMode.values.toSet(),
      );
      storage.gate!.complete();
      await disable;
      expect(provider.session.committedData.enabledWorkspaces, {
        AppMode.general,
      });
    },
  );

  test('failed disable rolls back enabled state and active mode', () async {
    final (provider, storage) = await setup();
    storage.error = StateError('disk full');
    await expectLater(
      provider.workspaces.setEnabled(AppMode.student, false),
      throwsStateError,
    );
    expect(provider.workspaceView.activeMode, AppMode.student);
    expect(provider.workspaceView.enabledWorkspaces, AppMode.values.toSet());
    expect(
      provider.session.committedData.enabledWorkspaces,
      AppMode.values.toSet(),
    );
    expect(storage.data.enabledWorkspaces, AppMode.values.toSet());
    await provider.workspaces.setEnabled(AppMode.student, false);
    expect(provider.workspaceView.enabledWorkspaces, {AppMode.general});
  });
  test('serial requests cannot disable the last workspace', () async {
    final (provider, _) = await setup();
    final first = provider.workspaces.setEnabled(AppMode.student, false);
    final second = provider.workspaces.setEnabled(AppMode.general, false);
    await first;
    await expectLater(second, throwsStateError);
    expect(provider.workspaceView.enabledWorkspaces, {AppMode.general});
  });
}
