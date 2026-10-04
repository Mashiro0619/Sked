import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
void main() {
  for (final mode in AppMode.values) {
    testWidgets(
      'outside-dismiss disabled still blocks navigation and keeps focus inside $mode editor',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1440, 1000);
        addTearDown(t.view.reset);
        final p = await workspaceProvider(mode: mode);
        addTearDown(p.dispose);
        if (mode == AppMode.general) {
          await p.updateGeneralDisplaySettings(
            closeEventPopupOnOutsideTap: false,
          );
        } else {
          await p.updateCloseCoursePopupOnOutsideTap(false);
        }
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
        final element = t.element(editor);
        final field = find
            .descendant(of: editor, matching: find.byType(EditableText))
            .first;
        await t.enterText(field, 'Modal draft');
        final targetMode = mode == AppMode.general ? 'student' : 'general';
        await t.tapAt(t.getCenter(key('workspace-resource-mode-$targetMode')));
        await t.pumpAndSettle();
        await t.tapAt(const Offset(620, 910));
        await t.pumpAndSettle();
        expect(p.activeMode, mode);
        expect(t.element(editor), same(element));
        expect(find.byType(AlertDialog), findsNothing);
        for (var i = 0; i < 24; i++) {
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
          final focus = FocusManager.instance.primaryFocus?.context;
          expect(focus, isNotNull);
          var inEditor = identical(focus, element);
          focus!.visitAncestorElements((ancestor) {
            if (identical(ancestor, element) ||
                ancestor.widget.key ==
                    const ValueKey('workspace-detail-resize')) {
              inEditor = true;
            }
            return !inEditor;
          });
          expect(
            inEditor,
            isTrue,
            reason:
                'Tab $i: ${FocusManager.instance.primaryFocus}\n${focus.widget}',
          );
        }
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await t.pumpAndSettle();
        expect(t.element(editor), same(element));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'docked editor keeps the assistant available; floating editor suspends it',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1920, 1100);
      addTearDown(t.view.reset);
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await p.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.sideBySide,
      );
      final prefs = DeveloperUiPreferences.memory(visible: true);
      addTearDown(prefs.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, developerUiPreferences: prefs),
      );
      await t.pumpAndSettle();
      await t.tap(key('general-add-event'));
      await t.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      final element = t.element(editor);
      await t.tap(key('assistant-toggle'));
      await t.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      expect(editor, findsOneWidget);
      expect(key('workspace-editor-barrier'), findsNothing);
      await t.enterText(key('assistant-draft'), 'Assistant draft');
      await p.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      await t.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsNothing);
      expect(key('workspace-editor-barrier'), findsOneWidget);
      expect(t.element(editor), same(element));
      await p.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.sideBySide,
      );
      await t.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      expect(
        t.widget<TextField>(key('assistant-draft')).controller!.text,
        'Assistant draft',
      );
      expect(t.element(editor), same(element));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop course reveals schedule directly and preserves text across field wrapping',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1440, 1000);
      addTearDown(t.view.reset);
      final p = await workspaceProvider(mode: AppMode.student);
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      await t.tap(key('student-add-course'));
      await t.pumpAndSettle();
      final editor = find.byType(CourseEditorSheet);
      expect(
        find.descendant(of: editor, matching: find.byType(ExpansionTile)),
        findsOneWidget,
      );
      expect(key('course-start-time-action').hitTestable(), findsOneWidget);
      expect(key('course-end-time-action').hitTestable(), findsOneWidget);
      await t.tap(find.descendant(of: editor, matching: find.text('More')));
      await t.pumpAndSettle();
      final teacher = find.descendant(
        of: find.descendant(
          of: editor,
          matching: find.byWidgetPredicate(
            (w) => w is WorkspaceEditorField && w.label == 'Teacher',
          ),
        ),
        matching: find.byType(TextField),
      );
      await t.ensureVisible(teacher);
      await t.pumpAndSettle();
      await t.enterText(teacher, 'Teacher draft');
      await t.pumpAndSettle();
      final element = t.element(teacher);
      final input = t.widget<TextField>(teacher).controller!;
      input.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
      await t.drag(key('workspace-detail-resize'), const Offset(-120, 0));
      await t.pumpAndSettle();
      expect(t.element(teacher), same(element));
      expect(input.text, 'Teacher draft');
      expect(input.selection.extentOffset, 7);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'inline desktop time validation does not invoke a detached expansion controller',
    (t) async {
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      t.view.physicalSize = const Size(1000, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: SizedBox(
              width: 480,
              child: WorkspaceEditorScope(
                enabled: true,
                floating: true,
                onHeight: (_) {},
                child: GeneralEventEditorSheet(
                  initialEvent: GeneralEvent(
                    id: 'invalid',
                    calendarId: 'work',
                    title: 'Invalid time',
                    startDateTimeIso: '2026-10-04T11:00:00.000',
                    endDateTimeIso: '2026-10-04T10:00:00.000',
                  ),
                  calendars: const [
                    GeneralSchedule(id: 'work', name: 'Work', events: []),
                  ],
                  activeCalendarId: 'work',
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop event exposes common options and keeps nested picker draft local',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1440, 1000);
      addTearDown(t.view.reset);
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      await t.tap(key('general-add-event'));
      await t.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      final element = t.element(editor);
      expect(key('event-recurrence-field').hitTestable(), findsOneWidget);
      expect(key('event-reminder-field').hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: editor, matching: find.byType(ExpansionTile)),
        findsOneWidget,
      );
      final pos = t.getTopLeft(key('workspace-editor-drag'));
      await t.tap(key('event-recurrence-field'));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.element(editor), same(element));
      expect(t.getTopLeft(key('workspace-editor-drag')), pos);
      await t.tap(find.descendant(of: editor, matching: find.text('More')));
      await t.pumpAndSettle();
      final notes = find.descendant(
        of: find.descendant(
          of: editor,
          matching: find.byWidgetPredicate(
            (w) => w is WorkspaceEditorField && w.label == 'Notes',
          ),
        ),
        matching: find.byType(TextField),
      );
      await t.ensureVisible(notes);
      await t.pumpAndSettle();
      expect(notes.hitTestable(), findsOneWidget);
      await t.enterText(notes, 'Expanded notes draft');
      await t.pumpAndSettle();
      expect(find.text('Expanded notes draft'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

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
