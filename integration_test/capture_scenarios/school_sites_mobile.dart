import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/school_web_import_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/sked_confirmation_dialog.dart';

import '../../test/support/workspace_harness.dart';
import '../support/visual_capture_session.dart';

const _shortSite = SchoolSite(name: 'a', loginUrl: 'https://vpn.czu.cn');
const _longUrl =
    'https://vpn.czu.cn/portal/authentication/student/timetable/login'
    '?redirect=https%3A%2F%2Fstudent.example.edu%2Fsemester%2F2026';
const _openKey = ValueKey('capture-open-school-sites');
const _scrollKey = PageStorageKey('school-sites-scroll');

class _MemorySchoolSiteStore extends SchoolSiteStore {
  _MemorySchoolSiteStore(List<SchoolSite> sites)
    : source = encodeSchoolSites(sites),
      super.base();

  String source;
  int writes = 0;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String value) async {
    writes++;
    source = value;
  }

  @override
  Future<String?> filePath() async => 'memory://capture-school-sites';
}

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _fields() => find.descendant(
  of: find.byType(AppSheetScaffold),
  matching: find.byType(TextField),
);

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('school sites keep inline editing and a shared mobile header', (
    tester,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final wasAvailable = DesktopWindowBridge.instance.available;
    final previousPlatform = debugDefaultTargetPlatformOverride;
    final captures = VisualCaptureSession(label: 'school-sites-mobile');
    const profiles = [
      ('phone-320-en-2x', Size(320, 900), 2.0, 'en', TargetPlatform.android),
      ('phone-360-zh', Size(360, 850), 1.0, 'zh', TargetPlatform.android),
      ('phone-393-zh', Size(393, 852), 1.0, 'zh', TargetPlatform.android),
      ('landscape-800-zh', Size(800, 393), 1.0, 'zh', TargetPlatform.android),
      ('windows-1280-zh', Size(1280, 900), 1.0, 'zh', TargetPlatform.windows),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    try {
      for (final (name, size, scale, language, platform) in profiles) {
        final android = platform == TargetPlatform.android;
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available = !android && wasAvailable;
        tester.view.physicalSize = size;
        final safe = android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        tester.view.viewInsets = const FakeViewPadding();
        tester.view.padding = safe;
        tester.view.viewPadding = safe;
        final provider = await workspaceProvider(locale: language);
        final boundary = GlobalKey();
        final longSite = SchoolSite(
          name: language == 'zh' ? '学校教务管理系统本科研究生课程表与校园统一身份认证登录入口' : 'School administration and student timetable portal with campus authentication',
          loginUrl: _longUrl,
        );
        final denseSites = [
          _shortSite,
          longSite,
          for (var index = 3; index <= 20; index++)
            SchoolSite(
              name: language == 'zh'
                  ? '第 $index 个学校教务与课程表登录入口'
                  : 'School $index administration and timetable portal',
              loginUrl: 'https://school-$index.example.edu/student/timetable',
            ),
        ];
        var mount = 0;
        var siteCount = 0;
        var simulatedImeBottom = 0.0;

        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<_MemorySchoolSiteStore> open(List<SchoolSite> sites) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          final store = _MemorySchoolSiteStore(sites);
          final service = SchoolSiteService(store: store);
          siteCount = sites.length;
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                key: ValueKey('$name-school-sites-${mount++}'),
                provider: provider,
                locale: Locale(language),
                textScale: scale,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: FilledButton(
                        key: _openKey,
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) =>
                                SchoolSitesPage(siteService: service),
                          ),
                        ),
                        child: const Text('Open school sites'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tap(find.byKey(_openKey));
          expect(find.byType(SchoolSitesPage), findsOneWidget);
          expect(_key('school-site-edit-0').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          return store;
        }

        Future<void> capture(String scene) => captures.capture(
          tester,
          boundary: find.byKey(boundary),
          name: '$name-$scene',
          pixelRatio: android ? 2 : 1,
          metadata: {
            'locale': language,
            'textScale': scale,
            'siteCount': siteCount,
            'viewDevicePixelRatio': 1,
            'simulatedImeBottomDp': simulatedImeBottom,
            'fixture': 'Production SchoolSitesPage with memory SchoolSiteStore',
            'evidence': android
                ? 'Windows Flutter rendering; Android platform style, geometry, '
                      'safe areas, touch and keyboard insets simulated. '
                      'No Android device or system IME acceptance.'
                : 'Windows Flutter client rendering and injected input with '
                      'isolated memory fixtures and simulated 1280dp viewport.',
          },
        );

        Future<void> setIme(double bottom) async {
          simulatedImeBottom = bottom;
          tester.view.viewInsets = FakeViewPadding(bottom: bottom);
          tester.view.padding = bottom > 0
              ? FakeViewPadding(top: safe.top)
              : safe;
          await tester.pumpAndSettle();
        }

        Future<void> showEditor(int index, SchoolSite site) async {
          final edit = _key('school-site-edit-$index');
          if (edit.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              edit,
              240,
              scrollable: find
                  .descendant(
                    of: find.byKey(_scrollKey),
                    matching: find.byType(Scrollable),
                  )
                  .first,
              maxScrolls: 40,
            );
          }
          await tap(edit);
          expect(find.byType(AppSheetScaffold), findsOneWidget);
          expect(
            find.byType(SchoolWebImportPage, skipOffstage: false),
            findsNothing,
            reason: 'The independent edit target must not open the site.',
          );
          expect(_fields(), findsNWidgets(2));
          expect(
            tester.widget<TextField>(_fields().first).controller!.text,
            site.name,
          );
          expect(
            tester.widget<TextField>(_fields().last).controller!.text,
            site.loginUrl,
          );
        }

        try {
          final singleStore = await open(const [_shortSite]);
          await capture('single-site');
          expect(singleStore.writes, 0);

          final store = await open([_shortSite, longSite]);
          final originalSource = store.source;
          final l = AppLocalizations.of(
            tester.element(find.byType(SchoolSitesPage)),
          );
          expect(find.byType(BackButton).hitTestable(), findsOneWidget);
          expect(
            find.byTooltip(l.schoolSitesAdd).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byTooltip(l.schoolHtmlImportEntry).hitTestable(),
            findsOneWidget,
          );
          await capture('two-sites');

          await showEditor(0, _shortSite);
          await capture('edit-short');
          final draftName = language == 'zh' ? 'a（未保存草稿）' : 'a - unsaved draft';
          await tester.enterText(_fields().first, draftName);
          await tester.pumpAndSettle();
          if (android) {
            await setIme(size.height < 500 ? 184 : 300);
            expect(
              find.widgetWithText(FilledButton, l.save).hitTestable(),
              findsOneWidget,
            );
            expect(
              find.widgetWithText(TextButton, l.cancel).hitTestable(),
              findsOneWidget,
            );
            await capture('edit-short-ime');
            await setIme(0);
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(SkedDiscardDraftDialog), findsOneWidget);
          await capture('discard-confirmation');
          await tap(
            find.descendant(
              of: find.byType(SkedDiscardDraftDialog),
              matching: find.widgetWithText(TextButton, l.cancel),
            ),
          );
          expect(find.byType(SkedDiscardDraftDialog), findsNothing);
          expect(
            tester.widget<TextField>(_fields().first).controller!.text,
            draftName,
          );
          await capture('draft-retained');
          await tap(find.widgetWithText(TextButton, l.cancel));
          await tap(find.widgetWithText(FilledButton, l.discardChangesAndExit));
          expect(find.byType(AppSheetScaffold), findsNothing);
          expect(store.source, originalSource);
          expect(store.writes, 0);
          await capture('list-after-discard');

          await showEditor(1, longSite);
          await capture('edit-long');
          await tap(find.widgetWithText(TextButton, l.cancel));
          expect(find.byType(AppSheetScaffold), findsNothing);
          expect(store.writes, 0);
          await tap(find.byType(BackButton).hitTestable());
          expect(find.byType(SchoolSitesPage), findsNothing);
          expect(find.byKey(_openKey).hitTestable(), findsOneWidget);

          final denseStore = await open(denseSites);
          await capture('twenty-sites-expanded');
          final scroll = find.byKey(_scrollKey);
          await tester.drag(scroll, const Offset(0, -440));
          await tester.pumpAndSettle();
          final scrollable = find
              .descendant(of: scroll, matching: find.byType(Scrollable))
              .first;
          expect(
            tester.state<ScrollableState>(scrollable).position.pixels,
            greaterThan(0),
          );
          expect(find.byType(BackButton).hitTestable(), findsOneWidget);
          expect(
            find.byTooltip(l.schoolSitesAdd).hitTestable(),
            findsOneWidget,
          );
          await capture('twenty-sites-collapsed');
          await tester.scrollUntilVisible(
            _key('school-site-edit-19'),
            300,
            scrollable: scrollable,
            maxScrolls: 60,
          );
          await tester.pumpAndSettle();
          expect(_key('school-site-edit-19').hitTestable(), findsOneWidget);
          expect(find.text(denseSites.last.name), findsOneWidget);
          await capture('twenty-sites-last');
          await tap(find.byType(BackButton).hitTestable());
          expect(find.byKey(_openKey).hitTestable(), findsOneWidget);
          expect(denseStore.writes, 0);
          expect(tester.takeException(), isNull);
        } finally {
          await setIme(0);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          provider.dispose();
        }
      }
      await captures.writeManifest(expectedCount: 54);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
      DesktopWindowBridge.instance.available = wasAvailable;
    }
  });
}
