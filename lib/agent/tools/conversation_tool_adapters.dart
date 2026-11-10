import 'dart:async';
import 'dart:convert';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../../utils/unique_id.dart';
import '../bridge/conversation_projection.dart';
import '../bridge/generated/api/contracts.dart' as native;
import '../bridge/generated/api/models.dart' show ViewConversationState;
import '../bridge/rust_agent_ui_delegate.dart';
import '../bridge/rust_conversation_repository.dart';
import '../conversations/conversation_models.dart';
import '../provider/provider.dart';
import 'application_tool_host.dart';
import 'platform_tool_adapters.dart';
import 'workflow_tool_adapters.dart';

ConversationToolAdapters registerConversationTools(
  ApplicationToolHost host, {
  required ExternalOperationCoordinator external,
  required RustConversationRepository repository,
  required RustAgentUiDelegate runtime,
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
  final RustConversationRepository _repository;
  final RustAgentUiDelegate _runtime;
  final String Function() _id;
  final _pendingOperations = <String, Future<void>>{};
  final _pendingErrors = <String, Object>{};

  Future<void> waitForPendingOperations() async {
    while (_pendingOperations.isNotEmpty) {
      await Future.wait(_pendingOperations.values.toList());
    }
  }

  /// Each persisted field has an explicit management owner. Adding a model
  /// field requires updating this classification and the coverage assertion.
  static const fieldOwnership = <String, String>{
    'id': 'host_identity',
    'title': 'conversations.rename',
    'titleWasEdited': 'conversations.rename',
    'createdAt': 'host_identity',
    'updatedAt': 'host_persistence',
    'mode': 'user_permission_control',
    'status': 'runtime_lifecycle',
    'archived': 'conversations.archive',
    'pinned': 'user_history_organization',
    'titleGeneration': 'runtime_title_generation',
    'draft': 'user_input_queue',
    'connectionFingerprint': 'private_endpoint_binding',
    'runId': 'runtime_lifecycle',
    'modelSelection': 'user_model_selection',
    'pendingQuestion': 'runtime_user_interaction',
    'executionHistoryStart': 'host_history_execution_boundary',
    'messages': 'current_conversation_history_or_approved_export',
    'sources': 'current_conversation_sources_or_approved_export',
    'runs': 'runtime_usage_or_approved_export',
    'attachments': 'host_attachment_storage',
    'draftAttachmentIds': 'user_attachment_selection',
    'draftReferences': 'user_context_references',
    'turns': 'runtime_turn_ownership',
    'historyVersions': 'user_history_redo',
    'replyRevisions': 'user_reply_regeneration',
    'redoBatches': 'host_history_recovery',
    'queuedInputs': 'user_input_queue',
    'queuedControls': 'user_context_compaction_queue',
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
  Future<AgentArtifactWriteResult> exportConversation(
    String conversationId,
  ) async {
    final save = _saveArtifact, binding = _binding;
    if (save == null) _unsupported('No file destination picker is attached.');
    _requireConversation(conversationId);
    final target = await _repository.read(conversationId);
    if (_binding != binding || !identical(_saveArtifact, save)) _conflict();
    return save(_artifact(target));
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
        return {'fields': fieldOwnership};
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
        final offset = _integer(args, 'offset', 0, 0, null);
        final limit = _integer(args, 'limit', 20, 1, null);
        final end = (offset + limit).clamp(0, items.length);
        return {
          'conversations': await Future.wait(
            items
                .sublist(offset.clamp(0, items.length), end)
                .map((item) => _readSummary(item.id)),
          ),
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
        return _readSummary(_text(args, 'id'));
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
        'Apply ${entry.key} for an explicit conversation. Conversation permissions cannot be supplied or upgraded by this tool.',
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
        await _runtime.loadConversation(conversation.id);
        await _repository.refresh(conversation.id);
        return _describeRun(conversation.id);
      },
      required: ['conversationId'],
    );
    for (final action in ['stop', 'resume']) {
      final name = 'runs.$action';
      _add(
        name,
        'Apply $action for an existing conversation run; the current permission mode applies. Resume continues only existing input under that conversation\'s user-selected mode and never grants business write permission. Stop does not undo accepted writes.',
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
      final settings = _host.session.committedData.agentSettings;
      final mode = settings.permissionMode;
      final modelSelection = settings.defaultModelSelection;
      bool defaultsChanged() {
        final current = _host.session.committedData.agentSettings;
        return current.permissionMode != mode ||
            current.defaultModelSelection != modelSelection;
      }

      final plan = _external.prepare(
        scope: scope,
        action: action,
        operationId: operationId,
        arguments: {
          'request': request,
          'conversationId': id,
          'title': title,
          'mode': mode.name,
          'modelSelection': modelSelection?.toJson(),
        },
        version: {
          'mode': mode.name,
          'modelSelection': modelSelection?.toJson(),
        },
        changes: [
          ResourceChange(
            key: 'conversation.create',
            before: null,
            after: {
              'id': id,
              'title': title,
              'permissionMode': mode.name,
              'modelSelection': modelSelection?.toJson(),
            },
          ),
        ],
        validate: () {
          _requireStorage();
          if (_repository.find(id) != null || defaultsChanged()) {
            _conflict();
          }
        },
        execute: (_) async {
          final acceptedMode = scope.policy.mode;
          void checkQueuedCreate() {
            scope.checkActive();
            if (scope.policy.mode != acceptedMode || defaultsChanged()) {
              _conflict();
            }
          }

          checkQueuedCreate();
          final value = await _repository.createManagedConversation(
            title: title,
            mode: mode,
            modelSelection: modelSelection,
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
    _requireConversation(id);
    if (action == 'conversations.export') {
      final target = await _repository.read(id);
      scope.checkActive();
      return _prepareExport(target, request, scope, operationId);
    }
    final target = await _repository.refresh(id);
    scope.checkActive();
    final title = action == 'conversations.rename'
        ? _title(args)
        : target.title;
    final archived = action == 'conversations.archive'
        ? args['archived']
        : target.archived;
    if (archived is! bool) _invalid('archived must be a boolean.');
    if (action == 'runs.resume') {
      if (_isRunning(id)) {
        throw const OperationProblem(
          OperationErrorCode.busy,
          'The conversation already has a run.',
        );
      }
      if (target.archived) {
        _invalid('Restore the archived conversation before resuming it.');
      }
      if (!_repository.stateFor(id)!.hasExecutionUserInput) {
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
        if (action == 'runs.resume' && _isRunning(id)) _conflict();
      },
      execute: (operation) async {
        final acceptedMode = scope.policy.mode;
        final stopsCallingRun =
            _host.conversationForScope(scope)?.id == id &&
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
            checkQueuedTarget(_requireConversation(id));
            await _repository.rename(id, title);
          case 'conversations.archive':
            return _deferManagement(
              operation,
              () => _runtime.setArchived(id, archived),
            );
          case 'conversations.delete':
            return _deferManagement(
              operation,
              () => _repository.delete(id, validate: checkQueuedTarget),
            );
          case 'runs.stop':
            await _runtime.stop(id);
            return _applied({
              ..._describeRun(id),
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
    final args = operation.arguments;
    final id = args['conversationId'] as String;
    final result = await _repository.client.query(
      native.AgentQuery(
        kind: native.QueryKind.conversationState,
        conversationId: id,
      ),
    );
    final target = result.state == null
        ? null
        : conversationStateFromRust(result.state!);
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
        result.presentation?.active == false ||
            target.status == ConversationStatus.stopping,
      'runs.resume' =>
        (await _repository.client.query(
              native.AgentQuery(
                kind: native.QueryKind.run,
                conversationId: id,
                targetId: args['runId'] as String,
              ),
            )).run?.id ==
            args['runId'],
      _ => false,
    };
    return applied
        ? _applied({
            'conversation': _summary(
              target,
              active: result.presentation?.active,
              state: result.state,
            ),
            if (operation.action.startsWith('runs.'))
              'run': {
                'runId': target.runId,
                'active': result.presentation?.active,
                'canContinue': result.presentation?.canContinue,
                'queuedInputs': target.queuedInputs.length,
              },
          })
        : ExternalEffectResult(
            state: ExternalEffectState.unknown,
            details: {
              'code': 'conversationOutcomeUnknown',
              if (_pendingErrors[operation.operationId] case final error?)
                'message': error.toString(),
            },
          );
  }

  Future<Map<String, Object?>> _readSummary(String id) async {
    _requireConversation(id);
    await _runtime.loadConversation(id);
    final conversation = await _repository.refresh(id);
    return _summary(conversation);
  }

  Map<String, Object?> _summary(
    AgentConversation item, {
    bool? active,
    ViewConversationState? state,
  }) {
    final currentState = state ?? _repository.stateFor(item.id)!;
    return {
      'id': item.id,
      'title': item.title,
      'archived': item.archived,
      'status': item.status.name,
      'permissionMode': item.mode.name,
      'createdAt': item.createdAt.toUtc().toIso8601String(),
      'updatedAt': item.updatedAt.toUtc().toIso8601String(),
      'messageCount': currentState.messageCount,
      'sourceCount': currentState.sourceCount,
      'hasDraft': item.draft.isNotEmpty,
      'runActive': active ?? _isRunning(item.id),
      'usage': item.usageSummary ?? summarizeConversationUsage(item.runs),
    };
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
          'queuedInputs': value.queuedInputs
              .map((input) => input.toJson())
              .toList(),
          'draftAttachmentIds': value.draftAttachmentIds,
          'draftReferences': value.draftReferences
              .map((reference) => reference.toJson())
              .toList(),
          'managementContextDigest': _repository
              .stateFor(value.id)!
              .managementContextDigest,
        },
      });

  bool _isRunning(String id) => _runtime.state.value.runFor(id).isActive;

  Map<String, Object?> _describeRun(String id) {
    final conversation = _requireConversation(id);
    final run = _runtime.state.value.runFor(id);
    return {
      'conversationId': id,
      'runId': conversation.runId,
      'active': run.isActive,
      'status': conversation.status.name,
      'stopRequested': conversation.status == ConversationStatus.stopping,
      'queuedInputs': conversation.queuedInputs.length,
      'usage':
          conversation.usageSummary ??
          summarizeConversationUsage(conversation.runs),
    };
  }

  ExternalEffectResult _deferManagement(
    ExternalOperationContext operation,
    Future<void> Function() action,
  ) {
    final id = operation.operationId;
    _pendingOperations[id] ??= Future<void>.sync(action)
        .catchError((Object error) {
          _pendingErrors[id] = error;
        })
        .then<void>((_) async {
          try {
            await _external.reconcile(operationId: id, readBack: _readBack);
          } catch (error) {
            _pendingErrors[id] = error;
          }
        })
        .whenComplete(() {
          unawaited(_pendingOperations.remove(id));
        });
    return ExternalEffectResult(
      state: ExternalEffectState.pending,
      details: {
        'conversationId': operation.arguments['conversationId'],
        'accepted': true,
        'completed': false,
        'operationId': id,
      },
    );
  }

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
        'usage':
            conversation.usageSummary ??
            summarizeConversationUsage(conversation.runs),
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

ExternalEffectResult _applied(Map<String, Object?> details) =>
    ExternalEffectResult(state: ExternalEffectState.applied, details: details);
ExternalEffectResult _unknown() => ExternalEffectResult(
  state: ExternalEffectState.unknown,
  details: const {'code': 'conversationOutcomeUnknown'},
);
const _string = {'type': 'string'};
const _offset = {'type': 'integer', 'minimum': 0};
const _limit = {'type': 'integer', 'minimum': 1};
void _keys(Map<String, Object?> args, Set<String> allowed) {
  if (args.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unexpected tool argument.');
  }
}

String _text(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! String || value.trim().isEmpty) {
    _invalid('$key must be a nonempty string.');
  }
  return value;
}

String _title(Map<String, Object?> args) => _text(args, 'title').trim();
int _integer(
  Map<String, Object?> args,
  String key,
  int fallback,
  int min,
  int? max,
) {
  final value = args[key] ?? fallback;
  if (value is! int || value < min || max != null && value > max) {
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
