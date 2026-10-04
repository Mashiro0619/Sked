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
            expect(rect.height, greaterThanOrEqualTo(36));
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
          Finder field(String label) => find.descendant(
            of: editor,
            matching: find.byWidgetPredicate(
              (w) => w is WorkspaceEditorField && w.label == label,
            ),
          );
          final dateField = mode == AppMode.general
              ? find.byType(WorkspaceEditorTimeRows)
              : field(l.time);
          expect(dateField, findsOneWidget);
          final label = find.descendant(
            of: dateField,
            matching: find.text(
              mode == AppMode.general ? l.eventStartTime : l.time,
            ),
          );
          final control = mode == AppMode.general
              ? find
                    .descendant(
                      of: dateField,
                      matching: find.byTooltip(l.pickDate),
                    )
                    .first
              : find
                    .descendant(
                      of: dateField,
                      matching: find.byKey(
                        const ValueKey('editor-field-control'),
                      ),
                    )
                    .first;
          expect(t.getCenter(label).dy, closeTo(t.getCenter(control).dy, 1));
          expect(t.getRect(control).left, greaterThan(t.getRect(label).right));
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
