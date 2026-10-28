import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/timetable_period_rail_harness.dart';

void main() {
  for (final duration in [1, 5, 10, 15, 25, 30, 35, 45]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('$duration minute period labels fit at scale $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          final periods = [
            CoursePeriodTime(
              index: 1,
              startMinutes: 480,
              endMinutes: 480 + duration,
            ),
          ];
          final snapshot = periods.single.toJson();
          await tester.pumpWidget(
            periodRailHarness(
              periods: periods,
              scaler: TextScaler.linear(scale),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final rail = find.byKey(const ValueKey('timetable-time-rail'));
          final labels = find.descendant(
            of: rail,
            matching: find.byType(CustomMultiChildLayout),
          );
          expect(labels, findsOneWidget);
          final bounds = tester.getRect(labels);
          expect(
            bounds.height,
            closeTo(duration * 1.4 * scale.clamp(1, 2), 0.001),
          );
          final label = '1\n08:00 – ${formatMinutes(480 + duration)}';
          expect(
            tester.getSemantics(find.bySemanticsLabel(label)).label,
            label,
          );
          var visibleLabels = 0;
          for (final text in tester.widgetList<Text>(
            find.descendant(of: rail, matching: find.byType(Text)),
          )) {
            final rect = tester.getRect(find.byWidget(text));
            if (rect.overlaps(bounds)) {
              visibleLabels++;
              expect(rect.top, greaterThanOrEqualTo(bounds.top - .001));
              expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + .001));
            }
          }
          if (duration == 45 && scale == 1) expect(visibleLabels, 3);
          if (duration == 25 && scale == 1) expect(visibleLabels, 1);
          if (duration == 1) expect(visibleLabels, 0);
          expect(periods.single.toJson(), snapshot);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('short labels select lines from actual nonlinear font heights', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        periodRailHarness(
          periods: const [
            CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 510),
          ],
          scaler: const _LargeTitleScaler(),
          locale: const Locale('ar'),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.bySemanticsLabel('1\n08:00 – 08:30')).label,
        '1\n08:00 – 08:30',
      );
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });
}

class _LargeTitleScaler extends TextScaler {
  const _LargeTitleScaler();
  @override
  double scale(double fontSize) => fontSize >= 14 ? fontSize * 3 : fontSize;
  @override
  double get textScaleFactor => 1;
}
