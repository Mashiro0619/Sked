import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final phone in [false, true]) {
    testWidgets(
      'renaming a course preserves untouched JSON fields on ${phone ? 'phone' : 'desktop'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone
            ? const Size(430, 950)
            : const Size(1440, 1000);
        addTearDown(tester.view.reset);
        const fields = <String, dynamic>{
          'Description': 'First line\nSecond line',
          'Attempts': 3,
          'Room': {'building': 'A', 'floor': 2},
          'Tags': ['lab', 'seminar'],
          'Required': true,
          'Unset': null,
          'Code': 'CS:201',
        };
        const course = CourseItem(
          id: 'metadata',
          name: 'Original course',
          teacher: '',
          location: 'Room A',
          dayOfWeek: 1,
          semesterWeeks: [1, 2],
          periods: [1],
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
                    periodTimeSetId:
                        initial.studentMode.periodTimeSets.first.id,
                  ),
                  courses: const [course],
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
        await tester.pumpWidget(WorkspaceHarness(provider: provider));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('timetable-course-hit-metadata')),
        );
        await tester.pumpAndSettle();
        final detail = find.byType(CourseDetailsSheet);
        await tester.tap(
          find.descendant(of: detail, matching: find.byTooltip('Edit course')),
        );
        await tester.pumpAndSettle();
        final editor = find.byType(CourseEditorSheet);
        await tester.enterText(
          find
              .descendant(of: editor, matching: find.byType(EditableText))
              .first,
          'Renamed course',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
        expect(editor, findsNothing);
        expect(provider.activeTimetable.courses.single.name, 'Renamed course');
        expect(provider.activeTimetable.courses.single.customFields, fields);
        expect(
          storage
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
          provider
              .committedAppData
              .studentMode
              .timetables
              .single
              .courses
              .single
              .customFields,
          fields,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        phone ? TargetPlatform.android : TargetPlatform.windows,
      ),
    );
  }
}
