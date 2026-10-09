import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_editor_time_rows.dart';

import '../support/workspace_harness.dart';

const _calendars = [
  GeneralSchedule(id: 'work', name: 'Work', events: []),
  GeneralSchedule(id: 'home', name: 'Home', events: []),
];

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is WorkspaceEditorField && widget.label == label,
);

Widget _editorHost({
  double width = 600,
  bool floating = true,
  List<GeneralSchedule> calendars = _calendars,
  GeneralEvent? initialEvent,
}) => Scaffold(
  body: Align(
    alignment: Alignment.topRight,
    child: SizedBox(
      width: width,
      child: WorkspaceEditorScope(
        enabled: true,
        floating: floating,
        onHeight: (_) {},
        child: GeneralEventEditorSheet(
          initialEvent: initialEvent,
          initialDate: DateTime(2026, 10, 9, 9),
          calendars: calendars,
          activeCalendarId: 'work',
        ),
      ),
    ),
  ),
);

void main() {
  for (final locale in ['zh', 'en']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'desktop event exposes labeled metadata and grouped dates: $locale/$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1200, 1000);
          addTearDown(tester.view.reset);
          final provider = await workspaceProvider(
            mode: AppMode.general,
            locale: locale,
          );
          addTearDown(provider.dispose);
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              locale: Locale(locale),
              textScale: scale,
              brightness: locale == 'en' ? Brightness.dark : Brightness.light,
              textDirection: locale == 'en'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              home: _editorHost(),
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(GeneralEventEditorSheet)),
          );
          final location = _field(l10n.place);
          final category = _field(l10n.calendar);
          final locationInput = find.descendant(
            of: location,
            matching: find.byType(TextField),
          );
          final categoryInput = find.descendant(
            of: category,
            matching: find.byType(SkedDropdownMenu<String>),
          );
          final locationLabel = find.descendant(
            of: location,
            matching: find.text(l10n.place),
          );
          final categoryLabel = find.descendant(
            of: category,
            matching: find.text(l10n.calendar),
          );
          expect(location, findsOneWidget);
          expect(category, findsOneWidget);
          expect(
            tester.getBottomLeft(locationLabel).dy,
            lessThan(tester.getTopLeft(locationInput).dy),
          );
          expect(
            tester.getBottomLeft(categoryLabel).dy,
            lessThan(tester.getTopLeft(categoryInput).dy),
          );
          expect(tester.widget<Text>(locationLabel).style!.fontSize, 12);
          expect(tester.widget<TextField>(locationInput).style!.fontSize, 14);
          expect(
            tester
                .widget<TextField>(
                  find.descendant(
                    of: find.byKey(const ValueKey('event-desktop-title')),
                    matching: find.byType(TextField),
                  ),
                )
                .style!
                .fontSize,
            22,
          );
          if (scale == 1) {
            expect(
              tester.getTopLeft(location).dy,
              tester.getTopLeft(category).dy,
            );
          } else {
            expect(
              tester.getTopLeft(category).dy,
              greaterThan(tester.getBottomLeft(location).dy),
            );
          }

          final rows = find.byType(WorkspaceEditorTimeRows);
          final dates = find.descendant(
            of: rows,
            matching: find.byTooltip(l10n.pickDate),
          );
          final allDay = find.descendant(
            of: rows,
            matching: find.byType(Switch),
          );
          final startLabel = find.descendant(
            of: rows,
            matching: find.text(l10n.eventStartTime),
          );
          expect(
            tester.getBottomLeft(allDay).dy,
            lessThan(tester.getTopLeft(startLabel).dy),
          );
          expect(
            tester.getBottomLeft(startLabel).dy,
            lessThan(tester.getTopLeft(dates.first).dy),
          );
          expect(tester.widget<Text>(startLabel).style!.fontSize, 12);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets(
    'long category names use a full column without replacing the focused draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1000);
      addTearDown(tester.view.reset);
      final provider = await workspaceProvider(mode: AppMode.general);
      addTearDown(provider.dispose);
      Future<void> pump(List<GeneralSchedule> calendars) async {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: _editorHost(calendars: calendars),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(_calendars);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );
      final location = _field(l10n.place);
      final category = _field(l10n.calendar);
      expect(tester.getTopLeft(location).dy, tester.getTopLeft(category).dy);
      final locationInput = find.byKey(
        const ValueKey('event-desktop-location'),
      );
      await tester.enterText(locationInput, 'Draft location');
      final editable = find.descendant(
        of: locationInput,
        matching: find.byType(EditableText),
      );
      final inputElement = tester.element(editable);
      final input = tester.widget<EditableText>(editable);
      const selection = TextSelection(baseOffset: 6, extentOffset: 14);
      input.controller.selection = selection;
      final picker = find.byType(SkedDropdownMenu<String>);
      final pickerElement = tester.element(picker);
      const longName = 'Product research and planning';

      await pump(const [
        GeneralSchedule(id: 'work', name: longName, events: []),
        GeneralSchedule(id: 'home', name: 'Home', events: []),
      ]);
      expect(
        tester.getTopLeft(category).dy,
        greaterThan(tester.getBottomLeft(location).dy),
      );
      final selectedName = find.descendant(
        of: category,
        matching: find.text(longName),
      );
      final nameParagraph = tester.renderObject<RenderParagraph>(selectedName);
      expect(nameParagraph.size.width, greaterThan(240));
      expect(nameParagraph.didExceedMaxLines, isFalse);
      expect(tester.element(editable), same(inputElement));
      expect(tester.element(picker), same(pickerElement));
      expect(input.controller.text, 'Draft location');
      expect(input.controller.selection, selection);
      expect(input.focusNode.hasFocus, isTrue);

      await pump(_calendars);
      expect(tester.getTopLeft(location).dy, tester.getTopLeft(category).dy);
      expect(tester.element(editable), same(inputElement));
      expect(tester.element(picker), same(pickerElement));
      expect(input.controller.selection, selection);
      expect(input.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'long recurrence summaries put reminder below the full-width recurrence',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1200);
      addTearDown(tester.view.reset);
      final provider = await workspaceProvider(mode: AppMode.general);
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: _editorHost(
            initialEvent: GeneralEvent(
              id: 'long-recurrence',
              calendarId: 'work',
              title: 'Planning',
              startDateTimeIso: '2026-10-09T09:00:00.000',
              endDateTimeIso: '2026-10-09T10:00:00.000',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.custom,
                interval: 999,
                unit: GeneralEventRecurrenceUnit.month,
                untilDateIso: '2030-10-09',
                count: 999,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final recurrence = find.byKey(const ValueKey('event-recurrence-field'));
      final reminder = find.byKey(const ValueKey('event-reminder-field'));
      expect(tester.getSize(recurrence).width, greaterThan(500));
      expect(tester.getSize(recurrence).width, tester.getSize(reminder).width);
      expect(
        tester.getTopLeft(reminder).dy,
        greaterThan(tester.getBottomLeft(recurrence).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop event retains metadata focus, selection, and expanded notes across wrapping and docking',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1000);
      addTearDown(tester.view.reset);
      final provider = await workspaceProvider(mode: AppMode.general);
      addTearDown(provider.dispose);
      Future<void> pump({double width = 600, bool floating = true}) async {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: _editorHost(width: width, floating: floating),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump();
      final title = find.byKey(const ValueKey('event-desktop-title'));
      await tester.enterText(title, 'Planning draft');
      final more = find.widgetWithText(ExpansionTile, 'More');
      await tester.ensureVisible(more);
      await tester.tap(find.descendant(of: more, matching: find.text('More')));
      await tester.pumpAndSettle();
      final notes = find.descendant(
        of: _field('Notes'),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Notes remain expanded');
      final notesElement = tester.element(notes);
      final location = find.byKey(const ValueKey('event-desktop-location'));
      await tester.ensureVisible(location);
      await tester.enterText(location, 'West meeting room');
      await tester.showKeyboard(location);
      final editable = find.descendant(
        of: location,
        matching: find.byType(EditableText),
      );
      final input = tester.widget<EditableText>(editable);
      const selection = TextSelection(baseOffset: 5, extentOffset: 12);
      input.controller.selection = selection;
      final locationElement = tester.element(editable);
      await tester.pump();
      expect(input.focusNode.hasFocus, isTrue);

      for (final floating in [false, true]) {
        await pump(width: floating ? 600 : 320, floating: floating);
        expect(tester.element(editable), same(locationElement));
        expect(input.focusNode.hasFocus, isTrue);
        expect(input.controller.text, 'West meeting room');
        expect(input.controller.selection, selection);
        expect(tester.element(notes), same(notesElement));
        expect(
          tester.widget<TextField>(notes).controller!.text,
          'Notes remain expanded',
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: title, matching: find.byType(TextField)),
              )
              .controller!
              .text,
          'Planning draft',
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
