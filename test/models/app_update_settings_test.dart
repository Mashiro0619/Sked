import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test('new app data receives prerelease updates by default', () {
    final data = buildInitialAppData(buildDefaultPeriodTimes());
    expect(data.includePrereleaseUpdates, isTrue);
    expect(data.toJson()['includePrereleaseUpdates'], isTrue);
    expect(
      AppData.decodeStorageSnapshot(data.encode()).includePrereleaseUpdates,
      isTrue,
    );
  });

  for (final selected in [false, true]) {
    test(
      'explicit update preference $selected survives default and roundtrip',
      () {
        final initial = buildInitialAppData(buildDefaultPeriodTimes());
        final data = AppData(
          activeMode: initial.activeMode,
          studentMode: initial.studentMode,
          generalMode: initial.generalMode,
          includePrereleaseUpdates: selected,
        );
        expect(
          data.copyWith(localeCode: 'en').includePrereleaseUpdates,
          selected,
        );
        expect(data.toJson()['includePrereleaseUpdates'], selected);
        expect(
          AppData.decodeStorageSnapshot(data.encode()).includePrereleaseUpdates,
          selected,
        );
      },
    );
  }

  test(
    'legacy missing preference keeps stable updates and is saved explicitly',
    () {
      final data = AppData.fromJson(const {});
      expect(data.includePrereleaseUpdates, isFalse);
      expect(data.toJson()['includePrereleaseUpdates'], isFalse);
      expect(
        AppData.decodeStorageSnapshot(data.encode()).includePrereleaseUpdates,
        isFalse,
      );
    },
  );

  test(
    'prerelease opt-in survives copy, storage roundtrip, and explicit reset',
    () {
      final optedIn = AppData.fromJson(const {})
          .copyWith(includePrereleaseUpdates: true);
      expect(
        optedIn.copyWith(localeCode: 'zh').includePrereleaseUpdates,
        isTrue,
      );
      final reloaded = AppData.decodeStorageSnapshot(optedIn.encode());
      expect(reloaded.includePrereleaseUpdates, isTrue);
      expect(reloaded.toJson()['includePrereleaseUpdates'], isTrue);
      final stable = reloaded.copyWith(includePrereleaseUpdates: false);
      expect(stable.includePrereleaseUpdates, isFalse);
      expect(stable.toJson()['includePrereleaseUpdates'], isFalse);
      expect(
        AppData.decodeStorageSnapshot(stable.encode()).includePrereleaseUpdates,
        isFalse,
      );
    },
  );

  for (final invalid in ['true', 1, null, <Object?>[], <String, Object?>{}]) {
    test(
      'strict storage decoding rejects invalid update preference $invalid',
      () {
        final snapshot = AppData.fromJson(const {}).toJson();
        snapshot['includePrereleaseUpdates'] = invalid;
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      },
    );
  }
}
