import 'package:flutter/foundation.dart';

import 'app_data.dart';

enum AppPreferenceCommand {
  locale,
  prereleaseUpdates,
  homeNavigationVisibility,
  homeNavigationCollapsed,
  panelDisplayMode,
}

enum AppPreferenceField {
  locale,
  includePrereleaseUpdates,
  availableUpdateVersion,
  hideHomeWorkspaceNavigation,
  homeWorkspaceNavigationCollapsed,
  workspacePanelDisplayMode,
}

/// A known command's exact write set, verified against its input snapshot.
///
/// Custom settings services that change any other field keep the ordinary
/// complete-snapshot save path. No write set is inferred from JSON differences.
@immutable
class AppPreferenceWrite {
  const AppPreferenceWrite._(this.before, this.snapshot, this.fields);

  final AppData before;
  final AppData snapshot;
  final Set<AppPreferenceField> fields;

  static AppPreferenceWrite? tryCreate({
    required AppData before,
    required AppData snapshot,
    required AppPreferenceCommand command,
  }) {
    final fields = switch (command) {
      AppPreferenceCommand.locale => const {AppPreferenceField.locale},
      AppPreferenceCommand.prereleaseUpdates => const {
        AppPreferenceField.includePrereleaseUpdates,
        AppPreferenceField.availableUpdateVersion,
      },
      AppPreferenceCommand.homeNavigationVisibility => const {
        AppPreferenceField.hideHomeWorkspaceNavigation,
      },
      AppPreferenceCommand.homeNavigationCollapsed => const {
        AppPreferenceField.homeWorkspaceNavigationCollapsed,
      },
      AppPreferenceCommand.panelDisplayMode => const {
        AppPreferenceField.workspacePanelDisplayMode,
      },
    };
    if (!_preservesOtherFields(before, snapshot, fields)) return null;
    return AppPreferenceWrite._(before, snapshot, fields);
  }

  static bool _preservesOtherFields(
    AppData before,
    AppData after,
    Set<AppPreferenceField> fields,
  ) =>
      before.activeMode == after.activeMode &&
      setEquals(before.enabledWorkspaces, after.enabledWorkspaces) &&
      mapEquals(
        before.workspaceReminderNotBefore,
        after.workspaceReminderNotBefore,
      ) &&
      identical(before.studentMode, after.studentMode) &&
      identical(before.generalMode, after.generalMode) &&
      identical(before.aiApiSettings, after.aiApiSettings) &&
      before.notificationSettings == after.notificationSettings &&
      before.privacyPolicyAcceptedVersion ==
          after.privacyPolicyAcceptedVersion &&
      before.privacyPolicyAcceptedAtIso == after.privacyPolicyAcceptedAtIso &&
      before.ignoredUpdateVersion == after.ignoredUpdateVersion &&
      (fields.contains(AppPreferenceField.locale) ||
          before.localeCode == after.localeCode) &&
      (fields.contains(AppPreferenceField.includePrereleaseUpdates) ||
          before.includePrereleaseUpdates == after.includePrereleaseUpdates) &&
      (fields.contains(AppPreferenceField.availableUpdateVersion) ||
          before.availableUpdateVersion == after.availableUpdateVersion) &&
      (fields.contains(AppPreferenceField.hideHomeWorkspaceNavigation) ||
          before.hideHomeWorkspaceNavigation ==
              after.hideHomeWorkspaceNavigation) &&
      (fields.contains(AppPreferenceField.homeWorkspaceNavigationCollapsed) ||
          before.homeWorkspaceNavigationCollapsed ==
              after.homeWorkspaceNavigationCollapsed) &&
      (fields.contains(AppPreferenceField.workspacePanelDisplayMode) ||
          before.workspacePanelDisplayMode == after.workspacePanelDisplayMode);
}
