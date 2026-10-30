import 'dart:convert';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../application/resource_queries.dart';
import '../../application/resource_mutations.dart';
import '../../controllers/app_backup_controller.dart';
import '../../controllers/general_navigation_controller.dart';
import '../../controllers/workspace_commands.dart';
import '../../models/school_import_models.dart';
import '../../models/timetable_models.dart';
import '../../services/data_transfer_codec.dart';
import '../../services/developer_sample_data_service.dart';
import '../../services/general_calendar_ics_service.dart';
import '../../services/import_export_service.dart';
import '../../services/student_timetable_service.dart';
import '../../widgets/timetable_week_projection.dart';
import '../../utils/unique_id.dart';
import '../conversations/conversation_models.dart';
import '../provider/provider.dart';
import '../runtime/agent_runtime_controller.dart' show AgentApprovalRequester;
import 'application_tool_host.dart';
import 'platform_tool_adapters.dart';

class AgentDataArtifact {
  const AgentDataArtifact({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.text,
  });
  final String id;
  final String name;
  final String mimeType;
  final String text;
  String get digest => mutationDigest(text);
  Map<String, Object?> summary() => {
    'artifactId': id,
    'name': name,
    'mimeType': mimeType,
    'bytes': utf8.encode(text).length,
    'digest': digest,
  };
}

class AgentArtifactWriteResult {
  const AgentArtifactWriteResult({
    required this.saved,
    this.cancelled = false,
    this.destination,
  });
  final bool saved;
  final bool cancelled;
  final String? destination;
}

class AgentNavigationTarget {
  const AgentNavigationTarget({
    required this.workspace,
    this.ref,
    this.date,
    this.week,
  });
  final AppMode workspace;
  final ResourceRef? ref;
  final DateTime? date;
  final int? week;
  Map<String, Object?> toJson() => {
    'workspace': workspace.name,
    if (ref != null) 'ref': ref!.toJson(),
    if (date != null) 'date': date!.toIso8601String(),
    if (week != null) 'week': week,
  };
}

typedef AgentMaintenanceRunner = Future<ExternalEffectResult> Function(
  OperationScope scope,
  Future<ExternalEffectResult> Function() action,
);

WorkflowToolAdapters registerWorkflowTools(
  ApplicationToolHost host, {
  required ExternalOperationCoordinator external,
  required PlatformToolAdapters platformTools,
  AppBackupController? backups,
  WorkspaceCommands? workspaces,
  DataTransferCodec codec = const DataTransferCodec(),
  AgentMaintenanceRunner? runMaintenance,
}) => WorkflowToolAdapters._(
  host: host,
  external: external,
  platformTools: platformTools,
  backups: backups,
  workspaces: workspaces,
  codec: codec,
  runMaintenance: runMaintenance,
).._register();

/// Pure codecs create bounded candidates. Main-data imports use the same
/// atomic receipt gate as other mutations; side effects use the existing
/// backup/maintenance owners and external pending receipts.
class WorkflowToolAdapters {
  WorkflowToolAdapters._({
    required this._host,
    required this._external,
    required this._platformTools,
    required this._backups,
    required this._workspaces,
    required this._codec,
    required this._runMaintenance,
  });

  final ApplicationToolHost _host;
  final ExternalOperationCoordinator _external;
  final PlatformToolAdapters _platformTools;
  final AppBackupController? _backups;
  final WorkspaceCommands? _workspaces;
  final DataTransferCodec _codec;
  final AgentMaintenanceRunner? _runMaintenance;
  Future<AgentArtifactWriteResult> Function(AgentDataArtifact)? _saveArtifact;
  Future<ExternalEffectResult> Function(OperationScope)? _clearData;
  Future<ExternalEffectResult> Function(AgentNavigationTarget)? _navigation;
  Future<ExternalEffectResult> Function(DeveloperSampleLanguage)?
  _developerSample;
  final _artifacts =
      <String, ({AgentDataArtifact value, OperationScope scope})>{};
  int _binding = 0;

  void bindServices({
    Future<AgentArtifactWriteResult> Function(AgentDataArtifact)? saveArtifact,
    Future<ExternalEffectResult> Function(OperationScope)? clearData,
    Future<ExternalEffectResult> Function(AgentNavigationTarget)? navigation,
    Future<ExternalEffectResult> Function(DeveloperSampleLanguage)?
    developerSample,
  }) {
    _saveArtifact = saveArtifact;
    _clearData = clearData;
    _navigation = navigation;
    _developerSample = developerSample;
    _binding++;
  }

  Map<String, Object?>? _recorded(
    Map<String, Object?> args,
    OperationScope scope,
    String action, {
    ExternalEffect? readBack,
  }) {
    final plan = _external.prepareRecorded(
      scope: scope,
      action: action,
      request: _request(args),
      operationId: _optionalText(args, 'operationId'),
      readBack: readBack,
    );
    return plan == null ? null : boundedToolReceipt(plan.summary());
  }

  void _add(
    String name,
    String description,
    Map<String, Object?> properties,
    ApplicationToolAction action, {
    List<String> required = const [],
  }) => _host.register(
    ToolDefinition(
      name: name,
      description: description,
      parameters: {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': false,
      },
    ),
    action,
  );

  void _register() {
    _registerDisplayAndRange();
    _add(
      'file_imports.inspect',
      'Decode an attached JSON/ICS/period-times file without changing data. Read exact imported IDs, missing start dates and all diagnostics using bounded pages.',
      {
        'sourceId': _string,
        'format': _format,
        'offset': _offsetSchema,
        'limit': _limitSchema,
      },
      _inspectImport,
      required: ['sourceId', 'format'],
    );
    _add(
      'file_imports.prepare',
      'Prepare an atomic import from one attached structured file. Select exact source IDs and add or replace an explicit target. Unknown IDs and missing semester dates fail. Commit with mutation.commit.',
      {
        'sourceId': _string,
        'format': _format,
        'action': {
          'type': 'string',
          'enum': ['add', 'replace'],
        },
        'ids': _idsSchema,
        'targetId': _string,
        'periodTimeSetId': _string,
        'name': _string,
        'confirmedStartDates': {
          'type': 'object',
          'additionalProperties': _string,
        },
        'operationId': _string,
      },
      _prepareFileImport,
      required: ['sourceId', 'format', 'action'],
    );
    _add(
      'exports.prepare',
      'Generate an immutable in-memory JSON/ICS/backup artifact from explicit resource IDs. This does not write a file or share it. Use exports.write then external.commit to save.',
      {
        'format': {
          'type': 'string',
          'enum': [..._fileFormats, 'backup_json'],
        },
        'ids': _idsSchema,
      },
      _prepareExport,
      required: ['format'],
    );
    _add(
      'exports.write',
      'Prepare saving a generated artifact through the application file destination picker. This never shares externally; commit with external.commit.',
      {'artifactId': _string, 'operationId': _string},
      _prepareArtifactWrite,
      required: ['artifactId'],
    );
    _add(
      'backups.describe',
      'Read restore support and current backup recovery status. Internal journal phases are read-only.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return {
          'supported': _backups != null && _runMaintenance != null,
          'journalStatus': _backups?.journalLoadStatus?.name,
          'canStartFreshAfterRecovery':
              _backups?.canStartFreshAfterRecovery ?? false,
          'generation': _host.mutations.generation,
          'current': _counts(_host.session.committedData),
        };
      },
    );
    _add(
      'backups.prepare_restore',
      'Prepare complete restore from an attached backup. The existing multi-store journal owns execution; local Agent connection and permissions are retained. Commit with external.commit.',
      {'sourceId': _string, 'operationId': _string},
      _prepareRestore,
      required: ['sourceId'],
    );
    _add(
      'maintenance.prepare_clear',
      'Prepare clearing all local application data, conversations, credentials and device preferences through the normal cleanup and guarded exit workflow. Commit with external.commit.',
      {'operationId': _string},
      _prepareClear,
    );
    _add(
      'workspaces.describe',
      'Read workspace availability separately from global management queries. Disabled workspaces remain queryable.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return _workspaceSnapshot();
      },
    );
    _add(
      'workspaces.prepare',
      'Prepare enabling, disabling or switching an existing workspace. At least one remains enabled; existing editor exit guards apply. Commit with external.commit.',
      {
        'workspace': _workspaceSchema,
        'action': {
          'type': 'string',
          'enum': ['enable', 'disable', 'switch'],
        },
        'operationId': _string,
      },
      _prepareWorkspace,
      required: ['workspace', 'action'],
    );
    _platformTools.registerReadBack('workspace.change', _readWorkspace);
    _add(
      'navigation.status',
      'Read currently selected workspace and resource without changing it.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return _navigationSnapshot();
      },
    );
    _add(
      'navigation.open',
      'Prepare revealing an explicit existing object, date or week. This changes navigation, never enables a disabled workspace. Commit with external.commit.',
      {
        'workspace': _workspaceSchema,
        'ref': {
          'type': 'object',
          'properties': {
            'kind': {
              'type': 'string',
              'enum': ResourceKind.values.map((k) => k.name).toList(),
            },
            'id': _string,
            'parentId': _string,
          },
          'required': ['kind', 'id'],
          'additionalProperties': false,
        },
        'date': _string,
        'week': {'type': 'integer', 'minimum': 1, 'maximum': 1000},
        'operationId': _string,
      },
      _prepareNavigation,
      required: ['workspace'],
    );
    _add(
      'developer.sample.prepare',
      'Prepare appending the existing deterministic developer sample data. This is an explicit data mutation and does not happen while changing ordinary preferences. Commit with external.commit.',
      {
        'language': {
          'type': 'string',
          'enum': DeveloperSampleLanguage.values.map((v) => v.name).toList(),
        },
        'operationId': _string,
      },
      _prepareDeveloperSample,
      required: ['language'],
    );
  }

  void _registerDisplayAndRange() {
    _add(
      'courses.display.list',
      'Read actual full-conflict groups for one timetable week, including the current displayed course and selectable course IDs. Disabled workspaces and non-current timetables are supported.',
      {
        'timetableId': _string,
        'week': _weekSchema,
        'offset': _offsetSchema,
        'limit': _limitSchema,
      },
      (args, scope, _) async {
        _keys(args, {'timetableId', 'week', 'offset', 'limit'});
        scope.checkActive();
        final data = _host.session.committedData;
        final timetableId = _text(args, 'timetableId');
        final week = _integer(args, 'week', min: 1, max: 1000);
        final groups = _displayGroups(data, timetableId, week, DateTime.now());
        final offset = _integer(args, 'offset', max: 1000000);
        final limit = _integer(args, 'limit', fallback: 25, min: 1);
        final page = groups.skip(offset).take(limit).toList();
        return {
          'timetableId': timetableId,
          'week': week,
          'itemCount': groups.length,
          'rows': [
            for (final group in page)
              {
                'conflictKey': group.layout.conflictKey,
                'weekday': group.weekday,
                'startMinutes': group.layout.startMinutes,
                'endMinutes': group.layout.endMinutes,
                'displayedCourseId': group.layout.course!.id,
                'preferredCourseId': readDisplayedCourseIdForConflict(
                  data.studentMode.conflictDisplayCourseIds,
                  group.layout.conflictKey!,
                ),
                'displayState': group.layout.displayState.name,
                'courseIds': [
                  for (final course in group.layout.conflictCourses)
                    (course as CourseItem).id,
                ],
                'selectableCourseIds':
                    group.layout.selectableConflictCourseIds!.toList()..sort(),
              },
          ],
          'nextOffset': offset + page.length < groups.length
              ? offset + page.length
              : null,
        };
      },
      required: ['timetableId', 'week'],
    );
    _add(
      'courses.display.prepare',
      'Prepare setting or resetting the displayed course for an exact full-conflict key returned by courses.display.list. A set must use a selectable course in that week. Commit with mutation.commit; this never switches or enables a workspace.',
      {
        'action': _setResetSchema,
        'timetableId': _string,
        'week': _weekSchema,
        'conflictKey': _string,
        'courseId': _string,
        'operationId': _string,
      },
      _prepareConflictDisplay,
      required: ['action', 'timetableId', 'week', 'conflictKey'],
    );
    _add(
      'navigation.range.prepare',
      'Prepare setting or resetting the general custom date range. Set requires real YYYY-MM-DD start/end dates spanning 1–14 inclusive days within 1970-01-01 through 2100-01-01. Preserves focus inside the range, otherwise focuses its start; reset follows normal hidden-weekend focus behavior. Commit with mutation.commit; disabled workspaces are supported.',
      {
        'action': _setResetSchema,
        'start': _string,
        'end': _string,
        'operationId': _string,
      },
      _prepareDateRange,
      required: ['action'],
    );
  }

  List<({int weekday, CourseLayout layout})> _displayGroups(
    AppData data,
    String timetableId,
    int week,
    DateTime now,
  ) {
    final student = data.studentMode;
    final timetable = student.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    if (timetable == null) _missingTarget();
    if (week > timetable.config.totalWeeks) {
      _invalid('Week is outside the selected timetable semester.');
    }
    final periods = periodTimeSetForId(
      student,
      timetable.config.periodTimeSetId,
    );
    if (periods == null || periods.periodTimes.isEmpty) {
      _invalid('The timetable has no valid bound period-time set.');
    }
    final projection = TimetableWeekProjectionCache().project(
      timetable: timetable,
      periodTimes: periods.periodTimes,
      selectedWeek: week,
      realCurrentWeek: currentWeekFor(timetable.config, now: now),
      showPastEndedCourses: student.showPastEndedCourses,
      showFutureCourses: student.showFutureCourses,
      preserveGaps: student.preserveTimetableGaps,
    );
    final layouts = projection.resolveLayouts(
      (key) => readDisplayedCourseIdForConflict(
        student.conflictDisplayCourseIds,
        key,
      ),
    );
    return [
      for (final day in layouts.entries)
        for (final layout in day.value)
          if (layout.isFullConflict && layout.conflictKey != null)
            (weekday: day.key, layout: layout),
    ];
  }

  Future<Map<String, Object?>> _prepareConflictDisplay(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {
      'action',
      'timetableId',
      'week',
      'conflictKey',
      'courseId',
      'operationId',
    });
    final action = _text(args, 'action');
    if (!{'set', 'reset'}.contains(action)) _invalid('Unknown display action.');
    final timetableId = _text(args, 'timetableId');
    final week = _integer(args, 'week', min: 1, max: 1000);
    final conflictKey = _text(args, 'conflictKey');
    if (action == 'reset' && args.containsKey('courseId')) {
      _invalid('Reset does not accept a courseId.');
    }
    final courseId = action == 'set' ? _text(args, 'courseId') : null;
    final plan = _host.mutations.prepareDraft(
      scope: scope,
      operationId: _optionalText(args, 'operationId'),
      command: {'action': 'courses.display', 'request': _request(args)},
      compile: (baseline, context) {
        final group = _displayGroups(
          baseline,
          timetableId,
          week,
          context.now,
        ).where((group) => group.layout.conflictKey == conflictKey).firstOrNull;
        if (group == null) {
          _invalid(
            'The conflict key is not a current full-conflict group in this week.',
          );
        }
        if (courseId != null &&
            !group.layout.selectableConflictCourseIds!.contains(courseId)) {
          _invalid(
            'The course cannot replace this week\'s displayed conflict.',
          );
        }
        final before = baseline.studentMode;
        final after = const StudentTimetableService()
            .setDisplayedCourseForConflict(before, conflictKey, courseId);
        return MutationDraft(
          candidate: baseline.copyWith(studentMode: after),
          changes: [
            if (mutationDigest(before.conflictDisplayCourseIds) !=
                mutationDigest(after.conflictDisplayCourseIds))
              ResourceChange(
                key: 'student.conflictDisplayCourseIds',
                before: before.conflictDisplayCourseIds,
                after: after.conflictDisplayCourseIds,
              ),
          ],
        );
      },
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<Map<String, Object?>> _prepareDateRange(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'action', 'start', 'end', 'operationId'});
    final action = _text(args, 'action');
    if (!{'set', 'reset'}.contains(action)) {
      _invalid('Unknown date-range action.');
    }
    if (action == 'reset' &&
        (args.containsKey('start') || args.containsKey('end'))) {
      _invalid('Reset does not accept start or end dates.');
    }
    GeneralDateRange? range;
    if (action == 'set') {
      try {
        range = GeneralDateRange.fromJson({
          'start': args['start'],
          'end': args['end'],
        });
      } on FormatException catch (error) {
        _invalid(error.message);
      }
    }
    final plan = _host.mutations.prepareDraft(
      scope: scope,
      operationId: _optionalText(args, 'operationId'),
      command: {'action': 'navigation.range', 'request': _request(args)},
      compile: (baseline, context) {
        final before = baseline.generalMode;
        final after = range == null
            ? GeneralNavigationController.withoutDateRange(before)
            : GeneralNavigationController.withDateRange(before, range);
        return MutationDraft(
          candidate: baseline.copyWith(generalMode: after),
          changes: [
            if (before.customDateRange != after.customDateRange)
              ResourceChange(
                key: 'general.customDateRange',
                before: before.customDateRange?.toJson(),
                after: after.customDateRange?.toJson(),
              ),
            if (before.selectedDateIso != after.selectedDateIso)
              ResourceChange(
                key: 'general.selectedDateIso',
                before: before.selectedDateIso,
                after: after.selectedDateIso,
              ),
          ],
        );
      },
    );
    return boundedToolReceipt(plan.summary());
  }

  ConversationSource _source(
    OperationScope scope,
    String id, {
    bool currentGeneration = true,
  }) {
    final source = _host
        .conversationForScope(scope)
        ?.sources
        .where((s) => s.id == id)
        .firstOrNull;
    if (source == null) {
      throw const OperationProblem(
        OperationErrorCode.notFound,
        'The source is not attached to this conversation.',
      );
    }
    if (currentGeneration &&
        source.provenance != null &&
        source.provenance!.datasetGeneration != _host.mutations.generation) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'Reattach or re-review this source after restoring application data.',
      );
    }
    return source;
  }

  Future<Object> _decode(String source, String format) {
    final locale = _host.session.committedData.localeCode;
    return switch (format) {
      'timetables_json' => _codec.decodeTimetables(source, localeCode: locale),
      'schedules_json' || 'schedules_ics' => _codec.decodeSchedules(
        source,
        localeCode: locale,
        ics: format == 'schedules_ics',
      ),
      'period_times_json' => _codec.decodePeriodTimes(
        source,
        localeCode: locale,
      ),
      _ => throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'Unknown file format.',
      ),
    };
  }

  Future<Map<String, Object?>> _inspectImport(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'sourceId', 'format', 'offset', 'limit'});
    final source = _source(scope, _text(args, 'sourceId'));
    final decoded = await _decode(source.text, _text(args, 'format'));
    scope.checkActive();
    final records = <Map<String, Object?>>[];
    final warnings = <Map<String, Object?>>[];
    if (decoded is TimetableImportCandidate) {
      for (final t in decoded.timetables) {
        records.add({
          'id': t.id,
          'name': t.config.name,
          'courses': t.courses.length,
          'startDateNeedsConfirmation': t.config.startDateNeedsConfirmation,
          'startDate': t.config.startDate.toIso8601String(),
          'periodTimeSetId': t.config.periodTimeSetId,
        });
      }
    } else if (decoded is GeneralImportCandidate) {
      for (final c in decoded.schedules) {
        records.add({'id': c.id, 'name': c.name, 'events': c.events.length});
      }
      warnings.addAll(decoded.warnings.map(_warning));
    } else if (decoded is List<CoursePeriodTime>) {
      records.addAll(decoded.map((p) => Map<String, Object?>.from(p.toJson())));
    }
    final offset = _integer(args, 'offset', fallback: 0, max: 1000000);
    final limit = _integer(args, 'limit', fallback: 50, min: 1, max: 100);
    final rows = [
      ...records.map((r) => {'type': 'item', ...r}),
      ...warnings.map((w) => {'type': 'diagnostic', ...w}),
    ];
    return {
      'sourceId': source.id,
      'sourceDigest': source.digest,
      'sourceTruncated': source.truncated,
      'itemCount': records.length,
      'diagnosticCount': warnings.length,
      'rows': rows.skip(offset).take(limit).toList(),
      'hasMore': offset + limit < rows.length,
      'nextOffset': offset + limit < rows.length ? offset + limit : null,
    };
  }

  Future<Map<String, Object?>> _prepareFileImport(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {
      'sourceId',
      'format',
      'action',
      'ids',
      'targetId',
      'periodTimeSetId',
      'name',
      'confirmedStartDates',
      'operationId',
    });
    final source = _source(scope, _text(args, 'sourceId'));
    final format = _text(args, 'format'), action = _text(args, 'action');
    if (source.truncated) {
      _invalid('Attach the complete structured file before importing it.');
    }
    if (!{'add', 'replace'}.contains(action)) {
      _invalid('Choose add or replace.');
    }
    final target = _optionalText(args, 'targetId');
    if ((action == 'replace') != (target != null)) {
      _invalid(
        'Replacement needs one explicit target; addition has no target.',
      );
    }
    final decoded = await _decode(source.text, format);
    scope.checkActive();
    _source(scope, source.id);
    final requested = _ids(
      args['ids'],
      required: format != 'period_times_json',
    );
    final dates = _map(args['confirmedStartDates'] ?? const {});
    final confirmed = {for (final e in dates.entries) e.key: _date(e.value)};
    final setId = _optionalText(args, 'periodTimeSetId');
    final command = <String, Object?>{...args}..remove('operationId');
    final plan = _host.mutations.prepareDraft(
      scope: scope,
      operationId: _optionalText(args, 'operationId'),
      command: {
        'tool': 'file_imports.prepare',
        ...command,
        'sourceDigest': source.digest,
      },
      compile: (baseline, context) {
        const service = ImportExportService();
        AppData candidate;
        if (decoded is TimetableImportCandidate) {
          if (args.containsKey('name')) {
            _invalid('Timetable imports preserve the names in the source.');
          }
          _requireIds(requested, decoded.timetables.map((t) => t.id));
          if (dates.keys.any((key) => !requested.contains(key))) {
            _invalid('A confirmed start date has no selected timetable.');
          }
          if (target != null &&
              !baseline.studentMode.timetables.any((t) => t.id == target)) {
            _missingTarget();
          }
          final result = service.importPreparedTimetables(
            baseline.studentMode,
            decoded.data,
            timetableIds: requested,
            mode: action == 'add'
                ? TimetableImportMode.addAsNew
                : TimetableImportMode.replaceActive,
            localeCode: baseline.localeCode,
            importBundledPeriodTimeSets: setId == null,
            targetPeriodTimeSetId: setId,
            replacementTimetableId: target,
            confirmedStartDates: confirmed,
          );
          candidate = baseline.copyWith(
            studentMode: result.data.copyWith(
              activeTimetableId: baseline.studentMode.activeTimetableId,
            ),
          );
        } else if (decoded is GeneralImportCandidate) {
          _requireIds(requested, decoded.schedules.map((s) => s.id));
          if (setId != null || dates.isNotEmpty || args.containsKey('name')) {
            _invalid('Schedule imports do not accept timetable options.');
          }
          if (target != null &&
              !baseline.generalMode.schedules.any((c) => c.id == target)) {
            _missingTarget();
          }
          final result = service.importPreparedGeneralSchedules(
            baseline.generalMode,
            decoded.schedules,
            scheduleIds: requested,
            mode: action == 'add'
                ? GeneralScheduleImportMode.addAsNew
                : GeneralScheduleImportMode.replaceActive,
            replacementScheduleId: target,
            localeCode: baseline.localeCode,
            icsWarnings: decoded.warnings,
          );
          candidate = baseline.copyWith(
            generalMode: result.data.copyWith(
              activeScheduleId: baseline.generalMode.activeScheduleId,
            ),
          );
        } else {
          if (requested.isNotEmpty || dates.isNotEmpty || setId != null) {
            _invalid(
              'Period-time imports do not accept schedule or timetable options.',
            );
          }
          final times = decoded as List<CoursePeriodTime>;
          final old = target == null
              ? null
              : baseline.studentMode.periodTimeSets
                    .where((s) => s.id == target)
                    .firstOrNull;
          if (target != null && old == null) _missingTarget();
          final name = _optionalText(args, 'name') ?? old?.name;
          if (name == null) _invalid('A new period-time set requires a name.');
          return const ResourceMutationCompiler().compile(baseline, [
            ResourceMutation(
              kind: ResourceKind.periodTimeSet,
              action: old == null
                  ? ResourceMutationAction.create
                  : ResourceMutationAction.patch,
              target: old == null
                  ? null
                  : ResourceRef(kind: ResourceKind.periodTimeSet, id: old.id),
              values: {
                'name': name,
                'periodTimes': times.map((time) => time.toJson()).toList(),
              },
            ),
          ], context: context);
        }
        return const ResourceMutationCompiler().diffResources(
          baseline,
          candidate,
        );
      },
    );
    final warnings = decoded is GeneralImportCandidate
        ? decoded.warnings.map(_warning).toList()
        : const <Map<String, Object?>>[];
    return {
      ...boundedToolReceipt(plan.summary()),
      'sourceTruncated': source.truncated,
      'diagnosticCount': warnings.length,
      'diagnostics': warnings.take(20).toList(),
      'hasMoreDiagnostics': warnings.length > 20,
    };
  }

  Future<Map<String, Object?>> _prepareExport(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'format', 'ids'});
    final format = _text(args, 'format'), data = _host.session.committedData;
    final ids = _ids(args['ids'], required: format != 'backup_json');
    late final String text;
    switch (format) {
      case 'timetables_json':
        _requireIds(ids, data.studentMode.timetables.map((t) => t.id));
        text = await _codec.encodeTimetables(
          data.studentMode,
          ids,
          localeCode: data.localeCode,
        );
      case 'schedules_json' || 'schedules_ics':
        _requireIds(ids, data.generalMode.schedules.map((c) => c.id));
        text = await _codec.encodeSchedules(
          data.generalMode,
          ids,
          localeCode: data.localeCode,
          ics: format == 'schedules_ics',
        );
      case 'period_times_json':
        if (ids.length != 1) _invalid('Select exactly one period-time set.');
        final set = data.studentMode.periodTimeSets
            .where((s) => s.id == ids.single)
            .firstOrNull;
        if (set == null) _missingTarget();
        text = await _codec.encodePeriodTimes(set.periodTimes);
      case 'backup_json':
        if (ids.isNotEmpty) {
          _invalid('Complete backups do not accept a resource selection.');
        }
        final backups = _backups;
        if (backups == null) _unsupported('Backup export is unavailable.');
        text = await backups.exportJson();
      default:
        _invalid('Unknown export format.');
    }
    scope.checkActive();
    if (utf8.encode(text).length > 32 * 1024 * 1024) {
      _invalid('The export exceeds the in-memory artifact budget.');
    }
    _artifacts.removeWhere((_, value) => value.scope.isCancelled);
    var bytes = _artifacts.values.fold<int>(
      0,
      (n, e) => n + utf8.encode(e.value.text).length,
    );
    while (_artifacts.isNotEmpty &&
        (_artifacts.length >= 8 ||
            bytes + utf8.encode(text).length > 32 * 1024 * 1024)) {
      final removed = _artifacts.remove(_artifacts.keys.first)!;
      bytes -= utf8.encode(removed.value.text).length;
    }
    final artifact = AgentDataArtifact(
      id: generateUuidV4(),
      name: 'sked-$format.${format == 'schedules_ics' ? 'ics' : 'json'}',
      mimeType: format == 'schedules_ics'
          ? 'text/calendar'
          : 'application/json',
      text: text,
    );
    _artifacts[artifact.id] = (value: artifact, scope: scope);
    return {
      'status': 'preparedArtifact',
      ...artifact.summary(),
      'fileWritten': false,
      'sourceGeneration': _host.mutations.generation,
    };
  }

  Future<Map<String, Object?>> _prepareArtifactWrite(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'artifactId', 'operationId'});
    final replay = _recorded(args, scope, 'exports.write');
    if (replay != null) return replay;
    final stored = _artifacts[_text(args, 'artifactId')], save = _saveArtifact;
    if (stored == null || !identical(stored.scope, scope)) {
      _expired('The generated artifact is no longer available in this run.');
    }
    if (save == null) _unsupported('No file destination picker is attached.');
    final artifact = stored.value, binding = _binding;
    final plan = _external.prepare(
      scope: scope,
      action: 'exports.write',
      arguments: {'request': _request(args), ...artifact.summary()},
      version: artifact.digest,
      changes: [
        ResourceChange(
          key: 'export.file',
          before: null,
          after: artifact.summary(),
        ),
      ],
      operationId: _optionalText(args, 'operationId'),
      validate: () {
        if (_binding != binding ||
            !identical(_saveArtifact, save) ||
            !identical(_artifacts[artifact.id]?.value, artifact)) {
          _conflict();
        }
      },
      execute: (_) async {
        final result = await save(artifact);
        return ExternalEffectResult(
          state: result.saved
              ? ExternalEffectState.applied
              : result.cancelled
              ? ExternalEffectState.failed
              : ExternalEffectState.unknown,
          details: {
            ...artifact.summary(),
            'saved': result.saved,
            'cancelled': result.cancelled,
            if (result.destination != null) 'destination': result.destination,
            'sharedExternally': false,
          },
        );
      },
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<Map<String, Object?>> _prepareRestore(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'sourceId', 'operationId'});
    final replay = _recorded(args, scope, 'backups.restore');
    if (replay != null) return replay;
    final backups = _backups, run = _runMaintenance;
    if (backups == null || run == null) {
      _unsupported('The backup restore workflow is unavailable.');
    }
    final source = _source(
      scope,
      _text(args, 'sourceId'),
      currentGeneration: false,
    );
    if (source.truncated) {
      _invalid('Attach the complete backup before restoring it.');
    }
    final prepared = await backups.prepareJson(source.text);
    scope.checkActive();
    final before = _counts(_host.session.committedData);
    final after = _counts(prepared.value.appData);
    final plan = _external.prepare(
      scope: scope,
      action: 'backups.restore',
      arguments: {
        'request': _request(args),
        'sourceId': source.id,
        'sourceDigest': source.digest,
      },
      version: source.digest,
      changes: [
        ResourceChange(
          key: 'backup.restore',
          before: before,
          after: {
            ...after,
            'sourceDigest': source.digest,
            'replacesSchoolSites': prepared.value.includesSchoolSites,
            'preservesLocalAgentConfiguration': true,
          },
        ),
      ],
      operationId: _optionalText(args, 'operationId'),
      validate: () {
        if (!backups.isCurrent(prepared)) _conflict();
      },
      execute: (_) => run(scope, () async {
        final count = await backups.restorePrepared(prepared);
        return ExternalEffectResult(
          state: ExternalEffectState.applied,
          dataStatus: ExternalDataState.committed,
          details: {
            'restored': true,
            'restoredTimetables': count,
            'generation': _host.mutations.generation,
            'sourceDigest': source.digest,
            'localAgentConfigurationPreserved': true,
          },
        );
      }),
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<Map<String, Object?>> _prepareClear(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'operationId'});
    final replay = _recorded(args, scope, 'maintenance.clear');
    if (replay != null) return replay;
    final clear = _clearData, binding = _binding;
    if (clear == null) {
      _unsupported('The local-data clear workflow is unavailable.');
    }
    final plan = _external.prepare(
      scope: scope,
      action: 'maintenance.clear',
      arguments: {'request': _request(args), 'scope': 'allLocalData'},
      version: _host.mutations.generation,
      changes: [
        ResourceChange(
          key: 'application.localData',
          before: {
            'businessData': _counts(_host.session.committedData),
            'conversations': 'all',
            'credentials': 'all',
            'devicePreferences': 'all',
            'schoolSession': 'local',
          },
          after: null,
        ),
      ],
      operationId: _optionalText(args, 'operationId'),
      validate: () {
        if (_binding != binding || !identical(_clearData, clear)) _conflict();
      },
      execute: (_) => clear(scope),
    );
    return boundedToolReceipt(plan.summary());
  }

  Map<String, Object?> _workspaceSnapshot() {
    final data = _host.session.committedData;
    return {
      'supported': _workspaces != null,
      'active': data.activeMode.name,
      'workspaces': [
        for (final mode in AppMode.values)
          {'workspace': mode.name, 'enabled': data.isWorkspaceEnabled(mode)},
      ],
    };
  }

  Future<Map<String, Object?>> _prepareWorkspace(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'workspace', 'action', 'operationId'});
    final replay = _recorded(
      args,
      scope,
      'workspace.change',
      readBack: _readWorkspace,
    );
    if (replay != null) return replay;
    final service = _workspaces;
    if (service == null) _unsupported('Workspace commands are unavailable.');
    final mode = _mode(args['workspace']), action = _text(args, 'action');
    if (!{'enable', 'disable', 'switch'}.contains(action)) {
      _invalid('Unknown workspace action.');
    }
    final data = _host.session.committedData;
    if (action == 'switch' && !data.isWorkspaceEnabled(mode)) {
      _invalid('Enable the target workspace before switching to it.');
    }
    if (action == 'disable' &&
        data.isWorkspaceEnabled(mode) &&
        data.enabledWorkspaces.length == 1) {
      _invalid('At least one workspace must remain enabled.');
    }
    final plan = _external.prepare(
      scope: scope,
      action: 'workspace.change',
      arguments: {
        'request': _request(args),
        'workspace': mode.name,
        'action': action,
      },
      version: _workspaceSnapshot(),
      changes: [
        ResourceChange(
          key: 'workspace.${mode.name}',
          before: {
            'enabled': data.isWorkspaceEnabled(mode),
            'active': data.activeMode == mode,
          },
          after: action,
        ),
      ],
      operationId: _optionalText(args, 'operationId'),
      validate: () {},
      execute: (operation) async {
        if (action == 'switch') {
          await service.switchMode(mode);
        } else {
          await service.setEnabled(mode, action == 'enable');
        }
        return _readWorkspace(operation);
      },
      readBack: _readWorkspace,
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<ExternalEffectResult> _readWorkspace(
    ExternalOperationContext operation,
  ) async {
    final mode = _mode(operation.arguments['workspace']),
        data = _host.session.committedData;
    final action = operation.arguments['action'];
    final applied = action == 'switch'
        ? data.activeMode == mode
        : data.isWorkspaceEnabled(mode) == (action == 'enable');
    return ExternalEffectResult(
      state: applied
          ? ExternalEffectState.applied
          : ExternalEffectState.unknown,
      dataStatus: applied
          ? ExternalDataState.committed
          : ExternalDataState.unknown,
      details: {
        'observed': _workspaceSnapshot(),
        'requestedStateObserved': applied,
      },
    );
  }

  Map<String, Object?> _navigationSnapshot() {
    final data = _host.session.committedData;
    return {
      'supported': _navigation != null,
      'workspace': data.activeMode.name,
      'timetableId': data.studentMode.activeTimetableId,
      'calendarId': data.generalMode.activeScheduleId,
      'date': data.generalMode.selectedDateIso,
    };
  }

  Future<Map<String, Object?>> _prepareNavigation(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'workspace', 'ref', 'date', 'week', 'operationId'});
    final replay = _recorded(args, scope, 'navigation.open');
    if (replay != null) return replay;
    final navigate = _navigation, binding = _binding;
    if (navigate == null) _unsupported('No navigation host is attached.');
    final mode = _mode(args['workspace']);
    if (!_host.session.committedData.isWorkspaceEnabled(mode)) {
      _invalid('The requested workspace is disabled.');
    }
    ResourceRef? ref;
    if (args['ref'] != null) {
      final raw = _map(args['ref']);
      _keys(raw, {'kind', 'id', 'parentId'});
      final kind = ResourceKind.values
          .where((k) => k.name == raw['kind'])
          .firstOrNull;
      if (kind == null || kind == ResourceKind.occurrence) {
        _invalid('Navigate to the parent event/course and an explicit date.');
      }
      if ((mode == AppMode.student) !=
          {
            ResourceKind.timetable,
            ResourceKind.course,
            ResourceKind.periodTimeSet,
          }.contains(kind)) {
        _invalid('Resource and workspace do not match.');
      }
      ref = ResourceRef(
        kind: kind,
        id: _text(raw, 'id'),
        parentId: _optionalText(raw, 'parentId'),
      );
      ResourceQueries(
        snapshot: _host.session.committedData,
        datasetGeneration: _host.mutations.generation,
        snapshotRevision: 0,
      ).get(ref);
    }
    final date = args['date'] == null ? null : _date(args['date']);
    final week = args['week'] == null
        ? null
        : _integer(args, 'week', min: 1, max: 1000);
    if (mode == AppMode.general && week != null) {
      _invalid('Week navigation belongs to a timetable.');
    }
    if (ref == null && date == null && week == null) {
      _invalid('Choose an object, date or week.');
    }
    final target = AgentNavigationTarget(
      workspace: mode,
      ref: ref,
      date: date,
      week: week,
    );
    final plan = _external.prepare(
      scope: scope,
      action: 'navigation.open',
      arguments: {'request': _request(args), ...target.toJson()},
      version: _navigationSnapshot(),
      changes: [
        ResourceChange(
          key: 'navigation',
          before: _navigationSnapshot(),
          after: target.toJson(),
        ),
      ],
      operationId: _optionalText(args, 'operationId'),
      validate: () {
        if (_binding != binding || !identical(_navigation, navigate)) {
          _conflict();
        }
      },
      execute: (_) => navigate(target),
    );
    return boundedToolReceipt(plan.summary());
  }

  Future<Map<String, Object?>> _prepareDeveloperSample(
    Map<String, Object?> args,
    OperationScope scope,
    AgentApprovalRequester _,
  ) async {
    _keys(args, {'language', 'operationId'});
    final replay = _recorded(args, scope, 'developer.sample');
    if (replay != null) return replay;
    final language = DeveloperSampleLanguage.values
        .where((l) => l.name == args['language'])
        .firstOrNull;
    if (language == null) _invalid('Unknown sample language.');
    final action = _developerSample, binding = _binding;
    if (action == null) {
      _unsupported('Developer sample commands are unavailable.');
    }
    final plan = _external.prepare(
      scope: scope,
      action: 'developer.sample',
      arguments: {'request': _request(args), 'language': language.name},
      version: _host.mutations.generation,
      changes: [
        ResourceChange(
          key: 'developer.sample',
          before: _counts(_host.session.committedData),
          after: {
            'append': 'one sample timetable and three sample calendars in enabled workspaces',
            'language': language.name,
          },
        ),
      ],
      operationId: _optionalText(args, 'operationId'),
      validate: () {
        if (_binding != binding || !identical(_developerSample, action)) {
          _conflict();
        }
      },
      execute: (_) => action(language),
    );
    return boundedToolReceipt(plan.summary());
  }
}

Map<String, Object?> _counts(AppData data) => {
  'timetables': data.studentMode.timetables.length,
  'courses': data.studentMode.timetables.fold<int>(
    0,
    (n, t) => n + t.courses.length,
  ),
  'calendars': data.generalMode.schedules.length,
  'events': data.generalMode.schedules.fold<int>(
    0,
    (n, c) => n + c.events.length,
  ),
  'periodTimeSets': data.studentMode.periodTimeSets.length,
};
Map<String, Object?> _warning(GeneralCalendarIcsImportWarning warning) => {
  'code': warning.code.name,
  'message': warning.fallbackMessage,
  if (warning.eventUid != null) 'eventUid': warning.eventUid,
  if (warning.eventTitle != null) 'eventTitle': warning.eventTitle,
};
const _fileFormats = [
  'timetables_json',
  'schedules_json',
  'schedules_ics',
  'period_times_json',
];
const _format = {'type': 'string', 'enum': _fileFormats};
const _string = {'type': 'string'};
const _workspaceSchema = {
  'type': 'string',
  'enum': ['student', 'general'],
};
const _idsSchema = {
  'type': 'array',
  'items': _string,
  'minItems': 1,
  'maxItems': 512,
  'uniqueItems': true,
};
const _offsetSchema = {'type': 'integer', 'minimum': 0};
const _limitSchema = {'type': 'integer', 'minimum': 1, 'maximum': 100};
const _weekSchema = {'type': 'integer', 'minimum': 1, 'maximum': 1000};
const _setResetSchema = {
  'type': 'string',
  'enum': ['set', 'reset'],
};
Map<String, Object?> _request(Map<String, Object?> args) =>
    Map<String, Object?>.of(args)..remove('operationId');
void _keys(Map<String, Object?> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unknown argument.');
  }
}

String _text(Map<String, Object?> args, String key) {
  final value = _optionalText(args, key);
  if (value == null) _invalid('Missing $key.');
  return value;
}

String? _optionalText(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value.length > 4096) {
    _invalid('Invalid $key.');
  }
  return value;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    _invalid('Expected an object.');
  }
  return Map<String, Object?>.from(value);
}

List<String> _ids(Object? value, {bool required = true}) {
  if (value == null && !required) return const [];
  if (value is! List ||
      value.isEmpty ||
      value.length > 512 ||
      value.any((v) => v is! String || v.isEmpty || v.length > 2048) ||
      value.toSet().length != value.length) {
    _invalid('Select a nonempty bounded list of distinct resource IDs.');
  }
  return value.cast<String>();
}

void _requireIds(List<String> requested, Iterable<String> available) {
  final known = available.toSet();
  if (requested.isEmpty || requested.any((id) => !known.contains(id))) {
    _missingTarget();
  }
}

AppMode _mode(Object? value) =>
    AppMode.values.where((m) => m.name == value).firstOrNull ??
    (throw const OperationProblem(
      OperationErrorCode.invalidArgument,
      'Unknown workspace.',
    ));
int _integer(
  Map<String, Object?> args,
  String key, {
  int fallback = 0,
  int min = 0,
  int max = 100,
}) {
  final value = args[key] ?? fallback;
  if (value is! int || value < min || value > max) _invalid('Invalid $key.');
  return value;
}

DateTime _date(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    _invalid('Use a real YYYY-MM-DD date.');
  }
  final result = DateTime.tryParse(value);
  if (result == null ||
      result.year < 1 ||
      result.year > 9999 ||
      result.toIso8601String().substring(0, 10) != value) {
    _invalid('Invalid calendar date.');
  }
  return result;
}

Never _invalid(String message) =>
    throw OperationProblem(OperationErrorCode.invalidArgument, message);
Never _unsupported(String message) =>
    throw OperationProblem(OperationErrorCode.unsupported, message);
Never _expired(String message) =>
    throw OperationProblem(OperationErrorCode.expired, message);
Never _missingTarget() => throw const OperationProblem(
  OperationErrorCode.notFound,
  'One or more explicitly selected resources no longer exist.',
);
Never _conflict() => throw const OperationProblem(
  OperationErrorCode.conflict,
  'The source or host changed; prepare a new plan.',
);
