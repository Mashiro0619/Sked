import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/expressive_motion.dart';

void main() {
  for (final policy in ['ticker', 'disabled', 'reduced']) {
    testWidgets('switcher preserves local input state when $policy changes', (
      tester,
    ) async {
      var changed = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final disabled = changed && policy == 'disabled';
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: disabled),
                  child: SkedMotionPolicyScope(
                    disableAnimations: disabled,
                    reduceMotion: changed && policy == 'reduced',
                    child: TickerMode(
                      enabled: !(changed && policy == 'ticker'),
                      child: const ExpressiveSwitcher(
                        child: TextField(key: ValueKey('local-input')),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final input = find.byKey(const ValueKey('local-input'));
      final originalState = tester.state(input);
      await tester.enterText(input, 'Keep this local draft');
      await tester.pumpAndSettle();
      for (final next in [true, false]) {
        update(() => changed = next);
        await tester.pumpAndSettle();
        expect(tester.state(input), same(originalState));
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Keep this local draft',
        );
        expect(
          TickerMode.valuesOf(tester.element(input)).enabled,
          !(next && policy == 'ticker'),
          reason: 'An accessibility preference must not pause child tickers.',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'disabled switcher settles current content and hides outgoing targets',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final focus = {
          for (final label in ['Previous', 'Current', 'Final'])
            label: FocusNode(),
        };
        addTearDown(() {
          for (final node in focus.values) {
            node.dispose();
          }
        });
        final taps = <String>[];
        var label = 'Previous';
        var disabled = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final content = label;
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: disabled),
                    child: ExpressiveSwitcher(
                      duration: const Duration(seconds: 2),
                      child: TextButton(
                        key: ValueKey(content),
                        focusNode: focus[content],
                        onPressed: () => taps.add(content),
                        child: Text(content),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        Finder content(String value) => find.byKey(ValueKey(value));
        FadeTransition fade(String value) => tester.widget<FadeTransition>(
          find
              .ancestor(
                of: content(value),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        ScaleTransition scale(String value) => tester.widget<ScaleTransition>(
          find
              .ancestor(
                of: content(value),
                matching: find.byType(ScaleTransition),
              )
              .first,
        );
        update(() => label = 'Current');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final currentState = tester.state(content('Current'));
        expect(fade('Current').opacity.value, lessThan(1));
        expect(find.text('Previous'), findsOneWidget);
        expect(find.bySemanticsLabel('Previous'), findsNothing);
        focus['Previous']!.requestFocus();
        await tester.pump();
        expect(focus['Previous']!.hasFocus, isFalse);

        update(() => disabled = true);
        await tester.pump();
        expect(tester.state(content('Current')), same(currentState));
        expect(fade('Current').opacity.value, 1);
        expect(scale('Current').scale.value, 1);
        expect(find.text('Previous'), findsNothing);
        expect(find.text('Previous', skipOffstage: false), findsOneWidget);
        expect(find.bySemanticsLabel('Current'), findsOneWidget);

        update(() => label = 'Final');
        await tester.pump();
        expect(fade('Final').opacity.value, 1);
        expect(scale('Final').scale.value, 1);
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Previous', skipOffstage: false), findsNothing);
        expect(find.text('Current', skipOffstage: false), findsNothing);
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason:
              'Disabled motion must override the custom two-second duration.',
        );
        await tester.tap(content('Final'));
        expect(taps, ['Final']);
        final finalState = tester.state(content('Final'));
        update(() => disabled = false);
        await tester.pumpAndSettle();
        expect(tester.state(content('Final')), same(finalState));
        expect(find.bySemanticsLabel('Final'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('ExpressiveTap does not trigger when disabled', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ExpressiveTap(
              enabled: false,
              onTap: () => tapCount += 1,
              child: const SizedBox(width: 100, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpressiveTap));
    await tester.pump();

    expect(tapCount, 0);
  });
}
