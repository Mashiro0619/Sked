import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../test/support/reminder_summary_harness.dart';
import '../test/support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));
Finder get details => find.byType(GeneralEventDetailsSheet);
Finder row(String title) => find.descendant(
  of: k('general-reminders-list'),
  matching: find.text(title),
);
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('hover preview and independent detail use one Windows surface', (
    t,
  ) async {
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/reminder-independent-visual',
      ),
    );
    await output.create(recursive: true);
    final captures = <String>[];
    addTearDown(t.view.reset);
    for (final locale in ['zh', 'en']) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1440, 900);
          final storage = reminderSummaryStorage(locale: locale);
          if (scale == 2) {
            final calendar = storage.data.generalMode.schedules.single;
            storage.data = storage.data.copyWith(
              generalMode: storage.data.generalMode.copyWith(
                schedules: [
                  calendar.copyWith(
                    events: [
                      for (final event in calendar.events)
                        event.id == 'study'
                            ? event.copyWith(
                                notes: List.filled(
                                  60,
                                  locale == 'zh' ? '用于验证独立面板限高与滚动保持的长备注。' : 'Long notes to verify independent height and scroll retention.',
                                ).join('\n'),
                              )
                            : event,
                    ],
                  ),
                ],
              ),
            );
          }
          final p = await workspaceProvider(
            mode: AppMode.general,
            storage: storage,
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
                direction: direction,
                brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
              ),
            ),
          );
          await t.pumpAndSettle();
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
              final file = '$locale-$scale-${direction.name}-$scene.png';
              await File('${output.path}/$file')
                  .writeAsBytes(bytes.buffer.asUint8List());
              captures.add(file);
            } finally {
              image.dispose();
            }
          }

          final m = await t.createGesture(kind: PointerDeviceKind.mouse);
          await m.addPointer(location: const Offset(2, 2));
          final title = locale == 'zh' ? '学习小组' : 'Study group';
          await m.moveTo(t.getCenter(row(title)));
          await t.pump(const Duration(milliseconds: 350));
          expect(
            find.descendant(
              of: details,
              matching: k('workspace-inspector-close'),
            ),
            findsNothing,
          );
          await capture('preview');
          final element = t.element(details);
          await t.tap(k('reminder-detail-detach'));
          await t.pumpAndSettle();
          expect(t.element(details), same(element));
          await capture('independent');
          await t.drag(
            find.descendant(
              of: details,
              matching: k('workspace-view-drag-handle'),
            ),
            const Offset(-45, 25),
          );
          await t.pumpAndSettle();
          // Large text can overlap the list: move the detail up first so the next
          // row is visible; the narrow-window screenshot records normal overlap.
          if (scale < 2) {
            await t.tap(row(locale == 'zh' ? '账单日' : 'Bill day'));
            await t.pumpAndSettle();
            await capture('switched');
          }
          if (scale == 2) {
            await t.drag(
              find.descendant(of: details, matching: k('workspace-view-body')),
              const Offset(0, -120),
            );
            await t.pumpAndSettle();
            await capture('long-scrolled-before-close');
          }
          final body = t.state<ScrollableState>(
            find
                .descendant(of: details, matching: find.byType(Scrollable))
                .last,
          );
          final scroll = body.position.pixels;
          final independent = t.element(details);
          final position = t.getRect(k('workspace-companion-view-surface'));
          await t.tap(
            find.descendant(
              of: k('general-reminders-list'),
              matching: k('workspace-inspector-close'),
            ),
          );
          await t.pumpAndSettle();
          expect(k('general-reminders-list'), findsNothing);
          expect(t.element(details), same(independent));
          expect(t.getRect(k('workspace-companion-view-surface')), position);
          expect(body.position.pixels, scroll);
          await capture('list-closed');
          t.view.physicalSize = const Size(1100, 720);
          await capture('resized');
          await m.removePointer();
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          p.dispose();
        }
      }
    }
    await File('${output.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'captures': captures,
        'evidence': 'Actual Windows fonts; synthetic pointer scenarios. Native result recorded separately.',
      }),
    );
  });

  testWidgets('native mouse hover crossing, upgrade, switch, drag and close', (
    t,
  ) async {
    if (!const bool.fromEnvironment('SKED_NATIVE_POINTER_CHECK')) return;
    binding.shouldPropagateDevicePointerEvents = true;
    await DesktopWindowBridge.instance.initialize();
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/reminder-hover-visual',
      ),
    );
    await output.create(recursive: true);
    final evidence = <Map<String, dynamic>>[];
    addTearDown(
      () => File('${output.path}/native.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(evidence)),
    );
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    final pointerPositions = <Map<String, Object?>>[];
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    await t.pumpWidget(
      Listener(
        onPointerHover: (event) => pointerPositions.add({
          'dx': event.position.dx,
          'dy': event.position.dy,
          'kind': event.kind.name,
        }),
        child: reminderSummaryHarness(p, ReminderSummaryClock()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(k('general-reminders-action'));
    await t.pumpAndSettle();
    Map<String, dynamic>? cursor;
    Future<Map<String, dynamic>> command(
      String action, {
      Offset? point,
      Offset? to,
    }) async {
      final reply = (await t.runAsync(
        () => Process.run('powershell', [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          File('tool/reminder_pointer_session.ps1').absolute.path,
          '-ProcessId',
          '$pid',
          '-Action',
          action,
          if (point != null) ...['-X', '${point.dx}', '-Y', '${point.dy}'],
          if (to != null) ...['-EndX', '${to.dx}', '-EndY', '${to.dy}'],
          if (action == 'restore') ...[
            '-SavedX',
            '${cursor!['savedX']}',
            '-SavedY',
            '${cursor['savedY']}',
          ],
        ]),
      ))!;
      final result = '${reply.stdout}'.trim();
      final report = result.startsWith('{')
          ? jsonDecode(result) as Map<String, dynamic>
          : <String, dynamic>{
              'status': 'blocked',
              'reason': '${reply.stderr}',
              'action': action,
            };
      evidence.add(report);
      return report;
    }

    Future<bool> native(String action, Offset point, {Offset? to}) async {
      final response = await command(action, point: point, to: to);
      await t.pumpAndSettle();
      return response['status'] == 'ok';
    }

    try {
      cursor = await command('inspect');
      if (cursor['status'] != 'ok') return;
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
      final target = t.getCenter(row('Study group'));
      evidence.add({
        'phase': 'native-target',
        'dx': target.dx,
        'dy': target.dy,
        'physical': '${t.view.physicalSize}',
        'dpr': t.view.devicePixelRatio,
      });
      if (!await native('move', target)) return;
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      final panel = t.getRect(k('workspace-companion-view-surface'));
      final source = t.getRect(
        find.ancestor(of: row('Study group'), matching: find.byType(ListTile)),
      );
      if (!await native(
        'move',
        Offset((source.left + panel.right) / 2, source.top + 16),
      )) {
        return;
      }
      await t.pump(const Duration(milliseconds: 300));
      expect(details, findsOneWidget);
      if (!await native('move', panel.center)) return;
      await t.pump(const Duration(milliseconds: 300));
      expect(details, findsOneWidget);
      if (!await native('click', t.getCenter(k('reminder-detail-detach')))) {
        return;
      }
      expect(k('reminder-detail-detach'), findsNothing);
      final before = t.getRect(k('workspace-companion-view-surface'));
      final handle = t.getCenter(
        find.descendant(of: details, matching: k('workspace-view-drag-handle')),
      );
      if (!await native('drag', handle, to: handle + const Offset(-45, 25))) {
        return;
      }
      final after = t.getRect(k('workspace-companion-view-surface'));
      expect(after.left - before.left, closeTo(-45, 3));
      expect(after.top - before.top, closeTo(25, 3));
      if (!await native('click', t.getCenter(row('Bill day')))) return;
      expect(
        find.descendant(of: details, matching: find.text('Bill day')),
        findsOneWidget,
      );
      if (!await native('click', const Offset(450, 700))) return;
      expect(details, findsOneWidget);
      final listVisibleAfterOutside = k('general-reminders-list')
          .evaluate()
          .isNotEmpty;
      if (listVisibleAfterOutside) {
        if (!await native(
          'click',
          t.getCenter(
            find.descendant(
              of: k('general-reminders-list'),
              matching: k('workspace-inspector-close'),
            ),
          ),
        )) {
          return;
        }
        expect(details, findsOneWidget);
      }
      expect(k('general-reminders-list'), findsNothing);
      if (!await native(
        'click',
        t.getCenter(
          find.descendant(
            of: details,
            matching: k('workspace-inspector-close'),
          ),
        ),
      )) {
        return;
      }
      expect(details, findsNothing);
      evidence.add({
        'status': 'passed',
        'scenarios': 'hover without X, corridor, independence, drag, switch, outside survival, source close, own X',
      });
    } catch (error) {
      evidence.add({
        'status': 'failed',
        'reason': '$error',
        'pointerEvents': pointerPositions,
      });
      rethrow;
    } finally {
      if (cursor?['status'] == 'ok') await command('restore');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      p.dispose();
      binding.shouldPropagateDevicePointerEvents = false;
    }
  });
}
