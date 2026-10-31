import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/agent_settings.dart';
import '../provider/provider.dart';
import 'agent_endpoint.dart';

enum AgentConnectionDiagnosticError {
  unsupportedModelsEndpoint,
  invalidModelsResponse,
}

class AgentConnectionDiagnosticException implements Exception {
  const AgentConnectionDiagnosticException(this.code);
  final AgentConnectionDiagnosticError code;
  @override
  String toString() => 'AgentConnectionDiagnosticException(${code.name})';
}

class AgentConnectionProbeResult {
  const AgentConnectionProbeResult({
    required this.toolCallingObserved,
    this.usage,
  });
  final bool toolCallingObserved;
  final ProviderUsage? usage;
  Map<String, Object?> toJson() => {
    'transportConnected': true,
    'toolCallingObserved': toolCallingObserved,
    'businessDataSent': false,
    'businessToolsExecuted': false,
    if (usage != null)
      'usage': {
        'inputTokens': usage!.inputTokens,
        'outputTokens': usage!.outputTokens,
        'totalTokens': usage!.totalTokens,
      },
  };
}

class AgentModelCatalog {
  AgentModelCatalog({required List<String> models, required this.complete})
    : models = List.unmodifiable(models);
  final List<String> models;
  final bool complete;
  Map<String, Object?> toJson() => {'models': models, 'complete': complete};
}

/// Explicit, synthetic connection diagnostics. Constructing this service never
/// starts a request. Callers own user intent, policy, and the connection/key
/// snapshot; responses are bounded and no redirect is followed.
class AgentConnectionDiagnostics {
  AgentConnectionDiagnostics({
    http.Client? client,
    ProviderClient? provider,
    this.timeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 10),
    this.maxCatalogBytes = 2 * 1024 * 1024,
    this.maxModels = 2000,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _providedProvider = provider;

  final http.Client _client;
  final bool _ownsClient;
  final ProviderClient? _providedProvider;
  final Duration timeout;
  final Duration idleTimeout;
  final int maxCatalogBytes;
  final int maxModels;

  Future<AgentConnectionProbeResult> probe(
    AgentSettings settings, {
    required String apiKey,
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) async {
    final provider = _providedProvider ?? ProviderClient(client: _client);
    final response = await provider.collect(
      ProviderRequest(
        endpoint: resolveConfiguredAgentEndpoint(settings),
        model: settings.model,
        reasoningEffort: settings.defaultModelSelection?.wireReasoningEffort,
        protocol: settings.protocol == AgentModelProtocol.responses
            ? ProviderProtocol.responses
            : ProviderProtocol.chatCompletions,
        allowInsecureHttp: allowInsecureHttp,
        limits: ProviderLimits(
          totalTimeout: timeout,
          idleTimeout: idleTimeout,
          maxRequestBytes: 16 * 1024,
          maxResponseBytes: 256 * 1024,
          maxEventBytes: 64 * 1024,
          maxToolArgumentBytes: 1024,
          maxToolCalls: 1,
          maxOutputTokens: 128,
          maxTotalTokens: 4096,
        ),
        messages: [
          ProviderMessage(
            role: ProviderRole.user,
            text: 'This is a synthetic connection test. Call connection.probe once with {"ok":true}. No real application data or business tool is available.',
          ),
        ],
        tools: [
          ToolDefinition(
            name: 'connection.probe',
            description:
                'Report that function calling works for this synthetic test.',
            parameters: {
              'type': 'object',
              'properties': {
                'ok': {'type': 'boolean'},
              },
              'required': ['ok'],
              'additionalProperties': false,
            },
          ),
        ],
      ),
      apiKey: apiKey,
      cancellation: cancellation,
    );
    final observed =
        response.toolCalls.length == 1 &&
        response.toolCalls.single.name == 'connection.probe' &&
        response.toolCalls.single.decodedArguments.length == 1 &&
        response.toolCalls.single.decodedArguments['ok'] == true;
    return AgentConnectionProbeResult(
      toolCallingObserved: observed,
      usage: response.usage,
    );
  }

  /// Standard completion paths imply a sibling models resource. An arbitrary
  /// custom completion path requires an explicit same-origin catalog endpoint.
  static Uri modelsEndpoint(Uri inference, {Uri? explicit}) {
    _validateUri(inference);
    if (explicit != null) {
      _validateUri(explicit);
      if (explicit.origin != inference.origin) {
        throw const ProviderException(ProviderError.invalidRequest);
      }
      return explicit;
    }
    final path = inference.path.replaceFirst(RegExp(r'/+$'), '');
    final suffix = path.endsWith('/chat/completions')
        ? '/chat/completions'
        : path.endsWith('/responses')
        ? '/responses'
        : null;
    if (suffix == null) {
      throw const AgentConnectionDiagnosticException(
        AgentConnectionDiagnosticError.unsupportedModelsEndpoint,
      );
    }
    return inference.replace(
      path: '${path.substring(0, path.length - suffix.length)}/models',
    );
  }

  Future<AgentModelCatalog> listModels(
    AgentSettings settings, {
    required String apiKey,
    Uri? explicitEndpoint,
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) async {
    final endpoint = modelsEndpoint(
      resolveConfiguredAgentEndpoint(settings),
      explicit: explicitEndpoint,
    );
    if (endpoint.scheme == 'http' && !allowInsecureHttp) {
      throw const ProviderException(ProviderError.insecureEndpoint);
    }
    if (timeout <= Duration.zero ||
        idleTimeout <= Duration.zero ||
        maxCatalogBytes <= 0 ||
        maxModels <= 0 ||
        apiKey.contains('\r') ||
        apiKey.contains('\n')) {
      throw const ProviderException(ProviderError.invalidRequest);
    }
    if (cancellation?.isCancelled ?? false) {
      throw const ProviderException(ProviderError.cancelled);
    }
    final stopped = Completer<ProviderException>();
    final abort = Completer<void>();
    var finished = false;
    void stop(ProviderError error) {
      if (finished || stopped.isCompleted) return;
      stopped.complete(ProviderException(error));
      if (!abort.isCompleted) abort.complete();
    }

    Future<T> guarded<T>(Future<T> action) =>
        Future.any([action, stopped.future.then<T>((error) => throw error)]);
    final timer = Timer(timeout, () => stop(ProviderError.timeout));
    unawaited(
      cancellation?.whenCancelled.then((_) => stop(ProviderError.cancelled)),
    );
    StreamIterator<List<int>>? iterator;
    try {
      final request =
          http.AbortableRequest('GET', endpoint, abortTrigger: abort.future)
            ..followRedirects = false
            ..maxRedirects = 0
            ..headers.addAll({
              'Accept': 'application/json',
              if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
            });
      final response = await guarded(
        _client.send(request).then((value) {
          if (stopped.isCompleted) {
            unawaited(value.stream.listen(null).cancel());
            throw const ProviderException(ProviderError.cancelled);
          }
          return value;
        }),
      );
      iterator = StreamIterator(response.stream);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw ProviderException(
          ProviderError.redirectRejected,
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProviderException(switch (response.statusCode) {
          401 || 403 => ProviderError.authentication,
          429 => ProviderError.rateLimited,
          _ => ProviderError.httpFailure,
        }, statusCode: response.statusCode);
      }
      if ((response.contentLength ?? 0) > maxCatalogBytes) {
        throw const ProviderException(ProviderError.responseBudgetExceeded);
      }
      final bytes = <int>[];
      while (await guarded(
        iterator.moveNext().timeout(
          idleTimeout,
          onTimeout: () => throw const ProviderException(ProviderError.timeout),
        ),
      )) {
        if (bytes.length + iterator.current.length > maxCatalogBytes) {
          throw const ProviderException(ProviderError.responseBudgetExceeded);
        }
        bytes.addAll(iterator.current);
      }
      return _decodeCatalog(utf8.decode(bytes));
    } on ProviderException {
      rethrow;
    } on AgentConnectionDiagnosticException {
      rethrow;
    } on FormatException {
      throw const AgentConnectionDiagnosticException(
        AgentConnectionDiagnosticError.invalidModelsResponse,
      );
    } catch (_) {
      if (stopped.isCompleted) throw await stopped.future;
      throw const ProviderException(ProviderError.transportFailure);
    } finally {
      finished = true;
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      await iterator?.cancel();
    }
  }

  AgentModelCatalog _decodeCatalog(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, Object?> ||
        json['data'] is! List ||
        (json.containsKey('has_more') && json['has_more'] is! bool)) {
      throw const AgentConnectionDiagnosticException(
        AgentConnectionDiagnosticError.invalidModelsResponse,
      );
    }
    final data = json['data'] as List;
    if (data.length > maxModels) {
      throw const ProviderException(ProviderError.responseBudgetExceeded);
    }
    final ids = <String>{};
    for (final item in data) {
      if (item is! Map<String, Object?> || item['id'] is! String) {
        throw const AgentConnectionDiagnosticException(
          AgentConnectionDiagnosticError.invalidModelsResponse,
        );
      }
      final id = item['id'] as String;
      if (id.trim().isEmpty ||
          id.length > 256 ||
          id.codeUnits.any((unit) => unit < 32)) {
        throw const AgentConnectionDiagnosticException(
          AgentConnectionDiagnosticError.invalidModelsResponse,
        );
      }
      ids.add(id);
    }
    final models = ids.toList()..sort();
    // A completed catalog also fits the durable external receipt admission
    // limit, so callers can page it without repeating a network request.
    if (utf8.encode(jsonEncode(models)).length > 512 * 1024) {
      throw const ProviderException(ProviderError.responseBudgetExceeded);
    }
    return AgentModelCatalog(
      models: models,
      complete: json['has_more'] != true,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

void _validateUri(Uri uri) {
  if (!uri.isAbsolute ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !{'http', 'https'}.contains(uri.scheme)) {
    throw const ProviderException(ProviderError.invalidRequest);
  }
}
