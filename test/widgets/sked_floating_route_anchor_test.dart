import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/sked_floating_anchor.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_picker_task.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

enum _Panel { form, picker }

Finder _key(String value) => find.byKey(ValueKey(value));

Future<ValueNotifier<Offset?>> _mountRouteTrigger(
  WidgetTester tester, {
  required _Panel panel,
  required bool removeOnOpen,
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = platform == TargetPlatform.android
      ? const Size(680, 800)
      : const Size(1200, 800);
  addTearDown(tester.view.reset);
  final position = ValueNotifier<Offset?>(const Offset(24, 180));
  addTearDown(position.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        // The Navigator's overlay has a nonzero origin. A route must not use
        // window coordinates as local offsets, even on its first frame.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(180, 80, 60, 40),
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (ownerContext) => Stack(
            children: [
              ValueListenableBuilder<Offset?>(
                valueListenable: position,
                builder: (context, offset, child) => offset != null
                    ? Positioned(
                        left: offset.dx,
                        top: offset.dy,
                        width: 100,
                        height: 32,
                        child: Builder(
                          key: const ValueKey('anchor-trigger'),
                          builder: (anchorContext) => TextButton(
                            onPressed: () {
                              const body = SkedTaskDialog(
                                title: Text('Floating content'),
                                content: SizedBox(height: 90),
                              );
                              if (panel == _Panel.form) {
                                unawaited(
                                  showExpressiveDialog<void>(
                                    context: ownerContext,
                                    desktopFloating: SkedDesktopFloatingDialog(
                                      anchorContext: anchorContext,
                                      preferredWidth: 240,
                                      maxWidth: 240,
                                    ),
                                    builder: (_) => body,
                                  ),
                                );
                              } else {
                                unawaited(
                                  showSkedPickerTask<void>(
                                    context: ownerContext,
                                    routeName: 'anchor-picker',
                                    preferredSize: (_) => const Size(240, 180),
                                    anchorContext: anchorContext,
                                    placement: SkedFloatingPlacement.below,
                                    compactPresentation:
                                        SkedPickerCompactPresentation.anchored,
                                    surfaceKey: const ValueKey(
                                      'picker-surface',
                                    ),
                                    builder: (_, finish, _) =>
                                        SkedTaskDialogScope(
                                          onClose: () => finish(null),
                                          child: body,
                                        ),
                                  ),
                                );
                              }
                              if (removeOnOpen) position.value = null;
                            },
                            child: const Text('Open'),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return position;
}

void main() {
  for (final panel in _Panel.values) {
    for (final removeOnOpen in [false, true]) {
      testWidgets('$panel anchors on its first frame in an offset overlay; '
          'trigger removed=$removeOnOpen', (tester) async {
        final position = await _mountRouteTrigger(
          tester,
          panel: panel,
          removeOnOpen: removeOnOpen,
        );
        final trigger = tester.getRect(_key('anchor-trigger'));
        await tester.tap(find.text('Open'));
        await tester.pump();
        final surface = _key(
          panel == _Panel.form ? 'floating-form-surface' : 'picker-surface',
        );
        final initial = tester.getRect(surface);
        expect(initial.left, closeTo(trigger.left, 0.01));
        expect(initial.top, closeTo(trigger.bottom + 6, 0.01));
        expect(initial.width, 240);
        await tester.pumpAndSettle();
        expect(tester.getRect(surface), initial);
        if (removeOnOpen) {
          expect(_key('anchor-trigger'), findsNothing);
          tester.view.physicalSize = const Size(1100, 760);
          await tester.pumpAndSettle();
          expect(tester.getRect(surface).topLeft, initial.topLeft);
          await tester.drag(
            _key(
              panel == _Panel.form
                  ? 'floating-form-drag-handle'
                  : 'sked-picker-drag-handle',
            ),
            const Offset(60, 30),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getRect(surface).topLeft,
            initial.topLeft + const Offset(60, 30),
          );
        } else {
          // A live trigger can scroll completely outside its overlay.
          // Keep the panel's last position rather than treating the offscreen
          // rectangle as an anchor and snapping back to the window center.
          position.value = const Offset(2000, 180);
          tester.view.physicalSize = const Size(1100, 760);
          await tester.pumpAndSettle();
          expect(tester.getRect(surface).topLeft, initial.topLeft);
        }
        Navigator.of(tester.element(surface)).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('compact anchored pickers retain a removed trigger position', (
    tester,
  ) async {
    await _mountRouteTrigger(
      tester,
      panel: _Panel.picker,
      removeOnOpen: true,
      platform: TargetPlatform.android,
    );
    final trigger = tester.getRect(_key('anchor-trigger'));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final surface = _key('picker-surface');
    final rect = tester.getRect(surface);
    expect(rect.left, closeTo(trigger.left, 0.01));
    expect(rect.top, closeTo(trigger.bottom + 6, 0.01));
    expect(find.byType(SkedFloatingSurface), findsNothing);
    Navigator.of(tester.element(surface)).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('forms resolve anchors inside the selected nested Navigator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Padding(
          padding: const EdgeInsets.only(left: 150, top: 60),
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 80),
                    child: Builder(
                      key: const ValueKey('nested-trigger'),
                      builder: (context) => TextButton(
                        onPressed: () => showExpressiveDialog<void>(
                          context: context,
                          useRootNavigator: false,
                          desktopFloating: SkedDesktopFloatingDialog(
                            anchorContext: context,
                            preferredWidth: 240,
                            maxWidth: 240,
                          ),
                          builder: (_) => const SkedTaskDialog(
                            title: Text('Nested form'),
                            content: SizedBox(height: 90),
                          ),
                        ),
                        child: const Text('Open nested'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final trigger = tester.getRect(_key('nested-trigger'));
    await tester.tap(find.text('Open nested'));
    await tester.pumpAndSettle();
    final surface = _key('floating-form-surface');
    final rect = tester.getRect(surface);
    expect(rect.left, closeTo(trigger.left, 0.01));
    expect(rect.top, closeTo(trigger.bottom + 6, 0.01));
    Navigator.of(tester.element(surface)).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('captured anchors follow layout and survive trigger removal', (
    tester,
  ) async {
    final position = ValueNotifier<Offset?>(const Offset(40, 80));
    addTearDown(position.dispose);
    final coordinateKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Padding(
          padding: const EdgeInsets.only(left: 70, top: 50),
          child: Transform.scale(
            scale: 0.8,
            alignment: Alignment.topLeft,
            child: SizedBox.expand(
              key: coordinateKey,
              child: ValueListenableBuilder<Offset?>(
                valueListenable: position,
                builder: (_, value, _) => Stack(
                  children: [
                    if (value != null)
                      Positioned(
                        left: value.dx,
                        top: value.dy,
                        width: 100,
                        height: 32,
                        child: const SizedBox(key: ValueKey('moving-trigger')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final anchor = SkedFloatingAnchor.capture(
      tester.element(_key('moving-trigger')),
    );
    final space =
        coordinateKey.currentContext!.findRenderObject()! as RenderBox;
    const initial = Rect.fromLTWH(102, 114, 80, 25.6);
    expect(anchor.initialRect, initial);
    expect(anchor.globalRect, initial);
    final snapshot = SkedFloatingAnchor.fromRect(anchor.initialRect);
    final first = anchor.rectIn(space)!;
    expect(first.left, closeTo(40, 0.01));
    expect(first.top, closeTo(80, 0.01));
    expect(first.width, closeTo(100, 0.01));
    expect(first.height, closeTo(32, 0.01));
    position.value = const Offset(90, 110);
    await tester.pump();
    final moved = anchor.globalRect;
    expect(moved!.topLeft, const Offset(142, 138));
    position.value = null;
    await tester.pump();
    expect(anchor.globalRect, moved);
    expect(anchor.initialRect, initial);
    expect(snapshot.globalRect, initial);
    final retained = anchor.rectIn(space)!;
    expect(retained.left, closeTo(90, 0.01));
    expect(retained.top, closeTo(110, 0.01));
    expect(tester.takeException(), isNull);
  });
}
