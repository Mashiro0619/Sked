import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

class _ControlledTimetableStorage implements TimetableStorage {
  _ControlledTimetableStorage(this.data);

  AppData? data;
  final List<Completer<void>?> saveGates = [];
  final List<Object?> saveErrors = [];
  final List<AppData> writeLog = [];
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    final index = saveCount;
    saveCount += 1;
    if (index < saveGates.length) {
      await saveGates[index]?.future;
    }
    if (index < saveErrors.length) {
      final error = saveErrors[index];
      if (error != null) {
        throw error;
      }
    }
    this.data = data;
    writeLog.add(data);
  }

  @override
  Future<String?> filePath() async => 'memory://provider-save-race-test';
}

Future<void> _waitForSaveCount(
  _ControlledTimetableStorage storage,
  int expected,
) async {
  for (var i = 0; i < 100 && storage.saveCount < expected; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(storage.saveCount, greaterThanOrEqualTo(expected));
}

TimetableProvider _providerWith(
  _ControlledTimetableStorage storage, {
  Duration uiStateSaveDelay = const Duration(hours: 1),
}) {
  return TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
    uiStateSaveDelay: uiStateSaveDelay,
  );
}

AppData _initialApp() {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  );
  return initial.copyWith(
    activeMode: AppMode.general,
    generalMode: initial.generalMode.copyWith(selectedDateIso: '2026-06-01'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'slow successful save does not overwrite a newer date mutation',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(null);

      final modeSave = provider.switchMode(AppMode.student);
      await _waitForSaveCount(storage, 1);
      await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));

      saveGate.complete();
      await modeSave;

      expect(provider.selectedGeneralDate, DateTime(2026, 6, 2));

      await provider.flushPendingUiStateSaves();
      expect(storage.saveCount, 2);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
    },
  );

  test(
    'slow failed save does not roll back a newer date before debounce fires',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(Exception('disk full'));

      final modeSaveExpectation = expectLater(
        provider.switchMode(AppMode.student),
        throwsException,
      );
      await _waitForSaveCount(storage, 1);
      await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));
      expect(storage.saveCount, 1);

      saveGate.complete();
      await modeSaveExpectation;

      expect(provider.activeMode, AppMode.student);
      expect(provider.selectedGeneralDate, DateTime(2026, 6, 2));

      await provider.flushPendingUiStateSaves();
      expect(storage.saveCount, 2);
      expect(storage.data!.activeMode, AppMode.student);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
    },
  );

  test(
    'storage failure gate does not roll back a newer debounced mutation',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(
        const StorageWriteException('storage unavailable'),
      );

      final modeSaveExpectation = expectLater(
        provider.switchMode(AppMode.student),
        throwsA(isA<StorageWriteException>()),
      );
      await _waitForSaveCount(storage, 1);
      await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));

      saveGate.complete();
      await modeSaveExpectation;

      expect(provider.canWrite, isFalse);
      expect(provider.activeMode, AppMode.student);
      expect(provider.selectedGeneralDate, DateTime(2026, 6, 2));

      await expectLater(
        provider.flushPendingUiStateSaves(),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );
      expect(storage.saveCount, 1);
      expect(provider.activeMode, AppMode.student);
      expect(provider.selectedGeneralDate, DateTime(2026, 6, 2));
    },
  );

  test(
    'two overlapping failed saves restore the last persisted snapshot',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      storage.saveGates.addAll([firstGate, secondGate]);
      storage.saveErrors.addAll([
        Exception('first write failed'),
        Exception('second write failed'),
      ]);

      final firstSaveExpectation = expectLater(
        provider.switchMode(AppMode.student),
        throwsException,
      );
      await _waitForSaveCount(storage, 1);
      final secondSaveExpectation = expectLater(
        provider.updateGeneralDisplaySettings(dayStartHour: 5),
        throwsException,
      );

      firstGate.complete();
      await firstSaveExpectation;
      await _waitForSaveCount(storage, 2);
      secondGate.complete();
      await secondSaveExpectation;

      expect(provider.activeMode, AppMode.general);
      expect(
        provider.generalDayStartHour,
        storage.data!.generalMode.dayStartHour,
      );
      expect(storage.writeLog, isEmpty);
    },
  );

  test(
    'an accepted save blocked by an earlier I/O failure restores persisted data',
    () async {
      final initial = _initialApp();
      final storage = _ControlledTimetableStorage(initial);
      final provider = _providerWith(storage);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final firstGate = Completer<void>();
      storage.saveGates.add(firstGate);
      storage.saveErrors.add(
        const StorageWriteException('storage unavailable'),
      );

      final firstSaveExpectation = expectLater(
        provider.switchMode(AppMode.student),
        throwsA(isA<StorageWriteException>()),
      );
      await _waitForSaveCount(storage, 1);
      final secondSaveExpectation = expectLater(
        provider.updateGeneralDisplaySettings(dayStartHour: 5),
        throwsA(isA<AcceptedWriteBlockedException>()),
      );

      firstGate.complete();
      await firstSaveExpectation;
      await secondSaveExpectation;

      expect(provider.canWrite, isFalse);
      expect(provider.activeMode, initial.activeMode);
      expect(provider.generalDayStartHour, initial.generalMode.dayStartHour);
      expect(storage.saveCount, 1);
      expect(storage.writeLog, isEmpty);
    },
  );

  test('lifecycle flush reports a deferred save failure once', () async {
    final storage = _ControlledTimetableStorage(_initialApp());
    final provider = _providerWith(storage);
    await provider.load();
    storage.saveCount = 0;
    storage.writeLog.clear();
    storage.saveGates.add(null);
    storage.saveErrors.add(Exception('disk full'));

    await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));

    await expectLater(provider.flushPendingUiStateSaves(), throwsException);
    expect(storage.saveCount, 1);
    expect(provider.selectedGeneralDate, DateTime(2026, 6, 1));

    await provider.flushPendingUiStateSaves();
    expect(storage.saveCount, 1);
  });

  test(
    'lifecycle flush awaits an in-flight save without duplicating it',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage, uiStateSaveDelay: Duration.zero);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(null);

      await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));
      await _waitForSaveCount(storage, 1);
      final flush = provider.flushPendingUiStateSaves();
      await Future<void>.delayed(Duration.zero);
      expect(storage.saveCount, 1);

      saveGate.complete();
      await flush;

      expect(storage.saveCount, 1);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
    },
  );

  test(
    'automatic save I/O failure publishes the recovery write gate',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage, uiStateSaveDelay: Duration.zero);
      await provider.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      storage.saveGates.add(null);
      storage.saveErrors.add(
        const StorageWriteException('storage unavailable'),
      );
      var notifications = 0;
      provider.addListener(() => notifications += 1);

      await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));
      final notificationsAfterEdit = notifications;
      await _waitForSaveCount(storage, 1);
      for (var i = 0; i < 20 && provider.canWrite; i += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(provider.canWrite, isFalse);
      expect(notifications, greaterThan(notificationsAfterEdit));
    },
  );
}
