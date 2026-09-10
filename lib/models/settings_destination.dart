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
  parser,
  periods,
  notificationPermissions;

  AppMode? get workspace => switch (this) {
    student ||
    schoolImport ||
    studentPreferences ||
    parser ||
    periods => AppMode.student,
    general || generalPreferences => AppMode.general,
    _ => null,
  };
}
