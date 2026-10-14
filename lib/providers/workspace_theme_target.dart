import '../models/timetable_models.dart';
import 'timetable_provider.dart';

/// A local editing target, not a second Provider or an application mode switch.
class WorkspaceThemeTarget {
  const WorkspaceThemeTarget(this.source, this.activeMode);
  final TimetableProvider source;
  final AppMode activeMode;
  AppData get data => source.settingsView.themeDataFor(activeMode);
  bool get isStudentMode => activeMode == AppMode.student;
  String get themeMode => data.themeMode;
  String get themeColorMode => data.themeColorMode;
  int get themeSeedColorValue => data.themeSeedColorValue;
  Map<String, int> get colorfulUiColorValues => data.colorfulUiColorValues;
  Map<String, int> get courseNameColorValues =>
      source.settingsView.courseNameColorValues;
  List<GeneralSchedule> get generalSchedules => source.generalView.schedules;
  String get colorfulCourseTextColorMode =>
      source.settingsView.colorfulCourseTextColorMode;
  bool get liveCourseOutlineEnabled =>
      source.settingsView.liveCourseOutlineEnabled;
  bool get liveCourseOutlineFollowTheme =>
      source.settingsView.liveCourseOutlineFollowTheme;
  int get liveCourseOutlineColorValue =>
      source.settingsView.liveCourseOutlineColorValue;
  String get liveCourseOutlineMode => source.settingsView.liveCourseOutlineMode;
  double get liveCourseOutlineWidth =>
      source.settingsView.liveCourseOutlineWidth;
  Future<void> updateThemeMode(String value) =>
      source.settingsCommands.updateThemeMode(value, workspace: activeMode);
  Future<void> updateThemeSeedColorValue(int value) => source.settingsCommands
      .updateThemeSeedColorValue(value, workspace: activeMode);
  Future<void> updateThemeColorMode(String value) => source.settingsCommands
      .updateThemeColorMode(value, workspace: activeMode);
  Future<void> updateColorfulUiColorValue(String key, int value) => source
      .settingsCommands
      .updateColorfulUiColorValue(key, value, workspace: activeMode);
  Future<void> updateCourseNameColorValue(String name, int value) =>
      source.settingsCommands.updateCourseNameColorValue(name, value);
  Future<void> updateGeneralScheduleColor(String id, int value) =>
      source.generalCommands.updateScheduleColor(id, value);
  Future<void> updateGeneralSchedule(GeneralSchedule value) =>
      source.generalCommands.updateSchedule(value);
  Future<void> updateColorfulCourseTextSettings({
    required String mode,
    required int customColorValue,
  }) => source.settingsCommands.updateColorfulCourseTextSettings(
    mode: mode,
    customColorValue: customColorValue,
  );
}
