import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import 'agenda_projection_service.dart';
import 'agenda_notification_contract.dart';

class NotificationText {
  const NotificationText({
    required this.allDay,
    required this.snoozeAction,
    required this.handledAction,
  });

  final String allDay;
  final String snoozeAction;
  final String handledAction;
}

class DeveloperNotificationText {
  const DeveloperNotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

DeveloperNotificationText developerNotificationText(
  String localeCode,
  AgendaNotificationTestChannel channel,
) {
  final locale = notificationLocale(localeCode);
  final language = locale.languageCode.toLowerCase();
  final traditional =
      language == 'zh' &&
      (locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode?.toLowerCase() == 'tw' ||
          locale.countryCode?.toLowerCase() == 'hk');
  final isCourse = channel == AgendaNotificationTestChannel.course;
  return switch (language) {
    'bg' => DeveloperNotificationText(
      title: 'Тестово известие на Sked',
      body: isCourse
          ? 'Каналът за напомняния за курсове работи.'
          : 'Каналът за напомняния за събития работи.',
    ),
    'cs' => DeveloperNotificationText(
      title: 'Test oznámení Sked',
      body: isCourse
          ? 'Kanál připomenutí kurzů funguje.'
          : 'Kanál připomenutí událostí funguje.',
    ),
    'da' => DeveloperNotificationText(
      title: 'Sked-testmeddelelse',
      body: isCourse
          ? 'Kanalen til kursuspåmindelser virker.'
          : 'Kanalen til begivenhedspåmindelser virker.',
    ),
    'de' => DeveloperNotificationText(
      title: 'Sked-Benachrichtigungstest',
      body: isCourse
          ? 'Der Kanal für Kurserinnerungen funktioniert.'
          : 'Der Kanal für Terminerinnerungen funktioniert.',
    ),
    'el' => DeveloperNotificationText(
      title: 'Δοκιμαστική ειδοποίηση Sked',
      body: isCourse
          ? 'Το κανάλι υπενθυμίσεων μαθημάτων λειτουργεί.'
          : 'Το κανάλι υπενθυμίσεων συμβάντων λειτουργεί.',
    ),
    'es' => DeveloperNotificationText(
      title: 'Prueba de notificaciones de Sked',
      body: isCourse
          ? 'El canal de recordatorios de cursos funciona.'
          : 'El canal de recordatorios de eventos funciona.',
    ),
    'et' => DeveloperNotificationText(
      title: 'Skedi testteavitus',
      body: isCourse
          ? 'Kursuste meeldetuletuste kanal töötab.'
          : 'Sündmuste meeldetuletuste kanal töötab.',
    ),
    'fi' => DeveloperNotificationText(
      title: 'Skedin testi-ilmoitus',
      body: isCourse
          ? 'Kurssimuistutusten kanava toimii.'
          : 'Tapahtumamuistutusten kanava toimii.',
    ),
    'fr' => DeveloperNotificationText(
      title: 'Test de notification Sked',
      body: isCourse
          ? 'Le canal de rappel des cours fonctionne.'
          : 'Le canal de rappel des événements fonctionne.',
    ),
    'hi' => DeveloperNotificationText(
      title: 'Sked परीक्षण सूचना',
      body: isCourse
          ? 'पाठ्यक्रम रिमाइंडर चैनल काम कर रहा है।'
          : 'इवेंट रिमाइंडर चैनल काम कर रहा है।',
    ),
    'hu' => DeveloperNotificationText(
      title: 'Sked tesztértesítés',
      body: isCourse
          ? 'A kurzusemlékeztetők csatornája működik.'
          : 'Az eseményemlékeztetők csatornája működik.',
    ),
    'it' => DeveloperNotificationText(
      title: 'Notifica di prova di Sked',
      body: isCourse
          ? 'Il canale dei promemoria dei corsi funziona.'
          : 'Il canale dei promemoria degli eventi funziona.',
    ),
    'ja' => DeveloperNotificationText(
      title: 'Sked 通知テスト',
      body: isCourse ? '授業リマインダーの通知チャンネルは正常です。' : '予定リマインダーの通知チャンネルは正常です。',
    ),
    'ko' => DeveloperNotificationText(
      title: 'Sked 알림 테스트',
      body: isCourse ? '수업 알림 채널이 정상적으로 작동합니다.' : '일정 알림 채널이 정상적으로 작동합니다.',
    ),
    'nl' => DeveloperNotificationText(
      title: 'Sked-testmelding',
      body: isCourse
          ? 'Het kanaal voor cursusherinneringen werkt.'
          : 'Het kanaal voor afspraakherinneringen werkt.',
    ),
    'pl' => DeveloperNotificationText(
      title: 'Powiadomienie testowe Sked',
      body: isCourse
          ? 'Kanał przypomnień o kursach działa.'
          : 'Kanał przypomnień o wydarzeniach działa.',
    ),
    'pt' => DeveloperNotificationText(
      title: 'Notificação de teste do Sked',
      body: isCourse
          ? 'O canal de lembretes de cursos está a funcionar.'
          : 'O canal de lembretes de eventos está a funcionar.',
    ),
    'ro' => DeveloperNotificationText(
      title: 'Notificare de test Sked',
      body: isCourse
          ? 'Canalul de mementouri pentru cursuri funcționează.'
          : 'Canalul de mementouri pentru evenimente funcționează.',
    ),
    'ru' => DeveloperNotificationText(
      title: 'Тестовое уведомление Sked',
      body: isCourse
          ? 'Канал напоминаний о курсах работает.'
          : 'Канал напоминаний о событиях работает.',
    ),
    'sl' => DeveloperNotificationText(
      title: 'Preizkusno obvestilo Sked',
      body: isCourse
          ? 'Kanal opomnikov za predmete deluje.'
          : 'Kanal opomnikov za dogodke deluje.',
    ),
    'sv' => DeveloperNotificationText(
      title: 'Sked-testavisering',
      body: isCourse
          ? 'Kanalen för kurspåminnelser fungerar.'
          : 'Kanalen för händelsepåminnelser fungerar.',
    ),
    'th' => DeveloperNotificationText(
      title: 'การแจ้งเตือนทดสอบ Sked',
      body: isCourse
          ? 'ช่องการเตือนวิชาเรียนทำงานเป็นปกติ'
          : 'ช่องการเตือนกิจกรรมทำงานเป็นปกติ',
    ),
    'vi' => DeveloperNotificationText(
      title: 'Thông báo thử nghiệm Sked',
      body: isCourse
          ? 'Kênh nhắc nhở môn học đang hoạt động.'
          : 'Kênh nhắc nhở sự kiện đang hoạt động.',
    ),
    'zh' => DeveloperNotificationText(
      title: traditional ? 'Sked 測試通知' : 'Sked 测试通知',
      body: isCourse
          ? (traditional ? '課程提醒通道正常。' : '课程提醒通道正常。')
          : (traditional ? '日程提醒通道正常。' : '日程提醒通道正常。'),
    ),
    _ => DeveloperNotificationText(
      title: 'Sked notification test',
      body: isCourse
          ? 'The course reminder channel is working.'
          : 'The schedule reminder channel is working.',
    ),
  };
}

NotificationText notificationText(String localeCode) {
  final locale = notificationLocale(localeCode);
  final l10n = lookupNotificationLocalizations(locale);
  final actions = _notificationActionLocalizations(locale);
  return NotificationText(
    allDay: l10n.allDay,
    snoozeAction: actions.notificationSnoozeAction,
    handledAction: actions.notificationHandledAction,
  );
}

AppLocalizations _notificationActionLocalizations(Locale locale) {
  // Keep legacy region aliases, including an explicit Hans script combined
  // with TW/HK, consistent with the notification labels they already use.
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode?.toLowerCase() == 'tw' ||
          locale.countryCode?.toLowerCase() == 'hk');
  return lookupNotificationLocalizations(
    traditional
        ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
        : locale,
  );
}

AppLocalizations lookupNotificationLocalizations(Locale locale) {
  try {
    return lookupAppLocalizations(locale);
  } on FlutterError {
    // Imported/legacy data may contain a locale that this build no longer
    // ships. Notifications must still be schedulable, so use English copy
    // rather than letting one bad locale abort the entire reconcile.
    return lookupAppLocalizations(const Locale('en'));
  }
}

String notificationChannelName(
  AgendaSourceDescriptor descriptor,
  String localeCode,
) => descriptor.channelNameFor(localeCode);

String notificationChannelDescription(
  AgendaSourceDescriptor descriptor,
  String localeCode,
) => descriptor.channelDescriptionFor(localeCode);

Locale notificationLocale(String code) {
  final parts = code.trim().replaceAll('_', '-').split('-');
  final language = parts.isEmpty || parts.first.isEmpty ? 'en' : parts.first;
  String? script;
  String? country;
  for (final part in parts.skip(1)) {
    if (part.length == 4 && script == null) {
      script = part[0].toUpperCase() + part.substring(1).toLowerCase();
    } else if (part.length == 2 && country == null) {
      country = part.toUpperCase();
    }
  }
  return Locale.fromSubtags(
    languageCode: language.toLowerCase(),
    // Android commonly reports Traditional Chinese as zh-TW/zh-HK without
    // an explicit script. Map those regions to the generated zh-Hant
    // localization so action labels do not fall back to Simplified Chinese.
    scriptCode:
        script ??
        (language.toLowerCase() == 'zh' &&
                const {'TW', 'HK', 'MO'}.contains(country)
            ? 'Hant'
            : null),
    countryCode: country,
  );
}

String notificationTwoDigits(int value) => value.toString().padLeft(2, '0');
