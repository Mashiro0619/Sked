import 'dart:convert';

import 'app_data_json_values.dart';
import 'app_data_storage_validation.dart';
import 'import_count_limits.dart';

import '../data/migrations/app_data_migrations.dart';
import '../l10n/app_locale.dart';
import '../utils/constants.dart';
import '../utils/import_id_sanitizer.dart';
import '../utils/localized_names.dart';
import '../utils/time_utils.dart';
import 'app_mode.dart';
import 'ai_api_settings.dart';
import 'course_item.dart';
import 'general_schedule.dart';
import 'general_schedule_data.dart';
import 'notification_settings.dart';
import 'student_mode_data.dart';
import 'timetable_data.dart';
import 'workspace_panel_display_mode.dart';

const Symbol _keepNullable = #keep;

class _ThemeSettingsSnapshot {
  const _ThemeSettingsSnapshot({
    required this.themeMode,
    required this.themeColorMode,
    required this.themeSeedColorValue,
    required this.colorfulUiColorValues,
  });

  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;

  _ThemeSettingsSnapshot copyWith({
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
  }) {
    return _ThemeSettingsSnapshot(
      themeMode: normalizeThemeMode(themeMode ?? this.themeMode),
      themeColorMode: normalizeThemeColorMode(
        themeColorMode ?? this.themeColorMode,
      ),
      themeSeedColorValue: themeSeedColorValue ?? this.themeSeedColorValue,
      colorfulUiColorValues:
          colorfulUiColorValues ?? this.colorfulUiColorValues,
    );
  }
}

const _modeThemeFieldKeys = {
  'themeMode',
  'themeColorMode',
  'themeSeedColorValue',
  'colorfulUiColorValues',
};

bool _hasModeThemeFields(Map<String, dynamic> json) {
  return _modeThemeFieldKeys.any(json.containsKey);
}

_ThemeSettingsSnapshot _decodeLegacyThemeSettings(Map<String, dynamic> json) {
  return _ThemeSettingsSnapshot(
    themeMode: normalizeThemeMode(
      appDataStringValue(json['themeMode'], defaultThemeMode),
    ),
    themeColorMode: normalizeThemeColorMode(
      appDataStringValue(json['themeColorMode'], defaultThemeColorMode),
    ),
    themeSeedColorValue:
        appDataParsedIntValue(json['themeSeedColorValue']) ??
        defaultThemeSeedColorValue,
    colorfulUiColorValues: decodeColorValueMap(json['colorfulUiColorValues']),
  );
}

StudentModeData _applyThemeSettingsToStudentMode(
  StudentModeData data,
  _ThemeSettingsSnapshot theme,
) {
  return data.copyWith(
    themeMode: theme.themeMode,
    themeColorMode: theme.themeColorMode,
    themeSeedColorValue: theme.themeSeedColorValue,
    colorfulUiColorValues: theme.colorfulUiColorValues,
  );
}

GeneralScheduleData _applyThemeSettingsToGeneralMode(
  GeneralScheduleData data,
  _ThemeSettingsSnapshot theme,
) {
  return data.copyWith(
    themeMode: theme.themeMode,
    themeColorMode: theme.themeColorMode,
    themeSeedColorValue: theme.themeSeedColorValue,
    colorfulUiColorValues: theme.colorfulUiColorValues,
  );
}

_ThemeSettingsSnapshot _themeSettingsForMode(
  AppMode mode,
  StudentModeData studentMode,
  GeneralScheduleData generalMode,
) {
  return switch (mode) {
    AppMode.general => _ThemeSettingsSnapshot(
      themeMode: generalMode.themeMode,
      themeColorMode: generalMode.themeColorMode,
      themeSeedColorValue: generalMode.themeSeedColorValue,
      colorfulUiColorValues: generalMode.colorfulUiColorValues,
    ),
    AppMode.student => _ThemeSettingsSnapshot(
      themeMode: studentMode.themeMode,
      themeColorMode: studentMode.themeColorMode,
      themeSeedColorValue: studentMode.themeSeedColorValue,
      colorfulUiColorValues: studentMode.colorfulUiColorValues,
    ),
  };
}

class AppData {
  factory AppData({
    required AppMode activeMode,
    Set<AppMode> enabledWorkspaces = const {AppMode.student, AppMode.general},
    Map<AppMode, DateTime> workspaceReminderNotBefore = const {},
    required StudentModeData studentMode,
    required GeneralScheduleData generalMode,
    String localeCode = defaultLocaleCode,
    bool hideHomeWorkspaceNavigation = false,
    bool homeWorkspaceNavigationCollapsed = false,
    WorkspacePanelDisplayMode workspacePanelDisplayMode =
        WorkspacePanelDisplayMode.overlay,
    AiApiSettings aiApiSettings = const AiApiSettings(),
    NotificationSettings notificationSettings = const NotificationSettings(),
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
    String? privacyPolicyAcceptedVersion,
    String? privacyPolicyAcceptedAtIso,
    bool includePrereleaseUpdates = true,
    String? ignoredUpdateVersion,
    String? availableUpdateVersion,
  }) {
    if (enabledWorkspaces.isEmpty || !enabledWorkspaces.contains(activeMode)) {
      throw const FormatException('Active workspace must be enabled.');
    }
    var nextStudentMode = studentMode;
    var nextGeneralMode = generalMode;
    final hasThemeUpdate =
        themeMode != null ||
        themeColorMode != null ||
        themeSeedColorValue != null ||
        colorfulUiColorValues != null;
    if (hasThemeUpdate) {
      final currentTheme = _themeSettingsForMode(
        activeMode,
        nextStudentMode,
        nextGeneralMode,
      );
      final updatedTheme = currentTheme.copyWith(
        themeMode: themeMode,
        themeColorMode: themeColorMode,
        themeSeedColorValue: themeSeedColorValue,
        colorfulUiColorValues: colorfulUiColorValues,
      );
      switch (activeMode) {
        case AppMode.general:
          nextGeneralMode = _applyThemeSettingsToGeneralMode(
            nextGeneralMode,
            updatedTheme,
          );
        case AppMode.student:
          nextStudentMode = _applyThemeSettingsToStudentMode(
            nextStudentMode,
            updatedTheme,
          );
      }
    }
    return AppData._(
      activeMode: activeMode,
      enabledWorkspaces: Set.unmodifiable(enabledWorkspaces),
      workspaceReminderNotBefore: Map.unmodifiable(workspaceReminderNotBefore),
      studentMode: nextStudentMode,
      generalMode: nextGeneralMode,
      localeCode: localeCode,
      hideHomeWorkspaceNavigation: hideHomeWorkspaceNavigation,
      homeWorkspaceNavigationCollapsed: homeWorkspaceNavigationCollapsed,
      workspacePanelDisplayMode: workspacePanelDisplayMode,
      aiApiSettings: aiApiSettings,
      notificationSettings: notificationSettings,
      privacyPolicyAcceptedVersion: privacyPolicyAcceptedVersion,
      privacyPolicyAcceptedAtIso: privacyPolicyAcceptedAtIso,
      includePrereleaseUpdates: includePrereleaseUpdates,
      ignoredUpdateVersion: ignoredUpdateVersion,
      availableUpdateVersion: availableUpdateVersion,
    );
  }

  const AppData._({
    required this.activeMode,
    required this.enabledWorkspaces,
    required this.workspaceReminderNotBefore,
    required this.studentMode,
    required this.generalMode,
    this.localeCode = defaultLocaleCode,
    this.hideHomeWorkspaceNavigation = false,
    this.homeWorkspaceNavigationCollapsed = false,
    this.workspacePanelDisplayMode = WorkspacePanelDisplayMode.overlay,
    this.aiApiSettings = const AiApiSettings(),
    this.notificationSettings = const NotificationSettings(),
    this.privacyPolicyAcceptedVersion,
    this.privacyPolicyAcceptedAtIso,
    this.includePrereleaseUpdates = true,
    this.ignoredUpdateVersion,
    this.availableUpdateVersion,
  });

  final AppMode activeMode;
  final Set<AppMode> enabledWorkspaces;
  final Map<AppMode, DateTime> workspaceReminderNotBefore;

  bool isWorkspaceEnabled(AppMode mode) => enabledWorkspaces.contains(mode);

  final StudentModeData studentMode;
  final GeneralScheduleData generalMode;
  final String localeCode;
  final bool hideHomeWorkspaceNavigation;
  final bool homeWorkspaceNavigationCollapsed;
  final WorkspacePanelDisplayMode workspacePanelDisplayMode;
  final AiApiSettings aiApiSettings;
  final NotificationSettings notificationSettings;
  final String? privacyPolicyAcceptedVersion;
  final String? privacyPolicyAcceptedAtIso;
  final bool includePrereleaseUpdates;
  final String? ignoredUpdateVersion;
  final String? availableUpdateVersion;

  _ThemeSettingsSnapshot get _activeThemeSettings =>
      _themeSettingsForMode(activeMode, studentMode, generalMode);

  String get themeMode => _activeThemeSettings.themeMode;
  String get themeColorMode => _activeThemeSettings.themeColorMode;
  int get themeSeedColorValue => _activeThemeSettings.themeSeedColorValue;
  Map<String, int> get colorfulUiColorValues =>
      _activeThemeSettings.colorfulUiColorValues;

  Map<String, dynamic> toJson() => {
    'schemaVersion': appDataCurrentSchemaVersion,
    'activeMode': activeMode.value,
    'enabledWorkspaces': [
      for (final mode in AppMode.values)
        if (isWorkspaceEnabled(mode)) mode.value,
    ],
    if (workspaceReminderNotBefore.isNotEmpty)
      'workspaceReminderNotBefore': {
        for (final entry in workspaceReminderNotBefore.entries)
          entry.key.value: entry.value.toUtc().toIso8601String(),
      },
    'studentMode': studentMode.toJson(),
    'generalMode': generalMode.toJson(),
    'localeCode': normalizeLocaleCode(localeCode),
    // Keep the persisted key stable: the setting now controls every adaptive
    // navigation shape, but its storage representation is still schema v2.
    'hideHomeBottomNavigationBar': hideHomeWorkspaceNavigation,
    'homeWorkspaceNavigationCollapsed': homeWorkspaceNavigationCollapsed,
    if (workspacePanelDisplayMode != WorkspacePanelDisplayMode.overlay)
      'workspacePanelDisplayMode': workspacePanelDisplayMode.value,
    'aiApiSettings': aiApiSettings.toJson(),
    // Keep the default snapshot byte-for-byte compatible with pre-notification
    // data.  The optional object is written as soon as the user changes one
    // of its values, and older readers can safely ignore it.
    if (notificationSettings != const NotificationSettings())
      'notificationSettings': notificationSettings.normalized().toJson(),
    if (privacyPolicyAcceptedVersion != null)
      'privacyPolicyAcceptedVersion': privacyPolicyAcceptedVersion,
    if (privacyPolicyAcceptedAtIso != null)
      'privacyPolicyAcceptedAtIso': privacyPolicyAcceptedAtIso,
    'includePrereleaseUpdates': includePrereleaseUpdates,
    if (ignoredUpdateVersion != null)
      'ignoredUpdateVersion': ignoredUpdateVersion,
    if (availableUpdateVersion != null)
      'availableUpdateVersion': availableUpdateVersion,
  };

  factory AppData.fromJson(Map<String, dynamic> json) {
    if ((tryDecodeAppDataVersion(json['schemaVersion']) ?? 0) >= 3 &&
        (tryDecodeAppDataVersion(json['schemaVersion']) ?? 0) <=
            appDataCurrentSchemaVersion &&
        !AppMode.values.any((mode) => mode.value == json['activeMode'])) {
      throw const FormatException('Stored active workspace is invalid.');
    }
    final usesLegacyThemeOwnership =
        !json.containsKey('schemaVersion') ||
        tryDecodeAppDataVersion(json['schemaVersion']) == 1;
    // Run schemaVersion migrations before any field decoding so legacy data
    // and future bumps are handled in one place instead of being scattered
    // across this fromJson body.
    final migrated = appDataMigrationRunner.run(json);

    final localeCode = normalizeLocaleCode(
      appDataStringValue(migrated['localeCode'], defaultLocaleCode),
    );

    // Detect legacy format: old flat keys exist and studentMode key is absent
    final isLegacy =
        migrated.containsKey('timetables') &&
        !migrated.containsKey('studentMode');

    final legacyThemeSettings = _decodeLegacyThemeSettings(migrated);

    StudentModeData studentMode;
    GeneralScheduleData generalMode;
    final AppMode activeMode;
    Map<String, dynamic> studentModeJson = const {};
    Map<String, dynamic> generalModeJson = const {};

    if (isLegacy) {
      // Migrate legacy flat JSON to nested StudentModeData
      studentModeJson = migrated;
      studentMode = StudentModeData.fromJson(migrated, localeCode: localeCode);
      generalModeJson = const {};
      generalMode = GeneralScheduleData.fromJson(
        const {},
        localeCode: localeCode,
      );
      activeMode = studentMode.timetables.isNotEmpty
          ? AppMode.student
          : AppMode.general;
    } else {
      studentModeJson =
          appDataStringKeyedMap(migrated['studentMode']) ?? const {};
      studentMode = migrated.containsKey('studentMode')
          ? StudentModeData.fromJson(studentModeJson, localeCode: localeCode)
          : StudentModeData.fromJson({}, localeCode: localeCode);
      generalModeJson =
          appDataStringKeyedMap(migrated['generalMode']) ?? const {};
      generalMode = migrated.containsKey('generalMode')
          ? GeneralScheduleData.fromJson(
              generalModeJson,
              localeCode: localeCode,
            )
          : _buildDefaultGeneralMode(localeCode: localeCode);
      activeMode = parseAppMode(
        appDataNullableStringValue(migrated['activeMode']),
      );
    }

    if (isLegacy || usesLegacyThemeOwnership) {
      if (!_hasModeThemeFields(studentModeJson)) {
        studentMode = _applyThemeSettingsToStudentMode(
          studentMode,
          legacyThemeSettings,
        );
      }
      if (!_hasModeThemeFields(generalModeJson)) {
        generalMode = _applyThemeSettingsToGeneralMode(
          generalMode,
          legacyThemeSettings,
        );
      }
    }
    return AppData(
      activeMode: activeMode,
      enabledWorkspaces: _decodeEnabledWorkspaces(migrated),
      workspaceReminderNotBefore: _decodeWorkspaceReminderBoundaries(migrated),
      studentMode: studentMode,
      generalMode: generalMode,
      localeCode: localeCode,
      hideHomeWorkspaceNavigation: _decodeHideHomeWorkspaceNavigation(migrated),
      homeWorkspaceNavigationCollapsed: _decodeHomeWorkspaceNavigationCollapsed(
        migrated,
      ),
      workspacePanelDisplayMode:
          migrated.containsKey('workspacePanelDisplayMode')
          ? WorkspacePanelDisplayMode.fromJson(
              migrated['workspacePanelDisplayMode'],
            )
          : WorkspacePanelDisplayMode.overlay,
      aiApiSettings: AiApiSettings.fromJson(
        _decodeAiApiSettingsJson(migrated, studentModeJson),
      ),
      notificationSettings: NotificationSettings.fromJson(
        _decodeNotificationSettingsJson(migrated),
      ),
      privacyPolicyAcceptedVersion: appDataNullableStringValue(
        migrated['privacyPolicyAcceptedVersion'],
      ),
      privacyPolicyAcceptedAtIso: appDataNullableStringValue(
        migrated['privacyPolicyAcceptedAtIso'],
      ),
      // Older versions omitted false, so a missing stored flag may be an
      // explicit opt-out. Only newly constructed data uses the enabled default.
      includePrereleaseUpdates: migrated['includePrereleaseUpdates'] == true,
      ignoredUpdateVersion: appDataNullableStringValue(
        migrated['ignoredUpdateVersion'],
      ),
      availableUpdateVersion: appDataNullableStringValue(
        migrated['availableUpdateVersion'],
      ),
    );
  }

  AppData copyWith({
    AppMode? activeMode,
    Set<AppMode>? enabledWorkspaces,
    Map<AppMode, DateTime>? workspaceReminderNotBefore,
    StudentModeData? studentMode,
    GeneralScheduleData? generalMode,
    String? localeCode,
    bool? hideHomeWorkspaceNavigation,
    bool? homeWorkspaceNavigationCollapsed,
    WorkspacePanelDisplayMode? workspacePanelDisplayMode,
    AiApiSettings? aiApiSettings,
    NotificationSettings? notificationSettings,
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
    Object? privacyPolicyAcceptedVersion = _keepNullable,
    Object? privacyPolicyAcceptedAtIso = _keepNullable,
    bool? includePrereleaseUpdates,
    Object? ignoredUpdateVersion = _keepNullable,
    Object? availableUpdateVersion = _keepNullable,
  }) {
    final nextActiveMode = activeMode ?? this.activeMode;
    var nextStudentMode = studentMode ?? this.studentMode;
    var nextGeneralMode = generalMode ?? this.generalMode;
    final nextAiApiSettings = aiApiSettings ?? this.aiApiSettings;
    final hasThemeUpdate =
        themeMode != null ||
        themeColorMode != null ||
        themeSeedColorValue != null ||
        colorfulUiColorValues != null;
    if (hasThemeUpdate) {
      final currentTheme = _themeSettingsForMode(
        nextActiveMode,
        nextStudentMode,
        nextGeneralMode,
      );
      final updatedTheme = currentTheme.copyWith(
        themeMode: themeMode,
        themeColorMode: themeColorMode,
        themeSeedColorValue: themeSeedColorValue,
        colorfulUiColorValues: colorfulUiColorValues,
      );
      switch (nextActiveMode) {
        case AppMode.general:
          nextGeneralMode = _applyThemeSettingsToGeneralMode(
            nextGeneralMode,
            updatedTheme,
          );
        case AppMode.student:
          nextStudentMode = _applyThemeSettingsToStudentMode(
            nextStudentMode,
            updatedTheme,
          );
      }
    }
    return AppData(
      activeMode: nextActiveMode,
      enabledWorkspaces: enabledWorkspaces ?? this.enabledWorkspaces,
      workspaceReminderNotBefore:
          workspaceReminderNotBefore ?? this.workspaceReminderNotBefore,
      studentMode: nextStudentMode,
      generalMode: nextGeneralMode,
      localeCode: normalizeLocaleCode(localeCode ?? this.localeCode),
      hideHomeWorkspaceNavigation:
          hideHomeWorkspaceNavigation ?? this.hideHomeWorkspaceNavigation,
      homeWorkspaceNavigationCollapsed:
          homeWorkspaceNavigationCollapsed ??
          this.homeWorkspaceNavigationCollapsed,
      workspacePanelDisplayMode:
          workspacePanelDisplayMode ?? this.workspacePanelDisplayMode,
      aiApiSettings: nextAiApiSettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      privacyPolicyAcceptedVersion:
          identical(privacyPolicyAcceptedVersion, _keepNullable)
          ? this.privacyPolicyAcceptedVersion
          : privacyPolicyAcceptedVersion as String?,
      privacyPolicyAcceptedAtIso:
          identical(privacyPolicyAcceptedAtIso, _keepNullable)
          ? this.privacyPolicyAcceptedAtIso
          : privacyPolicyAcceptedAtIso as String?,
      includePrereleaseUpdates:
          includePrereleaseUpdates ?? this.includePrereleaseUpdates,
      ignoredUpdateVersion: identical(ignoredUpdateVersion, _keepNullable)
          ? this.ignoredUpdateVersion
          : ignoredUpdateVersion as String?,
      availableUpdateVersion: identical(availableUpdateVersion, _keepNullable)
          ? this.availableUpdateVersion
          : availableUpdateVersion as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory AppData.decode(String source) {
    return AppData.fromJson(decodeAppDataJsonObject(source));
  }

  factory AppData.decodeStorageSnapshot(String source) {
    final json = decodeAppDataJsonObject(source);
    final migrated = appDataMigrationRunner.run(json);
    validateAppDataStorageSnapshot(migrated);
    return AppData.fromJson(migrated);
  }
}

Set<AppMode> _decodeEnabledWorkspaces(Map<String, dynamic> json) {
  final raw = json['enabledWorkspaces'];
  if (raw is! List ||
      raw.isEmpty ||
      raw.length > AppMode.values.length ||
      raw.toSet().length != raw.length ||
      raw.any((value) => !AppMode.values.any((mode) => mode.value == value))) {
    throw const FormatException('Stored enabled workspaces are invalid.');
  }
  return raw
      .map((value) => AppMode.values.singleWhere((mode) => mode.value == value))
      .toSet();
}

Map<AppMode, DateTime> _decodeWorkspaceReminderBoundaries(
  Map<String, dynamic> json,
) {
  if (!json.containsKey('workspaceReminderNotBefore')) return const {};
  final raw = json['workspaceReminderNotBefore'];
  if (raw is! Map) {
    throw const FormatException('Stored reminder boundaries are invalid.');
  }
  final result = <AppMode, DateTime>{};
  for (final entry in raw.entries) {
    if (!AppMode.values.any((mode) => mode.value == entry.key) ||
        entry.value is! String) {
      throw const FormatException('Stored reminder boundary is invalid.');
    }
    final date = DateTime.tryParse(entry.value as String);
    if (date == null || !date.isUtc) {
      throw const FormatException('Stored reminder boundary must be UTC.');
    }
    result[AppMode.values.singleWhere((mode) => mode.value == entry.key)] =
        date;
  }
  return result;
}

Map<String, dynamic> _decodeAiApiSettingsJson(
  Map<String, dynamic> json,
  Map<String, dynamic> studentModeJson,
) {
  if (json.containsKey('aiApiSettings')) {
    final value = appDataStringKeyedMap(json['aiApiSettings']);
    if (value == null) {
      throw const FormatException('AI API settings must be an object.');
    }
    return value;
  }
  // Keep reading the legacy nested location so existing data migrates on the
  // next save, while preserving strict decoding when it is present.
  if (studentModeJson.containsKey('schoolImportParserSettings')) {
    final value = appDataStringKeyedMap(
      studentModeJson['schoolImportParserSettings'],
    );
    if (value == null) {
      throw const FormatException('Legacy AI API settings must be an object.');
    }
    return value;
  }
  return const {};
}

Map<String, dynamic> _decodeNotificationSettingsJson(
  Map<String, dynamic> json,
) {
  if (!json.containsKey('notificationSettings')) {
    return const {};
  }
  final value = appDataStringKeyedMap(json['notificationSettings']);
  if (value == null) {
    throw const FormatException('Notification settings must be an object.');
  }
  return value;
}

bool _decodeHideHomeWorkspaceNavigation(Map<String, dynamic> json) {
  const persistedKey = 'hideHomeBottomNavigationBar';
  const developmentKey = 'hideHomeWorkspaceNavigation';
  // Prefer the development key if a local build wrote it before this rename
  // was finalized, then converge back to the schema-v2 key on the next save.
  final key = json.containsKey(developmentKey) ? developmentKey : persistedKey;
  if (!json.containsKey(key)) {
    return false;
  }
  final value = json[key];
  if (value is! bool) {
    throw const FormatException('Home navigation setting is invalid.');
  }
  return value;
}

bool _decodeHomeWorkspaceNavigationCollapsed(Map<String, dynamic> json) {
  const key = 'homeWorkspaceNavigationCollapsed';
  if (!json.containsKey(key)) {
    return false;
  }
  final value = json[key];
  if (value is! bool) {
    throw const FormatException(
      'Home workspace navigation collapsed setting is invalid.',
    );
  }
  return value;
}

GeneralScheduleData _buildDefaultGeneralMode({
  String localeCode = defaultLocaleCode,
}) {
  return GeneralScheduleData.createDefault(localeCode: localeCode);
}

// Import/Export support

class ImportExportEnvelope {
  const ImportExportEnvelope({
    required this.schema,
    required this.version,
    required this.data,
  });

  final String schema;
  final int version;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'version': version,
    'data': data,
  };

  factory ImportExportEnvelope.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = appDataStringKeyedMap(rawData);
    if (json.containsKey('data') && data == null) {
      throw const FormatException('Import/export data format is invalid.');
    }
    final version =
        readOptionalAppDataVersion(
          json,
          'version',
          errorMessage: 'Import/export version is invalid.',
        ) ??
        1;
    return ImportExportEnvelope(
      schema: appDataStringValue(json['schema']),
      version: version,
      data: data ?? const {},
    );
  }

  String encode() => jsonEncode(toJson());

  factory ImportExportEnvelope.decode(String source) {
    return ImportExportEnvelope.fromJson(decodeAppDataJsonObject(source));
  }
}

void _ensureSupportedEnvelope(
  ImportExportEnvelope envelope, {
  required String expectedSchema,
  String localeCode = defaultLocaleCode,
}) {
  if (!isImportExportSchema(envelope.schema, expectedSchema)) {
    throw FormatException(
      importFileTypeMismatchMessage(localeCode: localeCode),
    );
  }
  if (envelope.version > importExportVersion) {
    throw FormatException(
      importFileVersionUnsupportedMessage(localeCode: localeCode),
    );
  }
}

const _importExportSchemaAliases = <String, Set<String>>{
  appDataSchema: {
    appDataSchema,
    'classmate-app-data',
    'KeSchedule-app-data',
    'Sked-app-data',
  },
  timetableDataSchema: {
    timetableDataSchema,
    'classmate-timetable-data',
    'KeSchedule-timetable-data',
    'Sked-timetable-data',
  },
  periodTimesSchema: {
    periodTimesSchema,
    'classmate-period-times',
    'KeSchedule-period-times',
    'Sked-period-times',
  },
  generalScheduleDataSchema: {
    generalScheduleDataSchema,
    'Sked-general-schedule-data',
  },
  appBackupSchema: {appBackupSchema},
};

bool isImportExportSchema(String schema, String expectedSchema) {
  return _importExportSchemaAliases[expectedSchema]?.contains(schema) ??
      schema == expectedSchema;
}

String encodeAppDataEnvelope(AppData data) {
  return ImportExportEnvelope(
    schema: appDataSchema,
    version: importExportVersion,
    data: data.toJson(),
  ).encode();
}

String encodeTimetableDataEnvelope(TimetableExportData data) {
  return ImportExportEnvelope(
    schema: timetableDataSchema,
    version: importExportVersion,
    data: data.toJson(),
  ).encode();
}

String encodePeriodTimesEnvelope(List<CoursePeriodTime> periodTimes) {
  return ImportExportEnvelope(
    schema: periodTimesSchema,
    version: importExportVersion,
    data: {'periodTimes': periodTimes.map((item) => item.toJson()).toList()},
  ).encode();
}

List<CoursePeriodTime> decodePeriodTimesEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: periodTimesSchema,
    localeCode: localeCode,
  );
  validateImportCounts(
    envelope.data,
    kind: ImportCountKind.periodTimes,
    localeCode: localeCode,
  );
  final rawPeriodTimes = appDataListValue(envelope.data['periodTimes']);
  final periodTimes = rawPeriodTimes
      .map(appDataStringKeyedMap)
      .whereType<Map<String, dynamic>>()
      .map(CoursePeriodTime.fromJson)
      .toList();
  if (rawPeriodTimes.isNotEmpty && periodTimes.isEmpty) {
    throw const FormatException('Period times JSON format is invalid.');
  }
  return periodTimes;
}

AppData decodeAppDataEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: appDataSchema,
    localeCode: localeCode,
  );
  validateImportCounts(
    envelope.data,
    kind: ImportCountKind.appData,
    localeCode: localeCode,
  );
  return AppData.fromJson({...envelope.data, 'localeCode': localeCode});
}

TimetableExportData decodeTimetableDataEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: timetableDataSchema,
    localeCode: localeCode,
  );
  validateImportCounts(
    envelope.data,
    kind: ImportCountKind.timetables,
    localeCode: localeCode,
  );
  return TimetableExportData.fromJson(envelope.data, localeCode: localeCode);
}

AppData buildInitialAppData(
  List<CoursePeriodTime> periodTimes, {
  String localeCode = defaultLocaleCode,
  bool includePrereleaseUpdates = true,
}) {
  final defaultSet = PeriodTimeSet(
    id: defaultPeriodTimeSetId,
    name: defaultPeriodTimeSetName(localeCode: localeCode),
    periodTimes: buildPeriodTimesForCount(
      periodTimes.isEmpty ? 1 : periodTimes.length,
      source: periodTimes,
    ),
  );

  return AppData(
    activeMode: AppMode.student,
    studentMode: StudentModeData(
      activeTimetableId: '',
      timetables: const [],
      periodTimeSets: [defaultSet],
      themeMode: newUserDefaultThemeMode,
    ),
    generalMode: GeneralScheduleData.createDefault(localeCode: localeCode)
        .copyWith(themeMode: newUserDefaultThemeMode),
    localeCode: localeCode,
    includePrereleaseUpdates: includePrereleaseUpdates,
  );
}

enum GeneralScheduleImportMode { addAsNew, replaceActive }

class GeneralScheduleExportData {
  const GeneralScheduleExportData({required this.schedules});

  final List<GeneralSchedule> schedules;

  Map<String, dynamic> toJson() => {
    'schemaVersion': generalScheduleSchemaVersion,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };

  factory GeneralScheduleExportData.fromJson(
    Map<String, dynamic> json, {
    String localeCode = defaultLocaleCode,
  }) {
    final schemaVersion = readOptionalAppDataVersion(
      json,
      'schemaVersion',
      errorMessage: 'General schedule schemaVersion is invalid.',
    );
    if (schemaVersion != null && schemaVersion > generalScheduleSchemaVersion) {
      throw const FormatException(
        'General schedule schemaVersion is unsupported.',
      );
    }
    final raw = appDataListValue(json['schedules']);
    final scheduleMaps = raw
        .map(appDataStringKeyedMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    final usedScheduleIds = <String>{};
    final schedules = <GeneralSchedule>[];
    for (var i = 0; i < scheduleMaps.length; i++) {
      final schedule = GeneralSchedule.fromJson(
        scheduleMaps[i],
        localeCode: localeCode,
      );
      final scheduleId = normalizeImportedId(
        schedule.id,
        fallbackPrefix: 'calendar',
        existingIds: usedScheduleIds,
      );
      usedScheduleIds.add(scheduleId);
      schedules.add(
        schedule
            .copyWith(
              id: scheduleId,
              sortOrder: schedule.sortOrder < 0 ? i : schedule.sortOrder,
              events: [
                for (final event in schedule.events)
                  event.copyWith(calendarId: scheduleId),
              ],
            )
            .normalized(sortOrderFallback: i, localeCode: localeCode),
      );
    }
    if (raw.isNotEmpty && schedules.isEmpty) {
      throw const FormatException('General schedule JSON format is invalid.');
    }
    return GeneralScheduleExportData(schedules: schedules);
  }
}

String encodeGeneralScheduleDataEnvelope(GeneralScheduleExportData data) {
  return ImportExportEnvelope(
    schema: generalScheduleDataSchema,
    version: importExportVersion,
    data: data.toJson(),
  ).encode();
}

GeneralScheduleExportData decodeGeneralScheduleDataEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: generalScheduleDataSchema,
    localeCode: localeCode,
  );
  validateImportCounts(
    envelope.data,
    kind: ImportCountKind.schedules,
    localeCode: localeCode,
  );
  return GeneralScheduleExportData.fromJson(
    envelope.data,
    localeCode: localeCode,
  );
}
