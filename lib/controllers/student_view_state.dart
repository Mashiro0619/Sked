import '../models/timetable_models.dart';
import '../services/student_timetable_service.dart' as student_timetable;
import 'app_session.dart';
import 'observable_view_state.dart';

/// Student workspace queries and its transient selected week.
/// The underlying timetable data always comes from the shared session.
class StudentViewState extends ObservableViewState {
  StudentViewState(this._session) {
    initializePublication();
  }

  final AppSession _session;
  var _selectedWeek = 1;
  var _selectionEpoch = 0;

  @override
  Object get publicationKey => (data, localeCode, isEnabled, _selectedWeek);

  StudentModeData get data => _session.data.studentMode;
  String get localeCode => _session.data.localeCode;
  bool get isEnabled => _session.data.isWorkspaceEnabled(AppMode.student);
  bool get hasTimetables => data.timetables.isNotEmpty;
  bool get hasPeriodTimeSets => data.periodTimeSets.isNotEmpty;
  List<TimetableData> get timetables => data.timetables;
  List<PeriodTimeSet> get periodTimeSets => data.periodTimeSets;
  int get selectedWeek => _selectedWeek;
  int get selectionEpoch => _selectionEpoch;

  /// Mutations may adjust the week before persistence. The command's existing
  /// completion/error notification publishes this selection with its data.
  set selectedWeek(int value) {
    if (_selectedWeek == value) return;
    _selectedWeek = value;
    _selectionEpoch += 1;
  }

  TimetableData? get activeTimetableOrNull =>
      student_timetable.activeTimetableOrNull(data);

  TimetableData get activeTimetable =>
      activeTimetableOrNull ??
      TimetableData(
        id: '',
        config: TimetableConfig(
          name: emptyTimetableName(localeCode: localeCode),
          startDate: DateTime.now(),
          totalWeeks: 1,
          periodTimeSetId: '',
        ),
        courses: const [],
      );

  PeriodTimeSet? get activePeriodTimeSetOrNull {
    final timetable = activeTimetableOrNull;
    return timetable == null
        ? data.periodTimeSets.firstOrNull
        : periodTimeSetForId(timetable.config.periodTimeSetId);
  }

  PeriodTimeSet get activePeriodTimeSet =>
      activePeriodTimeSetOrNull ??
      PeriodTimeSet(
        id: '',
        name: defaultPeriodTimeSetName(localeCode: localeCode),
        periodTimes: const [
          CoursePeriodTime(
            index: 1,
            startMinutes: 8 * 60,
            endMinutes: (8 * 60) + 45,
          ),
        ],
      );

  int currentWeek() {
    final timetable = activeTimetableOrNull;
    return timetable == null ? 1 : currentWeekFor(timetable.config);
  }

  PeriodTimeSet? periodTimeSetForId(String id) =>
      student_timetable.periodTimeSetForId(data, id);

  List<TimetableData> timetablesUsingPeriodTimeSet(String periodTimeSetId) =>
      timetables
          .where((item) => item.config.periodTimeSetId == periodTimeSetId)
          .toList();

  int dailyPeriodsForTimetable(TimetableData timetable) =>
      periodTimeSetForId(timetable.config.periodTimeSetId)
          ?.periodTimes
          .length ??
      1;

  List<CoursePeriodTime> periodTimesForTimetable(TimetableData timetable) =>
      periodTimeSetForId(timetable.config.periodTimeSetId)?.periodTimes ??
      const [];

  String? displayedCourseIdForConflict(String conflictKey) =>
      readDisplayedCourseIdForConflict(
        data.conflictDisplayCourseIds,
        conflictKey,
      );
}
