import '../l10n/app_locale.dart';
import '../utils/localized_names.dart';

/// External import budgets, shared by JSON previews and full backup imports.
/// They apply before migration, model construction and normalization. Local
/// storage and pending restore journals must not use these admission limits.
abstract final class ImportCountLimits {
  static const timetables = 100;
  static const schedules = 100;
  static const periodTimeSets = 100;
  static const coursesAndEvents = 20000;
  static const periodTimes = 10000;
  static const schoolSites = 1000;
  static const listEntries = 250000;
  static const mapEntries = 1000000;
  static const nestingDepth = 64;
}

enum ImportCountKind {
  appData,
  timetables,
  schedules,
  periodTimes,
  backup,
  schoolSites,
}

/// Counts raw entries, including malformed entries and duplicates. Counting
/// happens before filtering; splitting entries across containers cannot evade
/// the shared budgets. Unknown/custom fields share the structural budget too.
void validateImportCounts(
  Object? data, {
  required ImportCountKind kind,
  String localeCode = defaultLocaleCode,
}) {
  final budget = _ImportCountBudget(localeCode);
  budget.checkDomain(data, kind);
  budget.checkStructure(data, 1);
}

class _ImportCountBudget {
  _ImportCountBudget(this.localeCode);

  final String localeCode;
  var _coursesAndEvents = 0;
  var _periodTimes = 0;
  var _listEntries = 0;
  var _mapEntries = 0;

  void _check(int count, int limit) {
    if (count > limit) {
      throw FormatException(
        importEntryLimitExceededMessage(localeCode: localeCode),
      );
    }
  }

  static Object? _field(Object? value, String key) =>
      value is Map ? value[key] : null;

  static List<dynamic> _list(Object? value) => value is List ? value : const [];

  void checkDomain(Object? data, ImportCountKind kind) {
    switch (kind) {
      case ImportCountKind.appData:
        // Keep the same flat legacy branch as AppData.fromJson.
        if (data is Map &&
            data.containsKey('timetables') &&
            !data.containsKey('studentMode')) {
          _student(data);
        } else {
          _student(_field(data, 'studentMode'));
          _schedules(_field(data, 'generalMode'));
        }
      case ImportCountKind.timetables:
        if (data is Map &&
            data.containsKey('config') &&
            data.containsKey('courses')) {
          _timetable(data);
        } else {
          _student(data);
          if (_field(data, 'timetables') is! List) {
            _timetable(_field(data, 'timetable'));
          }
        }
      case ImportCountKind.schedules:
        _schedules(data);
      case ImportCountKind.periodTimes:
        _addPeriodTimes(_field(data, 'periodTimes'));
      case ImportCountKind.backup:
        checkDomain(_field(data, 'appData'), ImportCountKind.appData);
        _check(
          _list(_field(data, 'schoolSites')).length,
          ImportCountLimits.schoolSites,
        );
      case ImportCountKind.schoolSites:
        _check(_list(data).length, ImportCountLimits.schoolSites);
    }
  }

  void _student(Object? data) {
    final timetables = _list(_field(data, 'timetables'));
    _check(timetables.length, ImportCountLimits.timetables);
    final sets = _list(_field(data, 'periodTimeSets'));
    _check(sets.length, ImportCountLimits.periodTimeSets);
    for (final set in sets) {
      _addPeriodTimes(_field(set, 'periodTimes'));
    }
    for (final timetable in timetables) {
      _timetable(timetable);
    }
  }

  void _timetable(Object? timetable) {
    _addCoursesAndEvents(_field(timetable, 'courses'));
    _addPeriodTimes(_field(_field(timetable, 'config'), 'periodTimes'));
  }

  void _schedules(Object? data) {
    final schedules = _list(_field(data, 'schedules'));
    _check(schedules.length, ImportCountLimits.schedules);
    for (final schedule in schedules) {
      _addCoursesAndEvents(_field(schedule, 'events'));
    }
  }

  void _addCoursesAndEvents(Object? items) {
    _coursesAndEvents += _list(items).length;
    _check(_coursesAndEvents, ImportCountLimits.coursesAndEvents);
  }

  void _addPeriodTimes(Object? items) {
    _periodTimes += _list(items).length;
    _check(_periodTimes, ImportCountLimits.periodTimes);
  }

  void checkStructure(Object? value, int depth) {
    if (value is List) {
      _check(depth, ImportCountLimits.nestingDepth);
      _listEntries += value.length;
      _check(_listEntries, ImportCountLimits.listEntries);
      for (final child in value) {
        checkStructure(child, depth + 1);
      }
    } else if (value is Map) {
      _check(depth, ImportCountLimits.nestingDepth);
      _mapEntries += value.length;
      _check(_mapEntries, ImportCountLimits.mapEntries);
      for (final child in value.values) {
        checkStructure(child, depth + 1);
      }
    }
  }
}
