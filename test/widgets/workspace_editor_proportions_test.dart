import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final mode in AppMode.values) {
    for (final locale in ['en', 'zh']) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'wider editor reduces wrapping without replacing draft: $mode/$locale/$scale',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(1600, 1100);
            addTearDown(t.view.reset);
            final rtl = locale == 'en';
            final p = await workspaceProvider(mode: mode, locale: locale);
            addTearDown(p.dispose);
            await t.pumpWidget(
              WorkspaceHarness(
                provider: p,
                locale: Locale(locale),
                textScale: scale,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
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
            final title = find
                .descendant(of: editor, matching: find.byType(TextField))
                .first;
            await t.enterText(title, 'Proportion draft');
            await t.pumpAndSettle();
            final input = t.widget<TextField>(title).controller!;
            input.selection = const TextSelection(
              baseOffset: 0,
              extentOffset: 10,
            );
            final surface = find.byKey(
              const ValueKey('workspace-detail-surface'),
            );
            final wide = t.getRect(surface);
            expect(wide.width, closeTo(600, .01));
            final save = find.widgetWithText(FilledButton, l.save);
            expect(
              rtl ? t.getRect(save).left : t.getRect(save).right,
              closeTo(rtl ? wide.left + 12 : wide.right - 12, .01),
            );
            final dates = find.descendant(
              of: editor,
              matching: find.byTooltip(l.pickDate),
            );
            if (mode == AppMode.general && scale == 1) {
              expect(t.getTopLeft(dates.first).dy, t.getTopLeft(dates.last).dy);
            }
            await t.drag(
              find.byKey(const ValueKey('workspace-detail-resize')),
              Offset(rtl ? -120 : 120, 0),
            );
            await t.pumpAndSettle();
            final narrow = t.getRect(surface);
            expect(narrow.width, closeTo(480, .01));
            expect(wide.height, lessThanOrEqualTo(narrow.height));
            if (mode == AppMode.general && scale == 1 ||
                mode == AppMode.student && scale == 1.5) {
              expect(wide.height, lessThan(narrow.height - 20));
            }
            if (mode == AppMode.general && scale == 1) {
              expect(
                t.getTopLeft(dates.last).dy,
                greaterThan(t.getTopLeft(dates.first).dy),
              );
            }
            expect(t.element(editor), same(element));
            expect(t.widget<TextField>(title).controller, same(input));
            expect(input.text, 'Proportion draft');
            expect(input.selection.extentOffset, 10);
            t.view.physicalSize = const Size(660, 420);
            await t.pumpAndSettle();
            expect(t.element(editor), same(element));
            final small = t.getRect(surface);
            expect(small.left, greaterThanOrEqualTo(8));
            expect(small.right, lessThanOrEqualTo(652));
            expect(
              find
                  .byKey(const ValueKey('workspace-editor-close'))
                  .hitTestable(),
              findsOneWidget,
            );
            expect(
              find.widgetWithText(FilledButton, l.save).hitTestable(),
              findsOneWidget,
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
