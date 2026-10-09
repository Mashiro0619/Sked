import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final mode in AppMode.values) {
    for (final locale in ['en', 'zh']) {
      for (final scale in [1.0, 1.5]) {
        testWidgets(
          'editor field layout reflows without replacing draft: $mode/$locale/$scale',
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
            final editable = find.descendant(
              of: title,
              matching: find.byType(EditableText),
            );
            final focus = t.widget<EditableText>(editable).focusNode;
            expect(focus.hasFocus, isTrue);
            input.selection = const TextSelection(
              baseOffset: 0,
              extentOffset: 10,
            );
            final surface = find.byKey(
              const ValueKey('workspace-detail-surface'),
            );
            final initial = t.getRect(surface);
            expect(
              initial.width,
              closeTo(mode == AppMode.general ? 480 : 440, .01),
            );
            final save = find.widgetWithText(FilledButton, l.save);
            expect(
              rtl ? t.getRect(save).left : t.getRect(save).right,
              closeTo(rtl ? initial.left + 12 : initial.right - 12, .01),
            );
            final dates = find.descendant(
              of: editor,
              matching: find.byTooltip(l.pickDate),
            );
            Future<void> resize(double width) async {
              final delta = t.getRect(surface).width - width;
              await t.drag(
                find.byKey(const ValueKey('workspace-detail-resize')),
                Offset(rtl ? -delta : delta, 0),
              );
              await t.pumpAndSettle();
              expect(t.getRect(surface).width, closeTo(width, .01));
            }

            await resize(680);
            final wide = t.getRect(surface);
            if (mode == AppMode.general) {
              final rows = find.byType(WorkspaceEditorTimeRows);
              final startLabel = find.descendant(
                of: rows,
                matching: find.text(l.eventStartTime),
              );
              final toggle = find.descendant(
                of: rows,
                matching: find.byType(Switch),
              );
              expect(
                t.getCenter(toggle).dy,
                closeTo(t.getCenter(startLabel).dy, .1),
              );
              expect(
                t.getRect(dates.last).top,
                greaterThan(t.getRect(dates.first).bottom),
              );
            }
            expect(t.element(editor), same(element));
            expect(t.widget<TextField>(title).controller, same(input));
            expect(input.selection.extentOffset, 10);
            expect(focus.hasFocus, isTrue);
            await resize(480);
            final narrow = t.getRect(surface);
            expect(narrow.width, closeTo(480, .01));
            expect(wide.height, lessThanOrEqualTo(narrow.height));
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
            expect(t.widget<EditableText>(editable).focusNode, same(focus));
            expect(focus.hasFocus, isTrue);
            await resize(320);
            if (mode == AppMode.general) {
              expect(
                t.getTopLeft(dates.last).dy,
                greaterThan(t.getTopLeft(dates.first).dy),
              );
            }
            expect(t.element(editor), same(element));
            expect(t.widget<TextField>(title).controller, same(input));
            expect(
              input.selection,
              const TextSelection(baseOffset: 0, extentOffset: 10),
            );
            expect(t.widget<EditableText>(editable).focusNode, same(focus));
            expect(focus.hasFocus, isTrue);
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
