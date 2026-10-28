import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/agenda_notification_presentation.dart';
import 'package:sked/services/agenda_notification_contract.dart';

Map<String, String> _legacyActions(String name) {
  final values = jsonDecode(
    File('test/fixtures/notification_${name}_before.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return values.map((locale, value) => MapEntry(locale, value as String));
}

Map<String, List<String>> _legacyDeveloperCopy() {
  final values = jsonDecode(
    File('test/fixtures/notification_developer_before.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return values.map(
    (locale, value) =>
        MapEntry(locale, (value as List<dynamic>).cast<String>()),
  );
}

List<String> _developerCopy(String code) {
  final course = developerNotificationText(
    code,
    AgendaNotificationTestChannel.course,
  );
  final schedule = developerNotificationText(
    code,
    AgendaNotificationTestChannel.schedule,
  );
  return [course.title, course.body, schedule.title, schedule.body];
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

  test('handled labels retain every pre-migration locale value', () {
    final expected = _legacyActions('handledAction');
    expect(
      expected.keys.toSet(),
      AppLocalizations.supportedLocales.map((locale) => '$locale').toSet(),
    );
    for (final entry in expected.entries) {
      expect(
        notificationText(entry.key).handledAction,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('handled labels retain legacy region and fallback behavior', () {
    final expected = _legacyActions('handledAction');
    for (final entry in _legacyAliases.entries) {
      expect(
        notificationText(entry.key).handledAction,
        expected[entry.value],
        reason: entry.key,
      );
    }
  });

  test(
    'handled labels are available in an isolate without widget context',
    () async {
      final expected = _legacyActions('handledAction');
      final codes = expected.keys.toList();
      final actual = await Isolate.run(
        () => [for (final code in codes) notificationText(code).handledAction],
      );
      expect(actual, orderedEquals(expected.values));
    },
  );

  test('developer notifications retain every pre-migration locale value', () {
    final expected = _legacyDeveloperCopy();
    expect(
      expected.keys.toSet(),
      AppLocalizations.supportedLocales.map((locale) => '$locale').toSet(),
    );
    for (final entry in expected.entries) {
      final value = entry.value;
      expect(_developerCopy(entry.key), [
        value[0],
        value[1],
        value[0],
        value[2],
      ], reason: entry.key);
    }
  });

  test(
    'developer notifications retain legacy region and fallback behavior',
    () {
      final expected = _legacyDeveloperCopy();
      for (final entry in _legacyAliases.entries) {
        final value = expected[entry.value]!;
        expect(_developerCopy(entry.key), [
          value[0],
          value[1],
          value[0],
          value[2],
        ], reason: entry.key);
      }
    },
  );

  test('developer notifications are available in an isolate without widget context', () async {
    final expected = _legacyDeveloperCopy();
    final codes = expected.keys.toList();
    final actual = await Isolate.run(
      () => [for (final code in codes) _developerCopy(code)],
    );
    expect(actual, [
      for (final value in expected.values)
        [value[0], value[1], value[0], value[2]],
    ]);
  });
}
