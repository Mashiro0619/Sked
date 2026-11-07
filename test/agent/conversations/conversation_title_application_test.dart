import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_action.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/workspace_harness.dart';

class _TitleProvider extends ProviderClient {
  final requests = <ProviderRequest>[];
  final keys = <String>[];

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests.add(request);
    keys.add(apiKey);
    final title = request.messages.first.text.startsWith(
      'Write a short, specific conversation title',
    );
    return Stream.value(
      ProviderCompleted(
        ProviderResponse(
          text: title
              ? 'Weekly timetable planning'
              : 'I can help plan your timetable.',
          toolCalls: const [],
          finishReason: 'stop',
          usage: ProviderUsage(
            inputTokens: title ? 12 : 30,
            outputTokens: title ? 3 : 10,
            totalTokens: title ? 15 : 40,
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('application wiring generates a title from first acceptance with separate usage', () async {
    final provider = _TitleProvider();
    final app = await workspaceProvider(
      agentProvider: provider,
      agentGenerateConversationTitles: true,
    );
    addTearDown(() async {
      await app.agent.quiesce();
      app.dispose();
    });
    await app.agent.configure(
      const AgentSettings(
        endpoint: 'https://fixture.example/v1',
        model: 'fixture',
        models: [
          AgentModelConfig(
            id: 'fixture',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'synthetic-application-key',
    );
    await app.agent.setEnabled(true);
    final conversation = await app.agent.conversations.createDraft(
      title: 'New conversation',
    );
    expect(app.agent.conversations.conversations, isEmpty);
    const message =
        'I have classes on Monday and Friday; help me plan the rest of the week.';
    await app.agent.runtime.send(conversation.id, message);
    await app.agent.runtime.waitForIdle();
    final saved = app.agent.conversations.find(conversation.id)!;
    expect(saved.title, 'Weekly timetable planning');
    expect(saved.titleWasEdited, isFalse);
    expect(saved.messages.first.text, message);
    expect(saved.titleGeneration!.model, 'fixture');
    expect(
      saved.titleGeneration!.request.outcome,
      ConversationAttemptOutcome.completed,
    );
    expect(saved.titleGeneration!.request.usage!.totalTokens, 15);
    expect(saved.runs.single.requests.single.usage!.totalTokens, 40);
    expect(provider.requests, hasLength(2));
    expect(provider.keys, everyElement('synthetic-application-key'));
    final titleRequest = provider.requests.firstWhere(
      (request) => request.messages.first.text.startsWith('Write a short'),
    );
    expect(titleRequest.tools, isEmpty);
    expect(
      jsonDecode(titleRequest.messages.last.text)['firstMessage'],
      message,
    );
    await app.agent.runtime.send(
      conversation.id,
      'Also reserve time for reading.',
    );
    await app.agent.runtime.waitForIdle();
    expect(provider.requests, hasLength(3));
    expect(
      app.agent.conversations.find(conversation.id)!.title,
      'Weekly timetable planning',
    );
  });
}
