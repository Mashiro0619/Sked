import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';

import '../tool/l10n/translation_policy.dart';
import '../tool/l10n/arb_audit.dart';

void main() {
  final template = readArbMessages(File('lib/l10n/app_en.arb'));

  test('the generated language list matches the explicit offered set', () {
    expect(
      AppLocalizations.supportedLocales
          .map((locale) => locale.toString())
          .toSet(),
      offeredLocaleCodes,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale supplies every offered interface message', () {
      final allowedFallbacks = allowedFallbacksForLocale(locale.toString());
      final file = File('lib/l10n/app_$locale.arb');
      expect(file.existsSync(), isTrue, reason: 'Missing locale source: $file');
      final messages = readArbMessages(file);
      final issues = auditArbLocale(
        locale: locale.toString(),
        template: template,
        messages: messages,
        allowedFallbacks: allowedFallbacks,
      );
      expect(issues, isEmpty, reason: issues.join('\n'));
      expect(messages['appTitle'], 'Sked');
      expect(messages['googlePlay'], 'Google Play');
      expect(messages['outlineWidthUnit'], 'px');
    });
  }
}
