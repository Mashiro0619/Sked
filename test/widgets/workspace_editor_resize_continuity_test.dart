import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Future<(TimetableProvider, DesktopLayoutPreferences)> _mount(
  WidgetTester t, {
  double dockedWidth = 440,
  bool rtl = false,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1440, 1000);
  addTearDown(t.view.reset);
  final previousAvailability = DesktopWindowBridge.instance.available;
  DesktopWindowBridge.instance.available = false;
  addTearDown(() {
    DesktopWindowBridge.instance.available = previousAvailability;
  });
  final provider = await workspaceProvider();
  addTearDown(provider.dispose);
  await provider.updateWorkspacePanelDisplayMode(
    WorkspacePanelDisplayMode.automatic,
  );
  final preferences = DesktopLayoutPreferences.memory(
    initialValues: {
      DesktopLayoutRegion.courseEditor: PreferredRegionSize(
        width: 530,
        height: 540,
        dockedWidth: dockedWidth,
      ),
    },
  );
  addTearDown(preferences.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      layoutPreferences: preferences,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    ),
  );
  await t.pumpAndSettle();
  await t.tap(_key('student-add-course'));
  await t.pumpAndSettle();
  expect(_key('workspace-editor-barrier'), findsNothing);
  expect(t.getSize(_key('workspace-detail-surface')).width, dockedWidth);
  return (provider, preferences);
}

void main() {
  for (final rtl in [false, true]) {
    testWidgets(
      'course editor continuously crosses automatic docking, reverses and releases: rtl=$rtl',
      (t) async {
        final (provider, preferences) = await _mount(t, rtl: rtl);
        final editor = find.byType(CourseEditorSheet);
        final element = t.element(editor);
        final input = find
            .descendant(of: editor, matching: find.byType(EditableText))
            .first;
        await t.enterText(input, 'Keep this resize draft');
        final editable = t.widget<EditableText>(input);
        editable.controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 8,
        );
        await t.pump();
        final focus = editable.focusNode;
        expect(focus.hasFocus, isTrue);
        final surface = _key('workspace-detail-surface');
        final initial = t.getRect(surface);
        final toolbar = t.getRect(_key('student-workspace-toolbar'));
        final handleElement = t.element(_key('workspace-detail-resize'));
        final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
        final navigator = frame.controller.navigatorKey.currentState;
        var expectedWidth = initial.width;
        var previousCanvas = t.getRect(_key('workspace-canvas-viewport'));
        final pointer = await t.startGesture(
          t.getCenter(_key('workspace-detail-resize')),
          kind: PointerDeviceKind.mouse,
        );
        try {
          for (final (steps, widening) in [(15, true), (8, false), (7, true)]) {
            for (var step = 0; step < steps; step++) {
              final widthChange = widening ? 16.0 : -16.0;
              await pointer.moveBy(Offset(widthChange * (rtl ? 1 : -1), 0));
              await t.pump();
              expectedWidth += widthChange;
              final rect = t.getRect(surface);
              expect(rect.width, closeTo(expectedWidth, .01));
              expect(
                rtl ? rect.left : rect.right,
                rtl ? initial.left : initial.right,
              );
              expect(
                t.element(_key('workspace-detail-resize')),
                same(handleElement),
              );
              expect(_key('workspace-editor-barrier'), findsNothing);
              final canvas = t.getRect(_key('workspace-canvas-viewport'));
              final change = canvas.width - previousCanvas.width;
              expect(
                widening ? -change : change,
                inInclusiveRange(-.01, 16.01),
              );
              expect(canvas.width, greaterThanOrEqualTo(600));
              previousCanvas = canvas;
              expect(t.getRect(_key('student-workspace-toolbar')), toolbar);
              expect(t.element(editor), same(element));
              expect(focus.hasFocus, isTrue);
              expect(
                editable.controller.selection,
                const TextSelection(baseOffset: 2, extentOffset: 8),
              );
            }
          }
        } finally {
          await pointer.up();
        }
        await t.pumpAndSettle();
        expect(expectedWidth, 664);
        expect(t.getSize(surface).width, closeTo(expectedWidth, .01));
        expect(_key('workspace-editor-barrier'), findsOneWidget);
        expect(frame.controller.navigatorKey.currentState, same(navigator));
        expect(t.element(editor), same(element));
        expect(editable.controller.text, 'Keep this resize draft');
        expect(editable.focusNode, same(focus));
        expect(focus.hasFocus, isTrue);
        expect(
          preferences.preferenceFor(DesktopLayoutRegion.courseEditor),
          const PreferredRegionSize(width: 664, height: 540, dockedWidth: 664),
        );

        await t.drag(
          _key('workspace-detail-resize'),
          Offset(rtl ? 40 : -40, 0),
          kind: PointerDeviceKind.mouse,
        );
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, closeTo(704, .01));
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.sideBySide,
        );
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, closeTo(664, .01));
        expect(_key('workspace-editor-barrier'), findsNothing);
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.overlay,
        );
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, closeTo(704, .01));
        expect(editable.controller.text, 'Keep this resize draft');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'keyboard crossing commits the current width and keeps the resize focus',
    (t) async {
      final (_, preferences) = await _mount(t, dockedWidth: 600);
      final handle = _key('workspace-detail-resize');
      final focus = Focus.of(
        t.element(
          find.descendant(of: handle, matching: find.byType(GestureDetector)),
        ),
      );
      focus.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(t.getSize(_key('workspace-detail-surface')).width, 624);
      expect(_key('workspace-editor-barrier'), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      expect(
        preferences.preferenceFor(DesktopLayoutRegion.courseEditor),
        const PreferredRegionSize(width: 624, height: 540, dockedWidth: 624),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(t.getSize(_key('workspace-detail-surface')).width, 648);
      expect(focus.hasFocus, isTrue);
      expect(
        preferences
            .preferenceFor(DesktopLayoutRegion.courseEditor)
            ?.dockedWidth,
        624,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
