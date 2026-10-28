import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/app_data_commit.dart';
import 'package:sked/models/app_preference_write.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/settings_service.dart';

import '../support/timetable_storage_fakes.dart';

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  final writes = <AppData>[];
  Future<void> Function()? beforeSave;

  @override
  Future<void> save(AppData value) async {
    await beforeSave?.call();
    await super.save(value);
    writes.add(value);
  }
}

class _ExtendedSettingsService extends SettingsService {
  @override
  AppData updateLocaleCode(AppData data, String localeCode) => super
      .updateLocaleCode(data, localeCode)
      .copyWith(ignoredUpdateVersion: 'custom');
}

Future<AppRuntime> _open(_Storage storage, {SettingsService? service}) async {
  final runtime = AppRuntime(
    storage: storage,
    systemLocaleCodeResolver: () => 'en',
    settingsService: service,
  );
  addTearDown(runtime.dispose);
  await runtime.lifecycle.load();
  return runtime;
}

List<AppDataCommit> _observe(AppRuntime runtime) {
  final commits = <AppDataCommit>[];
  final subscription = runtime.session.commits.listen(commits.add);
  addTearDown(subscription.cancel);
  return commits;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'five real preference commands complete after one write and publish once',
    () async {
      final storage = _Storage(
        buildInitialAppData(buildDefaultPeriodTimes())
            .copyWith(availableUpdateVersion: '3.0.0-beta'),
      );
      final runtime = await _open(storage);
      final commits = _observe(runtime);
      final started = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      storage.beforeSave = () async {
        started.complete();
        await release.future;
      };
      var completed = 0;
      final saves =
          [
                runtime.settingsCommands.updateLocaleCode('zh'),
                runtime.settingsCommands.updateIncludePrereleaseUpdates(false),
                runtime.settingsCommands.updateHideHomeWorkspaceNavigation(
                  true,
                ),
                runtime.settingsCommands.updateHomeWorkspaceNavigationCollapsed(
                  true,
                ),
                runtime.settingsCommands.updateWorkspacePanelDisplayMode(
                  WorkspacePanelDisplayMode.sideBySide,
                ),
              ]
              .map(
                (save) => save.then((_) {
                  completed += 1;
                }),
              )
              .toList();
      await started.future;
      expect(completed, 0);
      expect(commits, isEmpty);
      expect(storage.writes, isEmpty);
      expect(storage.data.availableUpdateVersion, '3.0.0-beta');
      release.complete();
      await Future.wait(saves);
      await Future<void>.delayed(Duration.zero);
      expect(completed, 5);
      expect(storage.writes, hasLength(1));
      expect(commits, hasLength(1));
      expect(commits.single.snapshot, same(storage.data));
      expect(storage.data.localeCode, 'zh');
      expect(storage.data.includePrereleaseUpdates, isFalse);
      expect(storage.data.availableUpdateVersion, isNull);
      expect(storage.data.hideHomeWorkspaceNavigation, isTrue);
      expect(storage.data.homeWorkspaceNavigationCollapsed, isTrue);
      expect(
        storage.data.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.sideBySide,
      );
    },
  );

  test(
    'failed preference batch restores the whole session and emits no commit',
    () async {
      final storage = _Storage(buildInitialAppData(buildDefaultPeriodTimes()));
      final runtime = await _open(storage);
      final initial = runtime.session.data;
      final commits = _observe(runtime);
      const failure = StorageWriteException('disk unavailable');
      storage.saveError = failure;
      await Future.wait([
        expectLater(
          runtime.settingsCommands.updateLocaleCode('zh'),
          throwsA(same(failure)),
        ),
        expectLater(
          runtime.settingsCommands.updateHideHomeWorkspaceNavigation(true),
          throwsA(same(failure)),
        ),
      ]);
      expect(runtime.session.data.toJson(), initial.toJson());
      expect(storage.data.toJson(), initial.toJson());
      expect(runtime.session.canWrite, isFalse);
      expect(commits, isEmpty);
      await runtime.lifecycle.retryStorageLoad();
      await runtime.settingsCommands.updateLocaleCode('zh');
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));
      expect(commits.single.snapshot.localeCode, 'zh');
    },
  );

  for (final publish in [(false, true), (true, false), (false, false)]) {
    test('shared receipt respects publish flags $publish', () async {
      final storage = _Storage(buildInitialAppData(buildDefaultPeriodTimes()));
      final runtime = await _open(storage);
      final commits = _observe(runtime);
      final first = AppPreferenceWrite.tryCreate(
        before: runtime.session.data,
        snapshot: runtime.session.data.copyWith(localeCode: 'zh'),
        command: AppPreferenceCommand.locale,
      )!;
      final second = AppPreferenceWrite.tryCreate(
        before: first.snapshot,
        snapshot: first.snapshot.copyWith(hideHomeWorkspaceNavigation: true),
        command: AppPreferenceCommand.homeNavigationVisibility,
      )!;
      final context = runtime.session.repository.captureWriteContext(
        dataSessionRevision: 0,
      );
      runtime.session.replaceData(first.snapshot);
      final firstSave = runtime.session.persist(
        first.snapshot,
        publish: publish.$1,
        preferenceWrite: first,
        writeContext: context,
      );
      runtime.session.replaceData(second.snapshot);
      final secondSave = runtime.session.persist(
        second.snapshot,
        publish: publish.$2,
        preferenceWrite: second,
        writeContext: context,
      );
      await Future.wait([firstSave, secondSave]);
      await Future<void>.delayed(Duration.zero);
      expect(storage.writes, hasLength(1));
      expect(commits, hasLength(publish.$1 || publish.$2 ? 1 : 0));
      if (commits.isNotEmpty) {
        expect(commits.single.snapshot, same(second.snapshot));
      }
    });
  }

  test('flush and maintenance settle older silent writes before publishing a new session', () async {
    final storage = _Storage(buildInitialAppData(buildDefaultPeriodTimes()));
    final runtime = await _open(storage);
    final commits = _observe(runtime);
    final started = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    storage.beforeSave = () async {
      storage.beforeSave = null;
      started.complete();
      await release.future;
    };
    runtime.session.replaceData(
      runtime.session.data.copyWith(ignoredUpdateVersion: 'silent'),
    );
    final silentSave = runtime.persistence.save(emitCommit: false);
    await started.future;
    final localeSave = runtime.settingsCommands.updateLocaleCode('zh');
    final hiddenSave = runtime.settingsCommands
        .updateHideHomeWorkspaceNavigation(true);
    final token = runtime.maintenance.reserve();
    final restore = runtime.maintenance.runWithLease(token, () async {
      runtime.session.replaceData(
        runtime.session.data.copyWith(
          localeCode: 'en',
          ignoredUpdateVersion: 'restored',
        ),
      );
      await runtime.persistence.saveAndNotify();
    });
    release.complete();
    try {
      await Future.wait([silentSave, localeSave, hiddenSave, restore]);
    } finally {
      runtime.maintenance.release(token);
    }
    await runtime.persistence.flushPendingUiStateSaves();
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, hasLength(3));
    expect(commits, hasLength(2));
    expect(commits.first.snapshot.localeCode, 'zh');
    expect(commits.last.snapshot.localeCode, 'en');
    expect(commits.last.snapshot.ignoredUpdateVersion, 'restored');
    expect(commits.last.snapshot, same(storage.data));
    expect(commits.map((commit) => commit.revision), [1, 2]);
    await runtime.lifecycle.retryStorageLoad();
    await runtime.settingsCommands.updateLocaleCode('zh');
    await Future<void>.delayed(Duration.zero);
    expect(commits, hasLength(3));
    expect(commits.last.revision, 3);
    expect(commits.last.snapshot, same(storage.data));
  });

  test(
    'flush and a custom service retain independent complete writes',
    () async {
      final storage = _Storage(buildInitialAppData(buildDefaultPeriodTimes()));
      final runtime = await _open(storage, service: _ExtendedSettingsService());
      final first = runtime.settingsCommands.updateHideHomeWorkspaceNavigation(
        true,
      );
      final custom = runtime.settingsCommands.updateLocaleCode('zh');
      final last = runtime.settingsCommands
          .updateHomeWorkspaceNavigationCollapsed(true);
      await Future.wait([first, custom, last]);
      expect(storage.writes, hasLength(3));
      expect(storage.data.ignoredUpdateVersion, 'custom');
      final next = runtime.settingsCommands.updateHideHomeWorkspaceNavigation(
        false,
      );
      final flush = runtime.persistence.flushPendingUiStateSaves();
      final finalSave = runtime.settingsCommands
          .updateHomeWorkspaceNavigationCollapsed(false);
      await Future.wait([next, flush, finalSave]);
      expect(storage.writes, hasLength(5));
    },
  );
}
