import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _form => find.byType(TimetableInformationDialogSurface);
Finder get _fields => find.byType(TimetableInformationForm);
Finder get _editor => find.byType(WorkspaceEditorScaffold);
Finder _field(int index) =>
    find.descendant(of: _fields, matching: find.byType(TextField)).at(index);
Finder _valueButton(String label) => find.descendant(
  of: find.descendant(
    of: _fields,
    matching: find.byWidgetPredicate(
      (widget) => widget is WorkspaceEditorValue && widget.label == label,
    ),
  ),
  matching: find.byType(TextButton),
);
Finder get _scroll => find
    .ancestor(of: _form, matching: find.byType(SingleChildScrollView))
    .first;
Finder get _surface =>
    find.ancestor(of: _form, matching: _key('app-bottom-task-surface')).first;

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.reset);
}

Future<TimetableProvider> _open(
  WidgetTester t, {
  bool editing = false,
  String locale = 'en',
  double scale = 1,
  WorkspacePanelDisplayMode? panelDisplayMode,
  WorkspaceMemoryStorage? storage,
}) async {
  final provider = await workspaceProvider(
    locale: locale,
    storage:
        storage ??
        (editing
            ? null
            : WorkspaceMemoryStorage(
                buildInitialAppData(
                  buildDefaultPeriodTimes(),
                  localeCode: locale,
                ),
              )),
  );
  addTearDown(provider.dispose);
  if (panelDisplayMode != null) {
    await provider.updateWorkspacePanelDisplayMode(panelDisplayMode);
  }
  await t.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: Locale(locale),
      textScale: scale,
      home: const HomeScreen(),
    ),
  );
  await t.pumpAndSettle();
  final l = AppLocalizations.of(t.element(find.byType(HomeScreen)));
  if (editing) {
    final id = provider.activeTimetable.id;
    final resourceRow = _key('resource-timetable-$id');
    final resourceEdit = _key('resource-timetable-edit-$id');
    if (resourceRow.hitTestable().evaluate().isEmpty) {
      final picker = _key('student-timetable-picker-button');
      await t.tap(
        picker.hitTestable().evaluate().isNotEmpty
            ? picker
            : _key('workspace-resource-collapse'),
      );
      await t.pumpAndSettle();
    }
    if (resourceRow.hitTestable().evaluate().isNotEmpty) {
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: t.getCenter(resourceRow));
      addTearDown(mouse.removePointer);
      await t.pumpAndSettle();
      expect(resourceEdit.hitTestable(), findsOneWidget);
      await t.tap(resourceEdit);
    } else {
      await t.tap(find.byTooltip(l.editTimetable).hitTestable());
    }
  } else {
    final create = find.widgetWithText(FilledButton, l.createTimetable);
    await t.ensureVisible(create);
    await t.pumpAndSettle();
    expect(create.hitTestable(), findsOneWidget);
    await t.tap(create);
  }
  await t.pumpAndSettle();
  expect(_fields, findsOneWidget);
  return provider;
}

void main() {
  for (final editing in [false, true]) {
    for (final locale in ['en', 'zh']) {
      testWidgets(
        'phone timetable editing=$editing $locale sheet wraps its form',
        (t) async {
          _viewport(t, const Size(393, 852));
          final provider = await _open(t, editing: editing, locale: locale);
          final before = provider.timetables.length;
          expect(
            ModalRoute.of(t.element(_form)),
            isA<ModalBottomSheetRoute<dynamic>>(),
          );
          final surface = t.getRect(_surface);
          final form = t.getRect(_form);
          expect(
            surface.height,
            closeTo(form.height + 24, .01),
            reason: 'Only the bottom safe area may extend past a short form.',
          );
          expect(surface.bottom, 852);
          expect(surface.top, greaterThan(24 + 100));
          final l = AppLocalizations.of(t.element(_form));
          final cancel = find.descendant(
            of: _form,
            matching: find.widgetWithText(TextButton, l.cancel),
          );
          expect(cancel.hitTestable(), findsOneWidget);
          await t.tap(cancel);
          await t.pumpAndSettle();
          expect(_form, findsNothing);
          expect(provider.timetables.length, before);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }

  for (final size in [
    const Size(393, 852),
    const Size(320, 568),
    const Size(800, 393),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'phone timetable $size scale=$scale uses the keyboard inset once',
        (t) async {
          _viewport(t, size);
          final provider = await _open(t, locale: 'zh', scale: scale);
          final field = find
              .descendant(of: _form, matching: find.byType(TextField))
              .first;
          final controller = t.widget<TextField>(field).controller!;
          await t.enterText(field, '键盘与旋转后保留的课表');
          const keyboard = 180.0;
          t.view.viewInsets = const FakeViewPadding(bottom: keyboard);
          t.view.padding = const FakeViewPadding(top: 24);
          await t.pumpAndSettle();
          expect(t.widget<TextField>(field).controller, same(controller));
          final surface = t.getRect(_surface);
          final viewport = t.getRect(_scroll);
          expect(surface.bottom, closeTo(size.height - keyboard, .01));
          expect(
            viewport.bottom,
            closeTo(surface.bottom, .01),
            reason: 'The modal host already removes the IME; no second inset.',
          );
          expect(surface.top, greaterThanOrEqualTo(24));
          final l = AppLocalizations.of(t.element(_form));
          final save = find.descendant(
            of: _form,
            matching: find.widgetWithText(FilledButton, l.save),
          );
          await t.ensureVisible(save);
          await t.pumpAndSettle();
          expect(save.hitTestable(), findsOneWidget);
          expect(
            t.getRect(save).bottom,
            lessThanOrEqualTo(size.height - keyboard),
          );
          expect(t.takeException(), isNull);
          t.view.viewInsets = const FakeViewPadding();
          t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          t.view.physicalSize = const Size(393, 852);
          await t.pumpAndSettle();
          expect(controller.text, '键盘与旋转后保留的课表');
          await t.ensureVisible(save);
          await t.pumpAndSettle();
          await t.tap(save);
          await t.pumpAndSettle();
          expect(_form, findsNothing);
          expect(provider.activeTimetable.config.name, '键盘与旋转后保留的课表');
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }

  for (final editing in [false, true]) {
    testWidgets(
      'desktop timetable editing=$editing floats, drags and resizes its draft',
      (t) async {
        _viewport(t, const Size(1440, 900));
        final provider = await _open(
          t,
          editing: editing,
          panelDisplayMode: WorkspacePanelDisplayMode.overlay,
        );
        final originalNames = provider.timetables
            .map((timetable) => timetable.config.name)
            .toList();
        final element = t.element(_fields);
        final l = AppLocalizations.of(element);
        expect(find.byType(BottomSheet), findsNothing);
        expect(WorkspaceTaskScope.contains(element), isTrue);
        expect(WorkspaceEditorScope.maybeOf(element)?.floating, isTrue);
        expect(_key('workspace-editor-barrier'), findsOneWidget);
        expect(_key('workspace-editor-close'), findsOneWidget);
        expect(_key('workspace-inspector-header'), findsNothing);
        expect(
          find.descendant(
            of: _key('workspace-editor-drag'),
            matching: find.text(editing ? l.editTimetable : l.createTimetable),
          ),
          findsOneWidget,
        );
        final surface = _key('workspace-detail-surface');
        final initial = t.getRect(surface);
        expect(initial.height, closeTo(t.getSize(_editor).height, .01));
        expect(initial.height, lessThan(600));
        expect(initial.left, greaterThanOrEqualTo(8));
        expect(initial.right, lessThanOrEqualTo(1440 - 8));

        await t.enterText(_field(0), 'Floating timetable draft');
        final input = t.widget<TextField>(_field(0)).controller!;
        input.selection = const TextSelection(baseOffset: 0, extentOffset: 8);
        await t.pumpAndSettle();
        final delta = Offset(initial.center.dx > 720 ? -100 : 100, 32);
        await t.drag(_key('workspace-editor-drag'), delta);
        await t.pumpAndSettle();
        final dragged = t.getRect(surface);
        expect((dragged.left - initial.left).abs(), greaterThan(50));
        expect(dragged.size, initial.size);
        await t.drag(_key('workspace-detail-resize'), const Offset(80, 0));
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, lessThan(dragged.width));
        expect(t.element(_fields), same(element));
        expect(t.widget<TextField>(_field(0)).controller, same(input));
        expect(input.text, 'Floating timetable draft');
        expect(input.selection.extentOffset, 8);

        await t.tap(_key('workspace-editor-close'));
        await t.pumpAndSettle();
        final confirmation = find.byType(AlertDialog);
        expect(confirmation, findsOneWidget);
        await t.tap(
          find.descendant(
            of: confirmation,
            matching: find.widgetWithText(TextButton, l.cancel),
          ),
        );
        await t.pumpAndSettle();
        expect(t.element(_fields), same(element));
        expect(input.text, 'Floating timetable draft');
        await t.tap(
          find.descendant(
            of: _editor,
            matching: find.widgetWithText(TextButton, l.cancel),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, l.discardChangesAndExit));
        await t.pumpAndSettle();
        expect(_fields, findsNothing);
        expect(
          provider.timetables.map((timetable) => timetable.config.name),
          orderedEquals(originalNames),
        );
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'narrow desktop timetable keeps a large-text draft through pickers and saves',
    (t) async {
      _viewport(t, const Size(760, 620));
      final initial = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'zh',
      );
      const evening = PeriodTimeSet(
        id: 'evening-periods',
        name: '晚间节次',
        periodTimes: [
          CoursePeriodTime(index: 1, startMinutes: 1080, endMinutes: 1125),
        ],
      );
      final storage = WorkspaceMemoryStorage(
        initial.copyWith(
          studentMode: initial.studentMode.copyWith(
            periodTimeSets: [...initial.studentMode.periodTimeSets, evening],
          ),
        ),
      );
      final provider = await _open(t, locale: 'zh', scale: 2, storage: storage);
      final element = t.element(_fields);
      final l = AppLocalizations.of(element);
      expect(WorkspaceEditorScope.maybeOf(element)?.floating, isTrue);
      expect(_key('workspace-editor-barrier'), findsOneWidget);
      await t.enterText(_field(0), '窄窗口里的课表草稿');
      await t.ensureVisible(_field(1));
      await t.enterText(_field(1), '20');
      final input = t.widget<TextField>(_field(0)).controller!;

      final date = _valueButton(l.semesterStartDate);
      await t.ensureVisible(date);
      await t.pumpAndSettle();
      await t.tap(date);
      await t.pumpAndSettle();
      final picker = find.byType(SkedDatePicker);
      expect(picker, findsOneWidget);
      final originalDate = t.widget<SkedDatePicker>(picker).initialDate;
      final selectedDate = DateTime(
        originalDate.year,
        originalDate.month,
        originalDate.day == 1 ? 2 : 1,
      );
      final dateLabel = selectedDate.toIso8601String().split('T').first;
      final day = _key('sked-date-$dateLabel');
      await t.ensureVisible(day);
      await t.tap(day);
      await t.ensureVisible(_key('sked-date-confirm'));
      await t.pumpAndSettle();
      await t.tap(_key('sked-date-confirm'));
      await t.pumpAndSettle();
      expect(picker, findsNothing);
      expect(t.element(_fields), same(element));
      expect(
        t.widget<TimetableInformationForm>(_fields).startDateLabel,
        dateLabel,
      );

      final periods = _valueButton(l.periodTimeSets);
      await t.ensureVisible(periods);
      await t.pumpAndSettle();
      await t.tap(periods);
      await t.pumpAndSettle();
      final periodPicker = find.byType(PeriodTimeSetPickerDialogView);
      expect(periodPicker, findsOneWidget);
      final eveningOption = find.descendant(
        of: periodPicker,
        matching: find.text(evening.name),
      );
      await t.ensureVisible(eveningOption);
      await t.pumpAndSettle();
      await t.tap(eveningOption);
      await t.pumpAndSettle();
      expect(periodPicker, findsNothing);
      expect(t.element(_fields), same(element));
      expect(provider.timetables, isEmpty);

      t.view.physicalSize = const Size(660, 420);
      await t.pumpAndSettle();
      expect(t.element(_fields), same(element));
      expect(t.widget<TextField>(_field(0)).controller, same(input));
      expect(input.text, '窄窗口里的课表草稿');
      final panel = t.getRect(_key('workspace-detail-surface'));
      expect(panel.left, greaterThanOrEqualTo(8));
      expect(panel.right, lessThanOrEqualTo(660 - 8));
      expect(panel.top, greaterThanOrEqualTo(24));
      expect(panel.bottom, lessThanOrEqualTo(420 - 8));
      expect(_key('workspace-editor-close').hitTestable(), findsOneWidget);
      final save = find.descendant(
        of: _editor,
        matching: find.widgetWithText(FilledButton, l.save),
      );
      expect(save.hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(_fields, findsNothing);
      expect(provider.timetables, hasLength(1));
      final saved = provider.activeTimetable.config;
      expect(saved.name, '窄窗口里的课表草稿');
      expect(saved.totalWeeks, 20);
      expect(saved.startDate, selectedDate);
      expect(saved.periodTimeSetId, evening.id);
      expect(
        storage.data.studentMode.timetables.single.config.name,
        saved.name,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'narrow desktop edit cancels its date picker and discards only the draft',
    (t) async {
      _viewport(t, const Size(760, 620));
      final provider = await _open(t, editing: true, scale: 1.5);
      final original = provider.activeTimetable.config;
      final element = t.element(_fields);
      final l = AppLocalizations.of(element);
      expect(WorkspaceEditorScope.maybeOf(element)?.floating, isTrue);
      await t.enterText(_field(0), 'Cancelled timetable draft');
      final date = _valueButton(l.semesterStartDate);
      await t.ensureVisible(date);
      await t.pumpAndSettle();
      await t.tap(date);
      await t.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsOneWidget);
      await t.ensureVisible(_key('sked-date-cancel'));
      await t.pumpAndSettle();
      await t.tap(_key('sked-date-cancel'));
      await t.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(t.element(_fields), same(element));
      expect(
        t.widget<TextField>(_field(0)).controller!.text,
        'Cancelled timetable draft',
      );
      await t.tap(
        find.descendant(
          of: _editor,
          matching: find.widgetWithText(TextButton, l.cancel),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(provider.activeTimetable.config, same(original));
      await t.tap(find.widgetWithText(FilledButton, l.discardChangesAndExit));
      await t.pumpAndSettle();
      expect(_fields, findsNothing);
      expect(provider.activeTimetable.config, same(original));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop timetable preserves its editor while switching between panel modes',
    (t) async {
      _viewport(t, const Size(2000, 1000));
      final provider = await _open(
        t,
        editing: true,
        panelDisplayMode: WorkspacePanelDisplayMode.sideBySide,
      );
      final element = t.element(_fields);
      expect(WorkspaceEditorScope.maybeOf(element)?.floating, isFalse);
      expect(_key('workspace-editor-barrier'), findsNothing);
      expect(_key('workspace-inspector-header'), findsNothing);
      final docked = t.getRect(_key('workspace-detail-surface'));
      await t.enterText(_field(0), 'Panel mode draft');
      final input = t.widget<TextField>(_field(0)).controller!;
      await provider.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      await t.pumpAndSettle();
      expect(WorkspaceEditorScope.maybeOf(element)?.floating, isTrue);
      expect(_key('workspace-editor-barrier'), findsOneWidget);
      expect(
        t.getSize(_key('workspace-detail-surface')).height,
        lessThan(docked.height),
      );
      expect(t.element(_fields), same(element));
      expect(t.widget<TextField>(_field(0)).controller, same(input));
      await provider.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.sideBySide,
      );
      await t.pumpAndSettle();
      expect(WorkspaceEditorScope.maybeOf(element)?.floating, isFalse);
      expect(_key('workspace-editor-barrier'), findsNothing);
      expect(t.element(_fields), same(element));
      expect(input.text, 'Panel mode draft');
      expect(_key('workspace-editor-close').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
