import '../models/timetable_models.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_view_state.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';

/// A local editing target, not a second Provider or an application mode switch.
class WorkspaceThemeTarget {
  const WorkspaceThemeTarget({
    required this._settings,
    required this._settingsCommands,
    required this._general,
    required this._generalCommands,
    required this.activeMode,
  });

  final SettingsViewState _settings;
  final SettingsCommands _settingsCommands;
  final GeneralViewState _general;
  final GeneralCommands _generalCommands;
  final AppMode activeMode;
  AppData get _theme => _settings.themeDataFor(activeMode);
  bool get isStudentMode => activeMode == AppMode.student;
  String get themeMode => _theme.themeMode;
  String get themeColorMode => _theme.themeColorMode;
  int get themeSeedColorValue => _theme.themeSeedColorValue;
  Map<String, int> get colorfulUiColorValues => _theme.colorfulUiColorValues;
  Map<String, int> get courseNameColorValues => _settings.courseNameColorValues;
  List<GeneralSchedule> get generalSchedules => _general.schedules;
  String get colorfulCourseTextColorMode =>
      _settings.colorfulCourseTextColorMode;
  bool get liveCourseOutlineEnabled => _settings.liveCourseOutlineEnabled;
  bool get liveCourseOutlineFollowTheme =>
      _settings.liveCourseOutlineFollowTheme;
  int get liveCourseOutlineColorValue => _settings.liveCourseOutlineColorValue;
  String get liveCourseOutlineMode => _settings.liveCourseOutlineMode;
  double get liveCourseOutlineWidth => _settings.liveCourseOutlineWidth;
  Future<void> updateThemeMode(String value) =>
      _settingsCommands.updateThemeMode(value, workspace: activeMode);
  Future<void> updateThemeSeedColorValue(int value) =>
      _settingsCommands.updateThemeSeedColorValue(value, workspace: activeMode);
  Future<void> updateThemeColorMode(String value) =>
      _settingsCommands.updateThemeColorMode(value, workspace: activeMode);
  Future<void> updateColorfulUiColorValue(String key, int value) =>
      _settingsCommands.updateColorfulUiColorValue(
        key,
        value,
        workspace: activeMode,
      );
  Future<void> updateCourseNameColorValue(String name, int value) =>
      _settingsCommands.updateCourseNameColorValue(name, value);
  Future<void> updateGeneralScheduleColor(String id, int value) =>
      _generalCommands.updateScheduleColor(id, value);
  Future<void> updateColorfulCourseTextSettings({
    required String mode,
    required int customColorValue,
  }) => _settingsCommands.updateColorfulCourseTextSettings(
    mode: mode,
    customColorValue: customColorValue,
  );
}
