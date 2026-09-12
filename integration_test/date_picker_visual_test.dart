import 'package:flutter/gestures.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

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
            viewSwitchBehavior: generalViewSwitchBehaviorMenu,
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

          final nativeCheck =
              const bool.fromEnvironment('SKED_NATIVE_POINTER_CHECK') &&
              name == 'windows-1440';
          final nativeEvidence = <Map<String, dynamic>>[];
          if (nativeCheck) {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            await _nativeWindow(tester, 'resize');
            await tester.pumpAndSettle();
            final sidebar = find.byKey(
              const ValueKey('general-resource-date-picker'),
            );
            Finder date(String value) => find.descendant(
              of: sidebar,
              matching: find.byKey(ValueKey(value)),
            );
            final report = await _nativeWindow(
              tester,
              'range-drag',
              from: tester.getCenter(date('sked-date-2026-09-09')),
              to: tester.getCenter(date('sked-date-2026-09-13')),
            );
            await tester.pumpAndSettle();
            expect(report['movedX'], 0);
            expect(report['movedY'], 0);
            expect(
              p.customGeneralDateRange,
              GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
            );
            nativeEvidence.add(report);
            await p.clearGeneralDateRange();
            await p.setSelectedGeneralDate(DateTime(2026, 9, 10));
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
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
          await capture('week-picker');
          expect(
            tester
                .widget<SkedDatePicker>(
                  find.byKey(const ValueKey('sked-date-picker-content')),
                )
                .rangeInteraction,
            DateRangeInteraction.none,
          );
          await tester.tap(
            find.byKey(const ValueKey('sked-date-picker-close')),
          );
          await tester.pumpAndSettle();
          final sidebar = find.byKey(
            const ValueKey('general-resource-date-picker'),
          );
          if (sidebar.evaluate().isNotEmpty) {
            Finder day(String value) => find.descendant(
              of: sidebar,
              matching: find.byKey(ValueKey(value)),
            );
            final drag = await tester.startGesture(
              tester.getCenter(day('sked-date-2026-09-09')),
              kind: PointerDeviceKind.mouse,
            );
            await drag.moveTo(tester.getCenter(day('sked-date-2026-09-13')));
            await tester.pumpAndSettle();
            expect(p.customGeneralDateRange, isNull);
            await capture('sidebar-drag-preview');
            await drag.cancel();
            await tester.pumpAndSettle();
            expect(p.customGeneralDateRange, isNull);
          }
          await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is PopupMenuItem<String> && w.value == 'custom',
            ),
          );
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
          await tester.ensureVisible(
            find.byKey(const ValueKey('sked-date-picker-close')),
          );
          await tester.tap(
            find.byKey(const ValueKey('sked-date-picker-close')),
          );
          await tester.pumpAndSettle();
          final timeField = find
              .descendant(of: editor, matching: find.byTooltip(l.pickTime))
              .first;
          await tester.ensureVisible(timeField);
          await tester.tap(timeField);
          await tester.pumpAndSettle();
          expect(find.byType(SkedTimePicker), findsOneWidget);
          expect(find.byType(TimePickerDialog), findsNothing);
          await capture('time-picker');
          if (nativeCheck) {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            await tester.pumpAndSettle();
            final minuteList = find.descendant(
              of: find.byKey(const ValueKey('sked-time-minutes')),
              matching: find.byType(ListView),
            );
            final controller = tester.widget<ListView>(minuteList).controller!;
            final before = controller.offset;
            final background = tester
                .stateList<ScrollableState>(
                  find.descendant(
                    of: find.byType(GeneralScheduleHomeScreen),
                    matching: find.byType(Scrollable),
                  ),
                )
                .toList();
            final offsets = [
              for (final scroll in background) scroll.position.pixels,
            ];
            final report = await _nativeWindow(
              tester,
              'wheel',
              from: tester.getCenter(minuteList),
            );
            await tester.pumpAndSettle();
            expect(controller.offset, isNot(before));
            expect([
              for (final scroll in background) scroll.position.pixels,
            ], offsets);
            expect(report['movedX'], 0);
            expect(report['movedY'], 0);
            nativeEvidence.add(report);
            await File('${out.path}/native-input.json').writeAsString(
              const JsonEncoder.withIndent('  ').convert(nativeEvidence),
            );
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
          }
          final minutes = find.descendant(
            of: find.byKey(const ValueKey('sked-time-minutes')),
            matching: find.byType(ListView),
          );
          final minuteInput = find.byKey(
            const ValueKey('sked-time-minute-input'),
          );
          final beforeMinute = tester
              .widget<TextField>(minuteInput)
              .controller!
              .text;
          await tester.sendEventToBinding(
            PointerScrollEvent(
              kind: PointerDeviceKind.mouse,
              position: tester.getCenter(minutes),
              scrollDelta: const Offset(0, 72),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(minuteInput).controller!.text,
            beforeMinute,
          );
          await tester.enterText(
            find.byKey(const ValueKey('sked-time-hour-input')),
            '09',
          );
          await tester.enterText(minuteInput, '17');
          await tester.pumpAndSettle();
          await capture('time-input-selected');
          await tester.ensureVisible(
            find.byKey(const ValueKey('sked-time-confirm')),
          );
          await tester.tap(find.byKey(const ValueKey('sked-time-confirm')));
          await tester.pumpAndSettle();
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

/// Opt-in native mouse checks target only this test process. The helper refuses
/// input if another window occludes the verified points and restores the cursor.
Future<Map<String, dynamic>> _nativeWindow(
  WidgetTester tester,
  String action, {
  Offset? from,
  Offset? to,
}) async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final previous = binding.shouldPropagateDevicePointerEvents;
  binding.shouldPropagateDevicePointerEvents = action != 'resize';
  try {
    final helper = const String.fromEnvironment('SKED_NATIVE_TOOL');
    final result = await tester.runAsync(
      () => Process.run('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-File',
        helper.isEmpty
            ? File('tool/capture_workbench_window.ps1').absolute.path
            : helper,
        '-ProcessId',
        pid.toString(),
        '-Action',
        action,
        '-CaptionHeightDp',
        '48',
        '-CaptionButtonWidthDp',
        '46',
        '-WidthDp',
        '1440',
        '-HeightDp',
        '900',
        if (from != null) ...[
          '-PointXDp',
          from.dx.toString(),
          '-PointYDp',
          from.dy.toString(),
        ],
        if (to != null) ...[
          '-EndPointXDp',
          to.dx.toString(),
          '-EndPointYDp',
          to.dy.toString(),
        ],
      ]),
    );
    if (result == null) {
      throw StateError('Native helper did not return a result.');
    }
    if (result.exitCode != 0) throw StateError(result.stderr.toString());
    return jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
  } finally {
    binding.shouldPropagateDevicePointerEvents = previous;
  }
}
