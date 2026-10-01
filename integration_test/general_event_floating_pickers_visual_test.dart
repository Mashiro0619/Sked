import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_floating_surface.dart';

import '../test/support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'general recurrence and reminders render adjacent with real Windows fonts',
    (t) async {
      await DesktopWindowBridge.instance.initialize();
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/general-floating-visual',
        ),
      );
      await output.create(recursive: true);
      final captures = <Map<String, Object?>>[];
      final nativeEvidence = <Map<String, Object?>>[];
      addTearDown(t.view.reset);
      addTearDown(
        () => File('${output.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert({'captures': captures, 'native': nativeEvidence}),
        ),
      );
      for (final locale in ['zh', 'en']) {
        for (final scale in [1.0, 1.5, 2.0]) {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1366, 900);
          final p = await workspaceProvider(
            mode: AppMode.general,
            locale: locale,
          );
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: Locale(locale),
                textScale: scale,
                brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 410,
                      child: GeneralEventEditorSheet(
                        initialDate: DateTime(2026, 10, 16),
                        calendars: const [
                          GeneralSchedule(id: 'work', name: 'Work', events: []),
                        ],
                        activeCalendarId: 'work',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final l = AppLocalizations.of(
            t.element(find.byType(GeneralEventEditorSheet)),
          );
          Future<void> tap(Finder field) async {
            await t.ensureVisible(field);
            await t.pumpAndSettle();
            await t.tap(field);
            await t.pumpAndSettle();
          }

          Future<void> capture(String scene) async {
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '$locale-$scale-$scene');
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final file = '$locale-$scale-$scene.png';
              await File('${output.path}/$file')
                  .writeAsBytes(bytes.buffer.asUint8List());
              captures.add({
                'file': file,
                'locale': locale,
                'scale': scale,
                'evidence': 'actual Windows Flutter rendering',
              });
            } finally {
              image.dispose();
            }
          }

          Future<void> checkNativeDrag(String which) async {
            if (locale != 'zh' ||
                scale != 1 ||
                !const bool.fromEnvironment('SKED_NATIVE_POINTER_CHECK')) {
              return;
            }
            t.view.resetPhysicalSize();
            t.view.resetDevicePixelRatio();
            Future<ProcessResult?> native(
              String action, {
              Offset? from,
              Offset? to,
            }) => t.runAsync(
              () => Process.run('powershell', [
                '-NoProfile',
                '-WindowStyle',
                'Hidden',
                '-ExecutionPolicy',
                'Bypass',
                '-File',
                File('tool/capture_workbench_window.ps1').absolute.path,
                '-ProcessId',
                '$pid',
                '-Action',
                action,
                '-WidthDp',
                '1280',
                '-HeightDp',
                '800',
                '-CaptionHeightDp',
                '48',
                '-CaptionButtonWidthDp',
                '46',
                if (from != null) ...[
                  '-PointXDp',
                  '${from.dx}',
                  '-PointYDp',
                  '${from.dy}',
                ],
                if (to != null) ...[
                  '-EndPointXDp',
                  '${to.dx}',
                  '-EndPointYDp',
                  '${to.dy}',
                ],
              ]),
            );
            final resize = await native('resize');
            expect(resize!.exitCode, 0, reason: '${resize.stderr}');
            await t.pumpAndSettle();
            await t.runAsync(
              () => Process.run('powershell', [
                '-NoProfile',
                '-WindowStyle',
                'Hidden',
                '-Command',
                '(New-Object -ComObject WScript.Shell).AppActivate($pid)',
              ]),
            );
            await t.pumpAndSettle();
            final before = t.getRect(find.byType(SkedFloatingSurface));
            debugPrint(
              'Native before: $before, physical=${t.view.physicalSize}, dpr=${t.view.devicePixelRatio}, resize=${resize.stdout}',
            );
            final from = t.getCenter(k('sked-picker-drag-handle'));
            final drag = await native(
              'range-drag',
              from: from,
              to: from + const Offset(-50, -25),
            );
            await t.pumpAndSettle();
            if (drag!.exitCode != 0) {
              // Do not bypass input ownership safeguards or claim native success.
              nativeEvidence.add({
                'panel': which,
                'status': 'blocked',
                'exitCode': drag.exitCode,
                'reason': '${drag.stderr}',
              });
              debugPrint('Native drag not verified: ${drag.stderr}');
            } else {
              final report =
                  jsonDecode('${drag.stdout}'.trim()) as Map<String, dynamic>;
              final after = t.getRect(find.byType(SkedFloatingSurface));
              debugPrint(
                'Native after: $after, from=$from, physical=${t.view.physicalSize}, dpr=${t.view.devicePixelRatio}, report=$report',
              );
              expect(after.left - before.left, closeTo(-50, 3));
              expect(after.top - before.top, closeTo(-25, 3));
              expect(report['movedX'], 0);
              expect(report['movedY'], 0);
              nativeEvidence.add({
                'panel': which,
                'status': 'passed',
                'geometry': report,
                'dx': after.left - before.left,
                'dy': after.top - before.top,
              });
            }
            await capture('$which-native-drag-attempt');
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(1366, 900);
            await t.pumpAndSettle();
          }

          await tap(k('event-recurrence-field'));
          final recurrence = find.byType(SkedFloatingSurface);
          expect(
            t.getRect(recurrence).right,
            closeTo(t.getRect(k('event-recurrence-field')).left - 6, 1),
          );
          await capture('recurrence-none');
          await checkNativeDrag('recurrence');
          await tap(k('general-recurrence-choice-custom'));
          await capture('recurrence-custom');
          await t.drag(k('sked-picker-drag-handle'), const Offset(-70, -30));
          await t.pumpAndSettle();
          await capture('recurrence-dragged');
          await tap(find.text(l.recurrenceEndDate));
          await capture('recurrence-end-date');
          await tap(k('sked-date-cancel'));
          await tap(k('general-recurrence-cancel'));
          await tap(k('event-reminder-field'));
          await tap(k('general-reminder-choice-5'));
          await tap(k('general-reminder-choice-60'));
          await capture('reminder-multiple');
          await checkNativeDrag('reminder');
          await t.drag(k('sked-picker-drag-handle'), const Offset(-70, -30));
          await t.pumpAndSettle();
          await capture('reminder-dragged');
          await tap(k('general-reminder-cancel'));
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          p.dispose();
        }
      }
    },
  );
}
