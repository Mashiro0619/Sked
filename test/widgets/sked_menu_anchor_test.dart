import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/widgets/sked_menu_anchor.dart';
import 'package:sked/widgets/sked_menu_surface.dart';

void main() {
  testWidgets('close and reopen retain progress and retire closing input', (
    tester,
  ) async {
    final menu = MenuController();
    final statuses = <AnimationStatus>[];
    var opened = 0;
    var closed = 0;
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SkedMenuAnchor(
              controller: menu,
              onOpen: () => opened++,
              onClose: () => closed++,
              onAnimationStatusChanged: statuses.add,
              menuChildren: [
                MenuItemButton(
                  overflowAxis: Axis.vertical,
                  closeOnActivate: false,
                  onPressed: () => selected++,
                  child: const Text('Item'),
                ),
              ],
              child: TextButton(
                onPressed: menu.open,
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    menu.open();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    SkedMenuSurface surface() => tester.widget(find.byType(SkedMenuSurface));
    final animation = surface().animation;
    final opening = surface().animation.value;
    expect(opening, greaterThan(0));
    expect(opening, lessThan(1));
    menu.close();
    expect(statuses.last, AnimationStatus.reverse);
    await tester.pump();
    expect(surface().animation.value, closeTo(opening, .001));
    expect(surface().closing, isTrue);
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    await tester.pump(const Duration(milliseconds: 24));
    final closing = surface().animation.value;
    expect(closing, lessThan(opening));
    menu.open();
    await tester.pump();
    expect(surface().animation, same(animation));
    expect(surface().animation.value, closeTo(closing, .001));
    expect(surface().closing, isFalse);
    await tester.pumpAndSettle();
    expect(menu.isOpen, isTrue);
    expect(surface().animation.value, 1);
    expect(opened, 2);
    expect(closed, 0);
    expect(selected, 0);
    menu.close();
    await tester.pumpAndSettle();
    expect(menu.isOpen, isFalse);
    expect(closed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('arrows and Tab cycle enabled menu items and Enter activates', (
    tester,
  ) async {
    final menu = MenuController();
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SkedMenuAnchor(
              controller: menu,
              menuChildren: [
                for (var index = 0; index < 3; index++)
                  MenuItemButton(
                    closeOnActivate: false,
                    onPressed: index == 1
                        ? null
                        : () {
                            selected.add(index);
                            menu.close();
                          },
                    child: Text('Item $index'),
                  ),
              ],
              child: TextButton(
                onPressed: menu.open,
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    menu.open();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, [0]);
    expect(menu.isOpen, isFalse);
    menu.open();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menu.isOpen, isFalse);
    expect(selected, [0]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the first Back closes the menu before leaving its page', (
    tester,
  ) async {
    final menu = MenuController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Center(
                      child: SkedMenuAnchor(
                        controller: menu,
                        menuChildren: const [
                          MenuItemButton(child: Text('Item')),
                        ],
                        child: TextButton(
                          onPressed: menu.open,
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Page'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Page'));
    await tester.pumpAndSettle();
    menu.open();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(menu.isOpen, isFalse);
    expect(find.text('Open'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Page'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('disabling animation during opening settles the visible menu', (
    tester,
  ) async {
    final menu = MenuController();
    var disabled = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: disabled),
              child: Scaffold(
                body: Center(
                  child: SkedMenuAnchor(
                    controller: menu,
                    menuChildren: const [MenuItemButton(child: Text('Item'))],
                    child: TextButton(
                      onPressed: menu.open,
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    menu.open();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    update(() => disabled = true);
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<SkedMenuSurface>(find.byType(SkedMenuSurface))
          .animation
          .value,
      1,
    );
    menu.close();
    await tester.pump();
    expect(menu.isOpen, isFalse);
    expect(find.byType(SkedMenuSurface), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
