import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'settings menu dismissal clears pointer focus but keeps keyboard feedback',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/dropdown-focus-visual',
        ),
      );
      await output.create(recursive: true);
      final captures = <Map<String, Object?>>[];
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      try {
        for (final (name, size, brightness, platform) in [
          (
            'desktop-light',
            const Size(1280, 900),
            Brightness.light,
            TargetPlatform.windows,
          ),
          (
            'desktop-dark',
            const Size(1280, 900),
            Brightness.dark,
            TargetPlatform.windows,
          ),
          (
            'phone',
            const Size(393, 852),
            Brightness.light,
            TargetPlatform.android,
          ),
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          t.view.physicalSize = size;
          final safe = platform == TargetPlatform.android
              ? const FakeViewPadding(top: 24, bottom: 24)
              : const FakeViewPadding();
          t.view.padding = safe;
          t.view.viewPadding = safe;
          final p = await workspaceProvider(
            mode: AppMode.general,
            locale: 'zh',
          );
          await p.updateThemeMode(brightness.name);
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: const Locale('zh'),
                brightness: brightness,
                home: const SettingsPage(initialWorkspace: AppMode.general),
              ),
            ),
          );
          await t.pumpAndSettle();
          final row = k('theme-workspace-target');
          await Scrollable.ensureVisible(t.element(row), alignment: .3);
          await t.pumpAndSettle();
          final anchor = find.descendant(
            of: row,
            matching: find.byType(MenuAnchor),
          );
          final trigger = t.widget<MenuAnchor>(anchor).childFocusNode!;
          final title = find.descendant(of: row, matching: find.text('外观配置目标'));
          final dropdown = t.widget<SkedDropdownMenu<String>>(
            find.descendant(
              of: row,
              matching: find.byType(SkedDropdownMenu<String>),
            ),
          );
          final currentLabel = dropdown.dropdownMenuEntries
              .singleWhere((entry) => entry.value == dropdown.initialSelection)
              .label;
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          final outside = Offset(4, size.height - 16);
          await mouse.addPointer(location: outside);
          await t.pumpAndSettle();

          Future<void> click(Finder target) async {
            final position = t.getCenter(target);
            await mouse.moveTo(position);
            await mouse.down(position);
            await mouse.up();
            await t.pumpAndSettle();
          }

          Future<void> leave() async {
            await mouse.moveTo(outside);
            await t.pumpAndSettle();
          }

          Future<String> capture(String scene) async {
            expect(t.takeException(), isNull, reason: '$name $scene');
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            try {
              final raw = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final rowRect = t.getRect(row);
              final x = (rowRect.left + 8).round();
              final y = rowRect.center.dy.round();
              final index = (y * image.width + x) * 4;
              final rowColor = List.generate(
                4,
                (i) => raw.getUint8(index + i),
              ).join(',');
              final png = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final filename = '$name-$scene.png';
              await File('${output.path}/$filename')
                  .writeAsBytes(png.buffer.asUint8List());
              captures.add({
                'file': filename,
                'widthDp': size.width,
                'heightDp': size.height,
                'platformStyle': platform.name,
                'brightness': brightness.name,
                'rowColorRgba': rowColor,
                'rowRect': [
                  rowRect.left,
                  rowRect.top,
                  rowRect.width,
                  rowRect.height,
                ],
              });
              return rowColor;
            } finally {
              image.dispose();
            }
          }

          final baseline = await capture('before');
          await mouse.moveTo(t.getCenter(title));
          await t.pumpAndSettle();
          expect(await capture('hover'), isNot(baseline));
          await leave();

          await click(title);
          await capture('open');
          await mouse.down(outside);
          await mouse.up();
          await leave();
          expect(find.byType(MenuItemButton), findsNothing);
          expect(trigger.hasFocus, isFalse);
          expect(await capture('closed-outside'), baseline);

          await click(anchor);
          await click(find.widgetWithText(MenuItemButton, currentLabel));
          await leave();
          expect(find.byType(MenuItemButton), findsNothing);
          expect(trigger.hasFocus, isFalse);
          expect(await capture('closed-selection'), baseline);

          await click(title);
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await leave();
          expect(find.byType(MenuItemButton), findsNothing);
          expect(trigger.hasFocus, isFalse);
          expect(await capture('closed-escape'), baseline);

          trigger.requestFocus();
          await t.pump();
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pumpAndSettle();
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
          expect(find.byType(MenuItemButton), findsNothing);
          expect(trigger.hasPrimaryFocus, isTrue);
          expect(await capture('keyboard-focus'), isNot(baseline));
          await mouse.removePointer();
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
          p.dispose();
        }
        await File('${output.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'evidence': 'Actual Windows Flutter rendering; Android geometry and safe areas are simulated. Pointer-dismissed row colors must match their pre-open pixels.',
            'captures': captures,
          }),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = true;
      }
    },
  );
}
