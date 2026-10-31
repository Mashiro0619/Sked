import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/provider/provider.dart';

void main() {
  for (final protocol in ProviderProtocol.values) {
    for (final effort in <String?>[null, 'high']) {
      test(
        '${protocol.name} sends its reasoning parameter only for an explicit selection: $effort',
        () async {
          final client = MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (protocol == ProviderProtocol.chatCompletions) {
              expect(body.containsKey('reasoning_effort'), effort != null);
              expect(body['reasoning_effort'], effort);
              expect(body.containsKey('reasoning'), isFalse);
              return http.Response(
                jsonEncode({
                  'choices': [
                    {
                      'index': 0,
                      'message': {'role': 'assistant', 'content': 'done'},
                      'finish_reason': 'stop',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            expect(body.containsKey('reasoning'), effort != null);
            expect(
              body['reasoning'],
              effort == null ? null : {'effort': effort},
            );
            expect(body.containsKey('reasoning_effort'), isFalse);
            return http.Response(
              jsonEncode({
                'status': 'completed',
                'output': [
                  {
                    'type': 'message',
                    'role': 'assistant',
                    'content': [
                      {'type': 'output_text', 'text': 'done'},
                    ],
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          });
          final provider = ProviderClient(client: client);
          addTearDown(provider.close);
          addTearDown(client.close);
          final response = await provider.collect(
            ProviderRequest(
              endpoint: Uri.parse(
                'https://models.example/v1/${protocol == ProviderProtocol.responses ? 'responses' : 'chat/completions'}',
              ),
              model: 'fixture-model',
              protocol: protocol,
              reasoningEffort: effort,
              messages: [
                ProviderMessage(role: ProviderRole.user, text: 'test'),
              ],
            ),
            apiKey: '',
          );
          expect(response.text, 'done');
        },
      );
    }
  }
}
