import 'dart:convert';

import '../../application/mutation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../application/resource_contracts.dart';
import '../../application/resource_mutation_schema.dart';
import '../../application/resource_mutations.dart';
import '../../models/timetable_models.dart';
import '../../utils/text_input_limits.dart';
import '../conversations/conversation_models.dart';
import '../provider/provider.dart';
import '../tools/application_tool_host.dart';
import 'school_import_candidate_decoder.dart';

/// A model's extracted candidate is data. The host validates it and prepares a
/// single reversible mutation; this tool never writes or creates a conversation.
void registerSchoolImportTools(ApplicationToolHost host) {
  host.register(
    ToolDefinition(
      name: 'imports.prepare',
      description:
          'Validate an extracted school timetable and prepare one atomic import. '
          'Provide real startDate, totalWeeks, course weeks and times; ask for '
          'missing facts. Choose create or an explicit replacement target. '
          'Select an existing periodTimeSetId when the source has no period times. '
          'Use mutation.commit to apply under the conversation permission mode.',
      parameters: {
        'type': 'object',
        'properties': {
          'candidate': _candidateSchema,
          'action': {
            'type': 'string',
            'enum': ['create', 'replace'],
          },
          'targetTimetableId': {'type': 'string'},
          'periodTimeSetId': {'type': 'string'},
          'sourceId': {
            'type': 'string',
            'description': 'A source attached to this conversation. A sole attachment is selected automatically; choose explicitly when there are multiple.',
          },
          'operationId': {'type': 'string'},
        },
        'required': ['candidate', 'action'],
        'additionalProperties': false,
      },
    ),
    (arguments, scope, _) async {
      const allowed = {
        'candidate',
        'action',
        'targetTimetableId',
        'periodTimeSetId',
        'sourceId',
        'operationId',
      };
      if (arguments.keys.any((key) => !allowed.contains(key))) {
        _invalidImport('Unknown import argument.');
      }
      final action = _optionalText(arguments, 'action');
      if (action != 'create' && action != 'replace') {
        _invalidImport('Choose create or replace.', 'action');
      }
      final targetId = _optionalText(arguments, 'targetTimetableId');
      if ((action == 'replace') != (targetId != null)) {
        _invalidImport(
          'Replacement requires an explicit timetable ID; creation has no target.',
          'targetTimetableId',
        );
      }
      final periodTimeSetId = _optionalText(arguments, 'periodTimeSetId');
      final availableSources =
          host.conversationForScope(scope)?.sources ??
          const <ConversationSource>[];
      final requestedSourceId = _optionalText(arguments, 'sourceId');
      if (requestedSourceId == null && availableSources.length > 1) {
        _invalidImport(
          'Select the source that was used for this candidate.',
          'sourceId',
        );
      }
      final sourceId = requestedSourceId ?? availableSources.firstOrNull?.id;
      ConversationSource? source;
      if (sourceId != null) {
        source = availableSources
            .where((item) => item.id == sourceId)
            .firstOrNull;
        if (source == null) {
          throw const OperationProblem(
            OperationErrorCode.notFound,
            'The source does not belong to this conversation.',
            field: 'sourceId',
          );
        }
        final provenance = source.provenance;
        if (provenance != null &&
            provenance.datasetGeneration != host.mutations.generation) {
          throw const OperationProblem(
            OperationErrorCode.expired,
            'Re-review the source after restoring or clearing application data.',
            field: 'sourceId',
          );
        }
        if (source.targetId != null && source.targetId != targetId) {
          _invalidImport(
            'This source was reviewed for a different timetable target.',
            'targetTimetableId',
          );
        }
      }
      final candidate = _importObject(arguments['candidate'], 'candidate');
      final plan = host.mutations.prepareDraft(
        scope: scope,
        operationId: _optionalText(arguments, 'operationId'),
        command: {
          'action': 'imports.prepare',
          'mode': action,
          'targetTimetableId': targetId,
          'periodTimeSetId': periodTimeSetId,
          'sourceDigest': source?.digest,
          'candidate': candidate,
        },
        compile: (baseline, context) => compileSchoolImport(
          baseline,
          candidate,
          context: context,
          targetTimetableId: targetId,
          periodTimeSetId: periodTimeSetId,
        ),
      );
      final warnings = [
        if (source?.truncated == true)
          'The reviewed source is truncated; this import may be incomplete.',
        ..._importWarnings(candidate),
      ];
      return {
        ...plan.summary(),
        'sourceTruncated': source?.truncated ?? false,
        'warningCount': warnings.length,
        'warningsTruncated':
            warnings.length > 8 ||
            warnings.take(8).any((warning) => warning.length > 256),
        'warnings': [
          for (final warning in warnings.take(8))
            truncateUtf16CodeUnits(warning, 256),
        ],
      };
    },
  );
}

Map<String, Object?> get _timetableSchema => {
  'type': 'object',
  'properties': {
    ...(ResourceMutationSchema.properties(ResourceKind.timetable)
      ..remove('periodTimeSetId')),
    'periodTimeSet': {
      'type': 'object',
      'properties': ResourceMutationSchema.properties(
        ResourceKind.periodTimeSet,
      ),
      'required': ['name', 'periodTimes'],
      'additionalProperties': false,
    },
    'courses': {
      'type': 'array',
      'minItems': 1,
      'maxItems': SchoolImportCandidateDecoder.maxImportedCourseCount,
      'items': {
        'type': 'object',
        'properties': {
          ...ResourceMutationSchema.properties(ResourceKind.course),
          'semesterWeeks': {
            ...(ResourceMutationSchema.properties(
                  ResourceKind.course,
                )['semesterWeeks']
                as Map<String, Object?>),
            'minItems': 1,
            'maxItems':
                SchoolImportCandidateDecoder.maxImportedSemesterWeekCount,
            'uniqueItems': true,
          },
          'periods': {
            ...(ResourceMutationSchema.properties(
                  ResourceKind.course,
                )['periods']
                as Map<String, Object?>),
            'maxItems':
                SchoolImportCandidateDecoder.maxImportedCoursePeriodCount,
            'uniqueItems': true,
          },
          'endMinutes': {'type': 'integer', 'minimum': 0, 'maximum': 1439},
          'customFields': {
            'type': 'object',
            'maxProperties':
                SchoolImportCandidateDecoder.maxImportedCustomFieldCount,
            'additionalProperties': {
              'type': ['string', 'number', 'boolean', 'null'],
            },
          },
        },
        'required': ['name', 'dayOfWeek', 'semesterWeeks'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['name', 'startDate', 'totalWeeks', 'courses'],
  'additionalProperties': false,
};

Map<String, Object?> get _candidateSchema => {
  'anyOf': [
    _timetableSchema,
    {
      'type': 'object',
      'properties': {
        'ok': {'type': 'boolean', 'const': true},
        'message': {'type': 'string'},
        'meta': {
          'type': 'object',
          'properties': {
            'sourceUrl': {'type': 'string'},
            'pageTitle': {'type': 'string'},
            'parser': {'type': 'string'},
            'warnings': {
              'type': 'array',
              'items': {'type': 'string'},
              'maxItems': SchoolImportCandidateDecoder.maxImportWarningCount,
            },
          },
          'additionalProperties': false,
        },
        'timetable': _timetableSchema,
      },
      'required': ['timetable'],
      'additionalProperties': false,
    },
  ],
};

/// Builds only a candidate, using the same strict resource commands as manual
/// Agent edits. Intermediate candidates never reach persistence or reminders.
MutationDraft compileSchoolImport(
  AppData baseline,
  Map<String, Object?> candidate, {
  required MutationContext context,
  String? targetTimetableId,
  String? periodTimeSetId,
}) {
  if (utf8.encode(jsonEncode(candidate)).length >
      ResourceMutationCompiler.maxInputBytes) {
    _invalidImport('The extracted candidate exceeds its byte budget.');
  }
  final wrapped = candidate.containsKey('timetable');
  if (wrapped) {
    _onlyFields(candidate, {'ok', 'message', 'meta', 'timetable'}, 'candidate');
  }
  if (candidate.containsKey('ok') && candidate['ok'] != true) {
    _invalidImport('The extracted candidate did not report a valid timetable.');
  }
  final timetable = wrapped
      ? _importObject(candidate['timetable'], 'timetable')
      : candidate;
  _onlyFields(timetable, {
    'name',
    'startDate',
    'totalWeeks',
    'periodTimeSet',
    'courses',
  }, 'timetable');
  SchoolImportCandidateDecoder.validateResponseBounds({
    'timetable': timetable,
    'meta': candidate['meta'],
  });
  final courses = timetable['courses'];
  if (courses is! List || courses.isEmpty) {
    _invalidImport('Provide at least one complete course.', 'courses');
  }
  final totalWeeks = timetable['totalWeeks'];
  if (totalWeeks is int) {
    for (final course in courses) {
      final values = _importObject(course, 'courses');
      final weeks = values['semesterWeeks'];
      if (weeks is List &&
          weeks.whereType<int>().any((week) => week > totalWeeks)) {
        _invalidImport(
          'A course extends beyond totalWeeks; correct the semester length or course weeks before importing.',
          'courses.semesterWeeks',
        );
      }
    }
  }
  var current = baseline;
  const compiler = ResourceMutationCompiler();
  MutationDraft step(List<ResourceMutation> commands) {
    final result = compiler.compile(current, commands, context: context);
    current = result.candidate;
    return result;
  }

  String setId;
  String? createdSetId;
  if (periodTimeSetId != null) {
    // The timetable command below performs an exact lookup. An unknown handle
    // never falls back to the active timetable's time set.
    setId = periodTimeSetId;
  } else {
    final bundled = _importObject(timetable['periodTimeSet'], 'periodTimeSet');
    final created = step([
      ResourceMutation(
        kind: ResourceKind.periodTimeSet,
        action: ResourceMutationAction.create,
        values: bundled,
      ),
    ]);
    setId = created.changes
        .where((change) => change.ref?.kind == ResourceKind.periodTimeSet)
        .single
        .ref!
        .id;
    createdSetId = setId;
  }
  final original = targetTimetableId == null
      ? null
      : baseline.studentMode.timetables
            .where((item) => item.id == targetTimetableId)
            .firstOrNull;
  if (targetTimetableId != null && original == null) {
    throw const OperationProblem(
      OperationErrorCode.notFound,
      'The replacement timetable no longer exists.',
      field: 'targetTimetableId',
    );
  }
  // Removing existing children inside the candidate permits changing the time
  // set while still validating all newly imported bindings before any save.
  if (original != null && original.courses.isNotEmpty) {
    for (var offset = 0; offset < original.courses.length; offset += 1000) {
      step([
        for (final course in original.courses.skip(offset).take(1000))
          ResourceMutation(
            kind: ResourceKind.course,
            action: ResourceMutationAction.delete,
            target: ResourceRef(
              kind: ResourceKind.course,
              id: course.id,
              parentId: original.id,
            ),
          ),
      ]);
    }
  }
  final tableStep = step([
    ResourceMutation(
      kind: ResourceKind.timetable,
      action: original == null
          ? ResourceMutationAction.create
          : ResourceMutationAction.patch,
      target: original == null
          ? null
          : ResourceRef(kind: ResourceKind.timetable, id: original.id),
      values: {
        'name': timetable['name'],
        'startDate': timetable['startDate'],
        'totalWeeks': timetable['totalWeeks'],
        'periodTimeSetId': setId,
      },
    ),
  ]);
  final tableId =
      original?.id ??
      tableStep.changes
          .where((change) => change.ref?.kind == ResourceKind.timetable)
          .single
          .ref!
          .id;
  step([
    for (final course in courses)
      ResourceMutation(
        kind: ResourceKind.course,
        action: ResourceMutationAction.create,
        destinationParentId: tableId,
        values: _importObject(course, 'courses'),
      ),
  ]);
  final updated = current.studentMode.timetables.singleWhere(
    (table) => table.id == tableId,
  );
  final tableRef = ResourceRef(kind: ResourceKind.timetable, id: tableId);
  final changes = [
    ResourceChange(
      key: resourceChangeKey(tableRef),
      ref: tableRef,
      before: original?.toJson(),
      after: updated.toJson(),
    ),
    if (createdSetId != null)
      ResourceChange(
        key: resourceChangeKey(
          ResourceRef(kind: ResourceKind.periodTimeSet, id: createdSetId),
        ),
        ref: ResourceRef(kind: ResourceKind.periodTimeSet, id: createdSetId),
        before: null,
        after: current.studentMode.periodTimeSets
            .singleWhere((set) => set.id == createdSetId)
            .toJson(),
      ),
  ];
  void auxiliary(String key, Object before, Object after) {
    if (mutationDigest(before) != mutationDigest(after)) {
      changes.add(ResourceChange(key: key, before: before, after: after));
    }
  }

  auxiliary(
    'student.activeTimetableId',
    baseline.studentMode.activeTimetableId,
    current.studentMode.activeTimetableId,
  );
  auxiliary(
    'student.courseNameColorValues',
    baseline.studentMode.courseNameColorValues,
    current.studentMode.courseNameColorValues,
  );
  auxiliary(
    'student.conflictDisplayCourseIds',
    baseline.studentMode.conflictDisplayCourseIds,
    current.studentMode.conflictDisplayCourseIds,
  );
  return MutationDraft(candidate: current, changes: changes);
}

List<String> _importWarnings(Map<String, Object?> candidate) {
  final meta = candidate['meta'];
  if (meta is! Map) return const [];
  final warnings = meta['warnings'];
  return warnings is List
      ? warnings.whereType<String>().take(100).toList()
      : const [];
}

String? _optionalText(Map<String, Object?> source, String key) {
  if (!source.containsKey(key)) return null;
  final value = source[key];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    _invalidImport('Expected a non-empty string.', key);
  }
  return value;
}

Map<String, Object?> _importObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    _invalidImport('Expected a JSON object.', field);
  }
  return Map<String, Object?>.from(value);
}

void _onlyFields(
  Map<String, Object?> value,
  Set<String> fields,
  String prefix,
) {
  for (final key in value.keys) {
    if (!fields.contains(key)) {
      _invalidImport('Unknown candidate field.', '$prefix.$key');
    }
  }
}

Never _invalidImport(String message, [String? field]) => throw OperationProblem(
  OperationErrorCode.invalidArgument,
  message,
  field: field,
);
