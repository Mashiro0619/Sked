import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/sked_menu_anchor.dart';

class _DropdownHarness extends StatefulWidget {
  const _DropdownHarness();

  @override
  State<_DropdownHarness> createState() => _DropdownHarnessState();
}

class _DropdownHarnessState extends State<_DropdownHarness> {
  bool enabled = true;
  final committed = 'first';

  void setEnabled(bool value) {
    setState(() => enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SkedDropdownMenu<String>(
          key: const ValueKey('test-dropdown'),
          initialSelection: committed,
          enabled: enabled,
          expandedInsets: EdgeInsets.zero,
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'first', label: 'First'),
            DropdownMenuEntry(value: 'second', label: 'Second'),
          ],
          onSelected: (_) {},
        ),
      ),
    );
  }
}

void main() {
  for (final label in ['First', 'Second']) {
    testWidgets('a pending tap on $label cannot select a reopened dropdown', (
      tester,
    ) async {
      final selected = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SkedDropdownMenu<String>(
                initialSelection: 'first',
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'first', label: 'First'),
                  DropdownMenuEntry(value: 'second', label: 'Second'),
                ],
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      final menu = tester
          .widget<SkedMenuAnchor>(find.byType(SkedMenuAnchor))
          .controller!;
      menu.open();
      await tester.pumpAndSettle();
      final item = find.widgetWithText(MenuItemButton, label);
      final previousState = tester.state(item);
      await tester.tap(item);
      // MenuItemButton dispatches its selection in a post-frame callback.
      // Reopen before that callback and before rebuilding the old item State.
      menu.close();
      menu.open();
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(menu.isOpen, isTrue);
      expect(tester.state(item), isNot(same(previousState)));
      await tester.tap(find.widgetWithText(MenuItemButton, 'Second'));
      await tester.pumpAndSettle();
      expect(selected, ['second']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'callbacks from a closed dropdown cannot select after reopening',
    (tester) async {
      final selected = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SkedDropdownMenu<String>(
                initialSelection: 'first',
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'first', label: 'First'),
                  DropdownMenuEntry(value: 'second', label: 'Second'),
                ],
                onSelected: selected.add,
              ),
            ),
          ),
        ),
      );
      final menu = tester
          .widget<SkedMenuAnchor>(find.byType(SkedMenuAnchor))
          .controller!;
      menu.open();
      await tester.pumpAndSettle();
      final oldSelect = tester
          .widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Second'))
          .onPressed!;
      menu.close();
      oldSelect();
      expect(selected, isEmpty);
      await tester.pumpAndSettle();
      menu.open();
      await tester.pumpAndSettle();
      oldSelect();
      expect(selected, isEmpty);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Second'));
      await tester.pumpAndSettle();
      expect(selected, ['second']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('resynchronizes the selection after a failed save', (
    tester,
  ) async {
    await tester.pumpWidget(const _DropdownHarness());
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const ValueKey('test-dropdown'));
    expect(find.text('First'), findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second').last);
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);

    // The provider did not publish the optimistic value because its save
    // failed.  While the command is disabled, keep the old committed value.
    final harness = tester.state<_DropdownHarnessState>(
      find.byType(_DropdownHarness),
    );
    harness.setEnabled(false);
    await tester.pumpAndSettle();

    harness.setEnabled(true);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
  });
}
