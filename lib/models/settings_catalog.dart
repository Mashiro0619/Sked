import '../l10n/app_localizations.dart';
import 'app_mode.dart';
import 'settings_destination.dart';

class SettingsCatalogEntry {
  const SettingsCatalogEntry(
    this.id,
    this.title,
    this.destination, {
    this.summary = '',
    this._workspace,
    this.category = false,
  });
  final String id, title, summary;
  final SettingsDestination destination;
  final AppMode? _workspace;
  AppMode? get workspace => _workspace ?? destination.workspace;
  final bool category;
}

/// The wide index anchors the same grouped overview used on phones.
/// Detailed display and workflow preferences remain on their own pages.
List<SettingsCatalogEntry> settingsCatalog(
  AppLocalizations l,
  Set<AppMode> enabled, {
  bool canClearData = true,
}) => [
  SettingsCatalogEntry(
    'appearance',
    l.settingsAppearanceLanguage,
    SettingsDestination.appearance,
    category: true,
  ),
  if (enabled.contains(AppMode.student))
    SettingsCatalogEntry(
      'student',
      l.studentTimetable,
      SettingsDestination.studentPreferences,
      category: true,
    ),
  if (enabled.contains(AppMode.general))
    SettingsCatalogEntry(
      'general',
      l.generalSchedule,
      SettingsDestination.generalPreferences,
      category: true,
    ),
  SettingsCatalogEntry(
    'notifications',
    l.notificationSettingsSection,
    SettingsDestination.notifications,
    category: true,
  ),
  SettingsCatalogEntry(
    'features',
    l.workspaceFeatures,
    SettingsDestination.features,
    category: true,
  ),
  SettingsCatalogEntry(
    'data',
    l.settingsDataPrivacy,
    SettingsDestination.data,
    category: true,
  ),
  SettingsCatalogEntry(
    'about',
    l.settingsSectionAbout,
    SettingsDestination.about,
    category: true,
  ),
];
