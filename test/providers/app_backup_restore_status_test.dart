import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

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
        final states = [provider.isRestoringAppBackup];
        final boundarySnapshots = <AppData>[];
        provider.maintenance.addListener(() {
          if (states.last != provider.isRestoringAppBackup) {
            states.add(provider.isRestoringAppBackup);
            boundarySnapshots.add(provider.appData);
          }
        });
        final commits = <AppDataCommit>[];
        final subscription = provider.committedData.listen(commits.add);
        addTearDown(subscription.cancel);
        final gate = _SaveGate();
        storage.gates.add(gate);
        if (fails) storage.saveError = StateError('disk full');
        final restoring = provider.importAppDataJson(
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
        expect(provider.isRestoringAppBackup, isTrue);
        expect(provider.committedAppData, same(original));
        expect(commits, isEmpty);
        await expectLater(
          provider.updateLocaleCode('zh'),
          throwsA(isA<AppBackupRestoreInProgressException>()),
        );

        gate.release.complete();
        await completion;
        await Future<void>.delayed(Duration.zero);
        expect(states, [false, true, false]);
        expect(provider.isRestoringAppBackup, isFalse);
        expect(provider.hideHomeWorkspaceNavigation, !fails);
        expect(boundarySnapshots.last.hideHomeWorkspaceNavigation, !fails);
        expect(provider.committedAppData.hideHomeWorkspaceNavigation, !fails);
        expect(commits, hasLength(fails ? 0 : 1));
        await provider.updateLocaleCode('zh');
        expect(provider.localeCode, 'zh');
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
      final states = [provider.isRestoringAppBackup];
      provider.maintenance.addListener(() {
        if (states.last != provider.isRestoringAppBackup) {
          states.add(provider.isRestoringAppBackup);
        }
      });
      final firstGate = _SaveGate();
      final secondGate = _SaveGate();
      storage.gates.addAll([firstGate, secondGate]);
      final first = provider.importAppDataJson(
        encodeAppBackup(original.copyWith(localeCode: 'zh'), []),
        mode: AppImportMode.replaceAll,
      );
      final second = provider.importAppDataJson(
        encodeAppBackup(original.copyWith(localeCode: 'de'), []),
        mode: AppImportMode.replaceAll,
      );
      await firstGate.started.future;
      expect(states, [false, true]);
      firstGate.release.complete();
      await first;
      await secondGate.started.future;
      expect(provider.isRestoringAppBackup, isTrue);
      expect(states, [false, true]);
      expect(provider.committedAppData.localeCode, 'zh');

      secondGate.release.complete();
      await second;
      expect(provider.localeCode, 'de');
      expect(states, [false, true, false]);
    },
  );

  test('a declined draft guard does not start restore status', () async {
    final provider = await workspaceProvider();
    addTearDown(provider.dispose);
    final source = await provider.exportAppDataJson();
    final unregister = provider.registerWorkspaceExitGuard(
      AppMode.student,
      () async => false,
    );
    addTearDown(unregister);
    var notifications = 0;
    provider.maintenance.addListener(() => notifications++);
    await expectLater(
      provider.importAppDataJson(source, mode: AppImportMode.replaceAll),
      throwsA(isA<WorkspaceChangeCancelledException>()),
    );
    expect(provider.isRestoringAppBackup, isFalse);
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
      final subscription = provider.committedData.listen(commits.add);
      addTearDown(subscription.cancel);
      final earlierSave = _SaveGate();
      final firstRestore = _SaveGate();
      final secondRestore = _SaveGate();
      storage.gates.addAll([earlierSave, firstRestore, secondRestore]);
      final saving = provider.updateGeneralDisplaySettings(showWeekends: false);
      await earlierSave.started.future;
      final backup = encodeAppBackup(provider.appData, []);
      final first = provider.importAppDataJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      final second = provider.importAppDataJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      expect(provider.isRestoringAppBackup, isTrue);

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
