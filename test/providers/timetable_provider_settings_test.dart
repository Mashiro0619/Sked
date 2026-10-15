import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/providers/workspace_theme_target.dart';

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
  await provider.lifecycle.load();
  return provider;
}

void main() {
  test(
    'hidden calendar reminder preference saves, deduplicates and rolls back',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);
      expect(provider.settingsView.remindHiddenGeneralCalendars, isFalse);
      await provider.settingsCommands.updateRemindHiddenGeneralCalendars(false);
      expect(storage.saveCount, 0);
      await provider.settingsCommands.updateRemindHiddenGeneralCalendars(true);
      expect(provider.settingsView.remindHiddenGeneralCalendars, isTrue);
      expect(
        storage.data!.notificationSettings.remindHiddenGeneralCalendars,
        isTrue,
      );
      await provider.settingsCommands.updateRemindHiddenGeneralCalendars(true);
      expect(storage.saveCount, 1);
      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.settingsCommands.updateRemindHiddenGeneralCalendars(false),
        throwsStateError,
      );
      expect(provider.settingsView.remindHiddenGeneralCalendars, isTrue);
      expect(
        storage.data!.notificationSettings.remindHiddenGeneralCalendars,
        isTrue,
      );
    },
  );

  test(
    'panel display preference is global, durable and rolls back on failure',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);
      expect(
        provider.settingsView.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.overlay,
      );
      await provider.settingsCommands.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      expect(storage.saveCount, 0);
      for (final mode in [
        WorkspacePanelDisplayMode.sideBySide,
        WorkspacePanelDisplayMode.automatic,
      ]) {
        await provider.settingsCommands.updateWorkspacePanelDisplayMode(mode);
        expect(provider.settingsView.workspacePanelDisplayMode, mode);
        expect(storage.data!.workspacePanelDisplayMode, mode);
        final reloaded = await _providerFor(storage);
        expect(reloaded.settingsView.workspacePanelDisplayMode, mode);
        reloaded.dispose();
      }
      expect(storage.saveCount, 2);
      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.settingsCommands.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.overlay,
        ),
        throwsStateError,
      );
      expect(
        provider.settingsView.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.automatic,
      );
      expect(
        storage.data!.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.automatic,
      );
      expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isFalse);
    },
  );

  test(
    'hidden home navigation setting persists and rolls back on failure',
    () async {
      final storage = _ControllableStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await _providerFor(storage);
      addTearDown(provider.dispose);

      expect(provider.settingsView.hideHomeWorkspaceNavigation, isFalse);

      await provider.settingsCommands.updateHideHomeWorkspaceNavigation(true);

      expect(provider.settingsView.hideHomeWorkspaceNavigation, isTrue);
      expect(storage.data!.hideHomeWorkspaceNavigation, isTrue);

      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.settingsCommands.updateHideHomeWorkspaceNavigation(false),
        throwsStateError,
      );

      expect(provider.settingsView.hideHomeWorkspaceNavigation, isTrue);
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

      expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isFalse);

      await provider.settingsCommands.updateHomeWorkspaceNavigationCollapsed(
        true,
      );

      expect(storage.saveCount, 1);
      expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isTrue);
      expect(storage.data!.homeWorkspaceNavigationCollapsed, isTrue);

      storage.nextSaveError = StateError('save failed');
      await expectLater(
        provider.settingsCommands.updateHomeWorkspaceNavigationCollapsed(false),
        throwsStateError,
      );

      expect(storage.saveCount, 2);
      expect(provider.settingsView.homeWorkspaceNavigationCollapsed, isTrue);
      expect(storage.data!.homeWorkspaceNavigationCollapsed, isTrue);
    },
  );

  for (final activeMode in AppMode.values) {
    test(
      'student course text commits atomically while active=$activeMode',
      () async {
        final storage = _ControllableStorage(
          buildInitialAppData(buildDefaultPeriodTimes())
              .copyWith(activeMode: activeMode),
        );
        final provider = await _providerFor(storage);
        addTearDown(provider.dispose);
        final target = WorkspaceThemeTarget(
          settings: provider.settingsView,
          settingsCommands: provider.settingsCommands,
          general: provider.generalView,
          generalCommands: provider.generalCommands,
          activeMode: AppMode.student,
        );
        final originalGeneral = provider.workspaceView.data.generalMode
            .toJson();

        await target.updateColorfulCourseTextSettings(
          mode: colorfulCourseTextColorModeCustom,
          customColorValue: 0xFF123456,
        );

        expect(storage.saveCount, 1);
        expect(provider.workspaceView.activeMode, activeMode);
        expect(
          target.colorfulCourseTextColorMode,
          colorfulCourseTextColorModeCustom,
        );
        expect(
          target.colorfulUiColorValues[colorfulCourseTextColorKey],
          0xFF123456,
        );
        expect(
          provider.workspaceView.data.generalMode.toJson(),
          originalGeneral,
        );
        expect(
          storage
              .data!
              .studentMode
              .colorfulUiColorValues[colorfulCourseTextColorKey],
          0xFF123456,
        );

        await target.updateColorfulCourseTextSettings(
          mode: colorfulCourseTextColorModeCustom,
          customColorValue: 0xFF123456,
        );
        expect(storage.saveCount, 1);
      },
    );

    test(
      'failed student course text save rolls back while active=$activeMode',
      () async {
        final storage = _ControllableStorage(
          buildInitialAppData(buildDefaultPeriodTimes())
              .copyWith(activeMode: activeMode),
        );
        final provider = await _providerFor(storage);
        addTearDown(provider.dispose);
        final original = provider.workspaceView.data.toJson();
        storage.nextSaveError = StateError('save failed');

        await expectLater(
          WorkspaceThemeTarget(
            settings: provider.settingsView,
            settingsCommands: provider.settingsCommands,
            general: provider.generalView,
            generalCommands: provider.generalCommands,
            activeMode: AppMode.student,
          ).updateColorfulCourseTextSettings(
            mode: colorfulCourseTextColorModeCustom,
            customColorValue: 0xFF123456,
          ),
          throwsStateError,
        );

        expect(provider.workspaceView.data.toJson(), original);
        expect(storage.data!.toJson(), original);
      },
    );
  }

  test('parser text settings commit once and roll back together', () async {
    final storage = _ControllableStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final provider = await _providerFor(storage);

    await provider.settingsCommands.updateCustomSchoolImportTextSettings(
      baseUrl: ' https://parser.example/v1 ',
      model: ' model-a ',
      prompt: ' prompt-a ',
    );

    expect(storage.saveCount, 1);
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://parser.example/v1',
    );
    expect(provider.settingsView.customSchoolImportModel, 'model-a');
    expect(provider.settingsView.customSchoolImportPrompt, 'prompt-a');

    storage.nextSaveError = StateError('save failed');
    await expectLater(
      provider.settingsCommands.updateCustomSchoolImportTextSettings(
        baseUrl: 'https://other.example/v1',
        model: 'model-b',
        prompt: 'prompt-b',
      ),
      throwsStateError,
    );

    expect(storage.saveCount, 2);
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://parser.example/v1',
    );
    expect(provider.settingsView.customSchoolImportModel, 'model-a');
    expect(provider.settingsView.customSchoolImportPrompt, 'prompt-a');
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
      final subscription = provider.session.commits.listen(commits.add);
      addTearDown(subscription.cancel);

      await provider.settingsCommands.updateNotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
        generalDefaultMinutesBefore: 30,
        lockScreenShowTitles: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(storage.saveCount, 1);
      expect(provider.settingsView.notificationsEnabled, isTrue);
      expect(provider.settingsView.courseDefaultMinutesBefore, 10);
      expect(provider.settingsView.generalDefaultMinutesBefore, 30);
      expect(provider.settingsView.lockScreenShowTitles, isTrue);
      expect(
        storage.data!.notificationSettings,
        provider.settingsView.notificationSettings,
      );
      expect(commits, hasLength(1));
      expect(commits.single.snapshot.notificationSettings.enabled, isTrue);

      await provider.settingsCommands.updateNotificationSettings();
      await Future<void>.delayed(Duration.zero);
      expect(storage.saveCount, 1);
      expect(commits, hasLength(1));

      await provider.settingsCommands.updateCourseDefaultReminder(null);
      await provider.settingsCommands.updateGeneralDefaultReminder(5);
      await provider.settingsCommands.updateLockScreenShowTitles(false);
      await provider.settingsCommands.updateNotificationsEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(storage.saveCount, 5);
      expect(provider.settingsView.notificationsEnabled, isFalse);
      expect(provider.settingsView.courseDefaultMinutesBefore, isNull);
      expect(provider.settingsView.generalDefaultMinutesBefore, 5);
      expect(provider.settingsView.lockScreenShowTitles, isFalse);
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
      final subscription = provider.session.commits.listen(commits.add);
      addTearDown(subscription.cancel);
      storage.nextSaveError = StateError('save failed');

      await expectLater(
        provider.settingsCommands.updateNotificationSettings(
          enabled: true,
          courseDefaultMinutesBefore: 10,
          generalDefaultMinutesBefore: 30,
          lockScreenShowTitles: true,
        ),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(storage.saveCount, 1);
      expect(
        provider.settingsView.notificationSettings,
        const NotificationSettings(),
      );
      expect(storage.data!.notificationSettings, const NotificationSettings());
      expect(commits, isEmpty);
    },
  );
}
