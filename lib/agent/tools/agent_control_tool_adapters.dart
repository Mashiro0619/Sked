import 'dart:async';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../../utils/unique_id.dart';
import '../connection/agent_connection_manager.dart';
import '../connection/agent_connection_diagnostics.dart';
import '../connection/agent_endpoint.dart';
import '../provider/provider.dart';
import 'application_tool_host.dart';
import 'platform_tool_adapters.dart';

/// Host-only input. It has no JSON representation and clears its reference
/// after consumption or cancellation; only the connection writer sees its key.
class AgentCredentialInput {
  AgentCredentialInput(String value) : _value = value;
  String? _value;
  String? take() {
    final value = _value;
    _value = null;
    return value;
  }

  void discard() => _value = null;
}

typedef AgentConnectionWriter = Future<void> Function(
  OperationScope scope,
  AgentSettings settings, {
  required AgentCredentialAction credentialAction,
  String? rawKey,
});
typedef AgentCredentialInputRequester = Future<AgentCredentialInput?> Function(
  Uri endpoint,
);

class _InputHandle {
  const _InputHandle(this.input, this.scope, this.endpoint, this.createdAt);
  final AgentCredentialInput input;
  final OperationScope scope;
  final String endpoint;
  final DateTime createdAt;
}

/// Controls the single shared connection. Secret input, permission selection,
/// and the running request snapshot remain owned by the application host.
class AgentControlToolAdapters {
  AgentControlToolAdapters({
    required this._host,
    required this._external,
    required this._connections,
    required this._configure,
    required PlatformToolAdapters platformTools,
    this._diagnostics,
    Future<String> Function(AgentSettings)? readKey,
    DateTime Function()? clock,
  }) : _readKey = readKey ?? _connections.readKeyFor,
       _clock = clock ?? DateTime.now {
    platformTools.registerReadBack('agent.connection', _readBack);
    _register();
  }

  final ApplicationToolHost _host;
  final ExternalOperationCoordinator _external;
  final AgentConnectionManager _connections;
  final AgentConnectionWriter _configure;
  final AgentConnectionDiagnostics? _diagnostics;
  final Future<String> Function(AgentSettings) _readKey;
  final DateTime Function() _clock;
  final _inputs = <String, _InputHandle>{};
  AgentCredentialInputRequester? _requestInput;
  int _binding = 0;
  static const inputLifetime = Duration(minutes: 15);

  void bindCredentialInput(AgentCredentialInputRequester? request) {
    for (final input in _inputs.values) {
      input.input.discard();
    }
    _inputs.clear();
    _requestInput = request;
    _binding++;
  }

  void discardScope(OperationScope scope) {
    _inputs.removeWhere((_, value) {
      if (!identical(value.scope, scope)) return false;
      value.input.discard();
      return true;
    });
  }

  void dispose() => bindCredentialInput(null);

  void _add(
    String name,
    String description,
    Map<String, Object?> properties,
    ApplicationToolAction execute, {
    List<String> required = const [],
  }) {
    _host.register(
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
      execute,
    );
  }

  void _register() {
    _registerDiagnostics();
    _add(
      'connection.describe',
      'Read the single shared Agent connection and its supported fields. Credential values, references and URL query data are never returned. Permission mode is host-only.',
      const {},
      (args, _, _) async {
        _keys(args, {});
        return {
          ..._publicConnection(_host.session.committedData.agentSettings),
          'protocols': AgentModelProtocol.values
              .map((value) => value.name)
              .toList(),
          'writableFields': ['protocol', 'endpoint', 'model', 'models'],
          'reasoningEfforts': AgentReasoningEffort.values
              .map((value) => value.name)
              .toList(),
          'credentialActions': ['keep', 'replace', 'clear'],
          'inputAvailable': _requestInput != null,
          'initialized': _connections.status.initialized,
          'needsRecovery': _connections.status.needsRecovery,
          'credentialAvailable': _connections.status.credentialAvailable,
          'credentialStorage': _connections.status.storageKind.name,
          'multipleSavedConnections': false,
          'defaults': _publicConnection(const AgentSettings()),
        };
      },
    );
    _add(
      'credentials.request_input',
      'Request secure host input for an exact endpoint. The result is a short-lived handle bound to this run and destination. This does not configure the connection and never returns a key. Plan mode does not open the input.',
      {'endpoint': _string},
      (args, scope, _) async {
        _keys(args, {'endpoint'});
        if (scope.policy.mode == AgentPermissionMode.plan) {
          throw const OperationProblem(
            OperationErrorCode.readOnly,
            'Plan mode does not request credential input.',
          );
        }
        final endpoint = _endpoint(_text(args, 'endpoint'));
        final request = _requestInput;
        if (request == null) {
          throw const OperationProblem(
            OperationErrorCode.unsupported,
            'No secure credential input is attached.',
          );
        }
        _pruneInputs();
        if (_inputs.length >= 4) {
          throw const OperationProblem(
            OperationErrorCode.busy,
            'Finish or discard a pending credential change first.',
          );
        }
        final binding = _binding;
        final input = await request(Uri.parse(endpoint));
        if (input == null) {
          throw const OperationProblem(
            OperationErrorCode.cancelled,
            'Credential input was cancelled.',
          );
        }
        try {
          scope.checkActive();
          if (_binding != binding ||
              scope.policy.mode == AgentPermissionMode.plan) {
            throw const OperationProblem(
              OperationErrorCode.cancelled,
              'The credential input is no longer active.',
            );
          }
          final id = generateUuidV4();
          _inputs[id] = _InputHandle(input, scope, endpoint, _clock().toUtc());
          unawaited(scope.whenCancelled.then((_) => discardScope(scope)));
          return {
            'credentialHandle': id,
            'endpoint': _publicEndpoint(endpoint),
            'expiresInSeconds': inputLifetime.inSeconds,
            'configured': false,
          };
        } catch (_) {
          input.discard();
          rethrow;
        }
      },
      required: ['endpoint'],
    );
    _add(
      'connection.prepare',
      'Prepare updating or resetting the shared connection; commit with external.commit. The model field is the default ID; models enables IDs with their selected reasoning levels. Automatic omits the parameter. Replacement requires a credential handle from this run and endpoint. Keeping a credential while changing destination is rejected. Model-list edits apply to future runs; changing the endpoint or credential stops old requests.',
      {
        'action': {
          'type': 'string',
          'enum': ['set', 'reset'],
        },
        'protocol': {
          'type': 'string',
          'enum': AgentModelProtocol.values.map((value) => value.name).toList(),
        },
        'endpoint': _string,
        'model': _string,
        'models': {
          'type': 'array',
          'maxItems': 256,
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string', 'minLength': 1, 'maxLength': 256},
              'reasoningEfforts': {
                'type': 'array',
                'minItems': 1,
                'uniqueItems': true,
                'items': {
                  'type': 'string',
                  'enum': AgentReasoningEffort.values
                      .map((value) => value.name)
                      .toList(),
                },
                'description': 'Include auto; enable only levels supported by the service.',
              },
              'defaultReasoningEffort': {
                'type': 'string',
                'enum': AgentReasoningEffort.values
                    .map((value) => value.name)
                    .toList(),
              },
            },
            'required': ['id', 'reasoningEfforts', 'defaultReasoningEffort'],
            'additionalProperties': false,
          },
        },
        'credentialAction': {
          'type': 'string',
          'enum': ['keep', 'replace', 'clear'],
        },
        'credentialHandle': _string,
        'operationId': _string,
      },
      (args, scope, _) async {
        _keys(args, {
          'action',
          'protocol',
          'endpoint',
          'model',
          'models',
          'credentialAction',
          'credentialHandle',
          'operationId',
        });
        final request = _requestFingerprint(args);
        final operationId = _optionalText(args, 'operationId');
        final replay = _external.prepareRecorded(
          scope: scope,
          action: 'agent.connection',
          request: request,
          operationId: operationId,
          readBack: _readBack,
        );
        if (replay != null) return boundedToolReceipt(replay.summary());
        final before = _host.session.committedData.agentSettings;
        final action = _text(args, 'action');
        if (!{'set', 'reset'}.contains(action)) {
          _invalid('Unknown connection action.');
        }
        if (action == 'reset' &&
            args.keys.any((key) => !{'action', 'operationId'}.contains(key))) {
          _invalid(
            'Reset does not accept connection fields or credential actions.',
          );
        }
        final credentialAction = action == 'reset'
            ? AgentCredentialAction.clear
            : AgentCredentialAction.values
                  .where(
                    (value) =>
                        value.name == (args['credentialAction'] ?? 'keep'),
                  )
                  .firstOrNull;
        if (credentialAction == null) _invalid('Unknown credential action.');
        final protocol = action == 'reset'
            ? AgentModelProtocol.chatCompletions
            : args['protocol'] == null
            ? before.protocol
            : AgentModelProtocol.values
                  .where((value) => value.name == args['protocol'])
                  .firstOrNull;
        if (protocol == null) _invalid('Unknown model protocol.');
        List<AgentModelConfig>? models;
        if (action == 'reset') {
          models = const [];
        } else if (args.containsKey('models')) {
          final raw = args['models'];
          if (raw is! List || raw.length > 256) {
            _invalid('Invalid enabled model list.');
          }
          try {
            models = raw.map(AgentModelConfig.fromJson).toList();
          } on FormatException {
            _invalid(
              'Model IDs, reasoning levels, or their defaults are invalid.',
            );
          }
        }
        late final AgentSettings desired;
        try {
          desired = before.copyWith(
            protocol: protocol,
            endpoint: action == 'reset'
                ? ''
                : args.containsKey('endpoint')
                ? _endpoint(_text(args, 'endpoint'))
                : before.endpoint,
            model: action == 'reset'
                ? ''
                : args.containsKey('model')
                ? _text(args, 'model')
                : models?.isEmpty == true
                ? ''
                : before.model,
            models: models,
          );
        } on FormatException {
          _invalid(
            'The default model must be enabled with valid thinking levels.',
          );
        }
        final endpoint = normalizeAgentEndpoint(desired.endpoint);
        if (credentialAction == AgentCredentialAction.keep &&
            before.credentialRef != null &&
            endpoint != normalizeAgentEndpoint(before.endpoint)) {
          _invalid(
            'Changing a credential destination requires replacement or clearing.',
          );
        }
        final handleId = _optionalText(args, 'credentialHandle');
        if ((credentialAction == AgentCredentialAction.replace) !=
            (handleId != null)) {
          _invalid(
            'Replacement requires a credential handle; keep and clear do not accept one.',
          );
        }
        _pruneInputs();
        final handle = handleId == null ? null : _inputs[handleId];
        if (handleId != null &&
            (handle == null ||
                !identical(handle.scope, scope) ||
                handle.endpoint != endpoint)) {
          throw const OperationProblem(
            OperationErrorCode.expired,
            'The credential handle does not belong to this run and endpoint.',
          );
        }
        final baseline = _identity(before), binding = _binding;
        final plan = _external.prepare(
          scope: scope,
          action: 'agent.connection',
          arguments: {
            'request': request,
            'expectedConfiguration': _configuration(desired),
            'credentialAction': credentialAction.name,
            'previousCredential': mutationDigest(before.credentialRef),
          },
          version: baseline,
          changes: [
            ResourceChange(
              key: 'agent.connection',
              before: _publicConnection(before),
              after: {
                ..._publicConnection(desired),
                'credentialConfigured':
                    credentialAction == AgentCredentialAction.clear
                    ? false
                    : credentialAction == AgentCredentialAction.replace
                    ? true
                    : before.credentialRef != null,
                'credentialAction': credentialAction.name,
              },
            ),
          ],
          operationId: operationId,
          validate: () {
            if (_identity(_host.session.committedData.agentSettings) !=
                baseline) {
              _conflict();
            }
            if (handle != null &&
                (_binding != binding ||
                    !identical(_inputs[handleId], handle) ||
                    _clock().toUtc().difference(handle.createdAt) >
                        inputLifetime)) {
              _conflict();
            }
          },
          execute: (operation) async {
            String? key;
            try {
              if (handle != null) {
                key = handle.input.take();
                _inputs.remove(handleId);
                if (key == null) {
                  return ExternalEffectResult(
                    state: ExternalEffectState.failed,
                    details: const {'code': 'credentialInputUnavailable'},
                  );
                }
              }
              await _configure(
                scope,
                desired,
                credentialAction: credentialAction,
                rawKey: key,
              );
              return await _readBack(operation);
            } on AgentConnectionException catch (error) {
              return ExternalEffectResult(
                state: error.settingsMayHaveCommitted
                    ? ExternalEffectState.unknown
                    : ExternalEffectState.failed,
                dataStatus: error.settingsMayHaveCommitted
                    ? ExternalDataState.unknown
                    : ExternalDataState.unchanged,
                details: {'code': error.code.name},
              );
            } finally {
              key = null;
              handle?.input.discard();
            }
          },
          readBack: _readBack,
        );
        return boundedToolReceipt(plan.summary());
      },
      required: ['action'],
    );
  }

  void _registerDiagnostics() {
    for (final kind in ['test', 'models']) {
      _add(
        'connection.$kind.prepare',
        kind == 'test'
            ? 'Prepare a tiny synthetic connection and tool-call test. No conversation or business data is sent. Commit with external.commit under the current permission mode.'
            : 'Prepare fetching model IDs once from the configured API. A custom catalog URL must have the same origin. Commit with external.commit, then page the saved result with connection.models.get.',
        {
          'operationId': _string,
          if (kind == 'models') 'modelsEndpoint': _string,
        },
        (args, scope, _) async {
          _keys(args, {'operationId', if (kind == 'models') 'modelsEndpoint'});
          final action = 'agent.connection.$kind';
          final request = _requestFingerprint(args);
          final operationId = _optionalText(args, 'operationId');
          final replay = _external.prepareRecorded(
            scope: scope,
            action: action,
            request: request,
            operationId: operationId,
          );
          if (replay != null) return boundedToolReceipt(replay.summary());
          final service = _diagnostics;
          if (service == null) {
            throw const OperationProblem(
              OperationErrorCode.unsupported,
              'Connection diagnostics are unavailable.',
            );
          }
          final snapshot = _host.session.committedData.agentSettings;
          if (snapshot.endpoint.isEmpty ||
              (kind == 'test' && snapshot.model.isEmpty)) {
            _invalid('Configure the model connection before testing it.');
          }
          final explicit = _optionalText(args, 'modelsEndpoint');
          final resolved = resolveConfiguredAgentEndpoint(snapshot);
          late final Uri destination;
          try {
            destination = kind == 'test'
                ? resolved
                : AgentConnectionDiagnostics.modelsEndpoint(
                    resolved,
                    explicit: explicit == null ? null : Uri.parse(explicit),
                  );
          } on AgentConnectionDiagnosticException {
            throw const OperationProblem(
              OperationErrorCode.unsupported,
              'This endpoint needs an explicit same-origin model catalog URL.',
            );
          } on ProviderException {
            _invalid(
              'The model catalog destination must use the configured API origin.',
            );
          }
          final baseline = _identity(snapshot);
          final plan = _external.prepare(
            scope: scope,
            action: action,
            arguments: {
              'request': request,
              'configuration': _configuration(snapshot),
            },
            version: baseline,
            changes: [
              ResourceChange(
                key: 'agent.connection.$kind',
                before: null,
                after: {
                  'connection': _publicConnection(snapshot),
                  'destination': _publicEndpoint(destination.toString()),
                  'request': kind == 'test'
                      ? 'syntheticToolProbe'
                      : 'modelCatalog',
                  'businessDataSent': false,
                  if (explicit != null)
                    'modelsEndpoint': _publicEndpoint(explicit),
                },
              ),
            ],
            operationId: operationId,
            validate: () {
              if (_identity(_host.session.committedData.agentSettings) !=
                  baseline) {
                _conflict();
              }
            },
            execute: (_) async {
              final policyRevision = scope.policy.revision;
              final cancellation = ProviderCancellationToken();
              unawaited(scope.whenCancelled.then((_) => cancellation.cancel()));
              String key = '';
              try {
                key = await _readKey(snapshot);
                scope.checkActive();
                if (scope.policy.revision != policyRevision ||
                    _identity(_host.session.committedData.agentSettings) !=
                        baseline) {
                  return ExternalEffectResult(
                    state: ExternalEffectState.failed,
                    details: const {
                      'code': 'requestSnapshotChanged',
                      'requestStarted': false,
                    },
                  );
                }
                final Map<String, Object?> details;
                if (kind == 'test') {
                  details = (await service.probe(
                    snapshot,
                    apiKey: key,
                    allowInsecureHttp: true,
                    cancellation: cancellation,
                  )).toJson();
                } else {
                  final catalog = await service.listModels(
                    snapshot,
                    apiKey: key,
                    explicitEndpoint: explicit == null
                        ? null
                        : Uri.parse(explicit),
                    allowInsecureHttp: true,
                    cancellation: cancellation,
                  );
                  details = {
                    ...catalog.toJson(),
                    'count': catalog.models.length,
                    'pageTool': 'connection.models.get',
                    'businessDataSent': false,
                  };
                }
                return ExternalEffectResult(
                  state: ExternalEffectState.applied,
                  details: details,
                );
              } on AgentConnectionDiagnosticException catch (error) {
                return ExternalEffectResult(
                  state: ExternalEffectState.failed,
                  details: {
                    'code': error.code.name,
                    'transportConnected': false,
                  },
                );
              } on ProviderException catch (error) {
                return ExternalEffectResult(
                  state: switch (error.code) {
                    ProviderError.cancelled ||
                    ProviderError.timeout ||
                    ProviderError.transportFailure =>
                      ExternalEffectState.unknown,
                    _ => ExternalEffectState.failed,
                  },
                  details: {
                    'code': error.code.name,
                    'transportConnected': false,
                  },
                );
              } on AgentConnectionException catch (error) {
                return ExternalEffectResult(
                  state: ExternalEffectState.failed,
                  details: {'code': error.code.name, 'requestStarted': false},
                );
              } on OperationProblem catch (error) {
                return ExternalEffectResult(
                  state: ExternalEffectState.failed,
                  details: {'code': error.code.name, 'requestStarted': false},
                );
              } finally {
                key = '';
              }
            },
          );
          return boundedToolReceipt(plan.summary());
        },
      );
    }
    _add(
      'connection.models.get',
      'Page a previously saved model catalog by operationId without making another API request. This is available in plan mode too.',
      {
        'operationId': _string,
        'offset': {'type': 'integer', 'minimum': 0},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
      },
      (args, _, _) async {
        _keys(args, {'operationId', 'offset', 'limit'});
        final receipt = _external.status(_text(args, 'operationId'));
        if (receipt == null ||
            receipt.result['action'] != 'agent.connection.models') {
          throw const OperationProblem(
            OperationErrorCode.notFound,
            'No model-catalog receipt exists for this operation.',
          );
        }
        final result = receipt.result['effectResult'] as Map<String, Object?>;
        final models = result['models'];
        if (models is! List) {
          return {
            'status': receipt.result['effectStatus'],
            'models': const [],
            'hasMore': false,
            'complete': false,
          };
        }
        final offset = args['offset'] ?? 0, limit = args['limit'] ?? 50;
        if (offset is! int ||
            offset < 0 ||
            limit is! int ||
            limit < 1 ||
            limit > 50) {
          _invalid('Model catalog pagination is outside its supported range.');
        }
        return {
          'models': models.skip(offset).take(limit).toList(),
          'count': models.length,
          'hasMore': offset + limit < models.length,
          'nextOffset': offset + limit < models.length ? offset + limit : null,
          'complete': result['complete'] == true,
        };
      },
      required: ['operationId'],
    );
  }

  Future<ExternalEffectResult> _readBack(
    ExternalOperationContext operation,
  ) async {
    final current = _host.session.committedData.agentSettings;
    final status = _connections.status;
    final credential = switch (operation.arguments['credentialAction']) {
      'clear' => current.credentialRef == null && !status.credentialAvailable,
      'keep' =>
        mutationDigest(current.credentialRef) ==
            operation.arguments['previousCredential'],
      'replace' =>
        status.credentialAvailable &&
            mutationDigest(current.credentialRef) !=
                operation.arguments['previousCredential'],
      _ => false,
    };
    final applied =
        status.initialized &&
        !status.needsRecovery &&
        credential &&
        (_configuration(current) ==
                operation.arguments['expectedConfiguration'] ||
            _configuration(current, legacy: true) ==
                operation.arguments['expectedConfiguration']);
    return ExternalEffectResult(
      state: applied
          ? ExternalEffectState.applied
          : ExternalEffectState.unknown,
      dataStatus: applied
          ? ExternalDataState.committed
          : ExternalDataState.unknown,
      details: {
        'connection': _publicConnection(current),
        'credentialAvailable': status.credentialAvailable,
        'needsRecovery': status.needsRecovery,
        'configuredForFutureRuns': applied,
      },
    );
  }

  void _pruneInputs() {
    final now = _clock().toUtc();
    _inputs.removeWhere((_, input) {
      final remove =
          input.scope.isCancelled ||
          now.difference(input.createdAt) > inputLifetime;
      if (remove) input.input.discard();
      return remove;
    });
  }
}

const _string = {'type': 'string'};
void _keys(Map<String, Object?> args, Set<String> allowed) {
  if (args.keys.any((key) => !allowed.contains(key))) {
    _invalid('Unexpected connection argument.');
  }
}

String _text(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! String || value.trim().isEmpty) {
    _invalid('Missing or invalid $key.');
  }
  return value;
}

String? _optionalText(Map<String, Object?> args, String key) =>
    args[key] == null ? null : _text(args, key);
String _endpoint(String value) {
  final normalized = normalizeAgentEndpoint(value);
  if (normalized.isEmpty) {
    _invalid('A credential destination must be configured.');
  }
  return normalized;
}

String _publicEndpoint(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) return '';
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}

Map<String, Object?> _publicConnection(AgentSettings settings) => {
  'protocol': settings.protocol.name,
  'endpoint': _publicEndpoint(settings.endpoint),
  'model': settings.model,
  'models': settings.availableModels.map((value) => value.toJson()).toList(),
  'credentialConfigured': settings.credentialRef != null,
};
String _configuration(AgentSettings settings, {bool legacy = false}) =>
    mutationDigest({
      'protocol': settings.protocol.name,
      'endpoint': normalizeAgentEndpoint(settings.endpoint),
      'model': settings.model,
      if (!legacy)
        'models': settings.availableModels
            .map((value) => value.toJson())
            .toList(),
    });
String _identity(AgentSettings settings) => mutationDigest({
  'configuration': _configuration(settings),
  'credential': settings.credentialRef,
});
Map<String, Object?> _requestFingerprint(Map<String, Object?> args) => {
  'digest': mutationDigest(
    Map<String, Object?>.of(args)..remove('operationId'),
  ),
};
Never _invalid(String message) =>
    throw OperationProblem(OperationErrorCode.invalidArgument, message);
Never _conflict() => throw const OperationProblem(
  OperationErrorCode.conflict,
  'The prepared connection or secure input changed; prepare a new plan.',
);
