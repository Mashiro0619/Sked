import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final mode in AppMode.values) {
    for (final locale in ['zh', 'en']) {
      testWidgets(
        'desktop $mode uses a headline and labeled controls: $locale',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1600, 1100);
          addTearDown(t.view.reset);
          final p = await workspaceProvider(mode: mode, locale: locale);
          addTearDown(p.dispose);
          await t.pumpWidget(
            WorkspaceHarness(provider: p, locale: Locale(locale)),
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
          final l = AppLocalizations.of(t.element(editor));
          final title = find
              .descendant(of: editor, matching: find.byType(TextField))
              .first;
          final input = t.widget<TextField>(title);
          expect(input.decoration!.prefixIcon, isNull);
          expect(input.decoration!.labelText, isNull);
          expect(input.decoration!.enabledBorder!.borderSide, BorderSide.none);
          expect(input.style!.fontSize, 22);
          final sections = t
              .widgetList<WorkspaceEditorFormSection>(
                find.descendant(
                  of: editor,
                  matching: find.byType(WorkspaceEditorFormSection),
                ),
              )
              .toList();
          expect(sections.where((section) => section.divider), isEmpty);
          expect(
            find.descendant(of: editor, matching: find.byType(Divider)),
            findsOneWidget,
          );
          expect(
            input.decoration!.floatingLabelBehavior,
            FloatingLabelBehavior.never,
          );
          expect(
            input.style!.fontSize,
            greaterThan(
              Theme.of(t.element(editor)).textTheme.bodyMedium!.fontSize!,
            ),
          );
          final values = find.descendant(
            of: editor,
            matching: find.byType(WorkspaceEditorValue),
          );
          expect(values, findsWidgets);
          for (final element in values.evaluate()) {
            final rect = t.getRect(
              find.byElementPredicate((value) => identical(value, element)),
            );
            expect(rect.height, greaterThanOrEqualTo(40));
            expect(
              find.descendant(
                of: find.byElementPredicate(
                  (value) => identical(value, element),
                ),
                matching: find.byType(OutlinedButton),
              ),
              findsNothing,
            );
          }
          final fields = find.descendant(
            of: editor,
            matching: find.byType(WorkspaceEditorField),
          );
          expect(fields, findsWidgets);
          for (final element in fields.evaluate()) {
            final field = find.byElementPredicate(
              (value) => identical(value, element),
            );
            final fieldWidget = element.widget as WorkspaceEditorField;
            final label = find
                .descendant(of: field, matching: find.text(fieldWidget.label))
                .first;
            final control = find
                .descendant(
                  of: field,
                  matching: find.byKey(const ValueKey('editor-field-control')),
                )
                .first;
            expect(t.getRect(label).bottom, lessThan(t.getRect(control).top));
            expect(t.getRect(label).left, closeTo(t.getRect(control).left, .1));
            expect(t.widget<Text>(label).style?.fontSize, 12);
          }
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
            final startLabel = find.descendant(
              of: editor,
              matching: find.text(l.eventStartTime),
            );
            expect(
              t.getRect(startLabel).bottom,
              lessThan(t.getRect(dates.first).top),
            );
            final dateWidth = t
                .renderObject<RenderBox>(dates.first)
                .getMaxIntrinsicWidth(double.infinity);
            final timeWidth = math.max(
              t
                  .renderObject<RenderBox>(times.first)
                  .getMaxIntrinsicWidth(double.infinity),
              t
                  .renderObject<RenderBox>(times.last)
                  .getMaxIntrinsicWidth(double.infinity),
            );
            final groupsFit =
                math.max(240, dateWidth + 12 + timeWidth) * 2 + 12 <=
                t.getSize(rows).width;
            expect(
              t.getRect(dates.first).top,
              groupsFit
                  ? closeTo(t.getRect(dates.last).top, .1)
                  : lessThan(t.getRect(dates.last).top),
            );
          }
          await t.enterText(title, 'Rebuilt editor draft');
          final countBefore = mode == AppMode.general
              ? p.generalSchedules.expand((calendar) => calendar.events).length
              : p.activeTimetable.courses.length;
          await t.tap(find.widgetWithText(FilledButton, l.save));
          await t.pumpAndSettle();
          expect(editor, findsNothing);
          final countAfter = mode == AppMode.general
              ? p.generalSchedules.expand((calendar) => calendar.events).length
              : p.activeTimetable.courses.length;
          expect(countAfter, countBefore + 1);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
