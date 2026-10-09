import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_panel_header.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final mode in AppMode.values) {
    for (final locale in ['zh', 'en']) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'editor compact header and labeled layout: $mode/$locale/$scale',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(1600, 1100);
            addTearDown(t.view.reset);
            final p = await workspaceProvider(mode: mode, locale: locale);
            addTearDown(p.dispose);
            await t.pumpWidget(
              WorkspaceHarness(
                provider: p,
                locale: Locale(locale),
                textScale: scale,
                textDirection: locale == 'en'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            );
            await t.pumpAndSettle();
            await t.tap(
              find.byKey(
                ValueKey(
                  mode == AppMode.general
                      ? 'general-add-event'
                      : 'student-add-course',
                ),
              ),
            );
            await t.pumpAndSettle();
            final editor = find.byType(
              mode == AppMode.general
                  ? GeneralEventEditorSheet
                  : CourseEditorSheet,
            );
            final element = t.element(editor);
            final l = AppLocalizations.of(element);
            final header = find.descendant(
              of: editor,
              matching: find.byType(SkedPanelHeader),
            );
            final heading = find.descendant(
              of: header,
              matching: find.text(
                mode == AppMode.general ? l.addEvent : l.addCourseTitle,
              ),
            );
            final close = find.byKey(const ValueKey('workspace-editor-close'));
            expect(t.getCenter(heading).dy, closeTo(t.getCenter(close).dy, .1));
            expect(DefaultTextStyle.of(t.element(heading)).style.fontSize, 15);
            expect(
              t
                  .getSize(find.byKey(const ValueKey('workspace-editor-drag')))
                  .height,
              greaterThanOrEqualTo(32),
            );
            expect(
              find.descendant(of: editor, matching: find.byType(Divider)),
              findsOneWidget,
            );
            final input = find
                .descendant(of: editor, matching: find.byType(TextField))
                .first;
            await t.enterText(input, 'Density draft');
            if (mode == AppMode.general) {
              final rows = find.byType(WorkspaceEditorTimeRows);
              final dates = find.descendant(
                of: rows,
                matching: find.byTooltip(l.pickDate),
              );
              final times = find.descendant(
                of: rows,
                matching: find.byTooltip(l.pickTime),
              );
              final toggle = find.descendant(
                of: rows,
                matching: find.byType(Switch),
              );
              final startLabel = find.descendant(
                of: rows,
                matching: find.text(l.eventStartTime),
              );
              final startDate = t.element(dates.first);
              final originalTime = t
                  .widgetList<Text>(
                    find.descendant(of: times, matching: find.byType(Text)),
                  )
                  .map((w) => w.data)
                  .toList();
              expect(
                t.getCenter(toggle).dy,
                closeTo(t.getCenter(startLabel).dy, .1),
              );
              expect(
                t.getRect(dates.first).bottom,
                lessThan(t.getRect(dates.last).top),
              );
              expect(
                t.getRect(startLabel).overlaps(t.getRect(toggle)),
                isFalse,
              );
              if (scale == 1) {
                final recurrence = find.byKey(
                  const ValueKey('event-recurrence-field'),
                );
                final reminder = find.byKey(
                  const ValueKey('event-reminder-field'),
                );
                final surface = find.byKey(
                  const ValueKey('workspace-detail-surface'),
                );
                final initialWidth = t.getSize(surface).width;
                for (final field in [recurrence, reminder]) {
                  expect(
                    t.getRect(field).left,
                    greaterThanOrEqualTo(t.getRect(surface).left),
                  );
                  expect(
                    t.getRect(field).right,
                    lessThanOrEqualTo(t.getRect(surface).right),
                  );
                }
                expect(
                  t.getRect(recurrence).overlaps(t.getRect(reminder)),
                  isFalse,
                );
                // Ahem's English summaries wrap at the compact default width.
                // Both summaries must share a row once their contents fit.
                final resize = find.byKey(
                  const ValueKey('workspace-detail-resize'),
                );
                final delta = initialWidth - 680;
                await t.drag(
                  resize,
                  Offset(locale == 'en' ? -delta : delta, 0),
                );
                await t.pumpAndSettle();
                expect(
                  t.getCenter(recurrence).dy,
                  closeTo(t.getCenter(reminder).dy, .1),
                );
                expect(
                  t.getRect(recurrence).overlaps(t.getRect(reminder)),
                  isFalse,
                );
                await t.drag(
                  resize,
                  Offset(locale == 'en' ? delta : -delta, 0),
                );
                await t.pumpAndSettle();
                expect(t.getSize(surface).width, closeTo(initialWidth, .1));
              }
              await t.ensureVisible(toggle);
              await t.tap(toggle);
              await t.pumpAndSettle();
              expect(times, findsNothing);
              expect(t.element(dates.first), same(startDate));
              expect(
                t.getCenter(toggle).dy,
                closeTo(t.getCenter(startLabel).dy, .1),
              );
              await t.tap(toggle);
              await t.pumpAndSettle();
              expect(times, findsNWidgets(2));
              expect(
                t
                    .widgetList<Text>(
                      find.descendant(of: times, matching: find.byType(Text)),
                    )
                    .map((w) => w.data)
                    .toList(),
                originalTime,
              );
            }
            t.view.physicalSize = const Size(660, 420);
            await t.pumpAndSettle();
            expect(t.element(editor), same(element));
            expect(close.hitTestable(), findsOneWidget);
            expect(
              find.widgetWithText(FilledButton, l.save).hitTestable(),
              findsOneWidget,
            );
            expect(
              t.widget<TextField>(input).controller!.text,
              'Density draft',
            );
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }
}
