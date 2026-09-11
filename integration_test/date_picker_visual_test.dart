import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../test/support/workbench_dense_data.dart';
import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'render custom date navigation on desktop and simulated touch layouts',
    (tester) async {
      await DesktopWindowBridge.instance.initialize();
      final out = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/custom-range-visual',
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
          'windows-1440-large',
          const Size(1440, 1000),
          2,
          Brightness.dark,
          TargetPlatform.windows,
        ),
        (
          'windows-800-split',
          const Size(800, 1000),
          1,
          Brightness.light,
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
          'tablet-large-simulated',
          const Size(1280, 900),
          1.3,
          Brightness.dark,
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
          'phone-large-simulated',
          const Size(360, 1000),
          2,
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
          final p = await denseWorkbenchProvider(locale: 'zh');
          await p.setSelectedGeneralDate(DateTime(2026, 9, 10));
          await p.updateGeneralDisplaySettings(
            dateLabelFormat: generalDateLabelFormatLocalized,
          );
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: const Locale('zh'),
                textScale: scale,
                brightness: brightness,
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> capture(String phase) async {
            expect(tester.takeException(), isNull);
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final filename = '$name-$phase.png';
              await File('${out.path}/$filename')
                  .writeAsBytes(bytes.buffer.asUint8List());
              manifest.add({
                'file': filename,
                'widthDp': size.width,
                'heightDp': size.height,
                'textScale': scale,
                'brightness': brightness.name,
                'platformStyle': platform.name,
                'evidence': 'actual Windows Flutter rendering; touch layouts are simulated, not Android hardware',
              });
            } finally {
              image.dispose();
            }
          }

          await capture('week');
          final button = find.byKey(
            ValueKey(
              platform == TargetPlatform.windows
                  ? 'general-date-picker'
                  : 'general-date-title-button',
            ),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await capture('range-picker');
          final popup = find.byKey(const ValueKey('sked-date-picker-content'));
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-2026-09-09')),
            ),
          );
          await tester.pumpAndSettle();
          expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
          expect(p.customGeneralDateRange, isNull);
          await capture('range-start');
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-2026-09-13')),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            p.customGeneralDateRange,
            GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
          );
          expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
          await capture('custom-five-days');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await capture('range-five-selected');
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-input-toggle')),
            ),
          );
          await tester.pumpAndSettle();
          await capture('range-input');
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-input-toggle')),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-month-year')),
            ),
          );
          await tester.pumpAndSettle();
          await capture('month-grid');
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-picker-close')),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-2026-09-09')),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-2026-09-22')),
            ),
          );
          await tester.pumpAndSettle();
          expect(p.customGeneralDateRange!.dayCount, 14);
          await capture('custom-fourteen-days');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await capture('range-fourteen-selected');
          await tester.tap(
            find.descendant(
              of: popup,
              matching: find.byKey(const ValueKey('sked-date-picker-close')),
            ),
          );
          await tester.pumpAndSettle();
          final horizontal = find
              .ancestor(
                of: find.byKey(
                  const ValueKey(
                    'general-week-day-header-2026-09-09T00:00:00.000',
                  ),
                ),
                matching: find.byType(SingleChildScrollView),
              )
              .first;
          final scroll = tester
              .widget<SingleChildScrollView>(horizontal)
              .controller!;
          final timeRuler = tester.getTopLeft(find.text('07:00'));
          if (scroll.position.maxScrollExtent > 0) {
            await tester.drag(
              horizontal,
              Offset(-scroll.position.maxScrollExtent - 160, 0),
            );
            await tester.pumpAndSettle();
            expect(p.customGeneralDateRange!.start, DateTime(2026, 9, 9));
            expect(tester.getTopLeft(find.text('07:00')), timeRuler);
            final lastHeader = find.byKey(
              const ValueKey('general-week-day-header-2026-09-22T00:00:00.000'),
            );
            expect(
              tester.getRect(lastHeader).right,
              lessThanOrEqualTo(tester.getRect(horizontal).right + .01),
            );
            await capture('custom-fourteen-end');
          }
          final l = AppLocalizations.of(
            tester.element(
              find.byKey(const ValueKey('general-workspace-toolbar')),
            ),
          );
          final add = platform == TargetPlatform.windows
              ? find.byKey(const ValueKey('general-add-event'))
              : find.byTooltip(l.addEvent).first;
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pumpAndSettle();
          final editor = find.byType(GeneralEventEditorSheet);
          final dateField = find
              .descendant(of: editor, matching: find.byTooltip(l.pickDate))
              .first;
          await tester.ensureVisible(dateField);
          await tester.tap(dateField);
          await tester.pumpAndSettle();
          await capture('form-picker');
          await tester.tap(
            find.byKey(const ValueKey('sked-date-input-toggle')),
          );
          await tester.pumpAndSettle();
          await capture('form-input');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          p.dispose();
        }
        await File(
          '${out.path}/manifest.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
      } finally {
        debugDefaultTargetPlatformOverride = null;
        DesktopWindowBridge.instance.available = true;
      }
    },
  );
}
