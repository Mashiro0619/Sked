import '../models/timetable_models.dart';
import 'timetable_provider.dart';

/// A local editing target, not a second Provider or an application mode switch.
class WorkspaceThemeTarget {
  const WorkspaceThemeTarget(this.source, this.activeMode);
  final TimetableProvider source;
  final AppMode activeMode;
  AppData get data => source.themeDataFor(activeMode);
  bool get isStudentMode => activeMode == AppMode.student;
  String get themeMode => data.themeMode;
  String get themeColorMode => data.themeColorMode;
  int get themeSeedColorValue => data.themeSeedColorValue;
  Map<String, int> get colorfulUiColorValues => data.colorfulUiColorValues;
  Map<String, int> get courseNameColorValues => source.courseNameColorValues;
  List<GeneralSchedule> get generalSchedules => source.generalSchedules;
  String get colorfulCourseTextColorMode => source.colorfulCourseTextColorMode;
  bool get liveCourseOutlineEnabled => source.liveCourseOutlineEnabled;
  bool get liveCourseOutlineFollowTheme => source.liveCourseOutlineFollowTheme;
  int get liveCourseOutlineColorValue => source.liveCourseOutlineColorValue;
  String get liveCourseOutlineMode => source.liveCourseOutlineMode;
  double get liveCourseOutlineWidth => source.liveCourseOutlineWidth;
  Future<void> updateThemeMode(String value) =>
      source.updateThemeMode(value, workspace: activeMode);
  Future<void> updateThemeSeedColorValue(int value) =>
      source.updateThemeSeedColorValue(value, workspace: activeMode);
  Future<void> updateThemeColorMode(String value) =>
      source.updateThemeColorMode(value, workspace: activeMode);
  Future<void> updateColorfulUiColorValue(String key, int value) =>
      source.updateColorfulUiColorValue(key, value, workspace: activeMode);
  Future<void> updateCourseNameColorValue(String name, int value) =>
      source.updateCourseNameColorValue(name, value);
  Future<void> updateGeneralSchedule(GeneralSchedule value) =>
      source.updateGeneralSchedule(value);
  Future<void> updateColorfulCourseTextSettings({
    required String mode,
    required int customColorValue,
  }) => source.updateColorfulCourseTextSettings(
    mode: mode,
    customColorValue: customColorValue,
  );
}
