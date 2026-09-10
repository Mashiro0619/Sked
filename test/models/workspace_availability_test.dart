import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  AppData initial() => buildInitialAppData(buildDefaultPeriodTimes());
  test(
    'v2 enables both workspaces without losing data or navigation choices',
    () {
      final json = initial().toJson()
        ..['schemaVersion'] = 2
        ..remove('enabledWorkspaces')
        ..remove('workspaceReminderNotBefore');
      json['hideHomeBottomNavigationBar'] = true;
      final migrated = AppData.decodeStorageSnapshot(jsonEncode(json));
      expect(migrated.enabledWorkspaces, AppMode.values.toSet());
      expect(migrated.hideHomeWorkspaceNavigation, isTrue);
      expect(migrated.toJson()['schemaVersion'], 3);
    },
  );
  for (final active in [null, 'unknown', 'Student', 1]) {
    test('v3 import rejects invalid active workspace: $active', () {
      final json = initial().toJson()..['activeMode'] = active;
      expect(() => AppData.fromJson(json), throwsFormatException);
    });
  }
  test('single workspace and reminder boundary round trip', () {
    final boundary = DateTime.utc(2026, 9, 8, 8);
    final data = initial().copyWith(
      activeMode: AppMode.general,
      enabledWorkspaces: {AppMode.general},
      workspaceReminderNotBefore: {AppMode.general: boundary},
    );
    final decoded = AppData.decodeStorageSnapshot(data.encode());
    expect(decoded.enabledWorkspaces, {AppMode.general});
    expect(decoded.workspaceReminderNotBefore[AppMode.general], boundary);
    expect(decoded.studentMode.toJson(), data.studentMode.toJson());
    expect(
      () => decoded.enabledWorkspaces.add(AppMode.student),
      throwsUnsupportedError,
    );
  });
  for (final invalid in [
    null,
    <String>[],
    ['unknown'],
    ['general', 'general'],
    ['general'],
    'general',
  ]) {
    test('v3 rejects invalid workspace selection: $invalid', () {
      final json = initial().toJson()
        ..['activeMode'] = 'student'
        ..['enabledWorkspaces'] = invalid;
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(json)),
        throwsFormatException,
      );
    });
  }
  test(
    'v3 cannot omit workspace state or accept a malformed reminder boundary',
    () {
      final json = initial().toJson()..remove('enabledWorkspaces');
      expect(() => AppData.fromJson(json), throwsFormatException);
      json['enabledWorkspaces'] = ['student', 'general'];
      json['workspaceReminderNotBefore'] = {'general': 'not a date'};
      expect(() => AppData.fromJson(json), throwsFormatException);
    },
  );
}
