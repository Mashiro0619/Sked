import '../models/general_event_occurrence.dart';
import '../models/general_schedule_data.dart';

const defaultGeneralReminderOverdueWindow = Duration(hours: 24);
const maximumGeneralReminderLookback = Duration(days: 30);

/// 通用模式（general mode）下"事件发生（occurrence）"相关的纯查询逻辑集合。
///
/// 这个 service 只读 [GeneralScheduleData]，不持有任何状态，所有方法都是
/// 幂等的。CRUD（增删改、reminder 标记 handled）属于 `GeneralCalendarService`。
class GeneralOccurrenceService {
  const GeneralOccurrenceService();

  List<GeneralEventOccurrence> occurrencesForRange(
    GeneralScheduleData general, {
    required DateTime startInclusive,
    required DateTime endExclusive,
    bool onlyVisibleCalendars = true,
  }) {
    return occurrencesForQuery(
      general,
      GeneralOccurrenceQuery(
        startInclusive: startInclusive,
        endExclusive: endExclusive,
        onlyVisibleCalendars: onlyVisibleCalendars,
      ),
    );
  }

  List<GeneralEventOccurrence> occurrencesForQuery(
    GeneralScheduleData general,
    GeneralOccurrenceQuery query,
  ) {
    return expandGeneralOccurrences(
      calendars: general.schedules,
      startInclusive: query.startInclusive,
      endExclusive: query.endExclusive,
      onlyVisibleCalendars: query.onlyVisibleCalendars,
    ).where(query.matches).toList();
  }

  List<GeneralEventOccurrence> upcomingOccurrences(
    GeneralScheduleData general, {
    DateTime? now,
    Duration horizon = const Duration(days: 7),
  }) {
    final anchor = now ?? DateTime.now();
    return occurrencesForQuery(
      general,
      GeneralOccurrenceQuery(
        startInclusive: anchor,
        endExclusive: anchor.add(horizon),
      ),
    );
  }

  bool isReminderHandled(
    GeneralScheduleData general,
    GeneralEventOccurrence occurrence,
  ) {
    return general.reminderAcknowledgements.any(
      (item) =>
          item.isHandled &&
          generalOccurrenceKeyMatches(
            item.occurrenceKey,
            calendarId: occurrence.calendar.id,
            eventId: occurrence.event.id,
            startDateTimeIso: occurrence.start.toIso8601String(),
          ),
    );
  }

  /// 判断 [now] 是否落在 [occurrence] 的「事件开始前的 reminder 窗口」之内。
  ///
  /// 窗口定义为 `[start - max(minutesBefore), start)`；事件已经开始或结束后
  /// 都不算 upcoming（属于 overdue 分支，见 [reminderItems]）。
  bool isInReminderWindow(GeneralEventOccurrence occurrence, DateTime now) {
    if (!now.isBefore(occurrence.start)) {
      return false;
    }
    for (final reminder in occurrence.event.reminders) {
      final reminderAt = occurrence.start.subtract(
        Duration(minutes: reminder.minutesBefore),
      );
      if (!now.isBefore(reminderAt)) {
        return true;
      }
    }
    return false;
  }

  /// 应用内提醒条的数据源。
  ///
  /// 不会触发系统通知/锁屏推送（本轮明确不做）；仅返回此刻应该在 UI 上展示的
  /// upcoming / in-progress / overdue 列表。已被用户标记 handled 的 occurrence 被排除。
  List<GeneralReminderItem> reminderItems(
    GeneralScheduleData general, {
    DateTime? now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
  }) {
    final anchor = now ?? DateTime.now();
    final lookback = boundedGeneralReminderLookback(overdueWindow);
    final candidates = occurrencesForRange(
      general,
      startInclusive: anchor.subtract(lookback),
      endExclusive: anchor.add(upcomingHorizon),
    );
    return reminderItemsFromOccurrences(
      general,
      candidates,
      now: anchor,
      occurrenceFilter: occurrenceFilter,
    );
  }

  List<GeneralReminderItem> reminderItemsFromOccurrences(
    GeneralScheduleData general,
    Iterable<GeneralEventOccurrence> occurrences, {
    required DateTime now,
    GeneralOccurrenceQuery? occurrenceFilter,
  }) {
    final items = <GeneralReminderItem>[];
    for (final occurrence in occurrences) {
      if (occurrence.event.reminders.isEmpty ||
          !(occurrenceFilter?.matches(occurrence) ?? true) ||
          isReminderHandled(general, occurrence)) {
        continue;
      }
      GeneralReminderStatus? status;
      if (occurrence.start.isAfter(now)) {
        if (isInReminderWindow(occurrence, now)) {
          status = GeneralReminderStatus.upcoming;
        }
      } else if (occurrence.end.isAfter(now)) {
        status = GeneralReminderStatus.inProgress;
      } else if (!occurrence.end.isAfter(now)) {
        status = GeneralReminderStatus.overdue;
      }
      if (status != null) {
        items.add(GeneralReminderItem(occurrence: occurrence, status: status));
      }
    }
    return items..sort((a, b) {
      final statusCompare = a.status.index.compareTo(b.status.index);
      if (statusCompare != 0) return statusCompare;
      return a.occurrence.start.compareTo(b.occurrence.start);
    });
  }
}

Duration boundedGeneralReminderLookback(Duration requested) {
  if (requested <= Duration.zero) {
    return Duration.zero;
  }
  if (requested > maximumGeneralReminderLookback) {
    return maximumGeneralReminderLookback;
  }
  return requested;
}
