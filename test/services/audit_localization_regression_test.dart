import '../support/agenda_notification_memory.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_presentation.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/agenda_notification_service.dart';

void main() {
  test('every offered UI language has its own notification snooze action', () {
    final english = notificationText('en').snoozeAction;
    for (final locale in AppLocalizations.supportedLocales) {
      final code = localeCodeFromLocale(locale);
      final action = notificationText(code).snoozeAction;
      expect(action, isNotEmpty, reason: code);
      if (code != 'en') expect(action, isNot(english), reason: code);
    }
    expect(notificationText('el').snoozeAction, 'Αναβολή για 10 λεπτά');
  });

  test('every offered UI language supplies every language subtitle', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final options = supportedLanguageOptions(lookupAppLocalizations(locale));
      expect(options, hasLength(AppLocalizations.supportedLocales.length));
      for (final option in options) {
        expect(option.nativeName, isNotEmpty);
        expect(option.localizedName, isNotEmpty);
        expect(
          languageMetadataForLocaleCode(option.code)
              .localizedNames[localeCodeFromLocale(locale)],
          isNotEmpty,
          reason: '${option.code} in $locale must not rely on a fallback',
        );
      }
    }
  });

  test('all locales own notification channel names descriptions and developer text', () {
    final descriptors = [
      const StudentAgendaSource().descriptor,
      const GeneralAgendaSource().descriptor,
    ];
    final english = developerNotificationText(
      'en',
      AgendaNotificationTestChannel.course,
    );
    for (final locale in AppLocalizations.supportedLocales) {
      final code = localeCodeFromLocale(locale);
      final normalized = code.toLowerCase().replaceAll('_', '-');
      for (final descriptor in descriptors) {
        expect(
          descriptor.localizedChannelNames[normalized],
          isNotEmpty,
          reason: '$code name',
        );
        expect(
          descriptor.localizedChannelDescriptions[normalized],
          isNotEmpty,
          reason: '$code description',
        );
      }
      final text = developerNotificationText(
        code,
        AgendaNotificationTestChannel.course,
      );
      expect(text.title, isNotEmpty);
      expect(text.body, isNotEmpty);
      if (code != 'en') expect(text.title, isNot(english.title), reason: code);
    }
    expect(
      const StudentAgendaSource().descriptor.channelId,
      'sked_course_reminders',
    );
    expect(
      const GeneralAgendaSource().descriptor.channelId,
      'sked_schedule_reminders',
    );
    expect(
      const StudentAgendaSource().descriptor.channelNameFor('zh-HK'),
      '課程提醒',
    );
  });

  test(
    'new default calendars follow locale while stored names stay intact',
    () {
      final chinese = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'zh',
      );
      expect(chinese.generalMode.schedules.single.name, '我的日历');
      expect(createDefaultGeneralSchedule(localeCode: 'zh-Hant').name, '我的日曆');
      final saved = chinese.copyWith(
        generalMode: chinese.generalMode.copyWith(
          schedules: [
            chinese.generalMode.schedules.single.copyWith(name: 'My calendar'),
          ],
        ),
      );
      expect(
        AppData.decode(saved.encode()).generalMode.schedules.single.name,
        'My calendar',
      );
      final custom = saved.copyWith(
        generalMode: saved.generalMode.copyWith(
          schedules: [
            saved.generalMode.schedules.single.copyWith(
              name: 'Family and work',
            ),
          ],
        ),
      );
      expect(
        AppData.decode(custom.encode()).generalMode.schedules.single.name,
        'Family and work',
      );
      const service = GeneralCalendarService();
      final added = service.addSchedule(chinese.generalMode, localeCode: 'de');
      expect(added.schedules.last.name, 'Mein Kalender');
      final deleted = service.deleteSchedule(
        chinese.generalMode,
        chinese.generalMode.activeScheduleId,
        localeCode: 'ja',
      );
      expect(deleted.schedules.single.name, 'マイカレンダー');
      expect(
        GeneralScheduleData.fromJson({
          'schedules': [],
        }, localeCode: 'zh').schedules.single.name,
        '我的日历',
      );
    },
  );

  test('English usage summary handles singular and plural independently', () {
    final strings = lookupAppLocalizations(appLocaleFromCode('en'));
    expect(
      strings.periodTimeSetUsageSummary(1, 1),
      '1 period · Used by 1 timetable',
    );
    expect(
      strings.periodTimeSetUsageSummary(0, 2),
      '0 periods · Used by 2 timetables',
    );
    expect(
      strings.periodTimeSetUsageSummary(2, 0),
      '2 periods · Used by 0 timetables',
    );
  });

  test('changing locale refreshes existing notification metadata without changing channel identity', () async {
    final now = DateTime(2026, 10, 23, 8);
    final gateway = MemoryAgendaNotificationGateway();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      now: () => now,
    );
    addTearDown(service.dispose);
    final base = buildInitialAppData(buildDefaultPeriodTimes());
    final calendar = base.generalMode.schedules.single;
    final data = base.copyWith(
      activeMode: AppMode.general,
      notificationSettings: const NotificationSettings(enabled: true),
      generalMode: base.generalMode.copyWith(
        schedules: [
          calendar.copyWith(
            events: [
              GeneralEvent(
                id: 'localized-reminder',
                calendarId: calendar.id,
                title: 'Calendar event',
                startDateTimeIso: '2026-10-23T10:00:00.000',
                endDateTimeIso: '2026-10-23T11:00:00.000',
                reminders: const [GeneralEventReminder(minutesBefore: 5)],
                reminderBehavior: GeneralEventReminderBehavior.custom,
              ),
            ],
          ),
        ],
      ),
    );
    await service.reconcile(data);
    final original = gateway.scheduled.values.single;
    expect(original.channelName, 'Schedule reminders');
    await service.reconcile(data.copyWith(localeCode: 'hi'));
    final changed = gateway.scheduled.values.single;
    expect(changed.key, original.key);
    expect(changed.channelId, original.channelId);
    expect(changed.channelName, 'इवेंट रिमाइंडर');
    expect(changed.channelDescription, 'कैलेंडर इवेंट के रिमाइंडर');
    expect(changed.localeCode, 'hi');
  });
}
