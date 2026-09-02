import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData? data;
  Object? nextError;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
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
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => 'en',
        uiStateSaveDelay: Duration.zero,
      );
      addTearDown(provider.dispose);
      final commits = <AppDataCommit>[];
      final subscription = provider.committedData.listen(commits.add);
      addTearDown(subscription.cancel);

      await provider.load();
      expect(commits, isEmpty);

      await provider.updateGeneralDisplaySettings(showWeekends: false);
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));
      expect(commits.single.revision, 1);
      expect(commits.single.snapshot.generalMode.showWeekends, isFalse);
      expect(commits.single.data, same(commits.single.snapshot));

      await provider.setSelectedGeneralDate(DateTime(2026, 8, 3));
      await provider.flushPendingUiStateSaves();
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));

      storage.nextError = StateError('write failed');
      await expectLater(
        provider.updateGeneralDisplaySettings(showWeekends: true),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(commits, hasLength(1));
    },
  );

  test('closing the provider closes committed stream', () async {
    final provider = TimetableProvider(
      storage: _MemoryStorage(buildInitialAppData(buildDefaultPeriodTimes())),
      systemLocaleCodeResolver: () => 'en',
    );
    final done = Completer<void>();
    provider.committedData.listen((_) {}, onDone: done.complete);
    provider.dispose();
    await expectLater(done.future, completes);
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
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => 'en',
    );
    addTearDown(provider.dispose);
    final commits = <AppDataCommit>[];
    final subscription = provider.committedData.listen(commits.add);
    addTearDown(subscription.cancel);

    await provider.load();
    await Future<void>.delayed(Duration.zero);

    expect(storage.saveCount, 1);
    expect(provider.appData, same(storage.data));
    expect(
      provider.appData.studentMode.periodTimeSets.single.id,
      'padded-period-set',
    );
    expect(commits, hasLength(1));
    expect(commits.single.revision, 1);
    expect(commits.single.snapshot, same(provider.appData));
  });
}
