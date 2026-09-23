import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/widgets/adaptive_navigation_scope.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));

class _Sites extends SchoolSiteStore {
  _Sites() : super.base();
  @override
  Future<String?> load() async => '[]';
  @override
  Future<void> save(String value) async {}
  @override
  Future<String?> filePath() async => 'memory://navigation-school-sites';
}

Future<void> _open(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> _fixture(WidgetTester t, double width) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 1000);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  final p = await workspaceProvider();
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-settings'),
            onPressed: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await _open(t, k('open-settings'));
  await _open(t, k('settings-student-transfer'));
}

void main() {
  for (final (width, platform) in [
    (393.0, TargetPlatform.android),
    (393.0, TargetPlatform.iOS),
    (660.0, TargetPlatform.windows),
    (1280.0, TargetPlatform.windows),
  ]) {
    testWidgets(
      'backup has one overview entry and is absent from privacy at $width',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 1000);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        await t.pumpWidget(
          WorkspaceHarness(provider: provider, home: const SettingsPage()),
        );
        await t.pumpAndSettle();

        final backup = k('settings-app-backup');
        expect(backup, findsOneWidget);
        expect(find.text('App backup and restore'), findsOneWidget);
        expect(
          find.descendant(of: k('settings-overview-data'), matching: backup),
          findsOneWidget,
        );
        await _open(t, k('settings-data-privacy'));

        expect(backup, findsNothing);
        expect(find.text('App backup and restore'), findsNothing);
        expect(
          find.byKey(
            const ValueKey('settings-app-backup'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(
          k('settings-clear-app-data'),
          platform == TargetPlatform.iOS ? findsNothing : findsOneWidget,
        );
        final back = find.byType(BackButton).hitTestable();
        expect(back, findsOneWidget);
        await t.tap(back);
        await t.pumpAndSettle();

        expect(backup, findsOneWidget);
        await _open(t, backup);
        expect(find.text('Restore from JSON file'), findsOneWidget);
        expect(find.text('Paste backup JSON'), findsOneWidget);
        expect(find.text('Share backup file'), findsOneWidget);
        expect(find.text('Save backup file'), findsOneWidget);
        expect(find.text('Copy backup text'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final (width, platform) in [
    (1280.0, TargetPlatform.windows),
    (660.0, TargetPlatform.windows),
    (393.0, TargetPlatform.android),
  ]) {
    testWidgets(
      'one back control returns through transfer, school sites and overview at $width',
      (t) async {
        await _fixture(t, width);
        final overviewScroll = t
            .widget<ScrollView>(
              find.byKey(
                const PageStorageKey('settings-overview-scroll'),
                skipOffstage: false,
              ),
            )
            .controller!;
        final offset = overviewScroll.offset;
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        final transfer = k('transfer-page-content');
        expect(transfer, findsOneWidget);
        final wide = AdaptiveNavigationScope.isWide(t.element(transfer));
        expect(wide, width >= 1000);
        final navigator = Navigator.of(t.element(transfer));
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => SchoolSitesPage(
                siteService: SchoolSiteService(store: _Sites()),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(SchoolSitesPage), findsOneWidget);
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        final sitesBar = t.widget<WorkbenchAppBar>(
          find.descendant(
            of: find.byType(SchoolSitesPage),
            matching: find.byType(WorkbenchAppBar),
          ),
        );
        expect(sitesBar.automaticallyImplyLeading, !wide);
        await t.tap(find.byType(BackButton).hitTestable());
        await t.pumpAndSettle();
        expect(transfer, findsOneWidget);
        expect(find.byType(SchoolSitesPage), findsNothing);
        await t.tap(find.byType(BackButton).hitTestable());
        await t.pumpAndSettle();
        expect(k('settings-overview-data'), findsOneWidget);
        expect(overviewScroll.offset, closeTo(offset, 0.01));
        await t.tap(find.byType(BackButton).hitTestable());
        await t.pumpAndSettle();
        expect(k('open-settings').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'desktop import subpages follow one back owner, including after resize',
    (t) async {
      await _fixture(t, 1280);
      await _open(
        t,
        k('transfer-action-SettingsStudentDataAction.importTimetablesText'),
      );
      expect(find.byType(TextImportPage), findsOneWidget);
      final editor = t.state(find.byType(TextImportPage));
      final input = find.byType(TextField);
      await t.enterText(input, '{"draft":true}');
      for (final width in [1280.0, 660.0, 1280.0]) {
        t.view.physicalSize = Size(width, 1000);
        await t.pumpAndSettle();
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        expect(t.state(find.byType(TextImportPage)), same(editor));
        expect(t.widget<TextField>(input).controller!.text, '{"draft":true}');
      }
      await t.tap(find.byType(BackButton).hitTestable());
      await t.pumpAndSettle();
      await _open(
        t,
        k('transfer-action-SettingsStudentDataAction.importSchoolHtml'),
      );
      expect(find.byType(SchoolHtmlImportPage), findsOneWidget);
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable());
      await t.pumpAndSettle();
      await _open(t, k('transfer-parser-settings'));
      expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable());
      await t.pumpAndSettle();
      expect(k('transfer-page-content'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'shared back cannot dismiss text import while submit is pending',
    (t) async {
      await _fixture(t, 1280);
      final gate = Completer<bool>();
      unawaited(
        Navigator.of(t.element(k('transfer-page-content'))).push<void>(
          MaterialPageRoute(
            builder: (_) => TextImportPage(
              title: 'Guarded import',
              onSubmit: (_, _) => gate.future,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '{}');
      await t.tap(find.byType(FilledButton));
      await t.pump();
      expect(find.byType(BackButton).hitTestable(), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable());
      await t.pump();
      expect(find.byType(TextImportPage), findsOneWidget);
      gate.complete(false);
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton).hitTestable());
      await t.pumpAndSettle();
      expect(find.byType(TextImportPage), findsNothing);
      expect(k('transfer-page-content'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
