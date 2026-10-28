import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/agenda_notification_presentation.dart';

Map<String, String> _legacyActions(String name) {
  final values = jsonDecode(
    File('test/fixtures/notification_${name}_before.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return values.map((locale, value) => MapEntry(locale, value as String));
}

const _legacyAliases = {
  'zh-TW': 'zh_Hant',
  'ZH_hAnT_tw': 'zh_Hant',
  'zh-Hans-TW': 'zh_Hant',
  'zh-Hans-HK': 'zh_Hant',
  'zh-MO': 'zh_Hant',
  'zh-Hans-MO': 'zh',
  'zh-CN': 'zh',
  'de-DE': 'de',
  'en-US': 'en',
  'xx-XX': 'en',
  '': 'en',
};

void main() {
  test('snooze labels retain every pre-migration locale value', () {
    final expected = _legacyActions('snoozeAction');
    expect(expected, hasLength(26));
    expect(
      expected.keys.toSet(),
      AppLocalizations.supportedLocales.map((locale) => '$locale').toSet(),
    );
    for (final entry in expected.entries) {
      expect(
        notificationText(entry.key).snoozeAction,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('snooze labels retain legacy region and fallback behavior', () {
    final expected = _legacyActions('snoozeAction');
    for (final entry in _legacyAliases.entries) {
      expect(
        notificationText(entry.key).snoozeAction,
        expected[entry.value],
        reason: entry.key,
      );
    }
  });

  test(
    'snooze labels are available in an isolate without widget context',
    () async {
      final expected = _legacyActions('snoozeAction');
      final codes = expected.keys.toList();
      final actual = await Isolate.run(
        () => [for (final code in codes) notificationText(code).snoozeAction],
      );
      expect(actual, orderedEquals(expected.values));
    },
  );
}
