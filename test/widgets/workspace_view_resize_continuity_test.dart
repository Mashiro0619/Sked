import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/workspace_frame.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

class _Fixture {
  _Fixture(double dockedWidth)
    : preferences = DesktopLayoutPreferences.memory(
        initialValues: {
          DesktopLayoutRegion.courseDetails: PreferredRegionSize(
            width: 530,
            height: 540,
            dockedWidth: dockedWidth,
          ),
        },
      );

  final pane = WorkspacePaneController();
  final mode = ValueNotifier(WorkspacePanelDisplayMode.automatic);
  final DesktopLayoutPreferences preferences;
  final text = TextEditingController();
  final focus = FocusNode();

  Future<void> open(WidgetTester t) async {
    unawaited(
      pane.show<void>(
        (_) => WorkspaceViewPanel(
          key: const ValueKey('test-view-content'),
          title: const Text('Course details'),
          child: Column(
            children: [
              TextField(controller: text, focusNode: focus),
              const SizedBox(
                height: 1000,
                child: Text('Details remain mounted'),
              ),
            ],
          ),
        ),
        presentation: WorkspacePanePresentation.view,
        layoutKey: DesktopLayoutRegion.courseDetails,
        dismissOnCanvasTap: false,
      ),
    );
    await t.pumpAndSettle();
  }

  void dispose() {
    pane.dispose();
    mode.dispose();
    preferences.dispose();
    text.dispose();
    focus.dispose();
  }
}

Future<_Fixture> _mount(
  WidgetTester t, {
  double dockedWidth = 360,
  bool rtl = false,
  double textScale = 1,
  Size viewport = const Size(1440, 1000),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = viewport;
  addTearDown(t.view.reset);
  final previousAvailability = DesktopWindowBridge.instance.available;
  DesktopWindowBridge.instance.available = false;
  addTearDown(() {
    DesktopWindowBridge.instance.available = previousAvailability;
  });
  final f = _Fixture(dockedWidth);
  addTearDown(f.dispose);
  await t.pumpWidget(
    ChangeNotifierProvider<DesktopLayoutPreferences>.value(
      value: f.preferences,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: Scaffold(
          body: ValueListenableBuilder<WorkspacePanelDisplayMode>(
            valueListenable: f.mode,
            builder: (context, mode, _) => WorkspaceFrame(
              controller: f.pane,
              panelDisplayMode: mode,
              resources: const SizedBox.expand(),
              canvas: const Column(
                children: [
                  SizedBox(height: 48),
                  Expanded(
                    child: WorkspaceCanvasBody(child: SizedBox.expand()),
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
  await f.open(t);
  return f;
}

Future<void> _unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void main() {
  testWidgets(
    'scaled view crosses docking and restores physical and logical widths',
    (t) async {
      final f = await _mount(
        t,
        textScale: 1.5,
        viewport: const Size(1800, 1000),
      );
      try {
        final surface = _key('workspace-detail-surface');
        final handle = _key('workspace-detail-resize');
        final handleElement = t.element(handle);
        final contentElement = t.element(_key('test-view-content'));
        final initial = t.getRect(surface);
        expect(initial.width, 540);
        expect(_key('workspace-floating-resize-top'), findsNothing);
        final pointer = await t.startGesture(
          t.getCenter(handle),
          kind: PointerDeviceKind.mouse,
        );
        try {
          for (var step = 1; step <= 4; step++) {
            // The first 24 dp move exceeds the 562 dp automatic dock budget.
            // Each move adds 16 logical dp at this text scale.
            await pointer.moveBy(const Offset(-24, 0));
            await t.pump();
            expect(t.getSize(surface).width, 540 + step * 24);
            expect(t.getRect(surface).right, initial.right);
            expect(t.element(handle), same(handleElement));
            expect(_key('workspace-floating-resize-top'), findsNothing);
          }
        } finally {
          await pointer.up();
        }
        await t.pumpAndSettle();
        expect(t.getSize(surface), const Size(636, 540));
        expect(_key('workspace-floating-resize-top'), findsOneWidget);
        expect(t.element(_key('test-view-content')), same(contentElement));
        expect(
          f.preferences.preferenceFor(DesktopLayoutRegion.courseDetails),
          const PreferredRegionSize(width: 636, height: 540, dockedWidth: 424),
        );
        await f.pane.close();
        await t.pumpAndSettle();
        await f.open(t);
        expect(t.getSize(surface), const Size(636, 540));
        expect(_key('workspace-floating-resize-top'), findsOneWidget);
      } finally {
        await _unmount(t);
      }
    },
    variant: _desktop,
  );

  for (final rtl in [false, true]) {
    testWidgets(
      'view resize crosses docking, reverses, retains content and reopens: rtl=$rtl',
      (t) async {
        final f = await _mount(t, rtl: rtl);
        try {
          final surface = _key('workspace-detail-surface');
          final handle = _key('workspace-detail-resize');
          final handleElement = t.element(handle);
          final contentElement = t.element(_key('test-view-content'));
          final navigator = f.pane.navigatorKey.currentState;
          await t.enterText(find.byType(TextField), 'Keep view state');
          f.text.selection = const TextSelection(
            baseOffset: 2,
            extentOffset: 8,
          );
          await t.pump();
          final initial = t.getRect(surface);
          var expectedWidth = initial.width;
          final pointer = await t.startGesture(
            t.getCenter(handle),
            kind: PointerDeviceKind.mouse,
          );
          try {
            for (final (steps, widening) in [
              (12, true),
              (4, false),
              (6, true),
            ]) {
              for (var step = 0; step < steps; step++) {
                final change = widening ? 24.0 : -24.0;
                await pointer.moveBy(Offset(change * (rtl ? 1 : -1), 0));
                await t.pump();
                expectedWidth += change;
                final rect = t.getRect(surface);
                expect(rect.width, closeTo(expectedWidth, .01));
                expect(
                  rtl ? rect.left : rect.right,
                  rtl ? initial.left : initial.right,
                );
                expect(t.element(handle), same(handleElement));
                expect(_key('workspace-floating-resize-top'), findsNothing);
                expect(
                  t.element(_key('test-view-content')),
                  same(contentElement),
                );
                expect(f.focus.hasFocus, isTrue);
                expect(
                  f.text.selection,
                  const TextSelection(baseOffset: 2, extentOffset: 8),
                );
              }
            }
          } finally {
            await pointer.up();
          }
          await t.pumpAndSettle();
          expect(expectedWidth, 696);
          expect(t.getSize(surface), const Size(696, 540));
          expect(_key('workspace-floating-resize-top'), findsOneWidget);
          expect(f.pane.navigatorKey.currentState, same(navigator));
          expect(t.element(_key('test-view-content')), same(contentElement));
          expect(f.focus.hasFocus, isTrue);
          expect(f.text.text, 'Keep view state');
          expect(
            f.preferences.preferenceFor(DesktopLayoutRegion.courseDetails),
            const PreferredRegionSize(
              width: 696,
              height: 540,
              dockedWidth: 696,
            ),
          );
          await f.pane.close();
          await t.pumpAndSettle();
          await f.open(t);
          expect(t.getSize(surface), const Size(696, 540));
        } finally {
          await _unmount(t);
        }
      },
      variant: _desktop,
    );

    testWidgets(
      'view keyboard crossing keeps resize focus and saves both widths: rtl=$rtl',
      (t) async {
        final f = await _mount(t, dockedWidth: 600, rtl: rtl);
        try {
          final handle = _key('workspace-detail-resize');
          final focus = Focus.of(
            t.element(
              find.descendant(
                of: handle,
                matching: find.byType(GestureDetector),
              ),
            ),
          );
          focus.requestFocus();
          await t.pump();
          final wider = rtl
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft;
          await t.sendKeyEvent(wider);
          await t.pumpAndSettle();
          expect(t.getSize(_key('workspace-detail-surface')).width, 624);
          expect(focus.hasFocus, isTrue);
          expect(
            f.preferences.preferenceFor(DesktopLayoutRegion.courseDetails),
            const PreferredRegionSize(
              width: 624,
              height: 540,
              dockedWidth: 624,
            ),
          );
          await t.sendKeyEvent(wider);
          await t.pumpAndSettle();
          expect(t.getSize(_key('workspace-detail-surface')).width, 648);
          expect(focus.hasFocus, isTrue);
          expect(
            f.preferences.preferenceFor(DesktopLayoutRegion.courseDetails),
            const PreferredRegionSize(
              width: 648,
              height: 540,
              dockedWidth: 624,
            ),
          );
        } finally {
          await _unmount(t);
        }
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'mode change retires the view resize without keeping a stale dock',
    (t) async {
      final f = await _mount(t);
      try {
        final surface = _key('workspace-detail-surface');
        final pointer = await t.startGesture(
          t.getCenter(_key('workspace-detail-resize')),
          kind: PointerDeviceKind.mouse,
        );
        await pointer.moveBy(const Offset(-48, 0));
        await t.pump();
        expect(t.getSize(surface).width, 408);
        f.mode.value = WorkspacePanelDisplayMode.overlay;
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, 530);
        await pointer.moveBy(const Offset(-48, 0));
        await pointer.up();
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, 530);
        expect(
          f.preferences
              .preferenceFor(DesktopLayoutRegion.courseDetails)
              ?.dockedWidth,
          408,
        );
        f.mode.value = WorkspacePanelDisplayMode.automatic;
        await t.pumpAndSettle();
        expect(t.getSize(surface).width, 408);
        expect(_key('workspace-floating-resize-top'), findsNothing);
      } finally {
        await _unmount(t);
      }
    },
    variant: _desktop,
  );

  testWidgets('replacing a view during a drag does not resize the new task', (
    t,
  ) async {
    final f = await _mount(t);
    try {
      final surface = _key('workspace-detail-surface');
      final pointer = await t.startGesture(
        t.getCenter(_key('workspace-detail-resize')),
        kind: PointerDeviceKind.mouse,
      );
      await pointer.moveBy(const Offset(-48, 0));
      await t.pump();
      expect(t.getSize(surface).width, 408);
      unawaited(
        f.pane.show<void>(
          (_) => const WorkspaceViewPanel(
            title: Text('Another task'),
            child: SizedBox(height: 300),
          ),
          presentation: WorkspacePanePresentation.view,
          layoutKey: DesktopLayoutRegion.eventDetails,
          dismissOnCanvasTap: false,
        ),
      );
      await t.pumpAndSettle();
      await pointer.moveBy(const Offset(-48, 0));
      await pointer.up();
      await t.pumpAndSettle();
      expect(t.getSize(surface).width, 360);
      expect(
        f.preferences.preferenceFor(DesktopLayoutRegion.eventDetails),
        isNull,
      );
      expect(
        f.preferences
            .preferenceFor(DesktopLayoutRegion.courseDetails)
            ?.dockedWidth,
        408,
      );
      await f.pane.close();
      await t.pumpAndSettle();
      expect(t.getSize(surface).width, 408);
      expect(_key('workspace-floating-resize-top'), findsNothing);
    } finally {
      await _unmount(t);
    }
  }, variant: _desktop);
}
