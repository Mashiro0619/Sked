import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

import '../support/workspace_harness.dart';

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  Completer<void>? gate;
  Completer<void>? entered;
  int writes = 0;
  @override
  Future<void> save(AppData data) async {
    writes++;
    if (entered?.isCompleted == false) entered!.complete();
    await gate?.future;
    await super.save(data);
  }
}

Future<(_Storage, TimetableProvider)> _setup({
  Future<void> Function(Future<void> Function())? lock,
}) async {
  final seed = await workspaceProvider(mode: AppMode.general);
  final storage = _Storage(seed.appData);
  seed.dispose();
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage,
    workspaceMutationLock: lock,
  );
  return (storage, provider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('range and focal date publish only after persistence and roundtrip on restart', () async {
    final (storage, p) = await _setup();
    addTearDown(p.dispose);
    final before = p.generalMode;
    final focusRevision = p.generalDateFocusRevision;
    final observed = <GeneralScheduleData>[];
    p.addListener(() => observed.add(p.generalMode));
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    final range = GeneralDateRange(DateTime(2027, 2, 3), DateTime(2027, 2, 7));
    final save = p.setGeneralDateRange(range);
    await storage.entered!.future;
    p.notifyListeners();
    expect(p.customGeneralDateRange, isNull);
    expect(p.generalDateFocusRevision, focusRevision);
    expect(p.selectedGeneralDate, before.selectedDate);
    expect(p.appData.generalMode.customDateRange, isNull);
    final pendingBackup = decodeAppBackup(await p.exportAppDataJson());
    expect(pendingBackup.appData.generalMode.customDateRange, isNull);
    expect(pendingBackup.appData.generalMode.selectedDate, before.selectedDate);
    expect(observed.every((x) => x.customDateRange == null), isTrue);
    storage.gate!.complete();
    await save;
    expect(p.generalDateFocusRevision, focusRevision + 1);
    expect(p.customGeneralDateRange, range);
    expect(p.selectedGeneralDate, range.start);
    expect(storage.data.generalMode.customDateRange, range);
    final restored = await workspaceProvider(storage: storage);
    addTearDown(restored.dispose);
    expect(restored.customGeneralDateRange, range);
    expect(restored.selectedGeneralDate, range.start);
    await p.setSelectedGeneralDate(DateTime(2027, 2, 5));
    expect(p.customGeneralDateRange, range);
    await p.setSelectedGeneralDate(
      DateTime(2027, 4, 1),
      moveCustomRange: false,
    );
    expect(p.customGeneralDateRange, range);
    expect(p.selectedGeneralDate, DateTime(2027, 4, 1));
    await p.setSelectedGeneralDate(p.selectedGeneralDate);
    expect(p.customGeneralDateRange!.start, DateTime(2027, 4, 1));
    expect(p.customGeneralDateRange!.dayCount, 5);
    await p.setSelectedGeneralDate(DateTime(2100));
    expect(p.customGeneralDateRange!.end, DateTime(2100));
    expect(p.customGeneralDateRange!.dayCount, 5);
  });
  test('failure keeps previous navigation and retry cannot overwrite another setting', () async {
    final (storage, p) = await _setup();
    addTearDown(p.dispose);
    final before = p.generalMode;
    final range = GeneralDateRange(DateTime(2027, 2, 3), DateTime(2027, 2, 7));
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    storage.saveError = StateError('write failed');
    final save = p.setGeneralDateRange(range);
    final rejected = expectLater(save, throwsStateError);
    await storage.entered!.future;
    final setting = p.updateGeneralDisplaySettings(showWeekends: false);
    storage.gate!.complete();
    await rejected;
    await setting;
    expect(p.customGeneralDateRange, isNull);
    expect(p.selectedGeneralDate, before.selectedDate);
    expect(p.generalShowWeekends, isFalse);
    expect(storage.data.generalMode.customDateRange, isNull);
    await p.setGeneralDateRange(range);
    expect(p.customGeneralDateRange, range);
    storage.saveError = StateError('clear failed');
    await expectLater(p.clearGeneralDateRange(), throwsStateError);
    expect(p.customGeneralDateRange, range);
    await p.clearGeneralDateRange();
    expect(p.customGeneralDateRange, isNull);
    expect(p.selectedGeneralDate, range.start);
  });
  test(
    'range survives backup, ordinary imports, settings and workspace disable',
    () async {
      final (storage, p) = await _setup();
      addTearDown(p.dispose);
      final range = GeneralDateRange(
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 22),
      );
      await p.setGeneralDateRange(range);
      final focus = p.selectedGeneralDate;
      await p.updateGeneralDisplaySettings(dayStartHour: 5);
      final backup = await p.exportAppDataJson();
      expect(
        decodeAppBackup(backup).appData.generalMode.customDateRange,
        range,
      );
      final categories = p.exportSelectedGeneralSchedulesJson(
        p.generalSchedules.map((s) => s.id).toList(),
      );
      await p.importSelectedGeneralSchedulesJson(
        categories,
        scheduleIds: p.generalSchedules.map((s) => s.id).toList(),
        mode: GeneralScheduleImportMode.addAsNew,
      );
      expect(p.customGeneralDateRange, range);
      await p.importGeneralSchedulesIcs(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:range-import\r\nDTSTART:20260909T090000\r\nDTEND:20260909T100000\r\nSUMMARY:Imported\r\nEND:VEVENT\r\nEND:VCALENDAR',
        mode: GeneralScheduleImportMode.addAsNew,
      );
      expect(p.customGeneralDateRange, range);
      await p.clearGeneralDateRange();
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      expect(p.customGeneralDateRange, range);
      expect(p.selectedGeneralDate, focus);
      await p.setWorkspaceEnabled(AppMode.general, false);
      expect(p.customGeneralDateRange, range);
      final writes = storage.writes;
      await expectLater(p.setGeneralDateRange(range), throwsStateError);
      expect(storage.writes, writes);
      await p.setWorkspaceEnabled(AppMode.general, true);
      expect(p.customGeneralDateRange, range);
    },
  );
  test('queued range and date commands serialize and never publish a half navigation', () async {
    final (storage, p) = await _setup();
    addTearDown(p.dispose);
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    final first = GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13));
    final second = GeneralDateRange(
      DateTime(2026, 12, 30),
      DateTime(2027, 1, 4),
    );
    final one = p.setGeneralDateRange(first);
    await storage.entered!.future;
    final two = p.setGeneralDateRange(second);
    final focus = p.setSelectedGeneralDate(DateTime(2027, 1, 3));
    expect(p.customGeneralDateRange, isNull);
    storage.gate!.complete();
    await Future.wait([one, two, focus]);
    expect(p.customGeneralDateRange, second);
    expect(p.selectedGeneralDate, DateTime(2027, 1, 3));
    expect(storage.data.generalMode.customDateRange, second);
    expect(storage.data.generalMode.selectedDate, DateTime(2027, 1, 3));
  });

  test(
    'a removed owner cannot commit after waiting for a deferred UI save',
    () async {
      final gate = Completer<void>(), entered = Completer<void>();
      final (storage, p) = await _setup();
      storage.gate = gate;
      storage.entered = entered;
      await p.setSelectedGeneralDate(DateTime(2026, 9, 7));
      await entered.future;
      addTearDown(p.dispose);
      var current = true;
      final before = p.generalMode, writes = storage.writes;
      final save = p.setGeneralDateRange(
        GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
        isCurrent: () => current,
      );
      final rejected = expectLater(save, throwsStateError);
      await entered.future;
      current = false;
      gate.complete();
      await rejected;
      expect(p.generalMode.customDateRange, before.customDateRange);
      expect(p.selectedGeneralDate, before.selectedDate);
      expect(storage.writes, writes);
    },
  );

  test('backup restore reserves a new data session before a queued navigation can write', () async {
    final gate = Completer<void>(), entered = Completer<void>();
    final (storage, p) = await _setup();
    storage.gate = gate;
    storage.entered = entered;
    await p.setSelectedGeneralDate(DateTime(2026, 9, 7));
    await entered.future;
    addTearDown(p.dispose);
    final backup = await p.exportAppDataJson();
    final oldToken = p.dataSessionToken;
    final save = p.setGeneralDateRange(
      GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
    );
    final rejected = expectLater(
      save,
      throwsA(isA<AppBackupRestoreInProgressException>()),
    );
    await entered.future;
    final restore = p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
    // The journal lease is asynchronous; the reservation itself must still
    // reject a navigation that was waiting for an older UI write.
    await Future<void>.delayed(Duration.zero);
    expect(p.dataSessionToken, isNot(same(oldToken)));
    gate.complete();
    await rejected;
    await restore;
    expect(p.customGeneralDateRange, isNull);
    expect(storage.data.generalMode.customDateRange, isNull);
  });

  test('disable waits for accepted range persistence, then rejects subsequent navigation', () async {
    final (storage, p) = await _setup();
    addTearDown(p.dispose);
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    final range = GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13));
    final save = p.setGeneralDateRange(range);
    await storage.entered!.future;
    final disable = p.setWorkspaceEnabled(AppMode.general, false);
    final lateSave = p.setGeneralDateRange(range.shifted(5)!);
    final rejected = expectLater(lateSave, throwsStateError);
    storage.gate!.complete();
    await save;
    await disable;
    await rejected;
    expect(p.isWorkspaceEnabled(AppMode.general), isFalse);
    expect(p.customGeneralDateRange, range);
    expect(storage.data.generalMode.customDateRange, range);
  });
}
