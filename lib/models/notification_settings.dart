/// Application-wide settings used by the platform reminder and widget
/// coordinators.  A null default offset means that no reminder is configured
/// for that source by default.
class NotificationSettings {
  static const Object keep = #keepNotificationValue;

  const NotificationSettings({
    this.enabled = false,
    this.courseDefaultMinutesBefore,
    this.generalDefaultMinutesBefore,
    this.lockScreenShowTitles = false,
  });

  final bool enabled;
  final int? courseDefaultMinutesBefore;
  final int? generalDefaultMinutesBefore;
  final bool lockScreenShowTitles;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'courseDefaultMinutesBefore': courseDefaultMinutesBefore,
    'generalDefaultMinutesBefore': generalDefaultMinutesBefore,
    'lockScreenShowTitles': lockScreenShowTitles,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      courseDefaultMinutesBefore: _decodeNotificationMinutes(
        json['courseDefaultMinutesBefore'],
      ),
      generalDefaultMinutesBefore: _decodeNotificationMinutes(
        json['generalDefaultMinutesBefore'],
      ),
      lockScreenShowTitles: json['lockScreenShowTitles'] is bool
          ? json['lockScreenShowTitles'] as bool
          : false,
    ).normalized();
  }

  NotificationSettings copyWith({
    bool? enabled,
    Object? courseDefaultMinutesBefore = keep,
    Object? generalDefaultMinutesBefore = keep,
    bool? lockScreenShowTitles,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      courseDefaultMinutesBefore: identical(courseDefaultMinutesBefore, keep)
          ? this.courseDefaultMinutesBefore
          : courseDefaultMinutesBefore as int?,
      generalDefaultMinutesBefore: identical(generalDefaultMinutesBefore, keep)
          ? this.generalDefaultMinutesBefore
          : generalDefaultMinutesBefore as int?,
      lockScreenShowTitles: lockScreenShowTitles ?? this.lockScreenShowTitles,
    ).normalized();
  }

  NotificationSettings normalized() {
    return NotificationSettings(
      enabled: enabled,
      courseDefaultMinutesBefore: _normalizeNotificationMinutes(
        courseDefaultMinutesBefore,
      ),
      generalDefaultMinutesBefore: _normalizeNotificationMinutes(
        generalDefaultMinutesBefore,
      ),
      lockScreenShowTitles: lockScreenShowTitles,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationSettings &&
        other.enabled == enabled &&
        other.courseDefaultMinutesBefore == courseDefaultMinutesBefore &&
        other.generalDefaultMinutesBefore == generalDefaultMinutesBefore &&
        other.lockScreenShowTitles == lockScreenShowTitles;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    courseDefaultMinutesBefore,
    generalDefaultMinutesBefore,
    lockScreenShowTitles,
  );
}

int? _decodeNotificationMinutes(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }
  return null;
}

int? _normalizeNotificationMinutes(int? value) {
  if (value == null || value < 0) return null;
  return value;
}
