import '../models/timetable_models.dart';
import 'mutation_draft.dart' show immutableMutationJson;
import 'operation_contracts.dart';
import 'resource_contracts.dart';

/// The public field catalog drives the compiler's field readers.
/// Semantic constraints still run against the actual destination and snapshot.
abstract final class ResourceMutationSchema {
  static final _properties = {
    for (final kind in ResourceKind.values)
      kind:
          immutableMutationJson(_buildProperties(kind)) as Map<String, Object?>,
  };
  static final _fields = {
    for (final kind in ResourceKind.values)
      kind: Set<String>.unmodifiable(properties(kind).keys),
  };

  static Set<String> fields(ResourceKind kind) => _fields[kind]!;

  static Map<String, Object?> properties(ResourceKind kind) =>
      Map.of(_properties[kind]!);

  static ApplicationField field(ResourceKind kind, String name) =>
      ApplicationField(name, _properties[kind]![name] as Map<String, Object?>);

  static void readFields(
    ResourceKind kind,
    Map<String, Object?> values, {
    required bool creating,
  }) {
    ApplicationField(
      '',
      _object(_properties[kind]!, creating ? requiredOnCreate(kind) : const []),
    ).object(values);
  }

  static Map<String, Object?> _buildProperties(
    ResourceKind kind,
  ) => switch (kind) {
    ResourceKind.calendar => {
      'name': _nonBlank,
      'colorValue': _color,
      'isVisible': {'type': 'boolean'},
      'sortOrder': {'type': 'integer', 'minimum': 0},
    },
    ResourceKind.timetable => {
      'name': _nonBlank,
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
        ..._nonBlank,
        'description':
            'An existing shared time-set ID. Query period_sets.list first.',
      },
    },
    ResourceKind.course => {
      'name': _nonBlank,
      'teacher': _text,
      'location': _text,
      'dayOfWeek': {'type': 'integer', 'minimum': 1, 'maximum': 7},
      'semesterWeeks': {
        'type': 'array',
        'minItems': 1,
        'uniqueItems': true,
        'items': {
          'type': 'integer',
          'minimum': 1,
          'maximum': maxTimetableWeeks,
        },
      },
      'periods': {
        'type': 'array',
        'uniqueItems': true,
        'items': {'type': 'integer', 'minimum': 1},
      },
      'startMinutes': {'type': 'integer', 'minimum': 0, 'maximum': 1439},
      'endMinutes': {
        'type': 'integer',
        'minimum': 0,
        'maximum': 1439,
        'description': 'Minutes within the day; 0 together with startMinutes 0 preserves an unknown raw time.',
      },
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
      'name': _nonBlank,
      'periodTimes': {
        'type': 'array',
        'minItems': 1,
        'items': _object(
          {
            'index': {'type': 'integer', 'minimum': 1},
            'startMinutes': {'type': 'integer', 'minimum': 0, 'maximum': 1439},
            'endMinutes': {'type': 'integer', 'minimum': 1, 'maximum': 1439},
          },
          ['index', 'startMinutes', 'endMinutes'],
        ),
      },
    },
    ResourceKind.event || ResourceKind.occurrence => {
      'title': _nonBlank,
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
  static const _nonBlank = {'type': 'string', 'pattern': r'\S'};
  static final _color = {
    'type': 'integer',
    'anyOf': [
      {'enum': generalCalendarSlotColorValues.toList()},
      {'minimum': 0, 'maximum': 0xffffffff},
    ],
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

/// Reads only the requested value from the same field definition published to callers.
/// Nested objects and array items are consumed by their domain parser.
class ApplicationField {
  const ApplicationField(this.name, this.schema);

  final String name;
  final Map<String, Object?> schema;

  ApplicationField property(String key) => ApplicationField(
    name.isEmpty ? key : '$name.$key',
    (schema['properties'] as Map)[key] as Map<String, Object?>,
  );
  ApplicationField get item =>
      ApplicationField(name, schema['items'] as Map<String, Object?>);

  String string(Object? value) => _scalar(value) as String;
  int integer(Object? value) => _scalar(value) as int;
  num number(Object? value) => _scalar(value) as num;
  bool boolean(Object? value) => _scalar(value) as bool;

  Object? _scalar(Object? value) {
    value ??= schema['default'];
    if (!_matches(value, schema)) _invalid('Invalid value for $name.');
    return value;
  }

  List<Object?> list(Object? value) {
    final minimum = schema['minItems'] as int?;
    final maximum = schema['maxItems'] as int?;
    if (value is! List ||
        (minimum != null && value.length < minimum) ||
        (maximum != null && value.length > maximum)) {
      _invalid('Invalid list for $name.');
    }
    return value;
  }

  Map<String, Object?> object(Object? value) {
    if (value is! Map<String, Object?>) {
      _invalid('Expected an object for $name.');
    }
    final properties = schema['properties'] as Map?;
    if (schema['additionalProperties'] == false && properties != null) {
      for (final key in value.keys) {
        if (!properties.containsKey(key)) _invalid('Unknown field.', key);
      }
    }
    for (final key in schema['required'] as List? ?? const []) {
      if (!value.containsKey(key)) {
        _invalid('Missing required field.', key as String);
      }
    }
    return value;
  }

  static bool _matches(Object? value, Map schema) {
    final types = schema['type'];
    bool matchesType(Object? type) => switch (type) {
      null => true,
      'null' => value == null,
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num && value.isFinite,
      'boolean' => value is bool,
      _ => false,
    };
    if (types is List ? !types.any(matchesType) : !matchesType(types)) {
      return false;
    }
    if (schema['enum'] case final List values when !values.contains(value)) {
      return false;
    }
    if (value is num) {
      final minimum = schema['minimum'] as num?;
      final maximum = schema['maximum'] as num?;
      if (!value.isFinite ||
          (minimum != null && value < minimum) ||
          (maximum != null && value > maximum)) {
        return false;
      }
    }
    final pattern = schema['pattern'] as String?;
    if (value is String && pattern != null) {
      if (!RegExp(pattern).hasMatch(value)) return false;
    }
    if (schema['anyOf'] case final List alternatives) {
      if (!alternatives.cast<Map>().any((part) => _matches(value, part))) {
        return false;
      }
    }
    return true;
  }

  Never _invalid(String message, [String? child]) => throw OperationProblem(
    OperationErrorCode.invalidArgument,
    message,
    field: child == null
        ? name
        : name.isEmpty
        ? child
        : '$name.$child',
  );
}
