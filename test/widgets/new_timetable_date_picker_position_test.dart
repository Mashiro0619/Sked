import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

const newTimetableDatePickerPositionCaptureKey = ValueKey(
  'new-timetable-date-picker-position-capture',
);

typedef NewTimetableDatePickerPositionCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

const _viewport = Size(900, 720);
const _draftName = '尚未保存的课表草稿';

Finder _key(String value) => find.byKey(ValueKey(value));

void _expectOrigin(
  WidgetTester tester,
  Finder surface,
  Offset origin,
  String description,
) {
  final rect = tester.getRect(surface);
  expect(
    rect.left,
    closeTo(origin.dx, .01),
    reason: '$description changed the horizontal origin: $rect.',
  );
  expect(
    rect.top,
    closeTo(origin.dy, .01),
    reason: '$description changed the vertical origin: $rect.',
  );
}

Future<void> _click(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
) async {
  expect(target.hitTestable(), findsOneWidget);
  final point = tester.getCenter(target);
  await mouse.moveTo(point);
  await mouse.down(point);
  await mouse.up();
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  TestGesture mouse,
  NewTimetableDatePickerPositionCapture? capture,
  String scene,
) async {
  if (capture == null) return;
  await mouse.moveTo(const Offset(16, 16));
  await tester.pumpAndSettle();
  await capture(tester, scene);
}

void main() => runNewTimetableDatePickerPositionTests();

void runNewTimetableDatePickerPositionTests({
  NewTimetableDatePickerPositionCapture? capture,
}) {
  testWidgets(
    'new timetable start-date browsing keeps both floating panels and its draft',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _viewport;
      addTearDown(tester.view.reset);

      final provider = await workspaceProvider(
        locale: 'zh',
        storage: WorkspaceMemoryStorage(
          buildInitialAppData(
            buildDefaultPeriodTimes(),
            localeCode: 'zh',
          ).copyWith(activeMode: AppMode.student),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      });
      await provider.settingsCommands.updateHomeWorkspaceNavigationCollapsed(
        false,
      );
      await provider.settingsCommands.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: newTimetableDatePickerPositionCaptureKey,
          child: WorkspaceHarness(
            provider: provider,
            locale: const Locale('zh'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final storedTimetables = List.of(provider.studentView.timetables);
      expect(storedTimetables, isEmpty);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkspaceFrame)),
      );
      final create = find
          .widgetWithText(FilledButton, l10n.createTimetable)
          .hitTestable();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(16, 16));
      try {
        // Exercise the empty workspace's create action and its real date picker.
        await _click(tester, mouse, create);
        final editor = find.byType(TimetableInformationDialogSurface);
        final form = find.descendant(
          of: editor,
          matching: find.byType(TimetableInformationForm),
        );
        final parentSurface = _key('workspace-detail-surface');
        expect(editor, findsOneWidget);
        expect(form, findsOneWidget);
        expect(parentSurface, findsOneWidget);
        final editorElement = tester.element(editor);
        final formElement = tester.element(form);
        final initialForm = tester.widget<TimetableInformationForm>(form);
        final nameController = initialForm.nameController;
        final weeksController = initialForm.weeksController;
        final startDateLabel = initialForm.startDateLabel;
        final nameField = find.descendant(
          of: form,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.controller == nameController,
          ),
        );
        final weeksField = find.descendant(
          of: form,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.controller == weeksController,
          ),
        );
        await tester.enterText(nameField, _draftName);
        await tester.enterText(weeksField, '20');
        await tester.pumpAndSettle();

        final startDate = find.descendant(
          of: form,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SkedEditorValueField &&
                widget.label == l10n.semesterStartDate,
          ),
        );
        expect(startDate.hitTestable(), findsOneWidget);
        final parentOrigin = tester.getRect(parentSurface).topLeft;
        await _capture(tester, mouse, capture, 'new-timetable-draft');
        await _click(tester, mouse, startDate);

        final picker = find.byType(SkedDatePicker);
        final dateSurface = _key('sked-date-picker-surface');
        expect(picker, findsOneWidget);
        expect(dateSurface, findsOneWidget);
        final pickerState = tester.state(picker);
        final initialDate = tester.widget<SkedDatePicker>(picker).initialDate;
        final dateOrigin = tester.getRect(dateSurface).topLeft;

        void expectDraftAndPositions(String interaction) {
          _expectOrigin(
            tester,
            parentSurface,
            parentOrigin,
            '$interaction parent',
          );
          _expectOrigin(
            tester,
            dateSurface,
            dateOrigin,
            '$interaction date picker',
          );
          expect(tester.element(editor), same(editorElement));
          expect(tester.element(form), same(formElement));
          expect(tester.state(picker), same(pickerState));
          final currentForm = tester.widget<TimetableInformationForm>(form);
          expect(currentForm.nameController, same(nameController));
          expect(currentForm.weeksController, same(weeksController));
          expect(nameController.text, _draftName);
          expect(weeksController.text, '20');
          expect(currentForm.startDateLabel, startDateLabel);
          expect(provider.studentView.timetables, storedTimetables);
          expect(tester.takeException(), isNull);
        }

        expectDraftAndPositions('Opening the start-date picker');
        await _capture(tester, mouse, capture, 'new-timetable-date-days');
        final monthYearLabel = find
            .descendant(
              of: _key('sked-date-month-year'),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    (widget.data?.contains(initialDate.year.toString()) ??
                        false),
              ),
            )
            .hitTestable();
        await _click(tester, mouse, monthYearLabel);
        expect(
          _key('sked-date-month-${initialDate.year}-${initialDate.month}'),
          findsOneWidget,
        );
        expectDraftAndPositions('Opening month selection');
        await _capture(tester, mouse, capture, 'new-timetable-date-months');

        await _click(tester, mouse, monthYearLabel);
        expect(_key('sked-date-year-${initialDate.year}'), findsOneWidget);
        expectDraftAndPositions('Opening year selection');
        await _capture(tester, mouse, capture, 'new-timetable-date-years');

        await _click(tester, mouse, _key('sked-date-cancel'));
        expect(picker, findsNothing);
        expect(dateSurface, findsNothing);
        expect(parentSurface, findsOneWidget);
        _expectOrigin(
          tester,
          parentSurface,
          parentOrigin,
          'Cancelling date selection',
        );
        expect(tester.element(editor), same(editorElement));
        expect(tester.element(form), same(formElement));
        final retainedForm = tester.widget<TimetableInformationForm>(form);
        expect(retainedForm.nameController, same(nameController));
        expect(retainedForm.weeksController, same(weeksController));
        expect(nameController.text, _draftName);
        expect(weeksController.text, '20');
        expect(retainedForm.startDateLabel, startDateLabel);
        expect(provider.studentView.timetables, storedTimetables);
        expect(tester.takeException(), isNull);
        await _capture(tester, mouse, capture, 'new-timetable-date-cancelled');
      } finally {
        await mouse.removePointer();
        FocusManager.instance.primaryFocus?.unfocus();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
