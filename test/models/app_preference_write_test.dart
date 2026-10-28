import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/app_preference_write.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/settings_service.dart';

void main() {
  final before = buildInitialAppData(
    buildDefaultPeriodTimes(),
  ).copyWith(activeMode: AppMode.general, availableUpdateVersion: '3.0.0-beta');
  const service = SettingsService();

  test('known preference commands describe their complete writes', () {
    final changes = <AppPreferenceCommand, AppData>{
      AppPreferenceCommand.locale: service.updateLocaleCode(before, 'zh-CN'),
      AppPreferenceCommand.prereleaseUpdates: service
          .updateIncludePrereleaseUpdates(before, false),
      AppPreferenceCommand.homeNavigationVisibility: service
          .updateHideHomeWorkspaceNavigation(before, true),
      AppPreferenceCommand.homeNavigationCollapsed: service
          .updateHomeWorkspaceNavigationCollapsed(before, true),
      AppPreferenceCommand.panelDisplayMode: service
          .updateWorkspacePanelDisplayMode(
            before,
            WorkspacePanelDisplayMode.sideBySide,
          ),
    };
    for (final entry in changes.entries) {
      final write = AppPreferenceWrite.tryCreate(
        before: before,
        snapshot: entry.value,
        command: entry.key,
      )!;
      expect(write.before, same(before));
      expect(write.snapshot, same(entry.value));
      expect(() => write.fields.clear(), throwsUnsupportedError);
    }
    final release = AppPreferenceWrite.tryCreate(
      before: before,
      snapshot: changes[AppPreferenceCommand.prereleaseUpdates]!,
      command: AppPreferenceCommand.prereleaseUpdates,
    )!;
    expect(release.fields, {
      AppPreferenceField.includePrereleaseUpdates,
      AppPreferenceField.availableUpdateVersion,
    });
    expect(release.snapshot.availableUpdateVersion, isNull);
  });

  test('an undeclared change cannot become a preference write', () {
    // Keep this list and AppPreferenceWrite's shell validation in step with
    // every new top-level AppData field; unknown writes must remain barriers.
    final declared = before.copyWith(localeCode: 'zh');
    final extraChanges = [
      declared.copyWith(activeMode: AppMode.student),
      declared.copyWith(enabledWorkspaces: {AppMode.general}),
      declared.copyWith(
        workspaceReminderNotBefore: {AppMode.general: DateTime(2026, 1, 1)},
      ),
      declared.copyWith(
        studentMode: declared.studentMode.copyWith(
          showFutureCourses: !declared.studentMode.showFutureCourses,
        ),
      ),
      declared.copyWith(
        generalMode: declared.generalMode.copyWith(
          showWeekends: !declared.generalMode.showWeekends,
        ),
      ),
      declared.copyWith(
        aiApiSettings: declared.aiApiSettings.copyWith(customModel: 'changed'),
      ),
      declared.copyWith(
        notificationSettings: declared.notificationSettings.copyWith(
          enabled: true,
        ),
      ),
      declared.copyWith(privacyPolicyAcceptedVersion: '2026-10-28'),
      declared.copyWith(privacyPolicyAcceptedAtIso: '2026-10-28T00:00:00'),
      declared.copyWith(ignoredUpdateVersion: 'changed'),
      declared.copyWith(availableUpdateVersion: 'changed'),
      declared.copyWith(includePrereleaseUpdates: false),
      declared.copyWith(hideHomeWorkspaceNavigation: true),
      declared.copyWith(homeWorkspaceNavigationCollapsed: true),
      declared.copyWith(
        workspacePanelDisplayMode: WorkspacePanelDisplayMode.sideBySide,
      ),
    ];
    for (final snapshot in extraChanges) {
      expect(
        AppPreferenceWrite.tryCreate(
          before: before,
          snapshot: snapshot,
          command: AppPreferenceCommand.locale,
        ),
        isNull,
      );
    }
  });
}
