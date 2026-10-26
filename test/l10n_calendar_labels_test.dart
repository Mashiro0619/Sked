import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sked/l10n/app_localizations.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

Map<String, dynamic> _messages(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  setUpAll(initializeDateFormatting);

  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale cancel remains distinct from deleting data', () {
      final messages = _messages('$locale');
      expect(
        (messages['cancel'] as String).trim().toLowerCase(),
        isNot((messages['delete'] as String).trim().toLowerCase()),
      );
    });
    test('$locale calendar labels are distinct and compact', () {
      final messages = _messages('$locale');
      final months = [for (final month in _months) messages['month$month']];
      final weekdays = [
        for (final day in _weekdays) messages['weekdayShort$day'] as String,
      ];
      expect(months.toSet(), hasLength(12));
      expect(weekdays.toSet(), hasLength(7));
      for (var i = 0; i < _weekdays.length; i++) {
        final full = messages['weekday${_weekdays[i]}'] as String;
        expect(
          weekdays[i].runes.length,
          lessThanOrEqualTo(full.runes.length),
          reason: '$locale ${_weekdays[i]} should fit its compact label slot.',
        );
      }
    });
  }

  for (final locale in [
    'bg',
    'cs',
    'da',
    'el',
    'et',
    'fi',
    'hu',
    'pl',
    'ro',
    'sl',
    'sv',
  ]) {
    test('$locale weekdays match the bundled CLDR abbreviations', () {
      final messages = _messages(locale);
      for (var i = 0; i < _weekdays.length; i++) {
        expect(
          messages['weekdayShort${_weekdays[i]}'],
          DateFormat('EEE', locale).format(DateTime(2026, 5, 25 + i)),
        );
      }
    });
  }

  test('corrected month labels name the expected CLDR month', () {
    expect(
      _messages('sv')['monthDecember'],
      DateFormat('MMM', 'sv').format(DateTime(2026, 12)),
    );
    expect(
      _messages('ro')['monthAugust'],
      DateFormat('MMMM', 'ro').format(DateTime(2026, 8)),
    );
    expect(
      _messages('hu')['monthDecember'],
      DateFormat('MMMM', 'hu').format(DateTime(2026, 12)),
    );
  });
}
