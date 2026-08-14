import '../models/app_data.dart';
import '../models/course_item.dart';
import '../models/general_event.dart';
import '../models/general_schedule.dart';
import '../models/timetable_data.dart';
import '../utils/localized_names.dart';
import '../utils/time_utils.dart';

/// The language used for labels in the developer sample data set.
enum DeveloperSampleLanguage { simplifiedChinese, english }

const _supportedReminderMinutes = <int>{0, 5, 10, 30, 60, 1440};

/// The result of appending one complete sample data batch.
class DeveloperSampleDataResult {
  const DeveloperSampleDataResult({
    required this.data,
    required this.timetableId,
    required this.activeScheduleId,
  });

  final AppData data;
  final String timetableId;
  final String activeScheduleId;
}

/// Builds deterministic, self-contained data for visual and interaction
/// checks. The service never mutates the supplied [AppData].
class DeveloperSampleDataService {
  DeveloperSampleDataService._();

  static int _batchSerial = 0;

  /// Returns [current] with one new timetable and three new calendars.
  ///
  /// All identifiers are allocated against the existing data before any
  /// object is built. This lets callers safely persist the returned snapshot
  /// with one write and retry the operation without overwriting user data.
  static DeveloperSampleDataResult append({
    required AppData current,
    required DeveloperSampleLanguage language,
    required DateTime now,
  }) {
    final usedIds = _collectIds(current);
    final prefix = _newBatchPrefix(now);
    final ids = _IdAllocator(prefix, usedIds);

    final existingPeriodTimeSet = _resolvePeriodTimeSet(current);
    final createdPeriodTimeSet = existingPeriodTimeSet == null
        ? PeriodTimeSet(
            id: ids.next('periods'),
            name: defaultPeriodTimeSetName(localeCode: current.localeCode),
            periodTimes: buildDefaultPeriodTimes(),
          )
        : null;
    final periodTimeSet = existingPeriodTimeSet ?? createdPeriodTimeSet!;
    final timetableId = ids.next('timetable');
    final periodTimes = periodTimeSet.periodTimes;

    final weekStart = startOfWeekMonday(normalizeDateOnly(now));
    final timetableName = language == DeveloperSampleLanguage.simplifiedChinese
        ? '示例课表'
        : 'Sample timetable';
    final courses = _buildCourses(
      language: language,
      ids: ids,
      periodTimes: periodTimes,
    );
    final timetable = TimetableData(
      id: timetableId,
      config: TimetableConfig(
        name: timetableName,
        startDate: weekStart,
        totalWeeks: 18,
        periodTimeSetId: periodTimeSet.id,
      ),
      courses: courses,
    );

    final calendars = _buildCalendars(
      language: language,
      ids: ids,
      now: normalizeDateOnly(now),
      sortOrderBase: current.generalMode.schedules.length,
    );
    final studentMode = current.studentMode.copyWith(
      activeTimetableId: timetableId,
      timetables: [...current.studentMode.timetables, timetable],
      periodTimeSets: [
        ...current.studentMode.periodTimeSets,
        ?createdPeriodTimeSet,
      ],
    );
    final generalMode = current.generalMode.copyWith(
      activeScheduleId: calendars.first.id,
      schedules: [...current.generalMode.schedules, ...calendars],
      selectedDateIso: _dateIso(normalizeDateOnly(now)),
    );
    final data = current.copyWith(
      studentMode: studentMode,
      generalMode: generalMode,
    );

    return DeveloperSampleDataResult(
      data: data,
      timetableId: timetableId,
      activeScheduleId: calendars.first.id,
    );
  }

  static String _newBatchPrefix(DateTime now) {
    // A serial also protects callers that intentionally pass the same [now]
    // while previewing multiple batches before persisting either one.
    final serial = ++_batchSerial;
    return 'developer_${now.microsecondsSinceEpoch}_$serial';
  }

  static Set<String> _collectIds(AppData data) {
    final ids = <String>{
      for (final set in data.studentMode.periodTimeSets) set.id,
      for (final timetable in data.studentMode.timetables) ...{
        timetable.id,
        for (final course in timetable.courses) course.id,
      },
      for (final schedule in data.generalMode.schedules) ...{
        schedule.id,
        for (final event in schedule.events) event.id,
      },
    };
    return ids;
  }

  static PeriodTimeSet? _resolvePeriodTimeSet(AppData current) {
    final studentMode = current.studentMode;
    TimetableData? activeTimetable;
    for (final timetable in studentMode.timetables) {
      if (timetable.id == studentMode.activeTimetableId) {
        activeTimetable = timetable;
        break;
      }
    }
    activeTimetable ??= studentMode.timetables.firstOrNull;

    if (activeTimetable != null) {
      for (final periodTimeSet in studentMode.periodTimeSets) {
        if (periodTimeSet.id == activeTimetable.config.periodTimeSetId &&
            periodTimeSet.periodTimes.isNotEmpty) {
          return periodTimeSet;
        }
      }
    }
    for (final periodTimeSet in studentMode.periodTimeSets) {
      if (periodTimeSet.periodTimes.isNotEmpty) return periodTimeSet;
    }
    return null;
  }
}

class _IdAllocator {
  _IdAllocator(this.prefix, this.used);

  final String prefix;
  final Set<String> used;
  var _index = 0;

  String next(String kind) {
    String candidate;
    do {
      _index += 1;
      candidate = '${prefix}_${kind}_$_index';
    } while (!used.add(candidate));
    return candidate;
  }
}

List<CourseItem> _buildCourses({
  required DeveloperSampleLanguage language,
  required _IdAllocator ids,
  required List<CoursePeriodTime> periodTimes,
}) {
  final allWeeks = List<int>.generate(18, (index) => index + 1);
  final oddWeeks = [for (var week = 1; week <= 18; week += 2) week];
  final evenWeeks = [for (var week = 2; week <= 18; week += 2) week];
  final firstHalf = [for (var week = 1; week <= 9; week++) week];
  final secondHalf = [for (var week = 10; week <= 18; week++) week];
  final chinese = language == DeveloperSampleLanguage.simplifiedChinese;

  final definitions = chinese
      ? <_CourseDefinition>[
          _CourseDefinition(
            '高等数学',
            '张老师',
            'A101',
            1,
            [1, 2],
            allWeeks,
            3.0,
            '覆盖微积分基础。',
          ),
          _CourseDefinition(
            '大学英语',
            '李老师',
            'B203',
            2,
            [3, 4],
            oddWeeks,
            2.0,
            '口语与阅读训练。',
          ),
          _CourseDefinition(
            '程序设计',
            '王老师',
            'C301',
            3,
            [5, 6],
            allWeeks,
            3.0,
            '使用 Dart 完成练习。',
          ),
          _CourseDefinition(
            '物理实验',
            '陈老师',
            '实验楼 2-201',
            4,
            [7, 8],
            evenWeeks,
            1.5,
            '请提前准备实验记录。',
          ),
          _CourseDefinition(
            '体育',
            '刘老师',
            '东操场',
            5,
            [9, 10],
            firstHalf,
            1.0,
            '天气恶劣时改为室内。',
          ),
          _CourseDefinition(
            '数据结构',
            '周老师',
            'C302',
            1,
            [5, 6],
            secondHalf,
            3.0,
            '包含一次上机作业。',
          ),
          _CourseDefinition(
            '线性代数',
            '赵老师',
            'A102',
            2,
            [1, 2],
            allWeeks,
            2.5,
            '重点练习矩阵运算。',
          ),
          _CourseDefinition(
            '设计基础',
            '孙老师',
            'D105',
            3,
            [1],
            allWeeks,
            2.0,
            '与学术写作安排在同一时段。',
          ),
          _CourseDefinition(
            '学术写作',
            '郑老师',
            'B201',
            3,
            [1],
            allWeeks,
            2.0,
            '示例冲突课程。',
          ),
          _CourseDefinition(
            '社团活动',
            '',
            '活动中心',
            5,
            [11, 12],
            allWeeks,
            0.5,
            '自由参加。',
          ),
        ]
      : <_CourseDefinition>[
          _CourseDefinition(
            'Calculus',
            'Ms. Zhang',
            'A101',
            1,
            [1, 2],
            allWeeks,
            3.0,
            'Foundations of calculus.',
          ),
          _CourseDefinition(
            'Academic English',
            'Mr. Li',
            'B203',
            2,
            [3, 4],
            oddWeeks,
            2.0,
            'Speaking and reading practice.',
          ),
          _CourseDefinition(
            'Programming',
            'Dr. Wang',
            'C301',
            3,
            [5, 6],
            allWeeks,
            3.0,
            'Exercises use Dart.',
          ),
          _CourseDefinition(
            'Physics Lab',
            'Dr. Chen',
            'Lab 2-201',
            4,
            [7, 8],
            evenWeeks,
            1.5,
            'Bring a lab notebook.',
          ),
          _CourseDefinition(
            'Physical Education',
            'Coach Liu',
            'East Field',
            5,
            [9, 10],
            firstHalf,
            1.0,
            'Moves indoors in bad weather.',
          ),
          _CourseDefinition(
            'Data Structures',
            'Dr. Zhou',
            'C302',
            1,
            [5, 6],
            secondHalf,
            3.0,
            'Includes a coding assignment.',
          ),
          _CourseDefinition(
            'Linear Algebra',
            'Dr. Zhao',
            'A102',
            2,
            [1, 2],
            allWeeks,
            2.5,
            'Focus on matrix operations.',
          ),
          _CourseDefinition(
            'Design Basics',
            'Ms. Sun',
            'D105',
            3,
            [1],
            allWeeks,
            2.0,
            'Shares a time slot with writing.',
          ),
          _CourseDefinition(
            'Academic Writing',
            'Mr. Zheng',
            'B201',
            3,
            [1],
            allWeeks,
            2.0,
            'An intentional conflict sample.',
          ),
          _CourseDefinition(
            'Club Activities',
            '',
            'Activity Center',
            5,
            [11, 12],
            allWeeks,
            0.5,
            'Drop in when available.',
          ),
        ];

  return [
    for (final definition in definitions)
      _makeCourse(
        id: ids.next('course'),
        definition: definition,
        periodTimes: periodTimes,
        language: language,
      ),
  ];
}

CourseItem _makeCourse({
  required String id,
  required _CourseDefinition definition,
  required List<CoursePeriodTime> periodTimes,
  required DeveloperSampleLanguage language,
}) {
  final periodPositions =
      definition.periods
          .map((period) => period.clamp(1, periodTimes.length))
          .toSet()
          .toList()
        ..sort();
  final selectedPeriodTimes = [
    for (final position in periodPositions) periodTimes[position - 1],
  ];
  final periods = selectedPeriodTimes.map((period) => period.index).toList()
    ..sort();
  final first = selectedPeriodTimes.first;
  final last = selectedPeriodTimes.last;
  return CourseItem(
    id: id,
    name: definition.name,
    teacher: definition.teacher,
    location: definition.location,
    dayOfWeek: definition.dayOfWeek,
    semesterWeeks: definition.weeks,
    periods: periods,
    startMinutes: first.startMinutes,
    endMinutes: last.endMinutes,
    timeRange: buildTimeRange(first.startMinutes, last.endMinutes),
    credit: definition.credit,
    remarks: definition.remarks,
    customFields: language == DeveloperSampleLanguage.simplifiedChinese
        ? const {'类型': '开发者示例'}
        : const {'Type': 'Developer sample'},
  );
}

class _CourseDefinition {
  const _CourseDefinition(
    this.name,
    this.teacher,
    this.location,
    this.dayOfWeek,
    this.periods,
    this.weeks,
    this.credit,
    this.remarks,
  );

  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final List<int> periods;
  final List<int> weeks;
  final double credit;
  final String remarks;
}

List<GeneralSchedule> _buildCalendars({
  required DeveloperSampleLanguage language,
  required _IdAllocator ids,
  required DateTime now,
  required int sortOrderBase,
}) {
  final chinese = language == DeveloperSampleLanguage.simplifiedChinese;
  final calendarNames = chinese
      ? const ['学习', '生活', '活动']
      : const ['Study', 'Personal', 'Activities'];
  final calendars = <GeneralSchedule>[];
  for (
    var calendarIndex = 0;
    calendarIndex < calendarNames.length;
    calendarIndex++
  ) {
    final calendarId = ids.next('calendar');
    final events = _buildEvents(
      calendarIndex: calendarIndex,
      calendarId: calendarId,
      ids: ids,
      language: language,
      now: now,
    );
    calendars.add(
      GeneralSchedule(
        id: calendarId,
        name: calendarNames[calendarIndex],
        colorValue: generalCalendarSlotColorValues[calendarIndex],
        sortOrder: sortOrderBase + calendarIndex,
        events: events,
      ),
    );
  }
  return calendars;
}

List<GeneralEvent> _buildEvents({
  required int calendarIndex,
  required String calendarId,
  required _IdAllocator ids,
  required DeveloperSampleLanguage language,
  required DateTime now,
}) {
  final chinese = language == DeveloperSampleLanguage.simplifiedChinese;
  DateTime dateAt(int offset) => addCalendarDays(now, offset);
  DateTime dateTimeAt(int offset, int hour, int minute) =>
      _at(dateAt(offset), hour, minute);
  final eventDefinitions = switch (calendarIndex) {
    0 => <_EventDefinition>[
      _EventDefinition(
        chinese ? '复习计划' : 'Review session',
        dateTimeAt(0, 19, 0),
        dateTimeAt(0, 20, 30),
        location: chinese ? '图书馆' : 'Library',
        notes: chinese ? '准备下周测验。' : 'Prepare for next week\'s quiz.',
        reminders: [0, 10],
      ),
      _EventDefinition(
        chinese ? '晨读' : 'Morning reading',
        dateTimeAt(1, 7, 30),
        dateTimeAt(1, 8, 0),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          unit: GeneralEventRecurrenceUnit.day,
          count: 5,
        ),
        reminders: [10],
      ),
      _EventDefinition(
        chinese ? '项目截止' : 'Project deadline',
        _at(dateAt(2), 0, 0),
        _at(dateAt(3), 0, 0),
        isAllDay: true,
        colorValue: 0xFFE57373,
        notes: chinese ? '提交课程项目。' : 'Submit the course project.',
        reminders: [1440, 60],
      ),
      _EventDefinition(
        chinese ? '学习小组' : 'Study group',
        dateTimeAt(3, 18, 30),
        dateTimeAt(3, 20, 0),
        recurrenceRule: GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          unit: GeneralEventRecurrenceUnit.week,
          untilDateIso: _dateIso(dateAt(21)),
        ),
        location: chinese ? '研讨室 1' : 'Seminar room 1',
        reminders: [30],
      ),
    ],
    1 => <_EventDefinition>[
      _EventDefinition(
        chinese ? '牙医预约' : 'Dentist appointment',
        dateTimeAt(2, 10, 0),
        dateTimeAt(2, 11, 0),
        location: chinese ? '市中心诊所' : 'Downtown clinic',
        reminders: [60],
      ),
      _EventDefinition(
        chinese ? '账单日' : 'Bill payment',
        _at(dateAt(4), 0, 0),
        _at(dateAt(5), 0, 0),
        isAllDay: true,
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.monthly,
          unit: GeneralEventRecurrenceUnit.month,
          count: 3,
        ),
        reminders: [1440],
      ),
      _EventDefinition(
        chinese ? '朋友生日' : 'Friend\'s birthday',
        _at(dateAt(5), 0, 0),
        _at(dateAt(6), 0, 0),
        isAllDay: true,
        colorValue: 0xFFFFB74D,
        reminders: [1440, 60],
      ),
      _EventDefinition(
        chinese ? '家务整理' : 'Household chores',
        dateTimeAt(6, 9, 0),
        dateTimeAt(6, 10, 0),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          interval: 2,
          unit: GeneralEventRecurrenceUnit.week,
          count: 4,
        ),
        reminders: [10],
      ),
    ],
    _ => <_EventDefinition>[
      _EventDefinition(
        chinese ? '社团例会' : 'Club meeting',
        dateTimeAt(1, 18, 0),
        dateTimeAt(1, 19, 30),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.weekly,
          unit: GeneralEventRecurrenceUnit.week,
          count: 6,
        ),
        location: chinese ? '活动中心 301' : 'Activity Center 301',
        reminders: [30],
      ),
      _EventDefinition(
        chinese ? '校园集市' : 'Campus fair',
        _at(dateAt(3), 0, 0),
        _at(dateAt(4), 0, 0),
        isAllDay: true,
        colorValue: 0xFF81C784,
        location: chinese ? '中央广场' : 'Central plaza',
        reminders: [60],
      ),
      _EventDefinition(
        chinese ? '晚间散步' : 'Evening walk',
        dateTimeAt(7, 20, 0),
        dateTimeAt(7, 20, 45),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          interval: 2,
          unit: GeneralEventRecurrenceUnit.day,
          count: 5,
        ),
        reminders: [10],
      ),
      _EventDefinition(
        chinese ? '展示彩排' : 'Presentation rehearsal',
        dateTimeAt(9, 15, 0),
        dateTimeAt(9, 16, 30),
        recurrenceRule: GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.custom,
          interval: 3,
          unit: GeneralEventRecurrenceUnit.day,
          untilDateIso: _dateIso(dateAt(30)),
        ),
        location: chinese ? '报告厅' : 'Auditorium',
        notes: chinese ? '带上演示文件。' : 'Bring the presentation deck.',
        reminders: [60, 10],
      ),
    ],
  };

  return [
    for (final definition in eventDefinitions)
      _buildEvent(definition, calendarId: calendarId, ids: ids, now: now),
  ];
}

GeneralEvent _buildEvent(
  _EventDefinition definition, {
  required String calendarId,
  required _IdAllocator ids,
  required DateTime now,
}) {
  final reminders =
      definition.reminders
          .where(_supportedReminderMinutes.contains)
          .toSet()
          .toList()
        ..sort();
  return GeneralEvent(
    id: ids.next('event'),
    calendarId: calendarId,
    title: definition.title,
    startDateTimeIso: definition.start.toIso8601String(),
    endDateTimeIso: definition.end.toIso8601String(),
    isAllDay: definition.isAllDay,
    recurrenceRule: definition.recurrenceRule,
    location: definition.location,
    notes: definition.notes,
    colorValue: definition.colorValue,
    reminders: [
      for (final minutes in reminders)
        GeneralEventReminder(minutesBefore: minutes),
    ],
    createdAtIso: now.toIso8601String(),
    updatedAtIso: now.toIso8601String(),
  );
}

class _EventDefinition {
  const _EventDefinition(
    this.title,
    this.start,
    this.end, {
    this.isAllDay = false,
    this.recurrenceRule = const GeneralEventRecurrenceRule(),
    this.location = '',
    this.notes = '',
    this.colorValue,
    this.reminders = const [],
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isAllDay;
  final GeneralEventRecurrenceRule recurrenceRule;
  final String location;
  final String notes;
  final int? colorValue;
  final List<int> reminders;
}

DateTime _at(DateTime date, int hour, int minute) {
  if (date.isUtc) {
    return DateTime.utc(date.year, date.month, date.day, hour, minute);
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

String _dateIso(DateTime value) =>
    normalizeDateOnly(value).toIso8601String().split('T').first;
