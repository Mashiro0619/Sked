import 'dart:async';
import 'dart:convert';
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

import '../../test/support/workspace_harness.dart';

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('desktop editor Windows-font layout matrix', (t) async {
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/capture-scenes/workspace-editor',
      ),
    );
    await output.create(recursive: true);
    final captures = <Map<String, Object?>>[];
    addTearDown(t.view.reset);
    for (final mode in AppMode.values) {
      for (final locale in ['zh', 'en']) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final editing in [false, true]) {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(1600, 1100);
            final p = await workspaceProvider(mode: mode, locale: locale);
            String domainSnapshot() => jsonEncode({
              'timetables': p.studentView.timetables
                  .map((table) => table.toJson())
                  .toList(),
              'calendars': p.generalView.schedules
                  .map((calendar) => calendar.toJson())
                  .toList(),
            });
            final originalDomainData = domainSnapshot();
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
            final table = p.studentView.activeTimetableOrNull;
            final calendar = editing
                ? p.generalView.schedules.firstWhere(
                    (calendar) => calendar.events.isNotEmpty,
                  )
                : p.generalView.schedules.first;
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
              editor: WorkspaceEditorConfiguration(
                anchorContext: anchor,
                preferredWidth: mode == AppMode.general ? 480 : 440,
              ),
              workspace: mode,
              builder: (_) => mode == AppMode.general
                  ? GeneralEventEditorSheet(
                      calendars: p.generalView.schedules,
                      activeCalendarId: calendar.id,
                      initialDate: DateTime(2026, 10, 4),
                      initialEvent: editing ? e : null,
                      onSave: save,
                    )
                  : CourseEditorSheet(
                      periodTimes: p.studentView.periodTimesForTimetable(
                        table!,
                      ),
                      totalWeeks: table.config.totalWeeks,
                      dayOfWeek: 1,
                      initialCourse: editing ? c : null,
                      onSave: save,
                    ),
            );
            unawaited(editorTask);
            await t.pumpAndSettle();
            expect(
              t
                  .getSize(
                    find.byKey(const ValueKey('workspace-detail-surface')),
                  )
                  .width,
              closeTo(mode == AppMode.general ? 480 : 440, .1),
            );
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
            final initialTimeGeometry = <String, Object?>{};
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
                final filename =
                    '${mode.name}-$locale-$scale-${editing ? 'edit' : 'add'}-$state.png';
                await File('${output.path}/$filename')
                    .writeAsBytes(bytes.buffer.asUint8List());
                captures.add({
                  'file': filename,
                  'mode': mode.name,
                  'locale': locale,
                  'textScale': scale,
                  'editing': editing,
                  'state': state,
                  'widthPx': image.width,
                  'heightPx': image.height,
                  if (initialTimeGeometry.isNotEmpty)
                    'initialTimeGeometry': initialTimeGeometry,
                });
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
              final times = find.descendant(
                of: rows,
                matching: find.byTooltip(strings.pickTime),
              );
              final startLabel = find.descendant(
                of: rows,
                matching: find.text(strings.eventStartTime),
              );
              final endLabel = find.descendant(
                of: rows,
                matching: find.text(strings.eventEndTime),
              );
              final geometry = <String, ui.Rect>{
                'startLabel': t.getRect(startLabel),
                'startDate': t.getRect(dates.first),
                'startTime': t.getRect(times.first),
                'allDaySwitch': t.getRect(toggle),
                'endLabel': t.getRect(endLabel),
                'endDate': t.getRect(dates.last),
                'endTime': t.getRect(times.last),
              };
              final entries = geometry.entries.toList();
              for (var i = 0; i < entries.length; i++) {
                for (var j = i + 1; j < entries.length; j++) {
                  expect(
                    entries[i].value.overlaps(entries[j].value),
                    isFalse,
                    reason:
                        '${entries[i].key} must not overlap ${entries[j].key}',
                  );
                }
              }
              final labelRect = geometry['startLabel']!;
              final dateRect = geometry['startDate']!;
              final switchRect = geometry['allDaySwitch']!;
              final inline =
                  (labelRect.center.dy - dateRect.center.dy).abs() < .1;
              expect(
                switchRect.center.dy,
                closeTo(labelRect.center.dy, .1),
                reason: 'All-day remains aligned with the start label.',
              );
              if (!inline) {
                expect(
                  labelRect.bottom,
                  lessThanOrEqualTo(dateRect.top + .1),
                  reason: 'A long label can move above its date control.',
                );
              }
              for (final prefix in ['start', 'end']) {
                final date = geometry['${prefix}Date']!;
                final time = geometry['${prefix}Time']!;
                final shareRow = (date.center.dy - time.center.dy).abs() < .1;
                if (!shareRow) {
                  expect(
                    time.top,
                    greaterThanOrEqualTo(date.bottom - .1),
                    reason: 'Stacked time follows its date.',
                  );
                }
              }
              final startTimeRect = geometry['startTime']!;
              final startBottom = dateRect.bottom > startTimeRect.bottom
                  ? dateRect.bottom
                  : startTimeRect.bottom;
              expect(
                geometry['endLabel']!.top,
                greaterThanOrEqualTo(startBottom - .1),
                reason: 'The end interval follows the whole start interval.',
              );
              expect(geometry['endDate']!.left, closeTo(dateRect.left, .1));
              initialTimeGeometry.addAll({
                'layout': inline ? 'inline-labels' : 'labels-above',
                'rects': {
                  for (final entry in geometry.entries)
                    entry.key: {
                      'left': entry.value.left,
                      'top': entry.value.top,
                      'right': entry.value.right,
                      'bottom': entry.value.bottom,
                    },
                },
              });
            }
            await capture('floating');
            if (scale == 1) {
              await p.settingsCommands.updateWorkspacePanelDisplayMode(
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
              await p.settingsCommands.updateWorkspacePanelDisplayMode(
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
            expect(
              domainSnapshot(),
              originalDomainData,
              reason: 'Preview, layout changes and failed saves preserve domain data.',
            );
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            p.dispose();
          }
        }
      }
    }
    expect(captures, hasLength(64));
    await File('${output.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'captures': captures,
        'source': 'integration_test/capture_scenarios/workspace_editor.dart',
        'captureValidation': 'Allow labels above controls; verify interval order, no overlaps and unchanged domain data.',
        'evidence': 'Actual Windows Flutter renderer with in-memory data; synthetic pointer and injected save failure, not native device or storage acceptance.',
      }),
    );
  });
}
