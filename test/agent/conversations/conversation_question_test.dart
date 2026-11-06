import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_portable_history.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_storage_codec.dart';
import 'package:sked/agent/interactions/agent_question.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);

  AgentQuestionRequest question() => AgentQuestionRequest(
    id: 'question',
    toolCallId: 'ask-call',
    runId: 'run',
    requestMessageId: 'assistant',
    createdAt: now,
    connectionFingerprint: 'fixture-connection',
    datasetGeneration: 'fixture-data',
    questions: [
      AgentQuestionPrompt(
        id: 'date',
        question: 'When does the semester begin?',
      ),
    ],
  );

  AgentConversation conversation({AgentQuestionRequest? pending}) {
    final request = pending ?? question();
    return AgentConversation(
      id: 'conversation',
      title: 'Question',
      createdAt: now,
      updatedAt: now,
      status: ConversationStatus.waitingUser,
      runId: 'run',
      connectionFingerprint: request.connectionFingerprint,
      pendingQuestion: request,
      messages: [
        ConversationMessage(
          id: 'user',
          role: ConversationRole.user,
          text: 'Import my timetable',
          createdAt: now,
        ),
        ConversationMessage(
          id: 'assistant',
          role: ConversationRole.assistant,
          text: '',
          createdAt: now,
          toolCalls: [
            ConversationToolCall(
              id: 'ask-call',
              name: 'ask_user',
              arguments: jsonEncode({
                'questions': request.questions
                    .map((question) => question.toJson())
                    .toList(),
              }),
            ),
          ],
        ),
      ],
      runs: [
        ConversationRunUsage(
          id: 'run',
          startedAt: now,
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'fixture-model',
        ),
      ],
    );
  }

  test(
    'current archive persists pending answers and supports explicit removal',
    () {
      final pending =
          AgentQuestionRequest.fromJson({
            ...question().toJson(),
            'contextReferenceDigest': 'a' * 64,
          }).withAnswers([
            AgentQuestionAnswer(questionId: 'date', text: '2026-09-01'),
          ]);
      final source = ConversationArchive(
        conversations: [conversation(pending: pending)],
      ).encode();
      expect(
        (jsonDecode(source) as Map)['version'],
        ConversationArchive.currentVersion,
      );
      final restored = ConversationArchive.decode(source).conversations.single;
      expect(restored.pendingQuestion!.toJson(), pending.toJson());
      expect(restored.pendingQuestion!.contextReferenceDigest, 'a' * 64);
      expect(
        restored.copyWith(title: 'Renamed').pendingQuestion,
        same(restored.pendingQuestion),
      );
      expect(
        restored.copyWith(clearPendingQuestion: true).pendingQuestion,
        isNull,
      );
      final dismissed = conversation(pending: question().withDismissed());
      expect(
        AgentConversation.fromJson(
          Map<String, dynamic>.from(dismissed.toJson()),
        ).pendingQuestion!.dismissed,
        isTrue,
      );
    },
  );

  test(
    'versions one through five decode without manufacturing a question wait',
    () {
      final legacy = conversation().copyWith(
        clearPendingQuestion: true,
        status: ConversationStatus.idle,
      );
      for (var version = 1; version <= 5; version++) {
        final json = jsonDecode(
          ConversationArchive(conversations: [legacy]).encode(),
        ) as Map<String, dynamic>;
        json['version'] = version;
        expect(
          ConversationArchive.decode(jsonEncode(json))
              .conversations
              .single
              .pendingQuestion,
          isNull,
        );
        final pendingJson = jsonDecode(
          ConversationArchive(conversations: [conversation()]).encode(),
        ) as Map<String, dynamic>;
        pendingJson['version'] = version;
        expect(
          () => ConversationArchive.decode(jsonEncode(pendingJson)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'pending questions require the original executable assistant call and run',
    () {
      final source = conversation();
      for (final update in <Map<String, Object?>>[
        {'requestMessageId': 'missing'},
        {'requestMessageId': 'user'},
        {'toolCallId': 'missing'},
        {'runId': 'missing'},
        {
          'questions': [
            {'id': 'date', 'question': 'A substituted question'},
          ],
        },
      ]) {
        final json = Map<String, dynamic>.from(source.toJson());
        json['pendingQuestion'] = {...question().toJson(), ...update};
        expect(() => AgentConversation.fromJson(json), throwsFormatException);
      }
      expect(
        () => source.copyWith(executionHistoryStart: source.messages.length),
        throwsFormatException,
      );
      final json = Map<String, dynamic>.from(source.toJson());
      final messages = json['messages'] as List;
      ((messages.last as Map)['toolCalls'] as List).single['name'] =
          'resources.query';
      expect(() => AgentConversation.fromJson(json), throwsFormatException);
    },
  );

  test('restart interrupts waiting runs while preserving unanswered or resolved input', () async {
    for (final pending in [
      question(),
      question().withDismissed(),
      question().withAnswers([
        AgentQuestionAnswer(questionId: 'date', text: '2026-09-01'),
      ]),
    ]) {
      final storage = _QuestionStorage(
        ConversationArchive(conversations: [conversation(pending: pending)])
            .encode(),
      );
      final repository = ConversationRepository(
        storage: storage,
        clock: () => now,
      );
      addTearDown(repository.dispose);
      await repository.load();
      final restored = repository.find('conversation')!;
      expect(restored.status, ConversationStatus.interrupted);
      expect(restored.runs.single.status, ConversationRunStatus.interrupted);
      expect(restored.pendingQuestion!.toJson(), pending.toJson());
      expect(
        ConversationArchive.decode(storage.source)
            .conversations
            .single
            .pendingQuestion!
            .toJson(),
        pending.toJson(),
      );
    }
  });

  test('portable history clears execution waits and preserves questions and answer messages', () {
    final pending = question().withAnswers([
      AgentQuestionAnswer(questionId: 'date', text: '2026-09-01'),
    ]);
    final source = conversation(pending: pending);
    final answerMessage = ConversationMessage(
      id: 'answer',
      role: ConversationRole.tool,
      text: jsonEncode({
        'answers': pending.answers!.map((answer) => answer.toJson()).toList(),
      }),
      createdAt: now,
      toolCallId: pending.toolCallId,
    );
    final portable = conversationAsPortableHistory(
      source.copyWith(messages: [...source.messages, answerMessage]),
    );
    expect(portable.pendingQuestion, isNull);
    expect(portable.status, ConversationStatus.idle);
    expect(portable.runId, isNull);
    expect(portable.connectionFingerprint, isNull);
    expect(portable.runs, isEmpty);
    expect(portable.executionMessages, isEmpty);
    expect(
      portable.messages[1].toolCalls.single.arguments,
      source.messages[1].toolCalls.single.arguments,
    );
    expect(portable.messages.last.text, answerMessage.text);
    expect(
      AgentConversation.fromJson(Map<String, dynamic>.from(portable.toJson()))
          .pendingQuestion,
      isNull,
    );
  });

  test(
    'failed answer persistence preserves the unresolved question on reload',
    () async {
      final storage = _QuestionStorage(
        ConversationArchive(conversations: [conversation()]).encode(),
      );
      final repository = ConversationRepository(
        storage: storage,
        clock: () => now,
      );
      addTearDown(repository.dispose);
      await repository.load();
      final before = storage.source;
      storage.failSave = true;
      await expectLater(
        repository.update(
          'conversation',
          (current) => current.copyWith(
            pendingQuestion: current.pendingQuestion!.withAnswers([
              AgentQuestionAnswer(questionId: 'date', text: '2026-09-01'),
            ]),
          ),
        ),
        throwsStateError,
      );
      expect(storage.source, before);
      expect(
        repository.find('conversation')!.pendingQuestion!.isResolved,
        isFalse,
      );
      storage.failSave = false;
      await repository.load();
      expect(
        repository.find('conversation')!.pendingQuestion!.isResolved,
        isFalse,
      );
    },
  );

  test(
    'retention keeps a pending interaction even if its display status is idle',
    () async {
      final source = conversation().copyWith(
        status: ConversationStatus.idle,
        runs: [conversation().runs.single.interrupt()],
      );
      final storage = _QuestionStorage(
        ConversationArchive(conversations: [source]).encode(),
      );
      final repository = ConversationRepository(
        storage: storage,
        clock: () => now.add(const Duration(days: 60)),
      );
      addTearDown(repository.dispose);
      await repository.load();
      expect(await repository.pruneHistory(days: 7, canRemove: (_) => true), 0);
      expect(repository.find('conversation')!.pendingQuestion, isNotNull);
    },
  );

  test('future question archive blocks fallback to an older readable slot', () {
    final archive = ConversationArchive(conversations: [conversation()])
        .encode();
    final future = jsonDecode(archive) as Map<String, dynamic>;
    future['version'] = ConversationArchive.currentVersion + 1;
    final futureSource = jsonEncode(future);
    final futureSlot = jsonEncode({
      'version': 1,
      'revision': 0,
      'checksum': sha256.convert(utf8.encode(futureSource)).toString(),
      'source': futureSource,
    });
    expect(
      () => decodeConversationSlots([
        futureSlot,
        encodeConversationSlot(archive, 0),
      ]),
      throwsA(isA<ConversationStorageException>()),
    );
  });
}

class _QuestionStorage extends ConversationStorage {
  _QuestionStorage(this.source) : super.base();

  String source;
  bool failSave = false;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    if (failSave) throw StateError('Synthetic question save failure');
    source = value;
  }
}
