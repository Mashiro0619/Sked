import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/workspace_context_snapshot.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/workspace_frame.dart';

class _Editor extends StatefulWidget {
  const _Editor();
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final draft = TextEditingController();
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(key: const ValueKey('draft'), controller: draft);
}

void main() {
  test('task budgets reserve the canvas at all sizes and font scales', () {
    for (final width in [
      360.0,
      599.0,
      600.0,
      800.0,
      839.0,
      840.0,
      1199.0,
      1200.0,
      1280.0,
      1440.0,
      1920.0,
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final canvas in [600.0, 800.0]) {
          for (final detail in [false, true]) {
            for (final assistant in [false, true]) {
              for (final collapsed in [false, true]) {
                final p = WorkbenchLayoutPolicy.resolve(
                  width,
                  scale,
                  detailOpen: detail,
                  hasSupporting: true,
                  assistantOpen: assistant,
                  minimumCanvas: canvas,
                  resourcesCollapsed: collapsed,
                );
                final side =
                    (p.resources ? p.resourceWidth + 1 : 0) +
                    (p.dockedDetail || p.supporting ? p.detailWidth + 1 : 0) +
                    (p.dockedAssistant ? p.assistantWidth + 1 : 0);
                if (side > 0) {
                  expect(width - side, greaterThanOrEqualTo(canvas * scale));
                }
                expect(p.supporting && (detail || assistant), isFalse);
              }
            }
          }
        }
      }
    }
  });
  test('portrait tablet settings split while the week canvas stays single', () {
    expect(WorkbenchLayoutPolicy.formCanSplit(800, 1), isTrue);
    expect(WorkbenchLayoutPolicy.formCanSplit(800, 1.3), isFalse);
    expect(
      WorkbenchLayoutPolicy.resolve(
        800,
        1,
        minimumCanvas: 800,
        detailOpen: false,
        hasSupporting: false,
      ).resources,
      isFalse,
    );
    final wide = WorkbenchLayoutPolicy.resolve(
      1920,
      1,
      minimumCanvas: 800,
      detailOpen: true,
      hasSupporting: false,
      assistantOpen: true,
    );
    expect(
      [wide.resources, wide.dockedDetail, wide.dockedAssistant],
      [true, true, true],
    );
    final medium = WorkbenchLayoutPolicy.resolve(
      1280,
      1,
      minimumCanvas: 800,
      detailOpen: true,
      hasSupporting: false,
      assistantOpen: true,
    );
    expect(medium.resources, isFalse);
    expect(medium.dockedDetail, isFalse);
    expect(medium.dockedAssistant, isTrue);
  });
  test(
    'assistant context is immutable and cannot expose a disabled workspace',
    () {
      final enabled = {AppMode.general};
      final snapshot = WorkspaceContextSnapshot(
        enabledWorkspaces: enabled,
        mode: AppMode.general,
        view: 'week',
        date: DateTime(2026, 9, 8),
      );
      enabled.add(AppMode.student);
      expect(snapshot.enabledWorkspaces, {AppMode.general});
      expect(() => snapshot.enabledWorkspaces.clear(), throwsUnsupportedError);
      expect(snapshot.withSelection('event').selectionId, 'event');
      expect(
        () => WorkspaceContextSnapshot(
          enabledWorkspaces: {AppMode.general},
          mode: AppMode.student,
          view: 'week',
        ),
        throwsArgumentError,
      );
    },
  );
  testWidgets(
    'independent editor and assistant survive rotation, keyboard and overlay focus',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final pane = WorkspacePaneController();
      final assistant = AssistantPaneController();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkspaceFrame(
              controller: pane,
              assistantController: assistant,
              assistantPreview: true,
              minimumCanvas: 800,
              contextSnapshot: WorkspaceContextSnapshot(
                enabledWorkspaces: {AppMode.general},
                mode: AppMode.general,
                view: 'week',
              ),
              resources: const Text('Resources'),
              canvas: Column(
                children: [
                  const AssistantPaneToggle(),
                  TextButton(
                    onPressed: () => pane.show<void>(
                      (_) => const _Editor(),
                      selectionId: 'event',
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final original = tester.state<_EditorState>(find.byType(_Editor));
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'Retained event',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assistant-draft')),
        'Retained conversation',
      );
      expect(find.byType(_Editor), findsOneWidget);
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      expect(find.byType(_Editor), findsNothing);
      expect(original.draft.text, 'Retained event');
      expect(pane.focusScope.descendantsAreFocusable, isFalse);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(assistant.isOpen, isFalse);
      expect(find.byType(_Editor), findsOneWidget);
      expect(tester.state<_EditorState>(find.byType(_Editor)), same(original));
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'Still editable',
      );
      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();
      assistant.setOpen(true);
      await tester.pumpAndSettle();
      expect(assistant.draft.text, 'Retained conversation');
      assistant.resize(450);
      await tester.pumpAndSettle();
      expect(assistant.width, 450);
      final handles = find.bySemanticsLabel('Resize panel');
      expect(tester.getSize(handles.first), const Size(48, 48));
      final beforeResize = tester.getSize(find.byType(_Editor)).width;
      await tester.drag(handles.first, const Offset(-36, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(_Editor)).width,
        greaterThan(beforeResize),
      );
      final mouse = find
          .descendant(of: handles.first, matching: find.byType(MouseRegion))
          .first;
      Focus.of(tester.element(mouse)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      await pane.close();
      await tester.pumpAndSettle();
      expect(find.byType(_Editor), findsNothing);
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      pane.dispose();
      assistant.dispose();
    },
  );
  testWidgets('production frame has no AI placeholder or entry', (
    tester,
  ) async {
    final pane = WorkspacePaneController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceFrame(
            controller: pane,
            assistantPreview: false,
            resources: const SizedBox(),
            canvas: const AssistantPaneToggle(),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('assistant-toggle')), findsNothing);
    expect(find.byType(AssistantPreviewPane), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    pane.dispose();
  });
}
