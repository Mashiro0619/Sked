import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';

final _android = TargetPlatformVariant.only(TargetPlatform.android);

Finder _dayField() => find.byWidgetPredicate(
  (widget) => widget is SkedEditorValueField && widget.label == '上课日',
);

Finder _weekday(String label) => find.byWidgetPredicate(
  (widget) => widget is SkedEditorOption && widget.label == label,
);

void _phone(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 640);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
}

Future<void> _openWeekdayPicker(WidgetTester tester) async {
  final field = _dayField();
  expect(field, findsOneWidget);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  expect(find.text('选择上课日'), findsOneWidget);
  expect(find.byType(AlertDialog), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void _expectInlineMarker(
  WidgetTester tester,
  Finder option, {
  required String label,
  required String shortLabel,
}) {
  final title = find.descendant(of: option, matching: find.text(label));
  final leading = find.descendant(of: option, matching: find.text(shortLabel));
  final marker = find.descendant(
    of: option,
    matching: find.byIcon(Icons.check_circle),
  );
  expect(title, findsOneWidget);
  expect(leading, findsOneWidget);
  expect(marker, findsOneWidget);
  final titleRect = tester.getRect(title);
  final markerRect = tester.getRect(marker);
  expect(markerRect.center.dy, closeTo(titleRect.center.dy, .01));
  expect(tester.getRect(leading).center.dy, closeTo(titleRect.center.dy, .01));
  expect(markerRect.left, greaterThanOrEqualTo(titleRect.right));
  expect(tester.getRect(option).height, greaterThanOrEqualTo(48));
}

void _expectWeekdayRows(
  WidgetTester tester, {
  required String selectedLabel,
  required String selectedShortLabel,
  required String otherLabel,
}) {
  final selected = _weekday(selectedLabel);
  final other = _weekday(otherLabel);
  expect(selected, findsOneWidget);
  expect(other, findsOneWidget);
  expect(tester.widget<SkedEditorOption>(selected).selected, isTrue);
  expect(tester.widget<SkedEditorOption>(other).selected, isFalse);
  expect(
    tester.getSize(selected).height,
    closeTo(tester.getSize(other).height, .01),
    reason: 'The selection marker must not add a second row.',
  );
  _expectInlineMarker(
    tester,
    selected,
    label: selectedLabel,
    shortLabel: selectedShortLabel,
  );
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'course weekday selection stays inline at $width with $scale text',
        (tester) async {
          _phone(tester, width);
          final provider = await workspaceProvider(locale: 'zh');
          addTearDown(provider.dispose);
          final before = provider.workspaceView.data.toJson();
          var saveCalls = 0;
          final source = CourseItem(
            id: 'weekday-layout-course',
            name: '马克思主义基本原理',
            teacher: '',
            location: '',
            dayOfWeek: DateTime.monday,
            semesterWeeks: const [1, 2],
            periods: const [1, 2],
            startMinutes: 8 * 60,
            endMinutes: 9 * 60 + 35,
            timeRange: buildTimeRange(8 * 60, 9 * 60 + 35),
            credit: 0,
            remarks: '',
            customFields: const {},
          );
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              locale: const Locale('zh'),
              textScale: scale,
              home: Scaffold(
                body: CourseEditorSheet(
                  periodTimes: buildDefaultPeriodTimes(),
                  totalWeeks: 18,
                  dayOfWeek: DateTime.monday,
                  initialCourse: source,
                  onSave: (_) async {
                    saveCalls++;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _openWeekdayPicker(tester);
          _expectWeekdayRows(
            tester,
            selectedLabel: '星期一',
            selectedShortLabel: '一',
            otherLabel: '星期二',
          );
          await tester.tap(_weekday('星期二'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.widget<SkedEditorValueField>(_dayField()).value, '星期二');
          expect(saveCalls, 0);
          expect(source.dayOfWeek, DateTime.monday);
          expect(provider.workspaceView.data.toJson(), before);
          expect(tester.takeException(), isNull);

          await _openWeekdayPicker(tester);
          _expectWeekdayRows(
            tester,
            selectedLabel: '星期二',
            selectedShortLabel: '二',
            otherLabel: '星期一',
          );
          final sunday = _weekday('星期日');
          await tester.ensureVisible(sunday);
          await tester.pumpAndSettle();
          expect(sunday.hitTestable(), findsOneWidget);
          await tester.tap(sunday);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(tester.widget<SkedEditorValueField>(_dayField()).value, '星期日');
          expect(saveCalls, 0);
          expect(provider.workspaceView.data.toJson(), before);

          await _openWeekdayPicker(tester);
          await tester.ensureVisible(_weekday('星期日'));
          await tester.pumpAndSettle();
          _expectWeekdayRows(
            tester,
            selectedLabel: '星期日',
            selectedShortLabel: '日',
            otherLabel: '星期六',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        variant: _android,
      );
    }
  }
}
