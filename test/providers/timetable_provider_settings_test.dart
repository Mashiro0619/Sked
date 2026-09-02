import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';

class _ControllableStorage implements TimetableStorage {
  _ControllableStorage(this.data);

  AppData? data;
  Object? nextSaveError;
  var saveCount = 0;

  @override
  Future<String?> filePath() async => 'memory://provider-settings-test';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData next) async {
    saveCount += 1;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw error;
    data = next;
  }
}

Future<TimetableProvider> _providerFor(_ControllableStorage storage) async {
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => 'en',
  );
  await provider.load();
  return provider;
}

void main() {
  test(
    'hidden home navigation setting persists and rolls back on failure',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);

      expect(provider.hideHomeWorkspaceNavigation, isFalse);

      await provider.updateHideHomeWorkspaceNavigation(true);

      expect(provider.hideHomeWorkspaceNavigation, isTrue);
      expect(storage.data!.hideHomeWorkspaceNavigation, isTrue);

      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.updateHideHomeWorkspaceNavigation(false),
        throwsStateError,
      );

      expect(provider.hideHomeWorkspaceNavigation, isTrue);
      expect(storage.data!.hideHomeWorkspaceNavigation, isTrue);
    },
  );

  test(
    'collapsed home navigation saves once and rolls back on failure',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);

      expect(provider.homeWorkspaceNavigationCollapsed, isFalse);

      await provider.updateHomeWorkspaceNavigationCollapsed(true);

      expect(storage.saveCount, 1);
      expect(provider.homeWorkspaceNavigationCollapsed, isTrue);
      expect(storage.data!.homeWorkspaceNavigationCollapsed, isTrue);

      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.updateHomeWorkspaceNavigationCollapsed(false),
        throwsStateError,
      );

      expect(storage.saveCount, 2);
      expect(provider.homeWorkspaceNavigationCollapsed, isTrue);
      expect(storage.data!.homeWorkspaceNavigationCollapsed, isTrue);
    },
  );

  test('course text mode and custom color commit atomically', () async {
    final storage = _ControllableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _providerFor(storage);

    await provider.updateColorfulCourseTextSettings(
      mode: colorfulCourseTextColorModeCustom,
      customColorValue: 0xFF123456,
    );

    expect(storage.saveCount, 1);
    expect(
      provider.colorfulCourseTextColorMode,
      colorfulCourseTextColorModeCustom,
    );
    expect(
      provider.colorfulUiColorValues[colorfulCourseTextColorKey],
      0xFF123456,
    );
  });

  test('failed course text settings save rolls back both fields', () async {
    final storage = _ControllableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _providerFor(storage);
    final originalMode = provider.colorfulCourseTextColorMode;
    storage.nextSaveError = StateError('save failed');

    await expectLater(
      provider.updateColorfulCourseTextSettings(
        mode: colorfulCourseTextColorModeCustom,
        customColorValue: 0xFF123456,
      ),
      throwsStateError,
    );

    expect(provider.colorfulCourseTextColorMode, originalMode);
    expect(
      provider.colorfulUiColorValues.containsKey(colorfulCourseTextColorKey),
      isFalse,
    );
  });

  test('parser text settings commit once and roll back together', () async {
    final storage = _ControllableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _providerFor(storage);

    await provider.updateCustomSchoolImportTextSettings(
      baseUrl: ' https://parser.example/v1 ',
      model: ' model-a ',
      prompt: ' prompt-a ',
    );

    expect(storage.saveCount, 1);
    expect(provider.customSchoolImportBaseUrl, 'https://parser.example/v1');
    expect(provider.customSchoolImportModel, 'model-a');
    expect(provider.customSchoolImportPrompt, 'prompt-a');

    storage.nextSaveError = StateError('save failed');
    await expectLater(
      provider.updateCustomSchoolImportTextSettings(
        baseUrl: 'https://other.example/v1',
        model: 'model-b',
        prompt: 'prompt-b',
      ),
      throwsStateError,
    );

    expect(storage.saveCount, 2);
    expect(provider.customSchoolImportBaseUrl, 'https://parser.example/v1');
    expect(provider.customSchoolImportModel, 'model-a');
    expect(provider.customSchoolImportPrompt, 'prompt-a');
  });

  test(
    'notification settings persist atomically and skip unchanged updates',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);
      final commits = <AppDataCommit>[];
      final subscription = provider.committedData.listen(commits.add);
      addTearDown(subscription.cancel);

      await provider.updateNotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
        generalDefaultMinutesBefore: 30,
        lockScreenShowTitles: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(storage.saveCount, 1);
      expect(provider.notificationsEnabled, isTrue);
      expect(provider.courseDefaultReminderMinutesBefore, 10);
      expect(provider.courseDefaultMinutesBefore, 10);
      expect(provider.generalDefaultReminderMinutesBefore, 30);
      expect(provider.generalDefaultMinutesBefore, 30);
      expect(provider.lockScreenShowTitles, isTrue);
      expect(storage.data!.notificationSettings, provider.notificationSettings);
      expect(commits, hasLength(1));
      expect(commits.single.snapshot.notificationSettings.enabled, isTrue);

      await provider.updateNotificationSettings();
      await Future<void>.delayed(Duration.zero);
      expect(storage.saveCount, 1);
      expect(commits, hasLength(1));

      await provider.updateCourseDefaultReminder(null);
      await provider.updateGeneralDefaultReminder(5);
      await provider.updateLockScreenShowTitles(false);
      await provider.updateNotificationsEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(storage.saveCount, 5);
      expect(provider.notificationsEnabled, isFalse);
      expect(provider.courseDefaultMinutesBefore, isNull);
      expect(provider.generalDefaultMinutesBefore, 5);
      expect(provider.lockScreenShowTitles, isFalse);
      expect(commits.map((item) => item.revision), [1, 2, 3, 4, 5]);
    },
  );

  test(
    'failed notification settings writes restore durable state without commit',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);
      final commits = <AppDataCommit>[];
      final subscription = provider.committedData.listen(commits.add);
      addTearDown(subscription.cancel);
      storage.nextSaveError = StateError('save failed');

      await expectLater(
        provider.updateNotificationSettings(
          enabled: true,
          courseDefaultMinutesBefore: 10,
          generalDefaultMinutesBefore: 30,
          lockScreenShowTitles: true,
        ),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(storage.saveCount, 1);
      expect(provider.notificationSettings, const NotificationSettings());
      expect(storage.data!.notificationSettings, const NotificationSettings());
      expect(commits, isEmpty);
    },
  );
}
