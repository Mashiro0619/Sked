import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_localizations_ro.dart';
import 'package:sked/l10n/app_localizations_ru.dart';
import 'package:sked/l10n/app_localizations_sl.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale period count preserves the submitted number', () {
      final messages = lookupAppLocalizations(locale);
      for (final count in [0, 1, 2, 3, 5, 11, 21, 100, 101, 102]) {
        final rendered = messages.periodTimesCount(count);
        expect(
          RegExp(r'\d+').allMatches(rendered).map((match) => match[0]).toList(),
          ['$count'],
          reason: '$locale count=$count rendered as $rendered',
        );
      }
    });
  }

  test('Romanian custom day phrases distinguish few from other', () {
    final messages = AppLocalizationsRo();
    for (final (days, unit) in [
      (1, 'zi'),
      (2, 'zile'),
      (19, 'zile'),
      (20, 'de zile'),
      (21, 'de zile'),
      (100, 'de zile'),
      (101, 'zile'),
      (119, 'zile'),
      (120, 'de zile'),
    ]) {
      expect(messages.dateRangeCustomDays(days), 'Personalizat · $days $unit');
    }
  });

  test('Slovenian singular and dual categories include larger counts', () {
    final messages = AppLocalizationsSl();
    for (final (days, unit) in [
      (1, 'dan'),
      (2, 'dneva'),
      (3, 'dni'),
      (4, 'dni'),
      (5, 'dni'),
      (100, 'dni'),
      (101, 'dan'),
      (102, 'dneva'),
      (103, 'dni'),
      (104, 'dni'),
      (201, 'dan'),
    ]) {
      expect(messages.dateRangeCustomDays(days), 'Po meri · $days $unit');
    }
  });

  test(
    'Russian day phrases use one after 21 while keeping 11 and 111 plural',
    () {
      final messages = AppLocalizationsRu();
      for (final (days, unit) in [
        (1, 'день'),
        (2, 'дня'),
        (5, 'дней'),
        (11, 'дней'),
        (14, 'дней'),
        (21, 'день'),
        (22, 'дня'),
        (25, 'дней'),
        (101, 'день'),
        (111, 'дней'),
      ]) {
        expect(
          messages.dateRangeCustomDays(days),
          'Произвольный · $days $unit',
        );
      }
    },
  );
}
