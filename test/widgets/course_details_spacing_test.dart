import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/workspace_view_panel.dart';

import '../support/workspace_harness.dart';

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);
final _mobile = TargetPlatformVariant.only(TargetPlatform.android);
const _panelKey = ValueKey('course-details-spacing-panel');
const _remarks =
    '考查 理论:32,实验:8 周学时:4 总学时:40 必修专业基础 '
    '教学班:(2026-2027-1)-0300058-01 教学班组成:25软件二;25软件一';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _primary(IconData icon) =>
    find.ancestor(of: find.byIcon(icon), matching: find.byType(Row)).first;

class _Fixture {
  _Fixture(this.provider, this.course);

  final TimetableProvider provider;
  final CourseItem course;
  int editCount = 0;
  int closeCount = 0;
  Offset drag = Offset.zero;
  Rect? editAnchor;

  AppLocalizations strings(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(CourseDetailsSheet)));

  List<String> values(WidgetTester tester) => [
    course.teacher,
    formatDayOfWeekLabel(
      course.dayOfWeek,
      localeCode: Localizations.localeOf(
        tester.element(find.byType(CourseDetailsSheet)),
      ).languageCode,
    ),
    formatSemesterWeeksValue(course.semesterWeeks),
    course.credit.toString(),
    course.remarks,
  ];
}

Future<_Fixture> _pump(
  WidgetTester tester, {
  String locale = 'zh',
  TextDirection direction = TextDirection.ltr,
  double width = 440,
  double scale = 1,
  bool viewTask = true,
  bool floating = true,
  String remarks = _remarks,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(locale: locale);
  final course = provider.activeTimetable.courses.first.copyWith(
    name: locale == 'zh' ? '计算方法' : 'Numerical Methods',
    teacher: locale == 'zh' ? '肖莎莎' : 'Prof. Chen',
    location: locale == 'zh' ? '辽河路校区 玉衡B308(公共机房)' : 'West campus · Room B308',
    dayOfWeek: 1,
    semesterWeeks: List.generate(10, (index) => index + 3),
    periods: const [1, 2],
    startMinutes: 480,
    endMinutes: 575,
    timeRange: buildTimeRange(480, 575),
    credit: 2.5,
    remarks: remarks,
    customFields: const {},
  );
  await provider.saveCourse(course);
  final fixture = _Fixture(provider, course);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: Locale(locale),
      textDirection: direction,
      textScale: scale,
      brightness: direction == TextDirection.rtl
          ? Brightness.dark
          : Brightness.light,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: _panelKey,
            width: width,
            child: WorkspaceViewTaskScope(
              enabled: viewTask,
              onClose: () => fixture.closeCount++,
              onContentHeight: (_) {},
              child: WorkspaceViewLayoutScope(
                compact: floating,
                onDragUpdate: (delta) => fixture.drag += delta,
                child: CourseDetailsSheet(
                  timetableId: provider.activeTimetable.id,
                  courseId: course.id,
                  weekday: course.dayOfWeek,
                  conflictKey: null,
                  isFullConflict: false,
                  onEdit: () => fixture.editCount++,
                  onEditAnchor: (anchor) {
                    final box = anchor.findRenderObject()! as RenderBox;
                    fixture.editAnchor =
                        box.localToGlobal(Offset.zero) & box.size;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

void main() {
  testWidgets(
    'desktop details remove nested card padding and use deliberate group gaps',
    (tester) async {
      final fixture = await _pump(tester);
      final strings = fixture.strings(tester);
      final panel = tester.getRect(find.byKey(_panelKey));
      final header = tester.getRect(_key('workspace-view-header'));
      final body = tester.getRect(_key('workspace-view-body'));
      final place = tester.getRect(_primary(Icons.place_outlined));
      final time = tester.getRect(_primary(Icons.schedule));

      expect(header.height, closeTo(48, .1));
      expect(place.top - body.top, closeTo(12, .1));
      expect(place.left - panel.left, closeTo(16, .1));
      expect(panel.right - place.right, closeTo(16, .1));
      expect(time.top - place.bottom, closeTo(12, .1));
      expect(
        tester.getTopLeft(find.text(strings.teacherName)).dy - time.bottom,
        closeTo(16, .1),
      );
      expect(
        tester.getTopLeft(find.text(fixture.course.location)).dy -
            tester.getBottomLeft(find.text(strings.place)).dy,
        closeTo(4, .1),
      );
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final scenario in [
    (locale: 'zh', direction: TextDirection.ltr, floating: true),
    (locale: 'en', direction: TextDirection.ltr, floating: false),
    (locale: 'en', direction: TextDirection.rtl, floating: true),
  ]) {
    testWidgets('desktop attributes share a full value column: $scenario', (
      tester,
    ) async {
      final fixture = await _pump(
        tester,
        locale: scenario.locale,
        direction: scenario.direction,
        floating: scenario.floating,
      );
      final strings = fixture.strings(tester);
      final labels = [
        strings.teacherName,
        strings.dayOfWeek,
        strings.semesterWeeks,
        strings.credits,
        strings.remarks,
      ];
      final values = fixture.values(tester);
      final panel = tester.getRect(find.byKey(_panelKey));
      final firstLabel = tester.getRect(find.text(labels.first));
      final firstValue = tester.getRect(find.text(values.first));
      final ltr = scenario.direction == TextDirection.ltr;

      expect(firstLabel.top, closeTo(firstValue.top, .1));
      expect(
        ltr
            ? firstValue.left - firstLabel.right
            : firstLabel.left - firstValue.right,
        closeTo(12, .1),
      );
      for (var index = 0; index < values.length; index++) {
        final value = tester.getRect(find.text(values[index]));
        final label = tester.getRect(find.text(labels[index]));
        expect(value.left, closeTo(firstValue.left, .1));
        expect(value.right, closeTo(firstValue.right, .1));
        expect(value.top, closeTo(label.top, .1));
        expect(
          ltr ? value.right : value.left,
          closeTo(ltr ? panel.right - 16 : panel.left + 16, .1),
        );
        if (index > 0) {
          final previous = tester.getRect(find.text(values[index - 1]));
          expect(value.top - previous.bottom, closeTo(8, .1));
        }
      }
      final remarks = tester.widget<Text>(find.text(fixture.course.remarks));
      expect(remarks.maxLines, isNull);
      expect(remarks.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    }, variant: _desktop);
  }

  testWidgets(
    'narrow large-text details stack attributes and scroll complete remarks',
    (tester) async {
      final remarks = '${List.filled(8, _remarks).join('\n')}\n备注结束';
      final fixture = await _pump(
        tester,
        width: 320,
        scale: 2,
        remarks: remarks,
      );
      final strings = fixture.strings(tester);
      final panel = tester.getRect(find.byKey(_panelKey));
      final header = tester.getRect(_key('workspace-view-header'));
      final teacherLabel = tester.getRect(find.text(strings.teacherName));
      final teacher = tester.getRect(find.text(fixture.course.teacher));
      final notes = find.text(remarks);
      final paragraph = tester.renderObject<RenderParagraph>(notes);

      expect(teacher.top - teacherLabel.bottom, closeTo(2, .1));
      expect(teacher.left, closeTo(panel.left + 16, .1));
      expect(teacher.right, closeTo(panel.right - 16, .1));
      expect(tester.getSize(notes).width, closeTo(288, .1));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.widget<Text>(notes).data, endsWith('备注结束'));

      final body = _key('workspace-view-body');
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(of: body, matching: find.byType(Scrollable)),
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final ending = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: remarks.length - 4,
          extentOffset: remarks.length,
        ),
      );
      expect(ending, isNotEmpty);
      final lastLine = paragraph.localToGlobal(
        Offset(ending.last.left, ending.last.bottom),
      );
      expect(tester.getRect(body).contains(lastLine), isTrue);
      expect(tester.getRect(_key('workspace-view-header')), header);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    '320-wide title, edit and close stay aligned and retain their actions',
    (tester) async {
      final fixture = await _pump(tester, width: 320);
      final edit = find.byTooltip(fixture.strings(tester).editCourseTooltip);
      final close = _key('workspace-inspector-close');
      final title = find.text(fixture.course.name);
      final titleRect = tester.getRect(title);
      final editRect = tester.getRect(edit);
      final closeRect = tester.getRect(close);
      final titleText = tester.widget<Text>(title);

      expect(titleText.style!.fontSize, 18);
      expect(titleText.style!.fontWeight, FontWeight.w600);
      expect(editRect.size, const Size(32, 32));
      expect(closeRect.size, editRect.size);
      expect(titleRect.center.dy, closeTo(editRect.center.dy, .1));
      expect(closeRect.center.dy, closeTo(editRect.center.dy, .1));
      expect(titleRect.right, lessThan(editRect.left));
      expect(editRect.right, lessThan(closeRect.left));
      expect(edit.hitTestable(), findsOneWidget);
      expect(close.hitTestable(), findsOneWidget);

      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(fixture.editCount, 1);
      expect(fixture.editAnchor, editRect);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(fixture.closeCount, 1);
      final gesture = await tester.startGesture(
        tester.getCenter(_key('workspace-view-drag-handle')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(25, 20));
      await tester.pump();
      await gesture.moveBy(const Offset(25, 20));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.drag.distance, greaterThan(0));
      expect(fixture.editCount, 1);
      expect(fixture.closeCount, 1);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'long custom labels reflow independently without widening built-in labels',
    (tester) async {
      final fixture = await _pump(tester);
      final originalTeacher = tester.getRect(find.text(fixture.course.teacher));
      const customLabel = 'Imported classroom provisioning classification name';
      const customValue = 'Imported value kept visible';
      await fixture.provider.saveCourse(
        fixture.course.copyWith(customFields: const {customLabel: customValue}),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text(fixture.course.teacher)),
        originalTeacher,
      );
      final label = tester.getRect(find.text(customLabel));
      final value = tester.getRect(find.text(customValue));
      expect(value.top - label.bottom, closeTo(2, .1));
      expect(value.left, label.left);
      expect(value.width, label.width);
      expect(
        value.width,
        closeTo(tester.getSize(find.byKey(_panelKey)).width - 32, .1),
      );
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'mobile details keep the existing heading, padded cards and loose rows',
    (tester) async {
      final fixture = await _pump(tester, width: 390, viewTask: false);
      final panel = tester.getRect(find.byKey(_panelKey));
      final strings = fixture.strings(tester);
      final heading = tester.widget<Text>(find.text(fixture.course.name));
      final theme = Theme.of(tester.element(find.byType(CourseDetailsSheet)));

      expect(find.byType(WorkspaceViewPanel), findsNothing);
      expect(heading.style, theme.textTheme.headlineSmall);
      expect(
        tester.getTopLeft(find.byIcon(Icons.place_outlined)).dx - panel.left,
        closeTo(30, .1),
      );
      expect(
        tester.getSize(find.byIcon(Icons.place_outlined)),
        const Size(24, 24),
      );
      expect(
        tester.widget<Text>(find.text(strings.place)).style,
        theme.textTheme.labelLarge,
      );
      expect(
        tester.getTopLeft(find.text(fixture.course.teacher)).dx,
        greaterThan(tester.getTopLeft(find.text('2.5')).dx),
      );
      expect(tester.takeException(), isNull);
    },
    variant: _mobile,
  );
}
