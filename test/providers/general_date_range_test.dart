import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart' show AppImportMode;
import 'package:sked/controllers/app_data_maintenance.dart'
    show AppBackupRestoreInProgressException;

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

Future<(_Storage, AppRuntime)> _setup({
  Future<void> Function(Future<void> Function())? lock,
}) async {
  final seed = await workspaceProvider(mode: AppMode.general);
  final storage = _Storage(seed.workspaceView.data);
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
    final before = p.generalView.visibleData;
    final focusRevision = p.generalView.focusRevision;
    final observed = <GeneralScheduleData>[];
    p.generalView.addListener(() => observed.add(p.generalView.visibleData));
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    final range = GeneralDateRange(DateTime(2027, 2, 3), DateTime(2027, 2, 7));
    final save = p.generalNavigation.setDateRange(range);
    await storage.entered!.future;
    final nextWeek = p.studentView.selectedWeek == 1 ? 2 : 1;
    await p.studentCommands.setSelectedWeek(nextWeek);
    expect(p.studentView.selectedWeek, nextWeek);
    expect(p.generalView.customDateRange, isNull);
    expect(p.generalView.focusRevision, focusRevision);
    expect(p.generalView.selectedDate, before.selectedDate);
    expect(p.workspaceView.data.generalMode.customDateRange, isNull);
    final pendingBackup = decodeAppBackup(await p.backups.exportJson());
    expect(pendingBackup.appData.generalMode.customDateRange, isNull);
    expect(pendingBackup.appData.generalMode.selectedDate, before.selectedDate);
    expect(observed, isEmpty);
    storage.gate!.complete();
    await save;
    expect(observed.single.customDateRange, range);
    expect(observed.single.selectedDate, range.start);
    expect(p.generalView.focusRevision, focusRevision + 1);
    expect(p.generalView.customDateRange, range);
    expect(p.generalView.selectedDate, range.start);
    expect(storage.data.generalMode.customDateRange, range);
    final restored = await workspaceProvider(storage: storage);
    addTearDown(restored.dispose);
    expect(restored.generalView.customDateRange, range);
    expect(restored.generalView.selectedDate, range.start);
    await p.generalNavigation.setSelectedDate(DateTime(2027, 2, 5));
    expect(p.generalView.customDateRange, range);
    await p.generalNavigation.setSelectedDate(
      DateTime(2027, 4, 1),
      moveCustomRange: false,
    );
    expect(p.generalView.customDateRange, range);
    expect(p.generalView.selectedDate, DateTime(2027, 4, 1));
    await p.generalNavigation.setSelectedDate(p.generalView.selectedDate);
    expect(p.generalView.customDateRange!.start, DateTime(2027, 4, 1));
    expect(p.generalView.customDateRange!.dayCount, 5);
    await p.generalNavigation.setSelectedDate(DateTime(2100));
    expect(p.generalView.customDateRange!.end, DateTime(2100));
    expect(p.generalView.customDateRange!.dayCount, 5);
  });
  test('failure keeps previous navigation and retry cannot overwrite another setting', () async {
    final (storage, p) = await _setup();
    addTearDown(p.dispose);
    final before = p.generalView.visibleData;
    final range = GeneralDateRange(DateTime(2027, 2, 3), DateTime(2027, 2, 7));
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    storage.saveError = StateError('write failed');
    final save = p.generalNavigation.setDateRange(range);
    final rejected = expectLater(save, throwsStateError);
    await storage.entered!.future;
    final setting = p.generalCommands.updateDisplaySettings(
      showWeekends: false,
    );
    storage.gate!.complete();
    await rejected;
    await setting;
    expect(p.generalView.customDateRange, isNull);
    expect(p.generalView.selectedDate, before.selectedDate);
    expect(p.generalView.data.showWeekends, isFalse);
    expect(storage.data.generalMode.customDateRange, isNull);
    await p.generalNavigation.setDateRange(range);
    expect(p.generalView.customDateRange, range);
    storage.saveError = StateError('clear failed');
    await expectLater(p.generalNavigation.clearDateRange(), throwsStateError);
    expect(p.generalView.customDateRange, range);
    await p.generalNavigation.clearDateRange();
    expect(p.generalView.customDateRange, isNull);
    expect(p.generalView.selectedDate, range.start);
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
      await p.generalNavigation.setDateRange(range);
      final focus = p.generalView.selectedDate;
      await p.generalCommands.updateDisplaySettings(dayStartHour: 5);
      final backup = await p.backups.exportJson();
      expect(
        decodeAppBackup(backup).appData.generalMode.customDateRange,
        range,
      );
      final categories = p.transfers.exportSelectedGeneralSchedulesJson(
        p.generalView.schedules.map((s) => s.id).toList(),
      );
      await p.transfers.importSelectedGeneralSchedulesJson(
        categories,
        scheduleIds: p.generalView.schedules.map((s) => s.id).toList(),
        mode: GeneralScheduleImportMode.addAsNew,
      );
      expect(p.generalView.customDateRange, range);
      await p.transfers.importGeneralSchedulesIcs(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:range-import\r\nDTSTART:20260909T090000\r\nDTEND:20260909T100000\r\nSUMMARY:Imported\r\nEND:VEVENT\r\nEND:VCALENDAR',
        mode: GeneralScheduleImportMode.addAsNew,
      );
      expect(p.generalView.customDateRange, range);
      await p.generalNavigation.clearDateRange();
      await p.backups.importJson(backup, mode: AppImportMode.replaceAll);
      expect(p.generalView.customDateRange, range);
      expect(p.generalView.selectedDate, focus);
      await p.workspaces.setEnabled(AppMode.general, false);
      expect(p.generalView.customDateRange, range);
      final writes = storage.writes;
      await expectLater(
        p.generalNavigation.setDateRange(range),
        throwsStateError,
      );
      expect(storage.writes, writes);
      await p.workspaces.setEnabled(AppMode.general, true);
      expect(p.generalView.customDateRange, range);
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
    final one = p.generalNavigation.setDateRange(first);
    await storage.entered!.future;
    final two = p.generalNavigation.setDateRange(second);
    final focus = p.generalNavigation.setSelectedDate(DateTime(2027, 1, 3));
    expect(p.generalView.customDateRange, isNull);
    storage.gate!.complete();
    await Future.wait([one, two, focus]);
    expect(p.generalView.customDateRange, second);
    expect(p.generalView.selectedDate, DateTime(2027, 1, 3));
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
      await p.generalNavigation.setSelectedDate(DateTime(2026, 9, 7));
      await entered.future;
      addTearDown(p.dispose);
      var current = true;
      final before = p.generalView.visibleData, writes = storage.writes;
      final save = p.generalNavigation.setDateRange(
        GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
        isCurrent: () => current,
      );
      final rejected = expectLater(save, throwsStateError);
      await entered.future;
      current = false;
      gate.complete();
      await rejected;
      expect(p.generalView.visibleData.customDateRange, before.customDateRange);
      expect(p.generalView.selectedDate, before.selectedDate);
      expect(storage.writes, writes);
    },
  );

  test('backup restore reserves a new data session before a queued navigation can write', () async {
    final gate = Completer<void>(), entered = Completer<void>();
    final (storage, p) = await _setup();
    storage.gate = gate;
    storage.entered = entered;
    await p.generalNavigation.setSelectedDate(DateTime(2026, 9, 7));
    await entered.future;
    addTearDown(p.dispose);
    final backup = await p.backups.exportJson();
    final oldToken = p.maintenance.dataSessionToken;
    final save = p.generalNavigation.setDateRange(
      GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
    );
    final rejected = expectLater(
      save,
      throwsA(isA<AppBackupRestoreInProgressException>()),
    );
    await entered.future;
    final restore = p.backups.importJson(
      backup,
      mode: AppImportMode.replaceAll,
    );
    // The journal lease is asynchronous; the reservation itself must still
    // reject a navigation that was waiting for an older UI write.
    await Future<void>.delayed(Duration.zero);
    expect(p.maintenance.dataSessionToken, isNot(same(oldToken)));
    gate.complete();
    await rejected;
    await restore;
    expect(p.generalView.customDateRange, isNull);
    expect(storage.data.generalMode.customDateRange, isNull);
  });

  test('disable waits for accepted range persistence, then rejects subsequent navigation', () async {
    final (storage, p) = await _setup();
    addTearDown(p.dispose);
    storage.gate = Completer<void>();
    storage.entered = Completer<void>();
    final range = GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13));
    final save = p.generalNavigation.setDateRange(range);
    await storage.entered!.future;
    final disable = p.workspaces.setEnabled(AppMode.general, false);
    final lateSave = p.generalNavigation.setDateRange(range.shifted(5)!);
    final rejected = expectLater(lateSave, throwsStateError);
    storage.gate!.complete();
    await save;
    await disable;
    await rejected;
    expect(p.workspaceView.isEnabled(AppMode.general), isFalse);
    expect(p.generalView.customDateRange, range);
    expect(storage.data.generalMode.customDateRange, range);
  });
}
