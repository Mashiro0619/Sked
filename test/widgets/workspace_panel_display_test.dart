import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/workspace_frame.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

class _DraftEditor extends StatefulWidget {
  const _DraftEditor(this.canLeave);
  final ValueNotifier<bool> canLeave;
  @override
  State<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<_DraftEditor> {
  final draft = TextEditingController();
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.canLeave,
    builder: (context, value, _) => PopScope<void>(
      canPop: value,
      child: Column(
        children: [
          const Text('Edit event'),
          TextField(
            key: const ValueKey('test-editor-draft'),
            controller: draft,
          ),
        ],
      ),
    ),
  );
}

class _FrameFixture {
  _FrameFixture({bool collapsed = false})
    : collapsed = ValueNotifier(collapsed);
  final pane = WorkspacePaneController();
  final assistant = AssistantPaneController();
  final mode = ValueNotifier(WorkspacePanelDisplayMode.overlay);
  final ValueNotifier<bool> collapsed;
  final canLeave = ValueNotifier(true);
  final calendarFocus = FocusNode();
  int resourceActions = 0;
  int calendarActions = 0;
  void dispose() {
    pane.dispose();
    assistant.dispose();
    mode.dispose();
    collapsed.dispose();
    canLeave.dispose();
    calendarFocus.dispose();
  }
}

Future<_FrameFixture> _mount(
  WidgetTester t, {
  double width = 1440,
  bool collapsed = false,
  bool supporting = false,
  double scale = 1,
  double minimumCanvas = 600,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetViewInsets);
  final f = _FrameFixture(collapsed: collapsed);
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    f.dispose();
  });
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ValueListenableBuilder<WorkspacePanelDisplayMode>(
          valueListenable: f.mode,
          builder: (context, mode, _) => ValueListenableBuilder<bool>(
            valueListenable: f.collapsed,
            builder: (context, collapsed, _) => WorkspaceFrame(
              controller: f.pane,
              assistantController: f.assistant,
              assistantPreview: true,
              panelDisplayMode: mode,
              resourcesCollapsed: collapsed,
              minimumCanvas: minimumCanvas,
              resources: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  key: const ValueKey('test-resource-action'),
                  onPressed: () => f.resourceActions++,
                  icon: const Icon(Icons.settings),
                ),
              ),
              supporting: supporting
                  ? const SizedBox.expand(
                      key: ValueKey('test-supporting'),
                      child: Text('Month agenda'),
                    )
                  : null,
              canvas: Column(
                children: [
                  SizedBox(
                    key: const ValueKey('test-toolbar'),
                    height: 72,
                    child: Row(
                      children: [
                        const AssistantPaneToggle(),
                        TextButton(
                          key: const ValueKey('test-edit-button'),
                          onPressed: () => unawaited(
                            f.pane.show<void>(
                              (_) => _DraftEditor(f.canLeave),
                              dismissOnCanvasTap: false,
                            ),
                          ),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          key: const ValueKey('test-note-button'),
                          onPressed: () => unawaited(
                            f.pane.show<void>(
                              (_) => const Text('Nested reminder'),
                            ),
                          ),
                          child: const Text('Reminder'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: WorkspaceCanvasBody(
                      child: Stack(
                        key: const ValueKey('test-calendar'),
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => f.calendarActions++,
                            child: const ColoredBox(color: Color(0xffeeeeee)),
                          ),
                          Positioned(
                            left: 16,
                            top: 16,
                            child: TextButton(
                              key: const ValueKey('test-calendar-action'),
                              onPressed: () => f.calendarActions++,
                              child: const Text('Calendar action'),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            top: 92,
                            width: 160,
                            child: TextField(
                              key: const ValueKey('test-calendar-field'),
                              focusNode: f.calendarFocus,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return f;
}

void main() {
  test(
    'automatic and side-by-side have distinct, scaled docking boundaries',
    () {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final collapsed in [false, true]) {
          final navigation = (collapsed ? 56 : 224) * scale;
          for (final mode in [
            WorkspacePanelDisplayMode.sideBySide,
            WorkspacePanelDisplayMode.automatic,
          ]) {
            final canvas =
                (mode == WorkspacePanelDisplayMode.sideBySide ? 360 : 600) *
                scale;
            final boundary = navigation + canvas + 360 * scale + 2;
            WorkspaceLayout resolve(double width) => WorkspaceLayout.resolve(
              width,
              scale,
              detailOpen: true,
              hasSupporting: false,
              pointer: true,
              resourcesCollapsed: collapsed,
              panelDisplayMode: mode,
            );
            expect(resolve(boundary).dockedDetail, isTrue);
            expect(resolve(boundary - .01).dockedDetail, isFalse);
            expect(resolve(boundary - .01).resources, isTrue);
          }
        }
      }
      final automatic = WorkspaceLayout.resolve(
        1280,
        1,
        minimumCanvas: 736,
        detailOpen: true,
        hasSupporting: false,
        panelDisplayMode: WorkspacePanelDisplayMode.automatic,
      );
      final beside = WorkspaceLayout.resolve(
        1280,
        1,
        minimumCanvas: 736,
        detailOpen: true,
        hasSupporting: false,
        panelDisplayMode: WorkspacePanelDisplayMode.sideBySide,
      );
      expect(automatic.dockedDetail, isFalse);
      expect(beside.dockedDetail, isTrue);
      expect(automatic.resourceWidth, beside.resourceWidth);
    },
  );

  test('hidden panes never reserve a dock and month supporting width is independent', () {
    for (final activeAssistant in [false, true]) {
      final p = WorkspaceLayout.resolve(
        1280,
        1,
        detailOpen: true,
        assistantOpen: true,
        assistantActive: activeAssistant,
        hasSupporting: true,
        panelDisplayMode: WorkspacePanelDisplayMode.sideBySide,
      );
      expect(p.assistantVisible, activeAssistant);
      expect(p.detailVisible, !activeAssistant);
      expect(p.dockedAssistant, activeAssistant);
      expect(p.dockedDetail, !activeAssistant);
      expect(p.supporting, isFalse);
    }
    final overlay = WorkspaceLayout.resolve(
      1920,
      1,
      detailOpen: true,
      hasSupporting: true,
      preferredDetailWidth: 600,
    );
    expect(overlay.supporting, isTrue);
    expect(overlay.supportingWidth, 360);
    expect(overlay.detailWidth, 600);
  });

  testWidgets(
    'outside tap reads the current foreground without requiring a rebuild',
    (t) async {
      final f = await _mount(t);
      f.mode.value = WorkspacePanelDisplayMode.sideBySide;
      await t.pumpAndSettle();
      unawaited(f.pane.show<void>((_) => const Text('Closable detail')));
      f.assistant.setOpen(true);
      await t.pumpAndSettle();
      expect(find.text('Closable detail'), findsOneWidget);
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      Future<void> outsideTap() async {
        final bar = t.getRect(_key('test-toolbar'));
        await t.tapAt(Offset(bar.right - 12, bar.center.dy));
        await t.pumpAndSettle();
      }

      await t.tap(find.text('Closable detail'));
      await outsideTap();
      expect(f.pane.hasPaneTasks, isFalse);
      unawaited(f.pane.show<void>((_) => const Text('Closable detail')));
      await t.pumpAndSettle();
      await t.tapAt(t.getRect(_key('workspace-assistant-pane')).center);
      await outsideTap();
      expect(f.pane.hasPaneTasks, isTrue);
      expect(f.assistant.isOpen, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'resizing a panel activates it before a two-pane layout stops fitting',
    (t) async {
      final f = await _mount(t);
      f.mode.value = WorkspacePanelDisplayMode.sideBySide;
      f.assistant.setOpen(true);
      await t.pumpAndSettle();
      await t.tap(_key('test-edit-button'));
      await t.pumpAndSettle();
      final editor = t.state<_DraftEditorState>(find.byType(_DraftEditor));
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      await t.drag(_key('workspace-assistant-resize'), const Offset(-200, 0));
      await t.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      expect(find.byType(_DraftEditor), findsNothing);
      expect(f.pane.hasPaneTasks, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(
        t.state<_DraftEditorState>(find.byType(_DraftEditor)),
        same(editor),
      );
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final collapsed in [false, true]) {
    for (final supporting in [false, true]) {
      testWidgets(
        'overlay retains sidebar and calendar rectangles: collapsed=$collapsed month=$supporting',
        (t) async {
          final f = await _mount(
            t,
            collapsed: collapsed,
            supporting: supporting,
          );
          final sidebar = t.getRect(_key('workspace-resource-width'));
          final calendar = t.getRect(_key('test-calendar'));
          final agenda = supporting ? t.getRect(_key('test-supporting')) : null;
          void expectStable() {
            expect(t.getRect(_key('workspace-resource-width')), sidebar);
            expect(t.getRect(_key('test-calendar')), calendar);
            if (supporting) expect(t.getRect(_key('test-supporting')), agenda);
          }

          await t.tap(_key('test-edit-button'));
          await t.pumpAndSettle();
          expectStable();
          expect(
            t.getRect(_key('workspace-detail-pane')).top,
            t.getRect(_key('test-toolbar')).bottom,
          );
          expect(t.getSize(_key('workspace-detail-pane')).width, 360);
          await t.drag(_key('workspace-detail-resize'), const Offset(-72, 0));
          await t.pumpAndSettle();
          expectStable();
          expect(
            t.getSize(_key('workspace-detail-pane')).width,
            greaterThan(360),
          );
          await t.tap(_key('assistant-toggle'));
          await t.pumpAndSettle();
          expectStable();
          expect(find.byType(_DraftEditor), findsNothing);
          expect(t.getSize(_key('workspace-assistant-pane')).width, 400);
          f.assistant.resize(600);
          await t.pumpAndSettle();
          expectStable();
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
          expect(find.byType(_DraftEditor), findsOneWidget);
          expectStable();
          await t.tap(_key('workspace-inspector-close'));
          await t.pumpAndSettle();
          expectStable();
          expect(t.takeException(), isNull);
        },
        variant: _desktop,
      );
    }
  }

  testWidgets(
    'nonmodal background is interactive, pane blanks do not click through, exit guards survive',
    (t) async {
      final f = await _mount(t);
      await t.tap(_key('test-edit-button'));
      await t.pumpAndSettle();
      f.canLeave.value = false;
      await t.pumpAndSettle();
      await t.tap(_key('test-resource-action'));
      await t.tap(_key('test-calendar-action'));
      await t.enterText(_key('test-calendar-field'), 'Calendar stays usable');
      await t.pump();
      expect(f.resourceActions, 1);
      expect(f.calendarActions, 1);
      expect(f.calendarFocus.hasFocus, isTrue);
      await t.tapAt(
        t.getRect(_key('workspace-detail-pane')).bottomCenter -
            const Offset(0, 24),
      );
      await t.pump();
      expect(f.calendarActions, 1);
      await t.tap(_key('workspace-inspector-close'));
      await t.pumpAndSettle();
      expect(f.pane.hasPaneTasks, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(f.pane.hasPaneTasks, isTrue);
      f.canLeave.value = true;
      await t.pumpAndSettle();
      expect(
        ModalRoute.of(t.element(_key('test-editor-draft')))!.popDisposition,
        RoutePopDisposition.pop,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(f.pane.hasPaneTasks, isFalse);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets('foreground switching preserves both drafts and nested routes', (
    t,
  ) async {
    final f = await _mount(t, width: 1920, minimumCanvas: 800);
    await t.tap(_key('test-edit-button'));
    await t.pumpAndSettle();
    final editor = t.state<_DraftEditorState>(find.byType(_DraftEditor));
    await t.enterText(_key('test-editor-draft'), 'Keep this event');
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    await t.enterText(_key('assistant-draft'), 'Keep this conversation');
    expect(find.byType(_DraftEditor), findsNothing);
    // A new task with the same null selection still becomes the foreground.
    await t.tap(_key('test-note-button'));
    await t.pumpAndSettle();
    expect(find.text('Nested reminder'), findsOneWidget);
    expect(find.byType(AssistantPreviewPane), findsNothing);
    expect(f.assistant.isOpen, isTrue);
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    expect(find.byType(AssistantPreviewPane), findsOneWidget);
    expect(f.assistant.isOpen, isTrue);
    await t.tap(_key('test-calendar-action'));
    await t.pump();
    expect(f.pane.hasPaneTasks, isTrue);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(f.assistant.isOpen, isFalse);
    expect(find.text('Nested reminder'), findsOneWidget);
    await f.pane.close();
    await t.pumpAndSettle();
    expect(t.state<_DraftEditorState>(find.byType(_DraftEditor)), same(editor));
    expect(editor.draft.text, 'Keep this event');
    await t.tap(_key('assistant-toggle'));
    await t.pumpAndSettle();
    for (final mode in [
      WorkspacePanelDisplayMode.sideBySide,
      WorkspacePanelDisplayMode.automatic,
    ]) {
      f.mode.value = mode;
      await t.pumpAndSettle();
      expect(find.byType(_DraftEditor), findsOneWidget);
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      expect(
        t.state<_DraftEditorState>(find.byType(_DraftEditor)),
        same(editor),
      );
      t.view.physicalSize = const Size(900, 900);
      await t.pumpAndSettle();
      expect(find.byType(_DraftEditor), findsNothing);
      expect(f.pane.focusScope.descendantsAreFocusable, isFalse);
      t.view.viewInsets = const FakeViewPadding(bottom: 250);
      await t.pumpAndSettle();
      expect(f.mode.value, mode);
      expect(editor.draft.text, 'Keep this event');
      expect(f.assistant.draft.text, 'Keep this conversation');
      t.view.resetViewInsets();
      t.view.physicalSize = const Size(1920, 900);
      await t.pumpAndSettle();
    }
    f.mode.value = WorkspacePanelDisplayMode.overlay;
    await t.pumpAndSettle();
    expect(find.byType(_DraftEditor), findsNothing);
    expect(f.assistant.draft.text, 'Keep this conversation');
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  testWidgets(
    'narrow overlay keeps toolbar available and excludes the covered calendar body',
    (t) async {
      final f = await _mount(t, width: 320);
      await t.tap(_key('test-edit-button'));
      await t.pumpAndSettle();
      expect(t.getSize(_key('workspace-detail-pane')).width, 320);
      expect(f.calendarFocus.canRequestFocus, isFalse);
      expect(_key('assistant-toggle').hitTestable(), findsOneWidget);
      await t.tap(_key('assistant-toggle'));
      await t.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      expect(t.getSize(_key('workspace-assistant-pane')).width, 320);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await f.pane.close();
      await t.pumpAndSettle();
      expect(f.calendarFocus.canRequestFocus, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );
}
