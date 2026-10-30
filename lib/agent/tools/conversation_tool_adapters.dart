import 'dart:convert';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../../utils/unique_id.dart';
import '../conversations/conversation_repository.dart';
import '../provider/provider.dart';
import '../runtime/agent_runtime_controller.dart';
import 'application_tool_host.dart';
import 'platform_tool_adapters.dart';
import 'workflow_tool_adapters.dart';

ConversationToolAdapters registerConversationTools(
  ApplicationToolHost host, {
  required ExternalOperationCoordinator external,
  required ConversationRepository repository,
  required AgentRuntimeController runtime,
  required PlatformToolAdapters platformTools,
  String Function()? idGenerator,
}) {
  final adapter = ConversationToolAdapters._(
    host,
    external,
    repository,
    runtime,
    idGenerator ?? generateUuidV4,
  );
  adapter._register(platformTools);
  return adapter;
}

/// Cross-conversation tools return metadata only. Body export always passes
/// through a host-selected file destination, never through a model response.
class ConversationToolAdapters {
  ConversationToolAdapters._(
    this._host,
    this._external,
    this._repository,
    this._runtime,
    this._id,
  );

  final ApplicationToolHost _host;
  final ExternalOperationCoordinator _external;
  final ConversationRepository _repository;
  final AgentRuntimeController _runtime;
  final String Function() _id;

  /// Each persisted field has an explicit management owner. Adding a model
  /// field requires updating this classification and the coverage assertion.
  static const fieldOwnership = <String, String>{
    'id': 'host_identity',
    'title': 'conversations.rename',
    'createdAt': 'host_identity',
    'updatedAt': 'host_persistence',
    'mode': 'user_permission_control',
    'status': 'runtime_lifecycle',
    'archived': 'conversations.archive',
    'draft': 'user_input_queue',
    'connectionFingerprint': 'private_endpoint_binding',
    'runId': 'runtime_lifecycle',
    'messages': 'current_conversation_history_or_approved_export',
    'sources': 'current_conversation_sources_or_approved_export',
    'runs': 'runtime_usage_or_approved_export',
  };
  Future<AgentArtifactWriteResult> Function(AgentDataArtifact)? _saveArtifact;
  int _binding = 0;

  void bindServices({
    Future<AgentArtifactWriteResult> Function(AgentDataArtifact)? saveArtifact,
  }) {
    _saveArtifact = saveArtifact;
    _binding++;
  }

  /// Direct UI export is a user-selected file operation, not an Agent grant.
  Future<AgentArtifactWriteResult> exportConversation(String conversationId) {
    final save = _saveArtifact;
    if (save == null) _unsupported('No file destination picker is attached.');
    return save(_artifact(_requireConversation(conversationId)));
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

  void _register(PlatformToolAdapters platform) {
    _add(
      'conversations.describe',
      'Describe conversation field ownership and supported semantic management actions. Identity, runtime state and user permission mode are never raw writable fields.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return {'fields': fieldOwnership, 'commitTool': 'external.commit'};
      },
    );
    _add(
      'conversations.list',
      'List bounded conversation metadata, including archived conversations when requested. This never loads another conversation body into the model.',
      {
        'state': {
          'type': 'string',
          'enum': ['active', 'archived', 'all'],
        },
        'offset': _offset,
        'limit': _limit,
      },
      (args, _, _) async {
        _keys(args, {'state', 'offset', 'limit'});
        _requireStorage();
        final filter = args['state'] ?? 'active';
        if (!const {'active', 'archived', 'all'}.contains(filter)) {
          _invalid('Unknown conversation state.');
        }
        final items =
            _repository.conversations
                .where(
                  (item) =>
                      filter == 'all' ||
                      item.archived == (filter == 'archived'),
                )
                .toList()
              ..sort((a, b) {
                final order = a.createdAt.compareTo(b.createdAt);
                return order == 0 ? a.id.compareTo(b.id) : order;
              });
        final offset = _integer(args, 'offset', 0, 0, items.length);
        final limit = _integer(args, 'limit', 20, 1, 50);
        final end = (offset + limit).clamp(0, items.length);
        return {
          'conversations': items.sublist(offset, end).map(_summary).toList(),
          'offset': offset,
          'total': items.length,
          'nextOffset': end < items.length ? end : null,
          'hasMore': end < items.length,
        };
      },
    );
    _add(
      'conversations.get',
      'Read metadata for an explicit conversation. Use the current-conversation history tools for body context or an approved export for another transcript.',
      {'id': _string},
      (args, _, _) async {
        _keys(args, {'id'});
        return _summary(_requireConversation(_text(args, 'id')));
      },
      required: ['id'],
    );

    for (final entry in {
      'create': {'title': _string},
      'rename': {'id': _string, 'title': _string},
      'delete': {'id': _string},
      'archive': {
        'id': _string,
        'archived': const {'type': 'boolean'},
      },
      'export': {'id': _string},
    }.entries) {
      final name = 'conversations.${entry.key}';
      _add(
        name,
        'Prepare ${entry.key} for an explicit conversation. Commit with external.commit under the current three-mode policy. Conversation permissions cannot be supplied or upgraded by this tool.',
        {...entry.value, 'operationId': _string},
        (args, scope, _) => _prepare(name, args, scope),
        required: entry.value.keys.toList(),
      );
      if (entry.key != 'export') platform.registerReadBack(name, _readBack);
    }
    _add(
      'runs.status',
      'Read actual runtime ownership, stored state, queued inputs and persisted usage for the latest run. Missing provider usage and monetary cost remain unknown; reported tokens are never a price quote.',
      {'conversationId': _string},
      (args, _, _) async {
        _keys(args, {'conversationId'});
        final conversation = _requireConversation(
          _text(args, 'conversationId'),
        );
        return _runtime.describeRun(conversation.id);
      },
      required: ['conversationId'],
    );
    for (final action in ['stop', 'resume']) {
      final name = 'runs.$action';
      _add(
        name,
        'Prepare $action for an existing conversation run; external.commit applies the current policy. Resume continues only existing input under that conversation\'s user-selected mode and never grants business write permission. Stop does not undo accepted writes.',
        {'conversationId': _string, 'operationId': _string},
        (args, scope, _) => _prepare(name, args, scope),
        required: ['conversationId'],
      );
      platform.registerReadBack(name, _readBack);
    }
  }

  Future<Map<String, Object?>> _prepare(
    String action,
    Map<String, Object?> args,
    OperationScope scope,
  ) async {
    final allowed = switch (action) {
      'conversations.create' => {'title', 'operationId'},
      'conversations.rename' => {'id', 'title', 'operationId'},
      'conversations.archive' => {'id', 'archived', 'operationId'},
      'runs.stop' || 'runs.resume' => {'conversationId', 'operationId'},
      _ => {'id', 'operationId'},
    };
    _keys(args, allowed);
    final request = Map<String, Object?>.of(args)..remove('operationId');
    final operationId = args['operationId'] == null
        ? null
        : _text(args, 'operationId');
    final recorded = _external.prepareRecorded(
      scope: scope,
      action: action,
      request: request,
      operationId: operationId,
      readBack: action == 'conversations.export' ? null : _readBack,
    );
    if (recorded != null) return recorded.summary();
    _requireStorage();
    if (action == 'conversations.create') {
      final title = _title(args), id = _id();
      final mode = _host.session.committedData.agentSettings.permissionMode;
      final plan = _external.prepare(
        scope: scope,
        action: action,
        operationId: operationId,
        arguments: {
          'request': request,
          'conversationId': id,
          'title': title,
          'mode': mode.name,
        },
        version: {'mode': mode.name},
        changes: [
          ResourceChange(
            key: 'conversation.create',
            before: null,
            after: {'id': id, 'title': title, 'permissionMode': mode.name},
          ),
        ],
        validate: () {
          _requireStorage();
          if (_repository.find(id) != null ||
              _host.session.committedData.agentSettings.permissionMode !=
                  mode) {
            _conflict();
          }
        },
        execute: (_) async {
          final acceptedMode = scope.policy.mode;
          void checkQueuedCreate() {
            scope.checkActive();
            if (scope.policy.mode != acceptedMode ||
                _host.session.committedData.agentSettings.permissionMode !=
                    mode) {
              _conflict();
            }
          }

          checkQueuedCreate();
          final value = await _repository.create(
            title: title,
            mode: mode,
            id: id,
            validate: checkQueuedCreate,
          );
          return _applied({'conversation': _summary(value), 'started': false});
        },
        readBack: _readBack,
      );
      return plan.summary();
    }
    final id = _text(
      args,
      action.startsWith('runs.') ? 'conversationId' : 'id',
    );
    final target = _requireConversation(id);
    if (action == 'conversations.export') {
      return _prepareExport(target, request, scope, operationId);
    }
    final title = action == 'conversations.rename'
        ? _title(args)
        : target.title;
    final archived = action == 'conversations.archive'
        ? args['archived']
        : target.archived;
    if (archived is! bool) _invalid('archived must be a boolean.');
    if (action == 'runs.resume') {
      if (_runtime.isRunning(id)) {
        throw const OperationProblem(
          OperationErrorCode.busy,
          'The conversation already has a run.',
        );
      }
      if (target.archived) {
        _invalid('Restore the archived conversation before resuming it.');
      }
      if (!target.messages.any(
        (message) => message.role == ConversationRole.user,
      )) {
        _invalid('Resume requires an existing user request.');
      }
    }
    final version = _targetVersion(target, action);
    final nextRunId = action == 'runs.resume' ? _id() : null;
    final arguments = <String, Object?>{
      'request': request,
      'conversationId': id,
      if (action == 'conversations.rename') 'title': title,
      if (action == 'conversations.archive') 'archived': archived,
      'runId': ?nextRunId,
      if (action.startsWith('runs.')) 'previousRunId': target.runId,
    };
    final after = switch (action) {
      'conversations.rename' => {..._summary(target), 'title': title},
      'conversations.archive' => {..._summary(target), 'archived': archived},
      'conversations.delete' => null,
      'runs.stop' => {'stopRequested': true, 'acceptedWritesMayFinish': true},
      'runs.resume' => {
        'runId': nextRunId,
        'permissionMode': target.mode.name,
        'existingInputOnly': true,
      },
      _ => throw StateError('Unregistered conversation action.'),
    };
    final plan = _external.prepare(
      scope: scope,
      action: action,
      operationId: operationId,
      arguments: arguments,
      version: version,
      changes: [
        ResourceChange(key: action, before: _summary(target), after: after),
      ],
      validate: () {
        final current = _requireConversation(id);
        if (_targetVersion(current, action) != version) _conflict();
        if (action == 'runs.resume' && _runtime.isRunning(id)) _conflict();
      },
      execute: (_) async {
        final acceptedMode = scope.policy.mode;
        final stopsCallingRun =
            _runtime.conversationForScope(scope)?.id == id &&
            (action == 'conversations.delete' ||
                action == 'conversations.archive' && archived);
        void checkQueuedTarget(AgentConversation current) {
          // Archiving/deleting the caller intentionally cancels that scope.
          // The already accepted metadata operation may finish, but no other
          // cancelled caller may introduce a later queued write.
          if (!stopsCallingRun) scope.checkActive();
          if (!scope.policy.enabled ||
              scope.policy.mode != acceptedMode ||
              _targetVersion(current, action) != version) {
            _conflict();
          }
        }

        scope.checkActive();
        checkQueuedTarget(_requireConversation(id));
        switch (action) {
          case 'conversations.rename':
            await _repository.update(id, (current) {
              checkQueuedTarget(current);
              return current.copyWith(title: title);
            });
          case 'conversations.archive':
            await _runtime.setArchived(
              id,
              archived,
              validate: checkQueuedTarget,
            );
          case 'conversations.delete':
            // Never await a run from inside this serial external effect: it
            // may be waiting for another effect queued behind this one.
            await _runtime.deleteConversation(id, validate: checkQueuedTarget);
            return _applied({
              'conversationId': id,
              'deleted': _repository.find(id) == null,
              'operationReceiptsRetained': true,
              'acceptedWritesMayFinish': true,
            });
          case 'runs.stop':
            await _runtime.stop(id);
            return _applied({
              ..._runtime.describeRun(id),
              'stopRequested': true,
              'acceptedWritesMayFinish': true,
            });
          case 'runs.resume':
            final runId = await _runtime.requestResume(id, runId: nextRunId!);
            return _applied({
              'conversationId': id,
              'runId': runId,
              'accepted': true,
              'completed': false,
              'permissionMode': target.mode.name,
            });
        }
        return _applied({'conversation': _summary(_requireConversation(id))});
      },
      readBack: _readBack,
    );
    return plan.summary();
  }

  Map<String, Object?> _prepareExport(
    AgentConversation target,
    Map<String, Object?> request,
    OperationScope scope,
    String? operationId,
  ) {
    final artifact = _artifact(target),
        save = _saveArtifact,
        binding = _binding;
    if (save == null) _unsupported('No file destination picker is attached.');
    final plan = _external.prepare(
      scope: scope,
      action: 'conversations.export',
      operationId: operationId,
      arguments: {
        'request': request,
        'conversationId': target.id,
        ...artifact.summary(),
      },
      version: artifact.digest,
      changes: [
        ResourceChange(
          key: 'conversation.export',
          before: null,
          after: {
            ...artifact.summary(),
            'snapshotAt': target.updatedAt.toUtc().toIso8601String(),
          },
        ),
      ],
      validate: () {
        _requireConversation(target.id);
        if (_binding != binding || !identical(_saveArtifact, save)) _conflict();
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
    return plan.summary();
  }

  Future<ExternalEffectResult> _readBack(
    ExternalOperationContext operation,
  ) async {
    if (!_repository.canWrite) return _unknown();
    final args = operation.arguments;
    final id = args['conversationId'] as String;
    final target = _repository.find(id);
    if (operation.action == 'conversations.delete') {
      return target == null
          ? _applied({
              'conversationId': id,
              'deleted': true,
              'operationReceiptsRetained': true,
            })
          : _unknown();
    }
    if (target == null) return _unknown();
    final applied = switch (operation.action) {
      'conversations.create' => true,
      'conversations.rename' => target.title == args['title'],
      'conversations.archive' => target.archived == args['archived'],
      'runs.stop' =>
        !_runtime.isRunning(id) ||
            _runtime.describeRun(id)['stopRequested'] == true,
      'runs.resume' => target.runId == args['runId'],
      _ => false,
    };
    return applied
        ? _applied({
            'conversation': _summary(target),
            if (operation.action.startsWith('runs.'))
              'run': _runtime.describeRun(id),
          })
        : _unknown();
  }

  Map<String, Object?> _summary(AgentConversation item) => {
    'id': item.id,
    'title': item.title,
    'archived': item.archived,
    'status': item.status.name,
    'permissionMode': item.mode.name,
    'createdAt': item.createdAt.toUtc().toIso8601String(),
    'updatedAt': item.updatedAt.toUtc().toIso8601String(),
    'messageCount': item.messages.length,
    'sourceCount': item.sources.length,
    'hasDraft': item.draft.isNotEmpty,
    'runActive': _runtime.isRunning(item.id),
    'usage': summarizeConversationUsage(item.runs),
  };

  AgentDataArtifact _artifact(
    AgentConversation conversation,
  ) => AgentDataArtifact(
    id: _id(),
    name: 'sked-conversation.json',
    mimeType: 'application/json',
    text: jsonEncode({
      'format': 'sked-conversation-transcript',
      'version': 1,
      'restorable': false,
      'conversation': {
        'id': conversation.id,
        'title': conversation.title,
        'createdAt': conversation.createdAt.toUtc().toIso8601String(),
        'updatedAt': conversation.updatedAt.toUtc().toIso8601String(),
        'archived': conversation.archived,
        'draft': conversation.draft,
        'messages': conversation.messages.map((item) => item.toJson()).toList(),
        'sources': conversation.sources.map((item) => item.toJson()).toList(),
        'runs': conversation.runs.map((item) => item.toJson()).toList(),
        'usage': summarizeConversationUsage(conversation.runs),
      },
    }),
  );

  AgentConversation _requireConversation(String id) {
    _requireStorage();
    final result = _repository.find(id);
    if (result == null) {
      throw const OperationProblem(
        OperationErrorCode.notFound,
        'Conversation does not exist.',
      );
    }
    return result;
  }

  void _requireStorage() {
    if (!_repository.canWrite) {
      throw const OperationProblem(
        OperationErrorCode.storageFailure,
        'Load or recover conversation storage before managing conversations.',
      );
    }
  }
}

String _targetVersion(AgentConversation value, String action) =>
    mutationDigest({
      'id': value.id,
      'createdAt': value.createdAt.toUtc().toIso8601String(),
      'title': value.title,
      'archived': value.archived,
      if (action != 'conversations.rename') ...{
        'mode': value.mode.name,
        'runId': value.runId,
        'draft': value.draft,
        'inputs': value.messages
            .where(
              (item) =>
                  item.role == ConversationRole.user ||
                  item.role == ConversationRole.notice,
            )
            .map((item) => item.toJson())
            .toList(),
        'sources': value.sources.map((item) => item.digest).toList(),
      },
    });
ExternalEffectResult _applied(Map<String, Object?> details) =>
    ExternalEffectResult(state: ExternalEffectState.applied, details: details);
ExternalEffectResult _unknown() => ExternalEffectResult(
  state: ExternalEffectState.unknown,
  details: const {'code': 'conversationOutcomeUnknown'},
);
const _string = {'type': 'string'};
const _offset = {'type': 'integer', 'minimum': 0};
const _limit = {'type': 'integer', 'minimum': 1, 'maximum': 50};
void _keys(Map<String, Object?> args, Set<String> allowed) {
  if (args.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unexpected tool argument.');
  }
}

String _text(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    _invalid('$key must be a bounded nonempty string.');
  }
  return value;
}

String _title(Map<String, Object?> args) => _text(args, 'title').trim();
int _integer(
  Map<String, Object?> args,
  String key,
  int fallback,
  int min,
  int max,
) {
  final value = args[key] ?? fallback;
  if (value is! int || value < min || value > max) {
    _invalid('$key is outside its bounds.');
  }
  return value;
}

Never _invalid(String message) =>
    throw OperationProblem(OperationErrorCode.invalidArgument, message);
Never _unsupported(String message) =>
    throw OperationProblem(OperationErrorCode.unsupported, message);
Never _conflict() => throw const OperationProblem(
  OperationErrorCode.conflict,
  'The conversation changed after preparation; prepare the action again.',
);
