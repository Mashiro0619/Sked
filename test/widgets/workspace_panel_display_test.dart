import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

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

Future<void> _dragResize(WidgetTester t, Finder handle, double distance) async {
  final gesture = await t.startGesture(
    t.getCenter(handle),
    kind: PointerDeviceKind.mouse,
  );
  try {
    await gesture.moveBy(Offset(distance.sign * 24, 0));
    await t.pump();
    // Several frames are intentional: losing a resize handle's identity when
    // a second pane hides must not interrupt this pointer's drag sequence.
    for (var step = 0; step < 16; step++) {
      await gesture.moveBy(Offset(distance / 16, 0));
      await t.pump();
    }
  } finally {
    await gesture.up();
  }
  await t.pumpAndSettle();
}

void main() {
  for (final mode in [
    WorkspacePanelDisplayMode.sideBySide,
    WorkspacePanelDisplayMode.automatic,
  ]) {
    testWidgets(
      'editor resize keeps the toolbar fixed and the calendar continuous: $mode',
      (t) async {
        final f = await _mount(t);
        f.mode.value = mode;
        await t.pumpAndSettle();
        final toolbar = t.getRect(_key('test-toolbar'));
        final resources = t.getRect(_key('workspace-resource-width'));
        await t.tap(_key('test-edit-button'));
        await t.pumpAndSettle();
        final editor = t.state<_DraftEditorState>(find.byType(_DraftEditor));
        editor.draft.text = 'Keep the editor and its navigation';
        var canvas = t.getRect(_key('test-calendar'));
        final gesture = await t.startGesture(
          t.getCenter(_key('workspace-detail-resize')),
          kind: PointerDeviceKind.mouse,
        );
        try {
          for (var i = 0; i < 45; i++) {
            await gesture.moveBy(const Offset(-24, 0));
            await t.pump();
            expect(t.getRect(_key('test-toolbar')), toolbar);
            expect(t.getRect(_key('workspace-resource-width')), resources);
            expect(
              t.getRect(_key('workspace-detail-pane')).top,
              toolbar.bottom,
            );
            final next = t.getRect(_key('test-calendar'));
            expect(next.width, lessThanOrEqualTo(canvas.width + .01));
            expect(canvas.width - next.width, lessThanOrEqualTo(48.01));
            canvas = next;
          }
        } finally {
          await gesture.up();
        }
        await t.pumpAndSettle();
        expect(
          canvas.width,
          mode == WorkspacePanelDisplayMode.sideBySide ? 360 : 600,
        );
        expect(
          t.getSize(_key('workspace-detail-pane')).width,
          closeTo((1440 - 224 - 1) * .8, .01),
        );
        expect(
          t.state<_DraftEditorState>(find.byType(_DraftEditor)),
          same(editor),
        );
        expect(editor.draft.text, 'Keep the editor and its navigation');
        expect(f.pane.hasPaneTasks, isTrue);
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  testWidgets('keyboard resizing observes the same work-area maximum', (
    t,
  ) async {
    await _mount(t);
    await t.tap(_key('test-edit-button'));
    await t.pumpAndSettle();
    await _dragResize(t, _key('workspace-detail-resize'), -1800);
    const maximum = (1440 - 224 - 1) * .8;
    final mouse = find
        .descendant(
          of: _key('workspace-detail-resize'),
          matching: find.byType(MouseRegion),
        )
        .first;
    Focus.of(t.element(mouse)).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(
      t.getSize(_key('workspace-detail-pane')).width,
      closeTo(maximum, .01),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(
      t.getSize(_key('workspace-detail-pane')).width,
      closeTo(maximum - 24, .01),
    );
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  for (final assistant in [false, true]) {
    final paneKey = assistant
        ? 'workspace-assistant-pane'
        : 'workspace-detail-pane';
    final resizeKey = assistant
        ? 'workspace-assistant-resize'
        : 'workspace-detail-resize';
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final collapsed in [false, true]) {
        testWidgets(
          'panel resize reaches four fifths: assistant=$assistant scale=$scale collapsed=$collapsed',
          (t) async {
            final f = await _mount(
              t,
              width: 2560,
              scale: scale,
              collapsed: collapsed,
            );
            final resources = t.getRect(_key('workspace-resource-width'));
            final calendar = t.getRect(_key('test-calendar'));
            final contentWidth = 2560 - resources.width - 1;
            await t.tap(
              _key(assistant ? 'assistant-toggle' : 'test-edit-button'),
            );
            await t.pumpAndSettle();
            expect(
              t.getSize(_key(paneKey)).width,
              (assistant ? 400 : 360) * scale,
            );
            final draft = assistant
                ? f.assistant.draft
                : t.state<_DraftEditorState>(find.byType(_DraftEditor)).draft;
            draft.text = 'Retained resized draft';
            await _dragResize(t, _key(resizeKey), -2200);
            expect(
              t.getSize(_key(paneKey)).width,
              closeTo(contentWidth * .8, .01),
            );
            expect(t.getRect(_key('workspace-resource-width')), resources);
            expect(t.getRect(_key('test-calendar')), calendar);
            expect(draft.text, 'Retained resized draft');
            // Hitting the upper bound is not allowed to accumulate a dead zone.
            await _dragResize(t, _key(resizeKey), -100);
            expect(
              t.getSize(_key(paneKey)).width,
              closeTo(contentWidth * .8, .01),
            );
            await _dragResize(t, _key(resizeKey), 80);
            expect(
              t.getSize(_key(paneKey)).width,
              lessThan(contentWidth * .8 - 50),
            );
            expect(t.takeException(), isNull);
          },
          variant: _desktop,
        );
      }
    }

    testWidgets(
      'resized pane adapts its cap on window and sidebar changes: assistant=$assistant',
      (t) async {
        final f = await _mount(t, width: 1920);
        await t.tap(_key(assistant ? 'assistant-toggle' : 'test-edit-button'));
        await t.pumpAndSettle();
        await _dragResize(t, _key(resizeKey), -1800);
        const wideMaximum = (1920 - 224 - 1) * .8;
        expect(t.getSize(_key(paneKey)).width, closeTo(wideMaximum, .01));
        t.view.physicalSize = const Size(1280, 900);
        await t.pumpAndSettle();
        const narrowMaximum = (1280 - 224 - 1) * .8;
        expect(t.getSize(_key(paneKey)).width, closeTo(narrowMaximum, .01));
        t.view.physicalSize = const Size(1920, 900);
        await t.pumpAndSettle();
        expect(t.getSize(_key(paneKey)).width, closeTo(wideMaximum, .01));
        t.view.physicalSize = const Size(1280, 900);
        await t.pumpAndSettle();
        // Start from the constrained visible width, not the previous wider
        // window's stored preference, so shrinking responds immediately.
        await _dragResize(t, _key(resizeKey), 80);
        expect(t.getSize(_key(paneKey)).width, lessThan(narrowMaximum - 50));
        f.collapsed.value = true;
        await t.pumpAndSettle();
        await _dragResize(t, _key(resizeKey), -1500);
        expect(
          t.getSize(_key(paneKey)).width,
          closeTo((1280 - 56 - 1) * .8, .01),
        );
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );

    for (final mode in [
      WorkspacePanelDisplayMode.sideBySide,
      WorkspacePanelDisplayMode.automatic,
    ]) {
      testWidgets(
        'continuous resize survives docking and pane visibility changes: $mode assistant=$assistant',
        (t) async {
          final f = await _mount(t, width: 1920);
          f.mode.value = mode;
          await t.tap(_key('test-edit-button'));
          await t.pumpAndSettle();
          final editor = t.state<_DraftEditorState>(find.byType(_DraftEditor));
          editor.draft.text = 'Editor draft';
          f.assistant.setOpen(true);
          f.assistant.draft.text = 'AI draft';
          await t.pumpAndSettle();
          expect(find.byType(_DraftEditor), findsOneWidget);
          expect(find.byType(AssistantPreviewPane), findsOneWidget);
          await _dragResize(t, _key(resizeKey), -1800);
          expect(
            t.getSize(_key(paneKey)).width,
            closeTo((1920 - 224 - 1) * .8, .01),
          );
          expect(t.getSize(_key('workspace-resource-width')).width, 224);
          expect(
            assistant
                ? find.byType(AssistantPreviewPane)
                : find.byType(_DraftEditor),
            findsOneWidget,
          );
          expect(
            assistant
                ? find.byType(_DraftEditor)
                : find.byType(AssistantPreviewPane),
            findsNothing,
          );
          expect(f.pane.hasPaneTasks, isTrue);
          expect(f.assistant.isOpen, isTrue);
          expect(f.mode.value, mode);
          expect(editor.draft.text, 'Editor draft');
          expect(f.assistant.draft.text, 'AI draft');
          expect(t.takeException(), isNull);
        },
        variant: _desktop,
      );
    }
  }

  testWidgets(
    'month supporting agenda does not reduce the four-fifths resize budget',
    (t) async {
      final f = await _mount(t, width: 1920, supporting: true);
      final resources = t.getRect(_key('workspace-resource-width'));
      final calendar = t.getRect(_key('test-calendar'));
      final supporting = t.getRect(_key('test-supporting'));
      f.assistant.setOpen(true);
      await t.pumpAndSettle();
      await _dragResize(t, _key('workspace-assistant-resize'), -1800);
      expect(
        t.getSize(_key('workspace-assistant-pane')).width,
        closeTo((1920 - 224 - 1) * .8, .01),
      );
      expect(t.getRect(_key('workspace-resource-width')), resources);
      expect(t.getRect(_key('test-calendar')), calendar);
      expect(t.getRect(_key('test-supporting')), supporting);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

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
