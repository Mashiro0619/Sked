import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/app_data.dart';

void main() {
  test(
    'existing data defaults to stable updates without changing its snapshot',
    () {
      final data = AppData.fromJson(const {});
      expect(data.includePrereleaseUpdates, isFalse);
      expect(data.toJson(), isNot(contains('includePrereleaseUpdates')));
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
      expect(stable.toJson(), isNot(contains('includePrereleaseUpdates')));
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
