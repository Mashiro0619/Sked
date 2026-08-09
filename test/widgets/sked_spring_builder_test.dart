import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/sked_spring_builder.dart';

void main() {
  testWidgets('starts at the target and settles after a retarget', (
    tester,
  ) async {
    final values = <double>[];
    var target = 0.0;
    var endCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                SkedSpringBuilder(
                  value: target,
                  onEnd: () => endCount++,
                  builder: (context, value, child) {
                    values.add(value);
                    return SizedBox(width: 100 + value, child: child);
                  },
                  child: const SizedBox(height: 20),
                ),
                TextButton(
                  onPressed: () => setState(() => target = 100),
                  child: const Text('go'),
                ),
              ],
            );
          },
        ),
      ),
    );
    expect(values.last, 0);

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(values.last, isNot(0));
    expect(values.last, isNot(100));
    await tester.pumpAndSettle();
    expect(values.last, 100);
    expect(endCount, 1);
  });

  testWidgets('retargeting in the opposite direction reaches the new target', (
    tester,
  ) async {
    var target = 0.0;
    final values = <double>[];
    late void Function(void Function()) update;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SkedSpringBuilder(
              value: target,
              builder: (context, value, child) {
                values.add(value);
                return const SizedBox();
              },
            );
          },
        ),
      ),
    );
    update(() => target = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final beforeReverse = values.last;
    update(() => target = 0);
    await tester.pumpAndSettle();
    expect(beforeReverse, greaterThan(0));
    expect(values.last, closeTo(0, 0.0001));
  });

  testWidgets('disabled animations snap and still notify onEnd', (
    tester,
  ) async {
    var target = 0.0;
    var endCount = 0;
    late void Function(void Function()) update;
    double? latest;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SkedSpringBuilder(
                value: target,
                onEnd: () => endCount++,
                builder: (context, value, child) {
                  latest = value;
                  return const SizedBox();
                },
              );
            },
          ),
        ),
      ),
    );
    update(() => target = 1);
    await tester.pump();
    expect(latest, 1);
    await tester.pump();
    expect(endCount, 1);
  });

  testWidgets('disabled TickerMode snaps without leaving a ticker running', (
    tester,
  ) async {
    var target = 0.0;
    late void Function(void Function()) update;
    double? latest;

    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SkedSpringBuilder(
                value: target,
                builder: (context, value, child) {
                  latest = value;
                  return const SizedBox();
                },
              );
            },
          ),
        ),
      ),
    );
    update(() => target = 42);
    await tester.pump();
    expect(latest, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion snaps spatial values without a spring', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    var target = 0.0;
    var endCount = 0;
    late void Function(void Function()) update;
    double? latest;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SkedSpringBuilder(
              value: target,
              onEnd: () => endCount++,
              builder: (context, value, child) {
                latest = value;
                return const SizedBox();
              },
            );
          },
        ),
      ),
    );
    update(() => target = 42);
    await tester.pump();
    expect(latest, 42);
    await tester.pump();
    expect(endCount, 1);
  });

  testWidgets('motion policy scope stops a running spring immediately', (
    tester,
  ) async {
    var target = 0.0;
    var reduceMotion = false;
    late void Function(void Function()) rebuild;
    double latest = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return SkedMotionPolicyScope(
              disableAnimations: false,
              reduceMotion: reduceMotion,
              child: SkedSpringBuilder(
                value: target,
                builder: (context, value, child) {
                  latest = value;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );

    rebuild(() => target = 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(latest, greaterThan(0));
    expect(latest, lessThan(100));

    rebuild(() => reduceMotion = true);
    await tester.pump();
    expect(latest, 100);
    await tester.pump(const Duration(milliseconds: 200));
    expect(latest, 100);
    expect(tester.takeException(), isNull);
  });
}
