import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localizations_en.dart';
import 'package:sked/l10n/app_localizations_cs.dart';
import 'package:sked/l10n/app_localizations_ru.dart';
import 'package:sked/l10n/app_localizations_sl.dart';

void main() {
  test('inclusive one-day custom labels are singular and small plurals remain localized', () {
    final en = AppLocalizationsEn(),
        cs = AppLocalizationsCs(),
        ru = AppLocalizationsRu(),
        sl = AppLocalizationsSl();
    expect(en.dateRangeCustomDays(1), 'Custom · 1 day');
    expect(en.dateRangeCustomDays(14), 'Custom · 14 days');
    expect(cs.dateRangeCustomDays(1), 'Vlastní · 1 den');
    expect(cs.dateRangeCustomDays(3), 'Vlastní · 3 dny');
    expect(cs.dateRangeCustomDays(14), 'Vlastní · 14 dní');
    expect(ru.dateRangeCustomDays(1), 'Произвольный · 1 день');
    expect(ru.dateRangeCustomDays(3), 'Произвольный · 3 дня');
    expect(ru.dateRangeCustomDays(14), 'Произвольный · 14 дней');
    expect(sl.dateRangeCustomDays(1), 'Po meri · 1 dan');
    expect(sl.dateRangeCustomDays(2), 'Po meri · 2 dneva');
    expect(sl.dateRangeCustomDays(3), 'Po meri · 3 dni');
  });
}
