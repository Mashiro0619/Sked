import '../models/timetable_models.dart';
import 'resource_contracts.dart';

/// The public value-field catalog is also the compiler's allowed-field source.
/// Semantic constraints still run against the actual destination and snapshot.
abstract final class ResourceMutationSchema {
  static final _fields = {
    for (final kind in ResourceKind.values)
      kind: Set<String>.unmodifiable(properties(kind).keys),
  };

  static Set<String> fields(ResourceKind kind) => _fields[kind]!;

  static Map<String, Object?> properties(ResourceKind kind) => switch (kind) {
    ResourceKind.calendar => {
      'name': _text,
      'colorValue': _color,
      'isVisible': {'type': 'boolean'},
      'sortOrder': {'type': 'integer', 'minimum': 0},
    },
    ResourceKind.timetable => {
      'name': _text,
      'startDate': {
        ..._text,
        'description':
            'Explicit semester start date at local midnight, YYYY-MM-DD.',
      },
      'totalWeeks': {
        'type': 'integer',
        'minimum': 1,
        'maximum': maxTimetableWeeks,
      },
      'periodTimeSetId': {
        ..._text,
        'description':
            'An existing shared time-set ID. Query period_sets.list first.',
      },
    },
    ResourceKind.course => {
      'name': _text,
      'teacher': _text,
      'location': _text,
      'dayOfWeek': {'type': 'integer', 'minimum': 1, 'maximum': 7},
      'semesterWeeks': {
        'type': 'array',
        'items': {
          'type': 'integer',
          'minimum': 1,
          'maximum': maxTimetableWeeks,
        },
      },
      'periods': {
        'type': 'array',
        'items': {'type': 'integer', 'minimum': 1},
      },
      'startMinutes': {'type': 'integer', 'minimum': 0, 'maximum': 1439},
      'endMinutes': {'type': 'integer', 'minimum': 1, 'maximum': 1440},
      'credit': {'type': 'number'},
      'remarks': _text,
      'customFields': {
        'type': 'object',
        'description': 'Preserve caller-defined JSON fields; patches replace this map only when supplied.',
      },
      'reminderSettings': _object(
        {
          'behavior': {
            'type': 'string',
            'enum': CourseReminderBehavior.values
                .map((value) => value.value)
                .toList(),
          },
          'minutesBefore': {
            'type': ['integer', 'null'],
            'minimum': 0,
          },
        },
        ['behavior'],
      ),
    },
    ResourceKind.periodTimeSet => {
      'name': _text,
      'periodTimes': {
        'type': 'array',
        'items': _object(
          {
            'index': {'type': 'integer', 'minimum': 1},
            'startMinutes': {'type': 'integer', 'minimum': 0, 'maximum': 1439},
            'endMinutes': {'type': 'integer', 'minimum': 1, 'maximum': 1440},
          },
          ['index', 'startMinutes', 'endMinutes'],
        ),
      },
    },
    ResourceKind.event || ResourceKind.occurrence => {
      'title': _text,
      'start': {
        ..._text,
        'description':
            'Explicit ISO date/time. All-day events use local midnight.',
      },
      'end': {
        ..._text,
        'description':
            'Exclusive ISO end strictly after start; never inferred from now.',
      },
      'isAllDay': {'type': 'boolean'},
      'recurrenceRule': _object(
        {
          'type': {
            'type': 'string',
            'enum': GeneralEventRecurrence.values
                .map((value) => value.value)
                .toList(),
          },
          'unit': {
            'type': 'string',
            'enum': GeneralEventRecurrenceUnit.values
                .map((value) => value.value)
                .toList(),
          },
          'interval': {'type': 'integer', 'minimum': 1, 'maximum': 999},
          'untilDate': {
            'type': ['string', 'null'],
          },
          'count': {
            'type': ['integer', 'null'],
            'minimum': 1,
          },
          'monthlyAnchorDay': {
            'type': ['integer', 'null'],
            'minimum': 1,
            'maximum': 31,
          },
        },
        ['type'],
      ),
      'recurrenceExceptionDates': {'type': 'array', 'items': _text},
      'location': _text,
      'notes': _text,
      'colorValue': {
        'type': ['integer', 'null'],
        'minimum': 0,
        'maximum': 0xffffffff,
      },
      'reminderBehavior': {
        'type': 'string',
        'enum': GeneralEventReminderBehavior.values
            .map((value) => value.value)
            .toList(),
      },
      'reminders': {
        'type': 'array',
        'items': _object(
          {
            'minutesBefore': {'type': 'integer', 'minimum': 0},
          },
          ['minutesBefore'],
        ),
      },
    },
  };

  static List<String> requiredOnCreate(ResourceKind kind) => switch (kind) {
    ResourceKind.calendar => ['name'],
    ResourceKind.timetable => [
      'name',
      'startDate',
      'totalWeeks',
      'periodTimeSetId',
    ],
    ResourceKind.course => ['name', 'dayOfWeek', 'semesterWeeks'],
    ResourceKind.periodTimeSet => ['name', 'periodTimes'],
    ResourceKind.event => ['title', 'start', 'end'],
    ResourceKind.occurrence => [],
  };

  static Map<String, Object?> describe(ResourceKind kind) => {
    'kind': kind.name,
    'actions': kind == ResourceKind.occurrence
        ? ['patch', 'delete', 'copy', 'dismissReminder', 'restoreReminder']
        : [
            'create',
            'patch',
            'copy',
            'delete',
            if (kind == ResourceKind.course || kind == ResourceKind.event)
              'move',
          ],
    'valuesSchema': _object(properties(kind), []),
    'requiredOnCreate': requiredOnCreate(kind),
    'omittedFields':
        'keep existing values; only create uses documented defaults',
    'target': 'Existing objects require exact id and owning parentId for courses, events and occurrences. Creation IDs come from the host.',
    'destination': 'Creating or moving a course/event requires destinationParentId. Reads and edits never change the current workspace.',
    'constraints': switch (kind) {
      ResourceKind.course => 'Use valid periods from the target time set, or an explicit startMinutes/endMinutes pair. Empty periods select explicit time. New semesterWeeks must be non-empty and within the target semester.',
      ResourceKind.periodTimeSet => 'Periods must be ordered, non-overlapping and valid. Rebind all referencing timetables before deleting. Referenced periods cannot disappear.',
      ResourceKind.occurrence => 'Only general event occurrences are mutable. For patch/delete/copy choose thisOccurrence, thisAndFollowing or entireSeries explicitly. Reminder actions address only the exact occurrence without a scope.',
      ResourceKind.event => 'Use type none to remove recurrence. Monthly anchors and exclusions are preserved on unrelated edits. reminderBehavior custom requires explicit offsets; inherit and disabled do not accept offsets.',
      ResourceKind.calendar => 'Deleting the last calendar creates an empty replacement; the receipt identifies it. sortOrder reorders the list.',
      ResourceKind.timetable => 'startDate, totalWeeks and the shared time-set ID must be explicit on create; existing courses must remain valid after rebinding.',
    },
  };

  static const _text = {'type': 'string'};
  static const _color = {
    'type': 'integer',
    'minimum': 0,
    'maximum': 0xffffffff,
  };
  static Map<String, Object?> _object(
    Map<String, Object?> fields,
    List<String> required,
  ) => {
    'type': 'object',
    'properties': fields,
    'required': required,
    'additionalProperties': false,
  };
}
