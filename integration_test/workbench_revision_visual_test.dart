import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';

import '../test/support/workspace_harness.dart';
import '../test/support/workbench_dense_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dense desktop and touch workbench revision rendering', (
    tester,
  ) async {
    // These are logical viewport/platform variants on Windows, not tablet hardware.
    await DesktopWindowBridge.instance.initialize();
    final out = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/revision-visual',
      ),
    );
    await out.create(recursive: true);
    final manifest = <Map<String, Object?>>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final cases = <(String, Size, double, Brightness, TargetPlatform)>[
      (
        'windows-1440',
        const Size(1440, 900),
        1,
        Brightness.light,
        TargetPlatform.windows,
      ),
      (
        'windows-1920-dark',
        const Size(1920, 1080),
        1,
        Brightness.dark,
        TargetPlatform.windows,
      ),
      (
        'tablet-portrait-simulated',
        const Size(800, 1280),
        1,
        Brightness.light,
        TargetPlatform.android,
      ),
      (
        'tablet-landscape-simulated',
        const Size(1280, 800),
        1,
        Brightness.light,
        TargetPlatform.android,
      ),
      (
        'phone-simulated',
        const Size(360, 800),
        1,
        Brightness.light,
        TargetPlatform.android,
      ),
      (
        'desktop-large-text',
        const Size(1440, 900),
        2,
        Brightness.dark,
        TargetPlatform.windows,
      ),
      (
        'tablet-1_3-text-simulated',
        const Size(1280, 800),
        1.3,
        Brightness.dark,
        TargetPlatform.android,
      ),
    ];
    try {
      for (final (name, size, scale, brightness, platform) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        tester.view.physicalSize = size;
        // Native caption controls are never painted on an Android simulation.
        for (final page in [
          'week',
          'month',
          'day',
          'list',
          'student',
          'appearance',
          'settings',
          'import',
          'export',
          'ai',
        ]) {
          final p = await denseWorkbenchProvider(
            locale: 'zh',
            mode: page == 'student' ? AppMode.student : AppMode.general,
            view: ['day', 'month', 'list'].contains(page)
                ? page
                : generalViewWeek,
          );
          final prefs = DeveloperUiPreferences.memory(visible: page == 'ai');
          final boundary = GlobalKey();
          final home = switch (page) {
            'appearance' => const SettingsPage(
              initialDestination: SettingsDestination.appearance,
            ),
            'settings' => const SettingsPage(),
            'import' => const SettingsPage(
              initialDestination: SettingsDestination.general,
              transferDirection: SettingsTransferDirection.import,
            ),
            'export' => const SettingsPage(
              initialDestination: SettingsDestination.general,
              transferDirection: SettingsTransferDirection.export,
            ),
            _ => null,
          };
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: const Locale('zh'),
                textScale: scale,
                brightness: brightness,
                home: home,
                developerUiPreferences: prefs,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$name $page');
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = '$name-$page.png';
          await File('${out.path}/$file')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
          manifest.add({
            'file': file,
            'widthDp': size.width,
            'heightDp': size.height,
            'scale': scale,
            'brightness': brightness.name,
            'platformStyle': platform.name,
            'kind': 'Flutter client renderer on Windows; not native frame or Android hardware',
          });
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          prefs.dispose();
          p.dispose();
        }
      }
      await File('${out.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'fixtures': '15 categories, duplicate names, 3 and 6 overlapping events, five all-day lanes, short event, long names',
          'captures': manifest,
        }),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = true;
    }
  });
}
