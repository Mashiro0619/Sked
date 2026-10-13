import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_panel_header.dart';
import 'package:sked/widgets/sked_task_body.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

enum _EditorKind { timetable, course, event }

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _root(_EditorKind kind) => find.byType(switch (kind) {
  _EditorKind.timetable => TimetableInformationDialogSurface,
  _EditorKind.course => CourseEditorSheet,
  _EditorKind.event => GeneralEventEditorSheet,
});

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectFirstLabelInsideBody(
  WidgetTester tester,
  Finder root,
  Finder body,
) {
  final field = find
      .descendant(of: root, matching: find.byType(SkedEditorTextField))
      .first;
  final label = tester.widget<SkedEditorTextField>(field).label;
  final text = find.descendant(
    of: field,
    matching: find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == label,
    ),
  );
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: label.length),
  );
  expect(boxes, isNotEmpty);
  expect(paragraph.didExceedMaxLines, isFalse);
  var bounds = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    bounds = bounds.expandToInclude(box.toRect());
  }
  // InputDecorator transforms floating labels outside the input border. Test
  // the painted text bounds, since the field's layout bounds miss clipping.
  final painted = Rect.fromPoints(
    paragraph.localToGlobal(bounds.topLeft),
    paragraph.localToGlobal(bounds.bottomRight),
  );
  final viewport = tester.getRect(body);
  expect(painted.top, greaterThanOrEqualTo(viewport.top - .5));
  expect(painted.bottom, lessThanOrEqualTo(viewport.bottom + .5));
}

Future<TimetableProvider> _open(
  WidgetTester tester,
  _EditorKind kind, {
  required Size size,
  required double scale,
  required WorkspacePanelDisplayMode mode,
  String locale = 'zh',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    locale: locale,
    storage: WorkspaceMemoryStorage(
      mobileLayoutData(locale: locale).copyWith(
        activeMode: kind == _EditorKind.event
            ? AppMode.general
            : AppMode.student,
      ),
    ),
  );
  addTearDown(provider.dispose);
  await provider.updateWorkspacePanelDisplayMode(mode);
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: Locale(locale),
      textScale: scale,
      home: kind == _EditorKind.event ? null : const HomeScreen(),
    ),
  );
  await tester.pumpAndSettle();
  final l = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
  if (kind == _EditorKind.timetable) {
    final id = provider.activeTimetable.id;
    final row = _key('resource-timetable-$id');
    if (row.hitTestable().evaluate().isEmpty) {
      final picker = _key('student-timetable-picker-button').hitTestable();
      await _tap(
        tester,
        picker.evaluate().isNotEmpty
            ? picker
            : _key('workspace-resource-collapse'),
      );
    }
    if (row.hitTestable().evaluate().isNotEmpty) {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      try {
        await mouse.addPointer(location: tester.getCenter(row));
        await tester.pumpAndSettle();
        await _tap(tester, _key('resource-timetable-edit-$id'));
      } finally {
        await mouse.removePointer();
      }
    } else {
      await _tap(tester, find.byTooltip(l.editTimetable).hitTestable());
    }
  } else {
    final action = _key(
      kind == _EditorKind.course ? 'student-add-course' : 'general-add-event',
    ).hitTestable();
    final inline = find
        .byTooltip(kind == _EditorKind.course ? l.addCourse : l.addEvent)
        .hitTestable();
    if (kind == _EditorKind.event &&
        action.evaluate().isEmpty &&
        inline.evaluate().isEmpty &&
        find.byType(FloatingActionButton).evaluate().isEmpty) {
      final slot = _key('general-timeline-empty-slot-2026-09-23T00:00:00.000');
      expect(slot, findsOneWidget);
      final bounds = tester.getRect(slot);
      await tester.longPressAt(Offset(bounds.center.dx, bounds.top + 40));
      await tester.pumpAndSettle();
    } else {
      await _tap(
        tester,
        action.evaluate().isNotEmpty
            ? action
            : inline.evaluate().isNotEmpty
            ? inline
            : find.byType(FloatingActionButton).first,
      );
    }
  }
  expect(_root(kind), findsOneWidget);
  return provider;
}

void main() {
  for (final kind in _EditorKind.values) {
    testWidgets(
      '$kind landscape IME preserves a full touch save target, caret and draft across rotation',
      (tester) async {
        await _open(
          tester,
          kind,
          size: const Size(568, 320),
          scale: 1,
          mode: WorkspacePanelDisplayMode.overlay,
        );
        try {
          final root = _root(kind);
          final element = tester.element(root);
          final sheet = find.byType(BottomSheet).last;
          final input = find
              .descendant(of: root, matching: find.byType(TextField))
              .first;
          final controller = tester.widget<TextField>(input).controller!;
          final editableFinder = find.descendant(
            of: input,
            matching: find.byType(EditableText),
          );
          final originalEditable = tester.state<EditableTextState>(
            editableFinder,
          );
          final originalFocus = originalEditable.widget.focusNode;
          final body = find.descendant(
            of: root,
            matching: find.byKey(const PageStorageKey('app-sheet-body')),
          );
          final l = AppLocalizations.of(tester.element(root));
          final save = find.descendant(
            of: root,
            matching: find.widgetWithText(FilledButton, l.save),
          );
          expect(tester.widget<BottomSheet>(sheet).showDragHandle, isTrue);
          await tester.enterText(input, '横屏键盘中保留的草稿');
          tester.view.padding = const FakeViewPadding(top: 24);
          tester.view.viewInsets = const FakeViewPadding(bottom: 214);
          await tester.pumpAndSettle();

          expect(tester.widget<BottomSheet>(sheet).showDragHandle, isFalse);
          expect(tester.element(root), same(element));
          expect(tester.widget<TextField>(input).controller, same(controller));
          expect(controller.text, '横屏键盘中保留的草稿');
          expect(save.hitTestable(), findsOneWidget);
          final saveBounds = tester.getRect(save);
          expect(saveBounds.height, greaterThanOrEqualTo(48));
          expect(saveBounds.top, greaterThanOrEqualTo(24));
          expect(saveBounds.bottom, lessThanOrEqualTo(320 - 214));
          final viewport = tester.getRect(body);
          expect(viewport.height, greaterThan(0));
          expect(viewport.bottom, lessThanOrEqualTo(saveBounds.top));
          final editable = tester.state<EditableTextState>(editableFinder);
          expect(editable, same(originalEditable));
          expect(editable.widget.focusNode, same(originalFocus));
          expect(editable.widget.focusNode.hasFocus, isTrue);
          final render = editable.renderEditable;
          final caret = render.getLocalRectForCaret(
            controller.selection.extent,
          );
          final caretBounds = Rect.fromPoints(
            render.localToGlobal(caret.topLeft),
            render.localToGlobal(caret.bottomRight),
          );
          expect(caretBounds.top, greaterThanOrEqualTo(viewport.top - .5));
          expect(caretBounds.bottom, lessThanOrEqualTo(viewport.bottom + .5));

          tester.view.physicalSize = const Size(320, 568);
          tester.view.viewInsets = const FakeViewPadding();
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          await tester.pumpAndSettle();
          expect(tester.widget<BottomSheet>(sheet).showDragHandle, isTrue);
          expect(tester.element(root), same(element));
          expect(tester.widget<TextField>(input).controller, same(controller));
          expect(controller.text, '横屏键盘中保留的草稿');
          expect(
            tester.state<EditableTextState>(editableFinder),
            same(originalEditable),
          );
          expect(originalFocus.hasFocus, isTrue);
          expect(controller.selection.isCollapsed, isTrue);
          expect(controller.selection.extentOffset, controller.text.length);
          expect(save.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final kind in _EditorKind.values) {
    for (final profile in [
      (const Size(393, 852), 1.0, 0.0),
      (const Size(320, 568), 2.0, 220.0),
      (const Size(800, 393), 1.3, 0.0),
    ]) {
      testWidgets(
        '$kind touch ${profile.$1} scale=${profile.$2} uses shared editor slots',
        (tester) async {
          final provider = await _open(
            tester,
            kind,
            size: profile.$1,
            scale: profile.$2,
            mode: WorkspacePanelDisplayMode.overlay,
          );
          final originalData = provider.activeTimetable.config.name;
          final root = _root(kind);
          final host = find.descendant(
            of: root,
            matching: find.byType(AppSheetScaffold),
          );
          expect(host, findsOneWidget);
          expect(
            tester.widget<AppSheetScaffold>(host).editorActions,
            isNotNull,
          );
          expect(
            find.descendant(of: host, matching: find.byType(SkedTaskBody)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: root,
              matching: find.byType(SkedEditorTextField),
            ),
            findsWidgets,
          );
          final header = find.descendant(
            of: root,
            matching: _key('app-sheet-header'),
          );
          final body = find.descendant(
            of: root,
            matching: find.byKey(const PageStorageKey('app-sheet-body')),
          );
          final footer = find.descendant(
            of: root,
            matching: _key('app-sheet-actions'),
          );
          expect(header, findsOneWidget);
          expect(body, findsOneWidget);
          expect(footer, findsOneWidget);
          final title = find
              .descendant(of: header, matching: find.byType(RichText))
              .first;
          final style = tester.widget<RichText>(title).text.style!;
          expect(
            style.fontSize,
            Theme.of(tester.element(header)).textTheme.headlineSmall!.fontSize,
          );
          expect(style.fontWeight, FontWeight.w400);
          final input = find
              .descendant(of: root, matching: find.byType(TextField))
              .first;
          _expectFirstLabelInsideBody(tester, root, body);
          await tester.enterText(input, '统一外壳中的待保存草稿');
          final controller = tester.widget<TextField>(input).controller!;
          controller.selection = const TextSelection(
            baseOffset: 1,
            extentOffset: 5,
          );
          tester.view.viewInsets = FakeViewPadding(bottom: profile.$3);
          if (profile.$3 > 0) {
            tester.view.padding = const FakeViewPadding(top: 24);
          }
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(input).controller, same(controller));
          expect(controller.text, '统一外壳中的待保存草稿');
          expect(
            controller.selection,
            const TextSelection(baseOffset: 1, extentOffset: 5),
          );
          expect(tester.getSize(body).height, greaterThan(0));
          _expectFirstLabelInsideBody(tester, root, body);
          final actionsBefore = tester.getRect(footer);
          await tester.drag(body, const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(tester.getRect(footer), actionsBefore);
          final l = AppLocalizations.of(tester.element(root));
          for (final label in [l.cancel, l.save]) {
            final button = find.descendant(
              of: footer,
              matching: find.text(label),
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            expect(button.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(button).bottom,
              lessThanOrEqualTo(profile.$1.height - profile.$3),
            );
          }
          expect(provider.activeTimetable.config.name, originalData);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }

    for (final mode in [
      WorkspacePanelDisplayMode.overlay,
      WorkspacePanelDisplayMode.sideBySide,
    ]) {
      testWidgets(
        '$kind $mode retains the shared desktop shell and input identity',
        (tester) async {
          await _open(
            tester,
            kind,
            size: const Size(2000, 1000),
            scale: 1,
            mode: mode,
            locale: 'en',
          );
          final root = _root(kind);
          final host = find.descendant(
            of: root,
            matching: find.byType(AppSheetScaffold),
          );
          expect(
            tester.widget<AppSheetScaffold>(host).editorActions,
            isNotNull,
          );
          final pane = find.descendant(
            of: root,
            matching: find.byType(WorkspaceEditorScaffold),
          );
          expect(pane, findsOneWidget);
          expect(
            find.descendant(of: pane, matching: find.byType(SkedPanelHeader)),
            findsOneWidget,
          );
          expect(WorkspaceTaskScope.contains(tester.element(root)), isTrue);
          expect(find.byType(BottomSheet), findsNothing);
          final input = find
              .descendant(of: root, matching: find.byType(TextField))
              .first;
          await tester.enterText(input, 'A retained desktop draft');
          final controller = tester.widget<TextField>(input).controller!;
          final element = tester.element(root);
          tester.view.physicalSize = const Size(760, 620);
          await tester.pumpAndSettle();
          expect(tester.element(root), same(element));
          expect(tester.widget<TextField>(input).controller, same(controller));
          expect(controller.text, 'A retained desktop draft');
          expect(_key('workspace-editor-close').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
