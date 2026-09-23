import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';

import '../test/support/workspace_harness.dart';

class _EmptySites extends SchoolSiteStore {
  _EmptySites() : super.base();
  @override
  Future<String?> load() async => '[]';
  @override
  Future<void> save(String source) async {}
  @override
  Future<String?> filePath() async => 'memory://transfer-visual-sites';
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundary,
  Directory output,
  String name,
) async {
  expect(tester.takeException(), isNull, reason: name);
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 1);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('${output.path}/$name.png')
        .writeAsBytes(data.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('transfer layout and single navigation owner with real fonts', (
    tester,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final wasAvailable = DesktopWindowBridge.instance.available;
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/settings-transfer-visual',
      ),
    );
    await output.create(recursive: true);
    final manifest = <Map<String, Object?>>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      DesktopWindowBridge.instance.available = true;
      tester.view.physicalSize = const Size(1440, 960);
      final empty = await workspaceProvider(
        locale: 'zh',
        storage: WorkspaceMemoryStorage(
          buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh'),
        ),
      );
      final emptyBoundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: emptyBoundary,
          child: WorkspaceHarness(provider: empty, locale: const Locale('zh')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sked').hitTestable(), findsOneWidget);
      expect(_key('student-workspace-toolbar'), findsOneWidget);
      await _capture(tester, emptyBoundary, output, 'desktop-empty');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      empty.dispose();

      for (final (name, size, scale, brightness, platform, student, locale) in [
        (
          'desktop-student',
          const Size(1440, 960),
          1.0,
          Brightness.light,
          TargetPlatform.windows,
          true,
          'zh',
        ),
        (
          'desktop-general',
          const Size(1440, 960),
          1.0,
          Brightness.light,
          TargetPlatform.windows,
          false,
          'zh',
        ),
        (
          'phone-student',
          const Size(393, 852),
          1.0,
          Brightness.light,
          TargetPlatform.android,
          true,
          'zh',
        ),
        (
          'tablet-large-dark',
          const Size(800, 1000),
          2.0,
          Brightness.dark,
          TargetPlatform.android,
          true,
          'zh',
        ),
        (
          'desktop-english',
          const Size(1280, 960),
          1.3,
          Brightness.light,
          TargetPlatform.windows,
          true,
          'en',
        ),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        tester.view.physicalSize = size;
        final padding = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        tester.view.padding = padding;
        tester.view.viewPadding = padding;
        final provider = await workspaceProvider(locale: locale);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: provider,
              locale: Locale(locale),
              brightness: brightness,
              textScale: scale,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final entry = _key(
          student ? 'settings-student-transfer' : 'settings-general-transfer',
        );
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(_key('transfer-page-content'), findsOneWidget);
        expect(find.byType(BackButton).hitTestable(), findsOneWidget);
        expect(
          _key('transfer-two-columns'),
          size.width == 1440 ? findsOneWidget : findsNothing,
        );
        await _capture(tester, boundary, output, name);
        manifest.add({
          'file': '$name.png',
          'widthDp': size.width,
          'heightDp': size.height,
          'textScale': scale,
          'brightness': brightness.name,
          'platformStyle': platform.name,
          'locale': locale,
          'evidence': 'Real Windows Flutter rendering; Android geometry is simulated, not device acceptance.',
        });
        if (name == 'desktop-student') {
          // Inject memory storage instead of loading the user's saved sites.
          unawaited(
            Navigator.of(tester.element(_key('transfer-page-content')))
                .push<void>(
                  MaterialPageRoute(
                    builder: (_) => SchoolSitesPage(
                      siteService: SchoolSiteService(store: _EmptySites()),
                    ),
                  ),
                ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BackButton).hitTestable(), findsOneWidget);
          await _capture(tester, boundary, output, 'desktop-school-sites');
          await tester.tap(find.byType(BackButton).hitTestable());
          await tester.pumpAndSettle();
          expect(_key('transfer-page-content'), findsOneWidget);
        }
        if (size.width < 1000) {
          await tester.ensureVisible(
            find.byType(SettingsTransferPageTile).last,
          );
          await tester.pumpAndSettle();
          await _capture(tester, boundary, output, '$name-scrolled');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      }
      await File('${output.path}/manifest.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = wasAvailable;
    }
  });
}
