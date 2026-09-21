import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'reference-inspired settings with actual fonts and stable hierarchy',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      const baseline = bool.fromEnvironment('SKED_SETTINGS_BASELINE');
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/settings-reference-after',
        ),
      );
      await output.create(recursive: true);
      final manifest = <Map<String, Object?>>[];
      final cases = [
        for (final brightness in Brightness.values)
          for (final (width, scale) in [
            (360.0, 1.0),
            (393.0, 1.0),
            (412.0, 1.3),
            (320.0, 2.0),
          ])
            (
              'phone-$width-$scale-${brightness.name}',
              Size(width, 900),
              scale,
              brightness,
              TargetPlatform.android,
              'zh',
            ),
        (
          'phone-320-en-2',
          const Size(320, 900),
          2.0,
          Brightness.light,
          TargetPlatform.android,
          'en',
        ),
        (
          'tablet-800',
          const Size(800, 1000),
          1.0,
          Brightness.dark,
          TargetPlatform.android,
          'zh',
        ),
        (
          'windows-360',
          const Size(360, 900),
          1.0,
          Brightness.light,
          TargetPlatform.windows,
          'zh',
        ),
        (
          'windows-1000',
          const Size(1000, 900),
          1.0,
          Brightness.dark,
          TargetPlatform.windows,
          'zh',
        ),
        (
          'windows-1280',
          const Size(1280, 900),
          1.0,
          Brightness.light,
          TargetPlatform.windows,
          'zh',
        ),
        (
          'windows-1440',
          const Size(1440, 900),
          1.3,
          Brightness.light,
          TargetPlatform.windows,
          'en',
        ),
      ];
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetViewPadding);
      addTearDown(t.view.resetPadding);
      try {
        for (final (name, size, scale, brightness, platform, language)
            in cases) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          t.view.physicalSize = size;
          final insets = platform == TargetPlatform.android
              ? const FakeViewPadding(top: 24, bottom: 24)
              : const FakeViewPadding();
          t.view.padding = insets;
          t.view.viewPadding = insets;
          final p = await workspaceProvider(locale: language);
          // Use the same saved brightness for the page and its live preview.
          await p.updateThemeMode(brightness.name);
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: Locale(language),
                brightness: brightness,
                textScale: scale,
                home: const SettingsPage(),
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
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final filename = '$name-$scene.png';
              await File('${output.path}/$filename')
                  .writeAsBytes(data.buffer.asUint8List());
              manifest.add({
                'file': filename,
                'widthDp': size.width,
                'heightDp': size.height,
                'textScale': scale,
                'brightness': brightness.name,
                'platformStyle': platform.name,
                'locale': language,
                'baseline': baseline,
                'evidence': 'Actual Windows Flutter rendering and fonts; Android geometry/safe areas simulated, not device acceptance.',
              });
            } finally {
              image.dispose();
            }
          }

          Future<void> open(String id) async {
            await t.ensureVisible(k(id));
            await t.pumpAndSettle();
            await t.tap(k(id));
            await t.pumpAndSettle();
          }

          if (!baseline && platform == TargetPlatform.windows) {
            final toolbar = t.getRect(
              find.descendant(
                of: k('settings-overview-app-bar'),
                matching: find.byType(AppBar),
              ),
            );
            expect(toolbar.top, 0, reason: '$name toolbar origin');
            expect(
              toolbar.bottom,
              t.getBottomLeft(k('desktop-window-divider')).dy,
              reason: '$name toolbar must share the native frame divider',
            );
          }

          await capture('overview-top');
          final controller = t
              .widget<ScrollView>(
                find.byKey(const PageStorageKey('settings-overview-scroll')),
              )
              .controller!;
          Future<void> captureChoice(String id, String scene) async {
            await Scrollable.ensureVisible(t.element(k(id)), alignment: .35);
            await t.pumpAndSettle();
            await t.tap(k(id));
            await t.pumpAndSettle();
            expect(find.byType(MenuItemButton), findsWidgets);
            if (!baseline && scale == 1) {
              final item = t.getRect(find.byType(MenuItemButton).first);
              expect(item.width, lessThan(t.getSize(k(id)).width));
            }
            await capture(scene);
            if (baseline) {
              // The prior desktop trigger does not retain keyboard focus; the
              // visual baseline driver closes its menu without changing data.
              t
                  .widget<MenuAnchor>(
                    find.descendant(
                      of: k(id),
                      matching: find.byType(MenuAnchor),
                    ),
                  )
                  .controller!
                  .close();
            } else {
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
            }
            await t.pumpAndSettle();
            expect(find.byType(MenuItemButton), findsNothing);
          }

          await captureChoice(
            'theme-brightness-choice',
            'overview-brightness-menu',
          );
          controller.jumpTo(controller.position.maxScrollExtent);
          await t.pumpAndSettle();
          await capture('overview-bottom');
          controller.jumpTo(0);
          await t.pumpAndSettle();
          for (final (entry, scene) in [
            ('settings-appearance-details', 'appearance'),
            ('settings-student-display', 'student-display'),
            ('settings-general-display', 'general-display'),
            ('settings-notifications', 'notifications'),
            ('settings-workspace-features', 'features'),
            ('settings-language', 'language'),
            ('settings-data-privacy', 'privacy'),
            ('settings-about', 'about'),
          ]) {
            await open(entry);
            await capture(scene);
            if (scene == 'appearance') {
              await captureChoice(
                'theme-brightness-mode-choice-list',
                'appearance-brightness-menu',
              );
            } else if (scene == 'general-display') {
              await captureChoice(
                'general-default-view',
                'general-default-view-menu',
              );
            }
            await t.tap(find.byType(BackButton).hitTestable().first);
            await t.pumpAndSettle();
            expect(controller.hasClients, isTrue);
          }
          await open('settings-period-times');
          expect(find.byType(PeriodTimeSetPickerDialogView), findsOneWidget);
          await capture('period-dialog');
          t
              .widget<PeriodTimeSetPickerDialogView>(
                find.byType(PeriodTimeSetPickerDialogView),
              )
              .onCancel();
          await t.pumpAndSettle();
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
