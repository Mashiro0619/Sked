import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/settings_catalog.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/adaptive_navigation_scope.dart';
import 'package:sked/widgets/adaptive_settings_scaffold.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/settings_page_header.dart';

import '../support/workspace_harness.dart';

String _title(SettingsDestination destination, AppLocalizations l) =>
    switch (destination) {
      SettingsDestination.appearance => l.theme,
      SettingsDestination.notifications => l.notificationSettingsSection,
      SettingsDestination.language => l.language,
      SettingsDestination.data => l.settingsDataPrivacy,
      SettingsDestination.features => l.workspaceFeatures,
      SettingsDestination.about => l.settingsSectionAbout,
      SettingsDestination.student ||
      SettingsDestination.schoolImport => l.dataImportExport,
      SettingsDestination.general => l.generalScheduleImportExport,
      SettingsDestination.studentPreferences => l.timetableDisplaySettings,
      SettingsDestination.generalPreferences => l.generalDisplaySettings,
      SettingsDestination.parser => l.schoolImportParserSettingsTitle,
      SettingsDestination.notificationPermissions =>
        l.notificationTroubleshooting,
    };

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

int _headingCount(WidgetTester t, String title) {
  final root =
      t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
  var count = 0;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isHeader && data.label == title) count++;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return count;
}

ScrollPosition _settingsPosition(WidgetTester tester) {
  final list = find.descendant(
    of: find.byType(SettingsPageScaffold),
    matching: find.byType(CustomScrollView),
  );
  return tester
      .state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      )
      .position;
}

void main() {
  for (final destination in SettingsDestination.values) {
    testWidgets(
      '${destination.name} uses the shared settings title through its real destination',
      (t) async {
        _viewport(t, const Size(393, 900));
        final p = await workspaceProvider(locale: 'zh');
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 32),
                ),
                child: SettingsPage(initialDestination: destination),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final header = find.byType(SettingsPageHeader);
        expect(header, findsOneWidget);
        final context = t.element(header);
        final title = _title(destination, AppLocalizations.of(context));
        expect(t.widget<SettingsPageHeader>(header).title, title);
        final actualBar = find.descendant(
          of: header,
          matching: find.byWidgetPredicate((widget) => widget is AppBar),
        );
        expect(t.getRect(actualBar).top, 24);
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        final expanded = find.byKey(const ValueKey('settings-expanded-title'));
        if (Theme.of(context).platform == TargetPlatform.android) {
          final bar = t.widget<SliverAppBar>(
            find.byKey(const ValueKey('settings-page-app-bar')),
          );
          expect(bar.pinned, isTrue);
          expect(bar.primary, isFalse);
          expect(t.widget<Text>(expanded).data, title);
          expect(t.widget<Text>(expanded).style!.fontSize, 32);
          final back = t.widget<BackButton>(find.byType(BackButton));
          expect(back.style!.shape!.resolve({}), isA<CircleBorder>());
        } else {
          final bar = t.widget<WorkbenchAppBar>(
            find.byKey(const ValueKey('settings-page-app-bar')),
          );
          expect(bar.primary, isFalse);
          expect(t.getSize(actualBar).height, 48);
          expect(expanded, findsNothing);
          expect(find.byType(DesktopDragRegion), findsWidgets);
          expect(find.byType(DesktopCaptionSpacer), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'desktop destination headers align with window controls at $scale text scale',
      (t) async {
        _viewport(t, const Size(1600, 900));
        DesktopWindowBridge.instance.available = true;
        addTearDown(() => DesktopWindowBridge.instance.available = false);
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        for (final destination in SettingsDestination.values) {
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              textScale: scale,
              home: SettingsPage(
                key: ValueKey(destination),
                initialDestination: destination,
              ),
            ),
          );
          await t.pumpAndSettle();
          final bar = find.byKey(const ValueKey('settings-page-app-bar'));
          final rect = t.getRect(bar);
          final divider = find.byKey(const ValueKey('desktop-window-divider'));
          expect(rect.top, 0, reason: destination.name);
          expect(rect.height, scale == 1 ? 48 : 64, reason: destination.name);
          expect(
            rect.bottom,
            t.getRect(divider).bottom,
            reason: '${destination.name} aligns with native window controls',
          );
          final drag = find.descendant(
            of: bar,
            matching: find.byType(DesktopDragRegion),
          );
          expect(t.getRect(drag), rect, reason: destination.name);
          final caption = find.descendant(
            of: bar,
            matching: find.byType(DesktopCaptionSpacer),
          );
          expect(
            t.getRect(caption).right,
            rect.right,
            reason: destination.name,
          );
          expect(t.getSize(caption).width, 138, reason: destination.name);
          expect(t.takeException(), isNull, reason: destination.name);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'desktop language search stays outside the title bar across resizing at $scale text scale',
      (t) async {
        _viewport(t, const Size(1600, 900));
        DesktopWindowBridge.instance.available = true;
        addTearDown(() => DesktopWindowBridge.instance.available = false);
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            textScale: scale,
            home: const SettingsPage(),
          ),
        );
        await t.pumpAndSettle();
        final languageEntry = find.byKey(const ValueKey('settings-language'));
        await t.ensureVisible(languageEntry);
        await t.pumpAndSettle();
        await t.tap(languageEntry);
        await t.pumpAndSettle();
        final bar = find.byKey(const ValueKey('settings-page-app-bar'));
        final search = find.byKey(const ValueKey('language-search'));
        await t.enterText(search, 'English');
        await t.pumpAndSettle();
        for (final width in [1600.0, 393.0, 1600.0]) {
          t.view.physicalSize = Size(width, 900);
          await t.pumpAndSettle();
          final rect = t.getRect(bar);
          expect(rect.height, scale == 1 ? 48 : 64);
          expect(
            rect.bottom,
            t
                .getRect(find.byKey(const ValueKey('desktop-window-divider')))
                .bottom,
          );
          if (width == 1600) {
            final sidebar = find
                .byWidgetPredicate(
                  (widget) =>
                      widget is WorkbenchAppBar &&
                      widget.key != const ValueKey('settings-page-app-bar'),
                )
                .hitTestable();
            expect(sidebar, findsOneWidget);
            expect(t.getRect(sidebar).bottom, rect.bottom);
          }
          expect(search.hitTestable(), findsOneWidget);
          expect(t.getRect(search).top, greaterThanOrEqualTo(rect.bottom));
          final drag = find.descendant(
            of: bar,
            matching: find.byType(DesktopDragRegion),
          );
          expect(t.getRect(drag).overlaps(t.getRect(search)), isFalse);
          expect(t.widget<TextField>(search).controller!.text, 'English');
          expect(
            find.byKey(const ValueKey('language-option-en')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('language-option-de')),
            findsNothing,
          );
          expect(t.takeException(), isNull);
        }
        await t.tap(find.byKey(const ValueKey('language-search-clear')));
        await t.pumpAndSettle();
        expect(t.widget<TextField>(search).controller!.text, isEmpty);
        final searchRect = t.getRect(search);
        await t.drag(
          find.byKey(const PageStorageKey('language-settings-scroll')),
          const Offset(0, -300),
        );
        await t.pumpAndSettle();
        expect(t.getRect(search), searchRect);
        expect(search.hitTestable(), findsOneWidget);
        expect(p.settingsView.localeCode, 'en');
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'desktop appearance keeps captions and drag space across both columns',
    (t) async {
      _viewport(t, const Size(1600, 900));
      DesktopWindowBridge.instance.available = true;
      addTearDown(() => DesktopWindowBridge.instance.available = false);
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const SettingsPage(
            initialDestination: SettingsDestination.appearance,
          ),
        ),
      );
      await t.pumpAndSettle();
      final bar = find.byKey(const ValueKey('settings-page-app-bar'));
      final rect = t.getRect(bar);
      expect(rect, const Rect.fromLTWH(0, 0, 1600, 48));
      final caption = find.descendant(
        of: bar,
        matching: find.byType(DesktopCaptionSpacer),
      );
      expect(t.getRect(caption).right, rect.right);
      expect(t.getSize(caption).width, 138);
      final drag = find.descendant(
        of: bar,
        matching: find.byType(DesktopDragRegion),
      );
      expect(t.getRect(drag), rect);
      final preview = find.byKey(const ValueKey('theme-workspace-preview'));
      expect(t.getRect(preview).top, greaterThanOrEqualTo(rect.bottom));
      expect(t.getRect(preview).right, lessThanOrEqualTo(1600));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'expanded and compact titles expose one heading during either fade',
    (t) async {
      _viewport(t, const Size(393, 700));
      final semantics = t.ensureSemantics();
      try {
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: const SettingsPage(
              initialDestination: SettingsDestination.studentPreferences,
            ),
          ),
        );
        await t.pumpAndSettle();
        const title = 'Timetable display and interaction';
        final list = find.byKey(
          const ValueKey('timetable-display-settings-list'),
        );
        final position = t
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        expect(_headingCount(t, title), 1);
        position.jumpTo(400);
        await t.pumpAndSettle();
        expect(_headingCount(t, title), 1);
        position.jumpTo(40);
        await t.pump(const Duration(milliseconds: 100));
        expect(_headingCount(t, title), 1);
        position.jumpTo(400);
        await t.pump(const Duration(milliseconds: 100));
        expect(_headingCount(t, title), 1);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'long Chinese title wraps, collapses and stays reachable at 320/$scale with one safe inset',
      (t) async {
        _viewport(t, const Size(320, 640));
        final p = await workspaceProvider(locale: 'zh');
        addTearDown(p.dispose);
        const title = '课程与日程的显示及交互设置';
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            textScale: scale,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 24, bottom: 32),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 32),
                ),
                child: SettingsPageScaffold(
                  title: title,
                  bodyBuilder: (_, header) =>
                      ResponsiveSettingsSingleColumnBody(
                        headerSliver: header,
                        children: [
                          for (var i = 0; i < 24; i++)
                            SizedBox(height: 64, child: Text('偏好 $i')),
                        ],
                      ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final list = find.byType(CustomScrollView);
        final expanded = find.byKey(const ValueKey('settings-expanded-title'));
        final rect = t.getRect(expanded);
        expect(rect.width, lessThanOrEqualTo(288));
        expect(rect.height, greaterThan(50));
        expect(rect.bottom, lessThan(t.getTopLeft(find.text('偏好 0')).dy));
        expect(t.getRect(list).top, 24);
        expect(t.getRect(list).bottom, 608);
        final position = t
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        position.jumpTo(400);
        await t.pumpAndSettle();
        final opacity = t.widget<Opacity>(
          find.ancestor(of: expanded, matching: find.byType(Opacity)).first,
        );
        expect(opacity.opacity, 0);
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        final compact = find.byKey(
          const ValueKey('settings-compact-title-scroll'),
        );
        expect(compact.hitTestable(), findsOneWidget);
        await t.drag(compact, const Offset(-120, 0));
        await t.pumpAndSettle();
        expect(
          t
              .state<ScrollableState>(
                find.descendant(of: compact, matching: find.byType(Scrollable)),
              )
              .position
              .pixels,
          greaterThan(0),
        );
        position.jumpTo(position.maxScrollExtent);
        await t.pumpAndSettle();
        final content = find.byKey(
          const ValueKey('responsive-settings-single-column-content'),
        );
        expect(
          t.getRect(list).bottom - t.getRect(content).bottom,
          closeTo(24, .01),
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'wide touch settings keep a compact header without a duplicate back button',
    (t) async {
      _viewport(t, const Size(1024, 768));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const AdaptiveNavigationScope(
            wide: true,
            child: SettingsPage(
              initialDestination: SettingsDestination.language,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-expanded-title')),
        findsNothing,
      );
      expect(find.byType(BackButton), findsNothing);
      final bar = find.byKey(const ValueKey('settings-page-app-bar'));
      final search = find.byKey(const ValueKey('language-search'));
      expect(t.getRect(bar).height, 64);
      expect(search.hitTestable(), findsOneWidget);
      expect(
        t.getRect(search).top,
        greaterThanOrEqualTo(t.getRect(bar).bottom),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'language search remains below the collapsed title and keeps its query',
    (t) async {
      _viewport(t, const Size(393, 700));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const SettingsPage(
            initialDestination: SettingsDestination.language,
          ),
        ),
      );
      await t.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('language-settings-scroll'));
      final bar = find.descendant(
        of: find.byKey(const ValueKey('settings-page-app-bar')),
        matching: find.byWidgetPredicate((widget) => widget is AppBar),
      );
      final expandedHeight = t.getRect(bar).height;
      await t.drag(list, const Offset(0, -400));
      await t.pumpAndSettle();
      final search = find.byKey(const ValueKey('language-search'));
      expect(t.getRect(bar).height, lessThan(expandedHeight));
      expect(search.hitTestable(), findsOneWidget);
      expect(
        t.getRect(search).top,
        greaterThanOrEqualTo(t.getRect(find.byType(BackButton)).bottom),
      );
      final collapsedSearchRect = t.getRect(search);
      await t.drag(list, const Offset(0, -200));
      await t.pumpAndSettle();
      expect(t.getRect(search), collapsedSearchRect);
      await t.enterText(search, 'English');
      await t.pumpAndSettle();
      expect(t.widget<TextField>(search).controller!.text, 'English');
      expect(find.byKey(const ValueKey('language-option-en')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final destination in [
    SettingsDestination.student,
    SettingsDestination.parser,
    SettingsDestination.language,
  ]) {
    testWidgets(
      'direct ${destination.name} uses actual wide constraints and retains its scroll host',
      (tester) async {
        _viewport(tester, const Size(1024, 900));
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsPage(initialDestination: destination),
                        ),
                      ),
                  child: const Text('Open direct settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open direct settings'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('settings-expanded-title')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('settings-page-app-bar')),
          findsOneWidget,
        );
        expect(find.byType(WorkbenchAppBar), findsOneWidget);
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        final position = _settingsPosition(tester);
        position.jumpTo(500.clamp(0, position.maxScrollExtent).toDouble());
        await tester.pumpAndSettle();
        for (final width in [700.0, 1024.0]) {
          final previousOffset = position.pixels;
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpAndSettle();
          expect(_settingsPosition(tester), same(position));
          expect(
            position.pixels,
            closeTo(
              previousOffset.clamp(0, position.maxScrollExtent).toDouble(),
              .01,
            ),
          );
          expect(
            find.byKey(const ValueKey('settings-expanded-title')),
            width == 700 ? findsOneWidget : findsNothing,
          );
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Open direct settings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final destination in SettingsDestination.values) {
    testWidgets(
      '${destination.name} retains its scroll position across touch navigation breakpoints',
      (tester) async {
        _viewport(tester, const Size(700, 900));
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: AdaptiveSettingsScaffold(
              catalog: [
                SettingsCatalogEntry(
                  destination.name,
                  destination.name,
                  destination,
                ),
              ],
              builder: (_) => SettingsPage(initialDestination: destination),
              overviewBuilder:
                  (context, controller, keys, openDestination, header) =>
                      CustomScrollView(
                        controller: controller,
                        slivers: [
                          header,
                          SliverToBoxAdapter(
                            child: TextButton(
                              key: const ValueKey('open-review-destination'),
                              onPressed: () => openDestination(destination),
                              child: const Text('Open settings'),
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-review-destination')));
        await tester.pumpAndSettle();
        final position = _settingsPosition(tester);
        position.jumpTo(500.clamp(0, position.maxScrollExtent).toDouble());
        await tester.pumpAndSettle();

        for (final width in [1100.0, 700.0]) {
          final previousOffset = position.pixels;
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpAndSettle();
          expect(_settingsPosition(tester), same(position));
          expect(
            position.pixels,
            closeTo(
              previousOffset.clamp(0, position.maxScrollExtent).toDouble(),
              0.01,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final destination in [
    SettingsDestination.student,
    SettingsDestination.parser,
  ]) {
    testWidgets(
      'direct ${destination.name} refreshes status bar styling without owning the navigation bar',
      (tester) async {
        _viewport(tester, const Size(393, 900));
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 32);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 32);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        const navigationStyle = SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFF123456),
          systemNavigationBarDividerColor: Color(0xFF654321),
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        );
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              brightness: brightness,
              home: AnnotatedRegion<SystemUiOverlayStyle>(
                value: navigationStyle,
                child: SettingsPage(initialDestination: destination),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final layer = tester.binding.renderViews.single.debugLayer!;
          final statusStyle = layer.find<SystemUiOverlayStyle>(
            const Offset(196.5, 12),
          );
          expect(statusStyle, isNotNull);
          final expected = brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark;
          expect(
            statusStyle!.statusBarIconBrightness,
            expected.statusBarIconBrightness,
          );
          expect(statusStyle.statusBarBrightness, expected.statusBarBrightness);
          expect(statusStyle.statusBarColor, Colors.transparent);
          expect(statusStyle.systemNavigationBarColor, isNull);
          expect(
            layer.find<SystemUiOverlayStyle>(const Offset(196.5, 884)),
            navigationStyle,
          );
          final appBar = find.descendant(
            of: find.byType(SettingsPageHeader),
            matching: find.byWidgetPredicate((widget) => widget is AppBar),
          );
          expect(tester.getRect(appBar).top, 24);
          expect(tester.takeException(), isNull);
        }
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
