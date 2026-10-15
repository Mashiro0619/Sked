import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/app_data_commit.dart'
    show AppDataCommit, AppDataDomain;

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData? data;
  Object? nextError;
  Future<void> Function()? beforeNextSave;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    final gate = beforeNextSave;
    beforeNextSave = null;
    await gate?.call();
    saveCount += 1;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://committed-data';
}

void main() {
  test(
    'emits a revision only after a successful persisted data save',
    () async {
      final storage = _MemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = AppRuntime(
        storage: storage,
        systemLocaleCodeResolver: () => 'en',
        uiStateSaveDelay: Duration.zero,
      );
      addTearDown(provider.dispose);
      final commits = <AppDataCommit>[];
      final subscription = provider.session.commits.listen(commits.add);
      addTearDown(subscription.cancel);

      await provider.lifecycle.load();
      expect(commits, isEmpty);

      await provider.generalCommands.updateDisplaySettings(showWeekends: false);
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));
      expect(commits.single.revision, 1);
      expect(commits.single.snapshot.generalMode.showWeekends, isFalse);
      expect(commits.single.data, same(commits.single.snapshot));
      expect(commits.single.changedDomains, {AppDataDomain.general});
      expect(commits.single.versions.general, 1);
      expect(commits.single.versions.agenda, 0);
      expect(commits.single.affectsAgenda, isFalse);

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 8, 3));
      await provider.persistence.flushPendingUiStateSaves();
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));

      storage.nextError = StateError('write failed');
      await expectLater(
        provider.generalCommands.updateDisplaySettings(showWeekends: true),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));
      expect(provider.session.versions.general, 1);
      expect(provider.session.versions.agenda, 0);
    },
  );

  test('queued saves compare consecutive durable snapshots', () async {
    final storage = _MemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = AppRuntime(
      storage: storage,
      systemLocaleCodeResolver: () => 'en',
    );
    addTearDown(provider.dispose);
    await provider.lifecycle.load();
    final commits = <AppDataCommit>[];
    final subscription = provider.session.commits.listen(commits.add);
    addTearDown(subscription.cancel);
    final started = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    storage.beforeNextSave = () async {
      started.complete();
      await release.future;
    };

    final notificationSave = provider.settingsCommands
        .updateNotificationsEnabled(true);
    await started.future;
    final themeSave = provider.settingsCommands.updateThemeMode(
      'dark',
      workspace: AppMode.student,
    );
    expect(commits, isEmpty);
    expect(provider.session.versions.agenda, 0);
    release.complete();
    await Future.wait([notificationSave, themeSave]);
    await Future<void>.delayed(Duration.zero);

    expect(commits, hasLength(2));
    expect(commits.first.changedDomains, {
      AppDataDomain.settings,
      AppDataDomain.agenda,
    });
    expect(commits.last.changedDomains, {AppDataDomain.student});
    expect(commits.map((commit) => commit.versions.agenda), [1, 1]);
    expect(commits.map((commit) => commit.revision), [1, 2]);
    expect(storage.data!.notificationSettings.enabled, isTrue);
    expect(storage.data!.studentMode.themeMode, 'dark');
  });

  test('closing the provider closes committed stream', () async {
    final provider = AppRuntime(
      storage: _MemoryStorage(buildInitialAppData(buildDefaultPeriodTimes())),
      systemLocaleCodeResolver: () => 'en',
    );
    final done = Completer<void>();
    provider.session.commits.listen((_) {}, onDone: done.complete);
    provider.dispose();
    await expectLater(done.future, completes);
  });

  test('an uncertain save does not advance agenda versions or the durable baseline', () async {
    final storage = _MemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = AppRuntime(
      storage: storage,
      systemLocaleCodeResolver: () => 'en',
    );
    addTearDown(provider.dispose);
    await provider.lifecycle.load();
    final commits = <AppDataCommit>[];
    final subscription = provider.session.commits.listen(commits.add);
    addTearDown(subscription.cancel);
    storage.nextError = StorageWriteStateUnknownException(
      writeError: StateError('write result unknown'),
      rollbackError: StateError('rollback result unknown'),
      recoveryArtifacts: const ['memory://recoverable-snapshot'],
    );
    await expectLater(
      provider.settingsCommands.updateNotificationsEnabled(true),
      throwsA(isA<StorageWriteStateUnknownException>()),
    );
    expect(provider.session.canWrite, isFalse);
    expect(provider.lifecycle.isStorageWriteStateUnknown, isTrue);
    expect(provider.session.versions.agenda, 0);
    expect(commits, isEmpty);

    await provider.lifecycle.retryStorageLoad();
    await provider.settingsCommands.updateIncludePrereleaseUpdates(
      !provider.settingsView.includePrereleaseUpdates,
    );
    await Future<void>.delayed(Duration.zero);
    expect(commits, hasLength(1));
    expect(commits.single.changedDomains, {AppDataDomain.settings});
    expect(commits.single.versions.agenda, 0);
    expect(commits.single.snapshot.notificationSettings.enabled, isFalse);
  });

  test('load emits the durable normalized snapshot after write-back', () async {
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    final storage = _MemoryStorage(
      AppData(
        activeMode: initial.activeMode,
        studentMode: initial.studentMode.copyWith(
          periodTimeSets: const [
            PeriodTimeSet(
              id: ' padded-period-set ',
              name: ' Padded period set ',
              periodTimes: [
                CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
              ],
            ),
          ],
        ),
        generalMode: initial.generalMode,
        localeCode: initial.localeCode,
      ),
    );
    final provider = AppRuntime(
      storage: storage,
      systemLocaleCodeResolver: () => 'en',
    );
    addTearDown(provider.dispose);
    final commits = <AppDataCommit>[];
    final subscription = provider.session.commits.listen(commits.add);
    addTearDown(subscription.cancel);

    await provider.lifecycle.load();
    await Future<void>.delayed(Duration.zero);

    expect(storage.saveCount, 1);
    expect(provider.workspaceView.data, same(storage.data));
    expect(
      provider.workspaceView.data.studentMode.periodTimeSets.single.id,
      'padded-period-set',
    );
    expect(commits, hasLength(1));
    expect(commits.single.revision, 1);
    expect(commits.single.snapshot, same(provider.workspaceView.data));
  });
}
