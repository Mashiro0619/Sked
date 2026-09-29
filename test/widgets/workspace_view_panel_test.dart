import 'dart:async';

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
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
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
          toolbar: const Text('Actions remain visible'),
          child: Column(
            children: List.generate(
              count,
              (i) => SizedBox(height: 48, child: Text('Row $i')),
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

void main() {
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
      expect(t.takeException(), isNull);
    }, variant: _desktop);
  }
}
