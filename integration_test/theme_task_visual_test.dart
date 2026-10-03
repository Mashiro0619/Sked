import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../test/support/theme_task_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'theme color normal invalid busy and failed Windows screenshots',
    (t) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/theme-task-visual',
        ),
      );
      await output.create(recursive: true);
      for (final kind in ['seed', 'value', 'course']) {
        for (final scale in [1.0, 2.0]) {
          final key = GlobalKey();
          final (_, storage) = await mountThemeTask(
            t,
            kind: kind,
            captureKey: key,
            textScale: scale,
            brightness: scale == 2 ? Brightness.dark : Brightness.light,
          );
          Future<void> capture(String state) async {
            await t.pump();
            expect(t.takeException(), isNull);
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            try {
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File('${output.path}/$kind-$scale-$state.png')
                  .writeAsBytes(data.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          }

          await capture('normal');
          final field = themeTaskKey('compact-color-picker-hex-field');
          await t.enterText(field, '#ZZ1234');
          await t.pumpAndSettle();
          expect(t.widget<FilledButton>(themeApply(kind)).onPressed, isNull);
          await capture('invalid');
          await t.enterText(field, '#197A86');
          await t.pumpAndSettle();
          final gate = Completer<void>();
          storage.pending = gate;
          storage.saveError = StateError('Visual regression save failure');
          try {
            await t.ensureVisible(themeApply(kind));
            await t.tap(themeApply(kind));
            await t.pump();
            await t.pump(const Duration(milliseconds: 300));
            expect(t.widget<FilledButton>(themeApply(kind)).onPressed, isNull);
            await capture('busy');
          } finally {
            gate.complete();
            storage.pending = null;
          }
          await t.pumpAndSettle();
          expect(themeTask, findsOneWidget);
          expect(t.widget<FilledButton>(themeApply(kind)).onPressed, isNotNull);
          await capture('failed');
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        }
      }
    },
  );
}
