import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mobile workspace bar and custom-to-week visual checks', (
    t,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    const before = bool.fromEnvironment('SKED_VISUAL_BASELINE');
    final out = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/mobile-navigation-after',
      ),
    );
    await out.create(recursive: true);
    final manifest = <Map<String, Object?>>[];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    addTearDown(t.view.resetViewPadding);
    final cases = <(String, Size, double, Brightness, TargetPlatform, String)>[
      (
        'phone-320-zh',
        const Size(320, 850),
        1,
        Brightness.light,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-360-zh',
        const Size(360, 850),
        1,
        Brightness.light,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-393-zh',
        const Size(393, 852),
        1.3,
        Brightness.dark,
        TargetPlatform.android,
        'zh',
      ),
      (
        'phone-412-en',
        const Size(412, 915),
        1,
        Brightness.light,
        TargetPlatform.android,
        'en',
      ),
      (
        'phone-320-en-2x',
        const Size(320, 850),
        2,
        Brightness.light,
        TargetPlatform.android,
        'en',
      ),
      (
        'phone-360-de-2x',
        const Size(360, 850),
        2,
        Brightness.dark,
        TargetPlatform.android,
        'de',
      ),
      (
        'tablet-800-en',
        const Size(800, 1000),
        1,
        Brightness.light,
        TargetPlatform.android,
        'en',
      ),
      (
        'windows-1280-en',
        const Size(1280, 1000),
        1,
        Brightness.light,
        TargetPlatform.windows,
        'en',
      ),
    ];
    try {
      for (final (name, size, scale, brightness, platform, language) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        t.view.physicalSize = size;
        final safe = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        t.view.padding = safe;
        t.view.viewPadding = safe;
        final base = mobileLayoutData(locale: language);
        final storage = WorkspaceMemoryStorage(
          base.copyWith(
            activeMode: AppMode.student,
            generalMode: base.generalMode.copyWith(
              selectedDateIso: '2026-09-03',
              customDateRange: GeneralDateRange(
                DateTime(2026, 9, 3),
                DateTime(2026, 9, 12),
              ),
            ),
          ),
        );
        final p = await workspaceProvider(storage: storage, locale: language);
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: p,
              locale: Locale(language),
              textScale: scale,
              brightness: brightness,
            ),
          ),
        );
        await t.pumpAndSettle();
        Future<void> capture(String scene) async {
          expect(t.takeException(), isNull, reason: '$name $scene');
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(
            pixelRatio: size.width < 600 ? 2 : 1,
          );
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = '$name-$scene.png';
            await File('${out.path}/$file')
                .writeAsBytes(bytes.buffer.asUint8List());
            final bar = find.byKey(
              const ValueKey('adaptive-shell-navigation-bar'),
            );
            manifest.add({
              'file': file,
              'widthDp': size.width,
              'heightDp': size.height,
              'textScale': scale,
              'locale': language,
              'brightness': brightness.name,
              'platformStyle': platform.name,
              'baseline': before,
              if (bar.evaluate().isNotEmpty)
                'navigationHeight': t.getSize(bar).height,
              'evidence': 'Real Windows Flutter rendering with simulated Android geometry; not Android device acceptance.',
            });
          } finally {
            image.dispose();
          }
        }

        expect(p.activeMode, AppMode.student);
        await capture('student');
        await p.switchMode(AppMode.general);
        await t.pumpAndSettle();
        await capture('general-custom');
        await p.clearGeneralDateRange();
        await t.pumpAndSettle();
        expect(p.customGeneralDateRange, isNull);
        await capture('general-week');
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        p.dispose();
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = false;
    }
    await File('${out.path}/manifest.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
  });
}
