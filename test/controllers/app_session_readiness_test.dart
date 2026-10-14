import 'package:flutter_test/flutter_test.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/timetable_storage_fakes.dart';

Future<(WorkspaceMemoryStorage, AppSession)> openSession() async {
  final data = buildInitialAppData(buildDefaultPeriodTimes());
  final storage = WorkspaceMemoryStorage(data);
  final repository = AppRepository(storage: storage);
  await repository.load();
  final session = AppSession(
    repository: repository,
    initialData: data,
    requireMutationAllowed: () {},
  );
  addTearDown(session.close);
  return (storage, session);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('readiness is independent of ordinary data commits', () async {
    final (_, session) = await openSession();
    final observed = <AppSessionReadiness>[];
    session.readiness.addListener(() => observed.add(session.readiness.value));
    expect(session.readiness.value.isReady, isFalse);
    session.updateLoadState(isLoading: true);
    session.updateLoadState(isLoaded: true, isLoading: false);
    session.updateLoadState(isLoaded: true, isLoading: false);
    expect(observed, hasLength(2));
    expect(observed.last.isReady, isTrue);

    final updated = session.data.copyWith(hideHomeWorkspaceNavigation: true);
    session.replaceData(updated);
    await session.persist(updated);
    expect(observed, hasLength(2));
    expect(session.committedData.hideHomeWorkspaceNavigation, isTrue);
  });

  for (final unknown in [false, true]) {
    test(
      'failed storage publishes its write gate and reload resolves it (unknown: $unknown)',
      () async {
        final (storage, session) = await openSession();
        session.updateLoadState(isLoaded: true);
        final observed = <AppSessionReadiness>[];
        session.readiness.addListener(
          () => observed.add(session.readiness.value),
        );
        storage.saveError = unknown
            ? StorageWriteStateUnknownException(
                writeError: StateError('write failed'),
                rollbackError: StateError('rollback failed'),
              )
            : const StorageWriteException('write failed');
        final updated = session.data.copyWith(
          hideHomeWorkspaceNavigation: true,
        );
        session.replaceData(updated);
        await expectLater(
          session.persist(updated),
          throwsA(isA<StorageWriteException>()),
        );

        expect(observed, hasLength(1));
        expect(observed.single.isReady, isTrue);
        expect(observed.single.canWrite, isFalse);
        expect(observed.single.isWriteStateUnknown, unknown);
        await session.repository.retryLoad();
        session.refreshReadiness();
        expect(observed, hasLength(2));
        expect(observed.last.canWrite, isTrue);
        expect(observed.last.isWriteStateUnknown, isFalse);
      },
    );
  }
}
