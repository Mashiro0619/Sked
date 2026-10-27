import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';
import 'package:sked/widgets/workspace_frame.dart';

CourseItem _course({
  String id = 'course',
  String title = 'Course',
  String location = 'Room 201',
  String teacher = 'Teacher',
  int start = 480,
  int duration = 90,
}) => CourseItem(
  id: id,
  name: title,
  location: location,
  teacher: teacher,
  dayOfWeek: 1,
  semesterWeeks: const [1],
  periods: const [1],
  startMinutes: start,
  endMinutes: start + duration,
  timeRange: buildTimeRange(start, start + duration),
  credit: 0,
  remarks: '',
  customFields: const {},
);

Widget _grid({
  required List<CourseItem> courses,
  String? selectedId,
  TextDirection direction = TextDirection.ltr,
  ValueChanged<TimetableCourseTapInfo>? onTap,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.windows),
  builder: (context, child) =>
      Directionality(textDirection: direction, child: child!),
  home: Scaffold(
    body: WorkspaceSelectionScope(
      selectedId: selectedId == null ? null : 'course:$selectedId',
      child: TimetableGrid(
        timetable: TimetableData(
          id: 'semantics-cache',
          config: TimetableConfig(
            name: 'Timetable',
            startDate: DateTime(2026, 1, 5),
            totalWeeks: 18,
            periodTimeSetId: defaultPeriodTimeSetId,
          ),
          courses: courses,
        ),
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
        ],
        weekDateStart: DateTime(2026, 1, 5),
        selectedWeek: 1,
        realCurrentWeek: 1,
        localeCode: 'en',
        preserveGaps: true,
        showPastEndedCourses: true,
        showFutureCourses: true,
        showGridLines: true,
        showDayHeader: false,
        fitVisibleDaysToWidth: true,
        visibleWeekdays: const [1],
        onCourseTap: onTap ?? (_) {},
        onEmptySlotTap: (_) {},
        themeColorMode: themeColorModeSingle,
        courseNameColorValues: const {},
        colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
        liveCourseOutlineEnabled: false,
        liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
        liveCourseOutlineColorValue: 0xff6750a4,
        liveCourseOutlineWidth: 2,
      ),
    ),
  ),
);

String _label(CourseItem course) => [
  course.name,
  'Monday',
  'Week 1',
  '${formatMinutes(course.startMinutes)}–${formatMinutes(course.endMinutes)}',
  'Location: ${course.location}',
  'Teacher: ${course.teacher}',
].join(', ');

Finder _annotation(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
Finder _hit(String id) => find.byKey(ValueKey('timetable-course-hit-$id'));
Finder _visual(String id) =>
    find.byKey(ValueKey('timetable-course-visual-$id'));

void _semanticTap(WidgetTester tester, String label) {
  final node = tester.getSemantics(_annotation(label));
  node.owner!.performAction(node.id, ui.SemanticsAction.tap);
}

void main() {
  testWidgets(
    'the same semantic label keeps properties and calls the current target',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(960, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final original = _course(id: 'original');
        final replacement = _course(id: 'replacement');
        final label = _label(original);
        var originalCalls = 0;
        TimetableCourseTapInfo? latest;
        await tester.pumpWidget(
          _grid(courses: [original], onTap: (_) => originalCalls++),
        );
        await tester.pumpAndSettle();
        final element = tester.element(_annotation(label));
        final properties = tester
            .widget<Semantics>(_annotation(label))
            .properties;
        final nodeId = tester.getSemantics(_annotation(label)).id;
        final hitRect = tester.getRect(_hit(original.id));
        final visualRect = tester.getRect(_visual(original.id));

        // Course identity and the callback change, while every announced field stays
        // identical. Reusing an old callback would activate the original course.
        await tester.pumpWidget(
          _grid(courses: [replacement], onTap: (info) => latest = info),
        );
        await tester.pumpAndSettle();
        expect(_label(replacement), label);
        expect(tester.element(_annotation(label)), same(element));
        expect(
          tester.widget<Semantics>(_annotation(label)).properties,
          same(properties),
        );
        final node = tester.getSemantics(_annotation(label));
        expect(node.id, nodeId);
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.longPress),
          isFalse,
        );
        expect(tester.getRect(_hit(replacement.id)), hitRect);
        expect(tester.getRect(_visual(replacement.id)), visualRect);
        _semanticTap(tester, label);
        expect(originalCalls, 0);
        expect(latest?.course.id, replacement.id);
        expect(latest?.course.name, replacement.name);
        expect(latest?.course.location, replacement.location);
        expect(latest?.course.teacher, replacement.teacher);
        expect(latest?.anchorRect, hitRect);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'label, selection and inherited direction remain visible to semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(960, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final original = _course();
        final label = _label(original);
        await tester.pumpWidget(_grid(courses: [original]));
        await tester.pumpAndSettle();
        final nodeId = tester.getSemantics(_annotation(label)).id;
        final originalProperties = tester
            .widget<Semantics>(_annotation(label))
            .properties;
        expect(
          tester
              .getSemantics(_annotation(label))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isFalse,
        );

        await tester.pumpWidget(
          _grid(courses: [original], selectedId: original.id),
        );
        await tester.pumpAndSettle();
        final selectedProperties = tester
            .widget<Semantics>(_annotation(label))
            .properties;
        expect(selectedProperties, isNot(same(originalProperties)));
        expect(tester.getSemantics(_annotation(label)).id, nodeId);
        expect(
          tester
              .getSemantics(_annotation(label))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isTrue,
        );

        final edited = _course(
          title: 'Revised course',
          location: 'Room 302',
          teacher: 'New teacher',
        );
        final editedLabel = _label(edited);
        TimetableCourseTapInfo? latest;
        await tester.pumpWidget(
          _grid(
            courses: [edited],
            selectedId: edited.id,
            onTap: (info) => latest = info,
          ),
        );
        await tester.pumpAndSettle();
        expect(_annotation(label), findsNothing);
        final editedProperties = tester
            .widget<Semantics>(_annotation(editedLabel))
            .properties;
        expect(editedProperties, isNot(same(selectedProperties)));
        final editedNode = tester.getSemantics(_annotation(editedLabel));
        expect(editedNode.id, nodeId);
        expect(editedNode.getSemanticsData().label, editedLabel);
        expect(
          editedNode.getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        _semanticTap(tester, editedLabel);
        expect(latest?.course.id, edited.id);
        expect(latest?.course.name, edited.name);
        expect(latest?.course.location, edited.location);
        expect(latest?.course.teacher, edited.teacher);

        await tester.pumpWidget(_grid(courses: [edited]));
        await tester.pumpAndSettle();
        final unselectedProperties = tester
            .widget<Semantics>(_annotation(editedLabel))
            .properties;
        expect(unselectedProperties, isNot(same(editedProperties)));
        expect(
          tester
              .getSemantics(_annotation(editedLabel))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isFalse,
        );

        await tester.pumpWidget(
          _grid(courses: [edited], direction: TextDirection.rtl),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Semantics>(_annotation(editedLabel)).properties,
          same(unselectedProperties),
        );
        expect(
          tester
              .getSemantics(_annotation(editedLabel))
              .getSemanticsData()
              .textDirection,
          TextDirection.rtl,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'dense semantic actions retain 48 dp without widening pointer targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(960, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final original = _course(
          id: 'first-original',
          title: 'First',
          duration: 10,
        );
        final replacement = _course(
          id: 'first-replacement',
          title: 'First',
          duration: 10,
        );
        final second = _course(
          id: 'second',
          title: 'Second',
          start: 490,
          duration: 10,
        );
        final third = _course(
          id: 'third',
          title: 'Third',
          start: 500,
          duration: 10,
        );
        final label = _label(original);
        var originalCalls = 0;
        TimetableCourseTapInfo? latest;
        await tester.pumpWidget(
          _grid(
            courses: [original, second, third],
            onTap: (_) => originalCalls++,
          ),
        );
        await tester.pumpAndSettle();
        final properties = tester
            .widget<Semantics>(_annotation(label))
            .properties;
        final nodeId = tester.getSemantics(_annotation(label)).id;
        final semanticRect = tester.getRect(_annotation(label));
        final hitRect = tester.getRect(_hit(original.id));
        final secondRect = tester.getRect(_hit(second.id));
        expect(properties.selected, isNull);
        expect(semanticRect.height, 48);
        expect(tester.getSemantics(_annotation(label)).rect.height, 48);
        expect(hitRect.height, lessThan(48));
        expect(semanticRect.width, greaterThan(hitRect.width));
        expect(hitRect.bottom, lessThanOrEqualTo(secondRect.top));

        await tester.pumpWidget(
          _grid(
            courses: [replacement, second, third],
            onTap: (info) => latest = info,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Semantics>(_annotation(label)).properties,
          same(properties),
        );
        final node = tester.getSemantics(_annotation(label));
        expect(node.id, nodeId);
        expect(
          node.getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.none,
        );
        expect(tester.getRect(_annotation(label)), semanticRect);
        expect(tester.getRect(_hit(replacement.id)), hitRect);
        expect(tester.getRect(_hit(second.id)), secondRect);
        _semanticTap(tester, label);
        expect(originalCalls, 0);
        expect(latest?.course.id, replacement.id);
        expect(latest?.anchorRect, semanticRect);

        await tester.tap(_hit(second.id));
        expect(latest?.course.id, second.id);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
