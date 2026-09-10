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

import '../test/support/workbench_dense_data.dart';
import '../test/support/workspace_harness.dart';

/// Captures the live Flutter surface only, even if another native window covers
/// the test application. These images do not claim native frame verification.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'render the week picker scrim continuously across window chrome',
    (tester) async {
      await DesktopWindowBridge.instance.initialize();
      expect(DesktopWindowBridge.instance.available, isTrue);
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/chrome-modal-visual',
        ),
      );
      await output.create(recursive: true);
      final captures = <Map<String, Object?>>[];
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final (name, size, scale, brightness)
          in const <(String, Size, double, Brightness)>[
            ('windows-light', Size(1440, 860), 1, Brightness.light),
            ('windows-dark-large-text', Size(1440, 1000), 2, Brightness.dark),
            ('windows-narrow', Size(800, 1020), 1, Brightness.light),
          ]) {
        tester.view.physicalSize = size;
        final provider = await denseWorkbenchProvider(
          mode: AppMode.student,
          locale: 'zh',
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: WorkspaceHarness(
              provider: provider,
              locale: const Locale('zh'),
              brightness: brightness,
              textScale: scale,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<List<ui.Color>> capture(String phase) async {
          expect(tester.takeException(), isNull);
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          try {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = '$name-$phase.png';
            await File('${output.path}/$file')
                .writeAsBytes(png.buffer.asUint8List());
            captures.add({
              'file': file,
              'widthDp': size.width,
              'heightDp': size.height,
              'textScale': scale,
              'brightness': brightness.name,
            });
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final divider = tester.getRect(
              find.byKey(const ValueKey('desktop-window-divider')),
            );
            return [
              for (final p in [
                Offset(size.width / 2, 6),
                Offset(size.width - 8, 6),
                Offset(size.width / 2, divider.center.dy),
                Offset(size.width - 8, divider.center.dy),
              ])
                (() {
                  final offset =
                      (p.dy.floor() * image.width + p.dx.floor()) * 4;
                  return ui.Color.fromARGB(
                    rgba.getUint8(offset + 3),
                    rgba.getUint8(offset),
                    rgba.getUint8(offset + 1),
                    rgba.getUint8(offset + 2),
                  );
                })(),
            ];
          } finally {
            image.dispose();
          }
        }

        final before = await capture('before');
        final context = tester.element(
          find.byKey(const ValueKey('student-workspace-toolbar')),
        );
        final jumpLabel = AppLocalizations.of(context).jumpToWeek;
        await tester.tap(
          find.byKey(const ValueKey('student-week-picker-button')),
        );
        await tester.pumpAndSettle();
        expect(find.text(jumpLabel), findsOneWidget);
        final barrier = tester
            .widget<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
            .color
            .value!;
        final after = await capture('dialog');
        for (var i = 0; i < after.length; i++) {
          final expected = Color.alphaBlend(barrier, before[i]);
          expect(after[i].r, closeTo(expected.r, 2 / 255));
          expect(after[i].g, closeTo(expected.g, 2 / 255));
          expect(after[i].b, closeTo(expected.b, 2 / 255));
        }
        Navigator.of(tester.element(find.text(jumpLabel))).pop();
        await tester.pumpAndSettle();
        final restored = await capture('closed');
        expect(restored, before);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      }
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'capturedAt': DateTime.now().toUtc().toIso8601String(),
          'kind': 'Actual Flutter client renderer on Windows; not native frame or Android hardware',
          'fixtures': 'Isolated in-memory timetable; no user storage',
          'captures': captures,
        }),
      );
    },
  );
}
