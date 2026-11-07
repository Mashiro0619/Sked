import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/application_ledger.dart';
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

  for (final change in ['none', 'references', 'connection', 'generation']) {
    test(
      'ending redo preserves a saved answer with $change context changes',
      () async {
        final h = await harness();
        await h.referenceTimetable();
        final stopped = await h.stopAfterAnswer(redo: true);
        final batch = h.current.pendingRedo!;
        final requests = h.provider.requests.length;
        switch (change) {
          case 'references':
            await h.app.agent.history.replacePendingReferences(h.id, const []);
          case 'connection':
            await h.app.agent.configure(
              h.app.agent.settings.copyWith(
                endpoint: 'https://changed.example/v1',
              ),
            );
          case 'generation':
            await h.changeGeneration();
        }
        await h.app.agent.history.endRedo(h.id, batchId: batch.id);
        expect(h.provider.requests.length, requests);
        final ended = h.chats.saved;
        expect(ended.pendingRedo, isNull);
        expect(ended.pendingQuestion, isNull);
        expect(ended.redoBatches.single.phase, ConversationRedoPhase.abandoned);
        final reply = _reply(ended.messages, stopped.question.toolCallId);
        _expectResult(reply, stopped.question);
        final result = jsonDecode(reply.text) as Map;
        expect(result['contextChanged'], change == 'none' ? isNull : isTrue);
        expect(ended.turns.single.messageIds, contains(reply.id));
        expect(
          ended.runs.last.tools.single.outcome,
          ConversationAttemptOutcome.completed,
        );
        if (change == 'none' || change == 'references') {
          h.provider.respond = (_) => _done();
          await h.app.agent.runtime.send(
            h.id,
            'Continue with the current selection',
          );
          final forwarded = h.provider.requests.last.messages.singleWhere(
            (message) => message.toolCallId == stopped.question.toolCallId,
          );
          expect(jsonDecode(forwarded.text), result);
        }
      },
    );
  }

  test(
    'ending redo rechecks question context after a queued conversation reload',
    () async {
      final h = await harness();
      final stopped = await h.stopAfterAnswer(redo: true);
      final batchId = h.current.pendingRedo!.id;
      final entered = Completer<void>();
      final release = Completer<void>();
      h.chats.beforeLoad = () async {
        entered.complete();
        await release.future;
      };
      // Reloading unchanged storage occupies the serialized queue without
      // changing the transcript. End redo reads context after this is released.
      final loading = h.app.agent.conversations.load();
      await entered.future.timeout(const Duration(seconds: 5));
      final blockedTail = h.app.agent.conversations.waitForPendingWrites();
      final ending = h.app.agent.history.endRedo(h.id, batchId: batchId);
      try {
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
        expect(
          identical(
            h.app.agent.conversations.waitForPendingWrites(),
            blockedTail,
          ),
          isFalse,
          reason: 'End redo reached its queued save before context changes.',
        );
        await h.changeGeneration();
      } finally {
        h.chats.beforeLoad = null;
        release.complete();
      }
      await loading;
      await ending;
      final result = jsonDecode(
        _reply(h.chats.saved.messages, stopped.question.toolCallId).text,
      ) as Map;
      expect(result['contextChanged'], isTrue);
      _expectResult(
        _reply(h.chats.saved.messages, stopped.question.toolCallId),
        stopped.question,
      );
    },
  );

  test('failed redo exit keeps the saved answer and retries its context annotation', () async {
    final h = await harness();
    await h.referenceTimetable();
    final stopped = await h.stopAfterAnswer(redo: true);
    final batchId = h.current.pendingRedo!.id;
    await h.app.agent.history.replacePendingReferences(h.id, const []);
    final before = h.chats.source;
    final calls = h.provider.requests.length;
    h.chats.beforeSave = (archive) async {
      if (archive.conversations.single.pendingRedo == null) {
        throw const ConversationStorageException('Synthetic redo exit failure');
      }
    };
    await expectLater(
      h.app.agent.history.endRedo(h.id, batchId: batchId),
      throwsA(isA<ConversationStorageException>()),
    );
    expect(h.chats.source, before);
    expect(h.current.pendingQuestion!.toJson(), stopped.question.toJson());
    expect(h.current.pendingRedo!.id, batchId);
    h.chats.beforeSave = null;
    await h.app.agent.conversations.load();
    await h.app.agent.history.endRedo(h.id, batchId: batchId);
    final reply = _reply(h.chats.saved.messages, stopped.question.toolCallId);
    expect((jsonDecode(reply.text) as Map)['contextChanged'], isTrue);
    _expectResult(reply, stopped.question);
    expect(h.provider.requests.length, calls);
  });

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
    await h.restart(stopped.answerSnapshot);
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
    await h.app.agent.runtime.waitForIdle().timeout(const Duration(seconds: 5));
    expect(h.provider.requests, hasLength(2));
    expect(h.app.agent.runtime.isRunning(h.id), isFalse);
    expect(h.app.agent.runtime.pendingInputCount(h.id), 0);

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
    bool redo = false,
  }) async {
    if (redo) {
      provider.respond = (_) => _done();
      await app.agent.runtime.send(id, 'Original task before redo');
    }
    var round = 0;
    provider.respond = (_) {
      if (!createCalendar) return _ask();
      return switch (round++) {
        0 => _call('discover', 'capabilities.describe', {
          'names': ['mutation.apply'],
        }),
        1 => _call('apply', 'mutation.apply', {
          'commands': [
            {
              'kind': 'calendar',
              'action': 'create',
              'values': {'name': 'Question history calendar'},
            },
          ],
        }),
        _ => _ask(),
      };
    };
    final running = redo
        ? app.agent.history.editAndRedo(
            id,
            current.messages.first.id,
            'Ask before choosing a date',
          )
        : app.agent.runtime.send(id, 'Original question task');
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
    expect(answerSnapshot, isNotNull);
    final accepted = ConversationArchive.decode(answerSnapshot!)
        .conversations
        .single
        .pendingQuestion!;
    expect(accepted.isResolved, isTrue);
    expect(current.pendingQuestion, isNull);
    _expectResult(_reply(current.messages, accepted.toolCallId), accepted);
    // Resume the actual durable boundary before the tool reply for tests of
    // unfinished redo answers. A normal Stop now settles the accepted answer.
    if (redo) await restart(answerSnapshot!);
    return _StoppedAnswer(current.messages.first.id, accepted, answerSnapshot!);
  }

  Future<void> referenceTimetable() async {
    final initial = app.session.committedData;
    final table = TimetableData(
      id: 'question-reference-table',
      config: TimetableConfig(
        name: 'Question reference timetable',
        startDate: DateTime(2026, 11, 2),
        totalWeeks: 16,
        periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
      ),
      courses: const [],
    );
    final changed = initial.copyWith(
      studentMode: initial.studentMode.copyWith(
        activeTimetableId: table.id,
        timetables: [...initial.studentMode.timetables, table],
      ),
    );
    app.session.replaceData(changed);
    await app.session.persist(changed);
    await app.agent.updateComposerReferences(id, [
      AgentComposerReference.resource(
        ref: ResourceRef(kind: ResourceKind.timetable, id: table.id),
        datasetGeneration: app.agent.mutations.generation,
        label: table.config.name,
      ),
    ]);
  }

  Future<void> changeGeneration() async {
    expect(app.session.committedData.applicationLedger!.receipts, isEmpty);
    final changed = app.session.committedData.copyWith(
      applicationLedger: ApplicationLedger(
        generation: '00000000-0000-4000-8000-000000000003',
      ),
    );
    app.session.replaceData(changed);
    await app.session.persist(changed);
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

    final conversationRun = app.agent.runtime.watchConversation(id);
    conversationRun.addListener(changed);
    app.agent.conversations.addListener(changed);
    try {
      changed();
      await ready.future.timeout(const Duration(seconds: 5));
    } finally {
      conversationRun.removeListener(changed);
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
  Future<void> Function()? beforeLoad;
  Future<void> Function(ConversationArchive)? beforeSave;
  void Function(ConversationArchive)? didSave;
  AgentConversation get saved =>
      ConversationArchive.decode(source!).conversations.single;
  @override
  Future<ConversationStorageLoad> load() async {
    await beforeLoad?.call();
    return ConversationStorageLoad(source: source);
  }

  @override
  Future<void> save(String value, {required int revision}) async {
    final archive = ConversationArchive.decode(value);
    await beforeSave?.call(archive);
    source = value;
    didSave?.call(archive);
  }
}
