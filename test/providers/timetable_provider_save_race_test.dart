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
  void Function(int index)? onSaveStarted;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    final index = saveCount;
    saveCount += 1;
    onSaveStarted?.call(index);
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
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(null);

      final modeSave = provider.workspaces.switchMode(AppMode.student);
      await _waitForSaveCount(storage, 1);
      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));

      saveGate.complete();
      await modeSave;

      expect(provider.generalView.selectedDate, DateTime(2026, 6, 2));

      await provider.persistence.flushPendingUiStateSaves();
      expect(storage.saveCount, 2);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
    },
  );

  test(
    'pending mode save does not leak target theme through provider getters',
    () async {
      final seed = _initialApp();
      final timetable = TimetableData(
        id: 'pending-theme-table',
        config: TimetableConfig(
          name: 'Pending theme',
          startDate: DateTime(2026, 1, 5),
          totalWeeks: 18,
          periodTimeSetId: defaultPeriodTimeSetId,
        ),
        courses: const [],
      );
      final base = seed.copyWith(
        activeMode: AppMode.student,
        studentMode: seed.studentMode.copyWith(
          activeTimetableId: timetable.id,
          timetables: [timetable],
        ),
      );
      final initial = base.copyWith(
        studentMode: base.studentMode.copyWith(
          themeMode: 'dark',
          themeSeedColorValue: 0xFF112233,
        ),
        generalMode: base.generalMode.copyWith(
          themeMode: 'light',
          themeSeedColorValue: 0xFF445566,
        ),
      );
      final storage = _ControlledTimetableStorage(initial);
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(null);

      final modeSave = provider.workspaces.switchMode(AppMode.general);
      await _waitForSaveCount(storage, 1);

      expect(provider.workspaceView.activeMode, AppMode.student);
      expect(provider.settingsView.themeMode, 'dark');
      expect(provider.settingsView.themeSeedColorValue, 0xFF112233);
      final nextWeek = provider.studentView.selectedWeek == 1 ? 2 : 1;
      await provider.studentCommands.setSelectedWeek(nextWeek);
      expect(provider.studentView.selectedWeek, nextWeek);
      expect(provider.workspaceView.activeMode, AppMode.student);
      expect(provider.settingsView.themeMode, 'dark');

      saveGate.complete();
      await modeSave;
      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.settingsView.themeMode, 'light');
      expect(provider.settingsView.themeSeedColorValue, 0xFF445566);
    },
  );

  test('direct overlapping mode requests are serialized', () async {
    final storage = _ControlledTimetableStorage(_initialApp());
    final provider = _providerWith(storage);
    await provider.lifecycle.load();
    storage.saveCount = 0;
    storage.writeLog.clear();
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    storage.saveGates.addAll([firstGate, secondGate]);
    storage.saveErrors.addAll([null, null]);

    final first = provider.workspaces.switchMode(AppMode.student);
    await _waitForSaveCount(storage, 1);
    final second = provider.workspaces.switchMode(AppMode.general);
    await Future<void>.delayed(Duration.zero);
    expect(storage.saveCount, 1);
    expect(provider.workspaceView.activeMode, AppMode.general);

    firstGate.complete();
    await first;
    await _waitForSaveCount(storage, 2);
    expect(provider.workspaceView.activeMode, AppMode.student);

    secondGate.complete();
    await second;
    expect(provider.workspaceView.activeMode, AppMode.general);
    expect(storage.data!.activeMode, AppMode.general);
    expect(storage.saveCount, 2);
  });

  test(
    'slow failed mode save preserves a newer date and committed mode',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(Exception('disk full'));

      final modeSaveExpectation = expectLater(
        provider.workspaces.switchMode(AppMode.student),
        throwsException,
      );
      await _waitForSaveCount(storage, 1);
      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      expect(storage.saveCount, 1);

      saveGate.complete();
      await modeSaveExpectation;

      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.generalView.selectedDate, DateTime(2026, 6, 2));

      await provider.persistence.flushPendingUiStateSaves();
      expect(storage.saveCount, 2);
      expect(storage.data!.activeMode, AppMode.general);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
    },
  );

  test(
    'failed mode save preserves UI state scheduled before the switch',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(Exception('mode write failed'));

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      final modeSaveExpectation = expectLater(
        provider.workspaces.switchMode(AppMode.student),
        throwsException,
      );
      await _waitForSaveCount(storage, 1);
      saveGate.complete();
      await modeSaveExpectation;

      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.generalView.selectedDate, DateTime(2026, 6, 2));

      await provider.persistence.flushPendingUiStateSaves();
      expect(storage.saveCount, 2);
      expect(storage.data!.activeMode, AppMode.general);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
    },
  );

  test(
    'storage failure gate keeps a newer debounced mutation read-only',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(
        const StorageWriteException('storage unavailable'),
      );

      final modeSaveExpectation = expectLater(
        provider.workspaces.switchMode(AppMode.student),
        throwsA(isA<StorageWriteException>()),
      );
      await _waitForSaveCount(storage, 1);
      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));

      saveGate.complete();
      await modeSaveExpectation;

      expect(provider.session.canWrite, isFalse);
      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.generalView.selectedDate, DateTime(2026, 6, 2));

      await expectLater(
        provider.persistence.flushPendingUiStateSaves(),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );
      expect(storage.saveCount, 1);
      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.generalView.selectedDate, DateTime(2026, 6, 2));
    },
  );

  test(
    'mode failure lets an overlapping settings save use the committed mode',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();
      storage.saveGates.addAll([firstGate, secondGate]);
      storage.saveErrors.addAll([Exception('first write failed'), null]);

      final firstSaveExpectation = expectLater(
        provider.workspaces.switchMode(AppMode.student),
        throwsException,
      );
      await _waitForSaveCount(storage, 1);
      final secondSave = provider.generalCommands.updateDisplaySettings(
        dayStartHour: 5,
      );

      firstGate.complete();
      await firstSaveExpectation;
      await _waitForSaveCount(storage, 2);
      secondGate.complete();
      await secondSave;

      expect(provider.workspaceView.activeMode, AppMode.general);
      expect(provider.generalView.data.dayStartHour, 5);
      expect(storage.data!.activeMode, AppMode.general);
      expect(storage.data!.generalMode.dayStartHour, 5);
      expect(storage.writeLog, hasLength(1));
    },
  );

  test('an accepted save blocked by an earlier I/O failure restores persisted data', () async {
    final initial = _initialApp();
    final storage = _ControlledTimetableStorage(initial);
    final provider = _providerWith(storage);
    await provider.lifecycle.load();
    storage.saveCount = 0;
    storage.writeLog.clear();
    final firstGate = Completer<void>();
    storage.saveGates.add(firstGate);
    storage.saveErrors.add(const StorageWriteException('storage unavailable'));

    final firstSaveExpectation = expectLater(
      provider.workspaces.switchMode(AppMode.student),
      throwsA(isA<StorageWriteException>()),
    );
    await _waitForSaveCount(storage, 1);
    final secondSaveExpectation = expectLater(
      provider.generalCommands.updateDisplaySettings(dayStartHour: 5),
      throwsA(isA<RecoveryWriteBlockedException>()),
    );

    firstGate.complete();
    await firstSaveExpectation;
    await secondSaveExpectation;

    expect(provider.session.canWrite, isFalse);
    expect(provider.workspaceView.activeMode, initial.activeMode);
    expect(provider.generalView.data.dayStartHour, 5);
    expect(storage.saveCount, 1);
    expect(storage.writeLog, isEmpty);
    expect(
      storage.data!.generalMode.dayStartHour,
      initial.generalMode.dayStartHour,
    );
  });

  test('lifecycle flush reports a deferred save failure once', () async {
    final storage = _ControlledTimetableStorage(_initialApp());
    final provider = _providerWith(storage);
    await provider.lifecycle.load();
    storage.saveCount = 0;
    storage.writeLog.clear();
    storage.saveGates.add(null);
    storage.saveErrors.add(Exception('disk full'));

    await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));

    await expectLater(
      provider.persistence.flushPendingUiStateSaves(),
      throwsException,
    );
    expect(storage.saveCount, 1);
    expect(provider.generalView.selectedDate, DateTime(2026, 6, 1));

    await provider.persistence.flushPendingUiStateSaves();
    expect(storage.saveCount, 1);
  });

  test(
    'lifecycle flush awaits an in-flight save without duplicating it',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage, uiStateSaveDelay: Duration.zero);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final saveGate = Completer<void>();
      storage.saveGates.add(saveGate);
      storage.saveErrors.add(null);

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      await _waitForSaveCount(storage, 1);
      final flush = provider.persistence.flushPendingUiStateSaves();
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
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      storage.saveGates.add(null);
      storage.saveErrors.add(
        const StorageWriteException('storage unavailable'),
      );
      var notifications = 0;
      provider.session.readiness.addListener(() => notifications += 1);

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      final notificationsAfterEdit = notifications;
      await _waitForSaveCount(storage, 1);
      for (var i = 0; i < 20 && provider.session.canWrite; i += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(provider.session.canWrite, isFalse);
      expect(notifications, greaterThan(notificationsAfterEdit));
    },
  );
  test(
    'dispose flushes a pending debounce without notifying disposed listeners',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final started = Completer<void>();
      final gate = Completer<void>();
      storage.onSaveStarted = (_) => started.complete();
      storage.saveGates.add(gate);
      var notifications = 0;
      provider.generalView.addListener(() => notifications += 1);
      provider.session.readiness.addListener(() => notifications += 1);

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      final notificationsBeforeDispose = notifications;
      provider.dispose();
      final flushed = provider.persistence.flushPendingUiStateSaves();
      await started.future;
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-01');
      gate.complete();
      await flushed;

      expect(storage.saveCount, 1);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-02');
      expect(notifications, notificationsBeforeDispose);
    },
  );

  test(
    'dispose queues the latest debounce behind an in-flight flush',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final started = [Completer<void>(), Completer<void>()];
      final gates = [Completer<void>(), Completer<void>()];
      storage.saveGates.addAll(gates);
      storage.onSaveStarted = (index) => started[index].complete();

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      final firstFlush = provider.persistence.flushPendingUiStateSaves();
      await started[0].future;
      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 3));
      provider.dispose();
      final finalFlush = provider.persistence.flushPendingUiStateSaves();
      gates[0].complete();
      await firstFlush;
      await started[1].future;
      expect(storage.writeLog.single.generalMode.selectedDateIso, '2026-06-02');
      gates[1].complete();
      await finalFlush;

      expect(storage.writeLog.map((data) => data.generalMode.selectedDateIso), [
        '2026-06-02',
        '2026-06-03',
      ]);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-03');
    },
  );

  test(
    'a disposed deferred save failure stays observable and keeps durable data',
    () async {
      final storage = _ControlledTimetableStorage(_initialApp());
      final provider = _providerWith(storage);
      await provider.lifecycle.load();
      storage.saveCount = 0;
      storage.writeLog.clear();
      final started = Completer<void>();
      final gate = Completer<void>();
      storage.saveGates.add(gate);
      storage.saveErrors.add(const StorageWriteException('disk unavailable'));
      storage.onSaveStarted = (_) => started.complete();
      var notifications = 0;
      provider.generalView.addListener(() => notifications += 1);
      provider.session.readiness.addListener(() => notifications += 1);

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 6, 2));
      final notificationsBeforeDispose = notifications;
      provider.dispose();
      final observedFailure = expectLater(
        provider.persistence.flushPendingUiStateSaves(),
        throwsA(isA<StorageWriteException>()),
      );
      await started.future;
      gate.complete();
      await observedFailure;
      await provider.shutdown.quiesce();

      expect(provider.session.canWrite, isFalse);
      expect(storage.writeLog, isEmpty);
      expect(storage.data!.generalMode.selectedDateIso, '2026-06-01');
      expect(notifications, notificationsBeforeDispose);
    },
  );
}
