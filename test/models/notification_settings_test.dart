import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/course_reminder_settings.dart';
import 'package:sked/models/notification_settings.dart';

void main() {
  group('NotificationSettings', () {
    test('round trips configured defaults and lock-screen privacy', () {
      const settings = NotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
        generalDefaultMinutesBefore: 30,
        lockScreenShowTitles: true,
      );

      expect(NotificationSettings.fromJson(settings.toJson()), settings);
    });

    test('missing and invalid optional offsets normalize to disabled', () {
      expect(NotificationSettings.fromJson(const {}).enabled, isFalse);
      expect(
        NotificationSettings.fromJson({
          'courseDefaultMinutesBefore': -1,
          'generalDefaultMinutesBefore': '10',
        }),
        const NotificationSettings(),
      );
    });

    test('copyWith retains, clears, and normalizes nullable defaults', () {
      const configured = NotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
        generalDefaultMinutesBefore: 30,
        lockScreenShowTitles: true,
      );

      final retained = configured.copyWith(enabled: false);
      expect(retained.enabled, isFalse);
      expect(retained.courseDefaultMinutesBefore, 10);
      expect(retained.generalDefaultMinutesBefore, 30);
      expect(retained.lockScreenShowTitles, isTrue);

      final cleared = retained.copyWith(
        courseDefaultMinutesBefore: null,
        generalDefaultMinutesBefore: -1,
        lockScreenShowTitles: false,
      );
      expect(cleared.courseDefaultMinutesBefore, isNull);
      expect(cleared.generalDefaultMinutesBefore, isNull);
      expect(cleared.lockScreenShowTitles, isFalse);
      expect(cleared, const NotificationSettings(enabled: false));
      expect(
        cleared.hashCode,
        const NotificationSettings(enabled: false).hashCode,
      );
    });

    test(
      'decodes integral numeric offsets but ignores non-integral values',
      () {
        final decoded = NotificationSettings.fromJson({
          'enabled': true,
          'courseDefaultMinutesBefore': 15.0,
          'generalDefaultMinutesBefore': 20.5,
          'lockScreenShowTitles': 'not-a-bool',
        });

        expect(decoded.enabled, isTrue);
        expect(decoded.courseDefaultMinutesBefore, 15);
        expect(decoded.generalDefaultMinutesBefore, isNull);
        expect(decoded.lockScreenShowTitles, isFalse);
      },
    );
  });

  group('CourseReminderSettings', () {
    test('old course data defaults to inherited reminders', () {
      expect(
        CourseReminderSettings.fromJson(const {}),
        const CourseReminderSettings(),
      );
    });

    test('custom reminders retain a non-negative offset', () {
      const settings = CourseReminderSettings(
        behavior: CourseReminderBehavior.custom,
        minutesBefore: 15,
      );
      expect(CourseReminderSettings.fromJson(settings.toJson()), settings);
    });

    test('custom reminders without an offset fall back to inherited', () {
      expect(
        const CourseReminderSettings(behavior: CourseReminderBehavior.custom)
            .normalized(),
        const CourseReminderSettings(),
      );
    });

    test('behavior parsing exposes all three reminder states', () {
      expect(
        parseCourseReminderBehavior(CourseReminderBehavior.inherit.value),
        CourseReminderBehavior.inherit,
      );
      expect(
        parseCourseReminderBehavior(CourseReminderBehavior.disabled.value),
        CourseReminderBehavior.disabled,
      );
      expect(
        parseCourseReminderBehavior(CourseReminderBehavior.custom.value),
        CourseReminderBehavior.custom,
      );
      expect(
        parseCourseReminderBehavior('unknown'),
        CourseReminderBehavior.inherit,
      );
    });

    test('normalizes stale offsets and preserves explicit custom values', () {
      const disabled = CourseReminderSettings(
        behavior: CourseReminderBehavior.disabled,
        minutesBefore: 30,
      );
      expect(disabled.isDisabled, isTrue);
      expect(disabled.isInherited, isFalse);
      expect(disabled.isCustom, isFalse);
      expect(disabled.toJson(), {'behavior': 'disabled', 'minutesBefore': 30});
      expect(
        disabled.normalized(),
        const CourseReminderSettings(behavior: CourseReminderBehavior.disabled),
      );

      final custom = CourseReminderSettings.fromJson({
        'behavior': 'custom',
        'minutesBefore': 20.0,
      });
      expect(custom.isCustom, isTrue);
      expect(custom.minutesBefore, 20);
      expect(
        custom.copyWith(minutesBefore: null),
        const CourseReminderSettings(),
      );
      expect(
        custom.copyWith(behavior: CourseReminderBehavior.disabled),
        const CourseReminderSettings(behavior: CourseReminderBehavior.disabled),
      );

      expect(
        CourseReminderSettings.fromJson({
          'behavior': 'custom',
          'minutesBefore': 20.5,
        }),
        const CourseReminderSettings(),
      );
      expect(
        CourseReminderSettings.fromJson({
          'behavior': 'custom',
          'minutesBefore': -1,
        }),
        const CourseReminderSettings(),
      );
    });
  });
}
