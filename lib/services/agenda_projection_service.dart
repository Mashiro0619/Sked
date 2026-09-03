import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/timetable_models.dart';
import 'general_occurrence_service.dart';

/// The time range and visibility policy requested from an [AgendaSource].
class AgendaProjectionQuery {
  const AgendaProjectionQuery({
    required this.startInclusive,
    required this.endExclusive,
    this.timetableId,
    this.includeHiddenGeneralSchedules = false,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
  final String? timetableId;
  final bool includeHiddenGeneralSchedules;

  bool get isValid => endExclusive.isAfter(startInclusive);
}

/// Adapter contract for a domain that contributes effective occurrences.
///
/// New domains (for example exams or tasks) implement this interface and are
/// registered with [AgendaSourceRegistry]; notification and widget consumers
/// remain unchanged.
abstract interface class AgendaSource {
  String get id;

  /// Presentation and platform metadata owned by the source adapter.  A new
  /// source can provide its labels/channel/group here without adding another
  /// source switch to notification or widget consumers.
  AgendaSourceDescriptor get descriptor => AgendaSourceDescriptor.fallback(id);

  Iterable<AgendaOccurrence> occurrences(
    AppData data,
    AgendaProjectionQuery query,
  );
}

/// Source-owned metadata consumed by all agenda projections.  The values are
/// intentionally plain Dart data so they can also be used by native bridges.
class AgendaSourceDescriptor {
  const AgendaSourceDescriptor({
    required this.id,
    required this.widgetGroup,
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    required this.typeLabel,
    required this.typeLabelZh,
    this.typeLabelZhHant,
    this.localizedTypeLabels = const {},
    this.localizedChannelNames = const {},
    this.localizedChannelDescriptions = const {},
  });

  factory AgendaSourceDescriptor.fallback(String id) {
    final normalized = id.trim().isEmpty ? 'agenda' : id.trim();
    // Android channel IDs are persisted by the platform. Keep fallback IDs
    // short, conservative, and collision-resistant so a future adapter can
    // use an arbitrary source name without leaking that name into platform
    // limits or colliding after character normalization.
    final channelStem = normalized
        .replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final readableStem = channelStem.isEmpty ? 'agenda' : channelStem;
    final abbreviatedStem = readableStem.length > 52
        ? readableStem.substring(0, 52)
        : readableStem;
    final digest = sha1
        .convert(utf8.encode(normalized))
        .toString()
        .substring(0, 12);
    return AgendaSourceDescriptor(
      id: normalized,
      widgetGroup: 'general',
      channelId: 'sked_${abbreviatedStem}_$digest',
      channelName: '$normalized reminders',
      channelDescription: 'Reminders from $normalized.',
      typeLabel: normalized,
      typeLabelZh: normalized,
      typeLabelZhHant: normalized,
    );
  }

  final String id;

  /// `timetable` sources feed the timetable widget; all other sources feed
  /// the general widget while remaining present in the overview.
  final String widgetGroup;
  final String channelId;
  final String channelName;
  final String channelDescription;
  final String typeLabel;
  final String typeLabelZh;
  final String? typeLabelZhHant;
  final Map<String, String> localizedTypeLabels;
  final Map<String, String> localizedChannelNames;
  final Map<String, String> localizedChannelDescriptions;

  String labelFor(String localeCode) {
    final locale = localeCode.trim().toLowerCase().replaceAll('_', '-');
    final localized = _localizedMetadataValue(
      localizedTypeLabels,
      localeCode,
      '',
    );
    if (localized.isNotEmpty) return localized;
    if (locale.startsWith('zh-hant') ||
        locale.startsWith('zh-tw') ||
        locale.startsWith('zh-hk')) {
      return typeLabelZhHant ?? typeLabelZh;
    }
    if (locale.startsWith('zh')) return typeLabelZh;
    return typeLabel;
  }

  String channelNameFor(String localeCode) =>
      _localizedMetadataValue(localizedChannelNames, localeCode, channelName);

  String channelDescriptionFor(String localeCode) => _localizedMetadataValue(
    localizedChannelDescriptions,
    localeCode,
    channelDescription,
  );

  String _localizedMetadataValue(
    Map<String, String> values,
    String localeCode,
    String fallback,
  ) {
    final normalized = localeCode.trim().toLowerCase().replaceAll('_', '-');
    final language = normalized.split('-').first;
    return values[normalized] ?? values[language] ?? fallback;
  }
}

class CallbackAgendaSource implements AgendaSource {
  const CallbackAgendaSource({
    required this.id,
    required this.builder,
    this.sourceDescriptor,
  });

  @override
  final String id;
  final Iterable<AgendaOccurrence> Function(
    AppData data,
    AgendaProjectionQuery query,
  )
  builder;
  final AgendaSourceDescriptor? sourceDescriptor;

  @override
  AgendaSourceDescriptor get descriptor =>
      sourceDescriptor ?? AgendaSourceDescriptor.fallback(id);

  @override
  Iterable<AgendaOccurrence> occurrences(
    AppData data,
    AgendaProjectionQuery query,
  ) => builder(data, query);
}

/// Immutable source registry. Keeping registration separate from projection
/// makes source ownership explicit and keeps platform services source-neutral.
class AgendaSourceRegistry {
  const AgendaSourceRegistry({this.sources = defaultAgendaSources});

  final List<AgendaSource> sources;

  AgendaSourceDescriptor descriptorFor(String sourceType) {
    for (final source in sources) {
      if (source.id == sourceType || source.descriptor.id == sourceType) {
        return source.descriptor;
      }
    }
    return AgendaSourceDescriptor.fallback(sourceType);
  }

  Set<String> sourceIdsForWidgetGroup(String group) {
    return {
      for (final source in sources)
        if (source.descriptor.widgetGroup == group) source.id,
    };
  }

  AgendaSourceRegistry withSource(AgendaSource source) {
    return AgendaSourceRegistry(
      sources: [
        for (final existing in sources)
          if (existing.id != source.id) existing,
        source,
      ],
    );
  }

  AgendaSourceRegistry withoutSource(String sourceId) {
    return AgendaSourceRegistry(
      sources: sources.where((source) => source.id != sourceId).toList(),
    );
  }
}

const defaultAgendaSources = <AgendaSource>[
  StudentAgendaSource(),
  GeneralAgendaSource(),
];

/// Merges all registered domains into one deterministically ordered stream.
class AgendaProjectionService {
  const AgendaProjectionService({this.registry = const AgendaSourceRegistry()});

  final AgendaSourceRegistry registry;

  List<AgendaOccurrence> project(
    AppData data, {
    required DateTime startInclusive,
    required DateTime endExclusive,
    String? timetableId,
    bool includeHiddenGeneralSchedules = false,
  }) {
    final query = AgendaProjectionQuery(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      timetableId: timetableId,
      includeHiddenGeneralSchedules: includeHiddenGeneralSchedules,
    );
    if (!query.isValid) return const [];

    final byId = <String, AgendaOccurrence>{};
    for (final source in registry.sources) {
      for (final occurrence in source.occurrences(data, query)) {
        final normalized = occurrence.normalized();
        if (!normalized.includeInAgenda ||
            normalized.stableId.isEmpty ||
            !normalized.hasValidRange) {
          continue;
        }
        // A stable ID is only unique within its source. Keep the source
        // namespace in the projection key so independently developed adapters
        // cannot hide one another by reusing a local record ID.
        byId.putIfAbsent(normalized.scopedStableId, () => normalized);
      }
    }
    final result = byId.values.toList()..sort(_compareAgendaOccurrences);
    return List.unmodifiable(result);
  }

  List<AgendaOccurrence> occurrencesForRange(
    AppData data, {
    required DateTime startInclusive,
    required DateTime endExclusive,
    String? timetableId,
    bool includeHiddenGeneralSchedules = false,
  }) {
    return project(
      data,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      timetableId: timetableId,
      includeHiddenGeneralSchedules: includeHiddenGeneralSchedules,
    );
  }

  List<AgendaOccurrence> upcoming(
    AppData data, {
    DateTime? now,
    Duration horizon = const Duration(days: 14),
    String? timetableId,
  }) {
    final anchor = now ?? DateTime.now();
    return project(
      data,
      startInclusive: anchor,
      endExclusive: anchor.add(horizon),
      timetableId: timetableId,
    );
  }
}

int _compareAgendaOccurrences(AgendaOccurrence a, AgendaOccurrence b) {
  final start = a.start.compareTo(b.start);
  if (start != 0) return start;
  final allDay = (b.isAllDay ? 1 : 0).compareTo(a.isAllDay ? 1 : 0);
  if (allDay != 0) return allDay;
  final end = a.end.compareTo(b.end);
  if (end != 0) return end;
  final title = a.title.compareTo(b.title);
  if (title != 0) return title;
  return a.stableId.compareTo(b.stableId);
}

class StudentAgendaSource implements AgendaSource {
  const StudentAgendaSource();

  @override
  String get id => AgendaSourceType.course;

  @override
  AgendaSourceDescriptor get descriptor => const AgendaSourceDescriptor(
    id: AgendaSourceType.course,
    widgetGroup: 'timetable',
    channelId: 'sked_course_reminders',
    channelName: 'Course reminders',
    channelDescription: 'Reminders for timetable courses',
    typeLabel: 'Course',
    typeLabelZh: '课程',
    typeLabelZhHant: '課程',
    localizedChannelNames: {
      'zh': '课程提醒',
      'zh-hant': '課程提醒',
      'zh-tw': '課程提醒',
      'de': 'Kurserinnerungen',
      'es': 'Recordatorios de cursos',
      'fr': 'Rappels de cours',
      'ja': '授業のリマインダー',
      'ko': '수업 알림',
    },
    localizedChannelDescriptions: {
      'zh': '课表课程提醒',
      'zh-hant': '課表課程提醒',
      'zh-tw': '課表課程提醒',
      'de': 'Erinnerungen an Stundenplan-Kurse',
      'es': 'Recordatorios de cursos del horario',
      'fr': 'Rappels pour les cours du planning',
    },
  );

  @override
  Iterable<AgendaOccurrence> occurrences(
    AppData data,
    AgendaProjectionQuery query,
  ) sync* {
    final timetables = data.studentMode.timetables;
    final timetable = _selectTimetable(
      timetables,
      query.timetableId ?? data.studentMode.activeTimetableId,
    );
    if (timetable == null) return;

    final startDate = normalizeDateOnly(query.startInclusive.toLocal());
    final normalizedEnd = query.endExclusive.toLocal();
    final endDate =
        normalizedEnd.hour == 0 &&
            normalizedEnd.minute == 0 &&
            normalizedEnd.second == 0 &&
            normalizedEnd.millisecond == 0 &&
            normalizedEnd.microsecond == 0
        ? normalizeDateOnly(normalizedEnd)
        : addCalendarDays(normalizeDateOnly(normalizedEnd), 1);
    if (!endDate.isAfter(startDate)) return;

    final config = timetable.config;
    final semesterStart = normalizeDateOnly(config.startDate.toLocal());
    final semesterEnd = addCalendarDays(
      startOfWeekFor(config, config.totalWeeks),
      6,
    );
    var date = startDate;
    while (date.isBefore(endDate)) {
      if (!date.isBefore(semesterStart) && !date.isAfter(semesterEnd)) {
        final week = currentWeekFor(config, now: date);
        for (final course in timetable.courses) {
          if (!matchesSemesterWeek(course, week) ||
              course.dayOfWeek != date.weekday) {
            continue;
          }
          final startMinutes = course.startMinutes;
          final endMinutes = course.endMinutes;
          if (endMinutes <= startMinutes ||
              (startMinutes == 0 && endMinutes == 0)) {
            continue;
          }
          final start = DateTime(
            date.year,
            date.month,
            date.day,
            startMinutes ~/ 60,
            startMinutes % 60,
          );
          final end = DateTime(
            date.year,
            date.month,
            date.day,
            endMinutes ~/ 60,
            endMinutes % 60,
          );
          if (!_overlaps(
            start,
            end,
            query.startInclusive,
            query.endExclusive,
          )) {
            continue;
          }
          final stableId = buildCourseAgendaId(
            timetable.id,
            course.id,
            _dateIso(date),
          );
          yield AgendaOccurrence(
            stableId: stableId,
            sourceType: AgendaSourceType.course,
            start: start,
            end: end,
            title: course.name,
            location: course.location,
            target: AgendaTarget(
              sourceType: AgendaSourceType.course,
              timetableId: timetable.id,
              courseId: course.id,
              dateIso: _dateIso(date),
            ),
            reminders: _courseReminders(
              course,
              data.notificationSettings.courseDefaultMinutesBefore,
            ),
            metadata: {
              if (course.teacher.isNotEmpty) 'teacher': course.teacher,
              if (course.remarks.isNotEmpty) 'remarks': course.remarks,
              'timetableId': timetable.id,
              'week': '$week',
            },
          );
        }
      }
      date = addCalendarDays(date, 1);
    }
  }
}

class GeneralAgendaSource implements AgendaSource {
  const GeneralAgendaSource();

  static const _occurrenceService = GeneralOccurrenceService();

  @override
  String get id => AgendaSourceType.generalEvent;

  @override
  AgendaSourceDescriptor get descriptor => const AgendaSourceDescriptor(
    id: AgendaSourceType.generalEvent,
    widgetGroup: 'general',
    channelId: 'sked_schedule_reminders',
    channelName: 'Schedule reminders',
    channelDescription: 'Reminders for schedule events',
    typeLabel: 'Schedule',
    typeLabelZh: '日程',
    typeLabelZhHant: '日程',
    localizedChannelNames: {
      'zh': '日程提醒',
      'zh-hant': '日程提醒',
      'zh-tw': '日程提醒',
      'de': 'Terminerinnerungen',
      'es': 'Recordatorios de eventos',
      'fr': "Rappels d'événements",
      'ja': '予定のリマインダー',
      'ko': '일정 알림',
    },
    localizedChannelDescriptions: {
      'zh': '日程事件提醒',
      'zh-hant': '日程事件提醒',
      'zh-tw': '日程事件提醒',
      'de': 'Erinnerungen an Termine',
      'es': 'Recordatorios de eventos del calendario',
      'fr': "Rappels pour les événements de l'agenda",
    },
  );

  @override
  Iterable<AgendaOccurrence> occurrences(
    AppData data,
    AgendaProjectionQuery query,
  ) sync* {
    final occurrences = _occurrenceService.occurrencesForRange(
      data.generalMode,
      startInclusive: query.startInclusive,
      endExclusive: query.endExclusive,
      onlyVisibleCalendars: !query.includeHiddenGeneralSchedules,
    );
    for (final occurrence in occurrences) {
      yield AgendaOccurrence(
        stableId: occurrence.occurrenceKey,
        sourceType: AgendaSourceType.generalEvent,
        start: occurrence.start,
        end: occurrence.end,
        title: occurrence.event.title,
        location: occurrence.event.location,
        isAllDay: occurrence.isAllDay,
        target: AgendaTarget(
          sourceType: AgendaSourceType.generalEvent,
          calendarId: occurrence.calendar.id,
          eventId: occurrence.event.id,
          occurrenceKey: occurrence.occurrenceKey,
          dateIso: occurrence.exceptionDateIso,
        ),
        reminders: [
          for (final reminder in occurrence.event.reminders)
            if (reminder.minutesBefore >= 0)
              AgendaReminder(minutesBefore: reminder.minutesBefore),
        ],
        metadata: {
          if (occurrence.event.notes.isNotEmpty)
            'notes': occurrence.event.notes,
          'calendarId': occurrence.calendar.id,
        },
      );
    }
  }
}

TimetableData? _selectTimetable(
  Iterable<TimetableData> timetables,
  String? timetableId,
) {
  // An explicit id is authoritative. Falling back to another timetable after
  // an import/delete race can schedule or display the wrong course set.
  if (timetableId == null || timetableId.isEmpty) {
    return timetables.isEmpty ? null : timetables.first;
  }
  for (final timetable in timetables) {
    if (timetable.id == timetableId) return timetable;
  }
  return null;
}

List<AgendaReminder> _courseReminders(
  CourseItem course,
  int? defaultMinutesBefore,
) {
  final settings = course.reminderSettings.normalized();
  switch (settings.behavior) {
    case CourseReminderBehavior.disabled:
      return const [];
    case CourseReminderBehavior.custom:
      final minutes = settings.minutesBefore;
      return minutes == null
          ? const []
          : [AgendaReminder(minutesBefore: minutes)];
    case CourseReminderBehavior.inherit:
      return defaultMinutesBefore == null
          ? const []
          : [AgendaReminder(minutesBefore: defaultMinutesBefore)];
  }
}

String buildCourseAgendaId(
  String timetableId,
  String courseId,
  String dateIso,
) {
  return [
    AgendaSourceType.course,
    Uri.encodeComponent(timetableId),
    Uri.encodeComponent(courseId),
    Uri.encodeComponent(dateIso),
  ].join('|');
}

bool _overlaps(
  DateTime start,
  DateTime end,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
}

String _dateIso(DateTime date) =>
    normalizeDateOnly(date).toIso8601String().split('T').first;
