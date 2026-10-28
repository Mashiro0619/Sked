import 'app_data_json_values.dart';

import 'dart:collection';

import '../l10n/app_locale.dart';
import '../utils/localized_names.dart';

import '../data/migrations/migration.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import '../utils/unique_id.dart';
import 'general_event.dart';
import 'general_event_occurrence.dart';
import 'general_schedule.dart';
import 'general_date_range.dart';

part 'general_occurrence_identity.dart';
part 'general_schedule_normalization.dart';

const generalViewWeek = 'week';
const generalViewDay = 'day';
const generalViewList = 'list';
const generalViewMonth = 'month';
const generalViewSwitchBehaviorCycle = 'cycle';
const generalViewSwitchBehaviorMenu = 'menu';
const generalToolbarWidthPolicyContent = 'content';
const generalToolbarWidthPolicyBalanced = 'balanced';
const generalToolbarWidthPolicyCalendarPriority = 'calendarPriority';
const generalToolbarWidthPolicyDatePriority = 'datePriority';
const generalDateLabelFormatLocalized = 'localized';
const generalDateLabelFormatSlash = 'slash';
const generalDateLabelFormatIso = 'iso';
const generalTimeGridHourHeightDefault = 72;
const generalTimeGridHourHeightMin = 36;
const generalTimeGridHourHeightMax = 120;
const generalTimeGridHourHeightStep = 4;
const generalScheduleSchemaVersion = 6;
const generalCustomDayMinWidthDefault = 96;
const generalCustomDayMinWidthMin = 64;
const generalCustomDayMinWidthMax = 320;
const generalCustomDayMinWidthStep = 8;

/// Null retains the legacy automatic fit/overflow policy. Widths are logical dp
/// before the timeline applies its accessibility text factor.
int? normalizeGeneralCustomDayMinWidth(int? value) {
  if (value == null) return null;
  final bounded = value.clamp(
    generalCustomDayMinWidthMin,
    generalCustomDayMinWidthMax,
  );
  return (bounded / generalCustomDayMinWidthStep).round() *
      generalCustomDayMinWidthStep;
}

bool _decodeGeneralAllDayTimelineCollapsed(Map<String, dynamic> json) {
  if (!json.containsKey('allDayTimelineCollapsed')) {
    return false;
  }
  final value = json['allDayTimelineCollapsed'];
  if (value is! bool) {
    throw const FormatException(
      'General schedule all-day timeline collapsed setting is invalid.',
    );
  }
  return value;
}

bool _hasLegacySchedulePayload(Map<String, dynamic> json) {
  return json.containsKey('schedules') || json.containsKey('activeScheduleId');
}

class GeneralReminderAcknowledgement {
  const GeneralReminderAcknowledgement({
    required this.occurrenceKey,
    this.isHandled = true,
    required this.updatedAtIso,
  });

  final String occurrenceKey;
  final bool isHandled;
  final String updatedAtIso;

  Map<String, dynamic> toJson() => {
    'occurrenceKey': occurrenceKey,
    'isHandled': isHandled,
    'updatedAt': updatedAtIso,
  };

  factory GeneralReminderAcknowledgement.fromJson(Map<String, dynamic> json) {
    return GeneralReminderAcknowledgement(
      occurrenceKey: appDataStringValue(json['occurrenceKey']),
      isHandled: appDataBoolValue(json['isHandled']) ?? true,
      updatedAtIso: appDataStringValue(json['updatedAt']),
    );
  }

  GeneralReminderAcknowledgement normalized() {
    final updatedAt = tryParseStrictIsoDateTime(updatedAtIso) ?? DateTime.now();
    return GeneralReminderAcknowledgement(
      occurrenceKey: occurrenceKey.trim(),
      isHandled: isHandled,
      updatedAtIso: updatedAt.toIso8601String(),
    );
  }
}

String normalizeGeneralView(String? value) {
  switch (value) {
    case generalViewDay:
    case generalViewList:
    case generalViewMonth:
    case generalViewWeek:
      return value!;
    default:
      return generalViewWeek;
  }
}

String normalizeGeneralViewSwitchBehavior(String? value) {
  switch (value) {
    case generalViewSwitchBehaviorMenu:
    case generalViewSwitchBehaviorCycle:
      return value!;
    default:
      return generalViewSwitchBehaviorMenu;
  }
}

String normalizeGeneralToolbarWidthPolicy(String? value) {
  switch (value) {
    case generalToolbarWidthPolicyBalanced:
    case generalToolbarWidthPolicyCalendarPriority:
    case generalToolbarWidthPolicyDatePriority:
    case generalToolbarWidthPolicyContent:
      return value!;
    default:
      return generalToolbarWidthPolicyContent;
  }
}

String normalizeGeneralDateLabelFormat(String? value) {
  switch (value) {
    case generalDateLabelFormatLocalized:
    case generalDateLabelFormatIso:
    case generalDateLabelFormatSlash:
      return value!;
    default:
      return generalDateLabelFormatSlash;
  }
}

String _decodeGeneralViewSwitchBehavior(Map<String, dynamic> json) {
  if (!json.containsKey('viewSwitchBehavior')) {
    return generalViewSwitchBehaviorMenu;
  }
  final value = json['viewSwitchBehavior'];
  if (value is! String ||
      !const {
        generalViewSwitchBehaviorCycle,
        generalViewSwitchBehaviorMenu,
      }.contains(value)) {
    throw const FormatException(
      'General schedule view switch behavior is invalid.',
    );
  }
  return value;
}

String _decodeGeneralToolbarWidthPolicy(Map<String, dynamic> json) {
  if (!json.containsKey('toolbarWidthPolicy')) {
    return generalToolbarWidthPolicyContent;
  }
  final value = json['toolbarWidthPolicy'];
  if (value is! String ||
      !const {
        generalToolbarWidthPolicyContent,
        generalToolbarWidthPolicyBalanced,
        generalToolbarWidthPolicyCalendarPriority,
        generalToolbarWidthPolicyDatePriority,
      }.contains(value)) {
    throw const FormatException(
      'General schedule toolbar width policy is invalid.',
    );
  }
  return value;
}

String _decodeGeneralDateLabelFormat(Map<String, dynamic> json) {
  if (!json.containsKey('dateLabelFormat')) {
    return generalDateLabelFormatSlash;
  }
  final value = json['dateLabelFormat'];
  if (value is! String ||
      !const {
        generalDateLabelFormatLocalized,
        generalDateLabelFormatSlash,
        generalDateLabelFormatIso,
      }.contains(value)) {
    throw const FormatException(
      'General schedule date label format is invalid.',
    );
  }
  return value;
}

class GeneralScheduleData {
  const GeneralScheduleData({
    required this.activeScheduleId,
    required this.schedules,
    this.selectedDateIso,
    this.customDateRange,
    this.defaultView = generalViewWeek,
    this.viewSwitchBehavior = generalViewSwitchBehaviorMenu,
    this.toolbarWidthPolicy = generalToolbarWidthPolicyContent,
    this.dateLabelFormat = generalDateLabelFormatSlash,
    this.fitWeekColumnsToWidth = true,
    this.customDayMinWidth,
    this.showWeekends = true,
    this.showLunarCalendar = true,
    this.dayStartHour = 6,
    this.dayEndHour = 23,
    this.timeGridMinutes = 60,
    this.timeGridHourHeight = generalTimeGridHourHeightDefault,
    this.closeEventPopupOnOutsideTap = true,
    this.showAddEventFab = true,
    this.enableLongPressAddEvent = true,
    this.allDayTimelineCollapsed = false,
    this.toolbarNavigationOrder = generalToolbarNavigationDefaultOrder,
    this.hiddenToolbarNavigationIds = toolbarNavigationDefaultHiddenIds,
    this.toolbarHiddenItemsBehavior = toolbarHiddenItemsBehaviorRemove,
    this.themeMode = defaultThemeMode,
    this.themeColorMode = defaultThemeColorMode,
    this.themeSeedColorValue = defaultThemeSeedColorValue,
    this.colorfulUiColorValues = const {},
    this.reminderAcknowledgements = const [],
  }) : _snapshot = null;

  // Only repaired, owned collections receive an index. The public constructor
  // still accepts raw values; the index contains only sendable model values.
  GeneralScheduleData._fromSnapshot(
    GeneralScheduleData source,
    _GeneralScheduleSnapshot snapshot,
    List<GeneralReminderAcknowledgement> acknowledgements,
  ) : _snapshot = snapshot,
      activeScheduleId = _activeScheduleId(
        snapshot.schedules,
        source.activeScheduleId,
      ),
      schedules = snapshot.schedules,
      selectedDateIso = source.selectedDateIso,
      customDateRange = source.customDateRange,
      defaultView = source.defaultView,
      viewSwitchBehavior = source.viewSwitchBehavior,
      toolbarWidthPolicy = source.toolbarWidthPolicy,
      dateLabelFormat = source.dateLabelFormat,
      fitWeekColumnsToWidth = source.fitWeekColumnsToWidth,
      customDayMinWidth = source.customDayMinWidth,
      showWeekends = source.showWeekends,
      showLunarCalendar = source.showLunarCalendar,
      dayStartHour = source.dayStartHour,
      dayEndHour = source.dayEndHour,
      timeGridMinutes = source.timeGridMinutes,
      timeGridHourHeight = source.timeGridHourHeight,
      closeEventPopupOnOutsideTap = source.closeEventPopupOnOutsideTap,
      showAddEventFab = source.showAddEventFab,
      enableLongPressAddEvent = source.enableLongPressAddEvent,
      allDayTimelineCollapsed = source.allDayTimelineCollapsed,
      toolbarNavigationOrder = source.toolbarNavigationOrder,
      hiddenToolbarNavigationIds = source.hiddenToolbarNavigationIds,
      toolbarHiddenItemsBehavior = source.toolbarHiddenItemsBehavior,
      themeMode = source.themeMode,
      themeColorMode = source.themeColorMode,
      themeSeedColorValue = source.themeSeedColorValue,
      colorfulUiColorValues = source.colorfulUiColorValues,
      reminderAcknowledgements = acknowledgements;

  final _GeneralScheduleSnapshot? _snapshot;

  final String activeScheduleId;
  final List<GeneralSchedule> schedules;
  final String? selectedDateIso;
  final GeneralDateRange? customDateRange;
  final String defaultView;
  final String viewSwitchBehavior;
  final String toolbarWidthPolicy;
  final String dateLabelFormat;
  final bool fitWeekColumnsToWidth;
  final int? customDayMinWidth;
  final bool showWeekends;
  final bool showLunarCalendar;
  final int dayStartHour;
  final int dayEndHour;
  final int timeGridMinutes;
  final int timeGridHourHeight;
  final bool closeEventPopupOnOutsideTap;
  final bool showAddEventFab;
  final bool enableLongPressAddEvent;
  final bool allDayTimelineCollapsed;
  final List<String> toolbarNavigationOrder;
  final List<String> hiddenToolbarNavigationIds;
  final String toolbarHiddenItemsBehavior;
  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;
  final List<GeneralReminderAcknowledgement> reminderAcknowledgements;

  List<GeneralSchedule> get visibleSchedules =>
      schedules.where((s) => s.isVisible).toList()..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });

  GeneralSchedule get activeSchedule {
    for (final s in schedules) {
      if (s.id == activeScheduleId) {
        return s;
      }
    }
    return schedules.first;
  }

  GeneralSchedule? get activeScheduleOrNull =>
      schedules.isEmpty ? null : activeSchedule;

  /// Repaired snapshots look up ownership without enumerating event lists.
  /// Raw callers retain the ability to contain duplicate event IDs.
  List<({GeneralSchedule schedule, GeneralEvent event})> eventLocationsById(
    String eventId,
  ) {
    final snapshot = _snapshot;
    if (snapshot != null) {
      return [
        for (final index in snapshot.indexes)
          if (index.eventsById[eventId] case final event?)
            (schedule: index.schedule, event: event),
      ];
    }
    return [
      for (final schedule in schedules)
        for (final event in schedule.events)
          if (event.id == eventId) (schedule: schedule, event: event),
    ];
  }

  /// A stored event has already crossed the repair boundary. Reusing it avoids
  /// parsing unchanged dates when an editor saves the original values.
  GeneralEvent normalizeEventForCalendar(
    GeneralEvent event, {
    required String calendarId,
  }) {
    final prepared = event.copyWith(calendarId: calendarId);
    final stored = _snapshot?.byScheduleId[calendarId]?.eventsById[prepared.id];
    return identical(stored, prepared)
        ? prepared
        : prepared.normalized(fallbackCalendarId: calendarId);
  }

  DateTime get selectedDate {
    final parsed = tryParseStrictIsoDate(selectedDateIso);
    return parsed == null
        ? customDateRange?.start ?? normalizeDateOnly(DateTime.now())
        : normalizeDateOnly(parsed);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': generalScheduleSchemaVersion,
    'activeScheduleId': activeScheduleId,
    'schedules': schedules.map((s) => s.toJson()).toList(),
    if (selectedDateIso != null) 'selectedDateIso': selectedDateIso,
    if (customDateRange != null) 'customDateRange': customDateRange!.toJson(),
    'defaultView': normalizeGeneralView(defaultView),
    'viewSwitchBehavior': normalizeGeneralViewSwitchBehavior(
      viewSwitchBehavior,
    ),
    'toolbarWidthPolicy': normalizeGeneralToolbarWidthPolicy(
      toolbarWidthPolicy,
    ),
    'dateLabelFormat': normalizeGeneralDateLabelFormat(dateLabelFormat),
    'fitWeekColumnsToWidth': fitWeekColumnsToWidth,
    if (customDayMinWidth != null)
      'customDayMinWidth': normalizeGeneralCustomDayMinWidth(customDayMinWidth),
    'showWeekends': showWeekends,
    'showLunarCalendar': showLunarCalendar,
    'dayStartHour': dayStartHour,
    'dayEndHour': dayEndHour,
    'timeGridMinutes': timeGridMinutes,
    'timeGridHourHeight': timeGridHourHeight,
    'closeEventPopupOnOutsideTap': closeEventPopupOnOutsideTap,
    'showAddEventFab': showAddEventFab,
    'enableLongPressAddEvent': enableLongPressAddEvent,
    'allDayTimelineCollapsed': allDayTimelineCollapsed,
    'toolbarNavigationOrder': normalizeToolbarNavigationOrder(
      toolbarNavigationOrder,
      knownIds: generalToolbarNavigationKnownIds,
      defaultOrder: generalToolbarNavigationDefaultOrder,
    ),
    'hiddenToolbarNavigationIds': normalizeToolbarHiddenNavigationIds(
      hiddenToolbarNavigationIds,
      knownIds: generalToolbarNavigationKnownIds,
    ),
    'toolbarHiddenItemsBehavior': normalizeToolbarHiddenItemsBehavior(
      toolbarHiddenItemsBehavior,
    ),
    'themeMode': normalizeThemeMode(themeMode),
    'themeColorMode': normalizeThemeColorMode(themeColorMode),
    'themeSeedColorValue': themeSeedColorValue,
    'colorfulUiColorValues': colorfulUiColorValues,
    'reminderAcknowledgements': reminderAcknowledgements
        .map((item) => item.toJson())
        .toList(),
  };

  factory GeneralScheduleData.fromJson(
    Map<String, dynamic> json, {
    String? localeCode,
  }) {
    final schemaVersion = readOptionalAppDataVersion(
      json,
      'schemaVersion',
      errorMessage: 'General schedule schemaVersion is invalid.',
    );
    if (schemaVersion != null && schemaVersion > generalScheduleSchemaVersion) {
      throw const UnsupportedSchemaVersionException(
        'General schedule schemaVersion is unsupported.',
      );
    }
    final viewSwitchBehavior = _decodeGeneralViewSwitchBehavior(json);
    final toolbarWidthPolicy = _decodeGeneralToolbarWidthPolicy(json);
    final dateLabelFormat = _decodeGeneralDateLabelFormat(json);
    final showAddEventFab = appDataBoolValue(json['showAddEventFab']) ?? true;
    final enableLongPressAddEvent =
        appDataBoolValue(json['enableLongPressAddEvent']) ?? true;
    final allDayTimelineCollapsed = _decodeGeneralAllDayTimelineCollapsed(json);
    final toolbarNavigationOrder = decodeToolbarNavigationStringList(
      json,
      'toolbarNavigationOrder',
      knownIds: generalToolbarNavigationKnownIds,
      defaultOrder: generalToolbarNavigationDefaultOrder,
    );
    final hiddenToolbarNavigationIds = decodeToolbarHiddenNavigationStringList(
      json,
      'hiddenToolbarNavigationIds',
      knownIds: generalToolbarNavigationKnownIds,
    );
    final toolbarHiddenItemsBehavior = decodeToolbarHiddenItemsBehavior(
      json,
      'toolbarHiddenItemsBehavior',
    );
    if ((schemaVersion ?? 0) < 2 && !_hasLegacySchedulePayload(json)) {
      return GeneralScheduleData.createDefault(
        localeCode: localeCode ?? defaultLocaleCode,
      ).copyWith(
        viewSwitchBehavior: viewSwitchBehavior,
        toolbarWidthPolicy: toolbarWidthPolicy,
        dateLabelFormat: dateLabelFormat,
        fitWeekColumnsToWidth:
            appDataBoolValue(json['fitWeekColumnsToWidth']) ?? true,
        customDayMinWidth: normalizeGeneralCustomDayMinWidth(
          appDataIntValue(json['customDayMinWidth']),
        ),
        showAddEventFab: showAddEventFab,
        enableLongPressAddEvent: enableLongPressAddEvent,
        allDayTimelineCollapsed: allDayTimelineCollapsed,
        toolbarNavigationOrder: toolbarNavigationOrder,
        hiddenToolbarNavigationIds: hiddenToolbarNavigationIds,
        toolbarHiddenItemsBehavior: toolbarHiddenItemsBehavior,
        timeGridHourHeight: _normalizeTimeGridHourHeight(
          appDataIntValue(json['timeGridHourHeight']),
        ),
      );
    }

    final schedules =
        appDataListValue(json['schedules'])
            .map(appDataStringKeyedMap)
            .whereType<Map<String, dynamic>>()
            .map(
              (json) => GeneralSchedule.fromJson(json, localeCode: localeCode),
            )
            .toList()
          ..sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order != 0 ? order : a.name.compareTo(b.name);
          });
    final withDefaults = schedules.isEmpty
        ? <GeneralSchedule>[
            createDefaultGeneralSchedule(
              localeCode: localeCode ?? defaultLocaleCode,
            ),
          ]
        : schedules;
    final activeId = appDataStringValue(json['activeScheduleId']);
    final resolvedActiveId = withDefaults.any((s) => s.id == activeId)
        ? activeId
        : withDefaults.first.id;

    return GeneralScheduleData(
      activeScheduleId: resolvedActiveId,
      schedules: [
        for (var i = 0; i < withDefaults.length; i++)
          withDefaults[i].copyWith(sortOrder: i),
      ],
      selectedDateIso: _normalizeDateIso(
        appDataNullableStringValue(json['selectedDateIso']),
      ),
      customDateRange: json['customDateRange'] == null
          ? null
          : GeneralDateRange.fromJson(json['customDateRange']),
      defaultView: normalizeGeneralView(
        appDataNullableStringValue(json['defaultView']),
      ),
      viewSwitchBehavior: viewSwitchBehavior,
      toolbarWidthPolicy: toolbarWidthPolicy,
      dateLabelFormat: dateLabelFormat,
      fitWeekColumnsToWidth:
          appDataBoolValue(json['fitWeekColumnsToWidth']) ?? true,
      customDayMinWidth: normalizeGeneralCustomDayMinWidth(
        appDataIntValue(json['customDayMinWidth']),
      ),
      showWeekends: appDataBoolValue(json['showWeekends']) ?? true,
      showLunarCalendar: appDataBoolValue(json['showLunarCalendar']) ?? true,
      dayStartHour: (appDataIntValue(json['dayStartHour']) ?? 6)
          .clamp(0, 23)
          .toInt(),
      dayEndHour: (appDataIntValue(json['dayEndHour']) ?? 23)
          .clamp(1, 24)
          .toInt(),
      timeGridMinutes: _normalizeGridMinutes(
        appDataIntValue(json['timeGridMinutes']),
      ),
      timeGridHourHeight: _normalizeTimeGridHourHeight(
        appDataIntValue(json['timeGridHourHeight']),
      ),
      closeEventPopupOnOutsideTap:
          appDataBoolValue(json['closeEventPopupOnOutsideTap']) ?? true,
      showAddEventFab: showAddEventFab,
      enableLongPressAddEvent: enableLongPressAddEvent,
      allDayTimelineCollapsed: allDayTimelineCollapsed,
      toolbarNavigationOrder: toolbarNavigationOrder,
      hiddenToolbarNavigationIds: hiddenToolbarNavigationIds,
      toolbarHiddenItemsBehavior: toolbarHiddenItemsBehavior,
      themeMode: normalizeThemeMode(
        appDataNullableStringValue(json['themeMode']) ?? defaultThemeMode,
      ),
      themeColorMode: normalizeThemeColorMode(
        appDataNullableStringValue(json['themeColorMode']) ??
            defaultThemeColorMode,
      ),
      themeSeedColorValue:
          appDataParsedIntValue(json['themeSeedColorValue']) ??
          defaultThemeSeedColorValue,
      colorfulUiColorValues: decodeColorValueMap(json['colorfulUiColorValues']),
      reminderAcknowledgements:
          appDataListValue(json['reminderAcknowledgements'])
              .map(appDataStringKeyedMap)
              .whereType<Map<String, dynamic>>()
              .map(GeneralReminderAcknowledgement.fromJson)
              .toList(),
    ).normalized(
      migrateLegacyElapsedExceptions: (schemaVersion ?? 1) < 4,
      localeCode: localeCode ?? defaultLocaleCode,
    );
  }

  factory GeneralScheduleData.createDefault({
    String localeCode = defaultLocaleCode,
  }) {
    final schedule = createDefaultGeneralSchedule(localeCode: localeCode);
    final data = GeneralScheduleData(
      activeScheduleId: schedule.id,
      schedules: [schedule],
      selectedDateIso: _dateIso(DateTime.now()),
    );
    return GeneralScheduleData._fromSnapshot(
      data,
      _GeneralScheduleSnapshot.fromSchedules([schedule]),
      const [],
    );
  }

  GeneralScheduleData copyWith({
    String? activeScheduleId,
    List<GeneralSchedule>? schedules,
    Object? selectedDateIso = _keepNullable,
    Object? customDateRange = _keepNullable,
    String? defaultView,
    String? viewSwitchBehavior,
    String? toolbarWidthPolicy,
    String? dateLabelFormat,
    bool? fitWeekColumnsToWidth,
    Object? customDayMinWidth = _keepNullable,
    bool? showWeekends,
    bool? showLunarCalendar,
    int? dayStartHour,
    int? dayEndHour,
    int? timeGridMinutes,
    int? timeGridHourHeight,
    bool? closeEventPopupOnOutsideTap,
    bool? showAddEventFab,
    bool? enableLongPressAddEvent,
    bool? allDayTimelineCollapsed,
    List<String>? toolbarNavigationOrder,
    List<String>? hiddenToolbarNavigationIds,
    String? toolbarHiddenItemsBehavior,
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
    List<GeneralReminderAcknowledgement>? reminderAcknowledgements,
  }) {
    final nextSchedules = schedules ?? this.schedules;
    final requestedActiveId = activeScheduleId ?? this.activeScheduleId;
    final active = nextSchedules
        .where((schedule) => schedule.id == requestedActiveId)
        .firstOrNull;
    final nextActiveId = active?.isVisible ?? false
        ? active!.id
        : nextSchedules
                  .where((schedule) => schedule.isVisible)
                  .firstOrNull
                  ?.id ??
              nextSchedules.firstOrNull?.id ??
              requestedActiveId;
    final nextRange = identical(customDateRange, _keepNullable)
        ? this.customDateRange
        : customDateRange as GeneralDateRange?;
    final nextDate = identical(selectedDateIso, _keepNullable)
        ? this.selectedDateIso
        : selectedDateIso as String?;
    final start = (dayStartHour ?? this.dayStartHour).clamp(0, 23);
    final updated = GeneralScheduleData(
      activeScheduleId: nextActiveId,
      schedules: nextSchedules,
      selectedDateIso: nextDate ?? _dateIso(nextRange?.start ?? DateTime.now()),
      customDateRange: nextRange,
      defaultView: normalizeGeneralView(defaultView ?? this.defaultView),
      viewSwitchBehavior: normalizeGeneralViewSwitchBehavior(
        viewSwitchBehavior ?? this.viewSwitchBehavior,
      ),
      toolbarWidthPolicy: normalizeGeneralToolbarWidthPolicy(
        toolbarWidthPolicy ?? this.toolbarWidthPolicy,
      ),
      dateLabelFormat: normalizeGeneralDateLabelFormat(
        dateLabelFormat ?? this.dateLabelFormat,
      ),
      fitWeekColumnsToWidth:
          fitWeekColumnsToWidth ?? this.fitWeekColumnsToWidth,
      customDayMinWidth: identical(customDayMinWidth, _keepNullable)
          ? this.customDayMinWidth
          : normalizeGeneralCustomDayMinWidth(customDayMinWidth as int?),
      showWeekends: showWeekends ?? this.showWeekends,
      showLunarCalendar: showLunarCalendar ?? this.showLunarCalendar,
      dayStartHour: start,
      dayEndHour: (dayEndHour ?? this.dayEndHour).clamp(start + 1, 24),
      timeGridMinutes: _normalizeGridMinutes(
        timeGridMinutes ?? this.timeGridMinutes,
      ),
      timeGridHourHeight: _normalizeTimeGridHourHeight(
        timeGridHourHeight ?? this.timeGridHourHeight,
      ),
      closeEventPopupOnOutsideTap:
          closeEventPopupOnOutsideTap ?? this.closeEventPopupOnOutsideTap,
      showAddEventFab: showAddEventFab ?? this.showAddEventFab,
      enableLongPressAddEvent:
          enableLongPressAddEvent ?? this.enableLongPressAddEvent,
      allDayTimelineCollapsed:
          allDayTimelineCollapsed ?? this.allDayTimelineCollapsed,
      toolbarNavigationOrder: _sharedStrings(
        this.toolbarNavigationOrder,
        normalizeToolbarNavigationOrder(
          toolbarNavigationOrder ?? this.toolbarNavigationOrder,
          knownIds: generalToolbarNavigationKnownIds,
          defaultOrder: generalToolbarNavigationDefaultOrder,
        ),
        canReuse: _snapshot != null,
      ),
      hiddenToolbarNavigationIds: _sharedStrings(
        this.hiddenToolbarNavigationIds,
        normalizeToolbarHiddenNavigationIds(
          hiddenToolbarNavigationIds ?? this.hiddenToolbarNavigationIds,
          knownIds: generalToolbarNavigationKnownIds,
        ),
        canReuse: _snapshot != null,
      ),
      toolbarHiddenItemsBehavior: normalizeToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehavior ?? this.toolbarHiddenItemsBehavior,
      ),
      themeMode: normalizeThemeMode(themeMode ?? this.themeMode),
      themeColorMode: normalizeThemeColorMode(
        themeColorMode ?? this.themeColorMode,
      ),
      themeSeedColorValue: themeSeedColorValue ?? this.themeSeedColorValue,
      colorfulUiColorValues:
          colorfulUiColorValues ?? this.colorfulUiColorValues,
      reminderAcknowledgements:
          reminderAcknowledgements ?? this.reminderAcknowledgements,
    );
    final snapshot = _snapshot;
    if (snapshot == null) {
      return schedules == null &&
              reminderAcknowledgements == null &&
              nextSchedules.isNotEmpty
          ? updated
          : updated.normalized();
    }
    final changes = snapshot.update(nextSchedules);
    return GeneralScheduleData._fromSnapshot(
      updated,
      changes.snapshot,
      changes.normalizeAcknowledgements(
        reminderAcknowledgements ?? this.reminderAcknowledgements,
        previous: this,
      ),
    );
  }

  GeneralScheduleData normalized({
    bool migrateLegacyElapsedExceptions = false,
    String localeCode = defaultLocaleCode,
  }) {
    final rawSchedules = schedules.isEmpty
        ? <GeneralSchedule>[
            createDefaultGeneralSchedule(localeCode: localeCode),
          ]
        : schedules;
    final usedScheduleIds = <String>{};
    final usedEventIds = <String>{};
    final normalizedSchedules = <GeneralSchedule>[];
    final occurrenceKeyRemaps = <GeneralOccurrenceKeyRemap>[];
    for (
      var scheduleIndex = 0;
      scheduleIndex < rawSchedules.length;
      scheduleIndex++
    ) {
      final schedule = rawSchedules[scheduleIndex];
      final rawScheduleId = schedule.id.trim();
      final scheduleId = normalizeUniqueId(
        rawScheduleId,
        fallbackPrefix: 'calendar',
        existingIds: usedScheduleIds,
      );
      usedScheduleIds.add(scheduleId);
      final normalizedEvents = <GeneralEvent>[];
      for (final event in schedule.events) {
        final rawEventId = event.id.trim();
        final normalizedEvent = event.normalized(
          fallbackCalendarId: scheduleId,
        );
        final eventId = normalizeUniqueId(
          normalizedEvent.id,
          fallbackPrefix: 'evt',
          existingIds: usedEventIds,
        );
        usedEventIds.add(eventId);
        final normalizedExceptionDateIso = migrateLegacyElapsedExceptions
            ? _remappedLegacyElapsedExceptionDates(
                rawEventStartDateTimeIso: event.startDateTimeIso.trim(),
                normalizedEventStartDateTimeIso:
                    normalizedEvent.startDateTimeIso,
                recurrenceRule: normalizedEvent.recurrenceRule,
                exceptionDateIso: normalizedEvent.recurrenceExceptionDateIso,
              )
            : normalizedEvent.recurrenceExceptionDateIso;
        final normalizedEventWithIds = normalizedEvent.copyWith(
          id: eventId,
          calendarId: scheduleId,
          recurrenceExceptionDateIso: migrateLegacyElapsedExceptions
              ? List.unmodifiable(normalizedExceptionDateIso)
              : normalizedExceptionDateIso,
        );
        occurrenceKeyRemaps.add(
          GeneralOccurrenceKeyRemap(
            rawScheduleId: rawScheduleId,
            rawEventId: rawEventId,
            rawStartDateTimeIso: event.startDateTimeIso.trim(),
            scheduleId: scheduleId,
            eventId: eventId,
            startDateTimeIso: normalizedEventWithIds.startDateTimeIso,
            isRepeating: normalizedEventWithIds.recurrenceRule.isRepeating,
            recurrenceRule: normalizedEventWithIds.recurrenceRule,
            hasReminders: normalizedEventWithIds.hasReminderConfiguration,
          ),
        );
        normalizedEvents.add(normalizedEventWithIds);
      }
      normalizedSchedules.add(
        schedule.copyWith(
          id: scheduleId,
          name: schedule.name.trim().isEmpty
              ? defaultGeneralCalendarName(localeCode: localeCode)
              : schedule.name.trim(),
          sortOrder: normalizedSchedules.length,
          events: List.unmodifiable(normalizedEvents),
        ),
      );
    }
    final requestedActive = normalizedSchedules
        .where((schedule) => schedule.id == activeScheduleId)
        .firstOrNull;
    final activeId = requestedActive?.isVisible ?? false
        ? requestedActive!.id
        : normalizedSchedules
                  .where((schedule) => schedule.isVisible)
                  .firstOrNull
                  ?.id ??
              normalizedSchedules.first.id;
    final start = dayStartHour.clamp(0, 23).toInt();
    final end = dayEndHour.clamp(start + 1, 24).toInt();
    final acknowledgements = remapGeneralReminderAcknowledgements(
      reminderAcknowledgements,
      occurrenceKeyRemaps,
    );
    final data = GeneralScheduleData(
      activeScheduleId: activeId,
      schedules: normalizedSchedules,
      selectedDateIso:
          selectedDateIso ?? _dateIso(customDateRange?.start ?? DateTime.now()),
      customDateRange: customDateRange,
      defaultView: normalizeGeneralView(defaultView),
      viewSwitchBehavior: normalizeGeneralViewSwitchBehavior(
        viewSwitchBehavior,
      ),
      toolbarWidthPolicy: normalizeGeneralToolbarWidthPolicy(
        toolbarWidthPolicy,
      ),
      dateLabelFormat: normalizeGeneralDateLabelFormat(dateLabelFormat),
      fitWeekColumnsToWidth: fitWeekColumnsToWidth,
      customDayMinWidth: normalizeGeneralCustomDayMinWidth(customDayMinWidth),
      showWeekends: showWeekends,
      showLunarCalendar: showLunarCalendar,
      dayStartHour: start,
      dayEndHour: end,
      timeGridMinutes: _normalizeGridMinutes(timeGridMinutes),
      timeGridHourHeight: _normalizeTimeGridHourHeight(timeGridHourHeight),
      closeEventPopupOnOutsideTap: closeEventPopupOnOutsideTap,
      showAddEventFab: showAddEventFab,
      enableLongPressAddEvent: enableLongPressAddEvent,
      allDayTimelineCollapsed: allDayTimelineCollapsed,
      toolbarNavigationOrder: List.unmodifiable(
        normalizeToolbarNavigationOrder(
          toolbarNavigationOrder,
          knownIds: generalToolbarNavigationKnownIds,
          defaultOrder: generalToolbarNavigationDefaultOrder,
        ),
      ),
      hiddenToolbarNavigationIds: List.unmodifiable(
        normalizeToolbarHiddenNavigationIds(
          hiddenToolbarNavigationIds,
          knownIds: generalToolbarNavigationKnownIds,
        ),
      ),
      toolbarHiddenItemsBehavior: normalizeToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehavior,
      ),
      themeMode: normalizeThemeMode(themeMode),
      themeColorMode: normalizeThemeColorMode(themeColorMode),
      themeSeedColorValue: themeSeedColorValue,
      colorfulUiColorValues: colorfulUiColorValues,
      reminderAcknowledgements: acknowledgements,
    );
    return GeneralScheduleData._fromSnapshot(
      data,
      _GeneralScheduleSnapshot.fromSchedules(normalizedSchedules),
      List.unmodifiable(acknowledgements),
    );
  }

  GeneralScheduleData withSchedule(GeneralSchedule schedule) {
    final id = schedule.id.trim();
    final normalizedSchedule = schedule.copyWith(
      id: id.isEmpty ? createDefaultGeneralSchedule().id : id,
    );
    final index = schedules.indexWhere((s) => s.id == normalizedSchedule.id);
    final updated = index >= 0
        ? [
            for (var i = 0; i < schedules.length; i++)
              if (i == index) normalizedSchedule else schedules[i],
          ]
        : [
            ...schedules,
            normalizedSchedule.copyWith(sortOrder: schedules.length),
          ];
    return copyWith(schedules: updated);
  }
}

String _dateIso(DateTime date) =>
    normalizeDateOnly(date).toIso8601String().split('T').first;

String? _normalizeDateIso(String? value) {
  final parsed = tryParseStrictIsoDate(value);
  return parsed == null ? null : _dateIso(parsed);
}

int _normalizeGridMinutes(int? value) {
  switch (value) {
    case 15:
    case 30:
    case 60:
      return value!;
    default:
      return 60;
  }
}

int _normalizeTimeGridHourHeight(int? value) {
  return (value ?? generalTimeGridHourHeightDefault)
      .clamp(generalTimeGridHourHeightMin, generalTimeGridHourHeightMax)
      .toInt();
}

List<String> _remappedLegacyElapsedExceptionDates({
  required String rawEventStartDateTimeIso,
  required String normalizedEventStartDateTimeIso,
  required GeneralEventRecurrenceRule recurrenceRule,
  required Iterable<String> exceptionDateIso,
}) {
  if (!recurrenceRule.isRepeating) {
    return exceptionDateIso.toSet().toList()..sort();
  }
  final rawEventStart = tryParseStrictIsoDateTime(rawEventStartDateTimeIso);
  final normalizedEventStart = tryParseStrictIsoDateTime(
    normalizedEventStartDateTimeIso,
  );
  if (rawEventStart == null || normalizedEventStart == null) {
    return exceptionDateIso.toSet().toList()..sort();
  }
  return remapLegacyElapsedGeneralRecurrenceExceptionDates(
    rawEventStart: rawEventStart,
    normalizedEventStart: normalizedEventStart,
    recurrenceRule: recurrenceRule,
    exceptionDateIso: exceptionDateIso,
  );
}

const Symbol _keepNullable = #keep;
