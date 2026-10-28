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
  final l10n = _notificationActionLocalizations(notificationLocale(localeCode));
  return DeveloperNotificationText(
    title: l10n.developerTestNotificationTitle,
    body: channel == AgendaNotificationTestChannel.course
        ? l10n.developerTestNotificationCourseBody
        : l10n.developerTestNotificationScheduleBody,
  );
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
