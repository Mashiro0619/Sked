import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/workspace_frame.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';

import '../test/support/workspace_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('desktop editor Windows-font layout matrix', (t) async {
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/desktop-editor-visual',
      ),
    );
    await output.create(recursive: true);
    addTearDown(t.view.reset);
    for (final mode in AppMode.values) {
      for (final locale in ['zh', 'en']) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final editing in [false, true]) {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(1600, 1100);
            final p = await workspaceProvider(mode: mode, locale: locale);
            final captureKey = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: captureKey,
                child: WorkspaceHarness(
                  provider: p,
                  locale: Locale(locale),
                  textScale: scale,
                  brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
                  textDirection: locale == 'en' && scale == 2
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
              ),
            );
            await t.pumpAndSettle();
            final frameFinder = find.byType(WorkspaceFrame);
            final frame = t.widget<WorkspaceFrame>(frameFinder);
            final context = t.element(frameFinder);
            final button = find.byKey(
              ValueKey(
                mode == AppMode.general
                    ? 'general-add-event'
                    : 'student-add-course',
              ),
            );
            final anchor = t.element(button);
            final table = p.activeTimetableOrNull;
            final calendar = editing
                ? p.generalSchedules.firstWhere(
                    (calendar) => calendar.events.isNotEmpty,
                  )
                : p.generalSchedules.first;
            final c = table?.courses.firstOrNull;
            final e = calendar.events.firstOrNull;
            final saveGate = Completer<void>();
            Future<void> save(Object _) async {
              await saveGate.future;
              throw StateError('Visual test: save unavailable');
            }

            final editorTask = showAppModalSheet<void>(
              context: context,
              workspacePane: frame.controller,
              editor: WorkspaceEditorConfiguration(anchorContext: anchor),
              workspace: mode,
              builder: (_) => mode == AppMode.general
                  ? GeneralEventEditorSheet(
                      calendars: p.generalSchedules,
                      activeCalendarId: calendar.id,
                      initialDate: DateTime(2026, 10, 4),
                      initialEvent: editing ? e : null,
                      onSave: save,
                    )
                  : CourseEditorSheet(
                      periodTimes: p.periodTimesForTimetable(table!),
                      totalWeeks: table.config.totalWeeks,
                      dayOfWeek: 1,
                      initialCourse: editing ? c : null,
                      onSave: save,
                    ),
            );
            unawaited(editorTask);
            await t.pumpAndSettle();
            if (editing) expect(mode == AppMode.general ? e : c, isNotNull);
            expect(
              find.text(
                mode == AppMode.general
                    ? (editing
                          ? (locale == 'zh' ? '编辑日程' : 'Edit event')
                          : (locale == 'zh' ? '添加日程' : 'Add event'))
                    : (editing
                          ? (locale == 'zh' ? '编辑课程' : 'Edit course')
                          : (locale == 'zh' ? '添加课程' : 'Add course')),
              ),
              findsWidgets,
            );
            Future<void> capture(String state, {bool settle = true}) async {
              if (settle) await t.pumpAndSettle();
              expect(t.takeException(), isNull);
              final image =
                  await (captureKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                await File(
                  '${output.path}/${mode.name}-$locale-$scale-${editing ? 'edit' : 'add'}-$state.png',
                ).writeAsBytes(bytes.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            }

            if (mode == AppMode.general && scale == 1) {
              final rows = find.byType(WorkspaceEditorTimeRows);
              final strings = AppLocalizations.of(t.element(rows));
              final dates = find.descendant(
                of: rows,
                matching: find.byTooltip(strings.pickDate),
              );
              final toggle = find.descendant(
                of: rows,
                matching: find.byType(Switch),
              );
              expect(
                t.getCenter(toggle).dy,
                closeTo(t.getCenter(dates.first).dy, .1),
              );
              expect(
                t.getTopLeft(dates.first).dx,
                closeTo(t.getTopLeft(dates.last).dx, .1),
              );
            }
            await capture('floating');
            if (scale == 1) {
              await p.updateWorkspacePanelDisplayMode(
                WorkspacePanelDisplayMode.sideBySide,
              );
              await capture('docked');
            }
            t.view.physicalSize = const Size(720, 420);
            await capture('short');
            expect(
              find
                  .byKey(const ValueKey('workspace-editor-close'))
                  .hitTestable(),
              findsOneWidget,
            );
            final l = AppLocalizations.of(
              t.element(
                find.byType(
                  mode == AppMode.general
                      ? GeneralEventEditorSheet
                      : CourseEditorSheet,
                ),
              ),
            );
            final saveButton = find.widgetWithText(FilledButton, l.save);
            expect(saveButton.hitTestable(), findsOneWidget);
            if (editing && scale == 1) {
              t.view.physicalSize = const Size(1600, 1100);
              await p.updateWorkspacePanelDisplayMode(
                WorkspacePanelDisplayMode.overlay,
              );
              await t.pumpAndSettle();
              final editor = find.byType(
                mode == AppMode.general
                    ? GeneralEventEditorSheet
                    : CourseEditorSheet,
              );
              final element = t.element(editor);
              await t.tap(saveButton);
              await t.pump(const Duration(milliseconds: 200));
              expect(t.widget<FilledButton>(saveButton).onPressed, isNull);
              expect(
                t
                    .widget<IconButton>(
                      find.byKey(const ValueKey('workspace-editor-close')),
                    )
                    .onPressed,
                isNull,
              );
              await capture('saving', settle: false);
              saveGate.complete();
              await t.pumpAndSettle();
              expect(t.element(editor), same(element));
              expect(t.widget<FilledButton>(saveButton).onPressed, isNotNull);
              expect(find.text(l.saveFailedRetry), findsWidgets);
              await capture('save-error');
            }
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            p.dispose();
          }
        }
      }
    }
  });
}
