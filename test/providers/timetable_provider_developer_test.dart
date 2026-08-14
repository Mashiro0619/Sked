import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/developer_sample_data_service.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(
    this.data, {
    this.recoveryStatus = RecoveryStatus.none,
  });

  AppData? data;
  final RecoveryStatus recoveryStatus;
  var saveCount = 0;
  Object? nextSaveError;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: recoveryStatus);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw error;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://provider-developer-test';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'developer sample data is persisted once without switching mode',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes())
          .copyWith(activeMode: AppMode.general, localeCode: 'de');
      final storage = _MemoryTimetableStorage(initial);
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      await provider.load();
      storage.saveCount = 0;

      await provider.addDeveloperSampleData(
        DeveloperSampleLanguage.english,
        now: DateTime(2026, 8, 14, 13, 37),
      );

      expect(storage.saveCount, 1);
      expect(provider.activeMode, AppMode.general);
      expect(provider.localeCode, 'de');
      expect(provider.studentMode.timetables, hasLength(1));
      expect(provider.studentMode.timetables.single.courses, hasLength(10));
      expect(provider.generalMode.schedules, hasLength(4));
      expect(provider.selectedWeek, 1);
      expect(
        storage.data!.studentMode.activeTimetableId,
        provider.studentMode.activeTimetableId,
      );
      expect(
        storage.data!.generalMode.activeScheduleId,
        provider.generalMode.activeScheduleId,
      );
    },
  );

  test('developer sample persistence failure rolls both modes back', () async {
    final periodTimes = buildDefaultPeriodTimes();
    final initial = buildInitialAppData(periodTimes);
    final timetable = TimetableData(
      id: 'existing-table',
      config: TimetableConfig(
        name: 'Existing timetable',
        startDate: DateTime(2026, 8, 3),
        totalWeeks: 18,
        periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
      ),
      courses: const [],
    );
    final storage = _MemoryTimetableStorage(initial);
    final provider = TimetableProvider(
      storage: storage,
      systemLocaleCodeResolver: () => defaultLocaleCode,
    );
    await provider.load();
    await provider.addTimetable(timetable.config);
    storage.saveCount = 0;
    await provider.setSelectedWeek(7);
    storage.saveCount = 0;
    storage.nextSaveError = const StorageWriteException('test failure');

    await expectLater(
      provider.addDeveloperSampleData(
        DeveloperSampleLanguage.simplifiedChinese,
        now: DateTime(2026, 8, 14, 13, 37),
      ),
      throwsA(isA<StorageWriteException>()),
    );

    expect(storage.saveCount, 1);
    expect(provider.studentMode.timetables, hasLength(1));
    expect(provider.generalMode.schedules, hasLength(1));
    expect(provider.selectedWeek, 7);
    expect(storage.data!.studentMode.timetables, hasLength(1));
    expect(storage.data!.generalMode.schedules, hasLength(1));
  });

  test(
    'developer sample data does not mutate a recovery-blocked snapshot',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _MemoryTimetableStorage(
        initial,
        recoveryStatus: RecoveryStatus.ioFailure,
      );
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      await provider.load();

      await expectLater(
        provider.addDeveloperSampleData(
          DeveloperSampleLanguage.english,
          now: DateTime(2026, 8, 14),
        ),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );

      expect(storage.saveCount, 0);
      expect(provider.studentMode.timetables, isEmpty);
      expect(provider.generalMode.schedules, hasLength(1));
    },
  );
}
