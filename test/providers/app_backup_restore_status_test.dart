import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/app_data_commit.dart'
    show AppDataCommit, AppDataDomain;
import 'package:sked/controllers/app_backup_controller.dart'
    show AppImportMode, WorkspaceChangeCancelledException;
import 'package:sked/controllers/app_data_maintenance.dart'
    show AppBackupRestoreInProgressException;

import '../support/workspace_harness.dart';

class _SaveGate {
  _SaveGate() {
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
  }

  final started = Completer<void>();
  final release = Completer<void>();
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  final gates = <_SaveGate>[];

  @override
  Future<void> save(AppData value) async {
    if (gates.isNotEmpty) {
      final gate = gates.removeAt(0);
      gate.started.complete();
      await gate.release.future;
    }
    await super.save(value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fails in [false, true]) {
    test(
      'restore status spans a ${fails ? 'failed' : 'successful'} transaction without emitting a commit',
      () async {
        final original = buildInitialAppData(buildDefaultPeriodTimes());
        final storage = _Storage(original);
        final provider = await workspaceProvider(storage: storage);
        addTearDown(provider.dispose);
        final states = [provider.maintenance.isReserved];
        final boundarySnapshots = <AppData>[];
        provider.maintenance.addListener(() {
          if (states.last != provider.maintenance.isReserved) {
            states.add(provider.maintenance.isReserved);
            boundarySnapshots.add(provider.workspaceView.data);
          }
        });
        final commits = <AppDataCommit>[];
        final subscription = provider.session.commits.listen(commits.add);
        addTearDown(subscription.cancel);
        final gate = _SaveGate();
        storage.gates.add(gate);
        if (fails) storage.saveError = StateError('disk full');
        final restoring = provider.backups.importJson(
          encodeAppBackup(
            original.copyWith(hideHomeWorkspaceNavigation: true),
            [],
          ),
          mode: AppImportMode.replaceAll,
        );
        final completion = fails
            ? expectLater(restoring, throwsStateError)
            : restoring;
        await gate.started.future;

        expect(states, [false, true]);
        expect(boundarySnapshots.single.toJson(), original.toJson());
        expect(provider.maintenance.isReserved, isTrue);
        expect(provider.session.committedData, same(original));
        expect(commits, isEmpty);
        await expectLater(
          provider.settingsCommands.updateLocaleCode('zh'),
          throwsA(isA<AppBackupRestoreInProgressException>()),
        );

        gate.release.complete();
        await completion;
        await Future<void>.delayed(Duration.zero);
        expect(states, [false, true, false]);
        expect(provider.maintenance.isReserved, isFalse);
        expect(provider.settingsView.hideHomeWorkspaceNavigation, !fails);
        expect(boundarySnapshots.last.hideHomeWorkspaceNavigation, !fails);
        expect(
          provider.session.committedData.hideHomeWorkspaceNavigation,
          !fails,
        );
        expect(commits, hasLength(fails ? 0 : 1));
        await provider.settingsCommands.updateLocaleCode('zh');
        expect(provider.settingsView.localeCode, 'zh');
      },
    );
  }

  test(
    'queued restores hold the status until the last lease is released',
    () async {
      final original = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _Storage(original);
      final provider = await workspaceProvider(storage: storage);
      addTearDown(provider.dispose);
      final states = [provider.maintenance.isReserved];
      provider.maintenance.addListener(() {
        if (states.last != provider.maintenance.isReserved) {
          states.add(provider.maintenance.isReserved);
        }
      });
      final firstGate = _SaveGate();
      final secondGate = _SaveGate();
      storage.gates.addAll([firstGate, secondGate]);
      final first = provider.backups.importJson(
        encodeAppBackup(original.copyWith(localeCode: 'zh'), []),
        mode: AppImportMode.replaceAll,
      );
      final second = provider.backups.importJson(
        encodeAppBackup(original.copyWith(localeCode: 'de'), []),
        mode: AppImportMode.replaceAll,
      );
      await firstGate.started.future;
      expect(states, [false, true]);
      firstGate.release.complete();
      await first;
      await secondGate.started.future;
      expect(provider.maintenance.isReserved, isTrue);
      expect(states, [false, true]);
      expect(provider.session.committedData.localeCode, 'zh');

      secondGate.release.complete();
      await second;
      expect(provider.settingsView.localeCode, 'de');
      expect(states, [false, true, false]);
    },
  );

  test('a declined draft guard does not start restore status', () async {
    final provider = await workspaceProvider();
    addTearDown(provider.dispose);
    final source = await provider.backups.exportJson();
    final unregister = provider.workspaces.registerExitGuard(
      AppMode.student,
      () async => false,
    );
    addTearDown(unregister);
    var notifications = 0;
    provider.maintenance.addListener(() => notifications++);
    await expectLater(
      provider.backups.importJson(source, mode: AppImportMode.replaceAll),
      throwsA(isA<WorkspaceChangeCancelledException>()),
    );
    expect(provider.maintenance.isReserved, isFalse);
    expect(notifications, 0);
  });

  test(
    'queued identical restores retain their own committed generations',
    () async {
      final original = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _Storage(original);
      final provider = await workspaceProvider(storage: storage);
      addTearDown(provider.dispose);
      final commits = <AppDataCommit>[];
      final subscription = provider.session.commits.listen(commits.add);
      addTearDown(subscription.cancel);
      final earlierSave = _SaveGate();
      final firstRestore = _SaveGate();
      final secondRestore = _SaveGate();
      storage.gates.addAll([earlierSave, firstRestore, secondRestore]);
      final saving = provider.generalCommands.updateDisplaySettings(
        showWeekends: false,
      );
      await earlierSave.started.future;
      final backup = encodeAppBackup(provider.workspaceView.data, []);
      final first = provider.backups.importJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      final second = provider.backups.importJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      expect(provider.maintenance.isReserved, isTrue);

      earlierSave.release.complete();
      await saving;
      await firstRestore.started.future;
      expect(commits, hasLength(1));
      expect(commits.single.affectsAgenda, isFalse);
      expect(commits.single.versions.dataSession, 0);

      firstRestore.release.complete();
      await first;
      await secondRestore.started.future;
      expect(commits, hasLength(2));
      expect(commits.last.changedDomains, {
        AppDataDomain.agenda,
        AppDataDomain.dataSession,
      });
      expect(commits.last.versions.dataSession, 1);

      secondRestore.release.complete();
      await second;
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(3));
      expect(commits.last.changedDomains, {
        AppDataDomain.agenda,
        AppDataDomain.dataSession,
      });
      expect(commits.last.versions.dataSession, 2);
      expect(commits.last.versions.agenda, 2);
    },
  );
}
