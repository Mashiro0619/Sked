import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/student_timetable_service.dart';

Matcher rejectsSetting(SettingValidationCode code) => throwsA(
  isA<SettingValidationException>().having((error) => error.code, 'code', code),
);

AppData sample({bool studentEnabled = true, bool generalEnabled = true}) {
  const periods = [
    CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
  ];
  const course = CourseItem(
    id: 'course-1',
    name: 'Math',
    teacher: 'Teacher',
    location: 'Room 1',
    dayOfWeek: 1,
    semesterWeeks: [1, 2],
    periods: [1],
    startMinutes: 0,
    endMinutes: 0,
    timeRange: '00:00 - 00:00',
    credit: 2,
    remarks: 'Keep me',
    customFields: {
      'nested': {'keep': true},
    },
  );
  return AppData(
    activeMode: generalEnabled ? AppMode.general : AppMode.student,
    enabledWorkspaces: {
      if (studentEnabled) AppMode.student,
      if (generalEnabled) AppMode.general,
    },
    workspaceReminderNotBefore: {AppMode.student: DateTime.utc(2026, 9, 1)},
    studentMode: StudentModeData(
      activeTimetableId: 'timetable-1',
      timetables: [
        TimetableData(
          id: 'timetable-1',
          config: TimetableConfig(
            name: 'Term',
            startDate: DateTime(2026, 9, 1),
            totalWeeks: 20,
            periodTimeSetId: 'periods-1',
          ),
          courses: [course],
        ),
      ],
      periodTimeSets: const [
        PeriodTimeSet(id: 'periods-1', name: 'Times', periodTimes: periods),
      ],
      courseNameColorValues: const {'Math': 0xff010203},
      colorfulUiColorValues: const {'primary': 0xffabcdef},
    ),
    generalMode: GeneralScheduleData(
      activeScheduleId: 'calendar-1',
      selectedDateIso: '2026-10-30',
      schedules: [
        GeneralSchedule(
          id: 'calendar-1',
          name: 'Calendar',
          events: [
            GeneralEvent(
              id: 'event-1',
              calendarId: 'calendar-1',
              title: 'Keep event',
              startDateTimeIso: '2026-10-30T08:00:00.000',
              endDateTimeIso: '2026-10-30T09:00:00.000',
            ),
          ],
        ),
      ],
      colorfulUiColorValues: {'secondary': 0xff123456},
    ),
    localeCode: 'en',
    includePrereleaseUpdates: true,
    ignoredUpdateVersion: '2.3.0',
    availableUpdateVersion: '2.4.0',
    privacyPolicyAcceptedVersion: '2026-09-01',
    privacyPolicyAcceptedAtIso: '2026-09-01T12:00:00.000',
    aiApiSettings: const AiApiSettings(
      customApiKey: 'secret-do-not-expose',
      customBaseUrl: 'https://user:password@example.test/v1',
    ),
    notificationSettings: const NotificationSettings(
      enabled: true,
      courseDefaultMinutesBefore: 15,
      generalDefaultMinutesBefore: 10,
    ),
  );
}

void main() {
  late SettingRegistry registry;
  setUp(() => registry = SettingRegistry());

  test('every Agent configuration field is classified and authority stays host-owned', () {
    expect(
      registry
          .describe(scope: SettingScope.agent)
          .map((entry) => entry.key.substring('agent.'.length))
          .toSet(),
      const AgentSettings().toJson().keys.toSet(),
    );
    expect(registry.descriptor('agent.permissionMode').readOnly, isTrue);
    expect(registry.descriptor('agent.endpoint').requiresAdapter, isTrue);
    expect(registry.descriptor('agent.credentialRef').sensitive, isTrue);
    final before = sample();
    final edited = registry.prepare(before, const [
      SettingEdit.set('agent.systemInstructions', '  Preserve user wording.  '),
      SettingEdit.set('agent.maxModelRounds', 8),
      SettingEdit.set('agent.historyRetentionDays', 30),
    ]);
    expect(
      edited.candidate.agentSettings.systemInstructions,
      '  Preserve user wording.  ',
    );
    expect(edited.candidate.agentSettings.maxModelRounds, 8);
    expect(edited.candidate.agentSettings.historyRetentionDays, 30);
    expect(
      edited.candidate.agentSettings.permissionMode,
      before.agentSettings.permissionMode,
    );
    expect(
      edited.changes.map((change) => change.key),
      unorderedEquals([
        'agent.systemInstructions',
        'agent.maxModelRounds',
        'agent.historyRetentionDays',
      ]),
    );
    final reset = registry.prepare(edited.candidate, const [
      SettingEdit.reset('agent.systemInstructions'),
      SettingEdit.reset('agent.maxModelRounds'),
      SettingEdit.reset('agent.historyRetentionDays'),
    ]);
    expect(reset.candidate.agentSettings, before.agentSettings);
    expect(
      () => registry.prepare(before, const [
        SettingEdit.set('agent.historyRetentionDays', 2),
      ]),
      rejectsSetting(SettingValidationCode.invalidValue),
    );
    expect(
      () => registry.prepare(before, const [
        SettingEdit.set('agent.permissionMode', 'full'),
      ]),
      rejectsSetting(SettingValidationCode.readOnly),
    );
  });

  test('every current workspace preference has an explicit descriptor', () {
    final data = sample();
    final studentFields = data.studentMode.toJson().keys.toSet()
      ..removeAll({'timetables', 'periodTimeSets'});
    final generalFields = data.generalMode.toJson().keys.toSet()
      ..removeAll({'schemaVersion', 'schedules', 'reminderAcknowledgements'});
    expect(
      registry
          .describe(scope: SettingScope.student)
          .map((entry) => entry.key.substring(8))
          .toSet(),
      studentFields,
    );
    // customDateRange is omitted from the sample JSON when absent, but remains
    // a navigation adapter capability, not an unregistered setting.
    generalFields.addAll({'customDateRange', 'customDayMinWidth'});
    expect(
      registry
          .describe(scope: SettingScope.general)
          .map((entry) => entry.key.substring(8))
          .toSet(),
      generalFields,
    );
    expect(
      registry.descriptors.map((entry) => entry.key).toSet().length,
      registry.descriptors.length,
    );
    expect(
      registry.descriptors
          .where((entry) => entry.key.startsWith('device.layout.'))
          .length,
      DesktopLayoutRegion.values.length * 3,
    );
  });

  test('all current app and notification preferences are described', () {
    final data = sample();
    final fields = data.toJson().keys.toSet()
      ..removeAll({
        'schemaVersion',
        'studentMode',
        'generalMode',
        'notificationSettings',
        'aiApiSettings',
        // Internal command receipts are not configurable preferences.
        'applicationLedger',
        'workspaceReminderNotBefore',
      })
      ..remove('hideHomeBottomNavigationBar')
      ..addAll({'hideHomeWorkspaceNavigation', 'workspacePanelDisplayMode'});
    expect(
      registry
          .describe(scope: SettingScope.app)
          .where((entry) => !entry.key.startsWith('app.notifications.'))
          .map((entry) => entry.key.substring(4))
          .toSet(),
      fields,
    );
    final notificationFields = data.notificationSettings.toJson().keys.toSet()
      ..add('remindHiddenGeneralCalendars');
    expect(
      registry.descriptors
          .where((entry) => entry.key.startsWith('app.notifications.'))
          .map((entry) => entry.key.substring('app.notifications.'.length))
          .toSet(),
      notificationFields,
    );
  });

  test('metadata exposes applicability and precise null/reset meanings', () {
    expect(
      registry.descriptor('general.showAddEventFab').platform,
      SettingPlatform.touchLayout,
    );
    expect(registry.descriptor('general.customDayMinWidth').nullable, isTrue);
    expect(registry.descriptor('general.customDayMinWidth').minimum, 64);
    expect(registry.descriptor('general.customDayMinWidth').step, 8);
    expect(
      registry
          .descriptor('app.notifications.generalDefaultMinutesBefore')
          .resetMeaning,
      contains('Disable'),
    );
    expect(registry.descriptor('app.workspacePanelDisplayMode').allowedValues, [
      'overlay',
      'sideBySide',
      'automatic',
    ]);
    expect(() => registry.descriptors.clear(), throwsUnsupportedError);
  });

  test('explicit targets manage both disabled and noncurrent workspaces', () {
    for (final data in [
      sample(studentEnabled: false),
      sample(generalEnabled: false),
    ]) {
      final before = data.encode();
      final result = registry.prepare(data, const [
        SettingEdit.set('student.themeMode', 'dark'),
        SettingEdit.set('general.themeMode', 'light'),
        SettingEdit.set('student.showFutureCourses', false),
        SettingEdit.set('general.showWeekends', false),
        SettingEdit.set('app.notifications.courseDefaultMinutesBefore', 35),
      ]);
      expect(result.candidate.studentMode.themeMode, 'dark');
      expect(result.candidate.generalMode.themeMode, 'light');
      expect(result.candidate.studentMode.showFutureCourses, isFalse);
      expect(result.candidate.generalMode.showWeekends, isFalse);
      expect(
        result.candidate.notificationSettings.courseDefaultMinutesBefore,
        35,
      );
      expect(result.candidate.activeMode, data.activeMode);
      expect(result.candidate.enabledWorkspaces, data.enabledWorkspaces);
      expect(
        result.candidate.workspaceReminderNotBefore,
        data.workspaceReminderNotBefore,
      );
      expect(
        result.candidate.studentMode.timetables,
        same(data.studentMode.timetables),
      );
      expect(
        result.candidate.generalMode.schedules,
        same(data.generalMode.schedules),
      );
      expect(data.encode(), before);
      expect(
        result.candidate.aiApiSettings.customApiKey,
        'secret-do-not-expose',
      );
    }
  });

  test(
    'keep and omitted fields preserve values; null disables or selects auto',
    () {
      final data = sample();
      final withWidth = registry.prepare(data, const [
        SettingEdit.set('general.customDayMinWidth', 104),
      ]).candidate;
      final result = registry.prepare(withWidth, const [
        SettingEdit.keep('app.notifications.courseDefaultMinutesBefore'),
        SettingEdit.set('app.notifications.generalDefaultMinutesBefore', null),
        SettingEdit.set('general.customDayMinWidth', null),
      ]);
      expect(
        result.candidate.notificationSettings.courseDefaultMinutesBefore,
        15,
      );
      expect(
        result.candidate.notificationSettings.generalDefaultMinutesBefore,
        isNull,
      );
      expect(result.candidate.generalMode.customDayMinWidth, isNull);
      expect(
        result.candidate.studentMode.colorfulUiColorValues,
        data.studentMode.colorfulUiColorValues,
      );
      expect(result.changes.map((entry) => entry.key).toSet(), {
        'app.notifications.generalDefaultMinutesBefore',
        'general.customDayMinWidth',
      });
      expect(
        () => registry.prepare(data, const [
          SettingEdit.set('general.showWeekends', null),
        ]),
        rejectsSetting(SettingValidationCode.invalidType),
      );
    },
  );

  test(
    'resets use explicit context defaults rather than legacy missing values',
    () {
      final custom = SettingRegistry(
        defaults: const SettingResetDefaults(
          localeCode: 'zh',
          includePrereleaseUpdates: false,
          studentThemeColorMode: 'colorful',
        ),
      );
      final result = custom.prepare(sample(), const [
        SettingEdit.reset('app.localeCode'),
        SettingEdit.reset('app.includePrereleaseUpdates'),
        SettingEdit.reset('student.themeColorMode'),
        SettingEdit.reset('app.ignoredUpdateVersion'),
      ]);
      expect(result.candidate.localeCode, 'zh');
      expect(result.candidate.includePrereleaseUpdates, isFalse);
      expect(result.candidate.studentMode.themeColorMode, 'colorful');
      expect(result.candidate.ignoredUpdateVersion, isNull);
      expect(result.candidate.availableUpdateVersion, isNull);
      final derived = result.changes.singleWhere(
        (entry) => entry.key == 'app.availableUpdateVersion',
      );
      expect(derived.derived, isTrue);
      expect(derived.before, '2.4.0');
      expect(derived.after, isNull);
    },
  );

  test('day range validates final combined intent without order-dependent clamping', () {
    final data = sample().copyWith(
      generalMode: sample().generalMode.copyWith(
        dayStartHour: 6,
        dayEndHour: 10,
      ),
    );
    for (final edits in [
      const [
        SettingEdit.set('general.dayStartHour', 20),
        SettingEdit.set('general.dayEndHour', 23),
      ],
      const [
        SettingEdit.set('general.dayEndHour', 23),
        SettingEdit.set('general.dayStartHour', 20),
      ],
    ]) {
      final next = registry.prepare(data, edits).candidate.generalMode;
      expect(next.dayStartHour, 20);
      expect(next.dayEndHour, 23);
    }
    final before = data.encode();
    expect(
      () => registry.prepare(data, const [
        SettingEdit.set('app.localeCode', 'zh'),
        SettingEdit.set('general.dayStartHour', 10),
      ]),
      rejectsSetting(SettingValidationCode.invalidCombination),
    );
    expect(data.encode(), before);
  });

  test(
    'settings do not materialize a date or change a hidden navigation target',
    () {
      final data = sample().copyWith(
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'hidden',
          schedules: [
            GeneralSchedule(id: 'visible', name: 'Visible', events: []),
            GeneralSchedule(
              id: 'hidden',
              name: 'Hidden',
              isVisible: false,
              events: [],
            ),
          ],
        ),
      );
      final result = registry.prepare(data, const [
        SettingEdit.set('general.themeMode', 'dark'),
        SettingEdit.set('general.timeGridMinutes', 15),
      ]);
      expect(result.candidate.generalMode.selectedDateIso, isNull);
      expect(result.candidate.generalMode.activeScheduleId, 'hidden');
      expect(
        result.candidate.generalMode.schedules,
        same(data.generalMode.schedules),
      );
      expect(result.changes.map((entry) => entry.key).toSet(), {
        'general.themeMode',
        'general.timeGridMinutes',
      });
    },
  );

  test('toolbar orders require a complete permutation and hidden ids a valid subset', () {
    final data = sample();
    final order = studentToolbarNavigationDefaultOrder.reversed.toList();
    final next = registry.prepare(data, [
      SettingEdit.set('student.toolbarNavigationOrder', order),
      const SettingEdit.set('general.hiddenToolbarNavigationIds', [
        'date',
        'view',
      ]),
      const SettingEdit.set('general.toolbarHiddenItemsBehavior', 'more'),
    ]).candidate;
    expect(next.studentMode.toolbarNavigationOrder, order);
    expect(next.generalMode.hiddenToolbarNavigationIds, ['date', 'view']);
    expect(next.generalMode.toolbarHiddenItemsBehavior, 'more');
    for (final edit in [
      const SettingEdit.set('student.toolbarNavigationOrder', ['week']),
      const SettingEdit.set('general.hiddenToolbarNavigationIds', [
        'date',
        'date',
      ]),
      const SettingEdit.set('student.hiddenToolbarNavigationIds', ['category']),
    ]) {
      expect(
        () => registry.prepare(data, [edit]),
        rejectsSetting(SettingValidationCode.invalidValue),
      );
    }
  });

  test('course color replacement and reset preserve automatic assignment semantics', () {
    final data = sample();
    final set = registry.prepare(data, const [
      SettingEdit.set('student.courseNameColorValues', {'Math': 0xff334455}),
    ]);
    expect(set.candidate.studentMode.courseNameColorValues, {
      'Math': 0xff334455,
    });
    final reset = registry.prepare(set.candidate, const [
      SettingEdit.reset('student.courseNameColorValues'),
    ]);
    expect(
      reset.candidate.studentMode.courseNameColorValues,
      buildStudentCourseNameColorValuesForTimetables(
        data.studentMode.timetables,
      ),
    );
    expect(
      registry.defaultValueFor(data, 'student.courseNameColorValues'),
      reset.candidate.studentMode.courseNameColorValues,
    );
    expect(
      () => registry.prepare(data, const [
        SettingEdit.set('student.courseNameColorValues', {
          'Missing': 0xff334455,
        }),
      ]),
      rejectsSetting(SettingValidationCode.invalidValue),
    );
  });

  test(
    'color overrides are explicit and unknown cross-workspace slots fail',
    () {
      final data = sample();
      final colors = <String, int>{
        'primary': 0xff224466,
        'course_text': 0xff112233,
      };
      final result = registry.prepare(data, [
        SettingEdit.set('student.colorfulUiColorValues', colors),
        const SettingEdit.set('student.colorfulCourseTextColorMode', 'custom'),
      ]);
      colors['primary'] = 0xff000000;
      expect(
        result.candidate.studentMode.colorfulUiColorValues['primary'],
        0xff224466,
      );
      expect(
        result.candidate.studentMode.colorfulCourseTextColorMode,
        'custom',
      );
      expect(
        () => result.candidate.studentMode.colorfulUiColorValues.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => registry.prepare(data, const [
          SettingEdit.set('general.colorfulUiColorValues', {
            'course_text': 0xff000000,
          }),
        ]),
        rejectsSetting(SettingValidationCode.invalidValue),
      );
      final reset = registry.prepare(result.candidate, const [
        SettingEdit.reset('student.colorfulUiColorValues'),
      ]);
      expect(reset.candidate.studentMode.colorfulUiColorValues, isEmpty);
    },
  );

  test('outline color intent updates its derived initialization flag', () {
    final set = registry.prepare(sample(), const [
      SettingEdit.set('student.liveCourseOutlineColorValue', 0xff112233),
      SettingEdit.set('student.liveCourseOutlineWidth', 3),
    ]);
    expect(
      set.candidate.studentMode.liveCourseOutlineCustomColorInitialized,
      isTrue,
    );
    expect(set.candidate.studentMode.liveCourseOutlineWidth, 3.0);
    expect(
      set.changes
          .singleWhere(
            (entry) =>
                entry.key == 'student.liveCourseOutlineCustomColorInitialized',
          )
          .derived,
      isTrue,
    );
    final reset = registry.prepare(set.candidate, const [
      SettingEdit.reset('student.liveCourseOutlineColorValue'),
    ]);
    expect(
      reset.candidate.studentMode.liveCourseOutlineCustomColorInitialized,
      isFalse,
    );
    expect(
      () => registry.prepare(sample(), const [
        SettingEdit.set(
          'student.liveCourseOutlineCustomColorInitialized',
          true,
        ),
      ]),
      rejectsSetting(SettingValidationCode.readOnly),
    );
  });

  test(
    'invalid values are rejected rather than repaired by model normalizers',
    () {
      final cases = <SettingEdit>[
        const SettingEdit.set('app.localeCode', 'not-a-language'),
        const SettingEdit.set('student.themeMode', 'black'),
        const SettingEdit.set('app.workspacePanelDisplayMode', 'docked'),
        const SettingEdit.set('general.defaultView', 'year'),
        const SettingEdit.set('general.timeGridMinutes', 20),
        const SettingEdit.set('general.customDayMinWidth', 65),
        const SettingEdit.set('general.timeGridHourHeight', 37),
        const SettingEdit.set('general.dayStartHour', -1),
        const SettingEdit.set(
          'app.notifications.generalDefaultMinutesBefore',
          -1,
        ),
        const SettingEdit.set('student.themeSeedColorValue', -1),
        const SettingEdit.set('student.liveCourseOutlineWidth', 5.0),
      ];
      for (final edit in cases) {
        expect(
          () => registry.prepare(sample(), [edit]),
          rejectsSetting(SettingValidationCode.invalidValue),
          reason: edit.key,
        );
      }
      for (final edit in [
        const SettingEdit.set('general.timeGridMinutes', 15.0),
        const SettingEdit.set('student.liveCourseOutlineWidth', double.nan),
        const SettingEdit.set('app.notifications.enabled', 1),
        const SettingEdit.set('student.colorfulUiColorValues', {
          'primary': 1.5,
        }),
      ]) {
        expect(
          () => registry.prepare(sample(), [edit]),
          rejectsSetting(SettingValidationCode.invalidType),
          reason: edit.key,
        );
      }
    },
  );

  test('unknown, duplicate, read-only and adapter writes fail without success placeholders', () {
    final data = sample();
    expect(
      () => registry.read(data, 'app.customApiKey'),
      rejectsSetting(SettingValidationCode.unknownKey),
    );
    expect(
      () => registry.prepare(data, const [SettingEdit.keep('app.unknown')]),
      rejectsSetting(SettingValidationCode.unknownKey),
    );
    expect(
      () => registry.prepare(data, const [
        SettingEdit.keep('app.localeCode'),
        SettingEdit.set('app.localeCode', 'zh'),
      ]),
      rejectsSetting(SettingValidationCode.duplicateKey),
    );
    for (final key in [
      'app.privacyPolicyAcceptedAtIso',
      'app.availableUpdateVersion',
      'platform.notifications',
    ]) {
      expect(
        () => registry.prepare(data, [SettingEdit.reset(key)]),
        rejectsSetting(SettingValidationCode.readOnly),
      );
    }
    for (final key in [
      'app.enabledWorkspaces',
      'device.layout.assistant.width',
      'legacy.parser.customBaseUrl',
      'device.schoolSites',
    ]) {
      expect(registry.descriptor(key).requiresAdapter, isTrue);
      expect(
        () => registry.prepare(data, [SettingEdit.reset(key)]),
        rejectsSetting(SettingValidationCode.requiresAdapter),
      );
    }
    expect(
      () => registry.read(data, 'legacy.parser.customBaseUrl'),
      rejectsSetting(SettingValidationCode.requiresAdapter),
    );
    expect(
      jsonEncode(
        registry.descriptors.map((descriptor) => descriptor.toJson()).toList(),
      ),
      isNot(contains('secret-do-not-expose')),
    );
  });

  test(
    'read results and change summaries cannot mutate application collections',
    () {
      final data = sample();
      final read = registry.read(data, 'student.colorfulUiColorValues') as Map;
      expect(() => read.clear(), throwsUnsupportedError);
      final result = registry.prepare(data, const [
        SettingEdit.reset('student.colorfulUiColorValues'),
      ]);
      expect(() => result.changes.clear(), throwsUnsupportedError);
      expect(
        () => (result.changes.single.before as Map).clear(),
        throwsUnsupportedError,
      );
      expect(data.studentMode.colorfulUiColorValues, {'primary': 0xffabcdef});
    },
  );

  test('same values and keep return the original snapshot', () {
    final data = sample();
    final result = registry.prepare(data, const [
      SettingEdit.keep('app.activeMode'),
      SettingEdit.set('general.showWeekends', true),
      SettingEdit.set('student.themeMode', 'system'),
    ]);
    expect(result.isEmpty, isTrue);
    expect(result.candidate, same(data));
  });

  test('explicit keep cannot be silently changed by a required dependency', () {
    final data = sample();
    final before = data.encode();
    expect(
      () => registry.prepare(data, const [
        SettingEdit.set('app.includePrereleaseUpdates', false),
        SettingEdit.keep('app.availableUpdateVersion'),
      ]),
      rejectsSetting(SettingValidationCode.invalidCombination),
    );
    expect(data.encode(), before);
  });

  test('ordinary prepared settings remain compatible with strict production decoding', () {
    final result = registry.prepare(sample(), const [
      SettingEdit.set('app.localeCode', 'zh'),
      SettingEdit.set('student.themeMode', 'dark'),
      SettingEdit.set('general.defaultView', 'month'),
      SettingEdit.set('general.customDayMinWidth', 128),
      SettingEdit.set('app.notifications.generalDefaultMinutesBefore', null),
      SettingEdit.set('student.liveCourseOutlineWidth', 1.5),
    ]);
    final decoded = AppData.decodeStorageSnapshot(result.candidate.encode());
    expect(decoded.localeCode, 'zh');
    expect(decoded.generalMode.customDayMinWidth, 128);
    expect(decoded.notificationSettings.generalDefaultMinutesBefore, isNull);
    expect(decoded.studentMode.timetables.single.courses.single.customFields, {
      'nested': {'keep': true},
    });
  });
}
