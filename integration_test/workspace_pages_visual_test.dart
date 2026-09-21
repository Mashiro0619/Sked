import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/screens/developer_mode_page.dart';
import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_import_parse_page.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/screens/school_import_result_editor_page.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/timetable_display_settings_page.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/widgets/period_time_set_manager.dart';

import '../test/support/workspace_harness.dart';

class _PreviewSites extends SchoolSiteStore {
  _PreviewSites() : super.base();
  String source = encodeSchoolSites(const [
    SchoolSite(name: '示例大学教务系统', loginUrl: 'https://school.example/login'),
    SchoolSite(name: '研究生教学平台', loginUrl: 'https://graduate.example/login'),
  ]);
  @override
  Future<String?> load() async => source;
  @override
  Future<void> save(String value) async {
    source = value;
  }

  @override
  Future<String?> filePath() async => 'memory://visual-sites';
}

const _importJson = '''{
  "name": "导入校对样例", "startDate": "2026-09-07", "totalWeeks": 16,
  "periodTimeSet": {"name": "教学节次", "periodTimes": [
    {"index":1,"startMinutes":480,"endMinutes":525},
    {"index":2,"startMinutes":535,"endMinutes":580}]},
  "courses": [{"name":"线性代数","teacher":"张老师","location":"教学楼 A201",
    "dayOfWeek":1,"semesterWeeks":[1,2,3,4,5,6,7,8],"periods":[1,2],
    "startMinutes":480,"endMinutes":580}]
}''';

/// Screenshots of actual Flutter client rendering, never the surrounding desktop.
/// All data/services are memory fixtures; no network or platform reminders run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('render all settings and workflow pages with isolated fixtures', (
    tester,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final projectLicense = await File('LICENSE').readAsString();
    LicenseRegistry.addLicense(
      () => Stream.value(
        LicenseEntryWithLineBreaks(const ['Sked'], projectLicense),
      ),
    );
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/fusion-pages',
      ),
    );
    await output.create(recursive: true);
    final captures = <Map<String, Object?>>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final cases =
        <
          (
            String,
            Widget? Function(TimetableProvider, AgendaNotificationService),
          )
        >[
          for (final category in [
            SettingsDestination.appearance,
            SettingsDestination.notifications,
            SettingsDestination.language,
            SettingsDestination.data,
            SettingsDestination.features,
            SettingsDestination.about,
          ])
            (
              'settings-${category.name}',
              (p, n) => SettingsPage(
                initialDestination: category,
                initialWorkspace: AppMode.student,
                notificationService: n,
              ),
            ),
          (
            'course-outline',
            (p, n) => SettingsPage(
              initialDestination: SettingsDestination.appearance,
              initialWorkspace: AppMode.student,
              notificationService: n,
            ),
          ),
          ('category-editor', (p, n) => null),
          (
            'licenses',
            (p, n) => SettingsPage(
              initialDestination: SettingsDestination.about,
              notificationService: n,
            ),
          ),
          (
            'developer',
            (p, n) => DeveloperModePage(
              productivityBridge: AndroidProductivityBridge(enabled: false),
            ),
          ),
          (
            'import-source-unconfigured',
            (p, n) => const SchoolHtmlImportPage(),
          ),
          (
            'student-management',
            (p, n) => SettingsPage(
              initialDestination: SettingsDestination.student,
              notificationService: n,
            ),
          ),
          (
            'general-management',
            (p, n) => SettingsPage(
              initialDestination: SettingsDestination.general,
              notificationService: n,
            ),
          ),
          ('student-display', (p, n) => const TimetableDisplaySettingsPage()),
          ('general-display', (p, n) => const GeneralDisplaySettingsPage()),
          ('period-manager', (p, n) => const PeriodTimeSetManagerPage()),
          (
            'period-editor',
            (p, n) =>
                PeriodTimesPage(periodTimeSetId: p.periodTimeSets.first.id),
          ),
          (
            'school-sites',
            (p, n) => SchoolSitesPage(
              siteService: SchoolSiteService(store: _PreviewSites()),
            ),
          ),
          (
            'school-site-editor',
            (p, n) => SchoolSitesPage(
              siteService: SchoolSiteService(store: _PreviewSites()),
            ),
          ),
          ('parser-settings', (p, n) => const SchoolImportParserSettingsPage()),
          (
            'import-source',
            (p, n) => const SchoolHtmlImportPage(
              initialContent: '''2026 秋季学期
线性代数 · 周一第 1–2 节 · 第 1–8 周
张老师 · 教学楼 A201''',
              initialTitle: '教务系统课程表',
            ),
          ),
          (
            'import-result-json',
            (p, n) =>
                const SchoolImportResultEditorPage(initialText: _importJson),
          ),
          (
            'import-review',
            (p, n) => SchoolImportParsePage(
              provider: p,
              stream: Stream.value(
                ParseDone(
                  response: SchoolImportResponse.fromJson(<String, dynamic>{
                    'ok': true,
                    'meta': {
                      'parser': '本地视觉样例（未联网）',
                      'warnings': ['请校对学期周次与节次时间。'],
                    },
                    'timetable': jsonDecode(_importJson),
                  }),
                ),
              ),
            ),
          ),
          (
            'notification-troubleshooting',
            (p, n) => NotificationSettingsPage(
              notificationService: n,
              productivityBridge: AndroidProductivityBridge(enabled: false),
              troubleshooting: true,
            ),
          ),
        ];
    try {
      // Touch layouts are platform-style simulations rendered on Windows.
      // Their density must not inherit the Windows host's compact controls.
      for (final (size, scale, brightness, platform)
          in const <(Size, double, Brightness, TargetPlatform)>[
            (Size(360, 800), 1, Brightness.light, TargetPlatform.android),
            (Size(800, 1280), 1, Brightness.light, TargetPlatform.android),
            (Size(1280, 800), 1, Brightness.light, TargetPlatform.android),
            (Size(1440, 900), 1, Brightness.dark, TargetPlatform.windows),
            (Size(1280, 900), 2, Brightness.dark, TargetPlatform.windows),
          ]) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        tester.view.physicalSize = size;
        for (final (name, build) in cases) {
          final provider = await workspaceProvider(
            locale: 'zh',
            mode: name == 'category-editor' ? AppMode.general : AppMode.student,
          );
          if (name == 'import-source') {
            await provider.updateCustomSchoolImportBaseUrl(
              'https://example.invalid/v1',
            );
            await provider.updateCustomSchoolImportApiKey(
              'visual-fixture-not-a-real-key',
            );
            await provider.updateCustomSchoolImportModel(
              'visual-fixture-model',
            );
          }
          final notifications = AgendaNotificationService(
            enabled: true,
            gateway: MemoryAgendaNotificationGateway()
              ..permissionGranted = false,
            runtimeStore: MemoryAgendaNotificationRuntimeStore(),
          );
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: provider,
                locale: const Locale('zh'),
                textScale: scale,
                brightness: brightness,
                home: build(provider, notifications),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (name == 'school-site-editor') {
            final l = AppLocalizations.of(
              tester.element(find.byType(SchoolSitesPage)),
            );
            await tester.tap(find.byTooltip(l.schoolSitesEdit).first);
            await tester.pumpAndSettle();
          }
          if (name == 'licenses') {
            final l = AppLocalizations.of(
              tester.element(find.byType(SettingsPage)),
            );
            await tester.tap(find.text(l.openSourceLicenses));
            await tester.pumpAndSettle();
            expect(find.byType(LicensePage), findsOneWidget);
            await tester.tap(find.widgetWithText(ListTile, 'Sked'));
            await tester.pumpAndSettle();
          }
          if (name == 'course-outline') {
            final card = find.byKey(
              const ValueKey('theme-outline-settings-card'),
            );
            for (var i = 0; i < 12 && card.evaluate().isEmpty; i++) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -240),
              );
              await tester.pumpAndSettle();
            }
            await tester.ensureVisible(card);
            await tester.pumpAndSettle();
            await tester.tap(
              find.descendant(of: card, matching: find.byType(InkWell)),
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('theme-outline-settings-page')),
              findsOneWidget,
            );
          }
          if (name == 'category-editor') {
            final resources = find
                .byKey(const ValueKey('workspace-resource-open'))
                .hitTestable();
            if (resources.evaluate().isNotEmpty) {
              await tester.tap(resources);
            } else {
              await tester.tap(
                find.byKey(const ValueKey('general-calendar-selector')),
              );
            }
            await tester.pumpAndSettle();
            final calendar = provider.generalSchedules.first;
            final tile = find.byKey(
              ValueKey('calendar-manager-tile-${calendar.id}'),
            );
            // Activate the name independently of the row's visibility action.
            await tester.tap(
              find.descendant(of: tile, matching: find.text(calendar.name)),
            );
            await tester.pumpAndSettle();
          }
          if (name == 'category-editor') {
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(find.byType(BackButton), findsOneWidget);
            expect(
              find.byKey(const ValueKey('rename-calendar-field')),
              findsOneWidget,
            );
            expect(provider.generalSchedules.first.isVisible, isTrue);
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '$name at $size / $scale',
          );
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final filename = '$name-${size.width.toInt()}-${scale}x.png';
          await File('${output.path}/$filename')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
          captures.add({
            'file': filename,
            'page': name,
            'widthDp': size.width,
            'heightDp': size.height,
            'textScale': scale,
            'brightness': brightness.name,
            'platform': defaultTargetPlatform.name,
          });
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          provider.dispose();
          notifications.dispose();
        }
      }
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'kind': 'Flutter client content rendered on Windows with memory fixtures; not native frame or Android hardware',
          'captures': captures,
        }),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = true;
    }
  });
}
