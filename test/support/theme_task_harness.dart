import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

import 'workspace_harness.dart';

class ThemeTaskStorage extends WorkspaceMemoryStorage {
  ThemeTaskStorage(super.data);
  Completer<void>? pending;
  int writes = 0;
  @override
  Future<void> save(AppData data) async {
    writes++;
    await pending?.future;
    await super.save(data);
  }
}

Finder themeTaskKey(String value) => find.byKey(ValueKey(value));
Future<(TimetableProvider, ThemeTaskStorage)> mountThemeTask(
  WidgetTester t, {
  String kind = 'seed',
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1440, 1000);
  addTearDown(t.view.reset);
  final storage = ThemeTaskStorage(
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
      themeColorMode: kind == 'seed'
          ? themeColorModeSingle
          : themeColorModeColorful,
    ),
  );
  final p = await workspaceProvider(
    mode: kind == 'category' ? AppMode.general : AppMode.student,
    storage: storage,
  );
  if (kind == 'category') {
    await p.switchMode(AppMode.general);
    await p.updateThemeColorMode(
      themeColorModeColorful,
      workspace: AppMode.general,
    );
  }
  if (kind == 'course') {
    await p.updateColorfulCourseTextSettings(
      mode: colorfulCourseTextColorModeCustom,
      customColorValue: 0xff654321,
    );
  }
  addTearDown(() {
    if (storage.pending?.isCompleted == false) storage.pending!.complete();
    p.dispose();
  });
  await t.pumpWidget(
    WorkspaceHarness(provider: p, home: const ThemeSettingsPage()),
  );
  await t.pumpAndSettle();
  final entry = kind == 'seed'
      ? find.text('Custom color').last
      : themeTaskKey(
          kind == 'category'
              ? 'theme-general-calendar-color-${p.generalSchedules.first.id}'
              : kind == 'value'
              ? 'theme-ui-color-primary'
              : 'theme-ui-color-$colorfulCourseTextColorKey',
        );
  await t.scrollUntilVisible(
    entry,
    200,
    maxScrolls: 20,
    scrollable: find
        .descendant(
          of: find.byType(ThemeSettingsPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.pumpAndSettle();
  await t.tap(entry);
  await t.pumpAndSettle();
  return (p, storage);
}

Finder themeApply(String kind) => find.widgetWithText(
  FilledButton,
  kind == 'seed' ? 'Apply color' : 'Apply settings',
);
Finder get themeTask => find.byType(SkedTaskDialog);
