import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/calendar_timeline_layout.dart';

void main() {
  test('empty and invalid durations do not become visible blocks', () {
    expect(layoutTimelineEventColumns<int>([]), isEmpty);
    expect(
      layoutTimelineEventColumns([
        const TimelineEventSpan(1, 90, 90),
        const TimelineEventSpan(2, 120, 60),
      ]),
      isEmpty,
    );
  });
  test('adjacent intervals keep their own groups and actual duration', () {
    final groups = layoutTimelineEventColumns([
      const TimelineEventSpan('a', 60, 61),
      const TimelineEventSpan('b', 61, 90),
    ]);
    expect(groups, hasLength(2));
    expect(
      groups.first.events.single.span.end -
          groups.first.events.single.span.start,
      1,
    );
    expect(groups.every((g) => g.columnCount == 1), isTrue);
  });
  test(
    'nested and chained overlaps reuse free columns without merging IDs',
    () {
      final groups = layoutTimelineEventColumns([
        const TimelineEventSpan('long', 0, 90),
        const TimelineEventSpan('same-name-1', 10, 40),
        const TimelineEventSpan('same-name-2', 10, 40),
        const TimelineEventSpan('later', 40, 60),
        const TimelineEventSpan('chain', 80, 100),
      ]);
      final group = groups.single;
      expect(group.columnCount, 3);
      expect(group.events.map((e) => e.column), [0, 1, 2, 1, 1]);
      expect(group.events.map((e) => e.span.value), [
        'long',
        'same-name-1',
        'same-name-2',
        'later',
        'chain',
      ]);
    },
  );
  test('equal starts put long intervals first and equal spans stay stable', () {
    final group = layoutTimelineEventColumns([
      const TimelineEventSpan('short', 0, 20),
      const TimelineEventSpan('long', 0, 30),
      const TimelineEventSpan('tie', 0, 20),
      const TimelineEventSpan('early', -10, 25),
    ]).single;
    expect(group.events.map((e) => e.span.value), [
      'early',
      'long',
      'short',
      'tie',
    ]);
    expect(group.columnCount, 4);
  });
  test('three or six events are shown when the column budget really fits', () {
    for (final n in [3, 6]) {
      final b = TimelineColumnBudget.resolve(
        width: n * 67.0,
        columns: n,
        textScale: 1,
        desktop: true,
      );
      expect(b.visibleColumns, n);
      expect(b.hasOverflow, isFalse);
      expect(b.columnWidth, greaterThanOrEqualTo(64));
    }
  });
  test('overflow uses a count rail instead of half the day', () {
    final b = TimelineColumnBudget.resolve(
      width: 224,
      columns: 6,
      textScale: 1,
      desktop: true,
    );
    expect(b.visibleColumns, 2);
    expect(b.overflowWidth, 28);
    expect(b.columnWidth, greaterThan(64));
    expect(b.overflowWidth, lessThan(b.columnWidth));
  });
  test('large text and touch change the budget, not the event data', () {
    final normal = TimelineColumnBudget.resolve(
      width: 280,
      columns: 3,
      textScale: 1,
      desktop: true,
    );
    final large = TimelineColumnBudget.resolve(
      width: 280,
      columns: 3,
      textScale: 2,
      desktop: true,
    );
    final touch = TimelineColumnBudget.resolve(
      width: 140,
      columns: 6,
      textScale: 1,
      desktop: false,
    );
    expect(normal.visibleColumns, 3);
    expect(large.visibleColumns, lessThan(3));
    expect(touch.overflowWidth, closeTo(44.8, .01));
    for (final width in [0.0, -1.0, double.infinity, 1.0]) {
      final b = TimelineColumnBudget.resolve(
        width: width,
        columns: 6,
        textScale: double.nan,
        desktop: true,
      );
      expect(b.columnWidth, isPositive);
      expect(b.visibleColumns, 1);
    }
    final single = TimelineColumnBudget.resolve(
      width: 60,
      columns: 0,
      textScale: .8,
      desktop: true,
    );
    expect(single.visibleColumns, 1);
    expect(single.hasOverflow, isFalse);
  });
}
