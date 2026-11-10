import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/rust_agent_ui_delegate.dart';
import 'package:sked/agent/bridge/rust_conversation_repository.dart';
import 'package:sked/agent/tools/conversation_tool_adapters.dart';
import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/agent_native_fixture.dart';
import 'platform_tool_test_support.dart';

const _id = 'managed-chat';
const _settings = AgentSettings(
  endpoint: 'https://fixture.invalid/v1',
  model: 'test-model',
  models: [
    AgentModelConfig(
      id: 'test-model',
      reasoningEfforts: [AgentReasoningEffort.none],
      defaultReasoningEffort: AgentReasoningEffort.none,
    ),
  ],
);

ViewConversationSource _source(String text) => ViewConversationSource(
  id: 'source',
  kind: 'structured_file',
  text: text,
  truncated: false,
  boundMessageId: 'message-0',
);

ViewConversationSnapshot _data() => copyNativeSnapshot(
  nativeConversationFixture(
    id: _id,
    messages: [
      for (var index = 0; index < 120; index++)
        nativeMessageFixture(
          id: 'message-$index',
          text: 'Message $index',
          role: index == 0 ? ViewMessageRole.user : ViewMessageRole.assistant,
        ),
    ],
  ),
  sources: [_source('Original source body')],
);

ViewConversationSnapshot _withExecutionStart(
  ViewConversationSnapshot value,
  int start,
) {
  final current = value.conversation;
  return copyNativeSnapshot(
    value,
    sequence: value.sequence + 1,
    conversation: ViewConversation(
      id: current.id,
      title: current.title,
      titleWasEdited: current.titleWasEdited,
      pinned: current.pinned,
      archived: current.archived,
      draftOnly: current.draftOnly,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      mode: current.mode,
      status: current.status,
      draft: current.draft,
      draftAttachmentIds: current.draftAttachmentIds,
      draftReferences: current.draftReferences,
      modelSelection: current.modelSelection,
      connectionFingerprint: current.connectionFingerprint,
      runId: current.runId,
      executionHistoryStart: start,
      titleGeneration: current.titleGeneration,
    ),
  );
}

class _ConversationCore extends MemoryAgentCore {
  _ConversationCore() : super(snapshots: [_data()]);

  @override
  Future<CommandResult> dispatch({required AgentCommand command}) async {
    if (command.kind != CommandKind.continue_) {
      return super.dispatch(command: command);
    }
    commands.add(command);
    final before = snapshots[command.conversationId]!;
    final resumedRun = command.targetId!;
    publish(
      copyNativeSnapshot(
        before,
        sequence: before.sequence + 1,
        conversation: copyNativeConversation(
          before.conversation,
          runId: 'next-queued-run',
          status: ViewConversationStatus.running,
        ),
        runs: [
          ViewRun(
            id: resumedRun,
            startedAt: 1793664000000,
            settledAt: 1793664000001,
            kind: ViewRunKind.model,
            status: ViewRunStatus.completed,
            requests: const [],
            tools: const [],
            environment: const JsonPayload(json: '{}'),
          ),
          const ViewRun(
            id: 'next-queued-run',
            startedAt: 1793664000002,
            kind: ViewRunKind.model,
            status: ViewRunStatus.running,
            requests: [],
            tools: [],
            environment: JsonPayload(json: '{}'),
          ),
        ],
      ),
    );
    throw StateError('Synthetic acknowledgement loss after resume');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlatformToolHarness h;
  late _ConversationCore core;
  late RustConversationRepository repository;
  late RustAgentUiDelegate runtime;
  late ConversationToolAdapters conversations;

  setUp(() async {
    h = PlatformToolHarness();
    await h.initialize();
    core = _ConversationCore();
    repository = RustConversationRepository(core.client, pageSize: 2);
    runtime = RustAgentUiDelegate(
      client: core.client,
      readSettings: () => _settings,
      readApiKey: (_) async => 'offline-placeholder',
      onOpenSettings: () {},
      onState: repository.ingestState,
    );
    var nextId = 0;
    conversations = registerConversationTools(
      h.host,
      external: h.external,
      repository: repository,
      runtime: runtime,
      platformTools: h.platform,
      idGenerator: () => 'managed-${++nextId}',
    );
    await repository.load();
  });

  tearDown(() async {
    await conversations.waitForPendingOperations();
    await h.close();
    repository.dispose();
    await runtime.dispose();
    await core.client.shutdown();
  });

  Future<void> replace(ViewConversationSnapshot snapshot) async {
    core.snapshots[_id] = snapshot;
    await repository.refresh(_id);
  }

  void expectNoBodyReads() => expect(
    core.queries.where((query) => query.kind == QueryKind.readConversation),
    isEmpty,
  );

  test(
    'metadata and management preserve total counts without body reads',
    () async {
      final summary = await h.call('conversations.get', {'id': _id});
      expect(summary['messageCount'], 120);
      expect(summary['sourceCount'], 1);
      final listed = await h.call('conversations.list');
      expect((listed['conversations'] as List).single, summary);
      expect(repository.find(_id)!.messages, isEmpty);
      expect(repository.find(_id)!.sources, isEmpty);
      expect(
        (await h.call('runs.status', {'conversationId': _id}))['active'],
        false,
      );

      final rename = await h.call('conversations.rename', {
        'id': _id,
        'title': 'Renamed',
      });
      final renamed = await h.externalCommit(rename);
      final renamedSummary =
          (renamed['effectResult'] as Map)['conversation'] as Map;
      expect(renamedSummary['title'], 'Renamed');
      expect(renamedSummary['messageCount'], 120);
      expect(renamedSummary['sourceCount'], 1);

      final archive = await h.call('conversations.archive', {
        'id': _id,
        'archived': true,
      });
      await h.externalCommit(archive);
      await conversations.waitForPendingOperations();
      final archived = await h.call('external.status', {
        'operationId': archive['operationId'],
      });
      final archivedSummary =
          (archived['effectResult'] as Map)['conversation'] as Map;
      expect(archived['effectStatus'], 'applied');
      expect(archivedSummary['archived'], true);
      expect(archivedSummary['messageCount'], 120);
      expect(archivedSummary['sourceCount'], 1);

      final deletion = await h.call('conversations.delete', {'id': _id});
      await h.externalCommit(deletion);
      await conversations.waitForPendingOperations();
      expect(core.snapshots.containsKey(_id), false);
      expectNoBodyReads();
    },
  );

  test(
    'management consent follows input and source changes, not assistant output',
    () async {
      final sourcePlan = await h.call('runs.stop', {'conversationId': _id});
      var current = core.snapshots[_id]!;
      await replace(
        copyNativeSnapshot(
          current,
          sequence: current.sequence + 1,
          sources: [_source('Changed source body')],
        ),
      );
      await expectLater(
        h.externalCommit(sourcePlan),
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.conflict,
          ),
        ),
      );

      final inputPlan = await h.call('runs.stop', {'conversationId': _id});
      current = core.snapshots[_id]!;
      await replace(
        copyNativeSnapshot(
          current,
          sequence: current.sequence + 1,
          messages: [
            copyNativeMessage(current.messages.first, text: 'Changed request'),
            ...current.messages.skip(1),
          ],
        ),
      );
      await expectLater(
        h.externalCommit(inputPlan),
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.conflict,
          ),
        ),
      );

      final outputPlan = await h.call('runs.stop', {'conversationId': _id});
      current = core.snapshots[_id]!;
      await replace(
        copyNativeSnapshot(
          current,
          sequence: current.sequence + 1,
          messages: [
            ...current.messages,
            nativeMessageFixture(id: 'later-answer', text: 'Additional output'),
          ],
        ),
      );
      expect((await h.externalCommit(outputPlan))['effectStatus'], 'applied');

      final rename = await h.call('conversations.rename', {
        'id': _id,
        'title': 'Title only',
      });
      current = core.snapshots[_id]!;
      await replace(
        copyNativeSnapshot(
          current,
          sequence: current.sequence + 1,
          sources: [_source('Another source edit')],
        ),
      );
      expect((await h.externalCommit(rename))['effectStatus'], 'applied');
      expectNoBodyReads();
    },
  );

  test(
    'resume checks the execution boundary and reconciles its original run',
    () async {
      await replace(_withExecutionStart(core.snapshots[_id]!, 120));
      await expectLater(
        h.call('runs.resume', {'conversationId': _id}),
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.invalidArgument,
          ),
        ),
      );
      await replace(_withExecutionStart(core.snapshots[_id]!, 0));
      final prepared = await h.call('runs.resume', {'conversationId': _id});
      final originalRunId = h.external
          .plan(prepared['planId'] as String)!
          .operation
          .arguments['runId'];
      final result = await h.externalCommit(prepared);
      expect(result['effectStatus'], 'applied');
      expect(core.snapshots[_id]!.conversation.runId, 'next-queued-run');
      expect(
        core.commands.where((command) => command.kind == CommandKind.continue_),
        hasLength(1),
      );
      expect(
        core.queries
            .where((query) => query.kind == QueryKind.run)
            .map((query) => query.targetId),
        [originalRunId],
      );
      expectNoBodyReads();
    },
  );

  test(
    'approved export reads the complete transcript without expanding the page',
    () async {
      final owner = Object();
      await repository.setViewActive(owner, _id);
      final visible = repository
          .visibleMessages(_id)
          .map((message) => message.id)
          .toList();
      expect(visible, hasLength(2));
      AgentDataArtifact? saved;
      conversations.bindServices(
        saveArtifact: (artifact) async {
          saved = artifact;
          return const AgentArtifactWriteResult(saved: true);
        },
      );
      final plan = await h.call('conversations.export', {'id': _id});
      expect((await h.externalCommit(plan))['effectStatus'], 'applied');
      final transcript =
          (jsonDecode(saved!.text) as Map)['conversation'] as Map;
      expect(transcript['messages'], hasLength(120));
      expect(
        (transcript['sources'] as List).single['text'],
        'Original source body',
      );
      expect(
        repository.visibleMessages(_id).map((message) => message.id),
        visible,
      );
      expect(
        core.queries.where((query) => query.kind == QueryKind.readConversation),
        hasLength(1),
      );
      await repository.setViewActive(owner, null);
    },
  );
}
