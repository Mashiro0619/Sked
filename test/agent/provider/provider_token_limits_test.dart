import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/provider/provider.dart';

void main() {
  for (final protocol in ProviderProtocol.values) {
    final outputField = protocol == ProviderProtocol.chatCompletions
        ? 'max_completion_tokens'
        : 'max_output_tokens';
    for (final streaming in [false, true]) {
      final mode = streaming ? 'SSE' : 'JSON';
      for (final usage in [(33484, 515), (2000000, 8000)]) {
        test(
          '${protocol.name} $mode accepts ${usage.$1 + usage.$2} tokens without a client cap',
          () async {
            final h = _Harness(protocol, streaming, usage.$1, usage.$2);
            addTearDown(h.client.close);
            final response = await h.client.collect(h.request(), apiKey: '');
            expect(h.body, isNot(contains(outputField)));
            expect(h.body, isNot(contains('max_tokens')));
            expect(response.text, 'Completed.');
            expect(response.usage?.inputTokens, usage.$1);
            expect(response.usage?.outputTokens, usage.$2);
            expect(response.usage?.totalTokens, usage.$1 + usage.$2);
          },
        );
      }

      test(
        '${protocol.name} $mode preserves explicit diagnostic caps and actual usage',
        () async {
          final h = _Harness(protocol, streaming, 4096, 1);
          addTearDown(h.client.close);
          final events = <ProviderEvent>[];
          await expectLater(
            h.client
                .stream(
                  h.request(
                    limits: const ProviderLimits(
                      maxOutputTokens: 128,
                      maxTotalTokens: 4096,
                    ),
                  ),
                  apiKey: '',
                )
                .forEach(events.add),
            throwsA(
              isA<ProviderException>().having(
                (error) => error.code,
                'code',
                ProviderError.tokenBudgetExceeded,
              ),
            ),
          );
          expect(h.body[outputField], 128);
          expect(
            events.whereType<ProviderUsageEvent>().last.usage.totalTokens,
            4097,
          );
          expect(events.whereType<ProviderCompleted>(), isEmpty);
        },
      );
    }

    test('${protocol.name} an output cap does not imply a total cap', () async {
      final h = _Harness(protocol, false, 2000000, 128);
      addTearDown(h.client.close);
      final response = await h.client.collect(
        h.request(limits: const ProviderLimits(maxOutputTokens: 128)),
        apiKey: '',
      );
      expect(h.body[outputField], 128);
      expect(response.usage?.totalTokens, 2000128);
    });

    test(
      '${protocol.name} a local total cap does not add an output cap',
      () async {
        final h = _Harness(protocol, false, 100, 1);
        addTearDown(h.client.close);
        final response = await h.client.collect(
          h.request(limits: const ProviderLimits(maxTotalTokens: 4096)),
          apiKey: '',
        );
        expect(h.body, isNot(contains(outputField)));
        expect(response.usage?.totalTokens, 101);
      },
    );
  }

  for (final limits in const [
    ProviderLimits(maxOutputTokens: 0),
    ProviderLimits(maxOutputTokens: -1),
    ProviderLimits(maxTotalTokens: 0),
    ProviderLimits(maxTotalTokens: -1),
  ]) {
    test(
      'explicit nonpositive token limits are rejected before transmission: ${limits.maxOutputTokens}/${limits.maxTotalTokens}',
      () async {
        final h = _Harness(ProviderProtocol.chatCompletions, false, 1, 1);
        addTearDown(h.client.close);
        await expectLater(
          h.client.collect(h.request(limits: limits), apiKey: ''),
          throwsA(
            isA<ProviderException>().having(
              (error) => error.code,
              'code',
              ProviderError.invalidRequest,
            ),
          ),
        );
        expect(h.body, isEmpty);
      },
    );
  }
}

class _Harness {
  _Harness(this.protocol, bool streaming, int inputTokens, int outputTokens) {
    client = ProviderClient(
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        final responses = protocol == ProviderProtocol.responses;
        final usage = <String, Object?>{
          responses ? 'input_tokens' : 'prompt_tokens': inputTokens,
          responses ? 'output_tokens' : 'completion_tokens': outputTokens,
          'total_tokens': inputTokens + outputTokens,
        };
        final response = <String, Object?>{
          if (responses) ...{
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': 'Completed.'},
                ],
              },
            ],
          } else ...{
            'choices': [
              {
                'index': 0,
                streaming ? 'delta' : 'message': {
                  'role': 'assistant',
                  'content': 'Completed.',
                },
                'finish_reason': 'stop',
              },
            ],
          },
          'usage': usage,
        };
        final payload = streaming
            ? 'data: ${jsonEncode(responses ? {'type': 'response.completed', 'response': response} : response)}\n\n${responses ? '' : 'data: [DONE]\n\n'}'
            : jsonEncode(response);
        return http.Response(
          payload,
          200,
          headers: {
            'content-type': streaming
                ? 'text/event-stream'
                : 'application/json',
          },
        );
      }),
    );
  }

  final ProviderProtocol protocol;
  late final ProviderClient client;
  Map<String, dynamic> body = {};

  ProviderRequest request({ProviderLimits limits = const ProviderLimits()}) =>
      ProviderRequest(
        endpoint: Uri.parse('https://fixture.example/v1'),
        model: 'fixture',
        protocol: protocol,
        limits: limits,
        messages: [ProviderMessage(role: ProviderRole.user, text: 'Continue.')],
      );
}
