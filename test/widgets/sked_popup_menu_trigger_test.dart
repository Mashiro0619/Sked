import 'dart:ui' show PointerDeviceKind, SemanticsAction, Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

void main() {
  testWidgets(
    'explicit child trigger style resolves hover and focus once and keeps menu actions',
    (tester) async {
      final focus = FocusNode();
      final enabled = ValueNotifier(true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        focus.dispose();
        enabled.dispose();
      });
      const hover = Color(0x10000000);
      const shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      );
      final choices = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (context, value, _) => SkedPopupMenuButton<int>(
                  key: const ValueKey('styled-trigger'),
                  enabled: value,
                  focusNode: focus,
                  tooltip: 'Choose',
                  triggerStyle: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(96, 48)),
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    shape: const WidgetStatePropertyAll(shape),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.transparent
                          : states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused)
                          ? hover
                          : Colors.transparent,
                    ),
                    side: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.focused)
                          ? const BorderSide(color: Colors.blue)
                          : BorderSide.none,
                    ),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  onSelected: choices.add,
                  itemBuilder: (_) => const [
                    SkedPopupMenuItem(value: 1, child: Text('First choice')),
                  ],
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        ),
      );
      final trigger = find.descendant(
        of: find.byKey(const ValueKey('styled-trigger')),
        matching: find.byType(TextButton),
      );
      expect(trigger, findsOneWidget);
      expect(tester.getSize(trigger).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(trigger)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      List<SemanticsNode> buttons() {
        final result = <SemanticsNode>[];
        void visit(SemanticsNode node) {
          if (node.getSemanticsData().flagsCollection.isButton) {
            result.add(node);
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(tester.getSemantics(trigger));
        return result;
      }

      final closed = buttons();
      expect(closed, hasLength(1));
      final closedData = closed.single.getSemanticsData();
      expect(closedData.flagsCollection.isEnabled, Tristate.isTrue);
      expect(closedData.flagsCollection.isExpanded, Tristate.isFalse);
      expect(closedData.label, 'Choose');
      expect(closedData.hasAction(SemanticsAction.tap), isTrue);
      final painted = find
          .descendant(of: trigger, matching: find.byType(Material))
          .first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(trigger));
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(painted).color, hover);
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(painted).color, hover);
      expect(
        tester.widget<Material>(painted).shape,
        shape.copyWith(side: const BorderSide(color: Colors.blue)),
      );
      closed.single.owner!.performAction(closed.single.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      final choice = tester.getSemantics(find.text('First choice'));
      expect(choice.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      choice.owner!.performAction(choice.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(choices, [1]);
      expect(buttons(), hasLength(1));
      expect(
        buttons().single.getSemanticsData().flagsCollection.isExpanded,
        Tristate.isFalse,
      );
      final oldOpen = tester.widget<TextButton>(trigger).onPressed!;
      enabled.value = false;
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(trigger).onPressed, isNull);
      final disabled = buttons();
      expect(disabled, hasLength(1));
      final disabledData = disabled.single.getSemanticsData();
      expect(disabledData.flagsCollection.isEnabled, Tristate.isFalse);
      expect(disabledData.flagsCollection.isExpanded, Tristate.isFalse);
      expect(disabledData.label, 'Choose');
      expect(disabledData.hasAction(SemanticsAction.tap), isFalse);
      oldOpen();
      await tester.pumpAndSettle();
      expect(find.text('First choice'), findsNothing);
      expect(choices, [1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ordinary child triggers keep their existing interaction surface',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkedPopupMenuButton<int>(
              key: const ValueKey('ordinary-trigger'),
              itemBuilder: (_) => const [
                SkedPopupMenuItem(value: 1, child: Text('Choice')),
              ],
              child: const Text('Open'),
            ),
          ),
        ),
      );
      final trigger = find.byKey(const ValueKey('ordinary-trigger'));
      expect(
        find.descendant(of: trigger, matching: find.byType(TextButton)),
        findsNothing,
      );
      final ink = tester.widget<InkWell>(
        find.descendant(of: trigger, matching: find.byType(InkWell)),
      );
      expect(ink.customBorder, isA<StadiumBorder>());
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('Choice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
