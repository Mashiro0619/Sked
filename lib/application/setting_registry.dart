import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../models/agent_settings.dart';
import '../services/desktop_layout_preferences.dart';
import '../services/general_calendar_service.dart';
import '../services/settings_service.dart';
import '../services/student_timetable_service.dart';
part 'setting_registry_catalog.dart';

enum SettingScope { app, student, general, agent, device, platform, legacy }

enum SettingValueType {
  boolean,
  integer,
  number,
  string,
  enumeration,
  stringList,
  colorMap,
  object,
}

/// Applicability describes where a preference takes effect, not permission.
enum SettingPlatform { all, touchLayout, desktopLayout, android, windows }

enum SettingDefaultSource { fixed, applicationContext, courseNames, adapter }

enum SettingEditKind { keep, set, reset }

enum SettingValidationCode {
  unknownKey,
  duplicateKey,
  readOnly,
  requiresAdapter,
  invalidType,
  invalidValue,
  invalidCombination,
}

class SettingValidationException implements Exception {
  const SettingValidationException(this.code, this.key, this.message);

  final SettingValidationCode code;
  final String key;
  // Messages describe the constraint, never echo a possibly sensitive value.
  final String message;

  @override
  String toString() =>
      'SettingValidationException(${code.name}, $key): $message';
}

/// Fixed reset intent, distinct from historical missing-field decoding.
///
/// The composition root can supply its resolved locale and distribution
/// preference. The defaults here match safe bootstrap fallback choices;
/// preparing a change never reads package metadata or the system locale.
class SettingResetDefaults {
  const SettingResetDefaults({
    this.localeCode = defaultLocaleCode,
    this.includePrereleaseUpdates = false,
    this.studentThemeColorMode = newUserDefaultStudentThemeColorMode,
  });

  final String localeCode;
  final bool includePrereleaseUpdates;
  final String studentThemeColorMode;
}

class SettingDescriptor {
  SettingDescriptor({
    required this.key,
    required this.scope,
    required this.type,
    this.nullable = false,
    Object? defaultValue,
    this.defaultSource = SettingDefaultSource.fixed,
    Iterable<Object> allowedValues = const [],
    this.minimum,
    this.maximum,
    this.step,
    this.minimumExclusive = false,
    this.platform = SettingPlatform.all,
    this.sensitive = false,
    this.readOnly = false,
    this.requiresAdapter = false,
    this.resetMeaning = 'Restore the declared default value.',
  }) : defaultValue = _freezeSettingValue(defaultValue),
       allowedValues = List.unmodifiable(allowedValues);

  final String key;
  final SettingScope scope;
  final SettingValueType type;
  final bool nullable;
  final Object? defaultValue;
  final SettingDefaultSource defaultSource;
  final List<Object> allowedValues;
  final num? minimum;
  final num? maximum;
  final num? step;
  final bool minimumExclusive;
  final SettingPlatform platform;
  final bool sensitive;
  final bool readOnly;
  final bool requiresAdapter;
  final String resetMeaning;

  bool get canPrepare => !readOnly && !requiresAdapter;

  Map<String, Object?> toJson() => {
    'key': key,
    'scope': scope.name,
    'type': type.name,
    'nullable': nullable,
    'defaultValue': defaultValue,
    'defaultSource': defaultSource.name,
    'allowedValues': allowedValues,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (step != null) 'step': step,
    if (minimumExclusive) 'minimumExclusive': true,
    'platform': platform.name,
    'sensitive': sensitive,
    'readOnly': readOnly,
    'requiresAdapter': requiresAdapter,
    'resetMeaning': resetMeaning,
  };
}

class SettingEdit {
  const SettingEdit.keep(this.key) : kind = SettingEditKind.keep, value = null;
  const SettingEdit.set(this.key, this.value) : kind = SettingEditKind.set;
  const SettingEdit.reset(this.key)
    : kind = SettingEditKind.reset,
      value = null;

  final String key;
  final SettingEditKind kind;
  final Object? value;
}

class PreparedSettingChange {
  PreparedSettingChange({
    required this.key,
    required this.kind,
    required Object? before,
    required Object? after,
    this.derived = false,
  }) : before = _freezeSettingValue(before),
       after = _freezeSettingValue(after);

  final String key;
  final SettingEditKind kind;
  final Object? before;
  final Object? after;
  final bool derived;
}

/// A pure candidate, not an authorization, durable result or commit receipt.
class PreparedSettingsChange {
  PreparedSettingsChange({
    required this.candidate,
    required Iterable<PreparedSettingChange> changes,
  }) : changes = List.unmodifiable(changes);

  final AppData candidate;
  final List<PreparedSettingChange> changes;
  bool get isEmpty => changes.isEmpty;
}

typedef _SettingReader = Object? Function(AppData data);
typedef _SettingWriter = AppData Function(AppData data, Object? value);

class _SettingBinding {
  const _SettingBinding(this.descriptor, this.read, [this.write]);
  final SettingDescriptor descriptor;
  final _SettingReader? read;
  final _SettingWriter? write;
}

/// Stable application settings metadata and side-effect-free preparation.
///
/// Namespaces select the target even when that workspace is disabled. No
/// permission, persistence, notification, OS or navigation action occurs here.
class SettingRegistry {
  SettingRegistry({
    SettingResetDefaults defaults = const SettingResetDefaults(),
  }) : _bindings = _buildSettingBindings(defaults) {
    for (final binding in _bindings.values) {
      if (binding.descriptor.canPrepare &&
          binding.descriptor.defaultSource !=
              SettingDefaultSource.courseNames) {
        _validateValue(binding.descriptor, binding.descriptor.defaultValue);
      }
    }
  }

  static const _settings = SettingsService();
  static const _calendars = GeneralCalendarService();
  final Map<String, _SettingBinding> _bindings;

  List<SettingDescriptor> get descriptors =>
      List.unmodifiable(_bindings.values.map((binding) => binding.descriptor));

  List<SettingDescriptor> describe({SettingScope? scope}) => List.unmodifiable(
    _bindings.values
        .map((binding) => binding.descriptor)
        .where((descriptor) => scope == null || descriptor.scope == scope),
  );

  SettingDescriptor descriptor(String key) => _binding(key).descriptor;

  Object? read(AppData data, String key) {
    final binding = _binding(key);
    final reader = binding.read;
    if (reader == null) {
      throw SettingValidationException(
        SettingValidationCode.requiresAdapter,
        key,
        'This value must be read through its owning adapter.',
      );
    }
    return _freezeSettingValue(reader(data));
  }

  /// Resolves resource-derived defaults without changing the resource data.
  Object? defaultValueFor(AppData data, String key) {
    final descriptor = _binding(key).descriptor;
    if (!descriptor.canPrepare) {
      throw SettingValidationException(
        descriptor.readOnly
            ? SettingValidationCode.readOnly
            : SettingValidationCode.requiresAdapter,
        key,
        'This setting has no pure reset operation.',
      );
    }
    if (descriptor.defaultSource == SettingDefaultSource.courseNames) {
      return Map<String, int>.unmodifiable(
        buildStudentCourseNameColorValuesForTimetables(
          data.studentMode.timetables,
        ),
      );
    }
    return descriptor.defaultValue;
  }

  PreparedSettingsChange prepare(
    AppData baseline,
    Iterable<SettingEdit> edits,
  ) {
    final requested = <String, SettingEdit>{};
    final values = <String, Object?>{};
    for (final edit in edits) {
      final descriptor = _binding(edit.key).descriptor;
      if (requested.containsKey(edit.key)) {
        throw SettingValidationException(
          SettingValidationCode.duplicateKey,
          edit.key,
          'A setting may occur only once in a preparation.',
        );
      }
      requested[edit.key] = edit;
      if (edit.kind == SettingEditKind.keep) continue;
      if (descriptor.readOnly || descriptor.requiresAdapter) {
        throw SettingValidationException(
          descriptor.readOnly
              ? SettingValidationCode.readOnly
              : SettingValidationCode.requiresAdapter,
          edit.key,
          'This setting requires its owning workflow and cannot be prepared here.',
        );
      }
      values[edit.key] = _validateValue(
        descriptor,
        edit.kind == SettingEditKind.reset
            ? defaultValueFor(baseline, edit.key)
            : edit.value,
      );
    }
    _validateCombinations(baseline, values);
    if (values.isEmpty) {
      return PreparedSettingsChange(candidate: baseline, changes: const []);
    }

    var candidate = baseline;
    for (final entry in values.entries) {
      final write = _bindings[entry.key]!.write;
      if (write != null) candidate = write(candidate, entry.value);
    }
    candidate = _applyStudentComplex(candidate, values, requested);
    candidate = _applyGeneral(candidate, values);
    final changes = <PreparedSettingChange>[];
    for (final entry in _bindings.entries) {
      final reader = entry.value.read;
      if (reader == null || entry.value.descriptor.sensitive) continue;
      final before = reader(baseline);
      final after = reader(candidate);
      if (_sameSettingValue(before, after)) continue;
      final edit = requested[entry.key];
      if (edit?.kind == SettingEditKind.keep) {
        throw SettingValidationException(
          SettingValidationCode.invalidCombination,
          entry.key,
          'A dependent change conflicts with the explicit keep instruction.',
        );
      }
      changes.add(
        PreparedSettingChange(
          key: entry.key,
          kind: edit?.kind ?? SettingEditKind.set,
          before: before,
          after: after,
          derived: edit == null || edit.kind == SettingEditKind.keep,
        ),
      );
    }
    return PreparedSettingsChange(
      candidate: changes.isEmpty ? baseline : candidate,
      changes: changes,
    );
  }

  _SettingBinding _binding(String key) =>
      _bindings[key] ??
      (throw SettingValidationException(
        SettingValidationCode.unknownKey,
        key,
        'Unknown setting key.',
      ));

  static Object? _validateValue(SettingDescriptor descriptor, Object? value) {
    Never fail(SettingValidationCode code, String message) =>
        throw SettingValidationException(code, descriptor.key, message);
    if (value == null) {
      if (descriptor.nullable) return null;
      fail(
        SettingValidationCode.invalidType,
        'Null is not allowed for this setting.',
      );
    }
    final validType = switch (descriptor.type) {
      SettingValueType.boolean => value is bool,
      SettingValueType.integer => value is int,
      SettingValueType.number => value is num && value.isFinite,
      SettingValueType.string ||
      SettingValueType.enumeration => value is String,
      SettingValueType.stringList =>
        value is List && value.every((item) => item is String),
      SettingValueType.colorMap =>
        value is Map &&
            value.entries.every(
              (entry) => entry.key is String && entry.value is int,
            ),
      SettingValueType.object => value is Map,
    };
    if (!validType) {
      fail(SettingValidationCode.invalidType, 'The value has an invalid type.');
    }
    if (value is num) {
      if (!value.isFinite ||
          (descriptor.minimum != null &&
              (descriptor.minimumExclusive
                  ? value <= descriptor.minimum!
                  : value < descriptor.minimum!)) ||
          (descriptor.maximum != null && value > descriptor.maximum!)) {
        fail(
          SettingValidationCode.invalidValue,
          'The value is outside the supported range.',
        );
      }
      if (descriptor.step != null &&
          (value - (descriptor.minimum ?? 0)) % descriptor.step! != 0) {
        fail(
          SettingValidationCode.invalidValue,
          'The value does not match the supported step.',
        );
      }
    }
    if (descriptor.type == SettingValueType.stringList) {
      final list = (value as List).cast<String>();
      if (list.toSet().length != list.length ||
          list.any((item) => !descriptor.allowedValues.contains(item))) {
        fail(
          SettingValidationCode.invalidValue,
          'The list contains duplicate or unsupported identifiers.',
        );
      }
      if (descriptor.key.endsWith('.toolbarNavigationOrder') &&
          list.length != descriptor.allowedValues.length) {
        fail(
          SettingValidationCode.invalidValue,
          'The order must contain each known toolbar identifier.',
        );
      }
      return List<String>.unmodifiable(list);
    }
    if (descriptor.type == SettingValueType.colorMap) {
      final colors = (value as Map).cast<String, int>();
      for (final entry in colors.entries) {
        if (entry.key.isEmpty ||
            entry.key.trim() != entry.key ||
            entry.value < 0 ||
            entry.value > 0xffffffff ||
            (descriptor.allowedValues.isNotEmpty &&
                !descriptor.allowedValues.contains(entry.key))) {
          fail(
            SettingValidationCode.invalidValue,
            'The color map contains an unsupported key or ARGB value.',
          );
        }
      }
      return Map<String, int>.unmodifiable(colors);
    }
    if (descriptor.allowedValues.isNotEmpty &&
        !descriptor.allowedValues.contains(value)) {
      fail(
        SettingValidationCode.invalidValue,
        'The value is not a supported choice.',
      );
    }
    if (descriptor.type == SettingValueType.string) {
      if (descriptor.key == 'agent.systemInstructions') {
        if ((value as String).length > 16000) {
          fail(
            SettingValidationCode.invalidValue,
            'Agent instructions exceed the supported length.',
          );
        }
        return value;
      }
      final normalized = (value as String).trim();
      if (normalized.isEmpty) {
        fail(
          SettingValidationCode.invalidValue,
          'Use null or reset to clear this setting.',
        );
      }
      return normalized;
    }
    return descriptor.type == SettingValueType.number
        ? (value as num).toDouble()
        : value;
  }

  static void _validateCombinations(AppData data, Map<String, Object?> values) {
    final start =
        values['general.dayStartHour'] as int? ?? data.generalMode.dayStartHour;
    final end =
        values['general.dayEndHour'] as int? ?? data.generalMode.dayEndHour;
    if ((values.containsKey('general.dayStartHour') ||
            values.containsKey('general.dayEndHour')) &&
        start >= end) {
      throw const SettingValidationException(
        SettingValidationCode.invalidCombination,
        'general.dayEndHour',
        'The end hour must be later than the start hour.',
      );
    }
    if (values['student.courseNameColorValues']
        case final Map<String, int> colors) {
      final names = data.studentMode.timetables
          .expand((table) => table.courses)
          .map((course) => normalizeCourseColorName(course.name))
          .toSet();
      if (colors.keys.any((name) => !names.contains(name))) {
        throw const SettingValidationException(
          SettingValidationCode.invalidValue,
          'student.courseNameColorValues',
          'Every course color key must name an existing course.',
        );
      }
    }
  }

  static AppData _applyStudentComplex(
    AppData data,
    Map<String, Object?> values,
    Map<String, SettingEdit> edits,
  ) {
    var student = data.studentMode;
    if (values.keys.any(
      (key) =>
          key.startsWith('student.') &&
          _studentComplexKeys.contains(key.substring(8)),
    )) {
      student = student.copyWith(
        themeMode: values['student.themeMode'] as String?,
        themeColorMode: values['student.themeColorMode'] as String?,
        themeSeedColorValue: values['student.themeSeedColorValue'] as int?,
        colorfulUiColorValues:
            values['student.colorfulUiColorValues'] as Map<String, int>?,
        courseNameColorValues:
            values.containsKey('student.courseNameColorValues')
            ? Map<String, int>.unmodifiable(
                buildStudentCourseNameColorValuesForTimetables(
                  student.timetables,
                  existing:
                      values['student.courseNameColorValues']
                          as Map<String, int>,
                ),
              )
            : null,
      );
      data = data.copyWith(studentMode: student);
    }
    if (values.keys.any((key) => key.startsWith('student.liveCourseOutline'))) {
      final original = data.studentMode;
      final colorEdit = edits['student.liveCourseOutlineColorValue'];
      data = _settings.updateLiveCourseOutlineSettings(
        data,
        enabled:
            values['student.liveCourseOutlineEnabled'] as bool? ??
            original.liveCourseOutlineEnabled,
        followTheme:
            values['student.liveCourseOutlineFollowTheme'] as bool? ??
            original.liveCourseOutlineFollowTheme,
        colorValue:
            values['student.liveCourseOutlineColorValue'] as int? ??
            original.liveCourseOutlineColorValue,
        customColorInitialized:
            colorEdit == null || colorEdit.kind == SettingEditKind.keep
            ? original.liveCourseOutlineCustomColorInitialized
            : colorEdit.kind == SettingEditKind.set,
        mode:
            values['student.liveCourseOutlineMode'] as String? ??
            original.liveCourseOutlineMode,
        width:
            values['student.liveCourseOutlineWidth'] as double? ??
            original.liveCourseOutlineWidth,
      );
    }
    return data;
  }

  static AppData _applyGeneral(AppData data, Map<String, Object?> values) {
    if (!values.keys.any((key) => key.startsWith('general.'))) return data;
    final original = data.generalMode;
    var next = _calendars.updateDisplaySettings(
      original,
      defaultView: values['general.defaultView'] as String?,
      viewSwitchBehavior: values['general.viewSwitchBehavior'] as String?,
      toolbarWidthPolicy: values['general.toolbarWidthPolicy'] as String?,
      dateLabelFormat: values['general.dateLabelFormat'] as String?,
      fitWeekColumnsToWidth: values['general.fitWeekColumnsToWidth'] as bool?,
      showWeekends: values['general.showWeekends'] as bool?,
      showLunarCalendar: values['general.showLunarCalendar'] as bool?,
      dayStartHour: values['general.dayStartHour'] as int?,
      dayEndHour: values['general.dayEndHour'] as int?,
      timeGridMinutes: values['general.timeGridMinutes'] as int?,
      timeGridHourHeight: values['general.timeGridHourHeight'] as int?,
      closeEventPopupOnOutsideTap:
          values['general.closeEventPopupOnOutsideTap'] as bool?,
      showAddEventFab: values['general.showAddEventFab'] as bool?,
      enableLongPressAddEvent:
          values['general.enableLongPressAddEvent'] as bool?,
      allDayTimelineCollapsed:
          values['general.allDayTimelineCollapsed'] as bool?,
      toolbarNavigationOrder:
          values['general.toolbarNavigationOrder'] as List<String>?,
      hiddenToolbarNavigationIds:
          values['general.hiddenToolbarNavigationIds'] as List<String>?,
      toolbarHiddenItemsBehavior:
          values['general.toolbarHiddenItemsBehavior'] as String?,
    );
    if (values.containsKey('general.customDayMinWidth')) {
      next = next.copyWith(
        customDayMinWidth: values['general.customDayMinWidth'],
      );
    }
    next = next.copyWith(
      themeMode: values['general.themeMode'] as String?,
      themeColorMode: values['general.themeColorMode'] as String?,
      themeSeedColorValue: values['general.themeSeedColorValue'] as int?,
      colorfulUiColorValues:
          values['general.colorfulUiColorValues'] as Map<String, int>?,
    );
    // Legacy copyWith also resolves navigation and may materialize today's
    // date. Settings preparation must preserve those unrelated source values,
    // including an intentionally unselected date and a hidden current calendar.
    if (next.activeScheduleId != original.activeScheduleId ||
        next.selectedDateIso != original.selectedDateIso ||
        !identical(next.schedules, original.schedules) ||
        !identical(
          next.reminderAcknowledgements,
          original.reminderAcknowledgements,
        )) {
      next = GeneralScheduleData(
        activeScheduleId: original.activeScheduleId,
        schedules: original.schedules,
        selectedDateIso: original.selectedDateIso,
        customDateRange: original.customDateRange,
        defaultView: next.defaultView,
        viewSwitchBehavior: next.viewSwitchBehavior,
        toolbarWidthPolicy: next.toolbarWidthPolicy,
        dateLabelFormat: next.dateLabelFormat,
        fitWeekColumnsToWidth: next.fitWeekColumnsToWidth,
        customDayMinWidth: next.customDayMinWidth,
        showWeekends: next.showWeekends,
        showLunarCalendar: next.showLunarCalendar,
        dayStartHour: next.dayStartHour,
        dayEndHour: next.dayEndHour,
        timeGridMinutes: next.timeGridMinutes,
        timeGridHourHeight: next.timeGridHourHeight,
        closeEventPopupOnOutsideTap: next.closeEventPopupOnOutsideTap,
        showAddEventFab: next.showAddEventFab,
        enableLongPressAddEvent: next.enableLongPressAddEvent,
        allDayTimelineCollapsed: next.allDayTimelineCollapsed,
        toolbarNavigationOrder: next.toolbarNavigationOrder,
        hiddenToolbarNavigationIds: next.hiddenToolbarNavigationIds,
        toolbarHiddenItemsBehavior: next.toolbarHiddenItemsBehavior,
        themeMode: next.themeMode,
        themeColorMode: next.themeColorMode,
        themeSeedColorValue: next.themeSeedColorValue,
        colorfulUiColorValues: next.colorfulUiColorValues,
        reminderAcknowledgements: original.reminderAcknowledgements,
      );
    }
    return data.copyWith(generalMode: next);
  }
}

const _studentComplexKeys = {
  'themeMode',
  'themeColorMode',
  'themeSeedColorValue',
  'colorfulUiColorValues',
  'courseNameColorValues',
};

Object? _freezeSettingValue(Object? value) {
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeSettingValue));
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freezeSettingValue(entry.value),
    });
  }
  return value;
}

bool _sameSettingValue(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameSettingValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && _sameSettingValue(a[key], b[key]),
        );
  }
  return a == b;
}
