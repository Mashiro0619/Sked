import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/workspace_harness.dart';

const _answer = 'Use the morning and preserve this submitted decision';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_Harness> harness() async {
    final value = await _Harness.create();
    addTearDown(value.close);
    return value;
  }

  for (final dismissed in [false, true]) {
    test(
      'redo archives the stopped ${dismissed ? 'dismissal' : 'answer'} with its original tool result identity',
      () async {
        final h = await harness();
        final stopped = await h.stopAfterAnswer(dismissed: dismissed);
        final originalReply = _reply(
          h.current.messages,
          stopped.question.toolCallId,
        );
        h.provider.respond = (_) => _done();

        await h.app.agent.history.editAndRedo(
          h.id,
          stopped.userMessageId,
          'Edited task',
        );

        final stored = h.chats.saved;
        expect(stored.pendingRedo, isNull);
        expect(stored.pendingQuestion, isNull);
        final retired = stored.historyVersions.single;
        final reply = _reply(retired.messages, stopped.question.toolCallId);
        expect(reply.id, originalReply.id);
        _expectResult(reply, stopped.question);
        expect(retired.turns.single.messageIds, contains(reply.id));
        expect(
          retired.runs.single.tools.single.outcome,
          ConversationAttemptOutcome.completed,
        );
        expect(h.provider.requests, hasLength(2));
        expect(
          h.app.agent.runtime.state.value.runFor(h.id).errorMessage,
          isNull,
        );
      },
    );
  }

  test('redo after restart materializes a saved answer whose tool reply was never published', () async {
    final h = await harness();
    final stopped = await h.stopAfterAnswer();
    await h.restart(stopped.answerSnapshot);
    expect(h.current.pendingQuestion!.isResolved, true);
    expect(
      h.current.messages.where(
        (message) => message.toolCallId == stopped.question.toolCallId,
      ),
      isEmpty,
    );
    final requests = h.provider.requests.length;
    h.provider.respond = (_) => _done();

    await h.app.agent.history.editAndRedo(
      h.id,
      stopped.userMessageId,
      'Edited after restart',
    );

    final retired = h.chats.saved.historyVersions.single;
    final reply = _reply(retired.messages, stopped.question.toolCallId);
    _expectResult(reply, stopped.question);
    expect(retired.turns.single.messageIds, contains(reply.id));
    expect(
      retired.runs.single.tools.single.outcome,
      ConversationAttemptOutcome.completed,
    );
    expect(h.provider.requests.length, requests + 1);
    expect(h.chats.saved.pendingRedo, isNull);
  });

  test('a business conflict during redo preflight preserves the accepted answer in current history', () async {
    final h = await harness();
    final stopped = await h.stopAfterAnswer(createCalendar: true);
    final currentData = h.app.session.committedData;
    final changed = currentData.copyWith(
      generalMode: currentData.generalMode.copyWith(
        schedules: currentData.generalMode.schedules
            .map(
              (calendar) => calendar.name == 'Question history calendar'
                  ? calendar.copyWith(name: 'Manual change after the question')
                  : calendar,
            )
            .toList(),
      ),
    );
    h.app.session.replaceData(changed);
    await h.app.session.persist(changed);
    final providerRequests = h.provider.requests.length;

    await expectLater(
      h.app.agent.history.editAndRedo(
        h.id,
        stopped.userMessageId,
        'Rejected edit',
      ),
      throwsA(
        isA<ConversationHistoryException>().having(
          (error) => error.code,
          'code',
          ConversationHistoryError.conflict,
        ),
      ),
    );

    final stored = h.chats.saved;
    expect(stored.pendingRedo, isNull);
    expect(stored.pendingQuestion, isNull);
    expect(stored.historyVersions, isEmpty);
    _expectResult(
      _reply(stored.messages, stopped.question.toolCallId),
      stopped.question,
    );
    expect(
      stored.runs.single.tools.last.outcome,
      ConversationAttemptOutcome.completed,
    );
    expect(h.provider.requests.length, providerRequests);
    expect(h.app.session.committedData.toJson(), changed.toJson());
    expect(stored.messages.first.text, 'Original question task');
  });

  test('a failed answer materialization keeps pending answers durable for storage recovery and retry', () async {
    final h = await harness();
    final stopped = await h.stopAfterAnswer();
    final before = h.chats.source;
    h.chats.beforeSave = (_) async {
      throw const ConversationStorageException(
        'Synthetic answer materialization failure',
      );
    };

    await expectLater(
      h.app.agent.history.editAndRedo(
        h.id,
        stopped.userMessageId,
        'Retryable edit',
      ),
      throwsA(isA<ConversationStorageException>()),
    );

    expect(h.chats.source, before);
    expect(h.current.pendingQuestion!.answers!.single.text, _answer);
    expect(h.chats.saved.pendingQuestion!.answers!.single.text, _answer);
    expect(h.chats.saved.historyVersions, isEmpty);
    expect(h.provider.requests, hasLength(1));
    h.chats.beforeSave = null;
    await h.app.agent.recoverConversations();
    h.provider.respond = (_) => _done();
    await h.app.agent.history.editAndRedo(
      h.id,
      stopped.userMessageId,
      'Retryable edit',
    );

    _expectResult(
      _reply(
        h.chats.saved.historyVersions.single.messages,
        stopped.question.toolCallId,
      ),
      stopped.question,
    );
    expect(h.chats.saved.pendingRedo, isNull);
  });

  test('redo clears an unanswered stopped question while preserving its unexecuted result', () async {
    final h = await harness();
    h.provider.respond = (_) => _ask();
    final running = h.app.agent.runtime.send(h.id, 'Original unanswered task');
    await h.waitForQuestion();
    final question = h.current.pendingQuestion!;
    await h.app.agent.runtime.stop(h.id);
    await running;
    final original = _reply(h.current.messages, question.toolCallId);
    h.provider.respond = (_) => _done();

    await h.app.agent.history.editAndRedo(
      h.id,
      h.current.messages.first.id,
      'New task',
    );

    expect(h.chats.saved.pendingQuestion, isNull);
    final retired = h.chats.saved.historyVersions.single;
    expect(_reply(retired.messages, question.toolCallId).text, original.text);
    expect(
      retired.runs.single.tools.single.outcome,
      ConversationAttemptOutcome.notStarted,
    );
  });

  test('steering queued during answer persistence keeps one answer result and leaves the remaining tool unstarted', () async {
    final h = await harness();
    h.provider.respond = (_) => ProviderResponse(
      text: '',
      toolCalls: [
        _ask().toolCalls.single,
        ProviderToolCall(
          id: 'after-question',
          name: 'capabilities.describe',
          arguments: jsonEncode({
            'names': ['calendars.list'],
          }),
        ),
      ],
      finishReason: 'tool_calls',
    );
    final running = h.app.agent.runtime.send(h.id, 'Original question task');
    await h.waitForQuestion();
    final question = h.current.pendingQuestion!;
    Future<void>? steering;
    var queuedBeforeAnswerAcknowledgement = false;
    h.chats.beforeSave = (archive) async {
      if (steering != null ||
          archive.conversations.single.pendingQuestion?.isResolved != true) {
        return;
      }
      final blockedTail = h.app.agent.conversations.waitForPendingWrites();
      h.provider.respond = (_) => _done();
      steering = h.app.agent.runtime.steer(h.id, 'Use this revised task');
      // Observe acceptance into the real serialized queue before releasing the
      // answer save. The original ask_user cannot publish its result yet.
      for (
        var attempt = 0;
        attempt < 1000 &&
            identical(
              h.app.agent.conversations.waitForPendingWrites(),
              blockedTail,
            );
        attempt++
      ) {
        await Future<void>.microtask(() {});
      }
      queuedBeforeAnswerAcknowledgement = !identical(
        h.app.agent.conversations.waitForPendingWrites(),
        blockedTail,
      );
      expect(queuedBeforeAnswerAcknowledgement, true);
    };

    await h.app.agent.runtime.answerQuestion(h.id, question.id, [
      AgentQuestionAnswer(questionId: 'detail', text: _answer),
    ]);
    await steering;
    await running;
    h.chats.beforeSave = null;
    await h.waitUntil(
      () =>
          h.provider.requests.length == 2 &&
          !h.app.agent.runtime.isRunning(h.id) &&
          h.app.agent.runtime.pendingInputCount(h.id) == 0,
    );

    final stored = h.chats.saved;
    expect(queuedBeforeAnswerAcknowledgement, true);
    expect(stored.pendingQuestion, isNull);
    expect(
      stored.messages.where(
        (message) =>
            message.role == ConversationRole.tool &&
            message.toolCallId == question.toolCallId,
      ),
      hasLength(1),
    );
    _expectResult(
      _reply(stored.messages, question.toolCallId),
      question.withAnswers([
        AgentQuestionAnswer(questionId: 'detail', text: _answer),
      ]),
    );
    final originalRun = stored.runs.first;
    expect(
      originalRun.tools.first.outcome,
      ConversationAttemptOutcome.completed,
    );
    expect(originalRun.tools, hasLength(1));
    final unstarted = _reply(stored.messages, 'after-question');
    expect(jsonDecode(unstarted.text)['status'], 'not_executed');
    expect(stored.turns.single.messageIds, contains(unstarted.id));
    expect(stored.turns, hasLength(1));
    expect(stored.status, ConversationStatus.idle);
    expect(h.app.agent.runtime.state.value.runFor(h.id).errorMessage, isNull);
    final modelReply = h.provider.requests.last.messages.singleWhere(
      (message) =>
          message.role == ProviderRole.tool &&
          message.toolCallId == question.toolCallId,
    );
    expect(jsonDecode(modelReply.text)['answers'], [
      AgentQuestionAnswer(questionId: 'detail', text: _answer).toJson(),
    ]);
  });
}

ConversationMessage _reply(
  Iterable<ConversationMessage> messages,
  String toolCallId,
) => messages.singleWhere(
  (message) =>
      message.role == ConversationRole.tool && message.toolCallId == toolCallId,
);

void _expectResult(ConversationMessage reply, AgentQuestionRequest question) {
  final result = jsonDecode(reply.text) as Map;
  expect(result['questionId'], question.id);
  expect(result['status'], question.dismissed ? 'dismissed' : 'answered');
  expect(
    result['answers'],
    question.answers?.map((answer) => answer.toJson()).toList() ?? [],
  );
}

ProviderResponse _ask() => _call('ask-question', 'ask_user', {
  'questions': [
    {'id': 'detail', 'question': 'Which part of the day should I use?'},
  ],
});

ProviderResponse _call(
  String id,
  String name,
  Map<String, Object?> arguments,
) => ProviderResponse(
  text: '',
  toolCalls: [
    ProviderToolCall(id: id, name: name, arguments: jsonEncode(arguments)),
  ],
  finishReason: 'tool_calls',
);

ProviderResponse _done() => ProviderResponse(
  text: 'The revised task is complete.',
  toolCalls: [],
  finishReason: 'stop',
);

class _StoppedAnswer {
  const _StoppedAnswer(this.userMessageId, this.question, this.answerSnapshot);
  final String userMessageId;
  final AgentQuestionRequest question;
  final String answerSnapshot;
}

class _Harness {
  final storage = WorkspaceMemoryStorage(
    buildInitialAppData(buildDefaultPeriodTimes()),
  );
  final chats = _Chats();
  final credentials = MemoryAgentCredentialStore();
  final provider = _Provider();
  late AppRuntime app;
  late String id;

  static Future<_Harness> create() async {
    final h = _Harness();
    await h.open();
    await h.app.agent.configure(
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
    );
    await h.app.agent.setEnabled(true);
    h.id = (await h.app.agent.conversations.create(
      title: 'Question history',
      mode: AgentPermissionMode.full,
    )).id;
    return h;
  }

  AgentConversation get current => app.agent.conversations.find(id)!;

  Future<void> open() async {
    app = await workspaceProvider(
      storage: storage,
      agentConversationStorage: chats,
      agentCredentialStore: credentials,
      agentProvider: provider,
    );
  }

  Future<void> restart(String source) async {
    await close();
    chats.source = source;
    await open();
    await app.agent.initialize();
  }

  Future<_StoppedAnswer> stopAfterAnswer({
    bool dismissed = false,
    bool createCalendar = false,
  }) async {
    var round = 0;
    provider.respond = (request) {
      if (!createCalendar) return _ask();
      return switch (round++) {
        0 => _call('discover', 'capabilities.describe', {
          'names': ['mutation.prepare', 'mutation.commit'],
        }),
        1 => _call('prepare', 'mutation.prepare', {
          'commands': [
            {
              'kind': 'calendar',
              'action': 'create',
              'values': {'name': 'Question history calendar'},
            },
          ],
        }),
        2 => _call('commit', 'mutation.commit', {
          'planId': (jsonDecode(
            request.messages
                .lastWhere((message) => message.role == ProviderRole.tool)
                .text,
          ) as Map)['planId'],
        }),
        _ => _ask(),
      };
    };
    final running = app.agent.runtime.send(id, 'Original question task');
    await waitForQuestion();
    final question = current.pendingQuestion!;
    String? answerSnapshot;
    chats.didSave = (archive) {
      final pending = archive.conversations.single.pendingQuestion;
      if (answerSnapshot == null && pending?.isResolved == true) {
        answerSnapshot = chats.source!;
        unawaited(app.agent.runtime.stop(id));
      }
    };
    if (dismissed) {
      await app.agent.runtime.dismissQuestion(id, question.id);
    } else {
      await app.agent.runtime.answerQuestion(id, question.id, [
        AgentQuestionAnswer(questionId: 'detail', text: _answer),
      ]);
    }
    chats.didSave = null;
    await running;
    expect(current.pendingQuestion!.isResolved, true);
    expect(answerSnapshot, isNotNull);
    return _StoppedAnswer(
      current.messages.first.id,
      current.pendingQuestion!,
      answerSnapshot!,
    );
  }

  Future<void> waitForQuestion() => waitUntil(
    () =>
        app.agent.runtime.state.value.runFor(id).phase ==
        AgentUiPhase.waitingUser,
  );

  Future<void> waitUntil(bool Function() predicate) async {
    if (predicate()) return;
    final ready = Completer<void>();
    void changed() {
      if (!ready.isCompleted && predicate()) ready.complete();
    }

    app.agent.runtime.state.addListener(changed);
    app.agent.conversations.addListener(changed);
    try {
      changed();
      await ready.future.timeout(const Duration(seconds: 5));
    } finally {
      app.agent.runtime.state.removeListener(changed);
      app.agent.conversations.removeListener(changed);
    }
  }

  Future<void> close() async {
    await app.agent.quiesce();
    app.dispose();
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  ProviderResponse Function(ProviderRequest) respond = (_) => _done();
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(respond(request));
  }
}

class _Chats extends ConversationStorage {
  _Chats() : super.base();
  String? source;
  Future<void> Function(ConversationArchive)? beforeSave;
  void Function(ConversationArchive)? didSave;
  AgentConversation get saved =>
      ConversationArchive.decode(source!).conversations.single;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    final archive = ConversationArchive.decode(value);
    await beforeSave?.call(archive);
    source = value;
    didSave?.call(archive);
  }
}
