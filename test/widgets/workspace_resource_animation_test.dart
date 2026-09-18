import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/workspace_frame.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../support/workspace_harness.dart';

const _ids = [
  'workspace-resource-collapse',
  'workspace-resource-mode-student',
  'workspace-resource-mode-general',
  'workspace-resource-open',
  'workspace-resource-settings',
];
Finder _key(String id) => find.byKey(ValueKey(id));
Finder _icon(String id) =>
    find.descendant(of: _key(id), matching: find.byType(Icon));
Map<String, Rect> _iconRects(WidgetTester t) => {
  for (final id in _ids) id: t.getRect(_icon(id)),
};
void _expectAnchors(WidgetTester t, Map<String, Rect> before) {
  for (final id in _ids) {
    final current = t.getRect(_icon(id));
    expect(current.left, closeTo(before[id]!.left, .01), reason: id);
    expect(current.top, closeTo(before[id]!.top, .01), reason: id);
    expect(current.size, before[id]!.size, reason: id);
  }
}

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

class _Pane extends StatefulWidget {
  const _Pane({super.key, this.reduceMotion = false, this.rtl = false});
  final bool reduceMotion, rtl;
  @override
  State<_Pane> createState() => _PaneState();
}

class _PaneState extends State<_Pane> {
  final controller = WorkspacePaneController();
  final settingsFocus = FocusNode();
  int settingsOpened = 0;
  @override
  void dispose() {
    controller.dispose();
    settingsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TimetableProvider>();
    return SkedMotionPolicyScope(
      disableAnimations: false,
      reduceMotion: widget.reduceMotion,
      child: Directionality(
        textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: WorkspaceFrame(
            controller: controller,
            resourcesCollapsed: p.homeWorkspaceNavigationCollapsed,
            canvas: const SizedBox(key: ValueKey('test-canvas')),
            resources: WorkspaceResourcePanel(
              title: 'Resources',
              onOpenResources: () {},
              onSettings: () => settingsOpened++,
              settingsFocusNode: settingsFocus,
              headerActions: [
                IconButton(
                  key: const ValueKey('add-resource'),
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                ),
              ],
              children: [
                for (var i = 0; i < 30; i++)
                  ListTile(title: Text('Resource $i'), onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'resource icons stay fixed during both transitions at $platform/$scale',
        (t) async {
          _viewport(t, const Size(2200, 1000));
          final p = await workspaceProvider();
          addTearDown(p.dispose);
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              textScale: scale,
              home: const _Pane(),
            ),
          );
          await t.pumpAndSettle();
          final before = _iconRects(t);
          final fullWidth = t.getSize(_key('workspace-resource-width')).width;
          final compactWidth =
              (platform == TargetPlatform.windows ? 56 : 80) * scale;
          await t.tap(_key('workspace-resource-collapse'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 60));
          final intermediate = t
              .getSize(_key('workspace-resource-width'))
              .width;
          expect(intermediate, greaterThan(compactWidth));
          expect(intermediate, lessThan(fullWidth));
          _expectAnchors(t, before);
          await t.pumpAndSettle();
          expect(
            t.getSize(_key('workspace-resource-width')).width,
            closeTo(compactWidth, .01),
          );
          _expectAnchors(t, before);
          final semantics = t.ensureSemantics();
          expect(
            t.getSemantics(_key('workspace-resource-settings')).label,
            contains('Settings'),
          );
          expect(_key('add-resource').hitTestable(), findsNothing);
          semantics.dispose();
          await t.tap(_key('workspace-resource-collapse'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 60));
          final opening = t.getSize(_key('workspace-resource-width')).width;
          expect(opening, greaterThan(compactWidth));
          expect(opening, lessThan(fullWidth));
          _expectAnchors(t, before);
          await t.pumpAndSettle();
          _expectAnchors(t, before);
          expect(_key('add-resource').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets(
    'resource transition preserves focused settings and list scroll position',
    (t) async {
      _viewport(t, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final pane = GlobalKey<_PaneState>();
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: _Pane(key: pane),
        ),
      );
      await t.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('workspace-resource-list'));
      await t.drag(list, const Offset(0, -240));
      await t.pumpAndSettle();
      final scroll = t.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final offset = scroll.position.pixels;
      pane.currentState!.settingsFocus.requestFocus();
      await t.pump();
      expect(pane.currentState!.settingsFocus.hasFocus, isTrue);
      await p.updateHomeWorkspaceNavigationCollapsed(true);
      await t.pumpAndSettle();
      expect(pane.currentState!.settingsFocus.hasFocus, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(pane.currentState!.settingsOpened, 1);
      await p.updateHomeWorkspaceNavigationCollapsed(false);
      await t.pumpAndSettle();
      expect(scroll.position.pixels, closeTo(offset, .01));
      expect(pane.currentState!.settingsFocus.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'RTL anchors also stay fixed and reduced motion settles immediately',
    (t) async {
      _viewport(t, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const _Pane(rtl: true, reduceMotion: true),
        ),
      );
      await t.pumpAndSettle();
      final before = _iconRects(t);
      await p.updateHomeWorkspaceNavigationCollapsed(true);
      await t.pump();
      expect(t.getSize(_key('workspace-resource-width')).width, 56);
      _expectAnchors(t, before);
      await p.updateHomeWorkspaceNavigationCollapsed(false);
      await t.pump();
      expect(t.getSize(_key('workspace-resource-width')).width, 224);
      _expectAnchors(t, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'resizing mid-transition preserves the canvas budget without overflow',
    (t) async {
      _viewport(t, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p, home: const _Pane()));
      await t.pumpAndSettle();
      await p.updateHomeWorkspaceNavigationCollapsed(true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 40));
      t.view.physicalSize = const Size(700, 900);
      await t.pump();
      expect(t.getSize(_key('test-canvas')).width, greaterThanOrEqualTo(600));
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(640, 320);
      await t.pumpAndSettle();
      expect(t.getSize(_key('workspace-resource-width')).width, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
