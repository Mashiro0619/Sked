import 'package:material_ui/material_ui.dart';
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
    var editTaps = 0;
    var optionTaps = 0;
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
                  onPressed: () => editTaps++,
                  icon: const Icon(Icons.edit_outlined),
                ),
                onTap: () => optionTaps++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ExpressiveDialogOption), findsOneWidget);
    final subtitleRect = tester.getRect(
      find.text(
        'A detailed subtitle with a long localized description and extra metadata',
      ),
    );
    expect(
      tester.getRect(find.byTooltip('Edit')).top,
      greaterThanOrEqualTo(subtitleRect.bottom + 6),
    );
    await tester.tap(find.byTooltip('Edit'));
    expect(editTaps, 1);
    expect(optionTaps, 0);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    for (final showUnselectedIndicator in [false, true]) {
      testWidgets('selection markers stay centered inline at $scale text scale '
          '(unselected indicator: $showUnselectedIndicator)', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final selected in [true, false])
                        ExpressiveDialogOption(
                          key: ValueKey(selected),
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(selected ? '星期一' : '星期二'),
                          titleMaxLines: null,
                          selected: selected,
                          unselectedIndicator: showUnselectedIndicator
                              ? const Icon(Icons.radio_button_unchecked)
                              : null,
                          onTap: () {},
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final selectedRect = tester.getRect(find.byKey(const ValueKey(true)));
        final unselectedRect = tester.getRect(
          find.byKey(const ValueKey(false)),
        );
        expect(selectedRect.height, closeTo(unselectedRect.height, .01));
        expect(selectedRect.height, greaterThanOrEqualTo(48));
        for (final (label, icon) in [
          ('星期一', Icons.check_circle),
          if (showUnselectedIndicator) ('星期二', Icons.radio_button_unchecked),
        ]) {
          final labelRect = tester.getRect(find.text(label));
          final markerRect = tester.getRect(find.byIcon(icon));
          expect(markerRect.left, greaterThanOrEqualTo(labelRect.right));
          expect(markerRect.center.dy, closeTo(labelRect.center.dy, .01));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

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
