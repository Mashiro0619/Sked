import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final mode in AppMode.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'desktop more fields keep external labels and input state: $mode/$scale',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(1600, 1100);
          addTearDown(t.view.reset);
          final p = await workspaceProvider(mode: mode);
          addTearDown(p.dispose);
          await t.pumpWidget(WorkspaceHarness(provider: p, textScale: scale));
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
          final more = find.descendant(
            of: editor,
            matching: find.byType(ExpansionTile),
          );
          await t.ensureVisible(more);
          await t.tap(find.descendant(of: more, matching: find.text('More')));
          await t.pumpAndSettle();
          final label = mode == AppMode.general ? 'Notes' : 'Teacher';
          final input = find.descendant(
            of: find.descendant(
              of: more,
              matching: find.byWidgetPredicate(
                (w) => w is WorkspaceEditorField && w.label == label,
              ),
            ),
            matching: find.byType(TextField),
          );
          expect(
            find.ancestor(
              of: input,
              matching: find.byType(WorkspaceEditorField),
            ),
            findsOneWidget,
          );
          expect(t.widget<TextField>(input).decoration!.prefixIcon, isNull);
          expect(
            t.widget<TextField>(input).decoration!.floatingLabelBehavior,
            FloatingLabelBehavior.never,
          );
          await t.ensureVisible(input);
          await t.enterText(input, 'Existing value');
          await t.pumpAndSettle();
          expect(t.widget<TextField>(input).controller!.text, 'Existing value');
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  for (final locale in ['en', 'zh']) {
    testWidgets(
      'desktop date and time fields retain localized action hints: $locale',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1440, 1000);
        addTearDown(t.view.reset);
        final p = await workspaceProvider(
          mode: AppMode.general,
          locale: locale,
        );
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(provider: p, locale: Locale(locale)),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('general-add-event')));
        await t.pumpAndSettle();
        final editor = find.byType(GeneralEventEditorSheet);
        final l = AppLocalizations.of(t.element(editor));
        expect(
          find.descendant(of: editor, matching: find.byTooltip(l.pickDate)),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: editor, matching: find.byTooltip(l.pickTime)),
          findsNWidgets(2),
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
