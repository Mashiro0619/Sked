import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/category_manager_harness.dart';
import '../support/workspace_harness.dart';

void main() {
  test(
    'category color persistence preserves latest fields and rolls back failure',
    () async {
      final storage = categoryManagerStorage();
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(p.dispose);
      await p.renameGeneralSchedule('category-1', 'Current name');
      await p.updateGeneralScheduleVisibility('category-1', false);
      final before = p.generalSchedules[1];
      storage.saveError = StateError('Expected color failure');
      await expectLater(
        p.updateGeneralScheduleColor('category-1', 0xff123456),
        throwsStateError,
      );
      expect(p.generalSchedules[1].colorValue, before.colorValue);
      await p.updateGeneralScheduleColor(
        'category-1',
        generalCalendarColorSlot6Value,
      );
      final after = p.generalSchedules[1];
      expect(after.name, before.name);
      expect(after.isVisible, false);
      expect(after.events.length, before.events.length);
      expect(after.colorValue, generalCalendarColorSlot6Value);
      expect(
        storage.data.generalMode.schedules[1].colorValue,
        generalCalendarColorSlot6Value,
      );
    },
  );
  test('category color cannot recreate deleted category or write into disabled workspace', () async {
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: categoryManagerStorage(),
    );
    addTearDown(p.dispose);
    await p.deleteGeneralSchedule('category-1');
    await p.updateGeneralScheduleColor('category-1', 0xff123456);
    expect(p.generalSchedules.any((s) => s.id == 'category-1'), isFalse);
    await p.setWorkspaceEnabled(AppMode.general, false);
    await expectLater(
      p.updateGeneralScheduleColor('category-0', 0xff123456),
      throwsStateError,
    );
  });
}
