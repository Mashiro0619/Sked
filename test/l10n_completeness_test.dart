import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';

void main() {
  final template = jsonDecode(
    File('lib/l10n/app_en.arb').readAsStringSync(),
  ) as Map<String, dynamic>;
  final messageKeys = template.keys
      .where((key) => !key.startsWith('@'))
      .toSet();

  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale supplies every offered interface message', () {
      // The day agenda adds English and Chinese copy first. Other languages
      // intentionally use the generator's English fallback for this message.
      final allowedFallbacks =
          locale.languageCode == 'en' || locale.languageCode == 'zh'
          ? const <String>{}
          : const {'studentDayEmpty'};
      final file = File('lib/l10n/app_$locale.arb');
      expect(file.existsSync(), isTrue, reason: 'Missing locale source: $file');
      final messages =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(
        messageKeys
            .difference(messages.keys.toSet())
            .difference(allowedFallbacks),
        isEmpty,
        reason: 'Missing $locale messages would silently fall back to English.',
      );
      for (final key in messageKeys) {
        if (!messages.containsKey(key) && allowedFallbacks.contains(key)) {
          continue;
        }
        expect(messages[key], isA<String>(), reason: '$locale: $key');
        expect(
          (messages[key] as String).trim(),
          isNotEmpty,
          reason: '$locale: $key',
        );
      }
      expect(messages['appTitle'], 'Sked');
      expect(messages['googlePlay'], 'Google Play');
      expect(messages['outlineWidthUnit'], 'px');
      if (allowedFallbacks.contains('studentDayEmpty')) {
        expect(
          lookupAppLocalizations(locale).studentDayEmpty,
          template['studentDayEmpty'],
        );
      }
    });
  }
}
