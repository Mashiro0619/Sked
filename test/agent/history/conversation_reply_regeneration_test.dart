import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/history/conversation_reply_regeneration.dart';
import 'package:sked/agent/provider/provider_models.dart';

void main() {
  test(
    'reply request strips tools but keeps the authorized connection snapshot',
    () {
      final original = ProviderRequest(
        endpoint: Uri.parse('http://local.example/v1/responses'),
        model: 'selected-model',
        protocol: ProviderProtocol.responses,
        messages: [],
        tools: [
          ToolDefinition(
            name: 'mutation.commit',
            description: '',
            parameters: {},
          ),
        ],
        allowInsecureHttp: true,
        reasoningEffort: 'high',
      );
      final context = [
        ProviderMessage(
          role: ProviderRole.user,
          text: 'Explain the saved result',
        ),
      ];
      final request = conversationReplyRequest(
        original,
        verifiedContext: context,
      );
      expect(request.tools, isEmpty);
      expect(request.endpoint, original.endpoint);
      expect(request.allowInsecureHttp, isTrue);
      expect(request.model, 'selected-model');
      expect(request.protocol, ProviderProtocol.responses);
      expect(request.reasoningEffort, 'high');
      expect(request.messages.last, same(context.single));
      expect(original.tools, hasLength(1));
    },
  );

  test(
    'an unsolicited write call is rejected instead of entering the tool loop',
    () {
      expect(
        () => validateConversationReplyResponse(
          ProviderResponse(
            text: 'I will change the schedule',
            toolCalls: [
              ProviderToolCall(
                id: 'call',
                name: 'mutation.commit',
                arguments: '{}',
              ),
            ],
            finishReason: 'tool_calls',
          ),
        ),
        throwsA(isA<ConversationHistoryException>()),
      );
      expect(
        () => validateConversationReplyResponse(
          ProviderResponse(
            text: '',
            toolCalls: [],
            responseItems: const [
              {'type': 'mcp_call'},
            ],
            finishReason: 'stop',
          ),
        ),
        throwsA(isA<ConversationHistoryException>()),
      );
      validateConversationReplyResponse(
        ProviderResponse(
          text: 'The recorded operation created the event.',
          toolCalls: [],
          finishReason: 'stop',
        ),
      );
    },
  );

  test('an empty or whitespace completion cannot replace a readable reply', () {
    for (final text in ['', ' \n\r\t ', '\u00a0\u3000']) {
      for (final withContinuation in [false, true]) {
        expect(
          () => validateConversationReplyResponse(
            ProviderResponse(
              text: text,
              toolCalls: [],
              responseItems: withContinuation
                  ? [
                      {
                        'type': 'reasoning',
                        'id': 'only-reasoning',
                        'summary': [],
                      },
                    ]
                  : [],
              finishReason: 'stop',
            ),
          ),
          throwsA(
            isA<ProviderException>().having(
              (error) => error.code,
              'code',
              ProviderError.incompleteResponse,
            ),
          ),
        );
      }
    }
    final response = ProviderResponse(
      text: '\n Revised explanation \n',
      toolCalls: [],
      finishReason: 'stop',
    );
    validateConversationReplyResponse(response);
    expect(response.text, '\n Revised explanation \n');
  });
}
