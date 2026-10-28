import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

final periodRailTimetable = TimetableData(
  id: 'rail-test',
  config: TimetableConfig(
    name: 'Period rail',
    startDate: DateTime(2026, 1, 5),
    totalWeeks: 18,
    periodTimeSetId: defaultPeriodTimeSetId,
  ),
  courses: const [],
);

Widget periodRailHarness({
  Key gridKey = const ValueKey('period-rail-grid'),
  required List<CoursePeriodTime> periods,
  TextScaler scaler = TextScaler.noScaling,
  double width = 1120,
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? ThemeData(platform: TargetPlatform.windows),
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(
    body: Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: TimetableGrid(
          key: gridKey,
          timetable: periodRailTimetable,
          periodTimes: periods,
          weekDateStart: DateTime(2026, 1, 5),
          selectedWeek: 1,
          realCurrentWeek: 1,
          localeCode: locale.languageCode,
          preserveGaps: true,
          showPastEndedCourses: true,
          showFutureCourses: true,
          showGridLines: true,
          onCourseTap: (_) {},
          onEmptySlotTap: (_) {},
          themeColorMode: themeColorModeSingle,
          courseNameColorValues: const {},
          colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
          liveCourseOutlineEnabled: false,
          liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
          liveCourseOutlineColorValue: 0xff6750a4,
          liveCourseOutlineWidth: 2,
        ),
      ),
    ),
  ),
);
