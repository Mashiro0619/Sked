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
    'zh' => DeveloperNotificationText(
      title: traditional ? 'Sked 測試通知' : 'Sked 测试通知',
      body: isCourse
          ? (traditional ? '課程提醒通道正常。' : '课程提醒通道正常。')
          : (traditional ? '日程提醒通道正常。' : '日程提醒通道正常。'),
    ),
    'ja' => DeveloperNotificationText(
      title: 'Sked 通知テスト',
      body: isCourse ? '授業リマインダーの通知チャンネルは正常です。' : '予定リマインダーの通知チャンネルは正常です。',
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
  final language = locale.languageCode.toLowerCase();
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode?.toLowerCase() == 'tw' ||
          locale.countryCode?.toLowerCase() == 'hk');
  final snoozeAction = switch (language) {
    'bg' => 'Отложи с 10 минути',
    'cs' => 'Odložit o 10 minut',
    'da' => 'Udsæt 10 minutter',
    'zh' => traditional ? '延後 10 分鐘' : '延后 10 分钟',
    'de' => '10 Minuten verschieben',
    'et' => 'Lükka 10 minutit edasi',
    'es' => 'Posponer 10 minutos',
    'fi' => 'Siirrä 10 minuuttia',
    'fr' => 'Reporter de 10 minutes',
    'hi' => '10 मिनट बाद याद दिलाएं',
    'hu' => 'Elhalasztás 10 perccel',
    'it' => 'Posticipa di 10 minuti',
    'ja' => '10 分後に再通知',
    'ko' => '10분 후 다시 알림',
    'nl' => '10 minuten uitstellen',
    'pl' => 'Odłóż o 10 minut',
    'pt' => 'Adiar 10 minutos',
    'ro' => 'Amână 10 minute',
    'ru' => 'Отложить на 10 минут',
    'sl' => 'Preloži za 10 minut',
    'sv' => 'Skjut upp 10 minuter',
    'th' => 'เลื่อน 10 นาที',
    'vi' => 'Hoãn 10 phút',
    _ => 'Snooze 10 minutes',
  };
  final handledAction = switch (language) {
    'bg' => 'Маркиране като обработено',
    'cs' => 'Označit jako vyřízené',
    'da' => 'Markér som håndteret',
    'de' => 'Als erledigt markieren',
    'el' => 'Σήμανση ως διεκπεραιωμένο',
    'es' => 'Marcar como gestionado',
    'et' => 'Märgi käsitletuks',
    'fi' => 'Merkitse käsitellyksi',
    'fr' => 'Marquer comme traité',
    'hi' => 'पूर्ण के रूप में चिह्नित करें',
    'hu' => 'Megjelölés kezeltként',
    'it' => 'Segna come gestito',
    'ja' => '処理済みとしてマーク',
    'ko' => '처리됨으로 표시',
    'nl' => 'Als afgehandeld markeren',
    'pl' => 'Oznacz jako obsłużone',
    'pt' => 'Marcar como tratado',
    'ro' => 'Marchează ca finalizat',
    'ru' => 'Отметить выполненным',
    'sl' => 'Označi kot obdelano',
    'sv' => 'Markera som hanterad',
    'th' => 'ทำเครื่องหมายว่าจัดการแล้ว',
    'vi' => 'Đánh dấu đã xử lý',
    'zh' => traditional ? '標記已處理' : '标记已处理',
    _ => l10n.markReminderHandled,
  };
  return NotificationText(
    allDay: l10n.allDay,
    snoozeAction: snoozeAction,
    handledAction: handledAction,
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
