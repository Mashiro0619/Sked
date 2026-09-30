import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/workspace_frame.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

class _Fixture {
  final pane = WorkspacePaneController();
  final mode = ValueNotifier(WorkspacePanelDisplayMode.overlay);
  final count = ValueNotifier(1);
  int taps = 0;
  int headerTaps = 0;
  int rowTaps = 0;
  void dispose() {
    pane.dispose();
    mode.dispose();
    count.dispose();
  }
}

Future<_Fixture> _pump(
  WidgetTester t, {
  double width = 1400,
  double scale = 1,
  bool rtl = false,
  EdgeInsets safePadding = EdgeInsets.zero,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 800);
  addTearDown(t.view.reset);
  final f = _Fixture();
  addTearDown(f.dispose);
  await t.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale), padding: safePadding),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: f.mode,
          builder: (context, mode, _) => WorkspaceFrame(
            controller: f.pane,
            panelDisplayMode: mode,
            resources: const SizedBox.expand(),
            canvas: Column(
              children: [
                const SizedBox(height: 48),
                Expanded(
                  child: WorkspaceCanvasBody(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => f.taps++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  unawaited(
    f.pane.show<void>(
      (_) => ValueListenableBuilder(
        valueListenable: f.count,
        builder: (context, count, _) => WorkspaceViewPanel(
          title: const Text('Panel heading'),
          headerAction: TextButton(
            key: const ValueKey('header-action'),
            onPressed: () => f.headerTaps++,
            child: const Text('Action'),
          ),
          toolbar: const Text('Actions remain visible'),
          child: Column(
            children: List.generate(
              count,
              (i) => SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => f.rowTaps++,
                  child: Text('Row $i'),
                ),
              ),
            ),
          ),
        ),
      ),
      presentation: WorkspacePanePresentation.view,
      dismissOnCanvasTap: false,
    ),
  );
  await t.pumpAndSettle();
  return f;
}

Future<void> _dragTitle(WidgetTester t, Offset delta) async {
  final gesture = await t.startGesture(
    t.getCenter(_key('workspace-view-drag-handle')),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(delta / 2);
  await t.pump();
  await gesture.moveBy(delta / 2);
  await t.pump();
  await gesture.up();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('only the title drags, leaving content and actions interactive', (
    t,
  ) async {
    final f = await _pump(t);
    final navigator = f.pane.navigatorKey.currentState;
    final original = t.getRect(_key('workspace-detail-surface'));
    await _dragTitle(t, const Offset(-180, 140));
    final moved = t.getRect(_key('workspace-detail-surface'));
    expect(moved.left, closeTo(original.left - 180, .1));
    expect(moved.top, closeTo(original.top + 140, .1));
    expect(moved.size, original.size);
    expect(f.pane.navigatorKey.currentState, same(navigator));
    await t.tap(_key('header-action'));
    await t.tap(find.text('Row 0'));
    await t.drag(_key('header-action'), const Offset(-60, 60));
    await t.drag(_key('workspace-view-body'), const Offset(-60, 60));
    await t.pumpAndSettle();
    expect(f.headerTaps, 1);
    expect(f.rowTaps, 1);
    expect(t.getRect(_key('workspace-detail-surface')), moved);
    await t.tapAt(Offset(original.center.dx, original.top + 10));
    await t.pumpAndSettle();
    expect(f.taps, 1);
    expect(f.pane.isOpen, isTrue);
    await t.tap(_key('workspace-inspector-close'));
    await t.pumpAndSettle();
    expect(f.pane.isOpen, isFalse);
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('drag bounds survive window resize and growing content', (
    t,
  ) async {
    final f = await _pump(t);
    final navigator = f.pane.navigatorKey.currentState;
    await _dragTitle(t, const Offset(-5000, 5000));
    final bounded = t.getRect(_key('workspace-detail-surface'));
    final canvas = t.getRect(_key('workspace-canvas'));
    expect(bounded.left, closeTo(canvas.left + 8, .1));
    expect(bounded.bottom, 792);
    await _dragTitle(t, const Offset(40, -40));
    final movedBack = t.getRect(_key('workspace-detail-surface'));
    expect(movedBack.left, closeTo(bounded.left + 40, .1));
    expect(movedBack.top, closeTo(bounded.top - 40, .1));
    t.view.physicalSize = const Size(800, 400);
    await t.pumpAndSettle();
    final resized = t.getRect(_key('workspace-detail-surface'));
    expect(resized.left, greaterThanOrEqualTo(8));
    expect(resized.right, lessThanOrEqualTo(792));
    expect(resized.top, greaterThanOrEqualTo(56));
    expect(resized.bottom, lessThanOrEqualTo(392));
    f.count.value = 40;
    await t.pumpAndSettle();
    final tall = t.getRect(_key('workspace-detail-surface'));
    expect(tall.top, 56);
    expect(tall.bottom, 392);
    final header = t.getRect(_key('workspace-view-header'));
    await t.drag(_key('workspace-view-body'), const Offset(0, -180));
    await t.pumpAndSettle();
    expect(t.getRect(_key('workspace-view-header')), header);
    expect(f.pane.navigatorKey.currentState, same(navigator));
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  testWidgets(
    'drag position belongs to each open task, not editors or docking',
    (t) async {
      final f = await _pump(t);
      await _dragTitle(t, const Offset(-180, 100));
      final moved = t.getRect(_key('workspace-detail-surface'));
      unawaited(
        f.pane.show<void>(
          (_) => const WorkspaceViewPanel(
            title: Text('Nested'),
            child: Text('Details'),
          ),
          presentation: WorkspacePanePresentation.view,
        ),
      );
      await t.pumpAndSettle();
      expect(t.getRect(_key('workspace-detail-surface')).right, 1392);
      await _dragTitle(t, const Offset(-50, 50));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(t.getRect(_key('workspace-detail-surface')), moved);
      unawaited(
        f.pane.show<void>((_) => const TextField(key: ValueKey('draft'))),
      );
      await t.pumpAndSettle();
      expect(_key('workspace-view-drag-handle'), findsNothing);
      await t.enterText(_key('draft'), 'Retained draft');
      f.mode.value = WorkspacePanelDisplayMode.sideBySide;
      await t.pumpAndSettle();
      f.mode.value = WorkspacePanelDisplayMode.overlay;
      await t.pumpAndSettle();
      expect(find.text('Retained draft'), findsOneWidget);
      await t.tap(_key('workspace-inspector-close'));
      await t.pumpAndSettle();
      expect(t.getRect(_key('workspace-detail-surface')), moved);
      f.mode.value = WorkspacePanelDisplayMode.sideBySide;
      await t.pumpAndSettle();
      expect(_key('workspace-view-drag-handle'), findsNothing);
      f.mode.value = WorkspacePanelDisplayMode.overlay;
      await t.pumpAndSettle();
      expect(t.getRect(_key('workspace-detail-surface')), moved);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      unawaited(
        f.pane.show<void>(
          (_) => const WorkspaceViewPanel(
            title: Text('Reopened'),
            child: Text('Fresh'),
          ),
          presentation: WorkspacePanePresentation.view,
        ),
      );
      await t.pumpAndSettle();
      final reopened = t.getRect(_key('workspace-detail-surface'));
      expect(reopened.right, 1392);
      expect(reopened.top, 56);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets('RTL drag follows the pointer and respects safe body bounds', (
    t,
  ) async {
    final f = await _pump(
      t,
      rtl: true,
      safePadding: const EdgeInsets.fromLTRB(20, 24, 30, 16),
    );
    final original = t.getRect(_key('workspace-detail-surface'));
    await _dragTitle(t, const Offset(150, 100));
    final moved = t.getRect(_key('workspace-detail-surface'));
    expect(moved.left, closeTo(original.left + 150, .1));
    expect(moved.top, closeTo(original.top + 100, .1));
    await _dragTitle(t, const Offset(-5000, -5000));
    final bounded = t.getRect(_key('workspace-detail-surface'));
    expect(bounded.left, 28);
    expect(bounded.top, 80);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(f.pane.isOpen, isFalse);
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('touch panels do not offer title dragging', (t) async {
    await _pump(t);
    expect(_key('workspace-view-drag-handle'), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('short overlay bounds its surface and resize hit region', (
    t,
  ) async {
    final f = await _pump(t);
    final panel = t.getRect(_key('workspace-detail-surface'));
    expect(panel.height, lessThan(250));
    expect(panel.top, 56);
    expect(panel.right, 1392);
    expect(t.getRect(_key('workspace-detail-resize')).height, panel.height);
    expect(_key('workspace-inspector-header'), findsNothing);
    expect(_key('workspace-inspector-close'), findsOneWidget);
    await t.tapAt(Offset(panel.center.dx, panel.bottom + 80));
    await t.pumpAndSettle();
    expect(f.taps, 1);
    expect(f.pane.isOpen, isTrue);
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  testWidgets(
    'width resize keeps a dragged panel anchored at its trailing edge',
    (t) async {
      await _pump(t);
      await _dragTitle(t, const Offset(-180, 100));
      final moved = t.getRect(_key('workspace-detail-surface'));
      await t.drag(_key('workspace-detail-resize'), const Offset(-100, 0));
      await t.pumpAndSettle();
      final wider = t.getRect(_key('workspace-detail-surface'));
      expect(wider.width, greaterThan(moved.width));
      expect(wider.right, closeTo(moved.right, .1));
      expect(wider.top, moved.top);
      await _dragTitle(t, const Offset(40, 40));
      final draggedAgain = t.getRect(_key('workspace-detail-surface'));
      expect(draggedAgain.right, closeTo(wider.right + 40, .1));
      expect(draggedAgain.top, closeTo(wider.top + 40, .1));
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets('content can grow and shrink without changing Navigator', (
    t,
  ) async {
    final f = await _pump(t);
    final navigator = f.pane.navigatorKey.currentState;
    final short = t.getSize(_key('workspace-detail-surface')).height;
    f.count.value = 40;
    await t.pumpAndSettle();
    final tall = t.getRect(_key('workspace-detail-surface'));
    expect(tall.height, greaterThan(short));
    expect(tall.bottom, 792);
    final header = t.getRect(_key('workspace-view-header'));
    await t.drag(_key('workspace-view-body'), const Offset(0, -250));
    await t.pumpAndSettle();
    expect(t.getRect(_key('workspace-view-header')), header);
    final scroll = t
        .state<ScrollableState>(
          find.descendant(
            of: _key('workspace-view-body'),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    final offset = scroll.pixels;
    expect(offset, greaterThan(0));
    await _dragTitle(t, const Offset(-100, 0));
    expect(scroll.pixels, offset);
    f.count.value = 1;
    await t.pumpAndSettle();
    expect(t.getSize(_key('workspace-detail-surface')).height, short);
    expect(f.pane.navigatorKey.currentState, same(navigator));
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  testWidgets('mode changes and nested editors retain task state', (t) async {
    final f = await _pump(t);
    final navigator = f.pane.navigatorKey.currentState;
    final short = t.getSize(_key('workspace-detail-surface')).height;
    for (final mode in [
      WorkspacePanelDisplayMode.sideBySide,
      WorkspacePanelDisplayMode.automatic,
    ]) {
      f.mode.value = mode;
      await t.pumpAndSettle();
      expect(t.getRect(_key('workspace-detail-surface')).bottom, 800);
      expect(f.pane.navigatorKey.currentState, same(navigator));
    }
    f.mode.value = WorkspacePanelDisplayMode.overlay;
    await t.pumpAndSettle();
    expect(t.getSize(_key('workspace-detail-surface')).height, short);
    unawaited(
      f.pane.show<void>((_) => const TextField(key: ValueKey('draft'))),
    );
    await t.pumpAndSettle();
    await t.enterText(_key('draft'), 'Retained draft');
    f.mode.value = WorkspacePanelDisplayMode.sideBySide;
    await t.pumpAndSettle();
    f.mode.value = WorkspacePanelDisplayMode.overlay;
    await t.pumpAndSettle();
    expect(find.text('Retained draft'), findsOneWidget);
    expect(t.getRect(_key('workspace-detail-surface')).bottom, 800);
    await t.tap(_key('workspace-inspector-close'));
    await t.pumpAndSettle();
    expect(t.getSize(_key('workspace-detail-surface')).height, short);
    expect(find.text('Row 0'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(f.pane.isOpen, isFalse);
    expect(t.takeException(), isNull);
  }, variant: _desktop);

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('narrow overlay retains canvas hit testing at scale $scale', (
      t,
    ) async {
      final f = await _pump(t, width: 360, scale: scale);
      final panel = t.getRect(_key('workspace-detail-surface'));
      expect(panel.left, greaterThanOrEqualTo(8));
      expect(panel.bottom, lessThan(790));
      await t.tapAt(Offset(180, panel.bottom + 10));
      expect(f.taps, 1);
      await _dragTitle(t, const Offset(1000, 5000));
      final moved = t.getRect(_key('workspace-detail-surface'));
      expect(moved.left, greaterThanOrEqualTo(8));
      expect(moved.right, lessThanOrEqualTo(352));
      expect(moved.bottom, lessThanOrEqualTo(792));
      expect(_key('workspace-inspector-close').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    }, variant: _desktop);
  }
}
