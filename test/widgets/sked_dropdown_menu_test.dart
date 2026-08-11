import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

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
