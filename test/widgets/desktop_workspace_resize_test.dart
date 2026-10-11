import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder key(String name) => find.byKey(ValueKey(name));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

Future<void> drag(WidgetTester tester, Offset start, Offset delta) async {
  final gesture = await tester.startGesture(
    start,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(delta / 2);
  await tester.pump();
  await gesture.moveBy(delta / 2);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'resource boundary resizes the same list and shares width with its drawer and next mount',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.reset);
      final provider = await workspaceProvider();
      final preferences = DesktopLayoutPreferences.memory();
      addTearDown(provider.dispose);
      addTearDown(preferences.dispose);
      Future<void> mount() async {
        await tester.pumpWidget(
          WorkspaceHarness(provider: provider, layoutPreferences: preferences),
        );
        await tester.pumpAndSettle();
      }

      await mount();
      final listFinder = find.byKey(
        const PageStorageKey('workspace-resource-list'),
      );
      final list = tester.element(listFinder);
      final gesture = await tester.startGesture(
        tester.getCenter(key('workspace-resource-resize')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(
        tester.getSize(key('workspace-resource-panel')).width,
        closeTo(384, .01),
      );
      expect(preferences.preferenceFor(DesktopLayoutRegion.resources), isNull);
      expect(tester.element(listFinder), same(list));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        preferences.preferenceFor(DesktopLayoutRegion.resources)?.width,
        closeTo(384, .01),
      );
      tester.view.physicalSize = const Size(1000, 1000);
      await tester.pumpAndSettle();
      expect(
        preferences.preferenceFor(DesktopLayoutRegion.resources)?.width,
        closeTo(384, .01),
      );
      await tester.tap(key('workspace-resource-collapse'));
      await tester.pumpAndSettle();
      expect(key('workspace-resource-scrim'), findsOneWidget);
      expect(tester.element(listFinder), same(list));
      expect(
        tester.getSize(key('workspace-resource-panel')).width,
        closeTo(384, .01),
      );
      await drag(
        tester,
        tester.getCenter(key('workspace-resource-resize')),
        const Offset(-40, 0),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1600, 1000);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(key('workspace-resource-panel')).width,
        closeTo(344, .01),
      );
      expect(tester.element(listFinder), same(list));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount();
      expect(
        tester.getSize(key('workspace-resource-panel')).width,
        closeTo(344, .01),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: desktop,
  );

  testWidgets(
    'permanent agenda boundary respects calendar budget and restores its preferred width',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 1000);
      addTearDown(tester.view.reset);
      final provider = await workspaceProvider();
      final preferences = DesktopLayoutPreferences.memory();
      final pane = WorkspacePaneController();
      addTearDown(provider.dispose);
      addTearDown(preferences.dispose);
      addTearDown(pane.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          layoutPreferences: preferences,
          home: Scaffold(
            body: WorkspaceFrame(
              controller: pane,
              resources: const SizedBox.expand(),
              supporting: const Text('Permanent agenda'),
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
      );
      await tester.pumpAndSettle();
      await drag(
        tester,
        tester.getCenter(key('workspace-supporting-resize')),
        const Offset(-140, 0),
      );
      expect(
        tester.getSize(key('workspace-supporting-pane')).width,
        closeTo(500, .01),
      );
      expect(
        preferences.preferenceFor(DesktopLayoutRegion.monthAgenda)?.width,
        closeTo(500, .01),
      );
      tester.view.physicalSize = const Size(1000, 1000);
      await tester.pumpAndSettle();
      expect(
        preferences.preferenceFor(DesktopLayoutRegion.monthAgenda)?.width,
        closeTo(500, .01),
      );
      expect(
        tester.getSize(key('workspace-canvas-viewport')).width,
        greaterThanOrEqualTo(600),
      );
      tester.view.physicalSize = const Size(1800, 1000);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(key('workspace-supporting-pane')).width,
        closeTo(500, .01),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: desktop,
  );
}
