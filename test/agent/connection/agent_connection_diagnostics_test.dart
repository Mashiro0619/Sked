import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/agent/connection/agent_connection_diagnostics.dart';
import 'package:sked/agent/connection/agent_endpoint.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/models/agent_settings.dart';

class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  final requests = <http.BaseRequest>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return handler(request);
  }
}

http.StreamedResponse _json(Object body, {int status = 200}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );
const _settings = AgentSettings(
  endpoint: 'https://api.test/v1',
  model: 'chosen-model',
  models: [
    AgentModelConfig(
      id: 'chosen-model',
      reasoningEfforts: [AgentReasoningEffort.medium],
      defaultReasoningEffort: AgentReasoningEffort.medium,
    ),
  ],
);
Matcher _provider(ProviderError code) =>
    isA<ProviderException>().having((e) => e.code, 'code', code);

void main() {
  for (final protocol in AgentModelProtocol.values) {
    test(
      'synthetic ${protocol.name} probe reuses base endpoint resolution and distinguishes tool support',
      () async {
        final settings = _settings.copyWith(protocol: protocol);
        final client = _Client((request) async {
          expect(request.url, resolveConfiguredAgentEndpoint(settings));
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer synthetic-key');
          final body = jsonDecode(
            utf8.decode(await request.finalize().toBytes()),
          ) as Map;
          expect(body['model'], 'chosen-model');
          if (protocol == AgentModelProtocol.responses) {
            expect(body['reasoning'], {'effort': 'medium'});
          } else {
            expect(body['reasoning_effort'], 'medium');
          }
          expect(body['tools'], hasLength(1));
          return protocol == AgentModelProtocol.responses
              ? _json({
                  'status': 'completed',
                  'output': [
                    {
                      'type': 'function_call',
                      'call_id': 'probe',
                      'name': 'connection__probe',
                      'arguments': '{"ok":true}',
                    },
                  ],
                  'usage': {
                    'input_tokens': 20,
                    'output_tokens': 4,
                    'total_tokens': 24,
                  },
                })
              : _json({
                  'choices': [
                    {
                      'finish_reason': 'tool_calls',
                      'message': {
                        'tool_calls': [
                          {
                            'id': 'probe',
                            'type': 'function',
                            'function': {
                              'name': 'connection__probe',
                              'arguments': '{"ok":true}',
                            },
                          },
                        ],
                      },
                    },
                  ],
                  'usage': {
                    'prompt_tokens': 20,
                    'completion_tokens': 4,
                    'total_tokens': 24,
                  },
                });
        });
        final service = AgentConnectionDiagnostics(client: client);
        final result = await service.probe(settings, apiKey: 'synthetic-key');
        expect(result.toolCallingObserved, isTrue);
        expect(result.usage?.totalTokens, 24);
        expect(result.toJson()['businessToolsExecuted'], isFalse);
        expect(jsonEncode(result.toJson()), isNot(contains('synthetic-key')));
        expect(client.requests, hasLength(1));
      },
    );
  }

  test(
    'probe requires a configured explicit effort before any request',
    () async {
      final client = _Client((_) async => _json({}));
      final service = AgentConnectionDiagnostics(client: client);
      for (final settings in [
        const AgentSettings(endpoint: 'https://api.test/v1'),
        const AgentSettings(
          endpoint: 'https://api.test/v1',
          model: 'model-only',
        ),
        const AgentSettings(
          endpoint: 'https://api.test/v1',
          model: 'empty-efforts',
          models: [
            AgentModelConfig(
              id: 'empty-efforts',
              reasoningEfforts: [],
              defaultReasoningEffort: AgentReasoningEffort.high,
            ),
          ],
        ),
      ]) {
        await expectLater(
          service.probe(settings, apiKey: 'key'),
          throwsA(
            isA<AgentConnectionDiagnosticException>().having(
              (e) => e.code,
              'code',
              AgentConnectionDiagnosticError.modelSelectionRequired,
            ),
          ),
        );
      }
      expect(client.requests, isEmpty);
    },
  );

  test(
    'model catalog remains available before configuring reasoning',
    () async {
      final client = _Client(
        (_) async => _json({
          'data': [
            {'id': 'candidate'},
          ],
        }),
      );
      final service = AgentConnectionDiagnostics(client: client);
      final result = await service.listModels(
        const AgentSettings(endpoint: 'https://api.test/v1'),
        apiKey: 'key',
      );
      expect(result.models, ['candidate']);
      expect(client.requests, hasLength(1));
    },
  );

  test(
    'successful text alone proves transport but not function calling',
    () async {
      final client = _Client(
        (_) async => _json({
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'content': 'Connected'},
            },
          ],
        }),
      );
      final result = await AgentConnectionDiagnostics(client: client)
          .probe(_settings, apiKey: 'key');
      expect(result.toJson()['transportConnected'], isTrue);
      expect(result.toolCallingObserved, isFalse);
    },
  );

  test(
    'model catalog derives a same-origin sibling and preserves partial status',
    () async {
      final client = _Client((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.test/v1/models');
        expect(request.followRedirects, isFalse);
        return _json({
          'object': 'list',
          'data': [
            {'id': 'z'},
            {'id': 'a'},
            {'id': 'z'},
          ],
          'has_more': true,
        });
      });
      final result = await AgentConnectionDiagnostics(client: client)
          .listModels(_settings, apiKey: 'key');
      expect(result.models, ['a', 'z']);
      expect(result.complete, isFalse);
      expect(client.requests, hasLength(1));
    },
  );

  test('custom catalog paths are explicit and cannot change origin or carry URL credentials', () async {
    expect(
      () => AgentConnectionDiagnostics.modelsEndpoint(
        Uri.parse('https://api.test/custom'),
      ),
      throwsA(
        isA<AgentConnectionDiagnosticException>().having(
          (e) => e.code,
          'code',
          AgentConnectionDiagnosticError.unsupportedModelsEndpoint,
        ),
      ),
    );
    expect(
      AgentConnectionDiagnostics.modelsEndpoint(
        Uri.parse('https://api.test/custom'),
        explicit: Uri.parse('https://api.test/catalog'),
      ).path,
      '/catalog',
    );
    for (final target in [
      'https://other.test/models',
      'http://api.test/models',
      'https://api.test:444/models',
      'https://user:password@api.test/models',
      'https://api.test/models?key=secret',
    ]) {
      expect(
        () => AgentConnectionDiagnostics.modelsEndpoint(
          Uri.parse('https://api.test/v1/responses'),
          explicit: Uri.parse(target),
        ),
        throwsA(_provider(ProviderError.invalidRequest)),
      );
    }
  });

  test('catalog HTTP requires explicit authorization and pre-cancellation never sends', () async {
    final client = _Client((_) async => _json({'data': []}));
    final service = AgentConnectionDiagnostics(client: client);
    await expectLater(
      service.listModels(
        _settings.copyWith(endpoint: 'http://api.test/v1'),
        apiKey: 'key',
      ),
      throwsA(_provider(ProviderError.insecureEndpoint)),
    );
    final token = ProviderCancellationToken()..cancel();
    await expectLater(
      service.listModels(_settings, apiKey: 'key', cancellation: token),
      throwsA(_provider(ProviderError.cancelled)),
    );
    expect(client.requests, isEmpty);
  });

  test(
    'redirects and authentication failures omit raw server error bodies',
    () async {
      for (final status in [302, 401]) {
        final client = _Client(
          (_) async => _json({'error': 'private-server-key'}, status: status),
        );
        try {
          await AgentConnectionDiagnostics(client: client)
              .listModels(_settings, apiKey: 'private-server-key');
          fail('The response must fail.');
        } on ProviderException catch (error) {
          expect(
            error.code,
            status == 302
                ? ProviderError.redirectRejected
                : ProviderError.authentication,
          );
          expect(error.toString(), isNot(contains('private-server-key')));
        }
        expect(client.requests, hasLength(1));
      }
    },
  );

  test(
    'malformed, oversized and over-count catalogs fail as whole responses',
    () async {
      final malformed = AgentConnectionDiagnostics(
        client: _Client(
          (_) async => _json({
            'data': [
              {'id': 42},
            ],
          }),
        ),
      );
      await expectLater(
        malformed.listModels(_settings, apiKey: ''),
        throwsA(isA<AgentConnectionDiagnosticException>()),
      );
      final large = AgentConnectionDiagnostics(
        maxCatalogBytes: 16,
        client: _Client(
          (_) async => _json({
            'data': [
              {'id': 'too-much-data'},
            ],
          }),
        ),
      );
      await expectLater(
        large.listModels(_settings, apiKey: ''),
        throwsA(_provider(ProviderError.responseBudgetExceeded)),
      );
      final many = AgentConnectionDiagnostics(
        maxModels: 1,
        client: _Client(
          (_) async => _json({
            'data': [
              {'id': 'a'},
              {'id': 'b'},
            ],
          }),
        ),
      );
      await expectLater(
        many.listModels(_settings, apiKey: ''),
        throwsA(_provider(ProviderError.responseBudgetExceeded)),
      );
    },
  );

  test(
    'in-flight catalog cancellation aborts an uncompleted response',
    () async {
      final started = Completer<void>();
      final response = Completer<http.StreamedResponse>();
      final client = _Client((_) {
        started.complete();
        return response.future;
      });
      final token = ProviderCancellationToken();
      final call = AgentConnectionDiagnostics(client: client)
          .listModels(_settings, apiKey: 'key', cancellation: token);
      final expected = expectLater(
        call,
        throwsA(_provider(ProviderError.cancelled)),
      );
      await started.future;
      token.cancel();
      await expected;
      expect(client.requests.single, isA<http.AbortableRequest>());
      response.complete(_json({'data': []}));
    },
  );

  test('catalog idle timeout ends a stalled body', () async {
    final stream = StreamController<List<int>>();
    addTearDown(stream.close);
    final client = _Client(
      (_) async => http.StreamedResponse(stream.stream, 200),
    );
    await expectLater(
      AgentConnectionDiagnostics(
        client: client,
        idleTimeout: const Duration(milliseconds: 10),
      ).listModels(_settings, apiKey: ''),
      throwsA(_provider(ProviderError.timeout)),
    );
  });
}
