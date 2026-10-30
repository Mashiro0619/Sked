import 'app_mode.dart';

/// Destinations own availability checks even when entered directly from a task.
enum SettingsDestination {
  appearance,
  notifications,
  language,
  data,
  features,
  about,
  student,
  general,
  schoolImport,
  studentPreferences,
  generalPreferences,
  notificationPermissions;

  AppMode? get workspace => switch (this) {
    student || schoolImport || studentPreferences => AppMode.student,
    general || generalPreferences => AppMode.general,
    _ => null,
  };
}
