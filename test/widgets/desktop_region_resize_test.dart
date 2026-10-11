import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_result_editor_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/widgets/period_time_set_manager.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
final _windows = TargetPlatformVariant.only(TargetPlatform.windows);

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
}

Future<void> _mount(
  WidgetTester t,
  TimetableProvider provider,
  DesktopLayoutPreferences preferences, {
  Widget? home,
  TextDirection direction = TextDirection.ltr,
}) async {
  await t.pumpWidget(
    ChangeNotifierProvider<DesktopLayoutPreferences>.value(
      value: preferences,
      child: WorkspaceHarness(
        provider: provider,
        home: home,
        textDirection: direction,
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _drag(WidgetTester t, Finder handle, Offset delta) async {
  final gesture = await t.startGesture(
    t.getCenter(handle),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(delta / 2);
  await t.pump();
  await gesture.moveBy(delta / 2);
  await t.pump();
  await gesture.up();
  await t.pumpAndSettle();
}

String _importDraft() => jsonEncode({
  'name': 'Resize timetable',
  'startDate': '2026-09-07',
  'totalWeeks': 16,
  'periodTimeSet': {
    'name': 'Periods',
    'periodTimes': [
      {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
    ],
  },
  'courses': [
    {
      'name': 'Retained course',
      'dayOfWeek': 1,
      'semesterWeeks': [1, 2],
      'periods': [1],
      'startMinutes': 480,
      'endMinutes': 525,
    },
  ],
});

void main() {
  for (final (home, region, handleKey, delta)
      in <(Widget, DesktopLayoutRegion, String, Offset)>[
        (
          const SettingsPage(),
          DesktopLayoutRegion.settingsNavigation,
          'settings-navigation-resize',
          const Offset(110, 0),
        ),
        (
          const PeriodTimeSetManagerPage(),
          DesktopLayoutRegion.periodTimeSets,
          'period-time-sets-resize',
          const Offset(110, 0),
        ),
        (
          const ThemeSettingsPage(),
          DesktopLayoutRegion.themePreview,
          'theme-preview-resize',
          const Offset(-110, 0),
        ),
      ]) {
    testWidgets(
      '${region.name} mouse boundary survives narrow reflow and reopening',
      (t) async {
        _viewport(t, const Size(1440, 900));
        final p = await workspaceProvider();
        final preferences = DesktopLayoutPreferences.memory();
        addTearDown(p.dispose);
        addTearDown(preferences.dispose);
        await _mount(t, p, preferences, home: home);
        final handle = _key(handleKey);
        final before = t.getCenter(handle);
        await _drag(t, handle, delta);
        final after = t.getCenter(handle);
        expect((after.dx - before.dx).abs(), greaterThan(60));
        final saved = preferences.preferenceFor(region)?.width;
        expect(saved, isNotNull);
        t.view.physicalSize = const Size(650, 800);
        await t.pumpAndSettle();
        expect(handle, findsNothing);
        expect(preferences.preferenceFor(region)?.width, saved);
        t.view.physicalSize = const Size(1440, 900);
        await t.pumpAndSettle();
        expect(t.getCenter(handle).dx, closeTo(after.dx, .01));
        await t.pumpWidget(const SizedBox.shrink());
        await _mount(t, p, preferences, home: home);
        expect(t.getCenter(handle).dx, closeTo(after.dx, .01));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: _windows,
    );
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'JSON preview boundary retains exact draft and caps content ($direction)',
      (t) async {
        _viewport(t, const Size(1440, 900));
        final p = await workspaceProvider();
        final preferences = DesktopLayoutPreferences.memory();
        addTearDown(p.dispose);
        addTearDown(preferences.dispose);
        await _mount(
          t,
          p,
          preferences,
          home: SchoolImportResultEditorPage(initialText: _importDraft()),
          direction: direction,
        );
        final field = find.byType(TextField);
        final element = t.element(field);
        final draft = '  ${_importDraft()}\n';
        await t.enterText(field, draft);
        final handle = _key('school-import-preview-resize');
        final sign = direction == TextDirection.ltr ? -1.0 : 1.0;
        await _drag(t, handle, Offset(3000 * sign, 0));
        expect(t.getSize(field).width, greaterThanOrEqualTo(624));
        final widthAtLimit = t
            .getSize(_key('school-import-json-preview'))
            .width;
        await _drag(t, handle, Offset(-80 * sign, 0));
        expect(
          t.getSize(_key('school-import-json-preview')).width,
          lessThan(widthAtLimit),
        );
        expect(t.element(field), same(element));
        expect(t.widget<TextField>(field).controller!.text, draft);
        t.view.physicalSize = const Size(650, 800);
        await t.pumpAndSettle();
        expect(t.element(field), same(element));
        expect(t.widget<TextField>(field).controller!.text, draft);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: _windows,
    );
  }
}
