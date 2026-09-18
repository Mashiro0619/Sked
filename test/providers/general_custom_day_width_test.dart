import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

import '../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      await p.setGeneralDateRange(range);
      final date = p.selectedGeneralDate;
      final revision = p.generalDateFocusRevision;
      await p.updateGeneralCustomDayMinWidth(160);
      expect(p.generalCustomDayMinWidth, 160);
      expect(storage.data.generalMode.customDayMinWidth, 160);
      expect(p.customGeneralDateRange, range);
      expect(p.selectedGeneralDate, date);
      expect(p.generalDateFocusRevision, revision);
      await p.updateGeneralDisplaySettings(
        showWeekends: false,
        dayStartHour: 5,
      );
      expect(p.generalCustomDayMinWidth, 160);
      final restarted = await workspaceProvider(storage: storage);
      addTearDown(restarted.dispose);
      expect(restarted.generalCustomDayMinWidth, 160);
      final backup = await p.exportAppDataJson();
      expect(
        decodeAppBackup(backup).appData.generalMode.customDayMinWidth,
        160,
      );
      final ids = p.generalSchedules.map((s) => s.id).toList();
      await p.importSelectedGeneralSchedulesJson(
        p.exportSelectedGeneralSchedulesJson(ids),
        scheduleIds: ids,
        mode: GeneralScheduleImportMode.addAsNew,
      );
      await p.importGeneralSchedulesIcs(
        'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:width-import\r\nDTSTART:20260909T090000\r\nDTEND:20260909T100000\r\nSUMMARY:Imported\r\nEND:VEVENT\r\nEND:VCALENDAR',
        mode: GeneralScheduleImportMode.addAsNew,
      );
      expect(p.generalCustomDayMinWidth, 160);
      await p.updateGeneralCustomDayMinWidth(null);
      expect(storage.data.generalMode.customDayMinWidth, isNull);
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      expect(p.generalCustomDayMinWidth, 160);
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
      await p.updateGeneralCustomDayMinWidth(128);
      storage.saveError = StateError('disk full');
      await expectLater(
        p.updateGeneralCustomDayMinWidth(192),
        throwsStateError,
      );
      expect(p.generalCustomDayMinWidth, 128);
      expect(storage.data.generalMode.customDayMinWidth, 128);
      await p.updateGeneralCustomDayMinWidth(128);
      await p.setWorkspaceEnabled(AppMode.general, false);
      await expectLater(
        p.updateGeneralCustomDayMinWidth(null),
        throwsStateError,
      );
      expect(p.generalCustomDayMinWidth, 128);
      await p.setWorkspaceEnabled(AppMode.general, true);
      await p.updateGeneralCustomDayMinWidth(null);
      expect(p.generalCustomDayMinWidth, isNull);
    },
  );
}
