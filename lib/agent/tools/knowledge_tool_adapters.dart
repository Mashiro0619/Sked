import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../knowledge/knowledge_service.dart';
import '../provider/provider.dart';
import 'application_tool_host.dart';

KnowledgeToolAdapters registerKnowledgeTools(
  ApplicationToolHost host, {
  required ExternalOperationCoordinator external,
  required AgentKnowledgeService service,
  required void Function(String action, ExternalEffect readBack)
  registerReadBack,
}) => KnowledgeToolAdapters(
  host,
  external: external,
  service: service,
  registerReadBack: registerReadBack,
);

class KnowledgeToolAdapters {
  KnowledgeToolAdapters(
    this.host, {
    required this.external,
    required this.service,
    required void Function(String, ExternalEffect) registerReadBack,
  }) {
    for (final kind in KnowledgeKind.values) {
      final family = kind == KnowledgeKind.skill ? 'skills' : 'memories';
      final action = 'knowledge.$family';
      registerReadBack(action, _readBack);
      if (kind == KnowledgeKind.memory) {
        _add(
          'memories.search',
          'Find bounded shared memories. needsRecheck means query actual resources before acting; memories never grant permission.',
          {
            'query': _string,
            'offset': _integer,
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 24},
          },
          (args, _) async {
            _keys(args, {'query', 'offset', 'limit'});
            await service.initialize();
            final query = args.containsKey('query')
                ? knowledgeText(args['query'], empty: true)
                : '';
            final offset = knowledgeInteger(args['offset'] ?? 0),
                limit = knowledgeInteger(args['limit'] ?? 12, min: 1);
            if (limit > 24) knowledgeInvalid('Memory page is too large.');
            final matches = service.list(
              kind,
              query: query,
              includeDisabled: false,
            );
            final page = matches.skip(offset).take(limit).toList();
            return {
              'memories': page.map(_summary).toList(),
              'hasMore': offset + page.length < matches.length,
              'nextOffset': offset + page.length < matches.length
                  ? offset + page.length
                  : null,
            };
          },
        );
      }
      _add(
        '$family.get',
        'Read one shared ${kind.name} for review or editing, including its current revision. This never changes the current Skill snapshot.',
        {'id': _string},
        (args, _) async {
          _keys(args, {'id'});
          final record = await service.read(
            kind,
            knowledgeText(args['id'], max: 128),
          );
          return {
            ...record.toJson(),
            'needsRecheck': service.needsRecheck(record),
            if (kind == KnowledgeKind.skill)
              'missingTools': service.missingTools(record),
          };
        },
        required: ['id'],
      );
      _add(
        '$family.prepare',
        'Prepare creating, editing, deleting or enabling shared ${kind.name} content. Existing records require the exact revision from get. Built-in Skills can be disabled or restored, not deleted. Commit with external.commit under the current three-mode policy.',
        {
          'action': {
            'type': 'string',
            'enum': [
              'create',
              'update',
              'delete',
              'setEnabled',
              if (kind == KnowledgeKind.skill) 'restoreOriginal',
            ],
          },
          'id': _string,
          'revision': _integer,
          'title': _string,
          'summary': _string,
          'body': _string,
          'sourceNote': _string,
          'enabled': {'type': 'boolean'},
          if (kind == KnowledgeKind.skill) ...{
            'triggers': _strings,
            'requiredTools': _strings,
            'optionalTools': _strings,
          },
          'operationId': _string,
        },
        (args, scope) => _prepare(kind, action, args, scope),
        required: ['action'],
      );
    }
    registerReadBack('knowledge.undo', _readBack);
    _add(
      'knowledge.undo.prepare',
      'Prepare a conditional inverse of one locally recorded knowledge operation. A later edit blocks the whole inverse. Commit with external.commit.',
      {'targetOperationId': _string, 'operationId': _string},
      (args, scope) async {
        _keys(args, {'targetOperationId', 'operationId'});
        final request = _request(args);
        final operationId = knowledgeOptionalText(
          args['operationId'],
          max: 512,
        );
        final replay = external.prepareRecorded(
          scope: scope,
          action: 'knowledge.undo',
          request: request,
          operationId: operationId,
          readBack: _readBack,
        );
        if (replay != null) return replay.summary();
        await service.initialize();
        return _stage(
          service.repository.prepareInverse(
            knowledgeText(args['targetOperationId'], max: 512),
          ),
          'knowledge.undo',
          request,
          scope,
          operationId,
        );
      },
      required: ['targetOperationId'],
    );
    _add(
      'knowledge.changes.get',
      'Read the full before/after content of a pending knowledge proposal in this run, for review before approval.',
      {'proposalId': _string},
      (args, scope) async {
        _keys(args, {'proposalId'});
        final id = knowledgeText(args['proposalId'], max: 256);
        final proposal = _proposals[id];
        if (proposal == null || !identical(proposal.scope, scope)) {
          throw const OperationProblem(
            OperationErrorCode.expired,
            'The knowledge proposal is no longer available.',
          );
        }
        return {
          'proposalId': id,
          'changes': proposal.plan.changes
              .map((change) => change.toJson())
              .toList(),
        };
      },
      required: ['proposalId'],
    );
  }

  final ApplicationToolHost host;
  final ExternalOperationCoordinator external;
  final AgentKnowledgeService service;
  final _proposals =
      <String, ({OperationScope scope, KnowledgeChangeSet plan})>{};
  KnowledgeChangeSet? readProposal(String id) => _proposals[id]?.plan;
  void discardScope(OperationScope scope) =>
      _proposals.removeWhere((_, value) => identical(value.scope, scope));

  void _add(
    String name,
    String description,
    Map<String, Object?> properties,
    Future<Map<String, Object?>> Function(Map<String, Object?>, OperationScope)
    execute, {
    List<String> required = const [],
  }) {
    host.register(
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
      (args, scope, _) => _guard(() => execute(args, scope)),
    );
  }

  Future<Map<String, Object?>> _prepare(
    KnowledgeKind kind,
    String actionName,
    Map<String, Object?> args,
    OperationScope scope,
  ) async {
    final action = knowledgeText(args['action'], max: 32);
    final fields = {
      'title',
      'summary',
      'body',
      'sourceNote',
      if (kind == KnowledgeKind.skill) ...{
        'triggers',
        'requiredTools',
        'optionalTools',
      },
    };
    _keys(args, {
      'action',
      'operationId',
      if (action != 'create') ...{'id', 'revision'},
      if (action == 'create' || action == 'update') ...fields,
      if (action == 'setEnabled') 'enabled',
    });
    if (!{
      'create',
      'update',
      'delete',
      'setEnabled',
      if (kind == KnowledgeKind.skill) 'restoreOriginal',
    }.contains(action)) {
      knowledgeInvalid('Unknown knowledge action.');
    }
    final request = _request(args),
        operationId = knowledgeOptionalText(args['operationId'], max: 512);
    final replay = external.prepareRecorded(
      scope: scope,
      action: actionName,
      request: request,
      operationId: operationId,
      readBack: _readBack,
    );
    if (replay != null) return replay.summary();
    await service.initialize();
    scope.checkActive();
    KnowledgeRecord record;
    if (action == 'create') {
      record = service.newRecord(
        kind,
        title: knowledgeText(args['title'], max: 256),
        body: knowledgeText(args['body'], max: KnowledgeLimits.skillBytes),
      );
    } else {
      record = await service.read(kind, knowledgeText(args['id'], max: 128));
      if (record.revision != knowledgeInteger(args['revision'])) {
        throw const KnowledgeException(
          KnowledgeError.conflict,
          'The knowledge revision changed.',
        );
      }
    }
    KnowledgeChangeSet plan;
    if (action == 'delete') {
      plan = service.prepareDelete(record);
    } else if (action == 'restoreOriginal') {
      plan = service.prepareOriginal(record);
    } else if (action == 'setEnabled') {
      plan = service.prepareSave(
        record.copyWith(enabled: knowledgeBoolean(args['enabled'])),
      );
    } else {
      final json = record.toJson();
      for (final field in fields) {
        if (args.containsKey(field)) json[field] = args[field];
      }
      if (kind == KnowledgeKind.skill) json['usesOriginal'] = false;
      final conversation = host.conversationForScope(scope);
      json['sourceConversationId'] = conversation?.id;
      json['sourceMessageId'] = conversation?.messages
          .where((message) => message.role.name == 'user')
          .lastOrNull
          ?.id;
      plan = service.prepareSave(KnowledgeRecord.fromJson(json));
    }
    return _stage(plan, actionName, request, scope, operationId);
  }

  Map<String, Object?> _stage(
    KnowledgeChangeSet plan,
    String action,
    Map<String, Object?> request,
    OperationScope scope,
    String? operationId,
  ) {
    _proposals.removeWhere((_, entry) => entry.scope.isCancelled);
    if (_proposals.length >= 128) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Finish the existing knowledge proposals first.',
      );
    }
    final prepared = external.prepare(
      scope: scope,
      action: action,
      operationId: operationId,
      arguments: {
        'request': request,
        'proposalId': plan.id,
        'knowledgeDigest': plan.digest,
        'targets': plan.changes.map((change) => change.key).toList(),
      },
      version: {
        for (final change in plan.changes) change.key: change.expectedRevision,
      },
      changes: [
        for (final change in plan.changes)
          ResourceChange(
            key: 'knowledge.${change.key}',
            before: change.before?.toJson(),
            after: change.after?.toJson(),
          ),
      ],
      receiptChanges: [
        for (final change in plan.changes)
          ResourceChange(
            key: 'knowledge.${change.key}',
            before: change.before?.summaryJson(),
            after: change.after == null
                ? null
                : {...change.after!.summaryJson(), 'proposalId': plan.id},
          ),
      ],
      validate: () => _guardSync(() => service.repository.validate(plan)),
      execute: (operation) async {
        final policyRevision = scope.policy.revision;
        try {
          final receipt = await service.repository.commit(
            plan,
            operationId: operation.operationId,
            validateOwner: () {
              scope.checkActive();
              if (scope.policy.revision != policyRevision) {
                throw const OperationProblem(
                  OperationErrorCode.cancelled,
                  'Knowledge permission changed before writing.',
                );
              }
            },
          );
          return ExternalEffectResult(
            state: ExternalEffectState.applied,
            dataStatus: ExternalDataState.committed,
            details: receipt.referenceJson(),
          );
        } on KnowledgeException catch (error) {
          if (error.code == KnowledgeError.unknown) rethrow;
          return _notStarted(error.code.name);
        } on OperationProblem catch (error) {
          // Cancellation or a policy change while this write was still queued
          // is a confirmed refusal, not an unknown external effect.
          return _notStarted(error.code.name);
        }
      },
      readBack: _readBack,
    );
    _proposals[plan.id] = (scope: scope, plan: plan);
    return {
      ...prepared.summary(),
      'changes': [
        for (final change in plan.changes)
          {
            'key': 'knowledge.${change.key}',
            'before': change.before == null
                ? null
                : {
                    'key': change.key,
                    'revision': change.before!.revision,
                    'contentSha256': change.before!.contentSha256,
                  },
            'after': change.after == null
                ? null
                : {
                    'key': change.key,
                    'contentSha256': change.after!.contentSha256,
                  },
          },
      ],
      'proposalId': plan.id,
      'contentPreviewTool': 'knowledge.changes.get',
    };
  }

  Future<ExternalEffectResult> _readBack(
    ExternalOperationContext operation,
  ) async {
    if (!service.repository.isLoaded || service.repository.blocked) {
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        dataStatus: ExternalDataState.unknown,
      );
    }
    final receipt = service.repository.receiptFor(operation.operationId);
    if (receipt == null ||
        receipt.digest != operation.arguments['knowledgeDigest']) {
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        dataStatus: ExternalDataState.unknown,
      );
    }
    return ExternalEffectResult(
      state: ExternalEffectState.applied,
      dataStatus: ExternalDataState.committed,
      details: receipt.referenceJson(),
    );
  }

  Map<String, Object?> _summary(KnowledgeRecord record) => {
    ...record.summaryJson(),
    'needsRecheck': service.needsRecheck(record),
  };

  ExternalEffectResult _notStarted(String code) => ExternalEffectResult(
    state: ExternalEffectState.failed,
    dataStatus: ExternalDataState.unchanged,
    details: {'code': code, 'effectStarted': false},
  );
  Map<String, Object?> _request(Map<String, Object?> args) => {
    'digest': mutationDigest(
      Map<String, Object?>.of(args)..remove('operationId'),
    ),
  };
}

Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on KnowledgeException catch (error) {
    _rethrowKnowledge(error);
  }
}

T _guardSync<T>(T Function() action) {
  try {
    return action();
  } on KnowledgeException catch (error) {
    _rethrowKnowledge(error);
  }
}

Never _rethrowKnowledge(KnowledgeException error) =>
    throw OperationProblem(switch (error.code) {
      KnowledgeError.invalid ||
      KnowledgeError.limit => OperationErrorCode.invalidArgument,
      KnowledgeError.conflict => OperationErrorCode.conflict,
      KnowledgeError.duplicate => OperationErrorCode.duplicateMismatch,
      KnowledgeError.unknown => OperationErrorCode.outcomeUnknown,
      KnowledgeError.unavailable => OperationErrorCode.storageFailure,
    }, error.message);
void _keys(Map<String, Object?> args, Set<String> allowed) {
  if (args.keys.any((key) => !allowed.contains(key))) {
    knowledgeInvalid('Unexpected knowledge argument.');
  }
}

const _string = {'type': 'string'};
const _integer = {'type': 'integer', 'minimum': 0};
const _strings = {
  'type': 'array',
  'maxItems': 64,
  'uniqueItems': true,
  'items': _string,
};
