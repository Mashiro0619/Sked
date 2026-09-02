/// Stable source identifiers used by the agenda projection layer.
///
/// These are strings rather than an enum so a future source can be added by
/// registering an adapter without changing the notification or widget
/// consumers.
abstract final class AgendaSourceType {
  static const course = 'course';
  static const generalEvent = 'general_event';
}

class AgendaTarget {
  const AgendaTarget({
    required this.sourceType,
    this.timetableId,
    this.courseId,
    this.calendarId,
    this.eventId,
    this.occurrenceKey,
    this.dateIso,
  });

  final String sourceType;
  final String? timetableId;
  final String? courseId;
  final String? calendarId;
  final String? eventId;
  final String? occurrenceKey;
  final String? dateIso;

  Map<String, dynamic> toJson() => {
    'sourceType': sourceType,
    if (timetableId != null) 'timetableId': timetableId,
    if (courseId != null) 'courseId': courseId,
    if (calendarId != null) 'calendarId': calendarId,
    if (eventId != null) 'eventId': eventId,
    if (occurrenceKey != null) 'occurrenceKey': occurrenceKey,
    if (dateIso != null) 'dateIso': dateIso,
  };

  AgendaTarget copyWith({
    String? sourceType,
    Object? timetableId = _keepNullable,
    Object? courseId = _keepNullable,
    Object? calendarId = _keepNullable,
    Object? eventId = _keepNullable,
    Object? occurrenceKey = _keepNullable,
    Object? dateIso = _keepNullable,
  }) {
    return AgendaTarget(
      sourceType: sourceType ?? this.sourceType,
      timetableId: identical(timetableId, _keepNullable)
          ? this.timetableId
          : timetableId as String?,
      courseId: identical(courseId, _keepNullable)
          ? this.courseId
          : courseId as String?,
      calendarId: identical(calendarId, _keepNullable)
          ? this.calendarId
          : calendarId as String?,
      eventId: identical(eventId, _keepNullable)
          ? this.eventId
          : eventId as String?,
      occurrenceKey: identical(occurrenceKey, _keepNullable)
          ? this.occurrenceKey
          : occurrenceKey as String?,
      dateIso: identical(dateIso, _keepNullable)
          ? this.dateIso
          : dateIso as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgendaTarget &&
        other.sourceType == sourceType &&
        other.timetableId == timetableId &&
        other.courseId == courseId &&
        other.calendarId == calendarId &&
        other.eventId == eventId &&
        other.occurrenceKey == occurrenceKey &&
        other.dateIso == dateIso;
  }

  @override
  int get hashCode => Object.hash(
    sourceType,
    timetableId,
    courseId,
    calendarId,
    eventId,
    occurrenceKey,
    dateIso,
  );
}

class AgendaReminder {
  const AgendaReminder({required this.minutesBefore});

  final int minutesBefore;

  DateTime fireAt(DateTime occurrenceStart) {
    return occurrenceStart.subtract(Duration(minutes: minutesBefore));
  }

  AgendaReminder normalized() {
    return AgendaReminder(minutesBefore: minutesBefore < 0 ? 0 : minutesBefore);
  }

  Map<String, dynamic> toJson() => {'minutesBefore': minutesBefore};

  @override
  bool operator ==(Object other) {
    return other is AgendaReminder && other.minutesBefore == minutesBefore;
  }

  @override
  int get hashCode => minutesBefore.hashCode;
}

/// A source-neutral, effective occurrence used by notifications, widgets and
/// future integrations. It intentionally contains no Flutter or platform
/// types.
class AgendaOccurrence {
  const AgendaOccurrence({
    required this.stableId,
    required this.sourceType,
    required this.start,
    required this.end,
    required this.title,
    required this.target,
    this.location = '',
    this.isAllDay = false,
    this.reminders = const [],
    this.metadata = const {},
    this.includeInAgenda = true,
  });

  final String stableId;
  final String sourceType;
  final DateTime start;
  final DateTime end;
  final String title;
  final String location;
  final bool isAllDay;
  final AgendaTarget target;
  final List<AgendaReminder> reminders;
  final Map<String, String> metadata;

  /// Allows a source adapter to keep an occurrence in its domain model while
  /// excluding it from notifications and widgets (for example archived or
  /// hidden records).  Consumers apply this policy centrally in projection.
  final bool includeInAgenda;

  /// Alias for consumers that use the common `id` naming convention.
  String get id => stableId;

  /// Globally scoped instance identity for consumers that combine multiple
  /// agenda sources. Source adapters may legitimately use the same local ID,
  /// so consumers must not de-duplicate on [stableId] alone.
  String get scopedStableId =>
      '${Uri.encodeComponent(sourceType)}|${Uri.encodeComponent(stableId)}';

  /// Alias for consumers that use `source` instead of `sourceType`.
  String get source => sourceType;

  bool get hasValidRange => end.isAfter(start);

  AgendaOccurrence normalized() {
    final normalizedStart = start;
    final normalizedEnd = end.isAfter(normalizedStart)
        ? end
        : normalizedStart.add(const Duration(minutes: 1));
    final normalizedReminders =
        reminders.map((item) => item.normalized()).toSet().toList()
          ..sort((a, b) => a.minutesBefore.compareTo(b.minutesBefore));
    return AgendaOccurrence(
      stableId: stableId.trim(),
      sourceType: sourceType.trim(),
      start: normalizedStart,
      end: normalizedEnd,
      title: title.trim(),
      location: location.trim(),
      isAllDay: isAllDay,
      target: target,
      reminders: List.unmodifiable(normalizedReminders),
      metadata: Map.unmodifiable(metadata),
      includeInAgenda: includeInAgenda,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgendaOccurrence &&
        other.sourceType == sourceType &&
        other.stableId == stableId;
  }

  @override
  int get hashCode => Object.hash(sourceType, stableId);
}

const Object _keepNullable = #keep;
