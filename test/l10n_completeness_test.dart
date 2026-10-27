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
      // New messages supply English and Chinese first; these explicit entries
      // track the remaining translations until they are supplied.
      final allowedFallbacks =
          locale.languageCode == 'en' || locale.languageCode == 'zh'
          ? const <String>{}
          : const {
              'notificationCoverageBlocked',
              'notificationCoverageFailed',
              'schoolWebImportSignOut',
              'schoolWebImportSignOutTitle',
              'schoolWebImportSignOutMessage',
              'schoolWebImportSignOutSuccess',
              'schoolWebImportSignOutFailed',
              'importWarningSkippedUnsupportedTimeZone',
              'icsSkippedTimeZonesReview',
              'icsImportRemainingAction',
              'expandTimelineEvents',
              'timelineEvents',
              'schoolImportEndpointChangeTitle',
              'schoolImportEndpointChangeMessage',
              'schoolImportEndpointChangeConfirm',
              'restoreBackupParserSettingsSummary',
              'backupParserEndpointUnset',
              'periodTimesDayFull',
              'importWarningRecurrenceDateClamped',
            };
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
    });
  }
}
