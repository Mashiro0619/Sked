import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
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
    final student = p.appData.studentMode.toJson();
    await p.updateGeneralDisplaySettings(fitWeekColumnsToWidth: false);
    await p.setSelectedGeneralDate(DateTime(2026, 10, 1));
    await p.updateGeneralDisplaySettings(showWeekends: false);
    expect(p.generalFitWeekColumnsToWidth, isFalse);
    expect(p.appData.studentMode.toJson(), student);
    final saved = AppData.fromJson(storage.data.toJson());
    final reloaded = await workspaceProvider(
      storage: WorkspaceMemoryStorage(saved),
      locale: 'zh',
    );
    addTearDown(reloaded.dispose);
    expect(reloaded.generalFitWeekColumnsToWidth, isFalse);
    expect(reloaded.appData.studentMode.toJson(), student);
    final backup = await reloaded.exportAppDataJson();
    await reloaded.updateGeneralDisplaySettings(fitWeekColumnsToWidth: true);
    await reloaded.importAppDataJson(backup, mode: AppImportMode.replaceAll);
    expect(reloaded.generalFitWeekColumnsToWidth, isFalse);
    expect(reloaded.appData.studentMode.toJson(), student);
    expect(reloaded.selectedGeneralDate, DateTime(2026, 10, 1));
  });
}
