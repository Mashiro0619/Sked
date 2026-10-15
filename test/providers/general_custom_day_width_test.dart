import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

import '../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'date navigation and clearing a weekend range retain column width',
    () async {
      final data = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'en',
      );
      final storage = WorkspaceMemoryStorage(
        data.copyWith(
          generalMode: data.generalMode.copyWith(
            customDayMinWidth: 160,
            showWeekends: false,
          ),
        ),
      );
      final provider = await workspaceProvider(storage: storage);
      addTearDown(provider.dispose);
      await provider.generalNavigation.setSelectedDate(DateTime(2030, 1, 2));
      await provider.persistence.flushPendingUiStateSaves();
      expect(provider.generalView.data.customDayMinWidth, 160);
      await provider.generalNavigation.setDateRange(
        GeneralDateRange(DateTime(2030, 1, 5), DateTime(2030, 1, 6)),
        focusedDate: DateTime(2030, 1, 6),
      );
      await provider.generalNavigation.clearDateRange();
      expect(provider.generalView.selectedDate, DateTime(2030, 1, 4));
      expect(storage.data.generalMode.customDayMinWidth, 160);
    },
  );

  test('optional column width keeps old schemas automatic and roundtrips through copies', () {
    final original = GeneralScheduleData.createDefault();
    expect(original.customDayMinWidth, isNull);
    expect(original.toJson().containsKey('customDayMinWidth'), isFalse);
    for (final version in [1, 2, 4, 5]) {
      final json = original.toJson()..['schemaVersion'] = version;
      expect(GeneralScheduleData.fromJson(json).customDayMinWidth, isNull);
      json['customDayMinWidth'] = 160;
      final restored = GeneralScheduleData.fromJson(json);
      expect(restored.customDayMinWidth, 160);
      expect(
        restored.copyWith(showWeekends: false).normalized().customDayMinWidth,
        160,
      );
      expect(
        restored.copyWith(customDayMinWidth: null).customDayMinWidth,
        isNull,
      );
      expect(restored.toJson()['schemaVersion'], generalScheduleSchemaVersion);
    }
    for (final (value, expected) in [
      (0, 64),
      (65, 64),
      (99, 96),
      (103, 104),
      (999, 320),
    ]) {
      expect(normalizeGeneralCustomDayMinWidth(value), expected);
      expect(
        original
            .copyWith(customDayMinWidth: value)
            .normalized()
            .customDayMinWidth,
        expected,
      );
    }
  });

  test(
    'strict storage rejects malformed, out of range and off-step widths',
    () {
      for (final value in ['96', 96.5, true, {}, [], -8, 0, 63, 65, 321]) {
        final json = AppData.fromJson(const {}).toJson();
        (json['generalMode'] as Map)['customDayMinWidth'] = value;
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(json)),
          throwsFormatException,
          reason: '$value',
        );
      }
      for (final value in <int?>[null, 64, 96, 320]) {
        final json = AppData.fromJson(const {}).toJson();
        (json['generalMode'] as Map)['customDayMinWidth'] = value;
        expect(
          AppData.decodeStorageSnapshot(jsonEncode(json))
              .generalMode
              .customDayMinWidth,
          value,
        );
      }
    },
  );

  test(
    'width saves, restarts, restores backups and survives content-only imports',
    () async {
      final data = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'en',
      );
      final storage = WorkspaceMemoryStorage(data);
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      final range = GeneralDateRange(
        DateTime(2026, 9, 3),
        DateTime(2026, 9, 9),
      );
      await p.generalNavigation.setDateRange(range);
      final date = p.generalView.selectedDate;
      final revision = p.generalView.focusRevision;
      await p.generalCommands.updateCustomDayMinWidth(160);
      expect(p.generalView.data.customDayMinWidth, 160);
      expect(storage.data.generalMode.customDayMinWidth, 160);
      expect(p.generalView.customDateRange, range);
      expect(p.generalView.selectedDate, date);
      expect(p.generalView.focusRevision, revision);
      await p.generalCommands.updateDisplaySettings(
        showWeekends: false,
        dayStartHour: 5,
      );
      expect(p.generalView.data.customDayMinWidth, 160);
      final restarted = await workspaceProvider(storage: storage);
      addTearDown(restarted.dispose);
      expect(restarted.generalView.data.customDayMinWidth, 160);
      final backup = await p.backups.exportJson();
      expect(
        decodeAppBackup(backup).appData.generalMode.customDayMinWidth,
        160,
      );
      final ids = p.generalView.schedules.map((s) => s.id).toList();
      await p.transfers.importSelectedGeneralSchedulesJson(
        p.transfers.exportSelectedGeneralSchedulesJson(ids),
        scheduleIds: ids,
        mode: GeneralScheduleImportMode.addAsNew,
      );
      await p.transfers.importGeneralSchedulesIcs(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:width-import\r\nDTSTART:20260909T090000\r\nDTEND:20260909T100000\r\nSUMMARY:Imported\r\nEND:VEVENT\r\nEND:VCALENDAR',
        mode: GeneralScheduleImportMode.addAsNew,
      );
      expect(p.generalView.data.customDayMinWidth, 160);
      await p.generalCommands.updateCustomDayMinWidth(null);
      expect(storage.data.generalMode.customDayMinWidth, isNull);
      await p.backups.importJson(backup, mode: AppImportMode.replaceAll);
      expect(p.generalView.data.customDayMinWidth, 160);
    },
  );

  test(
    'failed save rolls back width and disabled workspaces reject edits',
    () async {
      final storage = WorkspaceMemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
      );
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await p.generalCommands.updateCustomDayMinWidth(128);
      storage.saveError = StateError('disk full');
      await expectLater(
        p.generalCommands.updateCustomDayMinWidth(192),
        throwsStateError,
      );
      expect(p.generalView.data.customDayMinWidth, 128);
      expect(storage.data.generalMode.customDayMinWidth, 128);
      await p.generalCommands.updateCustomDayMinWidth(128);
      await p.workspaces.setEnabled(AppMode.general, false);
      await expectLater(
        p.generalCommands.updateCustomDayMinWidth(null),
        throwsStateError,
      );
      expect(p.generalView.data.customDayMinWidth, 128);
      await p.workspaces.setEnabled(AppMode.general, true);
      await p.generalCommands.updateCustomDayMinWidth(null);
      expect(p.generalView.data.customDayMinWidth, isNull);
    },
  );
}
