import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  for (final dragged in [false, true]) {
    testWidgets(
      'automatic editor docking preserves draft; manually dragged=$dragged',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(900, 900);
        addTearDown(t.view.reset);
        final p = await workspaceProvider(mode: AppMode.general);
        addTearDown(p.dispose);
        await p.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.automatic,
        );
        await t.pumpWidget(WorkspaceHarness(provider: p));
        await t.pumpAndSettle();
        await t.tap(key('general-add-event'));
        await t.pumpAndSettle();
        final editor = find.byType(GeneralEventEditorSheet);
        final element = t.element(editor);
        final input = find
            .descendant(of: editor, matching: find.byType(EditableText))
            .first;
        await t.enterText(input, 'Resize draft');
        await t.pumpAndSettle();
        expect(key('workspace-editor-barrier'), findsOneWidget);
        if (dragged) {
          await t.drag(key('workspace-editor-drag'), const Offset(-40, 20));
          await t.pumpAndSettle();
        }
        t.view.physicalSize = const Size(2000, 1000);
        await t.pumpAndSettle();
        expect(t.element(editor), same(element));
        expect(find.text('Resize draft'), findsOneWidget);
        expect(
          key('workspace-editor-barrier'),
          dragged ? findsOneWidget : findsNothing,
        );
        t.view.physicalSize = const Size(800, 700);
        await t.pumpAndSettle();
        expect(t.element(editor), same(element));
        expect(key('workspace-editor-close').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final mode in [AppMode.general, AppMode.student]) {
    testWidgets(
      'floating editor has one header, blocks background, drags without losing draft: $mode',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1440, 1000);
        addTearDown(t.view.reset);
        final p = await workspaceProvider(mode: mode);
        addTearDown(p.dispose);
        await t.pumpWidget(WorkspaceHarness(provider: p));
        await t.pumpAndSettle();
        final trigger = key(
          mode == AppMode.general ? 'general-add-event' : 'student-add-course',
        );
        await t.tap(trigger);
        await t.pumpAndSettle();
        final editor = find.byType(
          mode == AppMode.general ? GeneralEventEditorSheet : CourseEditorSheet,
        );
        expect(editor, findsOneWidget);
        expect(key('workspace-editor-barrier'), findsOneWidget);
        expect(key('workspace-editor-close'), findsOneWidget);
        expect(key('workspace-inspector-header'), findsNothing);
        final element = t.element(editor);
        final input = find
            .descendant(of: editor, matching: find.byType(EditableText))
            .first;
        await t.enterText(input, 'Floating draft');
        await t.pumpAndSettle();
        final handle = key('workspace-editor-drag');
        final before = t.getTopLeft(handle);
        await t.drag(handle, const Offset(-110, 40));
        await t.pumpAndSettle();
        expect(t.getTopLeft(handle).dx, lessThan(before.dx));
        expect(t.element(editor), same(element));
        expect(find.text('Floating draft'), findsOneWidget);
        await t.tapAt(const Offset(650, 900));
        await t.pumpAndSettle();
        expect(editor, findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await t.pumpAndSettle();
        expect(t.element(editor), same(element));
        expect(find.text('Floating draft'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
