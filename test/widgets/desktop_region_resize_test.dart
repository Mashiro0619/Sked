import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_result_editor_page.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/widgets/period_time_set_manager.dart';

import '../support/mobile_layout_data.dart';
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

class _SiteStore extends SchoolSiteStore {
  _SiteStore() : super.base();
  String source = encodeSchoolSites(const [
    SchoolSite(name: 'Resize school', loginUrl: 'https://school.example'),
  ]);
  @override
  Future<String?> load() async => source;
  @override
  Future<void> save(String value) async => source = value;
  @override
  Future<String?> filePath() async => 'memory://resize-sites';
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

Future<TimetableProvider> _calendarProvider({String view = generalViewWeek}) {
  final base = mobileLayoutData(locale: 'en');
  const calendar = 'resize-calendar';
  return workspaceProvider(
    storage: WorkspaceMemoryStorage(
      base.copyWith(
        activeMode: AppMode.general,
        generalMode: base.generalMode.copyWith(
          defaultView: view,
          selectedDateIso: '2026-09-23',
          activeScheduleId: calendar,
          schedules: [
            GeneralSchedule(
              id: calendar,
              name: 'Resize calendar',
              events: [
                for (var i = 0; i < 8; i++)
                  GeneralEvent(
                    id: 'resize-all-day-$i',
                    calendarId: calendar,
                    title: 'Resize all day $i',
                    startDateTimeIso: '2026-09-22T00:00:00.000',
                    endDateTimeIso: '2026-09-25T00:00:00.000',
                    isAllDay: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

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

  testWidgets(
    'school browser and editor share a boundary without replacing the draft',
    (t) async {
      _viewport(t, const Size(1440, 900));
      final p = await workspaceProvider();
      final preferences = DesktopLayoutPreferences.memory();
      final sites = _SiteStore();
      addTearDown(p.dispose);
      addTearDown(preferences.dispose);
      await _mount(
        t,
        p,
        preferences,
        home: SchoolSitesPage(siteService: SchoolSiteService(store: sites)),
      );
      await _drag(t, _key('school-sites-resize'), const Offset(100, 0));
      final browserBoundary = t.getCenter(_key('school-sites-resize')).dx;
      final l = AppLocalizations.of(t.element(find.byType(SchoolSitesPage)));
      await t.tap(find.widgetWithText(OutlinedButton, l.schoolSitesEdit));
      await t.pumpAndSettle();
      expect(
        t.getCenter(_key('school-site-editor-resize')).dx,
        closeTo(browserBoundary, .01),
      );
      final name = find.byType(TextField).first;
      final element = t.element(name);
      await t.enterText(name, 'Retained school draft');
      await _drag(t, _key('school-site-editor-resize'), const Offset(80, 0));
      t.view.physicalSize = const Size(650, 800);
      await t.pumpAndSettle();
      expect(t.element(name), same(element));
      expect(
        t.widget<TextField>(name).controller!.text,
        'Retained school draft',
      );
      expect(sites.source, isNot(contains('Retained school draft')));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: _windows,
  );

  testWidgets(
    'all-day mouse height reveals rows and survives collapse and reopening',
    (t) async {
      _viewport(t, const Size(1440, 1000));
      final p = await _calendarProvider();
      final preferences = DesktopLayoutPreferences.memory();
      addTearDown(p.dispose);
      addTearDown(preferences.dispose);
      await _mount(t, p, preferences);
      expect(find.text('Resize all day 3'), findsNothing);
      final strip = _key('general-all-day-timeline');
      final before = t.getSize(strip).height;
      await _drag(t, _key('general-all-day-resize'), const Offset(0, 140));
      final after = t.getSize(strip).height;
      expect(after, greaterThan(before + 60));
      expect(find.text('Resize all day 3').hitTestable(), findsOneWidget);
      final saved = preferences
          .preferenceFor(DesktopLayoutRegion.allDayTimeline)
          ?.height;
      expect(saved, isNotNull);
      await t.tap(_key('general-all-day-toggle'));
      await t.pumpAndSettle();
      expect(_key('general-all-day-collapsed-state'), findsOneWidget);
      expect(
        preferences.preferenceFor(DesktopLayoutRegion.allDayTimeline)?.height,
        saved,
      );
      await t.tap(_key('general-all-day-toggle'));
      await t.pumpAndSettle();
      expect(t.getSize(strip).height, closeTo(after, .01));
      await t.pumpWidget(const SizedBox.shrink());
      await _mount(t, p, preferences);
      expect(t.getSize(strip).height, closeTo(after, .01));
      expect(find.text('Resize all day 3').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: _windows,
  );

  testWidgets(
    'month agenda height protects the calendar and restores after a short window',
    (t) async {
      _viewport(t, const Size(900, 1100));
      final p = await _calendarProvider(view: generalViewMonth);
      final preferences = DesktopLayoutPreferences.memory();
      addTearDown(p.dispose);
      addTearDown(preferences.dispose);
      await _mount(t, p, preferences);
      final agenda = _key('general-month-stacked-agenda');
      final before = t.getSize(agenda).height;
      await _drag(
        t,
        _key('general-month-agenda-height-resize'),
        const Offset(0, -3000),
      );
      final after = t.getSize(agenda).height;
      expect(after, greaterThan(before));
      expect(
        t.getSize(_key('general-month-calendar-panel')).height,
        greaterThanOrEqualTo(388),
      );
      final saved = preferences
          .preferenceFor(DesktopLayoutRegion.monthAgendaBottom)
          ?.height;
      expect(saved, isNotNull);
      t.view.physicalSize = const Size(900, 700);
      await t.pumpAndSettle();
      expect(t.getSize(agenda).height, lessThan(after));
      expect(
        preferences
            .preferenceFor(DesktopLayoutRegion.monthAgendaBottom)
            ?.height,
        saved,
      );
      t.view.physicalSize = const Size(900, 1100);
      await t.pumpAndSettle();
      expect(t.getSize(agenda).height, closeTo(after, .01));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: _windows,
  );
}
