import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';

final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);
const _scenarios = [
  (
    locale: 'en',
    brightness: Brightness.light,
    direction: TextDirection.ltr,
    scale: 1.0,
  ),
  (
    locale: 'zh',
    brightness: Brightness.dark,
    direction: TextDirection.ltr,
    scale: 1.0,
  ),
  (
    locale: 'en',
    brightness: Brightness.dark,
    direction: TextDirection.rtl,
    scale: 1.5,
  ),
  (
    locale: 'zh',
    brightness: Brightness.light,
    direction: TextDirection.rtl,
    scale: 2.0,
  ),
];

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _field(Finder editor, String label) => find.descendant(
  of: editor,
  matching: find.byWidgetPredicate(
    (widget) => widget is WorkspaceEditorField && widget.label == label,
  ),
);
Finder _input(Finder field) =>
    find.descendant(of: field, matching: find.byType(TextField));
Finder _value(Finder field) =>
    find.descendant(of: field, matching: find.byType(WorkspaceEditorValue));

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1000);
  addTearDown(tester.view.reset);
}

Widget _resizableEditor({
  required ValueNotifier<double> width,
  required Widget child,
  bool floating = true,
}) => Scaffold(
  body: Align(
    alignment: Alignment.topCenter,
    child: ValueListenableBuilder<double>(
      valueListenable: width,
      child: child,
      builder: (context, value, child) => SizedBox(
        width: value,
        child: WorkspaceEditorScope(
          enabled: true,
          floating: floating,
          onHeight: (_) {},
          child: child!,
        ),
      ),
    ),
  ),
);

void _expectPair(
  WidgetTester tester,
  Finder first,
  Finder second, {
  required bool columns,
  required TextDirection direction,
}) {
  final firstRect = tester.getRect(first);
  final secondRect = tester.getRect(second);
  if (columns) {
    expect(firstRect.top, closeTo(secondRect.top, .1));
    expect(firstRect.width, closeTo(secondRect.width, .1));
    expect(
      direction == TextDirection.ltr
          ? secondRect.left - firstRect.right
          : firstRect.left - secondRect.right,
      closeTo(12, .1),
    );
  } else {
    expect(secondRect.top - firstRect.bottom, closeTo(12, .1));
    expect(firstRect.left, closeTo(secondRect.left, .1));
    expect(firstRect.width, closeTo(secondRect.width, .1));
  }
}

void _expectTopLabel(WidgetTester tester, Finder field, String label) {
  final text = find.descendant(of: field, matching: find.text(label)).first;
  final control = find.descendant(
    of: field,
    matching: _key('editor-field-control'),
  );
  expect(tester.getRect(text).bottom, lessThan(tester.getRect(control).top));
  expect(tester.widget<Text>(text).style?.fontSize, 12);
}

void main() {
  for (final floating in [true, false]) {
    for (final scenario in _scenarios) {
      testWidgets(
        'course hybrid fields reflow without losing More draft: $scenario floating=$floating',
        (tester) async {
          _viewport(tester);
          final provider = await workspaceProvider(locale: scenario.locale);
          addTearDown(provider.dispose);
          final width = ValueNotifier(600.0);
          addTearDown(width.dispose);
          final editing = scenario.brightness == Brightness.dark;
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              locale: Locale(scenario.locale),
              brightness: scenario.brightness,
              textDirection: scenario.direction,
              textScale: scenario.scale,
              home: _resizableEditor(
                width: width,
                floating: floating,
                child: CourseEditorSheet(
                  periodTimes: buildDefaultPeriodTimes(),
                  totalWeeks: 18,
                  dayOfWeek: 1,
                  initialCourse: editing
                      ? provider.activeTimetable.courses.first
                      : null,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final editor = find.byType(CourseEditorSheet);
          final l = AppLocalizations.of(tester.element(editor));
          final title = _key('course-desktop-title');
          expect(tester.widget<TextField>(title).style!.fontSize, 22);
          await tester.enterText(title, 'Course title draft');

          final more = find.widgetWithText(ExpansionTile, l.more);
          final moreLabel = find.descendant(
            of: more,
            matching: find.text(l.more),
          );
          final moreController = tester.widget<ExpansionTile>(more).controller!;
          if (!moreController.isExpanded) {
            await tester.ensureVisible(moreLabel);
            await tester.tap(moreLabel);
            await tester.pumpAndSettle();
          }
          final teacher = _input(_field(editor, l.teacherName));
          await tester.ensureVisible(teacher);
          await tester.enterText(teacher, 'Teacher draft retained');
          final teacherElement = tester.element(teacher);
          final teacherInput = tester.widget<TextField>(teacher).controller!;
          teacherInput.selection = const TextSelection(
            baseOffset: 2,
            extentOffset: 9,
          );
          final teacherFocus = FocusManager.instance.primaryFocus;
          final timeElement = tester.element(_key('course-start-time-action'));

          for (final value in [320.0, 680.0, 600.0]) {
            width.value = value;
            await tester.pumpAndSettle();
            final columns = value - 32 >= 480 * scenario.scale + 12;
            _expectPair(
              tester,
              _field(editor, l.dayOfWeek),
              _field(editor, l.semesterWeeks),
              columns: columns,
              direction: scenario.direction,
            );
            _expectPair(
              tester,
              _field(editor, l.startTime),
              _field(editor, l.endTime),
              columns: columns,
              direction: scenario.direction,
            );
            _expectPair(
              tester,
              _field(editor, l.teacherName),
              _field(editor, l.credits),
              columns: columns,
              direction: scenario.direction,
            );
            for (final label in [
              l.location,
              l.dayOfWeek,
              l.semesterWeeks,
              l.startTime,
              l.endTime,
              l.linkedPeriods,
              l.teacherName,
              l.credits,
              l.remarks,
              l.customFields,
              l.courseSystemReminder,
            ]) {
              _expectTopLabel(tester, _field(editor, label), label);
            }
            expect(
              tester.getSize(_field(editor, l.location)).width,
              value - 32,
            );
            expect(
              tester.getSize(_field(editor, l.linkedPeriods)).width,
              value - 32,
            );
            expect(tester.element(teacher), same(teacherElement));
            expect(
              tester.element(_key('course-start-time-action')),
              same(timeElement),
            );
            expect(FocusManager.instance.primaryFocus, same(teacherFocus));
            expect(teacherInput.text, 'Teacher draft retained');
            expect(teacherInput.selection.baseOffset, 2);
            expect(teacherInput.selection.extentOffset, 9);
            expect(moreController.isExpanded, isTrue);
            final reminderValue = find
                .descendant(
                  of: _key('course-reminder-behavior'),
                  matching: find.byType(Text),
                )
                .first;
            expect(
              DefaultTextStyle.of(tester.element(reminderValue)).style.fontSize,
              14,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.ensureVisible(moreLabel);
          await tester.tap(moreLabel);
          await tester.pumpAndSettle();
          await tester.tap(moreLabel);
          await tester.pumpAndSettle();
          expect(tester.element(teacher), same(teacherElement));
          expect(teacherInput.text, 'Teacher draft retained');
          expect(
            tester.widget<TextField>(title).controller!.text,
            'Course title draft',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        variant: _desktop,
      );

      testWidgets(
        'timetable hybrid fields keep input focus and picker anchors: $scenario floating=$floating',
        (tester) async {
          _viewport(tester);
          final provider = await workspaceProvider(locale: scenario.locale);
          addTearDown(provider.dispose);
          final width = ValueNotifier(600.0);
          final name = TextEditingController(text: 'Timetable draft');
          final weeks = TextEditingController(text: '18');
          addTearDown(width.dispose);
          addTearDown(name.dispose);
          addTearDown(weeks.dispose);
          final dateAnchor = GlobalKey();
          final periodsAnchor = GlobalKey();
          var dateCalls = 0;
          var periodCalls = 0;
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              locale: Locale(scenario.locale),
              brightness: scenario.brightness,
              textDirection: scenario.direction,
              textScale: scenario.scale,
              home: _resizableEditor(
                width: width,
                floating: floating,
                child: TimetableInformationDialogSurface(
                  title: const Text('Timetable'),
                  onClose: () {},
                  actions: const [],
                  form: TimetableInformationForm(
                    nameController: name,
                    weeksController: weeks,
                    startDateLabel: '2026-10-05',
                    periodTimeSetSummary: scenario.locale == 'zh'
                        ? '默认节次 · 13 节'
                        : 'Default periods · 13 periods',
                    enabled: true,
                    startDateAnchorKey: dateAnchor,
                    periodTimeSetAnchorKey: periodsAnchor,
                    onPickStartDate: () => dateCalls++,
                    onPickPeriodTimeSet: () => periodCalls++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final editor = find.byType(TimetableInformationForm);
          final l = AppLocalizations.of(tester.element(editor));
          final weeksField = _input(_field(editor, l.totalWeeks));
          await tester.enterText(weeksField, '24');
          weeks.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
          final element = tester.element(weeksField);
          final focus = FocusManager.instance.primaryFocus;
          final originalDateAnchor = dateAnchor.currentContext;
          final originalPeriodsAnchor = periodsAnchor.currentContext;

          for (final value in [320.0, 680.0, 600.0]) {
            width.value = value;
            await tester.pumpAndSettle();
            _expectPair(
              tester,
              _field(editor, l.totalWeeks),
              _field(editor, l.semesterStartDate),
              columns: value - 32 >= 480 * scenario.scale + 12,
              direction: scenario.direction,
            );
            for (final label in [
              l.totalWeeks,
              l.semesterStartDate,
              l.periodTimeSets,
            ]) {
              _expectTopLabel(tester, _field(editor, label), label);
            }
            expect(
              tester.getSize(_field(editor, l.periodTimeSets)).width,
              value - 32,
            );
            expect(tester.element(weeksField), same(element));
            expect(FocusManager.instance.primaryFocus, same(focus));
            expect(weeks.selection.extentOffset, 1);
            expect(dateAnchor.currentContext, same(originalDateAnchor));
            expect(periodsAnchor.currentContext, same(originalPeriodsAnchor));
            expect(tester.takeException(), isNull);
          }
          await tester.tap(_value(_field(editor, l.semesterStartDate)));
          await tester.tap(_value(_field(editor, l.periodTimeSets)));
          expect(dateCalls, 1);
          expect(periodCalls, 1);
          expect(name.text, 'Timetable draft');
          expect(weeks.text, '24');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        variant: _desktop,
      );
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'long course weeks reflow after picker selection without replacing anchors: $direction',
      (tester) async {
        _viewport(tester);
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        final width = ValueNotifier(600.0);
        addTearDown(width.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            textDirection: direction,
            home: _resizableEditor(
              width: width,
              child: CourseEditorSheet(
                periodTimes: buildDefaultPeriodTimes(),
                totalWeeks: 18,
                dayOfWeek: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final editor = find.byType(CourseEditorSheet);
        final l = AppLocalizations.of(tester.element(editor));
        final day = _field(editor, l.dayOfWeek);
        final weeks = _field(editor, l.semesterWeeks);
        final weekAnchor = tester.element(_value(weeks));
        final startAnchor = tester.element(_key('course-start-time-action'));
        final title = _key('course-desktop-title');
        await tester.enterText(title, 'Retained course draft');
        final titleController = tester.widget<TextField>(title).controller!;
        _expectPair(tester, day, weeks, columns: true, direction: direction);

        Future<void> selectWeeks(String action) async {
          await tester.ensureVisible(_value(weeks));
          await tester.tap(_value(weeks));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(TextButton, action));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, l.confirm));
          await tester.pumpAndSettle();
        }

        await selectWeeks('1, 3, 5…');
        _expectPair(tester, day, weeks, columns: false, direction: direction);
        expect(tester.element(_value(weeks)), same(weekAnchor));
        expect(
          tester.element(_key('course-start-time-action')),
          same(startAnchor),
        );
        expect(titleController.text, 'Retained course draft');
        await tester.ensureVisible(title);
        await tester.showKeyboard(title);
        titleController.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 8,
        );
        final focus = FocusManager.instance.primaryFocus;
        for (final nextWidth in [320.0, 680.0, 600.0]) {
          width.value = nextWidth;
          await tester.pumpAndSettle();
          _expectPair(tester, day, weeks, columns: false, direction: direction);
          expect(tester.element(_value(weeks)), same(weekAnchor));
          expect(
            tester.element(_key('course-start-time-action')),
            same(startAnchor),
          );
          expect(FocusManager.instance.primaryFocus, same(focus));
          expect(titleController.selection.extentOffset, 8);
        }
        await selectWeeks(l.selectAll);
        _expectPair(tester, day, weeks, columns: true, direction: direction);
        expect(tester.element(_value(weeks)), same(weekAnchor));
        expect(titleController.text, 'Retained course draft');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'long timetable date text takes a full row while retaining weeks focus',
    (tester) async {
      _viewport(tester);
      final provider = await workspaceProvider();
      addTearDown(provider.dispose);
      final width = ValueNotifier(600.0);
      final dateLabel = ValueNotifier('2026-10-05');
      final name = TextEditingController(text: 'Timetable draft');
      final weeks = TextEditingController(text: '18');
      final dateKey = GlobalKey();
      addTearDown(width.dispose);
      addTearDown(dateLabel.dispose);
      addTearDown(name.dispose);
      addTearDown(weeks.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: _resizableEditor(
            width: width,
            child: ValueListenableBuilder<String>(
              valueListenable: dateLabel,
              builder: (context, value, _) => TimetableInformationDialogSurface(
                title: const Text('Timetable'),
                onClose: () {},
                actions: const [],
                form: TimetableInformationForm(
                  nameController: name,
                  weeksController: weeks,
                  startDateLabel: value,
                  periodTimeSetSummary: 'Default periods',
                  enabled: true,
                  startDateAnchorKey: dateKey,
                  onPickStartDate: () {},
                  onPickPeriodTimeSet: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = find.byType(TimetableInformationForm);
      final l = AppLocalizations.of(tester.element(editor));
      final weeksField = _field(editor, l.totalWeeks);
      final date = _field(editor, l.semesterStartDate);
      _expectPair(
        tester,
        weeksField,
        date,
        columns: true,
        direction: TextDirection.ltr,
      );
      final input = _input(weeksField);
      await tester.enterText(input, '24');
      weeks.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
      final inputElement = tester.element(input);
      final dateAnchor = dateKey.currentContext;
      final focus = FocusManager.instance.primaryFocus;

      dateLabel.value = 'Monday, October 5, 2026';
      await tester.pumpAndSettle();
      _expectPair(
        tester,
        weeksField,
        date,
        columns: false,
        direction: TextDirection.ltr,
      );
      expect(tester.element(input), same(inputElement));
      expect(dateKey.currentContext, same(dateAnchor));
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(weeks.selection.extentOffset, 1);
      dateLabel.value = '2026-10-05';
      await tester.pumpAndSettle();
      _expectPair(
        tester,
        weeksField,
        date,
        columns: true,
        direction: TextDirection.ltr,
      );
      expect(tester.element(input), same(inputElement));
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(weeks.text, '24');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: _desktop,
  );

  testWidgets(
    'course hybrid time pickers keep distinct anchors and draft through failed save retry',
    (tester) async {
      _viewport(tester);
      final provider = await workspaceProvider();
      addTearDown(provider.dispose);
      final width = ValueNotifier(600.0);
      addTearDown(width.dispose);
      var attempts = 0;
      CourseItem? saved;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => _resizableEditor(
                        width: width,
                        child: CourseEditorSheet(
                          periodTimes: buildDefaultPeriodTimes(),
                          totalWeeks: 18,
                          dayOfWeek: 1,
                          onSave: (course) async {
                            attempts++;
                            if (attempts == 1) throw StateError('Try again');
                            saved = course;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final editor = find.byType(CourseEditorSheet);
      final l = AppLocalizations.of(tester.element(editor));
      final title = _key('course-desktop-title');
      await tester.enterText(title, 'Saved hybrid course');
      await tester.enterText(_input(_field(editor, l.location)), 'Room 201');
      final controller = tester.widget<TextField>(title).controller!;
      final startAnchor = tester.element(_key('course-start-time-action'));
      final endAnchor = tester.element(_key('course-end-time-action'));

      await tester.tap(_key('course-start-time-action'));
      await tester.pumpAndSettle();
      expect(find.byType(SkedTimePicker), findsOneWidget);
      await tester.enterText(_key('sked-time-minute-input'), '05');
      await tester.tap(_key('sked-time-confirm'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkspaceEditorValue>(_key('course-start-time-action'))
            .value,
        '08:05',
      );
      width.value = 320;
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('course-end-time-action'));
      await tester.tap(_key('course-end-time-action'));
      await tester.pumpAndSettle();
      expect(find.byType(SkedTimePicker), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SkedTimePicker), findsNothing);
      expect(
        tester.element(_key('course-start-time-action')),
        same(startAnchor),
      );
      expect(tester.element(_key('course-end-time-action')), same(endAnchor));
      expect(controller.text, 'Saved hybrid course');

      final save = find.widgetWithText(FilledButton, l.save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(editor, findsOneWidget);
      expect(tester.widget<TextField>(title).controller, same(controller));
      expect(controller.text, 'Saved hybrid course');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(editor, findsNothing);
      expect(saved!.name, 'Saved hybrid course');
      expect(saved!.location, 'Room 201');
      expect(saved!.startMinutes, 485);
      expect(saved!.endMinutes, buildDefaultPeriodTimes()[1].endMinutes);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );
}
