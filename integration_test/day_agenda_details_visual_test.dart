import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../test/support/agenda_detail_harness.dart';
import '../test/support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
Finder get agenda => k('general-selected-day-agenda');
Finder get detail => find.byType(GeneralEventDetailsSheet);
Finder inside(String key) => find.descendant(of: detail, matching: k(key));
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'day agenda preview and independent detail Windows font screenshots',
    (t) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/day-agenda-details-visual',
        ),
      );
      await output.create(recursive: true);
      final captures = <String>[];
      addTearDown(t.view.reset);
      for (final fixed in [false, true]) {
        for (final locale in ['zh', 'en']) {
          for (final scale in [1.0, 1.5, 2.0]) {
            final direction = locale == 'en' && scale == 2
                ? TextDirection.rtl
                : TextDirection.ltr;
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = Size(fixed ? 1440 * scale : 1440, 900);
            final p = await workspaceProvider(
              mode: AppMode.general,
              storage: agendaDetailStorage(
                locale: locale,
                view: fixed ? generalViewMonth : generalViewWeek,
                count: 3,
                longNotes: scale == 2,
              ),
            );
            final boundary = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: agendaDetailHarness(
                  p,
                  locale: locale,
                  scale: scale,
                  direction: direction,
                  brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
                ),
              ),
            );
            await t.pumpAndSettle();
            if (!fixed) {
              if (k('general-day-agenda-toggle').evaluate().isEmpty) {
                await t.tap(k('general-desktop-toolbar-more'));
                await t.pumpAndSettle();
              }
              await t.tap(k('general-day-agenda-toggle'));
              await t.pumpAndSettle();
            }
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
                final filename =
                    '${fixed ? 'fixed' : 'floating'}-$locale-$scale-${direction.name}-$scene.png';
                await File('${output.path}/$filename')
                    .writeAsBytes(bytes.buffer.asUint8List());
                captures.add(filename);
              } finally {
                image.dispose();
              }
            }

            final m = await t.createGesture(kind: PointerDeviceKind.mouse);
            await m.addPointer(location: const Offset(2, 2));
            await m.moveTo(
              t.getCenter(
                find.descendant(
                  of: agenda,
                  matching: find.text(
                    locale == 'zh' ? '复习计划' : 'Review session',
                  ),
                ),
              ),
            );
            await t.pump(const Duration(milliseconds: 350));
            await t.pumpAndSettle();
            expect(detail, findsOneWidget);
            expect(inside('workspace-inspector-close'), findsNothing);
            await capture('preview');
            final element = t.element(detail);
            await t.tap(k('reminder-detail-detach'));
            await t.pumpAndSettle();
            expect(t.element(detail), same(element));
            await t.drag(
              inside('workspace-view-drag-handle'),
              const Offset(-35, 20),
            );
            await t.pumpAndSettle();
            if (scale == 2) {
              await t.drag(
                inside('workspace-view-body'),
                const Offset(0, -120),
              );
              await t.pumpAndSettle();
            }
            final pos = t.getRect(k('workspace-companion-view-surface'));
            final body = t.state<ScrollableState>(
              find
                  .descendant(of: detail, matching: find.byType(Scrollable))
                  .last,
            );
            final scroll = body.position.pixels;
            await capture('independent');
            if (fixed) {
              await p.setSelectedGeneralDate(DateTime(2026, 9, 29));
            } else {
              await t.tap(
                find.descendant(
                  of: agenda,
                  matching: k('workspace-inspector-close'),
                ),
              );
            }
            await t.pumpAndSettle();
            expect(t.element(detail), same(element));
            expect(t.getRect(k('workspace-companion-view-surface')), pos);
            expect(body.position.pixels, scroll);
            await capture(fixed ? 'source-date-changed' : 'source-closed');
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
          'evidence': 'Actual Windows fonts; synthetic mouse. No native input pass claimed.',
        }),
      );
    },
  );
}
