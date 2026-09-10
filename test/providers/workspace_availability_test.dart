import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/providers/workspace_theme_target.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

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
    final general = WorkspaceThemeTarget(p, AppMode.general);
    await general.updateThemeColorMode(themeColorModeColorful);
    final calendar = p.generalSchedules.first;
    await general.updateGeneralSchedule(
      calendar.copyWith(colorValue: 0xff123456),
    );
    final student = WorkspaceThemeTarget(p, AppMode.student);
    final courseName = p.timetables.expand((table) => table.courses).first.name;
    await student.updateCourseNameColorValue(courseName, 0xff654321);
    expect(p.activeMode, AppMode.student);
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
      final before = p.appData;
      final backup = encodeAppBackup(before, []);
      final unregister = p.registerWorkspaceExitGuard(
        AppMode.student,
        () async => false,
      );
      await expectLater(
        p.importAppDataJson(backup, mode: AppImportMode.replaceAll),
        throwsA(isA<WorkspaceChangeCancelledException>()),
      );
      expect(p.appData, same(before));
      unregister();
    },
  );
  test('native close flushes state but respects draft veto', () async {
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final unregister = p.registerWorkspaceExitGuard(
      AppMode.general,
      () async => false,
    );
    expect(await p.prepareForWindowClose(), isFalse);
    unregister();
    expect(await p.prepareForWindowClose(), isTrue);
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  test('full backup retains disabled data and restores its availability without secrets', () async {
    final p = await workspaceProvider(mode: AppMode.general);
    addTearDown(p.dispose);
    await p.updateCustomSchoolImportApiKey('never-in-a-backup');
    final student = p.studentMode.toJson();
    await p.setWorkspaceEnabled(AppMode.student, false);
    final backup = await p.exportAppDataJson();
    expect(backup, isNot(contains('never-in-a-backup')));
    expect(decodeAppBackup(backup).appData.enabledWorkspaces, {
      AppMode.general,
    });
    expect(decodeAppBackup(backup).appData.studentMode.toJson(), student);
    await p.setWorkspaceEnabled(AppMode.student, true);
    await p.updateThemeSeedColorValue(0xff123456, workspace: AppMode.student);
    await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
    expect(p.enabledWorkspaces, {AppMode.general});
    expect(p.activeMode, AppMode.general);
    expect(p.studentMode.toJson(), student);
    expect(p.customSchoolImportApiKey, isEmpty);
  });

  test(
    'backup cannot disable a workspace when its draft guard declines',
    () async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final backup = encodeAppBackup(
        p.appData.copyWith(
          enabledWorkspaces: {AppMode.general},
          activeMode: AppMode.general,
        ),
        [],
      );
      final unregister = p.registerWorkspaceExitGuard(
        AppMode.student,
        () async => false,
      );
      addTearDown(unregister);
      await expectLater(
        p.importAppDataJson(backup, mode: AppImportMode.replaceAll),
        throwsA(isA<WorkspaceChangeCancelledException>()),
      );
      expect(p.enabledWorkspaces, AppMode.values.toSet());
      expect(p.activeMode, AppMode.student);
    },
  );

  Future<(TimetableProvider, _Storage)> setup() async {
    final storage = _Storage();
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => 'en',
    );
    await provider.load();
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
      final operation = provider.setWorkspaceEnabled(AppMode.student, false);
      await Future<void>.delayed(Duration.zero);
      expect(provider.activeMode, AppMode.student);
      expect(provider.enabledWorkspaces, AppMode.values.toSet());
      storage.gate!.complete();
      await operation;
      expect(provider.activeMode, AppMode.general);
      expect(provider.enabledWorkspaces, {AppMode.general});
      await expectLater(provider.switchMode(AppMode.student), throwsStateError);
      await expectLater(
        provider.setWorkspaceEnabled(AppMode.general, false),
        throwsStateError,
      );
      await provider.setWorkspaceEnabled(AppMode.student, true);
      expect(provider.activeMode, AppMode.general);
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
      final original = provider.committedAppData;
      // An ordinary preference write is optimistic in AppRepository.current.
      final write = provider.updateThemeMode('dark');
      await Future<void>.delayed(Duration.zero);
      expect(provider.committedAppData, same(original));
      storage.gate!.complete();
      await write;
      expect(provider.committedAppData, same(storage.data));

      storage.gate = Completer<void>();
      final disable = provider.setWorkspaceEnabled(AppMode.student, false);
      await Future<void>.delayed(Duration.zero);
      expect(
        provider.committedAppData.enabledWorkspaces,
        AppMode.values.toSet(),
      );
      storage.gate!.complete();
      await disable;
      expect(provider.committedAppData.enabledWorkspaces, {AppMode.general});
    },
  );

  test('failed disable rolls back enabled state and active mode', () async {
    final (provider, storage) = await setup();
    storage.error = StateError('disk full');
    await expectLater(
      provider.setWorkspaceEnabled(AppMode.student, false),
      throwsStateError,
    );
    expect(provider.activeMode, AppMode.student);
    expect(provider.enabledWorkspaces, AppMode.values.toSet());
    expect(provider.committedAppData.enabledWorkspaces, AppMode.values.toSet());
    expect(storage.data.enabledWorkspaces, AppMode.values.toSet());
    await provider.setWorkspaceEnabled(AppMode.student, false);
    expect(provider.enabledWorkspaces, {AppMode.general});
  });
  test('serial requests cannot disable the last workspace', () async {
    final (provider, _) = await setup();
    final first = provider.setWorkspaceEnabled(AppMode.student, false);
    final second = provider.setWorkspaceEnabled(AppMode.general, false);
    await first;
    await expectLater(second, throwsStateError);
    expect(provider.enabledWorkspaces, {AppMode.general});
  });
}
