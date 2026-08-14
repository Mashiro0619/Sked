import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/settings_service.dart';

void main() {
  const service = SettingsService();

  AppData base() => AppData.fromJson(const {});

  test(
    'updates home navigation collapsed preference and guards no-op writes',
    () {
      final initial = base();

      final collapsed = service.updateHomeWorkspaceNavigationCollapsed(
        initial,
        true,
      );

      expect(collapsed.homeWorkspaceNavigationCollapsed, isTrue);
      expect(
        identical(
          collapsed,
          service.updateHomeWorkspaceNavigationCollapsed(collapsed, true),
        ),
        isTrue,
      );
    },
  );

  group('SettingsService.updateSchoolImportParserSettings', () {
    test('replaces the parser settings subtree when any field differs', () {
      final data = base();
      final next = SchoolImportParserSettings(
        source: schoolImportParserSourceCustomOpenAi,
        customBaseUrl: 'https://api.example.com',
        customApiKey: 'sk-secret',
        customModel: 'gpt-mini',
        customPrompt: 'You are a school parser.',
      );

      final updated = service.updateSchoolImportParserSettings(data, next);

      final s = updated.studentMode.schoolImportParserSettings;
      expect(s.source, equals(next.source));
      expect(s.customBaseUrl, equals(next.customBaseUrl));
      expect(s.customApiKey, equals(next.customApiKey));
      expect(s.customModel, equals(next.customModel));
      expect(s.customPrompt, equals(next.customPrompt));
    });

    test('returns same instance when every field already matches', () {
      final initial = service.updateSchoolImportParserSettings(
        base(),
        SchoolImportParserSettings(
          source: schoolImportParserSourceCustomOpenAi,
          customBaseUrl: 'a',
          customApiKey: 'b',
          customModel: 'c',
          customPrompt: 'd',
        ),
      );
      final same = SchoolImportParserSettings(
        source: schoolImportParserSourceCustomOpenAi,
        customBaseUrl: 'a',
        customApiKey: 'b',
        customModel: 'c',
        customPrompt: 'd',
      );

      final updated = service.updateSchoolImportParserSettings(initial, same);

      expect(identical(updated, initial), isTrue);
    });

    test('normalizes parser settings before saving them', () {
      final updated = service.updateSchoolImportParserSettings(
        base(),
        SchoolImportParserSettings(
          source: 'unknown',
          customBaseUrl: ' https://api.example.com/v1 ',
          customApiKey: ' sk-secret ',
          customModel: ' gpt-mini ',
          customPrompt: ' Return JSON. ',
        ),
      );

      final settings = updated.studentMode.schoolImportParserSettings;
      expect(settings.source, schoolImportParserSourceCustomOpenAi);
      expect(settings.customBaseUrl, 'https://api.example.com/v1');
      expect(settings.customApiKey, 'sk-secret');
      expect(settings.customModel, 'gpt-mini');
      expect(settings.customPrompt, 'Return JSON.');
    });
  });

  group('SettingsService.updateLiveCourseOutlineSettings (no-op guard)', () {
    test('returns same instance when every outline field matches', () {
      // First write moves into a known state.
      final initial = service.updateLiveCourseOutlineSettings(
        base(),
        enabled: true,
        followTheme: false,
        colorValue: 0xFF112233,
        customColorInitialized: true,
        mode: 'always',
        width: 2.0,
      );

      // Second write with identical params should be a no-op.
      final replay = service.updateLiveCourseOutlineSettings(
        initial,
        enabled: true,
        followTheme: false,
        colorValue: 0xFF112233,
        customColorInitialized: true,
        mode: 'always',
        width: 2.0,
      );

      expect(identical(replay, initial), isTrue);
    });

    test('returns a new instance when any outline field changes', () {
      final initial = service.updateLiveCourseOutlineSettings(
        base(),
        enabled: false,
        followTheme: false,
        colorValue: 0,
        customColorInitialized: false,
        mode: 'always',
        width: 1.0,
      );

      final flipped = service.updateLiveCourseOutlineSettings(
        initial,
        enabled: true, // changed
        followTheme: false,
        colorValue: 0,
        customColorInitialized: false,
        mode: 'always',
        width: 1.0,
      );

      expect(identical(flipped, initial), isFalse);
      expect(flipped.studentMode.liveCourseOutlineEnabled, isTrue);
    });
  });

  group('SettingsService timetable layout settings', () {
    test('updates each setting independently and guards no-op writes', () {
      final initial = base();
      expect(initial.studentMode.fitDaySelectorToWidth, isTrue);
      expect(initial.studentMode.fitWeekColumnsToWidth, isTrue);
      expect(initial.studentMode.enableWeekSwipeNavigation, isTrue);

      final dayFixed = service.updateFitDaySelectorToWidth(initial, false);
      expect(dayFixed.studentMode.fitDaySelectorToWidth, isFalse);
      expect(dayFixed.studentMode.fitWeekColumnsToWidth, isTrue);
      expect(dayFixed.studentMode.enableWeekSwipeNavigation, isTrue);

      final weekFixed = service.updateFitWeekColumnsToWidth(dayFixed, false);
      expect(weekFixed.studentMode.fitDaySelectorToWidth, isFalse);
      expect(weekFixed.studentMode.fitWeekColumnsToWidth, isFalse);
      expect(weekFixed.studentMode.enableWeekSwipeNavigation, isTrue);

      final swipeOff = service.updateEnableWeekSwipeNavigation(
        weekFixed,
        false,
      );
      expect(swipeOff.studentMode.fitDaySelectorToWidth, isFalse);
      expect(swipeOff.studentMode.fitWeekColumnsToWidth, isFalse);
      expect(swipeOff.studentMode.enableWeekSwipeNavigation, isFalse);
      expect(
        identical(
          swipeOff,
          service.updateEnableWeekSwipeNavigation(swipeOff, false),
        ),
        isTrue,
      );
    });
  });

  test('updates course FAB visibility and guards no-op writes', () {
    final initial = base();

    final hidden = service.updateShowAddCourseFab(initial, false);

    expect(hidden.studentMode.showAddCourseFab, isFalse);
    expect(
      identical(hidden, service.updateShowAddCourseFab(hidden, false)),
      isTrue,
    );
  });

  test('updates long-press course add and guards no-op writes', () {
    final initial = base();

    final disabled = service.updateEnableLongPressAddCourse(initial, false);

    expect(disabled.studentMode.enableLongPressAddCourse, isFalse);
    expect(
      identical(
        disabled,
        service.updateEnableLongPressAddCourse(disabled, false),
      ),
      isTrue,
    );
  });
}
