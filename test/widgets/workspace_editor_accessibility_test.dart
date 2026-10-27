import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final (platform, scale, locale, direction) in [
    (TargetPlatform.android, 1.0, 'en', TextDirection.ltr),
    (TargetPlatform.android, 2.0, 'zh', TextDirection.rtl),
    (TargetPlatform.iOS, 1.0, 'en', TextDirection.rtl),
    (TargetPlatform.iOS, 2.0, 'zh', TextDirection.ltr),
  ]) {
    testWidgets(
      'touch weekday choices keep real 48dp targets: $platform/$scale/$locale',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(320, 800);
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        final p = await workspaceProvider(locale: locale);
        try {
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              locale: Locale(locale),
              textScale: scale,
              textDirection: direction,
              home: Scaffold(
                body: CourseEditorSheet(
                  periodTimes: buildDefaultPeriodTimes(),
                  totalWeeks: 18,
                  dayOfWeek: 1,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final l = AppLocalizations.of(
            t.element(find.byType(CourseEditorSheet)),
          );
          final field = find.byWidgetPredicate(
            (widget) =>
                widget is SkedEditorValueField && widget.label == l.dayOfWeek,
          );
          for (var day = 1; day <= 7; day++) {
            await t.ensureVisible(field);
            await t.tap(field);
            await t.pumpAndSettle();
            final label = formatDayOfWeekLabel(day, localeCode: locale);
            final option = find.byWidgetPredicate(
              (widget) => widget is SkedEditorOption && widget.label == label,
            );
            final hit = find.descendant(
              of: option,
              matching: find.byType(InkWell),
            );
            expect(find.byType(SkedEditorOption), findsNWidgets(7));
            if (day == 1) {
              await expectLater(t, meetsGuideline(androidTapTargetGuideline));
              await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
              final rects = find
                  .byType(SkedEditorOption)
                  .evaluate()
                  .map((element) => t.getRect(find.byWidget(element.widget)))
                  .toList();
              for (var index = 1; index < rects.length; index++) {
                expect(
                  rects[index - 1].bottom,
                  lessThanOrEqualTo(rects[index].top),
                );
              }
            }
            await t.ensureVisible(hit);
            await t.pumpAndSettle();
            var rect = t.getRect(hit);
            RenderObject child = t.renderObject(hit);
            while (child.parent != null) {
              final parent = child.parent!;
              final clip = parent.describeApproximatePaintClip(child);
              if (clip != null) {
                rect = rect.intersect(
                  MatrixUtils.transformRect(parent.getTransformTo(null), clip),
                );
              }
              child = parent;
            }
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            if (day.isEven) {
              final node = t.getSemantics(hit);
              node.owner!.performAction(node.id, ui.SemanticsAction.tap);
            } else {
              await t.tapAt(rect.center + const Offset(0, 23));
            }
            await t.pumpAndSettle();
            expect(find.byType(SkedEditorOption), findsNothing);
            expect(t.widget<SkedEditorValueField>(field).value, label);
          }
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          semantics.dispose();
          p.dispose();
        }
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final enabled in [true, false]) {
    testWidgets('desktop value exposes a single named button: $enabled', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: WorkspaceEditorValue(
                label: 'Starts',
                value: '09:00',
                onPressed: enabled ? () => taps++ : null,
              ),
            ),
          ),
        ),
      );
      final node = t.getSemantics(find.byType(WorkspaceEditorValue));
      final data = node.getSemanticsData();
      expect(data.label, 'Starts');
      expect(data.value, '09:00');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), enabled);
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(
        children,
        0,
        reason: 'The inner TextButton must not be announced.',
      );
      if (enabled) {
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        expect(taps, 1);
        await t.tap(find.byType(TextButton));
        expect(taps, 2);
      }
      semantics.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

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
