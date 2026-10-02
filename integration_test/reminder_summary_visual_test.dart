import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../test/support/reminder_summary_harness.dart';
import '../test/support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'grouped reminders with Windows fonts in light dark and large text',
    (t) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/reminder-summary-visual',
        ),
      );
      await output.create(recursive: true);
      final captures = <String>[];
      addTearDown(t.view.reset);
      for (final locale in ['zh', 'en']) {
        for (final scale in [1.0, 1.5, 2.0]) {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1366, 900);
          final p = await workspaceProvider(
            mode: AppMode.general,
            storage: reminderSummaryStorage(locale: locale),
          );
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: reminderSummaryHarness(
                p,
                ReminderSummaryClock(),
                session: GeneralReminderStartupSession(),
                locale: locale,
                scale: scale,
                brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(k('general-reminders-list'), findsOneWidget);
          Future<void> capture(String scene) async {
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final file = '$locale-$scale-$scene.png';
              await File('${output.path}/$file')
                  .writeAsBytes(bytes.buffer.asUint8List());
              captures.add(file);
            } finally {
              image.dispose();
            }
          }

          await capture('startup');
          await t.drag(k('workspace-view-drag-handle'), const Offset(-80, 25));
          await t.pumpAndSettle();
          await capture('grouped');
          final reminderElement = t.element(k('general-reminders-list'));
          final reminderRect = t.getRect(k('general-reminders-list'));
          await t.tap(
            find.descendant(
              of: k('general-reminders-list'),
              matching: find.text(locale == 'zh' ? '学习小组' : 'Study group'),
            ),
          );
          await t.pumpAndSettle();
          expect(t.element(k('general-reminders-list')), same(reminderElement));
          expect(t.getRect(k('general-reminders-list')), reminderRect);
          expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
          await capture('companion-detail');
          await t.tap(
            find.descendant(
              of: find.byType(GeneralEventDetailsSheet),
              matching: k('workspace-inspector-close'),
            ),
          );
          await t.pumpAndSettle();
          expect(t.element(k('general-reminders-list')), same(reminderElement));
          if (scale == 2) {
            t.view.physicalSize = const Size(920, 620);
            await t.pumpAndSettle();
            await t.drag(k('workspace-view-body'), const Offset(0, -280));
            await capture('short-window-scrolled');
          }
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          p.dispose();
        }
      }
      await File('${output.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'captures': captures,
          'evidence': 'Actual Windows Flutter font rendering, in-memory data; pointer gestures are synthetic, not native mouse acceptance.',
        }),
      );
    },
  );
}
