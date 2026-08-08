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

  testWidgets(
    'ExpressiveDialogOption keeps a trailing action inline without leading',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(260, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: ExpressiveDialogOption(
                  title: const Text('Period set'),
                  subtitle: const Text('8 periods'),
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

      final titleRect = tester.getRect(find.text('Period set'));
      final editRect = tester.getRect(find.byTooltip('Edit'));
      expect(editRect.top, lessThan(titleRect.bottom + 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ExpressiveDialogOption keeps compact rows touchable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: ExpressiveDialogOption(
                title: const Text('Weekly'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ExpressiveDialogOption)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
