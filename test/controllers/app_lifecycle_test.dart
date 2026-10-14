import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/controllers/app_lifecycle.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';

import '../support/workspace_harness.dart';

class _RecoveryStorage extends WorkspaceMemoryStorage {
  _RecoveryStorage(super.data);

  var unavailable = false;

  @override
  Future<StorageLoadResult> load() async => unavailable
      ? const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.ioFailure,
          recoveryArtifacts: ['memory://protected-recovery'],
        )
      : super.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'privacy metadata publishes independently from workspace content',
    () async {
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      var lifecycleChanges = 0;
      var studentChanges = 0;
      var generalChanges = 0;
      var settingsChanges = 0;
      app.lifecycle.addListener(() => lifecycleChanges += 1);
      app.studentView.addListener(() => studentChanges += 1);
      app.generalView.addListener(() => generalChanges += 1);
      app.settingsView.addListener(() => settingsChanges += 1);

      await app.lifecycle.acceptPrivacyPolicyCurrentVersion();
      expect(app.lifecycle.hasAcceptedCurrentPrivacyPolicy, isTrue);
      expect(
        (lifecycleChanges, studentChanges, generalChanges, settingsChanges),
        (1, 0, 0, 0),
      );

      final timetable = app.studentView.activeTimetable;
      await app.studentCommands.updateTimetableConfig(
        timetable.config.copyWith(name: '${timetable.config.name} updated'),
      );
      expect(
        (lifecycleChanges, studentChanges, generalChanges, settingsChanges),
        (1, 1, 0, 0),
      );
    },
  );

  test(
    'storage retry publishes recovery metadata and restores readiness',
    () async {
      final storage = _RecoveryStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final app = await workspaceProvider(storage: storage);
      addTearDown(app.dispose);
      final observed = <(StorageLoadStatus, bool)>[];
      app.lifecycle.addListener(() {
        observed.add((app.lifecycle.storageLoadStatus, app.lifecycle.canWrite));
      });

      storage.unavailable = true;
      await app.lifecycle.retryStorageLoad();
      expect(app.session.readiness.value.isReady, isTrue);
      expect(app.session.readiness.value.canWrite, isFalse);
      expect(observed.last, (StorageLoadStatus.ioFailure, false));
      expect(app.lifecycle.recoveryArtifacts, ['memory://protected-recovery']);
      expect(app.lifecycle.canStartFreshAfterRecovery, isFalse);

      storage.unavailable = false;
      await app.lifecycle.retryStorageLoad();
      expect(app.session.readiness.value.isReady, isTrue);
      expect(app.session.readiness.value.canWrite, isTrue);
      expect(observed.last, (StorageLoadStatus.success, true));
      expect(app.lifecycle.lastRecoveryStatus, RecoveryStatus.none);
    },
  );

  test(
    'failed normalization keeps its recovered view without a durable write',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final original = initial.copyWith(
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
      );
      final storage = WorkspaceMemoryStorage(original)
        ..saveError = const StorageWriteException('normalization write failed');

      final app = await workspaceProvider(storage: storage);
      addTearDown(app.dispose);

      expect(app.studentView.periodTimeSets.single.id, 'padded-period-set');
      expect(app.session.committedData, same(original));
      expect(
        app.session.committedData.studentMode.periodTimeSets.single.id,
        ' padded-period-set ',
      );
      expect(app.session.versions.student, 0);
      expect(app.session.versions.agenda, 0);
      expect(app.lifecycle.storageLoadStatus, StorageLoadStatus.ioFailure);
      expect(app.session.readiness.value.canWrite, isFalse);
    },
  );

  testWidgets('AppScope exposes the same observable lifecycle owner', (
    tester,
  ) async {
    final app = await workspaceProvider();
    addTearDown(app.dispose);
    var builds = 0;
    await tester.pumpWidget(
      AppScope(
        app: app,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer<AppLifecycle>(
            builder: (_, lifecycle, _) {
              builds += 1;
              expect(lifecycle, same(app.lifecycle));
              return Text(
                lifecycle.hasAcceptedCurrentPrivacyPolicy
                    ? 'accepted'
                    : 'pending',
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('pending'), findsOneWidget);

    await app.lifecycle.acceptPrivacyPolicyCurrentVersion();
    await tester.pump();

    expect(find.text('accepted'), findsOneWidget);
    expect(builds, 2);
  });
}
