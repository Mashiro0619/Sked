import '../models/general_event.dart';
import '../models/general_event_occurrence.dart';
import '../models/general_schedule.dart';
import '../models/general_schedule_data.dart';
import '../models/notification_settings.dart';
import 'general_reminder_items.dart';

export 'general_reminder_items.dart' show GeneralReminderItems;

const defaultGeneralReminderOverdueWindow = Duration(hours: 24);
const maximumGeneralReminderLookback = Duration(days: 30);

/// 通用模式（general mode）下"事件发生（occurrence）"相关的纯查询逻辑集合。
///
/// 这个 service 只读 [GeneralScheduleData]，不持有任何状态，所有方法都是
/// 幂等的。CRUD（增删改、reminder 标记 handled）属于 `GeneralCalendarService`。
class GeneralOccurrenceService {
  const GeneralOccurrenceService({
    this._expandEvent = expandGeneralEventOccurrences,
  });

  final GeneralEventOccurrenceExpander _expandEvent;

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
      expandEvent: _expandEvent,
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
    late final startDateTimeIso = occurrence.start.toIso8601String();
    return general.reminderAcknowledgements.any(
      (item) =>
          item.isHandled &&
          generalOccurrenceKeyMatches(
            item.occurrenceKey,
            calendarId: occurrence.calendar.id,
            eventId: occurrence.event.id,
            startDateTimeIso: startDateTimeIso,
          ),
    );
  }

  /// 判断 [now] 是否落在 [occurrence] 的「事件开始前的 reminder 窗口」之内。
  ///
  /// 窗口定义为 `[start - max(minutesBefore), start)`；事件已经开始或结束后
  /// 都不算 upcoming（属于 overdue 分支，见 [reminderItems]）。
  bool isInReminderWindow(
    GeneralEventOccurrence occurrence,
    DateTime now, {
    int? defaultMinutesBefore,
  }) {
    if (!now.isBefore(occurrence.start)) {
      return false;
    }
    final remainingMicros = occurrence.start.difference(now).inMicroseconds;
    final wholeMinutes = remainingMicros ~/ Duration.microsecondsPerMinute;
    final isWholeMinute = remainingMicros % Duration.microsecondsPerMinute == 0;
    for (final reminder in occurrence.event.resolveReminders(
      defaultMinutesBefore,
    )) {
      // Compare before multiplying unbounded custom/imported lead values into
      // a Duration. This is equivalent to now >= start - lead without overflow.
      if (reminder.minutesBefore > wholeMinutes ||
          (isWholeMinute && reminder.minutesBefore == wholeMinutes)) {
        return true;
      }
    }
    return false;
  }

  /// 应用内提醒条的数据源。
  ///
  /// 不会触发系统通知/锁屏推送；仅返回此刻应该在 UI 上展示的
  /// upcoming / in-progress / overdue 列表。已被用户标记 handled 的 occurrence 被排除。
  List<GeneralReminderItem> reminderItems(
    GeneralScheduleData general, {
    DateTime? now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
    NotificationSettings notificationSettings = const NotificationSettings(),
  }) {
    final anchor = now ?? DateTime.now();
    if (usesIndexedReminderItems(
      general,
      upcomingHorizon: upcomingHorizon,
      notificationSettings: notificationSettings,
      occurrenceFilter: occurrenceFilter,
    )) {
      return indexedReminderItems(
        general,
        now: anchor,
        upcomingHorizon: upcomingHorizon,
        overdueWindow: overdueWindow,
        occurrenceFilter: occurrenceFilter,
        notificationSettings: notificationSettings,
      );
    }
    final lookback = boundedGeneralReminderLookback(overdueWindow);
    final candidates = <GeneralEventOccurrence>[];
    for (final group in generalReminderCandidateGroups(
      general,
      notificationSettings.generalDefaultMinutesBefore,
    )) {
      candidates.addAll(
        occurrencesForQuery(
          group.data,
          GeneralOccurrenceQuery(
            startInclusive: anchor.subtract(lookback),
            endExclusive: generalReminderCandidateEndExclusive(
              group.data,
              anchor: anchor,
              upcomingHorizon: upcomingHorizon,
              notificationSettings: notificationSettings,
              maximumMinutesBefore: group.maximumMinutesBefore,
            ),
            onlyVisibleCalendars:
                !notificationSettings.remindHiddenGeneralCalendars,
          ),
        ),
      );
    }
    return reminderItemsFromOccurrences(
      general,
      candidates,
      now: anchor,
      occurrenceFilter: occurrenceFilter,
      notificationSettings: notificationSettings,
    );
  }

  /// Chooses a compact query algorithm, without changing the result count or
  /// the saved lead time. Ordinary short windows retain their shared cache.
  bool usesIndexedReminderItems(
    GeneralScheduleData general, {
    Duration upcomingHorizon = const Duration(hours: 24),
    NotificationSettings notificationSettings = const NotificationSettings(),
    GeneralOccurrenceQuery? occurrenceFilter,
  }) {
    if (upcomingHorizon <= Duration.zero) return false;
    const indexedWindow = Duration(days: 128);
    for (final calendar in general.schedules) {
      if (!calendar.isVisible &&
          !notificationSettings.remindHiddenGeneralCalendars) {
        continue;
      }
      for (final event in calendar.events) {
        if (!event.recurrenceRule.isRepeating) continue;
        final reminders = event.resolveReminders(
          notificationSettings.generalDefaultMinutesBefore,
        );
        if (reminders.isEmpty) continue;
        if (upcomingHorizon > indexedWindow ||
            reminders.any(
              (reminder) => reminder.minutesBefore > indexedWindow.inMinutes,
            )) {
          return true;
        }
      }
    }
    return false;
  }

  /// Exact status sections backed by recurrence ordinals and sparse exclusions.
  /// No candidate objects are retained for offscreen rows.
  GeneralReminderItems indexedReminderItems(
    GeneralScheduleData general, {
    required DateTime now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
    NotificationSettings notificationSettings = const NotificationSettings(),
  }) {
    final start = now.subtract(boundedGeneralReminderLookback(overdueWindow));
    final handled = _HandledReminderIndex(general.reminderAcknowledgements);
    final runs = <GeneralReminderRun>[];
    for (final calendar in general.schedules) {
      if (!calendar.isVisible &&
          !notificationSettings.remindHiddenGeneralCalendars) {
        continue;
      }
      for (final event in calendar.events) {
        if (!_matchesReminderEvent(calendar, event, occurrenceFilter)) continue;
        final reminders = event.resolveReminders(
          notificationSettings.generalDefaultMinutesBefore,
        );
        if (reminders.isEmpty) continue;
        var lead = 0;
        for (final reminder in reminders) {
          if (reminder.minutesBefore > lead) lead = reminder.minutesBefore;
        }
        final end = generalReminderCandidateEndExclusive(
          general,
          anchor: now,
          upcomingHorizon: upcomingHorizon,
          notificationSettings: notificationSettings,
          maximumMinutesBefore: lead,
        );
        final range = GeneralEventOccurrenceRange(
          calendar: calendar,
          event: event,
          startInclusive: start,
          endExclusive: end,
          excludedStartDateTimeIso: handled.startTimesFor(
            calendar.id,
            event.id,
          ),
        );
        if (range.isEmpty) continue;
        final future = _firstReminderIndex(
          range,
          (occurrence) => occurrence.start.isAfter(now),
        );
        final notEnded = _firstReminderIndex(
          range,
          (occurrence) => occurrence.end.isAfter(now),
        );
        if (notEnded > 0) {
          runs.add(
            GeneralReminderRun(
              range: range.slice(0, notEnded),
              status: GeneralReminderStatus.overdue,
            ),
          );
        }
        if (future > notEnded) {
          runs.add(
            GeneralReminderRun(
              range: range.slice(notEnded, future),
              status: GeneralReminderStatus.inProgress,
            ),
          );
        }
        final notDue = _firstReminderIndex(
          range,
          (occurrence) =>
              occurrence.start.isAfter(now) &&
              !isInReminderWindow(
                occurrence,
                now,
                defaultMinutesBefore:
                    notificationSettings.generalDefaultMinutesBefore,
              ),
        );
        if (notDue > future) {
          runs.add(
            GeneralReminderRun(
              range: range.slice(future, notDue),
              status: GeneralReminderStatus.upcoming,
            ),
          );
        }
      }
    }
    return GeneralReminderItems(runs, compare: compareGeneralReminderItems);
  }

  List<GeneralReminderItem> reminderItemsFromOccurrences(
    GeneralScheduleData general,
    Iterable<GeneralEventOccurrence> occurrences, {
    required DateTime now,
    GeneralOccurrenceQuery? occurrenceFilter,
    NotificationSettings notificationSettings = const NotificationSettings(),
  }) {
    final items = <GeneralReminderItem>[];
    // Parse history once per batch, only if a candidate passes the filters.
    // Keeping the index local also observes undo and restored/raw snapshots.
    late final handled = _HandledReminderIndex(
      general.reminderAcknowledgements,
    );
    for (final occurrence in occurrences) {
      if ((!occurrence.calendar.isVisible &&
              !notificationSettings.remindHiddenGeneralCalendars) ||
          occurrence.event
              .resolveReminders(
                notificationSettings.generalDefaultMinutesBefore,
              )
              .isEmpty ||
          !(occurrenceFilter?.matches(occurrence) ?? true) ||
          handled.contains(occurrence)) {
        continue;
      }
      GeneralReminderStatus? status;
      if (occurrence.start.isAfter(now)) {
        if (isInReminderWindow(
          occurrence,
          now,
          defaultMinutesBefore:
              notificationSettings.generalDefaultMinutesBefore,
        )) {
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
    return items..sort(compareGeneralReminderItems);
  }
}

bool _matchesReminderEvent(
  GeneralSchedule calendar,
  GeneralEvent event,
  GeneralOccurrenceQuery? filter,
) =>
    filter == null ||
    !filter.hasFilter ||
    filter.matches(
      GeneralEventOccurrence(
        calendar: calendar,
        event: event,
        start: DateTime.utc(2000),
        end: DateTime.utc(2000),
        sequence: 0,
      ),
    );

int _firstReminderIndex(
  List<GeneralEventOccurrence> occurrences,
  bool Function(GeneralEventOccurrence) matches,
) {
  var low = 0;
  var high = occurrences.length;
  while (low < high) {
    final middle = low + ((high - low) ~/ 2);
    if (matches(occurrences[middle])) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return low;
}

/// Widens positive reminder queries to include their effective lead times.
///
/// The extra microsecond belongs only to an actual reminder boundary. It lets
/// an occurrence appear at exactly `start - lead` despite the expansion's
/// exclusive end, without changing ordinary range or zero/negative horizons.
DateTime generalReminderCandidateEndExclusive(
  GeneralScheduleData general, {
  required DateTime anchor,
  required Duration upcomingHorizon,
  required NotificationSettings notificationSettings,
  int? maximumMinutesBefore,
}) {
  final requestedEnd = anchor.add(upcomingHorizon);
  if (upcomingHorizon <= Duration.zero) return requestedEnd;

  final maximumLead =
      maximumMinutesBefore ??
      maximumGeneralReminderMinutesBefore(general, notificationSettings);
  // Compare before constructing a Duration: imported/custom lead values are
  // not product-capped, and multiplying an arbitrary integer can overflow.
  final lastSupported = anchor.isUtc
      ? DateTime.utc(9999, 12, 31, 23, 59, 59, 999, 999)
      : DateTime(9999, 12, 31, 23, 59, 59, 999, 999);
  final remaining = lastSupported.difference(anchor).inMicroseconds;
  if (remaining <= 0 ||
      maximumLead > remaining ~/ Duration.microsecondsPerMinute) {
    return requestedEnd.isAfter(lastSupported) ? requestedEnd : lastSupported;
  }
  final reminderHorizon = Duration(minutes: maximumLead);
  if (reminderHorizon < upcomingHorizon) return requestedEnd;
  final reminderEnd = anchor.add(reminderHorizon);
  return reminderEnd.isBefore(lastSupported)
      ? reminderEnd.add(const Duration(microseconds: 1))
      : reminderEnd;
}

int maximumGeneralReminderMinutesBefore(
  GeneralScheduleData general,
  NotificationSettings notificationSettings,
) {
  var maximumMinutesBefore = 0;
  for (final schedule in general.schedules) {
    if (!schedule.isVisible &&
        !notificationSettings.remindHiddenGeneralCalendars) {
      continue;
    }
    for (final event in schedule.events) {
      for (final reminder in event.resolveReminders(
        notificationSettings.generalDefaultMinutesBefore,
      )) {
        if (reminder.minutesBefore > maximumMinutesBefore) {
          maximumMinutesBefore = reminder.minutesBefore;
        }
      }
    }
  }
  return maximumMinutesBefore;
}

/// Events with the same effective lead share their expansion range.
/// A long one-off reminder must not widen unrelated short-lead recurrences.
class GeneralReminderCandidateGroup {
  const GeneralReminderCandidateGroup({
    required this.data,
    required this.maximumMinutesBefore,
    this.cacheScope,
  });

  final GeneralScheduleData data;
  final int maximumMinutesBefore;
  final Object? cacheScope;
}

List<GeneralReminderCandidateGroup> generalReminderCandidateGroups(
  GeneralScheduleData general,
  int? defaultMinutesBefore,
) {
  final grouped = <int, Map<GeneralSchedule, List<GeneralEvent>>>{};
  for (final schedule in general.schedules) {
    for (final event in schedule.events) {
      var lead = 0;
      for (final reminder in event.resolveReminders(defaultMinutesBefore)) {
        if (reminder.minutesBefore > lead) lead = reminder.minutesBefore;
      }
      (grouped.putIfAbsent(lead, () => {}).putIfAbsent(schedule, () => [])).add(
        event,
      );
    }
  }
  // Retain the shared exact/range cache for the common single-policy case,
  // including empty datasets, rather than constructing snapshots per tick.
  if (grouped.length <= 1) {
    return [
      GeneralReminderCandidateGroup(
        data: general,
        maximumMinutesBefore: grouped.keys.firstOrNull ?? 0,
      ),
    ];
  }
  return [
    for (final entry in grouped.entries)
      GeneralReminderCandidateGroup(
        data: GeneralScheduleData(
          activeScheduleId: general.activeScheduleId,
          schedules: [
            for (final schedule in entry.value.entries)
              schedule.key.copyWith(events: List.unmodifiable(schedule.value)),
          ],
        ),
        maximumMinutesBefore: entry.key,
        cacheScope: Object(),
      ),
  ];
}

class _HandledReminderIndex {
  _HandledReminderIndex(Iterable<GeneralReminderAcknowledgement> history) {
    for (final acknowledgement in history) {
      if (!acknowledgement.isHandled) continue;
      final key = acknowledgement.occurrenceKey;
      final parsed = parseGeneralOccurrenceKey(key);
      if (parsed == null) {
        _rawKeys.add(key);
      } else {
        (_startsByEvent[(parsed.calendarId, parsed.eventId)] ??= <String>{})
            .add(parsed.startDateTimeIso);
        _parsedKeys.add((
          parsed.calendarId,
          parsed.eventId,
          parsed.startDateTimeIso,
        ));
      }
    }
  }

  final _parsedKeys = <(String, String, String)>{};
  final _rawKeys = <String>{};
  final _startsByEvent = <(String, String), Set<String>>{};

  Iterable<String> startTimesFor(String calendarId, String eventId) sync* {
    yield* _startsByEvent[(calendarId, eventId)] ?? const <String>{};
    final prefix = '$calendarId|$eventId|';
    for (final raw in _rawKeys) {
      if (raw.startsWith(prefix)) yield raw.substring(prefix.length);
    }
  }

  bool contains(GeneralEventOccurrence occurrence) {
    if (_parsedKeys.isEmpty && _rawKeys.isEmpty) return false;
    final calendarId = occurrence.calendar.id;
    final eventId = occurrence.event.id;
    // Match the exact ISO text, as generalOccurrenceKeyMatches does.
    final startDateTimeIso = occurrence.start.toIso8601String();
    return _parsedKeys.contains((calendarId, eventId, startDateTimeIso)) ||
        // Only parse failures use the raw join. Adding parsed keys here too
        // would change ownership for legacy strings that look like v2 keys.
        (_rawKeys.isNotEmpty &&
            _rawKeys.contains('$calendarId|$eventId|$startDateTimeIso'));
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

/// Reading order is explicit, not coupled to the status enum declaration order.
/// Ended means the scheduled end has passed, not that the task is incomplete.
int compareGeneralReminderItems(GeneralReminderItem a, GeneralReminderItem b) {
  int rank(GeneralReminderStatus status) => switch (status) {
    GeneralReminderStatus.inProgress => 0,
    GeneralReminderStatus.upcoming => 1,
    GeneralReminderStatus.overdue => 2,
  };
  final status = rank(a.status).compareTo(rank(b.status));
  if (status != 0) return status;
  final time = switch (a.status) {
    GeneralReminderStatus.inProgress => a.occurrence.end.compareTo(
      b.occurrence.end,
    ),
    GeneralReminderStatus.upcoming => a.occurrence.start.compareTo(
      b.occurrence.start,
    ),
    GeneralReminderStatus.overdue => b.occurrence.end.compareTo(
      a.occurrence.end,
    ),
  };
  if (time != 0) return time;
  final title = a.occurrence.event.title.compareTo(b.occurrence.event.title);
  return title != 0
      ? title
      : a.occurrence.occurrenceKey.compareTo(b.occurrence.occurrenceKey);
}
