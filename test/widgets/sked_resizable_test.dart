import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/sked_resizable.dart';

void main() {
  _extentResizeHandleTests();
  for (final rtl in [false, true]) {
    testWidgets(
      'eight physical resize edges, cursors, limits and reset: rtl=$rtl',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1100, 850);
        addTearDown(tester.view.reset);
        const initial = Rect.fromLTWH(200, 200, 400, 300);
        const bounds = Rect.fromLTRB(20, 60, 1080, 830);
        var rect = initial;
        SkedResizeEdge? selected;
        late StateSetter rebuild;
        var saves = 0;
        final draft = TextEditingController(text: 'Keep this selection');
        addTearDown(draft.dispose);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      rebuild = setState;
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: rect,
                            child: SkedResizableFrame(
                              onResize: (edge, delta) => setState(() {
                                selected = edge;
                                rect = resizeSkedFloatingRect(
                                  rect: rect,
                                  delta: delta,
                                  edge: edge,
                                  bounds: bounds,
                                  minimumSize: const Size(200, 120),
                                );
                              }),
                              onEnd: () => saves++,
                              onReset: () => setState(() => rect = initial),
                              child: ColoredBox(
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(30),
                                  child: TextField(controller: draft),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          final field = tester.element(find.byType(TextField));
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          for (final (edge, point, delta, cursor) in [
            (
              SkedResizeEdge.left,
              initial.centerLeft + const Offset(2, 0),
              const Offset(-40, 0),
              SystemMouseCursors.resizeLeftRight,
            ),
            (
              SkedResizeEdge.right,
              initial.centerRight - const Offset(2, 0),
              const Offset(40, 0),
              SystemMouseCursors.resizeLeftRight,
            ),
            (
              SkedResizeEdge.top,
              initial.topCenter + const Offset(0, 2),
              const Offset(0, -30),
              SystemMouseCursors.resizeUpDown,
            ),
            (
              SkedResizeEdge.bottom,
              initial.bottomCenter - const Offset(0, 2),
              const Offset(0, 30),
              SystemMouseCursors.resizeUpDown,
            ),
            (
              SkedResizeEdge.topLeft,
              initial.topLeft + const Offset(2, 2),
              const Offset(-40, -30),
              SystemMouseCursors.resizeUpLeftDownRight,
            ),
            (
              SkedResizeEdge.topRight,
              initial.topRight + const Offset(-2, 2),
              const Offset(40, -30),
              SystemMouseCursors.resizeUpRightDownLeft,
            ),
            (
              SkedResizeEdge.bottomLeft,
              initial.bottomLeft + const Offset(2, -2),
              const Offset(-40, 30),
              SystemMouseCursors.resizeUpRightDownLeft,
            ),
            (
              SkedResizeEdge.bottomRight,
              initial.bottomRight - const Offset(2, 2),
              const Offset(40, 30),
              SystemMouseCursors.resizeUpLeftDownRight,
            ),
          ]) {
            rebuild(() => rect = initial);
            await tester.pump();
            await mouse.moveTo(point);
            await tester.pump();
            expect(
              RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
              cursor,
              reason: edge.name,
            );
            final beforeSaves = saves;
            await mouse.down(point);
            await mouse.moveBy(delta / 2);
            await tester.pump();
            await mouse.moveBy(delta / 2);
            await tester.pump();
            expect(selected, edge);
            expect(saves, beforeSaves);
            expect(rect.left, initial.left + (edge.movesLeft ? delta.dx : 0));
            expect(
              rect.right,
              initial.right + (edge.movesRight ? delta.dx : 0),
            );
            expect(rect.top, initial.top + (edge.movesTop ? delta.dy : 0));
            expect(
              rect.bottom,
              initial.bottom + (edge.movesBottom ? delta.dy : 0),
            );
            await mouse.up();
            await tester.pump();
            expect(saves, beforeSaves + 1);
            expect(tester.element(find.byType(TextField)), same(field));
            expect(draft.text, 'Keep this selection');
          }
          rebuild(() => rect = initial);
          await tester.pump();
          await mouse.down(initial.centerRight - const Offset(2, 0));
          await mouse.moveBy(const Offset(900, 0));
          await tester.pump();
          expect(rect.right, bounds.right);
          await mouse.moveBy(const Offset(-20, 0));
          await tester.pump();
          expect(rect.right, bounds.right - 20);
          await mouse.up();
          await tester.pump();

          final edge = find.byKey(const ValueKey('floating-resize-right'));
          Focus.of(
            tester.element(
              find.descendant(of: edge, matching: find.byType(GestureDetector)),
            ),
          ).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.pump();
          expect(rect, initial);
          final beforeKeyboardSaves = saves;
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          expect(saves, beforeKeyboardSaves + 1);
          await tester.pump(const Duration(milliseconds: 300));
          expect(rect.width, initial.width + 24);
          rebuild(() => rect = initial);
          await tester.pump();
          final leftSemantics = tester.getSemantics(
            find
                .descendant(
                  of: find.byKey(const ValueKey('floating-resize-left')),
                  matching: find.byType(Semantics),
                )
                .first,
          );
          tester.binding.renderViews.single.owner!.semanticsOwner!
              .performAction(leftSemantics.id, SemanticsAction.increase);
          await tester.pump();
          expect(rect.width, initial.width + 24);
          expect(rect.right, initial.right);
          await mouse.removePointer();
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}

void _extentResizeHandleTests() {
  for (final (axis, reverse, direction, increase) in [
    (Axis.horizontal, false, TextDirection.ltr, const Offset(1, 0)),
    (Axis.horizontal, false, TextDirection.rtl, const Offset(-1, 0)),
    (Axis.horizontal, true, TextDirection.ltr, const Offset(-1, 0)),
    (Axis.vertical, false, TextDirection.ltr, const Offset(0, 1)),
    (Axis.vertical, true, TextDirection.rtl, const Offset(0, -1)),
  ]) {
    testWidgets(
      'divider accumulates same-frame moves and reverses at its limit: '
      '$axis reverse=$reverse $direction',
      (tester) async {
        var extent = 300.0;
        final committed = <double>[];
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => Center(
                    child: SizedBox(
                      width: axis == Axis.horizontal ? 9 : 120,
                      height: axis == Axis.horizontal ? 120 : 9,
                      child: SkedExtentResizeHandle(
                        extent: extent,
                        minExtent: 200,
                        maxExtent: 500,
                        axis: axis,
                        reverse: reverse,
                        onChanged: (value) => setState(() => extent = value),
                        onEnd: () => committed.add(extent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final handle = find.byType(SkedExtentResizeHandle);
        final original = tester.element(handle);
        final gesture = await tester.startGesture(
          tester.getCenter(handle),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(increase * 40);
        await tester.pump();
        expect(extent, 340);

        // Both events arrive before the parent can rebuild with the new size.
        await gesture.moveBy(increase * 40);
        await gesture.moveBy(increase * 40);
        expect(extent, 420);
        expect(committed, isEmpty);

        // Reversing must respond immediately, even without rendering the cap.
        await gesture.moveBy(increase * 200);
        expect(extent, 500);
        await gesture.moveBy(increase * -30);
        expect(extent, 470);
        await gesture.up();
        expect(committed, [470]);
        await tester.pumpAndSettle();
        expect(tester.element(handle), same(original));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'divider rebases on viewport caps and commits every keyboard or semantics step',
    (tester) async {
      var preferredExtent = 400.0;
      var maximum = 600.0;
      final committed = <double>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      late StateSetter rebuild;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Center(
                    child: SizedBox(
                      width: 9,
                      height: 120,
                      child: SkedExtentResizeHandle(
                        extent: preferredExtent.clamp(200, maximum),
                        minExtent: 200,
                        maxExtent: maximum,
                        focusNode: focus,
                        onChanged: (value) =>
                            setState(() => preferredExtent = value),
                        onEnd: () => committed.add(preferredExtent),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(SkedExtentResizeHandle)),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        expect(preferredExtent, 440);

        rebuild(() => maximum = 300);
        await tester.pump();
        expect(preferredExtent, 440);
        expect(committed, isEmpty);
        await gesture.moveBy(const Offset(-30, 0));
        await gesture.moveBy(const Offset(-30, 0));
        expect(preferredExtent, 240);
        await gesture.up();
        expect(committed, [240]);

        rebuild(() => maximum = 600);
        focus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        expect(preferredExtent, 288);
        expect(committed, [240, 264, 288]);
        await tester.pump();

        final node = tester.getSemantics(
          find
              .descendant(
                of: find.byType(SkedExtentResizeHandle),
                matching: find.byType(Semantics),
              )
              .first,
        );
        final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
        owner.performAction(node.id, SemanticsAction.increase);
        owner.performAction(node.id, SemanticsAction.increase);
        expect(preferredExtent, 336);
        expect(committed, [240, 264, 288, 312, 336]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
