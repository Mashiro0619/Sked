import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/timetable_models.dart';
import '../models/workspace_availability.dart';
import 'general_occurrence_service.dart';

/// The time range and visibility policy requested from an [AgendaSource].
class AgendaProjectionQuery {
  const AgendaProjectionQuery({
    required this.startInclusive,
    required this.endExclusive,
    this.timetableId,
    this.includeHiddenGeneralSchedules = false,
    this.includeReminderCandidates = false,
    this.retainedOccurrenceIds = const {},
    this.ownedOccurrenceIds = const {},
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
  final String? timetableId;
  final bool includeHiddenGeneralSchedules;

  /// For notification consumers the bounds describe reminder fire times.
  /// Sources should also include later occurrences whose lead times enter
  /// this window. Ordinary agenda/widget queries keep their existing bounds.
  final bool includeReminderCandidates;

  /// Explicit runtime identities (for example a still-active snooze) whose
  /// starts may be outside the generated reminder window.
  final Set<String> retainedOccurrenceIds;

  /// Existing platform cards keep the original overlap/visibility policy.
  /// Unlike an explicit active snooze, ownership does not extend that policy.
  final Set<String> ownedOccurrenceIds;

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
    bool includeReminderCandidates = false,
    Set<String> retainedOccurrenceIds = const {},
    Set<String> ownedOccurrenceIds = const {},
  }) {
    final query = AgendaProjectionQuery(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
      timetableId: timetableId,
      includeHiddenGeneralSchedules: includeHiddenGeneralSchedules,
      includeReminderCandidates: includeReminderCandidates,
      retainedOccurrenceIds: retainedOccurrenceIds,
      ownedOccurrenceIds: ownedOccurrenceIds,
    );
    if (!query.isValid) return const [];

    final byId = <String, AgendaOccurrence>{};
    for (final source in registry.sources) {
      for (final occurrence in source.occurrences(data, query)) {
        if (!data.allowsAgendaSource(occurrence.sourceType)) continue;
        if (query.includeReminderCandidates &&
            !query.retainedOccurrenceIds.contains(occurrence.scopedStableId) &&
            !(query.ownedOccurrenceIds.contains(occurrence.scopedStableId) &&
                _overlaps(
                  occurrence.start,
                  occurrence.end,
                  query.startInclusive,
                  query.endExclusive,
                )) &&
            !occurrence.reminders.any(
              (reminder) =>
                  _reminderFiresInWindow(reminder, occurrence.start, query),
            )) {
          continue;
        }
        final boundary =
            data.workspaceReminderNotBefore[workspaceForAgendaSource(
              occurrence.sourceType,
            )];
        final normalized = occurrence.normalized().copyWith(
          reminders: occurrence.reminders
              .where(
                (reminder) =>
                    boundary == null ||
                    !reminder.fireAt(occurrence.start).isBefore(boundary),
              )
              .toList(),
        );
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
      'en': 'Course reminders',
      'bg': 'Напомняния за курсове',
      'cs': 'Připomenutí kurzů',
      'da': 'Kursuspåmindelser',
      'de': 'Kurserinnerungen',
      'el': 'Υπενθυμίσεις μαθημάτων',
      'es': 'Recordatorios de cursos',
      'et': 'Kursuste meeldetuletused',
      'fi': 'Kurssimuistutukset',
      'fr': 'Rappels de cours',
      'hi': 'पाठ्यक्रम रिमाइंडर',
      'hu': 'Kurzusemlékeztetők',
      'it': 'Promemoria dei corsi',
      'ja': '授業のリマインダー',
      'ko': '수업 알림',
      'nl': 'Cursusherinneringen',
      'pl': 'Przypomnienia o kursach',
      'pt': 'Lembretes de cursos',
      'ro': 'Mementouri pentru cursuri',
      'ru': 'Напоминания о курсах',
      'sl': 'Opomniki za predmete',
      'sv': 'Kurspåminnelser',
      'th': 'การเตือนวิชาเรียน',
      'vi': 'Nhắc nhở môn học',
      'zh': '课程提醒',
      'zh-hant': '課程提醒',
      'zh-tw': '課程提醒',
      'zh-hk': '課程提醒',
      'zh-mo': '課程提醒',
    },
    localizedChannelDescriptions: {
      'en': 'Reminders for timetable courses',
      'bg': 'Напомняния за курсове от разписанието',
      'cs': 'Připomenutí kurzů v rozvrhu',
      'da': 'Påmindelser om kurser i skemaet',
      'de': 'Erinnerungen an Stundenplan-Kurse',
      'el': 'Υπενθυμίσεις μαθημάτων του ωρολογίου προγράμματος',
      'es': 'Recordatorios de cursos del horario',
      'et': 'Tunniplaani kursuste meeldetuletused',
      'fi': 'Lukujärjestyksen kurssien muistutukset',
      'fr': 'Rappels pour les cours du planning',
      'hi': 'समय सारिणी के पाठ्यक्रमों के रिमाइंडर',
      'hu': 'Órarendi kurzusok emlékeztetői',
      'it': 'Promemoria per i corsi dell’orario',
      'ja': '時間割の授業のリマインダー',
      'ko': '시간표 수업에 대한 알림',
      'nl': 'Herinneringen voor cursussen in het rooster',
      'pl': 'Przypomnienia o kursach w planie zajęć',
      'pt': 'Lembretes dos cursos do horário',
      'ro': 'Mementouri pentru cursurile din orar',
      'ru': 'Напоминания о курсах из расписания',
      'sl': 'Opomniki za predmete v urniku',
      'sv': 'Påminnelser om kurser i schemat',
      'th': 'การเตือนวิชาในตารางเรียน',
      'vi': 'Nhắc nhở cho các môn trong thời khóa biểu',
      'zh': '课表课程提醒',
      'zh-hant': '課表課程提醒',
      'zh-tw': '課表課程提醒',
      'zh-hk': '課表課程提醒',
      'zh-mo': '課表課程提醒',
    },
    localizedTypeLabels: {
      'bg': 'Курс',
      'cs': 'Kurz',
      'da': 'Kursus',
      'de': 'Kurs',
      'el': 'Μάθημα',
      'es': 'Curso',
      'et': 'Kursus',
      'fi': 'Kurssi',
      'fr': 'Cours',
      'hi': 'पाठ्यक्रम',
      'hu': 'Kurzus',
      'it': 'Corso',
      'ja': '授業',
      'ko': '수업',
      'nl': 'Cursus',
      'pl': 'Kurs',
      'pt': 'Curso',
      'ro': 'Curs',
      'ru': 'Курс',
      'sl': 'Predmet',
      'sv': 'Kurs',
      'th': 'วิชา',
      'vi': 'Khóa học',
    },
  );

  @override
  Iterable<AgendaOccurrence> occurrences(
    AppData data,
    AgendaProjectionQuery query,
  ) sync* {
    if (!data.isWorkspaceEnabled(AppMode.student)) return;
    final timetables = data.studentMode.timetables;
    final timetable = _selectTimetable(
      timetables,
      query.timetableId ?? data.studentMode.activeTimetableId,
    );
    if (timetable == null) return;

    if (query.includeReminderCandidates) {
      // Resolve each course's actual policy before shifting. A global maximum
      // would scan all intervening days, and can be arbitrarily large in JSON.
      final byLead = <int, List<CourseItem>>{};
      for (final course in timetable.courses) {
        for (final reminder in _courseReminders(
          course,
          data.notificationSettings.courseDefaultMinutesBefore,
        )) {
          (byLead[reminder.normalized().minutesBefore] ??= []).add(course);
        }
      }
      for (final entry in byLead.entries) {
        final shifted = _shiftReminderQuery(query, entry.key);
        if (shifted == null) continue;
        final narrowed = timetable.copyWith(courses: entry.value);
        yield* occurrences(
          data.copyWith(
            studentMode: data.studentMode.copyWith(timetables: [narrowed]),
          ),
          shifted,
        );
      }
      for (final stableId in _retainedStableIds(query, id)) {
        final parts = stableId.split('|');
        if (parts.length != 4 || parts.first != AgendaSourceType.course) {
          continue;
        }
        String tableId;
        String courseId;
        try {
          tableId = Uri.decodeComponent(parts[1]);
          courseId = Uri.decodeComponent(parts[2]);
        } on FormatException {
          continue;
        }
        if (tableId != timetable.id) continue;
        final date = tryParseStrictIsoDateTime(parts[3]);
        if (date == null) continue;
        final courses = timetable.courses
            .where((course) => course.id == courseId)
            .toList();
        if (courses.isEmpty) continue;
        final day = normalizeDateOnly(date.toLocal());
        for (final occurrence in occurrences(
          data.copyWith(
            studentMode: data.studentMode.copyWith(
              timetables: [timetable.copyWith(courses: courses)],
            ),
          ),
          AgendaProjectionQuery(
            startInclusive: day,
            endExclusive: addCalendarDays(day, 1),
            timetableId: timetable.id,
          ),
        )) {
          if (occurrence.stableId == stableId) yield occurrence;
        }
      }
      return;
    }

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
    final periodTimes =
        data.studentMode.periodTimeSets
            .where((set) => set.id == config.periodTimeSetId)
            .firstOrNull
            ?.periodTimes ??
        const <CoursePeriodTime>[];
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
          final time = resolveCourseTimeRange(course, periodTimes);
          if (time == null) continue;
          final startMinutes = time.startMinutes;
          final endMinutes = time.endMinutes;
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
      'en': 'Schedule reminders',
      'bg': 'Напомняния за събития',
      'cs': 'Připomenutí událostí',
      'da': 'Begivenhedspåmindelser',
      'de': 'Terminerinnerungen',
      'el': 'Υπενθυμίσεις συμβάντων',
      'es': 'Recordatorios de eventos',
      'et': 'Sündmuste meeldetuletused',
      'fi': 'Tapahtumamuistutukset',
      'fr': 'Rappels d’événements',
      'hi': 'इवेंट रिमाइंडर',
      'hu': 'Eseményemlékeztetők',
      'it': 'Promemoria degli eventi',
      'ja': '予定のリマインダー',
      'ko': '일정 알림',
      'nl': 'Afspraakherinneringen',
      'pl': 'Przypomnienia o wydarzeniach',
      'pt': 'Lembretes de eventos',
      'ro': 'Mementouri pentru evenimente',
      'ru': 'Напоминания о событиях',
      'sl': 'Opomniki za dogodke',
      'sv': 'Händelsepåminnelser',
      'th': 'การเตือนกิจกรรม',
      'vi': 'Nhắc nhở sự kiện',
      'zh': '日程提醒',
      'zh-hant': '日程提醒',
      'zh-tw': '日程提醒',
      'zh-hk': '日程提醒',
      'zh-mo': '日程提醒',
    },
    localizedChannelDescriptions: {
      'en': 'Reminders for schedule events',
      'bg': 'Напомняния за събития от календара',
      'cs': 'Připomenutí událostí v kalendáři',
      'da': 'Påmindelser om kalenderbegivenheder',
      'de': 'Erinnerungen an Termine',
      'el': 'Υπενθυμίσεις συμβάντων ημερολογίου',
      'es': 'Recordatorios de eventos del calendario',
      'et': 'Kalendrisündmuste meeldetuletused',
      'fi': 'Kalenteritapahtumien muistutukset',
      'fr': 'Rappels pour les événements de l’agenda',
      'hi': 'कैलेंडर इवेंट के रिमाइंडर',
      'hu': 'Naptári események emlékeztetői',
      'it': 'Promemoria per gli eventi del calendario',
      'ja': 'カレンダーの予定のリマインダー',
      'ko': '캘린더 일정에 대한 알림',
      'nl': 'Herinneringen voor agenda-afspraken',
      'pl': 'Przypomnienia o wydarzeniach w kalendarzu',
      'pt': 'Lembretes dos eventos do calendário',
      'ro': 'Mementouri pentru evenimentele din calendar',
      'ru': 'Напоминания о событиях календаря',
      'sl': 'Opomniki za dogodke v koledarju',
      'sv': 'Påminnelser om kalenderhändelser',
      'th': 'การเตือนกิจกรรมในปฏิทิน',
      'vi': 'Nhắc nhở cho các sự kiện trong lịch',
      'zh': '日程事件提醒',
      'zh-hant': '日程事件提醒',
      'zh-tw': '日程事件提醒',
      'zh-hk': '日程事件提醒',
      'zh-mo': '日程事件提醒',
    },
    localizedTypeLabels: {
      'bg': 'График',
      'cs': 'Rozvrh',
      'da': 'Skema',
      'de': 'Zeitplan',
      'el': 'Πρόγραμμα',
      'es': 'Agenda',
      'et': 'Ajakava',
      'fi': 'Aikataulu',
      'fr': 'Planning',
      'hi': 'अनुसूची',
      'hu': 'Ütemezés',
      'it': 'Agenda',
      'ja': '予定',
      'ko': '일정',
      'nl': 'Planning',
      'pl': 'Harmonogram',
      'pt': 'Agenda',
      'ro': 'Program',
      'ru': 'Расписание',
      'sl': 'Urnik',
      'sv': 'Schema',
      'th': 'กำหนดการ',
      'vi': 'Lịch',
    },
  );

  @override
  Iterable<AgendaOccurrence> occurrences(
    AppData data,
    AgendaProjectionQuery query,
  ) sync* {
    if (!data.isWorkspaceEnabled(AppMode.general)) return;
    if (query.includeReminderCandidates) {
      final retained = _retainedStableIds(
        query,
        id,
      ).map(parseGeneralOccurrenceKey).nonNulls.toList(growable: false);
      for (final calendar in data.generalMode.schedules) {
        if (!calendar.isVisible && !query.includeHiddenGeneralSchedules) {
          continue;
        }
        for (final event in calendar.events) {
          final projectedKeys = <String>{};
          final leads = {
            for (final reminder in event.resolveReminders(
              data.notificationSettings.generalDefaultMinutesBefore,
            ))
              if (reminder.minutesBefore >= 0) reminder.minutesBefore,
          };
          for (final lead in leads) {
            final shifted = _shiftReminderQuery(query, lead);
            if (shifted == null) continue;
            final range = GeneralEventOccurrenceRange(
              calendar: calendar,
              event: event,
              startInclusive: shifted.startInclusive,
              endExclusive: shifted.endExclusive,
            );
            // Occurrence ranges use overlap semantics. Notifications instead
            // need starts inside the shifted fire-time window: skip an entire
            // long-duration prefix by index, without visiting every old row.
            for (final occurrence in _startsFrom(
              range,
              shifted.startInclusive,
            )) {
              if (projectedKeys.add(occurrence.occurrenceKey)) {
                yield _projectOccurrence(data, occurrence);
              }
            }
          }
          for (final parts in retained) {
            if (parts.calendarId != calendar.id || parts.eventId != event.id) {
              continue;
            }
            final start = tryParseStrictIsoDateTime(parts.startDateTimeIso);
            if (start == null) continue;
            final range = GeneralEventOccurrenceRange(
              calendar: calendar,
              event: event,
              startInclusive: start,
              endExclusive: start.add(const Duration(microseconds: 1)),
            );
            for (final occurrence in _startsFrom(range, start)) {
              if (occurrence.start.isAtSameMomentAs(start) &&
                  projectedKeys.add(occurrence.occurrenceKey)) {
                yield _projectOccurrence(data, occurrence);
              }
            }
          }
        }
      }
      return;
    }
    final occurrences = _occurrenceService.occurrencesForRange(
      data.generalMode,
      startInclusive: query.startInclusive,
      endExclusive: query.endExclusive,
      onlyVisibleCalendars: !query.includeHiddenGeneralSchedules,
    );
    for (final occurrence in occurrences) {
      yield _projectOccurrence(data, occurrence);
    }
  }

  AgendaOccurrence _projectOccurrence(
    AppData data,
    GeneralEventOccurrence occurrence,
  ) => AgendaOccurrence(
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
      for (final reminder in occurrence.event.resolveReminders(
        data.notificationSettings.generalDefaultMinutesBefore,
      ))
        if (reminder.minutesBefore >= 0)
          AgendaReminder(minutesBefore: reminder.minutesBefore),
    ],
    metadata: {
      if (occurrence.event.notes.isNotEmpty) 'notes': occurrence.event.notes,
      'calendarId': occurrence.calendar.id,
    },
  );
}

/// Moves a reminder-fire-time window to occurrence-start time, preserving
/// elapsed-time (rather than civil-day) arithmetic across DST. Compare the
/// unbounded imported lead before constructing Duration, which can overflow.
AgendaProjectionQuery? _shiftReminderQuery(
  AgendaProjectionQuery query,
  int minutesBefore,
) {
  final lead = minutesBefore < 0 ? 0 : minutesBefore;
  final utcLastExclusive = DateTime.utc(10000);
  final localLastExclusive = DateTime(10000);
  final lastExclusive = localLastExclusive.isAfter(utcLastExclusive)
      ? localLastExclusive
      : utcLastExclusive;
  final availableMicros = lastExclusive
      .difference(query.startInclusive)
      .inMicroseconds;
  if (availableMicros <= 0 ||
      lead > availableMicros ~/ Duration.microsecondsPerMinute) {
    return null;
  }
  final delta = Duration(minutes: lead);
  final start = query.startInclusive.add(delta);
  if (!start.isBefore(lastExclusive)) return null;
  final remainingMicros = lastExclusive
      .difference(query.endExclusive)
      .inMicroseconds;
  final end =
      remainingMicros <= 0 ||
          lead > remainingMicros ~/ Duration.microsecondsPerMinute
      ? lastExclusive
      : query.endExclusive.add(delta);
  return AgendaProjectionQuery(
    startInclusive: start,
    endExclusive: end,
    timetableId: query.timetableId,
    includeHiddenGeneralSchedules: query.includeHiddenGeneralSchedules,
  );
}

Iterable<GeneralEventOccurrence> _startsFrom(
  GeneralEventOccurrenceRange range,
  DateTime startInclusive,
) sync* {
  var first = 0;
  var end = range.length;
  while (first < end) {
    final middle = first + ((end - first) ~/ 2);
    if (range[middle].start.isBefore(startInclusive)) {
      first = middle + 1;
    } else {
      end = middle;
    }
  }
  yield* range.slice(first);
}

Iterable<String> _retainedStableIds(
  AgendaProjectionQuery query,
  String sourceType,
) sync* {
  for (final scoped in {
    ...query.retainedOccurrenceIds,
    ...query.ownedOccurrenceIds,
  }) {
    final parts = scoped.split('|');
    if (parts.length != 2) continue;
    try {
      if (Uri.decodeComponent(parts[0]) == sourceType) {
        yield Uri.decodeComponent(parts[1]);
      }
    } on FormatException {
      continue;
    }
  }
}

bool _reminderFiresInWindow(
  AgendaReminder reminder,
  DateTime occurrenceStart,
  AgendaProjectionQuery query,
) {
  final lead = reminder.normalized().minutesBefore;
  final fromStart = occurrenceStart
      .difference(query.startInclusive)
      .inMicroseconds;
  if (fromStart < 0 || lead > fromStart ~/ Duration.microsecondsPerMinute) {
    return false;
  }
  final fromEnd = occurrenceStart.difference(query.endExclusive).inMicroseconds;
  return fromEnd < 0 || lead > fromEnd ~/ Duration.microsecondsPerMinute;
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
