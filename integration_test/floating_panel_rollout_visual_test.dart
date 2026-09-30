import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_floating_surface.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';
import 'package:sked/l10n/app_localizations.dart';

import '../test/support/workspace_harness.dart';
import 'category_manager_visual_test.dart' as categories;
import 'desktop_view_panels_visual_test.dart' as views;

void main() {
  categories.main();
  views.main();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'course fields open adjacent redesigned panels with actual fonts',
    (t) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/floating-v2',
        ),
      );
      await output.create(recursive: true);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1366, 900);
      addTearDown(t.view.reset);
      for (final locale in ['en', 'zh']) {
        for (final scale in [1.0, 1.5, 2.0]) {
          final p = await workspaceProvider(locale: locale);
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
                      width: 390,
                      child: CourseEditorSheet(
                        periodTimes: buildDefaultPeriodTimes(),
                        totalWeeks: 19,
                        dayOfWeek: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final l = AppLocalizations.of(
            t.element(find.byType(CourseEditorSheet)),
          );
          for (final (label, scene) in [
            (l.dayOfWeek, 'weekday'),
            (l.semesterWeeks, 'weeks'),
            (l.linkedPeriods, 'periods'),
          ]) {
            final trigger = find.text(label).first;
            await t.ensureVisible(trigger);
            await t.tap(trigger);
            await t.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('sked-picker-drag-handle')),
              findsOneWidget,
            );
            if (scene == 'weekday') {
              expect(
                t.getRect(find.byType(SkedFloatingSurface)).right,
                lessThan(t.getRect(trigger).left),
              );
            }
            Future<void> capture(String suffix) async {
              expect(t.takeException(), isNull);
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File('${output.path}/$locale-$scale-$scene$suffix.png')
                  .writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            }

            await capture('');
            await t.drag(
              find.byKey(const ValueKey('sked-picker-drag-handle')),
              const Offset(-50, 30),
            );
            await t.pumpAndSettle();
            await capture('-dragged');
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
          }
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: Locale(locale),
                textScale: scale,
                home: const ThemeSettingsPage(),
              ),
            ),
          );
          await t.pumpAndSettle();
          final custom = find.text(l.themeCustomColor).first;
          await t.ensureVisible(custom);
          await t.tap(custom);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('${output.path}/$locale-$scale-color.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          p.dispose();
        }
      }
    },
  );
  testWidgets(
    'desktop floating choices actual-font light dark locale and scale gallery',
    (t) async {
      final output = Directory(
        const String.fromEnvironment(
          'SKED_VISUAL_OUTPUT',
          defaultValue: '.scratch/floating-panel-rollout',
        ),
      );
      await output.create(recursive: true);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 900);
      addTearDown(t.view.reset);
      for (final locale in ['zh', 'en']) {
        for (final brightness in Brightness.values) {
          for (final scale in [1.0, 1.5, 2.0]) {
            final p = await workspaceProvider(locale: locale);
            final boundary = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: p,
                  seedColor: const Color(0xff008577),
                  locale: Locale(locale),
                  textScale: scale,
                  brightness: brightness,
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.fromLTRB(80, 110, 80, 0),
                      child: Builder(
                        builder: (context) {
                          final l = AppLocalizations.of(context);
                          return Wrap(
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              Builder(
                                builder: (anchor) => OutlinedButton(
                                  key: const ValueKey('gallery-date'),
                                  onPressed: () => unawaited(
                                    showSkedDatePicker(
                                      context: anchor,
                                      anchorContext: anchor,
                                      initialDate: DateTime(2026, 9, 30),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    ),
                                  ),
                                  child: Text(l.semesterStartDate),
                                ),
                              ),
                              Builder(
                                builder: (anchor) => OutlinedButton(
                                  key: const ValueKey('gallery-time'),
                                  onPressed: () => unawaited(
                                    showSkedTimePicker(
                                      context: anchor,
                                      anchorContext: anchor,
                                      initialTime: const TimeOfDay(
                                        hour: 15,
                                        minute: 30,
                                      ),
                                    ),
                                  ),
                                  child: Text(l.startTime),
                                ),
                              ),
                              Builder(
                                builder: (anchor) => OutlinedButton(
                                  key: const ValueKey('gallery-periods'),
                                  onPressed: () => unawaited(
                                    showPeriodTimeSetPickerDialog(
                                      anchor,
                                      provider: p,
                                      anchorContext: anchor,
                                      selectedPeriodTimeSetId:
                                          p.periodTimeSets.first.id,
                                    ),
                                  ),
                                  child: Text(l.periodTimeSets),
                                ),
                              ),
                              SkedPopupMenuButton<String>(
                                key: const ValueKey('gallery-menu'),
                                tooltip: l.more,
                                itemBuilder: (_) => [
                                  SkedPopupMenuItem(
                                    value: 'edit',
                                    child: Text(l.editTimetable),
                                  ),
                                  SkedPopupMenuItem(
                                    value: 'rename',
                                    child: Text(l.rename),
                                  ),
                                ],
                                icon: const Icon(Icons.more_horiz),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            for (final scene in ['date', 'time', 'periods', 'menu']) {
              await t.tap(find.byKey(ValueKey('gallery-$scene')));
              await t.pumpAndSettle();
              expect(
                t.takeException(),
                isNull,
                reason: '$locale-$brightness-$scale-$scene',
              );
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                '${output.path}/$locale-${brightness.name}-$scale-$scene.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
              await t.sendKeyEvent(LogicalKeyboardKey.escape);
              await t.pumpAndSettle();
            }
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            p.dispose();
          }
        }
      }
    },
  );
}
