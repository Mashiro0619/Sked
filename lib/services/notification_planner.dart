import '../models/agenda.dart';

/// Leaves headroom below common OEM alarm limits while still covering a busy
/// two-week schedule. The nearest reminders always win when this is reached.
const defaultMaxScheduledNotifications = 200;

/// A platform-neutral notification that should exist for an agenda occurrence.
/// The platform bridge owns conversion of [key] to an Android notification id.
class NotificationPlanItem {
  const NotificationPlanItem({
    required this.key,
    required this.occurrence,
    required this.reminder,
    required this.fireAt,
  });

  final String key;
  final AgendaOccurrence occurrence;
  final AgendaReminder reminder;
  final DateTime fireAt;
}

/// The capped result of projecting notification targets.
///
/// [truncatedCount] is exposed separately so callers can surface a useful
/// diagnostic instead of silently losing distant reminders.
class NotificationPlanResult {
  const NotificationPlanResult({
    required this.items,
    required this.truncatedCount,
  });

  const NotificationPlanResult.empty() : items = const [], truncatedCount = 0;

  final List<NotificationPlanItem> items;
  final int truncatedCount;

  int get candidateCount => items.length + truncatedCount;
  bool get isTruncated => truncatedCount > 0;
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

  /// Hard cap for Android's rolling alarm window. A value of zero disables
  /// scheduling; negative values are normalized to zero for defensive input
  /// handling.
  final int maxScheduledNotifications;

  List<NotificationPlanItem> buildPlan(
    Iterable<AgendaOccurrence> occurrences, {
    required DateTime now,
    Duration horizon = const Duration(days: 14),
  }) => buildPlanResult(occurrences, now: now, horizon: horizon).items;

  /// Builds a sorted, de-duplicated plan and reports how many distant items
  /// were omitted by the OEM-safe cap.
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
    final byKey = <String, NotificationPlanItem>{};
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
        byKey.putIfAbsent(
          key,
          () => NotificationPlanItem(
            key: key,
            occurrence: occurrence,
            reminder: reminder,
            fireAt: fireAt,
          ),
        );
      }
    }
    return _limit(
      byKey.values,
      maxItems: applyLimit ? maxScheduledNotifications : null,
    );
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
    final byKey = <String, NotificationPlanItem>{};
    for (final item in items) {
      final existing = byKey[item.key];
      if (existing == null || _comparePlanItems(item, existing) < 0) {
        byKey[item.key] = item;
      }
    }
    final ordered = byKey.values.toList()..sort(_comparePlanItems);
    if (maxItems == null) {
      return NotificationPlanResult(
        items: List.unmodifiable(ordered),
        truncatedCount: 0,
      );
    }
    final limit = maxItems < 0 ? 0 : maxItems;
    final truncatedCount = ordered.length > limit ? ordered.length - limit : 0;
    return NotificationPlanResult(
      items: List.unmodifiable(ordered.take(limit)),
      truncatedCount: truncatedCount,
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
