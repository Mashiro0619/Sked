/// How a course resolves its reminder schedule.
///
/// `inherit` uses the application-wide course default, `disabled` suppresses
/// reminders for this course, and `custom` uses [minutesBefore].
enum CourseReminderBehavior {
  inherit('inherit'),
  disabled('disabled'),
  custom('custom');

  const CourseReminderBehavior(this.value);

  final String value;
}

CourseReminderBehavior parseCourseReminderBehavior(String? value) {
  for (final behavior in CourseReminderBehavior.values) {
    if (behavior.value == value) return behavior;
  }
  return CourseReminderBehavior.inherit;
}

int? _decodeIntegralMinutes(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }
  return null;
}

const Object _keepNullable = #keep;

class CourseReminderSettings {
  const CourseReminderSettings({
    this.behavior = CourseReminderBehavior.inherit,
    this.minutesBefore,
  });

  final CourseReminderBehavior behavior;
  final int? minutesBefore;

  bool get isInherited => behavior == CourseReminderBehavior.inherit;
  bool get isDisabled => behavior == CourseReminderBehavior.disabled;
  bool get isCustom => behavior == CourseReminderBehavior.custom;

  Map<String, dynamic> toJson() => {
    'behavior': behavior.value,
    if (minutesBefore != null) 'minutesBefore': minutesBefore,
  };

  /// Decodes user/import data permissively, matching the rest of the model
  /// layer. Strict on-disk validation is performed by AppData's storage
  /// snapshot validator.
  factory CourseReminderSettings.fromJson(Map<String, dynamic> json) {
    final behavior = parseCourseReminderBehavior(
      json['behavior'] is String ? json['behavior'] as String : null,
    );
    final minutes = _decodeIntegralMinutes(json['minutesBefore']);
    return CourseReminderSettings(
      behavior: behavior,
      minutesBefore: minutes,
    ).normalized();
  }

  CourseReminderSettings copyWith({
    CourseReminderBehavior? behavior,
    Object? minutesBefore = _keepNullable,
  }) {
    return CourseReminderSettings(
      behavior: behavior ?? this.behavior,
      minutesBefore: identical(minutesBefore, _keepNullable)
          ? this.minutesBefore
          : minutesBefore as int?,
    ).normalized();
  }

  CourseReminderSettings normalized() {
    switch (behavior) {
      case CourseReminderBehavior.inherit:
      case CourseReminderBehavior.disabled:
        return CourseReminderSettings(behavior: behavior);
      case CourseReminderBehavior.custom:
        final minutes = minutesBefore;
        if (minutes == null || minutes < 0) {
          return const CourseReminderSettings(
            behavior: CourseReminderBehavior.inherit,
          );
        }
        return CourseReminderSettings(
          behavior: CourseReminderBehavior.custom,
          minutesBefore: minutes,
        );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is CourseReminderSettings &&
        other.behavior == behavior &&
        other.minutesBefore == minutesBefore;
  }

  @override
  int get hashCode => Object.hash(behavior, minutesBefore);
}
