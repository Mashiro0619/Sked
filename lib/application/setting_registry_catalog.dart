part of 'setting_registry.dart';

Map<String, _SettingBinding> _buildSettingBindings(
  SettingResetDefaults defaults,
) {
  final bindings = <String, _SettingBinding>{};
  void add(
    String key,
    SettingScope scope,
    SettingValueType type,
    Object? defaultValue,
    _SettingReader? read, {
    _SettingWriter? write,
    bool nullable = false,
    Iterable<Object> allowed = const [],
    num? min,
    num? max,
    num? step,
    bool minExclusive = false,
    bool readOnly = false,
    bool adapter = false,
    bool sensitive = false,
    SettingPlatform platform = SettingPlatform.all,
    SettingDefaultSource defaultSource = SettingDefaultSource.fixed,
    String resetMeaning = 'Restore the declared default value.',
  }) {
    if (bindings.containsKey(key)) {
      throw StateError('Duplicate setting registration: $key');
    }
    bindings[key] = _SettingBinding(
      SettingDescriptor(
        key: key,
        scope: scope,
        type: type,
        defaultValue: defaultValue,
        nullable: nullable,
        allowedValues: allowed,
        minimum: min,
        maximum: max,
        step: step,
        minimumExclusive: minExclusive,
        readOnly: readOnly,
        requiresAdapter: adapter,
        adapterTool: adapter ? _settingAdapterTool(key) : null,
        sensitive: sensitive,
        platform: platform,
        defaultSource: defaultSource,
        resetMeaning: resetMeaning,
      ),
      read,
      write,
    );
  }

  void appBool(
    String name,
    bool value,
    _SettingReader read,
    _SettingWriter write,
  ) => add(
    'app.$name',
    SettingScope.app,
    SettingValueType.boolean,
    value,
    read,
    write: write,
  );
  appBool(
    'hideHomeWorkspaceNavigation',
    false,
    (d) => d.hideHomeWorkspaceNavigation,
    (d, v) => SettingRegistry._settings.updateHideHomeWorkspaceNavigation(
      d,
      v as bool,
    ),
  );
  appBool(
    'homeWorkspaceNavigationCollapsed',
    false,
    (d) => d.homeWorkspaceNavigationCollapsed,
    (d, v) => SettingRegistry._settings.updateHomeWorkspaceNavigationCollapsed(
      d,
      v as bool,
    ),
  );
  add(
    'app.localeCode',
    SettingScope.app,
    SettingValueType.enumeration,
    defaults.localeCode,
    (d) => d.localeCode,
    allowed: AppLocalizations.supportedLocales.map(localeCodeFromLocale),
    defaultSource: SettingDefaultSource.applicationContext,
    write: (d, v) => SettingRegistry._settings.updateLocaleCode(d, v as String),
  );
  add(
    'app.workspacePanelDisplayMode',
    SettingScope.app,
    SettingValueType.enumeration,
    'overlay',
    (d) => d.workspacePanelDisplayMode.value,
    allowed: WorkspacePanelDisplayMode.values.map((mode) => mode.value),
    write: (d, v) => SettingRegistry._settings.updateWorkspacePanelDisplayMode(
      d,
      WorkspacePanelDisplayMode.fromJson(v),
    ),
  );
  add(
    'app.includePrereleaseUpdates',
    SettingScope.app,
    SettingValueType.boolean,
    defaults.includePrereleaseUpdates,
    (d) => d.includePrereleaseUpdates,
    defaultSource: SettingDefaultSource.applicationContext,
    write: (d, v) =>
        SettingRegistry._settings.updateIncludePrereleaseUpdates(d, v as bool),
  );
  add(
    'app.ignoredUpdateVersion',
    SettingScope.app,
    SettingValueType.string,
    null,
    (d) => d.ignoredUpdateVersion,
    nullable: true,
    write: (d, v) => v == null
        ? d.copyWith(ignoredUpdateVersion: null)
        : SettingRegistry._settings.ignoreUpdateVersion(d, v as String),
  );
  for (final entry in <String, _SettingReader>{
    'availableUpdateVersion': (d) => d.availableUpdateVersion,
    'privacyPolicyAcceptedVersion': (d) => d.privacyPolicyAcceptedVersion,
    'privacyPolicyAcceptedAtIso': (d) => d.privacyPolicyAcceptedAtIso,
  }.entries) {
    add(
      'app.${entry.key}',
      SettingScope.app,
      SettingValueType.string,
      null,
      entry.value,
      nullable: true,
      readOnly: true,
    );
  }
  add(
    'app.activeMode',
    SettingScope.app,
    SettingValueType.enumeration,
    null,
    (d) => d.activeMode.value,
    allowed: AppMode.values.map((mode) => mode.value),
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  add(
    'app.enabledWorkspaces',
    SettingScope.app,
    SettingValueType.stringList,
    null,
    (d) => AppMode.values
        .where(d.isWorkspaceEnabled)
        .map((mode) => mode.value)
        .toList(),
    allowed: AppMode.values.map((mode) => mode.value),
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  const notificationDefaults = NotificationSettings();
  const agentDefaults = AgentSettings();
  final agentPreferences = {
    'enabled': (SettingValueType.boolean, null, null),
    'systemInstructions': (SettingValueType.string, null, null),
    'maxModelRounds': (SettingValueType.integer, 1, 100),
    'maxToolCalls': (SettingValueType.integer, 1, 500),
    'maxTotalTokens': (SettingValueType.integer, 1024, 1000000),
    'historyRetentionDays': (SettingValueType.integer, 0, 3650),
  };
  final agentFields = {
    'enabled',
    'permissionMode',
    'protocol',
    'endpoint',
    'model',
    'models',
    'credentialRef',
    ...agentPreferences.keys,
  };
  for (final field in agentFields) {
    final entry = MapEntry(field, agentDefaults.toJson()[field]);
    final preference = agentPreferences[entry.key];
    add(
      'agent.${entry.key}',
      SettingScope.agent,
      preference?.$1 ??
          switch (entry.key) {
            'enabled' => SettingValueType.boolean,
            'permissionMode' || 'protocol' => SettingValueType.enumeration,
            'models' => SettingValueType.objectList,
            _ => SettingValueType.string,
          },
      entry.value,
      (d) => d.agentSettings.toJson()[entry.key],
      nullable: entry.value == null,
      allowed: switch (entry.key) {
        'permissionMode' => const ['plan', 'ask', 'full'],
        'protocol' => AgentModelProtocol.values.map((value) => value.name),
        _ => const [],
      },
      readOnly: entry.key == 'permissionMode',
      adapter: preference == null,
      sensitive: entry.key == 'credentialRef' || entry.key == 'endpoint',
      min: preference?.$2,
      max: preference?.$3,
      write: preference == null
          ? null
          : (d, v) {
              final values = d.agentSettings.toJson()..[entry.key] = v;
              try {
                return d.copyWith(
                  agentSettings: AgentSettings.fromJson(values),
                );
              } on FormatException {
                throw SettingValidationException(
                  SettingValidationCode.invalidValue,
                  'agent.${entry.key}',
                  'The Agent preference is outside its supported limits.',
                );
              }
            },
      resetMeaning: entry.key == 'historyRetentionDays'
          ? 'Keep history until explicitly deleted; finite retention accepts 7–3650 days and excludes unfinished conversations.'
          : preference == null
          ? 'Use the owning Agent connection or host control.'
          : 'Restore the declared default for future runs.',
    );
  }
  add(
    'app.agentSettings',
    SettingScope.app,
    SettingValueType.object,
    null,
    (d) => {
      'enabled': d.agentSettings.enabled,
      'permissionMode': d.agentSettings.permissionMode.name,
      'protocol': d.agentSettings.protocol.name,
      'endpoint': d.agentSettings.endpoint,
      'model': d.agentSettings.model,
      'credentialConfigured': d.agentSettings.credentialRef != null,
    },
    adapter: true,
    resetMeaning:
        'The host handles Agent configuration and permission changes.',
  );
  add(
    'app.notifications.enabled',
    SettingScope.app,
    SettingValueType.boolean,
    notificationDefaults.enabled,
    (d) => d.notificationSettings.enabled,
    write: (d, v) =>
        SettingRegistry._settings.updateNotificationEnabled(d, v as bool),
  );
  add(
    'app.notifications.courseDefaultMinutesBefore',
    SettingScope.app,
    SettingValueType.integer,
    null,
    (d) => d.notificationSettings.courseDefaultMinutesBefore,
    nullable: true,
    min: 0,
    resetMeaning: 'Disable the default course reminder.',
    write: (d, v) =>
        SettingRegistry._settings.updateCourseDefaultReminder(d, v as int?),
  );
  add(
    'app.notifications.generalDefaultMinutesBefore',
    SettingScope.app,
    SettingValueType.integer,
    null,
    (d) => d.notificationSettings.generalDefaultMinutesBefore,
    nullable: true,
    min: 0,
    resetMeaning: 'Disable the default event reminder.',
    write: (d, v) =>
        SettingRegistry._settings.updateGeneralDefaultReminder(d, v as int?),
  );
  add(
    'app.notifications.lockScreenShowTitles',
    SettingScope.app,
    SettingValueType.boolean,
    false,
    (d) => d.notificationSettings.lockScreenShowTitles,
    write: (d, v) =>
        SettingRegistry._settings.updateLockScreenShowTitles(d, v as bool),
  );
  add(
    'app.notifications.remindHiddenGeneralCalendars',
    SettingScope.app,
    SettingValueType.boolean,
    false,
    (d) => d.notificationSettings.remindHiddenGeneralCalendars,
    write: (d, v) => SettingRegistry._settings
        .updateRemindHiddenGeneralCalendars(d, v as bool),
  );

  const studentDefaults = StudentModeData(
    activeTimetableId: '',
    timetables: [],
    periodTimeSets: [],
  );
  final studentBools = <String, (bool, _SettingReader, _SettingWriter)>{
    'closeCoursePopupOnOutsideTap': (
      studentDefaults.closeCoursePopupOnOutsideTap,
      (d) => d.studentMode.closeCoursePopupOnOutsideTap,
      (d, v) => SettingRegistry._settings.updateCloseCoursePopupOnOutsideTap(
        d,
        v as bool,
      ),
    ),
    'preserveTimetableGaps': (
      studentDefaults.preserveTimetableGaps,
      (d) => d.studentMode.preserveTimetableGaps,
      (d, v) =>
          SettingRegistry._settings.updatePreserveTimetableGaps(d, v as bool),
    ),
    'showPastEndedCourses': (
      studentDefaults.showPastEndedCourses,
      (d) => d.studentMode.showPastEndedCourses,
      (d, v) =>
          SettingRegistry._settings.updateShowPastEndedCourses(d, v as bool),
    ),
    'showFutureCourses': (
      studentDefaults.showFutureCourses,
      (d) => d.studentMode.showFutureCourses,
      (d, v) => SettingRegistry._settings.updateShowFutureCourses(d, v as bool),
    ),
    'showTimetableGridLines': (
      studentDefaults.showTimetableGridLines,
      (d) => d.studentMode.showTimetableGridLines,
      (d, v) =>
          SettingRegistry._settings.updateShowTimetableGridLines(d, v as bool),
    ),
    'showAddCourseFab': (
      studentDefaults.showAddCourseFab,
      (d) => d.studentMode.showAddCourseFab,
      (d, v) => SettingRegistry._settings.updateShowAddCourseFab(d, v as bool),
    ),
    'enableLongPressAddCourse': (
      studentDefaults.enableLongPressAddCourse,
      (d) => d.studentMode.enableLongPressAddCourse,
      (d, v) => SettingRegistry._settings.updateEnableLongPressAddCourse(
        d,
        v as bool,
      ),
    ),
    'fitDaySelectorToWidth': (
      studentDefaults.fitDaySelectorToWidth,
      (d) => d.studentMode.fitDaySelectorToWidth,
      (d, v) =>
          SettingRegistry._settings.updateFitDaySelectorToWidth(d, v as bool),
    ),
    'fitWeekColumnsToWidth': (
      studentDefaults.fitWeekColumnsToWidth,
      (d) => d.studentMode.fitWeekColumnsToWidth,
      (d, v) =>
          SettingRegistry._settings.updateFitWeekColumnsToWidth(d, v as bool),
    ),
    'enableWeekSwipeNavigation': (
      studentDefaults.enableWeekSwipeNavigation,
      (d) => d.studentMode.enableWeekSwipeNavigation,
      (d, v) => SettingRegistry._settings.updateEnableWeekSwipeNavigation(
        d,
        v as bool,
      ),
    ),
  };
  for (final entry in studentBools.entries) {
    add(
      'student.${entry.key}',
      SettingScope.student,
      SettingValueType.boolean,
      entry.value.$1,
      entry.value.$2,
      write: entry.value.$3,
      platform: entry.key == 'showAddCourseFab'
          ? SettingPlatform.touchLayout
          : SettingPlatform.all,
    );
  }
  add(
    'student.toolbarNavigationOrder',
    SettingScope.student,
    SettingValueType.stringList,
    studentToolbarNavigationDefaultOrder,
    (d) => d.studentMode.toolbarNavigationOrder,
    allowed: studentToolbarNavigationKnownIds,
    write: (d, v) => SettingRegistry._settings
        .updateStudentToolbarNavigationOrder(d, v as List<String>),
  );
  add(
    'student.hiddenToolbarNavigationIds',
    SettingScope.student,
    SettingValueType.stringList,
    toolbarNavigationDefaultHiddenIds,
    (d) => d.studentMode.hiddenToolbarNavigationIds,
    allowed: studentToolbarNavigationKnownIds,
    write: (d, v) => SettingRegistry._settings
        .updateStudentToolbarNavigationHiddenIds(d, v as List<String>),
  );
  add(
    'student.toolbarHiddenItemsBehavior',
    SettingScope.student,
    SettingValueType.enumeration,
    toolbarHiddenItemsBehaviorRemove,
    (d) => d.studentMode.toolbarHiddenItemsBehavior,
    allowed: [toolbarHiddenItemsBehaviorRemove, toolbarHiddenItemsBehaviorMore],
    write: (d, v) => SettingRegistry._settings
        .updateStudentToolbarHiddenItemsBehavior(d, v as String),
  );
  add(
    'student.colorfulCourseTextColorMode',
    SettingScope.student,
    SettingValueType.enumeration,
    defaultColorfulCourseTextColorMode,
    (d) => d.studentMode.colorfulCourseTextColorMode,
    allowed: [
      colorfulCourseTextColorModeAuto,
      colorfulCourseTextColorModeCustom,
    ],
    write: (d, v) => SettingRegistry._settings
        .updateColorfulCourseTextColorMode(d, v as String),
  );
  add(
    'student.courseNameColorValues',
    SettingScope.student,
    SettingValueType.colorMap,
    const <String, int>{},
    (d) => d.studentMode.courseNameColorValues,
    defaultSource: SettingDefaultSource.courseNames,
    resetMeaning:
        'Recompute automatic colors for the existing normalized course names.',
  );
  for (final entry in <String, (Object, _SettingReader)>{
    'liveCourseOutlineEnabled': (
      defaultLiveCourseOutlineEnabled,
      (d) => d.studentMode.liveCourseOutlineEnabled,
    ),
    'liveCourseOutlineFollowTheme': (
      defaultLiveCourseOutlineFollowTheme,
      (d) => d.studentMode.liveCourseOutlineFollowTheme,
    ),
    'liveCourseOutlineCustomColorInitialized': (
      defaultLiveCourseOutlineCustomColorInitialized,
      (d) => d.studentMode.liveCourseOutlineCustomColorInitialized,
    ),
  }.entries) {
    add(
      'student.${entry.key}',
      SettingScope.student,
      SettingValueType.boolean,
      entry.value.$1,
      entry.value.$2,
      readOnly: entry.key == 'liveCourseOutlineCustomColorInitialized',
    );
  }
  add(
    'student.liveCourseOutlineColorValue',
    SettingScope.student,
    SettingValueType.integer,
    defaultLiveCourseOutlineColorValue,
    (d) => d.studentMode.liveCourseOutlineColorValue,
    min: 0,
    max: 0xffffffff,
  );
  add(
    'student.liveCourseOutlineMode',
    SettingScope.student,
    SettingValueType.enumeration,
    defaultLiveCourseOutlineMode,
    (d) => d.studentMode.liveCourseOutlineMode,
    allowed: [
      liveCourseOutlineModeCurrentOrNext,
      liveCourseOutlineModeAllDisplayed,
    ],
  );
  add(
    'student.liveCourseOutlineWidth',
    SettingScope.student,
    SettingValueType.number,
    defaultLiveCourseOutlineWidth,
    (d) => d.studentMode.liveCourseOutlineWidth,
    min: minLiveCourseOutlineWidth,
    max: maxLiveCourseOutlineWidth,
  );

  const generalDefaults = GeneralScheduleData(
    activeScheduleId: '',
    schedules: [],
  );
  final generalBools = <String, (bool, _SettingReader)>{
    'fitWeekColumnsToWidth': (
      generalDefaults.fitWeekColumnsToWidth,
      (d) => d.generalMode.fitWeekColumnsToWidth,
    ),
    'showWeekends': (
      generalDefaults.showWeekends,
      (d) => d.generalMode.showWeekends,
    ),
    'showLunarCalendar': (
      generalDefaults.showLunarCalendar,
      (d) => d.generalMode.showLunarCalendar,
    ),
    'closeEventPopupOnOutsideTap': (
      generalDefaults.closeEventPopupOnOutsideTap,
      (d) => d.generalMode.closeEventPopupOnOutsideTap,
    ),
    'showAddEventFab': (
      generalDefaults.showAddEventFab,
      (d) => d.generalMode.showAddEventFab,
    ),
    'enableLongPressAddEvent': (
      generalDefaults.enableLongPressAddEvent,
      (d) => d.generalMode.enableLongPressAddEvent,
    ),
    'allDayTimelineCollapsed': (
      generalDefaults.allDayTimelineCollapsed,
      (d) => d.generalMode.allDayTimelineCollapsed,
    ),
  };
  for (final entry in generalBools.entries) {
    add(
      'general.${entry.key}',
      SettingScope.general,
      SettingValueType.boolean,
      entry.value.$1,
      entry.value.$2,
      platform: entry.key == 'showAddEventFab'
          ? SettingPlatform.touchLayout
          : SettingPlatform.all,
    );
  }
  add(
    'general.defaultView',
    SettingScope.general,
    SettingValueType.enumeration,
    generalDefaults.defaultView,
    (d) => d.generalMode.defaultView,
    allowed: [
      generalViewWeek,
      generalViewDay,
      generalViewList,
      generalViewMonth,
    ],
  );
  add(
    'general.viewSwitchBehavior',
    SettingScope.general,
    SettingValueType.enumeration,
    generalDefaults.viewSwitchBehavior,
    (d) => d.generalMode.viewSwitchBehavior,
    allowed: [generalViewSwitchBehaviorCycle, generalViewSwitchBehaviorMenu],
    platform: SettingPlatform.touchLayout,
  );
  add(
    'general.toolbarWidthPolicy',
    SettingScope.general,
    SettingValueType.enumeration,
    generalDefaults.toolbarWidthPolicy,
    (d) => d.generalMode.toolbarWidthPolicy,
    allowed: [
      generalToolbarWidthPolicyContent,
      generalToolbarWidthPolicyBalanced,
      generalToolbarWidthPolicyCalendarPriority,
      generalToolbarWidthPolicyDatePriority,
    ],
    platform: SettingPlatform.touchLayout,
  );
  add(
    'general.dateLabelFormat',
    SettingScope.general,
    SettingValueType.enumeration,
    generalDefaults.dateLabelFormat,
    (d) => d.generalMode.dateLabelFormat,
    allowed: [
      generalDateLabelFormatLocalized,
      generalDateLabelFormatSlash,
      generalDateLabelFormatIso,
    ],
  );
  add(
    'general.customDayMinWidth',
    SettingScope.general,
    SettingValueType.integer,
    null,
    (d) => d.generalMode.customDayMinWidth,
    nullable: true,
    min: generalCustomDayMinWidthMin,
    max: generalCustomDayMinWidthMax,
    step: generalCustomDayMinWidthStep,
    resetMeaning: 'Remove the explicit width and use automatic layout.',
  );
  add(
    'general.dayStartHour',
    SettingScope.general,
    SettingValueType.integer,
    generalDefaults.dayStartHour,
    (d) => d.generalMode.dayStartHour,
    min: 0,
    max: 23,
  );
  add(
    'general.dayEndHour',
    SettingScope.general,
    SettingValueType.integer,
    generalDefaults.dayEndHour,
    (d) => d.generalMode.dayEndHour,
    min: 1,
    max: 24,
  );
  add(
    'general.timeGridMinutes',
    SettingScope.general,
    SettingValueType.integer,
    generalDefaults.timeGridMinutes,
    (d) => d.generalMode.timeGridMinutes,
    allowed: [15, 30, 60],
  );
  add(
    'general.timeGridHourHeight',
    SettingScope.general,
    SettingValueType.integer,
    generalTimeGridHourHeightDefault,
    (d) => d.generalMode.timeGridHourHeight,
    min: generalTimeGridHourHeightMin,
    max: generalTimeGridHourHeightMax,
    step: generalTimeGridHourHeightStep,
  );
  add(
    'general.toolbarNavigationOrder',
    SettingScope.general,
    SettingValueType.stringList,
    generalToolbarNavigationDefaultOrder,
    (d) => d.generalMode.toolbarNavigationOrder,
    allowed: generalToolbarNavigationKnownIds,
  );
  add(
    'general.hiddenToolbarNavigationIds',
    SettingScope.general,
    SettingValueType.stringList,
    toolbarNavigationDefaultHiddenIds,
    (d) => d.generalMode.hiddenToolbarNavigationIds,
    allowed: generalToolbarNavigationKnownIds,
  );
  add(
    'general.toolbarHiddenItemsBehavior',
    SettingScope.general,
    SettingValueType.enumeration,
    toolbarHiddenItemsBehaviorRemove,
    (d) => d.generalMode.toolbarHiddenItemsBehavior,
    allowed: [toolbarHiddenItemsBehaviorRemove, toolbarHiddenItemsBehaviorMore],
  );

  for (final mode in [AppMode.student, AppMode.general]) {
    final student = mode == AppMode.student;
    final prefix = mode.value;
    final scope = student ? SettingScope.student : SettingScope.general;
    add(
      '$prefix.themeMode',
      scope,
      SettingValueType.enumeration,
      defaultThemeMode,
      (d) => student ? d.studentMode.themeMode : d.generalMode.themeMode,
      allowed: ['system', 'light', 'dark'],
    );
    add(
      '$prefix.themeColorMode',
      scope,
      SettingValueType.enumeration,
      student ? defaults.studentThemeColorMode : defaultThemeColorMode,
      (d) =>
          student ? d.studentMode.themeColorMode : d.generalMode.themeColorMode,
      allowed: [themeColorModeSingle, themeColorModeColorful],
      defaultSource: student
          ? SettingDefaultSource.applicationContext
          : SettingDefaultSource.fixed,
    );
    add(
      '$prefix.themeSeedColorValue',
      scope,
      SettingValueType.integer,
      defaultThemeSeedColorValue,
      (d) => student
          ? d.studentMode.themeSeedColorValue
          : d.generalMode.themeSeedColorValue,
      min: 0,
      max: 0xffffffff,
    );
    add(
      '$prefix.colorfulUiColorValues',
      scope,
      SettingValueType.colorMap,
      const <String, int>{},
      (d) => student
          ? d.studentMode.colorfulUiColorValues
          : d.generalMode.colorfulUiColorValues,
      allowed: [
        colorfulUiPrimaryKey,
        colorfulUiSecondaryKey,
        colorfulUiTertiaryKey,
        if (student) colorfulCourseTextColorKey,
        if (!student) ...colorfulGeneralCalendarColorKeys,
        if (!student) ...colorfulGeneralMonthTextColorKeys,
      ],
      resetMeaning:
          'Remove explicit color overrides and use theme-derived colors.',
    );
  }

  add(
    'student.activeTimetableId',
    SettingScope.student,
    SettingValueType.string,
    null,
    (d) => d.studentMode.activeTimetableId,
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  add(
    'student.conflictDisplayCourseIds',
    SettingScope.student,
    SettingValueType.object,
    null,
    (d) => d.studentMode.conflictDisplayCourseIds,
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  add(
    'general.activeScheduleId',
    SettingScope.general,
    SettingValueType.string,
    null,
    (d) => d.generalMode.activeScheduleId,
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  add(
    'general.selectedDateIso',
    SettingScope.general,
    SettingValueType.string,
    null,
    (d) => d.generalMode.selectedDateIso,
    nullable: true,
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  add(
    'general.customDateRange',
    SettingScope.general,
    SettingValueType.object,
    null,
    (d) => d.generalMode.customDateRange?.toJson(),
    nullable: true,
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  for (final field in [
    'source',
    'customBaseUrl',
    'customModel',
    'customPrompt',
  ]) {
    // Legacy parser mutations and sensitive destination presentation belong to
    // the migration/connection adapter. Never expose the runtime API key.
    add(
      'legacy.parser.$field',
      SettingScope.legacy,
      SettingValueType.string,
      null,
      null,
      adapter: true,
      readOnly: true,
      sensitive: field == 'customBaseUrl' || field == 'customPrompt',
      defaultSource: SettingDefaultSource.adapter,
    );
  }
  for (final region in DesktopLayoutRegion.values) {
    for (final dimension in ['width', 'height', 'dockedWidth']) {
      add(
        'device.layout.${region.name}.$dimension',
        SettingScope.device,
        SettingValueType.number,
        null,
        null,
        nullable: true,
        min: 0,
        minExclusive: true,
        adapter: true,
        platform: SettingPlatform.desktopLayout,
        defaultSource: SettingDefaultSource.adapter,
        resetMeaning:
            'Remove this explicit device dimension through the layout adapter.',
      );
    }
  }
  add(
    'device.assistantPreviewEnabled',
    SettingScope.device,
    SettingValueType.boolean,
    false,
    null,
    adapter: true,
  );
  add(
    'device.schoolSites',
    SettingScope.device,
    SettingValueType.object,
    null,
    null,
    adapter: true,
    defaultSource: SettingDefaultSource.adapter,
  );
  for (final name in [
    'notifications',
    'exactAlarms',
    'batteryOptimization',
    'autostart',
    'credentialStatus',
  ]) {
    add(
      'platform.$name',
      SettingScope.platform,
      SettingValueType.object,
      null,
      null,
      adapter: true,
      readOnly: true,
      defaultSource: SettingDefaultSource.adapter,
      platform:
          ['exactAlarms', 'batteryOptimization', 'autostart'].contains(name)
          ? SettingPlatform.android
          : SettingPlatform.all,
    );
  }
  return Map.unmodifiable(bindings);
}

String? _settingAdapterTool(String key) {
  if (key.startsWith('device.layout.')) return 'device.layout.prepare';
  return switch (key) {
    'app.activeMode' || 'app.enabledWorkspaces' => 'workspaces.prepare',
    'app.agentSettings' => 'agent_settings.prepare',
    'agent.protocol' ||
    'agent.endpoint' ||
    'agent.model' ||
    'agent.models' ||
    'agent.credentialRef' => 'connection.prepare',
    'student.activeTimetableId' ||
    'general.activeScheduleId' ||
    'general.selectedDateIso' => 'navigation.open',
    'student.conflictDisplayCourseIds' => 'courses.display.prepare',
    'general.customDateRange' => 'navigation.range.prepare',
    'device.assistantPreviewEnabled' => 'device.preferences.prepare',
    'device.schoolSites' => 'school_sites.prepare',
    _ => null,
  };
}
