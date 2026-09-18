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

import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'workspace press feedback, panel spacing and category header with real fonts',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/workspace-chrome-visual',
        ),
      );
      await output.create(recursive: true);
      final manifest = <Map<String, Object?>>[];
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      final cases = [
        for (final brightness in Brightness.values)
          for (final (width, scale) in [(393.0, 1.0), (320.0, 2.0)])
            (
              'phone-$width-$scale-${brightness.name}',
              width,
              scale,
              brightness,
              TargetPlatform.android,
            ),
        ('windows-330', 330.0, 1.0, Brightness.light, TargetPlatform.windows),
        ('windows-660', 660.0, 1.3, Brightness.dark, TargetPlatform.windows),
        ('windows-1440', 1440.0, 1.0, Brightness.light, TargetPlatform.windows),
      ];
      try {
        for (final (name, width, scale, brightness, platform) in cases) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          t.view.physicalSize = Size(width, 900);
          final insets = platform == TargetPlatform.android
              ? const FakeViewPadding(top: 24, bottom: 24)
              : const FakeViewPadding();
          t.view.padding = insets;
          t.view.viewPadding = insets;
          final p = await workspaceProvider(
            mode: platform == TargetPlatform.android
                ? AppMode.student
                : AppMode.general,
            locale: 'zh',
          );
          await p.updateGeneralDisplaySettings(defaultView: generalViewWeek);
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: const Locale('zh'),
                brightness: brightness,
                textScale: scale,
              ),
            ),
          );
          await t.pumpAndSettle();
          Future<Uint8List?> capture(String scene) async {
            expect(t.takeException(), isNull, reason: '$name $scene');
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            try {
              final png = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final filename = '$name-$scene.png';
              await File('${output.path}/$filename')
                  .writeAsBytes(png.buffer.asUint8List());
              manifest.add({
                'file': filename,
                'widthDp': width,
                'textScale': scale,
                'brightness': brightness.name,
                'platformStyle': platform.name,
                'evidence': 'Windows Flutter renderer and real fonts; viewport and Android safe insets simulated, not Android device acceptance.',
              });
              final bar = k('adaptive-shell-navigation-bar');
              if (bar.evaluate().isEmpty) return null;
              final rect = t.getRect(bar);
              final raw = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              return Uint8List.fromList(
                raw.buffer.asUint8List().sublist(
                  rect.top.ceil() * image.width * 4,
                  rect.bottom.floor() * image.width * 4,
                ),
              );
            } finally {
              image.dispose();
            }
          }

          final before = await capture('idle');
          if (platform == TargetPlatform.android) {
            for (final mode in ['student', 'general']) {
              final gesture = await t.startGesture(
                t.getCenter(k('adaptive-shell-$mode-destination')),
              );
              await t.pump(const Duration(milliseconds: 160));
              final held = await capture('$mode-pressed');
              expect(
                listEquals(before, held),
                isTrue,
                reason: '$name $mode should not draw a transient pill/ripple.',
              );
              await gesture.cancel();
              await t.pumpAndSettle();
            }
            await t.tap(k('adaptive-shell-general-destination'));
            await t.pumpAndSettle();
            expect(p.activeMode, AppMode.general);
            await capture('general-selected');
          } else {
            expect(k('general-resource-menu'), findsNothing);
            final toggle = k('general-day-agenda-toggle').hitTestable();
            if (toggle.evaluate().isEmpty) {
              await t.tap(k('general-desktop-toolbar-more'));
              await t.pumpAndSettle();
            }
            await t.tap(k('general-day-agenda-toggle').hitTestable());
            await t.pumpAndSettle();
            final header = t.getRect(k('workspace-inspector-header'));
            final close = t.getRect(k('workspace-inspector-close'));
            expect(close.top - header.top, 8);
            expect(header.right - close.right, 8);
            await capture('agenda-close-spacing');
            final mouse = await t.createGesture(
              kind: ui.PointerDeviceKind.mouse,
              pointer: 9,
            );
            await mouse.addPointer(location: const Offset(2, 2));
            await mouse.moveTo(close.center);
            await t.pump(const Duration(milliseconds: 180));
            await capture('agenda-close-hover');
            await mouse.removePointer();
            await t.tap(k('workspace-inspector-close'));
            await t.pumpAndSettle();
            expect(k('general-selected-day-agenda'), findsNothing);
          }
          await t.pumpWidget(const SizedBox.shrink());
          p.dispose();
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = true;
        await File(
          '${output.path}/manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      }
    },
  );
}
