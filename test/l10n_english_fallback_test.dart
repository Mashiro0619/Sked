import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_localizations_en.dart';
import 'package:sked/l10n/app_localizations_nl.dart';

import '../tool/l10n/translation_policy.dart';

Map<String, dynamic> _source(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final english = AppLocalizationsEn();
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == 'en' || locale.languageCode == 'zh') continue;
    test('$locale uses the current English assistant fallback', () {
      final messages = lookupAppLocalizations(locale);
      expect(
        messages.assistantPreviewDescription,
        isNot(isIn(retiredEnglishMessages['assistantPreviewDescription']!)),
      );
      if (!_source('$locale').containsKey('assistantPreviewDescription')) {
        expect(
          messages.assistantPreviewDescription,
          english.assistantPreviewDescription,
        );
      }
    });
  }

  test(
    'untranslated Dutch import and privacy messages follow current English',
    () {
      final dutch = AppLocalizationsNl();
      final source = _source('nl');
      final actual = {
        'exportTimetableText': dutch.exportTimetableText,
        'importTimetableText': dutch.importTimetableText,
        'privacyPolicyEntryDesc': dutch.privacyPolicyEntryDesc,
        'schoolHtmlImportEmpty': dutch.schoolHtmlImportEmpty,
        'schoolHtmlImportEntry': dutch.schoolHtmlImportEntry,
        'schoolHtmlImportEntryDesc': dutch.schoolHtmlImportEntryDesc,
        'schoolHtmlImportHtmlHint': dutch.schoolHtmlImportHtmlHint,
        'schoolHtmlImportHtmlLabel': dutch.schoolHtmlImportHtmlLabel,
        'schoolHtmlImportNonHtmlHint': dutch.schoolHtmlImportNonHtmlHint,
        'schoolHtmlImportPageTitle': dutch.schoolHtmlImportPageTitle,
      };
      final expected = {
        'exportTimetableText': english.exportTimetableText,
        'importTimetableText': english.importTimetableText,
        'privacyPolicyEntryDesc': english.privacyPolicyEntryDesc,
        'schoolHtmlImportEmpty': english.schoolHtmlImportEmpty,
        'schoolHtmlImportEntry': english.schoolHtmlImportEntry,
        'schoolHtmlImportEntryDesc': english.schoolHtmlImportEntryDesc,
        'schoolHtmlImportHtmlHint': english.schoolHtmlImportHtmlHint,
        'schoolHtmlImportHtmlLabel': english.schoolHtmlImportHtmlLabel,
        'schoolHtmlImportNonHtmlHint': english.schoolHtmlImportNonHtmlHint,
        'schoolHtmlImportPageTitle': english.schoolHtmlImportPageTitle,
      };
      for (final entry in actual.entries) {
        expect(
          entry.value,
          isNot(isIn(retiredEnglishMessages[entry.key]!)),
          reason: entry.key,
        );
        if (!source.containsKey(entry.key)) {
          expect(entry.value, expected[entry.key], reason: entry.key);
        }
      }
    },
  );
}
