import 'dart:math' as math;

import '../models/agenda.dart';

/// Leaves headroom below Samsung's reported 500 AlarmManager request limit.
/// Android reminders are scheduled directly; callers must surface overflow as
/// a coverage limitation instead of relying on a late background refill.
const defaultMaxScheduledNotifications = 450;

/// User-driven snoozes must survive capacity pressure ahead of generated
/// reminder candidates. Late recovery remains lower priority than a normal
/// on-time reminder because it is only a last-resort repair path.
enum NotificationPlanPriority { lateRecovery, normal, userSnooze }

/// A platform-neutral notification that should exist for an agenda occurrence.
/// The platform bridge owns conversion of [key] to an Android notification id.
class NotificationPlanItem {
  const NotificationPlanItem({
    required this.key,
    required this.occurrence,
    required this.reminder,
    required this.fireAt,
    this.priority = NotificationPlanPriority.normal,
  });

  final String key;
  final AgendaOccurrence occurrence;
  final AgendaReminder reminder;
  final DateTime fireAt;
  final NotificationPlanPriority priority;
}

/// The capped result of projecting notification targets.
///
/// The planner deliberately reports only whether capacity was exceeded. A
/// notification source may be unbounded, so calculating a full omitted count
/// is both expensive and misleading.
class NotificationPlanResult {
  const NotificationPlanResult({
    required this.items,
    required this.hasCapacityOverflow,
  });

  const NotificationPlanResult.empty()
    : items = const [],
      hasCapacityOverflow = false;

  final List<NotificationPlanItem> items;
  final bool hasCapacityOverflow;
}

/// Pure planner for future notification targets.
///
/// It is deliberately independent from permission state and platform APIs.
/// Callers can reuse the exact same plan for native notifications, widget
/// refresh alarms, or tests.
class NotificationPlanner {
  const NotificationPlanner({
    this.maxScheduledNotifications = defaultMaxScheduledNotifications,
  });

  /// Hard cap for direct platform alarms. A value of zero disables scheduling;
  /// negative values are normalized to zero for defensive input handling.
  final int maxScheduledNotifications;

  List<NotificationPlanItem> buildPlan(
    Iterable<AgendaOccurrence> occurrences, {
    required DateTime now,
    Duration horizon = const Duration(days: 14),
  }) => buildPlanResult(occurrences, now: now, horizon: horizon).items;

  /// Builds a sorted, de-duplicated plan and reports whether it exceeds the
  /// direct-platform capacity.
  ///
  /// [applyLimit] lets a coordinator merge runtime-only reminders before the
  /// final cap is applied, without duplicating ordering or truncation logic.
  NotificationPlanResult buildPlanResult(
    Iterable<AgendaOccurrence> occurrences, {
    required DateTime now,
    Duration horizon = const Duration(days: 14),
    bool applyLimit = true,
  }) {
    if (horizon <= Duration.zero) return const NotificationPlanResult.empty();
    final endExclusive = now.add(horizon);
    final collector = _NotificationPlanCollector(
      maxItems: applyLimit ? maxScheduledNotifications : null,
    );
    for (final occurrence in occurrences) {
      if (!occurrence.hasValidRange) continue;
      for (final rawReminder in occurrence.reminders) {
        final reminder = rawReminder.normalized();
        final fireAt = reminder.fireAt(occurrence.start);
        if (fireAt.isBefore(now) || !fireAt.isBefore(endExclusive)) {
          continue;
        }
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        collector.add(
          NotificationPlanItem(
            key: key,
            occurrence: occurrence,
            reminder: reminder,
            fireAt: fireAt,
          ),
        );
      }
    }
    return collector.finish();
  }

  /// Applies the planner's cap after a caller adds runtime-only items such as
  /// a snoozed reminder. This keeps the platform alarm count bounded even
  /// when a reminder is restored outside the normal upcoming query.
  NotificationPlanResult limitPlan(Iterable<NotificationPlanItem> items) =>
      _limit(items, maxItems: maxScheduledNotifications);

  NotificationPlanResult _limit(
    Iterable<NotificationPlanItem> items, {
    required int? maxItems,
  }) {
    final collector = _NotificationPlanCollector(maxItems: maxItems);
    for (final item in items) {
      collector.add(item);
    }
    return collector.finish();
  }
}

/// Keeps only the earliest direct candidates when a caller applies a cap.
///
/// This avoids materializing every occurrence of a long or unbounded rule
/// merely to discover that Android can only accept the nearest requests.
class _NotificationPlanCollector {
  _NotificationPlanCollector({required int? maxItems})
    : _maxItems = maxItems == null ? null : math.max(0, maxItems);

  final int? _maxItems;
  final Map<String, NotificationPlanItem> _byKey = {};
  var _hasCapacityOverflow = false;

  void add(NotificationPlanItem item) {
    final existing = _byKey[item.key];
    if (existing != null) {
      if (_comparePlanItems(item, existing) < 0) {
        _byKey[item.key] = item;
      }
      return;
    }

    final maxItems = _maxItems;
    if (maxItems == null || _byKey.length < maxItems) {
      _byKey[item.key] = item;
      return;
    }

    _hasCapacityOverflow = true;
    if (maxItems == 0) return;
    MapEntry<String, NotificationPlanItem>? latest;
    for (final entry in _byKey.entries) {
      if (latest == null || _comparePlanItems(entry.value, latest.value) > 0) {
        latest = entry;
      }
    }
    if (latest != null && _comparePlanItems(item, latest.value) < 0) {
      _byKey
        ..remove(latest.key)
        ..[item.key] = item;
    }
  }

  NotificationPlanResult finish() {
    final items = _byKey.values.toList()..sort(_comparePlanItems);
    return NotificationPlanResult(
      items: List.unmodifiable(items),
      hasCapacityOverflow: _hasCapacityOverflow,
    );
  }
}

int _comparePlanItems(NotificationPlanItem a, NotificationPlanItem b) {
  final time = a.fireAt.compareTo(b.fireAt);
  return time != 0 ? time : a.key.compareTo(b.key);
}

String buildNotificationPlanKey(
  String sourceType,
  String stableOccurrenceId,
  int minutesBefore,
) {
  return [
    'v1',
    Uri.encodeComponent(sourceType),
    Uri.encodeComponent(stableOccurrenceId),
    minutesBefore.toString(),
  ].join('|');
}

/// Parses the canonical key emitted by [buildNotificationPlanKey].
///
/// This is intentionally kept beside the builder so platform payload
/// consumers can distinguish a managed reminder from an arbitrary string.
({String sourceType, String stableOccurrenceId, int minutesBefore})?
parseNotificationPlanKey(String value) {
  final parts = value.split('|');
  if (parts.length != 4 || parts.first != 'v1') return null;
  try {
    final sourceType = Uri.decodeComponent(parts[1]);
    final stableOccurrenceId = Uri.decodeComponent(parts[2]);
    final minutesBefore = int.tryParse(parts[3]);
    if (sourceType.trim().isEmpty ||
        stableOccurrenceId.trim().isEmpty ||
        minutesBefore == null ||
        minutesBefore < 0 ||
        buildNotificationPlanKey(
              sourceType,
              stableOccurrenceId,
              minutesBefore,
            ) !=
            value) {
      return null;
    }
    return (
      sourceType: sourceType,
      stableOccurrenceId: stableOccurrenceId,
      minutesBefore: minutesBefore,
    );
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

class NotificationPlanDiff {
  const NotificationPlanDiff({
    required this.toSchedule,
    required this.toCancel,
  });

  final List<NotificationPlanItem> toSchedule;
  final List<String> toCancel;

  bool get isEmpty => toSchedule.isEmpty && toCancel.isEmpty;
}

/// Computes an incremental notification update without making platform calls.
class NotificationReconciler {
  const NotificationReconciler();

  NotificationPlanDiff diff({
    required Iterable<NotificationPlanItem> desired,
    required Map<String, DateTime> existingFireTimes,
  }) {
    final desiredByKey = <String, NotificationPlanItem>{
      for (final item in desired) item.key: item,
    };
    final toSchedule = <NotificationPlanItem>[];
    for (final item in desiredByKey.values) {
      final existing = existingFireTimes[item.key];
      if (existing == null || existing != item.fireAt) {
        toSchedule.add(item);
      }
    }
    final toCancel =
        existingFireTimes.keys
            .where((key) => !desiredByKey.containsKey(key))
            .toList()
          ..sort();
    toSchedule.sort((a, b) {
      final time = a.fireAt.compareTo(b.fireAt);
      return time != 0 ? time : a.key.compareTo(b.key);
    });
    return NotificationPlanDiff(
      toSchedule: List.unmodifiable(toSchedule),
      toCancel: List.unmodifiable(toCancel),
    );
  }
}
