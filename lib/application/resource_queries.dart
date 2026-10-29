import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/timetable_models.dart';
import '../services/agenda_projection_service.dart' show buildCourseAgendaId;
import 'resource_contracts.dart';

export 'resource_contracts.dart';

/// Queries a caller-owned committed snapshot. The caller must replace this
/// reader when the snapshot or its generation/revision changes. No active
/// selection, visibility, workspace availability or persistence is modified.
class ResourceQueries {
  ResourceQueries({
    required this._snapshot,
    required this.datasetGeneration,
    required this.snapshotRevision,
    GeneralEventOccurrenceExpander? expandEvent,
  }) : _expandEvent = expandEvent ?? _indexedOccurrences {
    if (datasetGeneration.trim().isEmpty ||
        datasetGeneration.length > 128 ||
        snapshotRevision < 0) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'A non-empty generation and non-negative revision are required.',
      );
    }
  }

  final AppData _snapshot;
  final String datasetGeneration;
  final int snapshotRevision;
  final GeneralEventOccurrenceExpander _expandEvent;

  static Set<String> fieldsFor(ResourceKind kind, ResourceView view) =>
      Set.unmodifiable(_viewFields(kind, view));

  static Set<String> allowedFieldsFor(ResourceKind kind) => Set.unmodifiable({
    ..._viewFields(kind, ResourceView.summary),
    ..._viewFields(kind, ResourceView.detail),
    ..._viewFields(kind, ResourceView.edit),
  });

  QueryPage query(ResourceQuery query) {
    _validate(query);
    final fields =
        (query.fields ?? _viewFields(query.kind, query.view)).toList()..sort();
    final fingerprint = _fingerprint(query, fields);
    final offset = _readCursor(query.cursor, fingerprint);
    final matches = <_Match>[];
    for (final match in _matches(query)) {
      if (query.ids != null && !query.ids!.contains(match.ref.id)) continue;
      matches.add(match);
      if (matches.length > ResourceQueryLimits.maxMatches) {
        throw const ResourceQueryException(
          ResourceQueryErrorCode.queryTooLarge,
          'Narrow the resource filters or occurrence date range.',
        );
      }
    }
    matches.sort(_compareMatches);
    if (offset > 0 && offset >= matches.length) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidCursor,
        'The cursor does not address a remaining result.',
      );
    }

    final items = <ResourceRecord>[];
    var next = offset;
    while (next < matches.length && items.length < query.limit) {
      final match = matches[next];
      final record = ResourceRecord(
        ref: match.ref,
        view: query.view,
        values: {for (final field in fields) field: match.read(field)},
      );
      final candidate = _page(
        [...items, record],
        matches.length,
        next + 1,
        fingerprint,
      );
      if (_byteLength(candidate.toJson()) > ResourceQueryLimits.maxPageBytes) {
        if (items.isEmpty) {
          throw const ResourceQueryException(
            ResourceQueryErrorCode.resultTooLarge,
            'Select fewer fields; one resource exceeds the page byte budget.',
          );
        }
        break;
      }
      items.add(record);
      next += 1;
    }
    return _page(items, matches.length, next, fingerprint);
  }

  /// Occurrence lookup also requires a containing, bounded query range.
  ResourceRecord get(
    ResourceRef ref, {
    ResourceView view = ResourceView.detail,
    Set<String>? fields,
    DateTime? startInclusive,
    DateTime? endExclusive,
  }) {
    final needsParent = switch (ref.kind) {
      ResourceKind.course ||
      ResourceKind.event ||
      ResourceKind.occurrence => true,
      _ => false,
    };
    if (needsParent != (ref.parentId != null)) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'The reference must have the correct parent scope.',
        field: 'parentId',
      );
    }
    final occurrenceTarget = ref.kind == ResourceKind.occurrence
        ? _occurrenceTarget(ref)
        : null;
    if (ref.kind == ResourceKind.occurrence && occurrenceTarget == null) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.notFound,
        'The occurrence identity does not match its requested parent.',
      );
    }
    final page = query(
      ResourceQuery(
        kind: ref.kind,
        view: view,
        ids: {ref.id},
        parentIds: ref.parentId == null ? null : {ref.parentId!},
        sourceIds: occurrenceTarget == null ? null : {occurrenceTarget.id},
        occurrenceSource: occurrenceTarget?.source,
        fields: fields,
        startInclusive: startInclusive,
        endExclusive: endExclusive,
        limit: 1,
      ),
    );
    if (page.items.isEmpty) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.notFound,
        'The resource does not exist in the requested scope.',
      );
    }
    if (page.totalMatches != 1) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidSnapshot,
        'The snapshot contains duplicate resource identities.',
      );
    }
    return page.items.single;
  }

  QueryPage _page(
    List<ResourceRecord> items,
    int total,
    int next,
    String fingerprint,
  ) => QueryPage(
    datasetGeneration: datasetGeneration,
    snapshotRevision: snapshotRevision,
    items: items,
    totalMatches: total,
    nextCursor: next < total ? _cursor(next, fingerprint) : null,
  );

  Iterable<_Match> _matches(ResourceQuery query) sync* {
    final search = query.search.trim().toLowerCase();
    final studentEnabled = _snapshot.isWorkspaceEnabled(AppMode.student);
    final generalEnabled = _snapshot.isWorkspaceEnabled(AppMode.general);
    if (query.kind == ResourceKind.periodTimeSet) {
      if (!query.includeDisabled && !studentEnabled) return;
      for (final set in _snapshot.studentMode.periodTimeSets) {
        if (!_search(search, [set.name])) continue;
        yield _Match(
          ResourceRef(kind: query.kind, id: set.id),
          (field) => switch (field) {
            'name' => set.name,
            'periodCount' => set.periodTimes.length,
            'periodTimes' =>
              set.periodTimes.map((time) => time.toJson()).toList(),
            'timetableCount' =>
              _snapshot.studentMode.timetables
                  .where((table) => table.config.periodTimeSetId == set.id)
                  .length,
            'workspaceEnabled' => studentEnabled,
            _ => throw StateError('Unregistered period field'),
          },
        );
      }
      return;
    }
    if (studentEnabled || query.includeDisabled) {
      for (final table in _snapshot.studentMode.timetables) {
        if (query.kind == ResourceKind.timetable) {
          if (_search(search, [table.config.name])) {
            yield _Match(
              ResourceRef(kind: query.kind, id: table.id),
              (field) => switch (field) {
                'name' => table.config.name,
                'startDate' => table.config.startDate.toIso8601String(),
                'totalWeeks' => table.config.totalWeeks,
                'periodTimeSetId' => table.config.periodTimeSetId,
                'courseCount' => table.courses.length,
                'workspaceEnabled' => studentEnabled,
                _ => throw StateError('Unregistered timetable field'),
              },
            );
          }
          continue;
        }
        if (query.kind != ResourceKind.course &&
            query.kind != ResourceKind.occurrence) {
          continue;
        }
        if (query.parentIds != null && !query.parentIds!.contains(table.id)) {
          continue;
        }
        if (query.kind == ResourceKind.occurrence &&
            query.occurrenceSource == OccurrenceSource.event) {
          continue;
        }
        final periodTimes =
            _snapshot.studentMode.periodTimeSets
                .where((set) => set.id == table.config.periodTimeSetId)
                .firstOrNull
                ?.periodTimes ??
            const <CoursePeriodTime>[];
        for (final course in table.courses) {
          if (query.kind == ResourceKind.course &&
              query.ids != null &&
              !query.ids!.contains(course.id)) {
            continue;
          }
          if (query.kind == ResourceKind.occurrence &&
              query.sourceIds != null &&
              !query.sourceIds!.contains(course.id)) {
            continue;
          }
          if (!_search(search, [
            course.name,
            course.teacher,
            course.location,
            course.remarks,
            table.config.name,
          ])) {
            continue;
          }
          if (query.kind == ResourceKind.course) {
            yield _course(table, course, periodTimes, studentEnabled);
          } else {
            yield* _courseOccurrences(
              query,
              table,
              course,
              periodTimes,
              studentEnabled,
            );
          }
        }
      }
    }
    if (!generalEnabled && !query.includeDisabled) return;
    final eventCandidates = _eventCandidates(query);
    for (final calendar in _snapshot.generalMode.schedules) {
      if (!calendar.isVisible && !query.includeHidden) continue;
      if (query.kind == ResourceKind.calendar) {
        if (_search(search, [calendar.name])) {
          yield _Match(
            ResourceRef(kind: query.kind, id: calendar.id),
            (field) => switch (field) {
              'name' => calendar.name,
              'colorValue' => calendar.colorValue,
              'isVisible' => calendar.isVisible,
              'sortOrder' => calendar.sortOrder,
              'eventCount' => calendar.events.length,
              'workspaceEnabled' => generalEnabled,
              _ => throw StateError('Unregistered calendar field'),
            },
          );
        }
        continue;
      }
      if (query.kind != ResourceKind.event &&
          query.kind != ResourceKind.occurrence) {
        continue;
      }
      if (query.parentIds != null && !query.parentIds!.contains(calendar.id)) {
        continue;
      }
      if (query.kind == ResourceKind.occurrence &&
          query.occurrenceSource == OccurrenceSource.course) {
        continue;
      }
      final events = eventCandidates == null
          ? calendar.events
          : eventCandidates[calendar] ?? const <GeneralEvent>[];
      for (final event in events) {
        if (query.kind == ResourceKind.event &&
            query.ids != null &&
            !query.ids!.contains(event.id)) {
          continue;
        }
        if (query.kind == ResourceKind.occurrence &&
            query.sourceIds != null &&
            !query.sourceIds!.contains(event.id)) {
          continue;
        }
        if (!_search(search, [
          event.title,
          event.location,
          event.notes,
          calendar.name,
        ])) {
          continue;
        }
        if (query.kind == ResourceKind.event) {
          yield _event(calendar, event, generalEnabled);
        } else {
          final occurrences = _expandEvent(
            calendar: calendar,
            event: event,
            startInclusive: query.startInclusive!,
            endExclusive: query.endExclusive!,
          );
          if (occurrences.length > ResourceQueryLimits.maxMatches) {
            throw const ResourceQueryException(
              ResourceQueryErrorCode.queryTooLarge,
              'Narrow the occurrence date range or select a source record.',
            );
          }
          for (final occurrence in occurrences) {
            yield _Match(
              ResourceRef(
                kind: ResourceKind.occurrence,
                id: occurrence.occurrenceKey,
                parentId: calendar.id,
              ),
              (field) => switch (field) {
                'source' => ResourceRef(
                  kind: ResourceKind.event,
                  id: event.id,
                  parentId: calendar.id,
                ).toJson(),
                'title' => event.title,
                'start' => occurrence.start.toIso8601String(),
                'end' => occurrence.end.toIso8601String(),
                'isAllDay' => event.isAllDay,
                'location' => event.location,
                'notes' => event.notes,
                'sequence' => occurrence.sequence,
                'week' => null,
                'recurrenceRule' => event.recurrenceRule.toJson(),
                'reminderBehavior' => event.reminderBehavior.value,
                'reminders' =>
                  event
                      .resolveReminders(
                        _snapshot
                            .notificationSettings
                            .generalDefaultMinutesBefore,
                      )
                      .map((item) => item.toJson())
                      .toList(),
                'workspaceEnabled' => generalEnabled,
                'calendarVisible' => calendar.isVisible,
                _ => throw StateError('Unregistered occurrence field'),
              },
              start: occurrence.start,
            );
          }
        }
      }
    }
  }

  Map<GeneralSchedule, List<GeneralEvent>>? _eventCandidates(
    ResourceQuery query,
  ) {
    final ids = switch (query.kind) {
      ResourceKind.event => query.ids,
      ResourceKind.occurrence => query.sourceIds,
      _ => null,
    };
    if (ids == null) return null;
    final candidates = <GeneralSchedule, List<GeneralEvent>>{};
    for (final id in ids) {
      for (final location in _snapshot.generalMode.eventLocationsById(id)) {
        (candidates[location.schedule] ??= []).add(location.event);
      }
    }
    return candidates;
  }

  _Match _course(
    TimetableData table,
    CourseItem course,
    List<CoursePeriodTime> periods,
    bool enabled,
  ) => _Match(
    ResourceRef(kind: ResourceKind.course, id: course.id, parentId: table.id),
    (field) => switch (field) {
      'name' => course.name,
      'teacher' => course.teacher,
      'location' => course.location,
      'dayOfWeek' => course.dayOfWeek,
      'semesterWeeks' => course.semesterWeeks,
      'periods' => course.periods,
      'startMinutes' => course.startMinutes,
      'endMinutes' => course.endMinutes,
      'effectiveTime' => _effectiveTime(course, periods),
      'credit' => course.credit,
      'remarks' => course.remarks,
      'customFields' => course.customFields,
      'reminderSettings' => course.reminderSettings.toJson(),
      'workspaceEnabled' => enabled,
      _ => throw StateError('Unregistered course field'),
    },
  );

  _Match _event(GeneralSchedule calendar, GeneralEvent event, bool enabled) =>
      _Match(
        ResourceRef(
          kind: ResourceKind.event,
          id: event.id,
          parentId: calendar.id,
        ),
        (field) => switch (field) {
          'title' => event.title,
          'start' => event.startDateTimeIso,
          'end' => event.endDateTimeIso,
          'isAllDay' => event.isAllDay,
          'recurrenceRule' => event.recurrenceRule.toJson(),
          'recurrenceExceptionDates' => event.recurrenceExceptionDateIso,
          'location' => event.location,
          'notes' => event.notes,
          'colorValue' => event.colorValue,
          'reminderBehavior' => event.reminderBehavior.value,
          'reminders' => event.reminders.map((item) => item.toJson()).toList(),
          'createdAt' => event.createdAtIso,
          'updatedAt' => event.updatedAtIso,
          'workspaceEnabled' => enabled,
          'calendarVisible' => calendar.isVisible,
          _ => throw StateError('Unregistered event field'),
        },
      );

  Iterable<_Match> _courseOccurrences(
    ResourceQuery query,
    TimetableData table,
    CourseItem course,
    List<CoursePeriodTime> periods,
    bool enabled,
  ) sync* {
    final time = resolveCourseTimeRange(course, periods);
    if (time == null) return;
    final semesterStart = normalizeDateOnly(table.config.startDate.toLocal());
    final semesterEnd = addCalendarDays(
      startOfWeekFor(table.config, table.config.totalWeeks),
      6,
    );
    var date = normalizeDateOnly(query.startInclusive!.toLocal());
    final lastDate = normalizeDateOnly(query.endExclusive!.toLocal());
    while (!date.isAfter(lastDate)) {
      if (!date.isBefore(semesterStart) &&
          !date.isAfter(semesterEnd) &&
          date.weekday == course.dayOfWeek) {
        final week = currentWeekFor(table.config, now: date);
        if (matchesSemesterWeek(course, week)) {
          final start = DateTime(
            date.year,
            date.month,
            date.day,
            time.startMinutes ~/ 60,
            time.startMinutes % 60,
          );
          final end = DateTime(
            date.year,
            date.month,
            date.day,
            time.endMinutes ~/ 60,
            time.endMinutes % 60,
          );
          if (end.isAfter(start) &&
              end.isAfter(query.startInclusive!) &&
              start.isBefore(query.endExclusive!) &&
              start.year == date.year &&
              start.month == date.month &&
              start.day == date.day) {
            final occurrenceWeek = week;
            final occurrenceStart = start;
            final occurrenceEnd = end;
            yield _Match(
              ResourceRef(
                kind: ResourceKind.occurrence,
                id: buildCourseAgendaId(
                  table.id,
                  course.id,
                  '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                ),
                parentId: table.id,
              ),
              (field) => switch (field) {
                'source' => ResourceRef(
                  kind: ResourceKind.course,
                  id: course.id,
                  parentId: table.id,
                ).toJson(),
                'title' => course.name,
                'start' => occurrenceStart.toIso8601String(),
                'end' => occurrenceEnd.toIso8601String(),
                'isAllDay' => false,
                'location' => course.location,
                'notes' => course.remarks,
                'sequence' => null,
                'week' => occurrenceWeek,
                'recurrenceRule' => null,
                'reminderBehavior' => course.reminderSettings.behavior.value,
                'reminders' => _courseReminders(course),
                'workspaceEnabled' => enabled,
                'calendarVisible' => null,
                _ => throw StateError('Unregistered occurrence field'),
              },
              start: start,
            );
          }
        }
      }
      final next = addCalendarDays(date, 1);
      if (!next.isAfter(date)) break;
      date = next;
    }
  }

  List<Map<String, int>> _courseReminders(CourseItem course) {
    final settings = course.reminderSettings;
    final minutes = switch (settings.behavior) {
      CourseReminderBehavior.disabled => null,
      CourseReminderBehavior.inherit =>
        _snapshot.notificationSettings.courseDefaultMinutesBefore,
      CourseReminderBehavior.custom => settings.minutesBefore,
    };
    return [
      if (minutes != null && minutes >= 0) {'minutesBefore': minutes},
    ];
  }

  void _validate(ResourceQuery query) {
    if (query.limit < 1 ||
        query.limit > ResourceQueryLimits.maxPageItems ||
        query.search.length > 512) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'The page limit or search text exceeds the supported bounds.',
      );
    }
    for (final ids in [query.ids, query.parentIds, query.sourceIds]) {
      if (ids != null &&
          (ids.length > ResourceQueryLimits.maxFilterIds ||
              ids.any(
                (id) =>
                    id.trim().isEmpty ||
                    id.length > ResourceQueryLimits.maxIdLength,
              ))) {
        throw const ResourceQueryException(
          ResourceQueryErrorCode.invalidArgument,
          'Resource filters require bounded, non-empty IDs.',
        );
      }
    }
    final child =
        query.kind == ResourceKind.course ||
        query.kind == ResourceKind.event ||
        query.kind == ResourceKind.occurrence;
    if (!child && query.parentIds != null) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'This resource kind does not have a parent filter.',
        field: 'parentIds',
      );
    }
    if (query.kind == ResourceKind.occurrence) {
      final start = query.startInclusive;
      final end = query.endExclusive;
      if (start == null ||
          end == null ||
          start.year < 1 ||
          end.year > 9999 ||
          !end.isAfter(start) ||
          end.difference(start) >
              const Duration(days: ResourceQueryLimits.maxRangeDays)) {
        throw const ResourceQueryException(
          ResourceQueryErrorCode.invalidArgument,
          'Occurrences require a positive range of at most 366 days within years 1–9999.',
          field: 'dateRange',
        );
      }
    } else if (query.startInclusive != null ||
        query.endExclusive != null ||
        query.sourceIds != null ||
        query.occurrenceSource != null) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'Date ranges and source filters are only supported for occurrences.',
      );
    }
    if (query.fields != null &&
        !allowedFieldsFor(query.kind).containsAll(query.fields!)) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidField,
        'The projection contains an unknown field.',
        field: 'fields',
      );
    }
  }

  String _fingerprint(ResourceQuery query, List<String> fields) {
    List<String>? sorted(Set<String>? values) =>
        values == null ? null : (values.toList()..sort());
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'kind': query.kind.name,
              'view': query.view.name,
              'ids': sorted(query.ids),
              'parentIds': sorted(query.parentIds),
              'sourceIds': sorted(query.sourceIds),
              'source': query.occurrenceSource?.name,
              'search': query.search.trim().toLowerCase(),
              'hidden': query.includeHidden,
              'disabled': query.includeDisabled,
              'fields': fields,
              'limit': query.limit,
              'start': query.startInclusive?.toUtc().toIso8601String(),
              'end': query.endExclusive?.toUtc().toIso8601String(),
              'localStartOffset': query.startInclusive
                  ?.toLocal()
                  .timeZoneOffset
                  .inMinutes,
              'localEndOffset': query.endExclusive
                  ?.toLocal()
                  .timeZoneOffset
                  .inMinutes,
            }),
          ),
        )
        .toString();
  }

  String _cursor(int offset, String fingerprint) => base64Url.encode(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'generation': datasetGeneration,
        'revision': snapshotRevision,
        'query': fingerprint,
        'offset': offset,
      }),
    ),
  );

  int _readCursor(String? cursor, String fingerprint) {
    if (cursor == null) return 0;
    Object? decoded;
    try {
      if (cursor.length > 2048) throw const FormatException();
      decoded = jsonDecode(
        utf8.decode(base64Url.decode(cursor), allowMalformed: false),
      );
    } on FormatException {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidCursor,
        'The cursor is not a supported continuation token.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 5 ||
        decoded['v'] != 1 ||
        decoded['generation'] is! String ||
        decoded['revision'] is! int ||
        decoded['query'] is! String ||
        decoded['offset'] is! int ||
        (decoded['offset'] as int) <= 0) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidCursor,
        'The cursor is not a supported continuation token.',
      );
    }
    if (decoded['generation'] != datasetGeneration ||
        decoded['revision'] != snapshotRevision) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.staleCursor,
        'The cursor belongs to a different dataset snapshot.',
      );
    }
    if (decoded['query'] != fingerprint) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.cursorQueryMismatch,
        'The cursor belongs to a different query.',
      );
    }
    return decoded['offset'] as int;
  }
}

class _Match {
  const _Match(this.ref, this.read, {this.start});
  final ResourceRef ref;
  final Object? Function(String) read;
  final DateTime? start;
}

int _compareMatches(_Match a, _Match b) {
  final byTime = a.start == null ? 0 : a.start!.compareTo(b.start!);
  if (byTime != 0) return byTime;
  final byParent = (a.ref.parentId ?? '').compareTo(b.ref.parentId ?? '');
  return byParent != 0 ? byParent : a.ref.id.compareTo(b.ref.id);
}

bool _search(String query, List<String> values) =>
    query.isEmpty || values.any((value) => value.toLowerCase().contains(query));

int _byteLength(Object? value) => utf8.encode(jsonEncode(value)).length;

Map<String, Object?> _effectiveTime(
  CourseItem course,
  List<CoursePeriodTime> periods,
) {
  final resolved = resolveCourseTimeRange(course, periods);
  return {
    'source': course.endMinutes > course.startMinutes
        ? 'explicit'
        : resolved == null
        ? 'unresolved'
        : 'periods',
    'startMinutes': resolved?.startMinutes,
    'endMinutes': resolved?.endMinutes,
  };
}

List<GeneralEventOccurrence> _indexedOccurrences({
  required GeneralSchedule calendar,
  required GeneralEvent event,
  required DateTime startInclusive,
  required DateTime endExclusive,
}) => GeneralEventOccurrenceRange(
  calendar: calendar,
  event: event,
  startInclusive: startInclusive,
  endExclusive: endExclusive,
);

({OccurrenceSource source, String id})? _occurrenceTarget(ResourceRef ref) {
  if (ref.id.length > ResourceQueryLimits.maxIdLength) return null;
  final event = parseGeneralOccurrenceKey(ref.id);
  if (event != null &&
      event.calendarId == ref.parentId &&
      event.eventId.isNotEmpty &&
      tryParseStrictIsoDateTime(event.startDateTimeIso) != null &&
      buildGeneralOccurrenceKey(
            event.calendarId,
            event.eventId,
            event.startDateTimeIso,
          ) ==
          ref.id) {
    return (source: OccurrenceSource.event, id: event.eventId);
  }
  final parts = ref.id.split('|');
  if (parts.length != 4 || parts.first != 'course') return null;
  try {
    final parent = Uri.decodeComponent(parts[1]);
    final course = Uri.decodeComponent(parts[2]);
    final date = Uri.decodeComponent(parts[3]);
    if (parent == ref.parentId &&
        course.isNotEmpty &&
        tryParseStrictIsoDate(date) != null &&
        buildCourseAgendaId(parent, course, date) == ref.id) {
      return (source: OccurrenceSource.course, id: course);
    }
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
  return null;
}

Set<String> _viewFields(ResourceKind kind, ResourceView view) {
  final writable = switch (kind) {
    ResourceKind.timetable => const {
      'name',
      'startDate',
      'totalWeeks',
      'periodTimeSetId',
    },
    ResourceKind.course => const {
      'name',
      'teacher',
      'location',
      'dayOfWeek',
      'semesterWeeks',
      'periods',
      'startMinutes',
      'endMinutes',
      'credit',
      'remarks',
      'customFields',
      'reminderSettings',
    },
    ResourceKind.periodTimeSet => const {'name', 'periodTimes'},
    ResourceKind.calendar => const {
      'name',
      'colorValue',
      'isVisible',
      'sortOrder',
    },
    ResourceKind.event => const {
      'title',
      'start',
      'end',
      'isAllDay',
      'recurrenceRule',
      'recurrenceExceptionDates',
      'location',
      'notes',
      'colorValue',
      'reminderBehavior',
      'reminders',
    },
    ResourceKind.occurrence => const {
      'source',
      'title',
      'start',
      'end',
      'isAllDay',
      'location',
      'notes',
      'sequence',
      'week',
      'recurrenceRule',
      'reminderBehavior',
      'reminders',
    },
  };
  if (view == ResourceView.edit) return writable;
  final summary = switch (kind) {
    ResourceKind.timetable => {...writable, 'courseCount', 'workspaceEnabled'},
    ResourceKind.course => const {
      'name',
      'dayOfWeek',
      'semesterWeeks',
      'effectiveTime',
      'workspaceEnabled',
    },
    ResourceKind.periodTimeSet => const {
      'name',
      'periodCount',
      'timetableCount',
      'workspaceEnabled',
    },
    ResourceKind.calendar => const {
      'name',
      'colorValue',
      'isVisible',
      'eventCount',
      'workspaceEnabled',
    },
    ResourceKind.event => const {
      'title',
      'start',
      'end',
      'isAllDay',
      'recurrenceRule',
      'workspaceEnabled',
      'calendarVisible',
    },
    ResourceKind.occurrence => const {
      'source',
      'title',
      'start',
      'end',
      'isAllDay',
      'workspaceEnabled',
      'calendarVisible',
    },
  };
  return view == ResourceView.summary
      ? summary
      : {
          ...summary,
          ...writable,
          if (kind == ResourceKind.event) ...{'createdAt', 'updatedAt'},
        };
}
