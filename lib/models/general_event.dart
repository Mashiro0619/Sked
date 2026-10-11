import '../utils/time_utils.dart';

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

List<dynamic> _listValue(Object? value) {
  return value is List ? value : const <dynamic>[];
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

String? _nullableStringValue(Object? value) {
  return value is String ? value : null;
}

int? _intValue(Object? value) {
  return value is num ? value.toInt() : null;
}

bool? _boolValue(Object? value) {
  return value is bool ? value : null;
}

enum GeneralEventRecurrence {
  none('none'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  custom('custom');

  const GeneralEventRecurrence(this.value);
  final String value;
}

enum GeneralEventRecurrenceUnit {
  day('day'),
  week('week'),
  month('month');

  const GeneralEventRecurrenceUnit(this.value);
  final String value;
}

GeneralEventRecurrence parseGeneralEventRecurrence(String? value) {
  return GeneralEventRecurrence.values.firstWhere(
    (r) => r.value == value,
    orElse: () => GeneralEventRecurrence.none,
  );
}

GeneralEventRecurrenceUnit parseGeneralEventRecurrenceUnit(String? value) {
  return GeneralEventRecurrenceUnit.values.firstWhere(
    (unit) => unit.value == value,
    orElse: () => GeneralEventRecurrenceUnit.week,
  );
}

class GeneralEventReminder {
  const GeneralEventReminder({required this.minutesBefore});

  final int minutesBefore;

  Map<String, dynamic> toJson() => {'minutesBefore': minutesBefore};

  factory GeneralEventReminder.fromJson(Map<String, dynamic> json) {
    return GeneralEventReminder(
      minutesBefore: _intValue(json['minutesBefore']) ?? 0,
    );
  }
}

enum GeneralEventReminderBehavior {
  inherit('inherit'),
  disabled('disabled'),
  custom('custom');

  const GeneralEventReminderBehavior(this.value);
  final String value;
}

GeneralEventReminderBehavior? _decodeReminderBehavior(
  Map<String, dynamic> json,
) {
  if (!json.containsKey('reminderBehavior')) return null;
  final value = json['reminderBehavior'];
  for (final behavior in GeneralEventReminderBehavior.values) {
    if (behavior.value == value) return behavior;
  }
  throw const FormatException('General event reminder behavior is invalid.');
}

int? _decodeMonthlyAnchorDay(Map<String, dynamic> json) {
  final value = json['monthlyAnchorDay'];
  if (value == null) return null;
  if (value is num && value.isFinite && value % 1 == 0) {
    final day = value.toInt();
    if (day >= 1 && day <= 31) return day;
  }
  throw const FormatException('General event monthly anchor day is invalid.');
}

class GeneralEventRecurrenceRule {
  const GeneralEventRecurrenceRule({
    this.type = GeneralEventRecurrence.none,
    this.interval = 1,
    this.unit = GeneralEventRecurrenceUnit.week,
    this.untilDateIso,
    this.count,
    this.monthlyAnchorDay,
  });

  final GeneralEventRecurrence type;
  final int interval;
  final GeneralEventRecurrenceUnit unit;
  final String? untilDateIso;
  final int? count;
  final int? monthlyAnchorDay;

  bool get isRepeating => type != GeneralEventRecurrence.none;

  int get normalizedInterval => interval < 1 ? 1 : interval;

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'interval': normalizedInterval,
    'unit': unit.value,
    if (untilDateIso != null) 'untilDate': untilDateIso,
    if (count != null) 'count': count,
    if (monthlyAnchorDay != null) 'monthlyAnchorDay': monthlyAnchorDay,
  };

  factory GeneralEventRecurrenceRule.fromJson(Map<String, dynamic> json) {
    final type = parseGeneralEventRecurrence(
      _nullableStringValue(json['type']),
    );
    final legacyUnit = switch (type) {
      GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
      GeneralEventRecurrence.weekly => GeneralEventRecurrenceUnit.week,
      GeneralEventRecurrence.monthly => GeneralEventRecurrenceUnit.month,
      _ => parseGeneralEventRecurrenceUnit(_nullableStringValue(json['unit'])),
    };
    return GeneralEventRecurrenceRule(
      type: type,
      interval: (_intValue(json['interval']) ?? 1).clamp(1, 999).toInt(),
      unit: legacyUnit,
      untilDateIso: _nullableStringValue(json['untilDate']),
      count: _intValue(json['count']),
      monthlyAnchorDay: _decodeMonthlyAnchorDay(json),
    );
  }

  GeneralEventRecurrenceRule copyWith({
    GeneralEventRecurrence? type,
    int? interval,
    GeneralEventRecurrenceUnit? unit,
    Object? untilDateIso = _keepNullable,
    Object? count = _keepNullable,
    Object? monthlyAnchorDay = _keepNullable,
  }) {
    return GeneralEventRecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      unit: unit ?? this.unit,
      untilDateIso: identical(untilDateIso, _keepNullable)
          ? this.untilDateIso
          : untilDateIso as String?,
      count: identical(count, _keepNullable) ? this.count : count as int?,
      monthlyAnchorDay: identical(monthlyAnchorDay, _keepNullable)
          ? this.monthlyAnchorDay
          : monthlyAnchorDay as int?,
    );
  }
}

class GeneralEvent {
  GeneralEvent({
    required this.id,
    this.calendarId = '',
    required this.title,
    required this.startDateTimeIso,
    required this.endDateTimeIso,
    this.isAllDay = false,
    GeneralEventRecurrenceRule? recurrenceRule,
    GeneralEventRecurrence recurrence = GeneralEventRecurrence.none,
    String? recurrenceEndDateIso,
    this.recurrenceExceptionDateIso = const [],
    this.location = '',
    this.notes = '',
    this.colorValue,
    this.reminders = const [],
    GeneralEventReminderBehavior? reminderBehavior,
    this.createdAtIso,
    this.updatedAtIso,
  }) : reminderBehavior =
           reminderBehavior ??
           (reminders.isEmpty
               ? GeneralEventReminderBehavior.disabled
               : GeneralEventReminderBehavior.custom),
       recurrenceRule =
           recurrenceRule ??
           GeneralEventRecurrenceRule(
             type: recurrence,
             unit: switch (recurrence) {
               GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
               GeneralEventRecurrence.monthly =>
                 GeneralEventRecurrenceUnit.month,
               _ => GeneralEventRecurrenceUnit.week,
             },
             untilDateIso: recurrenceEndDateIso,
           );

  final String id;
  final String calendarId;
  final String title;
  final String startDateTimeIso;
  final String endDateTimeIso;
  final bool isAllDay;
  final GeneralEventRecurrenceRule recurrenceRule;
  final List<String> recurrenceExceptionDateIso;
  final String location;
  final String notes;
  final int? colorValue;
  final List<GeneralEventReminder> reminders;
  final GeneralEventReminderBehavior reminderBehavior;
  final String? createdAtIso;
  final String? updatedAtIso;

  GeneralEventRecurrence get recurrence => recurrenceRule.type;

  String? get recurrenceEndDateIso => recurrenceRule.untilDateIso;

  /// Whether this event can have reminders without changing its own policy.
  /// Inherited reminders retain acknowledgements while the default is off.
  bool get hasReminderConfiguration =>
      reminderBehavior == GeneralEventReminderBehavior.inherit ||
      (reminderBehavior == GeneralEventReminderBehavior.custom &&
          reminders.any((item) => item.minutesBefore >= 0));

  List<GeneralEventReminder> resolveReminders(int? defaultMinutesBefore) {
    switch (reminderBehavior) {
      case GeneralEventReminderBehavior.inherit:
        return defaultMinutesBefore == null || defaultMinutesBefore < 0
            ? const []
            : [GeneralEventReminder(minutesBefore: defaultMinutesBefore)];
      case GeneralEventReminderBehavior.disabled:
        return const [];
      case GeneralEventReminderBehavior.custom:
        return reminders.where((item) => item.minutesBefore >= 0).toList();
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'calendarId': calendarId,
      'title': title,
      'start': startDateTimeIso,
      'end': endDateTimeIso,
      'isAllDay': isAllDay,
      'recurrenceRule': recurrenceRule.toJson(),
      'recurrenceExceptionDates': recurrenceExceptionDateIso,
      'location': location,
      'notes': notes,
      'reminderBehavior': reminderBehavior.value,
      'reminders': reminders.map((item) => item.toJson()).toList(),
    };
    if (colorValue != null) {
      json['colorValue'] = colorValue;
    }
    if (createdAtIso != null) {
      json['createdAt'] = createdAtIso;
    }
    if (updatedAtIso != null) {
      json['updatedAt'] = updatedAtIso;
    }
    return json;
  }

  factory GeneralEvent.fromJson(Map<String, dynamic> json) {
    final legacyRecurrence = parseGeneralEventRecurrence(
      _nullableStringValue(json['recurrence']),
    );
    final ruleJson =
        _asStringKeyedMap(json['recurrenceRule']) ??
        <String, dynamic>{
          'type': legacyRecurrence.value,
          if (json['recurrenceEndDate'] != null)
            'untilDate': json['recurrenceEndDate'],
        };
    final remindersJson = _listValue(json['reminders']);
    return GeneralEvent(
      id: _stringValue(json['id']),
      calendarId: _stringValue(json['calendarId']),
      title: _stringValue(json['title']),
      startDateTimeIso: _stringValue(json['start']),
      endDateTimeIso: _stringValue(json['end']),
      isAllDay: _boolValue(json['isAllDay']) ?? false,
      recurrenceRule: GeneralEventRecurrenceRule.fromJson(ruleJson),
      recurrenceExceptionDateIso: _listValue(json['recurrenceExceptionDates'])
          .where((item) => item != null)
          .map((item) => item.toString())
          .toList(),
      location: _stringValue(json['location']),
      notes: _stringValue(json['notes']),
      colorValue: _intValue(json['colorValue']),
      reminderBehavior: _decodeReminderBehavior(json),
      reminders: remindersJson
          .map(_asStringKeyedMap)
          .whereType<Map<String, dynamic>>()
          .map(GeneralEventReminder.fromJson)
          .toList(),
      createdAtIso: _nullableStringValue(json['createdAt']),
      updatedAtIso: _nullableStringValue(json['updatedAt']),
    );
  }

  GeneralEvent copyWith({
    String? id,
    String? calendarId,
    String? title,
    String? startDateTimeIso,
    String? endDateTimeIso,
    bool? isAllDay,
    GeneralEventRecurrenceRule? recurrenceRule,
    GeneralEventRecurrence? recurrence,
    Object? recurrenceEndDateIso = _keepNullable,
    List<String>? recurrenceExceptionDateIso,
    String? location,
    String? notes,
    Object? colorValue = _keepNullable,
    List<GeneralEventReminder>? reminders,
    GeneralEventReminderBehavior? reminderBehavior,
    Object? createdAtIso = _keepNullable,
    Object? updatedAtIso = _keepNullable,
  }) {
    final nextRecurrenceRule =
        recurrenceRule ??
        (recurrence == null && identical(recurrenceEndDateIso, _keepNullable)
            ? this.recurrenceRule
            : this.recurrenceRule.copyWith(
                type: recurrence,
                unit: switch (recurrence ?? this.recurrenceRule.type) {
                  GeneralEventRecurrence.daily =>
                    GeneralEventRecurrenceUnit.day,
                  GeneralEventRecurrence.monthly =>
                    GeneralEventRecurrenceUnit.month,
                  _ => this.recurrenceRule.unit,
                },
                untilDateIso: recurrenceEndDateIso,
              ));
    return GeneralEvent(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      startDateTimeIso: startDateTimeIso ?? this.startDateTimeIso,
      endDateTimeIso: endDateTimeIso ?? this.endDateTimeIso,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: nextRecurrenceRule,
      recurrenceExceptionDateIso:
          recurrenceExceptionDateIso ?? this.recurrenceExceptionDateIso,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      colorValue: identical(colorValue, _keepNullable)
          ? this.colorValue
          : colorValue as int?,
      reminders: reminders ?? this.reminders,
      reminderBehavior:
          reminderBehavior ??
          (reminders == null
              ? this.reminderBehavior
              : reminders.isEmpty
              ? GeneralEventReminderBehavior.disabled
              : GeneralEventReminderBehavior.custom),
      createdAtIso: identical(createdAtIso, _keepNullable)
          ? this.createdAtIso
          : createdAtIso as String?,
      updatedAtIso: identical(updatedAtIso, _keepNullable)
          ? this.updatedAtIso
          : updatedAtIso as String?,
    );
  }

  GeneralEvent normalized({required String fallbackCalendarId}) {
    var start = tryParseStrictIsoDateTime(startDateTimeIso) ?? DateTime.now();
    var end =
        tryParseStrictIsoDateTime(endDateTimeIso) ??
        start.add(const Duration(hours: 1));
    if (isAllDay) {
      start = _nearestCalendarDateBoundary(start);
      end = _nearestCalendarDateBoundary(end);
    }
    if (!end.isAfter(start)) {
      end = isAllDay
          ? calendarDateEndExclusive(start)
          : start.add(const Duration(hours: 1));
    }
    final startDate = normalizeDateOnly(start);
    final parsedUntilDate = tryParseStrictIsoDate(recurrenceRule.untilDateIso);
    final normalizedUntilDate = parsedUntilDate == null
        ? null
        : _formatDateIso(
            calendarDaysBetween(startDate, parsedUntilDate) < 0
                ? startDate
                : parsedUntilDate,
          );
    final normalizedRecurrenceRule = recurrenceRule.copyWith(
      interval: recurrenceRule.interval.clamp(1, 999),
      unit: switch (recurrenceRule.type) {
        GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
        GeneralEventRecurrence.weekly => GeneralEventRecurrenceUnit.week,
        GeneralEventRecurrence.monthly => GeneralEventRecurrenceUnit.month,
        _ => recurrenceRule.unit,
      },
      untilDateIso: normalizedUntilDate,
      count: recurrenceRule.count != null && recurrenceRule.count! > 0
          ? recurrenceRule.count
          : null,
      monthlyAnchorDay:
          (recurrenceRule.type == GeneralEventRecurrence.monthly ||
                  (recurrenceRule.type == GeneralEventRecurrence.custom &&
                      recurrenceRule.unit ==
                          GeneralEventRecurrenceUnit.month)) &&
              recurrenceRule.monthlyAnchorDay != null &&
              recurrenceRule.monthlyAnchorDay! >= 1 &&
              recurrenceRule.monthlyAnchorDay! <= 31
          ? recurrenceRule.monthlyAnchorDay
          : null,
    );
    final normalizedExceptionDates =
        recurrenceExceptionDateIso
            .map(_tryNormalizeDateIso)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final normalizedReminders =
        reminderBehavior == GeneralEventReminderBehavior.custom
        ? reminders.where((item) => item.minutesBefore >= 0).toList()
        : const <GeneralEventReminder>[];
    return copyWith(
      calendarId: calendarId.trim().isEmpty
          ? fallbackCalendarId
          : calendarId.trim(),
      title: title.trim().isEmpty ? 'Untitled event' : title.trim(),
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: end.toIso8601String(),
      recurrenceRule: normalizedRecurrenceRule,
      recurrenceExceptionDateIso: normalizedExceptionDates,
      reminderBehavior:
          reminderBehavior == GeneralEventReminderBehavior.custom &&
              normalizedReminders.isEmpty
          ? GeneralEventReminderBehavior.disabled
          : reminderBehavior,
      reminders: normalizedReminders,
      createdAtIso: _tryNormalizeDateTimeIso(createdAtIso),
      updatedAtIso: _tryNormalizeDateTimeIso(updatedAtIso),
    );
  }
}

DateTime _nearestCalendarDateBoundary(DateTime value) {
  final date = normalizeDateOnly(value);
  if (value.hour >= 12) {
    return nextCalendarDate(date);
  }
  return date;
}

String? _tryNormalizeDateIso(String value) {
  final parsed = tryParseStrictIsoDate(value);
  return parsed == null ? null : _formatDateIso(parsed);
}

String _formatDateIso(DateTime value) =>
    normalizeDateOnly(value).toIso8601String().split('T').first;

String? _tryNormalizeDateTimeIso(String? value) =>
    tryParseStrictIsoDateTime(value)?.toIso8601String();

const Symbol _keepNullable = #keep;
