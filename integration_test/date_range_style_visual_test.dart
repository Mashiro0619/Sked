import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/general_date_range.dart';
import 'package:sked/models/general_schedule_data.dart'
    show
        generalViewDay,
        generalViewWeek,
        generalViewMonth,
        generalViewSwitchBehaviorMenu;
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/workbench_dense_data.dart';
import '../test/support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'range highlights on actual desktop and simulated phone surfaces',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/date-range-style-visual',
        ),
      );
      await output.create(recursive: true);
      final manifest = <Map<String, Object?>>[];
      final originalStrategy = FocusManager.instance.highlightStrategy;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      try {
        for (final (name, size, scale, brightness, platform, direction) in [
          (
            'desktop-light',
            const Size(1280, 900),
            1.0,
            Brightness.light,
            TargetPlatform.windows,
            TextDirection.ltr,
          ),
          (
            'desktop-dark',
            const Size(1280, 900),
            1.0,
            Brightness.dark,
            TargetPlatform.windows,
            TextDirection.ltr,
          ),
          (
            'desktop-large',
            const Size(1440, 1000),
            2.0,
            Brightness.light,
            TargetPlatform.windows,
            TextDirection.ltr,
          ),
          (
            'desktop-rtl',
            const Size(1280, 900),
            1.0,
            Brightness.light,
            TargetPlatform.windows,
            TextDirection.rtl,
          ),
          (
            'phone',
            const Size(393, 852),
            1.0,
            Brightness.light,
            TargetPlatform.android,
            TextDirection.ltr,
          ),
          (
            'phone-large',
            const Size(320, 900),
            2.0,
            Brightness.dark,
            TargetPlatform.android,
            TextDirection.ltr,
          ),
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          DesktopWindowBridge.instance.available =
              platform == TargetPlatform.windows;
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTouch;
          t.view.physicalSize = size;
          final provider = await denseWorkbenchProvider(locale: 'zh');
          await provider.setGeneralDateRange(
            GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 20)),
          );
          final boundary = GlobalKey();
          Future<void> mountWorkbench() async {
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: provider,
                  locale: const Locale('zh'),
                  textScale: scale,
                  brightness: brightness,
                  textDirection: direction,
                ),
              ),
            );
            await t.pumpAndSettle();
          }

          await mountWorkbench();
          final desktop = platform == TargetPlatform.windows;
          var embedded =
              desktop &&
              k('general-resource-date-picker').evaluate().isNotEmpty;
          if (!embedded) {
            await t.tap(
              k(desktop ? 'general-date-picker' : 'general-date-title-button'),
            );
            await t.pumpAndSettle();
          }
          var calendar = k(
            embedded
                ? 'general-resource-date-picker'
                : 'sked-date-picker-surface',
          );
          Future<void> capture(String state, {bool full = false}) async {
            expect(t.takeException(), isNull);
            expect(calendar, findsOneWidget);
            final rect = t
                .getRect(calendar)
                .inflate(8)
                .intersect(Offset.zero & size);
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            try {
              if (full) {
                final data = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                await File('${output.path}/$name-$state-full.png')
                    .writeAsBytes(data.buffer.asUint8List());
              }
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder);
              canvas.drawImageRect(
                image,
                rect,
                Rect.fromLTWH(0, 0, rect.width, rect.height),
                Paint(),
              );
              final picture = recorder.endRecording();
              final crop = await picture.toImage(
                rect.width.ceil(),
                rect.height.ceil(),
              );
              picture.dispose();
              try {
                final data = (await crop.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                final file = '$name-$state.png';
                await File('${output.path}/$file')
                    .writeAsBytes(data.buffer.asUint8List());
                manifest.add({
                  'file': file,
                  'widthDp': size.width,
                  'heightDp': size.height,
                  'textScale': scale,
                  'brightness': brightness.name,
                  'direction': direction.name,
                  'evidence': 'actual Windows Flutter rendering; phone layout is simulated, not Android hardware',
                });
              } finally {
                crop.dispose();
              }
            } finally {
              image.dispose();
            }
          }

          await capture('range', full: true);
          if (name == 'desktop-light') {
            FocusManager.instance.highlightStrategy =
                FocusHighlightStrategy.alwaysTraditional;
            t
                .widget<Focus>(
                  find.descendant(
                    of: calendar,
                    matching: k('sked-date-grid-focus'),
                  ),
                )
                .focusNode!
                .requestFocus();
            await t.pumpAndSettle();
            await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            await t.pumpAndSettle();
            await capture('keyboard');
            FocusManager.instance.highlightStrategy =
                FocusHighlightStrategy.alwaysTouch;
            for (final (state, range) in [
              (
                'today-endpoint',
                GeneralDateRange(DateTime(2026, 9, 20), DateTime(2026, 9, 23)),
              ),
              (
                'single-day',
                GeneralDateRange(DateTime(2026, 9, 23), DateTime(2026, 9, 23)),
              ),
              (
                'cross-month',
                GeneralDateRange(DateTime(2026, 9, 29), DateTime(2026, 10, 4)),
              ),
            ]) {
              await provider.setGeneralDateRange(range);
              await t.pumpAndSettle();
              await capture(state);
            }
          }
          if (!embedded) {
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
          }
          await provider.updateGeneralDisplaySettings(
            viewSwitchBehavior: generalViewSwitchBehaviorMenu,
          );
          await provider.clearGeneralDateRange();
          await provider.setSelectedGeneralDate(DateTime(2026, 9, 9));
          for (final view in [
            generalViewWeek,
            generalViewDay,
            if (desktop && embedded) generalViewMonth,
          ]) {
            if (!desktop) {
              // Each phone snapshot starts from a fresh view session rather
              // than reusing the previously opened sheet and its owner.
              await t.pumpWidget(const SizedBox.shrink());
              await t.pumpAndSettle();
              await provider.updateGeneralDisplaySettings(defaultView: view);
              await mountWorkbench();
            } else {
              // Switch the active view through its actual command. Changing the
              // default preference does not replace an already active view.
              final overflow = k('general-desktop-toolbar-more').hitTestable();
              if (overflow.evaluate().isNotEmpty) {
                await t.tap(overflow);
                await t.pumpAndSettle();
                final choice = k('general-view-choice-$view');
                await t.ensureVisible(choice);
                await t.tap(choice);
              } else {
                await t.tap(k('general-view-switcher'));
                await t.pumpAndSettle();
                final choice = find.byWidgetPredicate(
                  (widget) =>
                      widget is PopupMenuItem<String> && widget.value == view,
                );
                await t.ensureVisible(choice);
                await t.tap(choice);
              }
              await t.pumpAndSettle();
            }
            embedded =
                desktop &&
                k('general-resource-date-picker').evaluate().isNotEmpty;
            if (!embedded) {
              await t.tap(
                k(
                  desktop ? 'general-date-picker' : 'general-date-title-button',
                ),
              );
              await t.pumpAndSettle();
            }
            calendar = k(
              embedded
                  ? 'general-resource-date-picker'
                  : 'sked-date-picker-surface',
            );
            final picker = t.widget<SkedDatePicker>(
              embedded
                  ? calendar
                  : find.descendant(
                      of: calendar,
                      matching: find.byType(SkedDatePicker),
                    ),
            );
            expect(picker.displayRange, isNull);
            expect(
              picker.selectionUnit,
              view == generalViewWeek
                  ? DateSelectionUnit.week
                  : DateSelectionUnit.day,
            );
            await capture('ordinary-$view', full: name == 'desktop-light');
            if (!embedded) {
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
            }
          }
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
          provider.dispose();
        }
        await File(
          '${output.path}/manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = true;
        FocusManager.instance.highlightStrategy = originalStrategy;
      }
    },
  );
}
