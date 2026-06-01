import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/widgets/expressive_dialog.dart';

void main() {
  testWidgets('ExpressiveDialogContent fits compact phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AlertDialog(
            content: ExpressiveDialogContent(
              child: Text('Compact dialog content'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ExpressiveDialogContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ExpressiveDialogOption fits compact width with long text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(260, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: ExpressiveDialogOption(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text(
                  'A very long option title that should never force overflow',
                ),
                subtitle: const Text(
                  'A detailed subtitle with a long localized description and extra metadata',
                ),
                trailing: IconButton(
                  tooltip: 'Edit',
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ExpressiveDialogOption), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
