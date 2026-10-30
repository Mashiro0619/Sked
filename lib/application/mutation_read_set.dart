import '../models/timetable_models.dart';
import 'mutation_draft.dart';
import 'resource_contracts.dart';
import 'setting_registry.dart';

/// The semantic inputs to the standard resource and setting compilers.
///
/// Child commands read their owner metadata and time binding, not unrelated
/// siblings. Copying or deleting an owner reads the complete owner. The
/// coordinator also compares every compiled change, including derived writes,
/// before accepting a candidate rebuilt from the current persisted snapshot.
class MutationReadSet {
  MutationReadSet({
    required Iterable<ResourceMutation> resources,
    required Iterable<SettingEdit> edits,
    required SettingRegistry settings,
  }) {
    void setting(String key) {
      _readers[key] = (data) => settings.read(data, key);
    }

    for (final command in resources) {
      final target = command.target;
      if (target != null) {
        _resource(target);
        if (target.parentId != null) _owner(command.kind, target.parentId!);
      }
      if (command.destinationParentId case final parentId?) {
        _owner(command.kind, parentId);
      }
      if (command.kind == ResourceKind.timetable) {
        if (target != null) _owner(ResourceKind.course, target.id);
        if (command.values['periodTimeSetId'] case final String setId) {
          _resource(ResourceRef(kind: ResourceKind.periodTimeSet, id: setId));
        }
      }
      if (command.kind == ResourceKind.periodTimeSet &&
          target != null &&
          command.action != ResourceMutationAction.copy) {
        // Rebinding or adding a dependent course changes what a time-set edit
        // affects, even when its own before/after JSON would remain identical.
        _readers['periodTimeSetReferences:${target.id}'] = (data) => [
          for (final table in data.studentMode.timetables)
            if (table.config.periodTimeSetId == target.id) table.toJson(),
        ];
      }
      if (command.kind == ResourceKind.occurrence &&
          command.action == ResourceMutationAction.dismissReminder) {
        setting('app.notifications.generalDefaultMinutesBefore');
      }
    }

    for (final edit in edits) {
      if (edit.kind == SettingEditKind.keep) continue;
      setting(edit.key);
      if (edit.key == 'general.dayStartHour' ||
          edit.key == 'general.dayEndHour') {
        setting('general.dayStartHour');
        setting('general.dayEndHour');
      }
      if (edit.key.startsWith('student.liveCourseOutline')) {
        for (final key in const [
          'Enabled',
          'FollowTheme',
          'CustomColorInitialized',
          'ColorValue',
          'Mode',
          'Width',
        ]) {
          setting('student.liveCourseOutline$key');
        }
      }
      if (edit.key == 'student.courseNameColorValues') {
        _readers['student.courseColorNames'] = (data) =>
            (data.studentMode.timetables
                .expand((table) => table.courses)
                .map((course) => normalizeCourseColorName(course.name))
                .toSet()
                .toList()
              ..sort());
      }
    }
  }

  final _readers = <String, Object? Function(AppData)>{};

  List<String> get keys => List.unmodifiable(_readers.keys);

  Map<String, Object?> snapshot(AppData data) => {
    for (final entry in _readers.entries) entry.key: entry.value(data),
  };

  void _resource(ResourceRef ref) {
    if (ref.kind == ResourceKind.occurrence) {
      final parts = parseGeneralOccurrenceKey(ref.id);
      if (parts == null) return; // The strict compiler reports invalid input.
      _resource(
        ResourceRef(
          kind: ResourceKind.event,
          id: parts.eventId,
          parentId: ref.parentId,
        ),
      );
      return;
    }
    _readers[resourceChangeKey(ref)] = (data) => switch (ref.kind) {
      ResourceKind.timetable => [
        for (final item in data.studentMode.timetables)
          if (item.id == ref.id) item.toJson(),
      ],
      ResourceKind.course => [
        for (final table in data.studentMode.timetables)
          if (table.id == ref.parentId)
            for (final item in table.courses)
              if (item.id == ref.id) item.toJson(),
      ],
      ResourceKind.periodTimeSet => [
        for (final item in data.studentMode.periodTimeSets)
          if (item.id == ref.id) item.toJson(),
      ],
      ResourceKind.calendar => [
        for (final item in data.generalMode.schedules)
          if (item.id == ref.id) item.toJson(),
      ],
      ResourceKind.event => [
        for (final calendar in data.generalMode.schedules)
          if (calendar.id == ref.parentId)
            for (final item in calendar.events)
              if (item.id == ref.id) item.toJson(),
      ],
      ResourceKind.occurrence => const <Object?>[],
    };
  }

  void _owner(ResourceKind child, String id) {
    if (child == ResourceKind.course) {
      _readers['timetableBinding:$id'] = (data) => [
        for (final table in data.studentMode.timetables)
          if (table.id == id)
            {
              'id': table.id,
              'config': table.config.toJson(),
              'periodTimeSets': [
                for (final set in data.studentMode.periodTimeSets)
                  if (set.id == table.config.periodTimeSetId) set.toJson(),
              ],
            },
      ];
    } else if (child == ResourceKind.event ||
        child == ResourceKind.occurrence) {
      _readers['calendarMetadata:$id'] = (data) => [
        for (final calendar in data.generalMode.schedules)
          if (calendar.id == id) Map.of(calendar.toJson())..remove('events'),
      ];
    }
  }
}
