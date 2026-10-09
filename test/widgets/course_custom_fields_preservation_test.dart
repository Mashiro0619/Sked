import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../support/workspace_harness.dart';

const _fields = <String, dynamic>{
  'Description': 'First line\nSecond line',
  'Attempts': 3,
  'Room': {'building': 'A', 'floor': 2},
  'Tags': ['lab', 'seminar'],
  'Required': true,
  'Unset': null,
  'Code': 'CS:201',
  ' Key:\nwith whitespace ': ' Value with whitespace ',
};

Finder _customFields() => find.byKey(const ValueKey('course-custom-fields'));

Future<({TimetableProvider provider, WorkspaceMemoryStorage storage})>
_openEditor(
  WidgetTester tester, {
  required bool phone,
  Map<String, dynamic> fields = _fields,
  Size? viewport,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize =
      viewport ?? (phone ? const Size(430, 950) : const Size(1440, 1000));
  addTearDown(tester.view.reset);
  final course = CourseItem(
    id: 'metadata',
    name: 'Original course',
    teacher: '',
    location: 'Room A',
    dayOfWeek: 1,
    semesterWeeks: const [1, 2],
    periods: const [1],
    startMinutes: 480,
    endMinutes: 525,
    timeRange: '08:00-08:45',
    credit: 0,
    remarks: '',
    customFields: fields,
  );
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  final storage = WorkspaceMemoryStorage(
    initial.copyWith(
      studentMode: initial.studentMode.copyWith(
        activeTimetableId: 'table',
        timetables: [
          TimetableData(
            id: 'table',
            config: TimetableConfig(
              name: 'Semester',
              startDate: DateTime(2026, 10, 5),
              totalWeeks: 18,
              periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
            ),
            courses: [course],
          ),
        ],
      ),
    ),
  );
  final provider = await workspaceProvider(storage: storage);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await provider.setSelectedWeek(1);
  await tester.pumpWidget(
    WorkspaceHarness(provider: provider, locale: locale, textScale: textScale),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('timetable-course-hit-metadata')));
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(
    tester.element(find.byType(CourseDetailsSheet)),
  );
  await tester.tap(
    find.descendant(
      of: find.byType(CourseDetailsSheet),
      matching: find.byTooltip(l10n.editCourseTooltip),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(CourseEditorSheet), findsOneWidget);
  return (provider: provider, storage: storage);
}

void _expectStoredFields(
  ({TimetableProvider provider, WorkspaceMemoryStorage storage}) state,
  Map<String, dynamic> fields,
) {
  expect(state.provider.activeTimetable.courses.single.customFields, fields);
  expect(
    state
        .storage
        .data
        .studentMode
        .timetables
        .single
        .courses
        .single
        .customFields,
    fields,
  );
  expect(
    state
        .provider
        .committedAppData
        .studentMode
        .timetables
        .single
        .courses
        .single
        .customFields,
    fields,
  );
}

Future<void> _save(WidgetTester tester) async {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(CourseEditorSheet)),
  );
  final save = find.widgetWithText(FilledButton, l10n.save);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _editCustomFields(WidgetTester tester, String text) async {
  await tester.ensureVisible(_customFields());
  await tester.pumpAndSettle();
  await tester.enterText(_customFields(), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'JSON validation wraps completely on a narrow large-text screen',
    (tester) async {
      final state = await _openEditor(
        tester,
        phone: true,
        viewport: const Size(320, 568),
        textScale: 2,
        locale: const Locale('de'),
      );
      await _editCustomFields(tester, '{');
      await _save(tester);
      final l10n = AppLocalizations.of(tester.element(_customFields()));
      final error = find.text(l10n.customFieldsInvalidJson);
      expect(error, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(error);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - .1,
        ),
      );
      await tester.ensureVisible(error);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, l10n.save).hitTestable(),
        findsOneWidget,
      );
      _expectStoredFields(state, _fields);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final phone in [false, true]) {
    final platform = TargetPlatformVariant.only(
      phone ? TargetPlatform.android : TargetPlatform.windows,
    );
    final label = phone ? 'phone' : 'desktop';

    testWidgets('renaming a course preserves untouched JSON fields on $label', (
      tester,
    ) async {
      final state = await _openEditor(tester, phone: phone);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(CourseEditorSheet),
              matching: find.byType(EditableText),
            )
            .first,
        'Renamed course',
      );
      await _save(tester);
      expect(find.byType(CourseEditorSheet), findsNothing);
      expect(
        state.provider.activeTimetable.courses.single.name,
        'Renamed course',
      );
      _expectStoredFields(state, _fields);
      expect(tester.takeException(), isNull);
    }, variant: platform);

    testWidgets(
      'editing one JSON field preserves all other saved fields on $label',
      (tester) async {
        final state = await _openEditor(tester, phone: phone);
        final textField = tester.widget<TextField>(_customFields());
        final l10n = AppLocalizations.of(tester.element(_customFields()));
        expect(textField.decoration!.helperText, l10n.jsonContent);
        final original = textField.controller!.text;
        await _editCustomFields(
          tester,
          original.replaceFirst('"Code": "CS:201"', '"Code": "CS:202"'),
        );
        await _save(tester);
        expect(find.byType(CourseEditorSheet), findsNothing);
        _expectStoredFields(state, {..._fields, 'Code': 'CS:202'});
        expect(tester.takeException(), isNull);
      },
      variant: platform,
    );

    testWidgets(
      'structured field changes, removals and additions persist on $label',
      (tester) async {
        final state = await _openEditor(tester, phone: phone);
        final edited = {..._fields}
          ..remove('Unset')
          ..remove('Attempts')
          ..['Renamed attempts'] = 4
          ..['Room'] = {'building': 'B', 'floor': 3}
          ..['Added'] = [false, null, 5];
        await _editCustomFields(tester, jsonEncode(edited));
        await _save(tester);
        expect(find.byType(CourseEditorSheet), findsNothing);
        _expectStoredFields(state, edited);
        expect(tester.takeException(), isNull);
      },
      variant: platform,
    );

    testWidgets(
      'invalid JSON retains its draft and can be corrected on $label',
      (tester) async {
        final state = await _openEditor(tester, phone: phone);
        final l10n = AppLocalizations.of(tester.element(_customFields()));
        for (final invalid in [
          '{',
          '[]',
          'null',
          'true',
          '3',
          '"text"',
          'Attempts:4',
          '{"Attempts":1e400}',
        ]) {
          await _editCustomFields(tester, invalid);
          await _save(tester);
          expect(find.byType(CourseEditorSheet), findsOneWidget);
          final field = tester.widget<TextField>(_customFields());
          expect(field.controller!.text, invalid);
          expect(find.text(l10n.customFieldsInvalidJson), findsOneWidget);
          expect(field.focusNode!.hasFocus, isTrue);
          _expectStoredFields(state, _fields);
          expect(tester.takeException(), isNull);
        }
        await _editCustomFields(
          tester,
          jsonEncode({..._fields, 'Attempts': 4}),
        );
        expect(
          tester.widget<TextField>(_customFields()).decoration!.error,
          isNull,
        );
        await _save(tester);
        _expectStoredFields(state, {..._fields, 'Attempts': 4});
        expect(find.byType(CourseEditorSheet), findsNothing);
      },
      variant: platform,
    );

    testWidgets(
      'clearing structured fields is an intentional removal on $label',
      (tester) async {
        final state = await _openEditor(tester, phone: phone);
        await _editCustomFields(tester, '');
        await _save(tester);
        _expectStoredFields(state, {});
        expect(find.byType(CourseEditorSheet), findsNothing);
      },
      variant: platform,
    );

    testWidgets(
      'cancel discards changed JSON without touching saved data on $label',
      (tester) async {
        final state = await _openEditor(tester, phone: phone);
        final l10n = AppLocalizations.of(tester.element(_customFields()));
        await _editCustomFields(tester, '{');
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.discardChangesAndExit));
        await tester.pumpAndSettle();
        expect(find.byType(CourseEditorSheet), findsNothing);
        _expectStoredFields(state, _fields);
      },
      variant: platform,
    );

    testWidgets(
      'ordinary custom fields keep their text editing behavior on $label',
      (tester) async {
        final state = await _openEditor(
          tester,
          phone: phone,
          fields: const {'Code': 'CS:201', 'Number': '003', 'Required': 'true'},
        );
        final field = tester.widget<TextField>(_customFields());
        expect(field.decoration!.helperText, isNull);
        expect(
          field.controller!.text,
          'Code:CS:201\nNumber:003\nRequired:true',
        );
        await _editCustomFields(
          tester,
          'Code:CS:202\nNumber:003\nRequired:true\nNull:null',
        );
        await _save(tester);
        _expectStoredFields(state, {
          'Code': 'CS:202',
          'Number': '003',
          'Required': 'true',
          'Null': 'null',
        });
        expect(find.byType(CourseEditorSheet), findsNothing);
      },
      variant: platform,
    );
  }
}
