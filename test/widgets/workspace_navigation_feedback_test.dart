import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/workspace_harness.dart';

typedef _Frame = ({ByteData bytes, int width, int height});

Future<_Frame> _frame(WidgetTester tester, GlobalKey boundary) async =>
    (await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
          .toImage(pixelRatio: 1);
      try {
        return (
          bytes: (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
          width: image.width,
          height: image.height,
        );
      } finally {
        image.dispose();
      }
    }))!;

int _changes(_Frame before, _Frame after, Rect rect) {
  expect(after.width, before.width);
  expect(after.height, before.height);
  var changes = 0;
  for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
      final index = (y * before.width + x) * 4;
      if (before.bytes.getUint32(index) != after.bytes.getUint32(index)) {
        changes++;
      }
    }
  }
  return changes;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'workspace navigation paints press, hover and focus feedback at $brightness',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 850);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final originalStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = originalStrategy,
        );
        final provider = await workspaceProvider(locale: 'zh');
        addTearDown(provider.dispose);
        final boundary = GlobalKey();
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: provider,
                locale: const Locale('zh'),
                brightness: brightness,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final destination = find.byKey(
            const ValueKey('adaptive-shell-general-destination'),
          );
          final bar = find.byKey(
            const ValueKey('adaptive-shell-navigation-bar'),
          );
          final rect = tester.getRect(bar);
          final idle = await _frame(tester, boundary);
          final touch = await tester.startGesture(
            tester.getCenter(destination),
            kind: ui.PointerDeviceKind.touch,
          );
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            _changes(idle, await _frame(tester, boundary), rect),
            greaterThan(0),
          );
          expect(provider.workspaceView.activeMode, AppMode.student);
          await touch.cancel();
          await tester.pumpAndSettle();
          expect(_changes(idle, await _frame(tester, boundary), rect), 0);

          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(destination));
          await tester.pumpAndSettle();
          expect(
            _changes(idle, await _frame(tester, boundary), rect),
            greaterThan(0),
          );
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          expect(_changes(idle, await _frame(tester, boundary), rect), 0);

          final focus = Focus.of(
            tester.element(
              find
                  .descendant(of: destination, matching: find.byType(Icon))
                  .first,
            ),
          );
          focus.requestFocus();
          await tester.pumpAndSettle();
          expect(
            _changes(idle, await _frame(tester, boundary), rect),
            greaterThan(0),
          );
          final node = tester.getSemantics(destination);
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
          node.owner!.performAction(node.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(provider.workspaceView.activeMode, AppMode.general);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
