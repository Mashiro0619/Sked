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
  final String id;
  final String title;
  final String summary;
  final SettingsDestination destination;
  final AppMode? _workspace;
  AppMode? get workspace => _workspace ?? destination.workspace;
  final bool category;
}

/// The settings center has six destinations; workflow settings live with their task.
List<SettingsCatalogEntry> settingsCatalog(
  AppLocalizations l,
  Set<AppMode> enabled, {
  bool canClearData = true,
}) {
  final entries = <SettingsCatalogEntry>[
    SettingsCatalogEntry(
      'appearance',
      l.settingsSectionAppearance,
      SettingsDestination.appearance,
      category: true,
    ),
    SettingsCatalogEntry(
      'notifications',
      l.notificationSettingsSection,
      SettingsDestination.notifications,
      category: true,
    ),
    SettingsCatalogEntry(
      'language',
      l.language,
      SettingsDestination.language,
      category: true,
    ),
    SettingsCatalogEntry(
      'data',
      l.settingsDataPrivacy,
      SettingsDestination.data,
      category: true,
    ),
    SettingsCatalogEntry(
      'features',
      l.workspaceFeatures,
      SettingsDestination.features,
      category: true,
    ),
    SettingsCatalogEntry(
      'about',
      l.settingsSectionAbout,
      SettingsDestination.about,
      category: true,
    ),
  ];
  return entries
      .where(
        (entry) => entry.workspace == null || enabled.contains(entry.workspace),
      )
      .toList(growable: false);
}
