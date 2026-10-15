import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/controllers/app_backup_controller.dart' show AppImportMode;
import 'package:sked/services/general_calendar_service.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('general fit preference defaults on for fresh and legacy data', () {
    expect(GeneralScheduleData.createDefault().fitWeekColumnsToWidth, isTrue);
    expect(GeneralScheduleData.fromJson({}).fitWeekColumnsToWidth, isTrue);
    final old = mobileLayoutData().generalMode.toJson()
      ..remove('fitWeekColumnsToWidth');
    expect(GeneralScheduleData.fromJson(old).fitWeekColumnsToWidth, isTrue);
    expect(
      GeneralScheduleData.fromJson({'fitWeekColumnsToWidth': false})
          .fitWeekColumnsToWidth,
      isFalse,
    );
    for (final invalid in [null, 'false', 0, [], {}]) {
      expect(
        GeneralScheduleData.fromJson({...old, 'fitWeekColumnsToWidth': invalid})
            .fitWeekColumnsToWidth,
        isTrue,
      );
    }
  });

  test(
    'general fit survives serialization, normalization and unrelated edits',
    () {
      const service = GeneralCalendarService();
      final data = mobileLayoutData().generalMode.copyWith(
        fitWeekColumnsToWidth: false,
      );
      expect(data.toJson()['fitWeekColumnsToWidth'], isFalse);
      expect(
        GeneralScheduleData.fromJson(data.toJson()).fitWeekColumnsToWidth,
        isFalse,
      );
      expect(data.normalized().fitWeekColumnsToWidth, isFalse);
      expect(
        data.copyWith(defaultView: generalViewDay).fitWeekColumnsToWidth,
        isFalse,
      );
      expect(
        service
            .setSelectedDate(data, DateTime(2026, 10, 1))
            .fitWeekColumnsToWidth,
        isFalse,
      );
      expect(
        service
            .updateDisplaySettings(data, showWeekends: false)
            .fitWeekColumnsToWidth,
        isFalse,
      );
      expect(
        service
            .updateDisplaySettings(data, fitWeekColumnsToWidth: true)
            .fitWeekColumnsToWidth,
        isTrue,
      );
    },
  );

  test('general and student preferences stay independent across reload and backup restore', () async {
    final storage = WorkspaceMemoryStorage(mobileLayoutData());
    final p = await workspaceProvider(storage: storage, locale: 'zh');
    addTearDown(p.dispose);
    final student = p.workspaceView.data.studentMode.toJson();
    await p.generalCommands.updateDisplaySettings(fitWeekColumnsToWidth: false);
    await p.generalNavigation.setSelectedDate(DateTime(2026, 10, 1));
    await p.generalCommands.updateDisplaySettings(showWeekends: false);
    expect(p.generalView.data.fitWeekColumnsToWidth, isFalse);
    expect(p.workspaceView.data.studentMode.toJson(), student);
    final saved = AppData.fromJson(storage.data.toJson());
    final reloaded = await workspaceProvider(
      storage: WorkspaceMemoryStorage(saved),
      locale: 'zh',
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.generalView.data.fitWeekColumnsToWidth, isFalse);
    expect(reloaded.workspaceView.data.studentMode.toJson(), student);
    final backup = await reloaded.backups.exportJson();
    await reloaded.generalCommands.updateDisplaySettings(
      fitWeekColumnsToWidth: true,
    );
    await reloaded.backups.importJson(backup, mode: AppImportMode.replaceAll);
    expect(reloaded.generalView.data.fitWeekColumnsToWidth, isFalse);
    expect(reloaded.workspaceView.data.studentMode.toJson(), student);
    expect(reloaded.generalView.selectedDate, DateTime(2026, 10, 1));
  });
}
