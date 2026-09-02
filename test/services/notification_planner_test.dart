import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/agenda.dart';
import 'package:sked/services/notification_planner.dart';

AgendaOccurrence _occurrence({
  required String id,
  required DateTime start,
  required DateTime end,
  List<AgendaReminder> reminders = const [],
}) {
  return AgendaOccurrence(
    stableId: id,
    sourceType: 'test',
    start: start,
    end: end,
    title: id,
    target: const AgendaTarget(sourceType: 'test'),
    reminders: reminders,
  );
}

void main() {
  test('planner filters invalid ranges and deterministically orders deduplicated reminders', () {
    final now = DateTime(2026, 8, 3, 8);
    final planner = const NotificationPlanner();
    final first = _occurrence(
      id: 'same',
      start: DateTime(2026, 8, 3, 9),
      end: DateTime(2026, 8, 3, 10),
      reminders: const [
        AgendaReminder(minutesBefore: 10),
        AgendaReminder(minutesBefore: 10),
        AgendaReminder(minutesBefore: -5),
      ],
    );
    final duplicateStableId = _occurrence(
      id: 'same',
      start: DateTime(2026, 8, 3, 9, 30),
      end: DateTime(2026, 8, 3, 10, 30),
      reminders: const [AgendaReminder(minutesBefore: 10)],
    );
    final sameFireTime = _occurrence(
      id: 'alphabetically-earlier',
      start: DateTime(2026, 8, 3, 8, 10),
      end: DateTime(2026, 8, 3, 9),
      reminders: const [AgendaReminder(minutesBefore: 0)],
    );
    final sameFireTimeSecond = _occurrence(
      id: 'alphabetically-later',
      start: DateTime(2026, 8, 3, 8, 10),
      end: DateTime(2026, 8, 3, 9),
      reminders: const [AgendaReminder(minutesBefore: 0)],
    );
    final invalid = _occurrence(
      id: 'invalid',
      start: DateTime(2026, 8, 3, 9),
      end: DateTime(2026, 8, 3, 9),
      reminders: const [AgendaReminder(minutesBefore: 10)],
    );

    final plan = planner.buildPlan(
      [first, duplicateStableId, sameFireTimeSecond, sameFireTime, invalid],
      now: now,
      horizon: const Duration(hours: 2),
    );

    expect(plan, hasLength(4));
    expect(plan.map((item) => item.fireAt), [
      DateTime(2026, 8, 3, 8, 10),
      DateTime(2026, 8, 3, 8, 10),
      DateTime(2026, 8, 3, 8, 50),
      DateTime(2026, 8, 3, 9),
    ]);
    expect(plan.take(2).map((item) => item.occurrence.stableId), [
      'alphabetically-earlier',
      'alphabetically-later',
    ]);
    expect(plan[2].occurrence.start, DateTime(2026, 8, 3, 9));
    expect(plan.last.reminder.minutesBefore, 0);
    expect(plan.last.key, contains('same'));
  });

  test(
    'planner excludes an empty window and the exclusive horizon boundary',
    () {
      final occurrence = _occurrence(
        id: 'boundary',
        start: DateTime(2026, 8, 3, 10),
        end: DateTime(2026, 8, 3, 11),
        reminders: const [AgendaReminder(minutesBefore: 0)],
      );
      final planner = const NotificationPlanner();

      expect(
        planner.buildPlan(
          [occurrence],
          now: DateTime(2026, 8, 3, 8),
          horizon: Duration.zero,
        ),
        isEmpty,
      );
      expect(
        planner.buildPlan(
          [occurrence],
          now: DateTime(2026, 8, 3, 8),
          horizon: const Duration(hours: 2),
        ),
        isEmpty,
      );
    },
  );

  test(
    'planner caps distant reminders deterministically and exposes truncation',
    () {
      final now = DateTime(2026, 8, 3, 8);
      const planner = NotificationPlanner(maxScheduledNotifications: 3);
      final occurrences = [
        _occurrence(
          id: 'later',
          start: now.add(const Duration(hours: 4)),
          end: now.add(const Duration(hours: 5)),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
        _occurrence(
          id: 'same-time-z',
          start: now.add(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
        _occurrence(
          id: 'same-time-a',
          start: now.add(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
        _occurrence(
          id: 'middle',
          start: now.add(const Duration(hours: 2)),
          end: now.add(const Duration(hours: 3)),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
        _occurrence(
          id: 'furthest',
          start: now.add(const Duration(hours: 5)),
          end: now.add(const Duration(hours: 6)),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
      ];

      final uncapped = planner.buildPlanResult(
        occurrences,
        now: now,
        applyLimit: false,
      );
      final capped = planner.limitPlan(uncapped.items.reversed);

      expect(uncapped.items, hasLength(5));
      expect(uncapped.truncatedCount, 0);
      expect(capped.items.map((item) => item.occurrence.stableId), [
        'same-time-a',
        'same-time-z',
        'middle',
      ]);
      expect(capped.truncatedCount, 2);
      expect(capped.candidateCount, 5);
      expect(capped.isTruncated, isTrue);
      expect(
        planner.buildPlan(occurrences, now: now).map((item) => item.key),
        capped.items.map((item) => item.key),
      );
    },
  );

  test('planner safely treats a negative cap as no schedulable items', () {
    final now = DateTime(2026, 8, 3, 8);
    const planner = NotificationPlanner(maxScheduledNotifications: -1);
    final result = planner.buildPlanResult([
      _occurrence(
        id: 'only',
        start: now.add(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 2)),
        reminders: const [AgendaReminder(minutesBefore: 0)],
      ),
    ], now: now);

    expect(result.items, isEmpty);
    expect(result.truncatedCount, 1);
  });

  test('planner resolves duplicate runtime keys to the earliest reminder', () {
    final now = DateTime(2026, 8, 3, 8);
    final occurrence = _occurrence(
      id: 'duplicate',
      start: now.add(const Duration(hours: 1)),
      end: now.add(const Duration(hours: 2)),
    );
    final later = NotificationPlanItem(
      key: 'same-key',
      occurrence: occurrence,
      reminder: const AgendaReminder(minutesBefore: 0),
      fireAt: now.add(const Duration(hours: 2)),
    );
    final earlier = NotificationPlanItem(
      key: 'same-key',
      occurrence: occurrence,
      reminder: const AgendaReminder(minutesBefore: 0),
      fireAt: now.add(const Duration(minutes: 10)),
    );

    final result = const NotificationPlanner(maxScheduledNotifications: 1)
        .limitPlan([later, earlier]);

    expect(result.items, hasLength(1));
    expect(result.items.single.fireAt, earlier.fireAt);
    expect(result.truncatedCount, 0);
  });

  test(
    'reconciler sorts schedules and cancellations independently of map order',
    () {
      final now = DateTime(2026, 8, 3, 8);
      final late = NotificationPlanItem(
        key: 'z-late',
        occurrence: _occurrence(
          id: 'late',
          start: now.add(const Duration(hours: 2)),
          end: now.add(const Duration(hours: 3)),
        ),
        reminder: const AgendaReminder(minutesBefore: 0),
        fireAt: now.add(const Duration(hours: 2)),
      );
      final earlyZ = NotificationPlanItem(
        key: 'z-early',
        occurrence: _occurrence(
          id: 'early-z',
          start: now.add(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
        ),
        reminder: const AgendaReminder(minutesBefore: 0),
        fireAt: now.add(const Duration(hours: 1)),
      );
      final earlyA = NotificationPlanItem(
        key: 'a-early',
        occurrence: _occurrence(
          id: 'early-a',
          start: now.add(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
        ),
        reminder: const AgendaReminder(minutesBefore: 0),
        fireAt: now.add(const Duration(hours: 1)),
      );

      final diff = const NotificationReconciler().diff(
        desired: [late, earlyZ, earlyA],
        existingFireTimes: {
          'unchanged': now,
          'z-early': now.add(const Duration(minutes: 30)),
          'obsolete-b': now,
          'obsolete-a': now,
        },
      );

      expect(diff.isEmpty, isFalse);
      expect(diff.toSchedule.map((item) => item.key), [
        'a-early',
        'z-early',
        'z-late',
      ]);
      expect(diff.toCancel, ['obsolete-a', 'obsolete-b', 'unchanged']);
    },
  );
}
