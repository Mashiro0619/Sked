import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_portable_history.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/application/resource_contracts.dart';

final _now = DateTime.utc(2026, 11, 7);

void main() {
  test('message and draft references round trip in the current archive', () {
    final source = _conversation();
    final encoded = ConversationArchive(conversations: [source]).encode();
    expect(
      (jsonDecode(encoded) as Map)['version'],
      ConversationArchive.currentVersion,
    );
    final restored = ConversationArchive.decode(encoded).conversations.single;
    expect(
      _json(restored.messages.single.contextReferences),
      _json(source.messages.single.contextReferences),
    );
    expect(_json(restored.draftReferences), _json(source.draftReferences));
    expect(
      () => restored.messages.single.contextReferences.clear(),
      throwsUnsupportedError,
    );
    expect(() => restored.draftReferences.clear(), throwsUnsupportedError);
    final input = [_resource()];
    final message = _message(references: input, attachmentIds: const []);
    final draft = _bareConversation().copyWith(draftReferences: input);
    input.clear();
    expect(message.contextReferences, hasLength(1));
    expect(draft.draftReferences, hasLength(1));
  });

  test('retired archives cannot manufacture new composer references', () {
    final legacy = _bareConversation().copyWith(
      messages: [_message(references: const [], attachmentIds: const [])],
    );
    for (var version = 1; version <= 6; version++) {
      Map<String, dynamic> archive() =>
          (jsonDecode(ConversationArchive(conversations: [legacy]).encode())
                as Map<String, dynamic>)
            ..['version'] = version;
      expect(
        () => ConversationArchive.decode(jsonEncode(archive())),
        throwsFormatException,
      );
      final draftField = archive();
      ((draftField['conversations'] as List).single as Map)['draftReferences'] =
          [];
      expect(
        () => ConversationArchive.decode(jsonEncode(draftField)),
        throwsFormatException,
      );
      final messageField = archive();
      final messageOwner =
          (messageField['conversations'] as List).single as Map;
      ((messageOwner['messages'] as List).single as Map)['contextReferences'] =
          [];
      expect(
        () => ConversationArchive.decode(jsonEncode(messageField)),
        throwsFormatException,
      );
      final historyField = archive();
      final historyOwner =
          (historyField['conversations'] as List).single as Map;
      historyOwner['historyVersions'] = [
        _history(_message(references: const [], attachmentIds: const []))
            .toJson(),
      ];
      final history = (historyOwner['historyVersions'] as List).single as Map;
      ((history['messages'] as List).single as Map)['contextReferences'] = null;
      expect(
        () => ConversationArchive.decode(jsonEncode(historyField)),
        throwsFormatException,
      );
    }
  });

  test(
    'retired v6 questions cannot restore executable waits in the new archive',
    () {
      final pending = AgentQuestionRequest(
        id: 'question',
        toolCallId: 'ask-call',
        runId: 'run',
        requestMessageId: 'ask-message',
        createdAt: _now,
        connectionFingerprint: 'connection',
        questions: [AgentQuestionPrompt(id: 'date', question: 'Which date?')],
      );
      final source = _bareConversation().copyWith(
        status: ConversationStatus.waitingUser,
        pendingQuestion: pending,
        messages: [
          ConversationMessage(
            id: 'ask-message',
            role: ConversationRole.assistant,
            text: '',
            createdAt: _now,
            toolCalls: [
              ConversationToolCall(
                id: 'ask-call',
                name: 'ask_user',
                arguments: jsonEncode({
                  'questions': pending.questions
                      .map((item) => item.toJson())
                      .toList(),
                }),
              ),
            ],
          ),
        ],
        runs: [
          ConversationRunUsage(
            id: 'run',
            startedAt: _now,
            kind: ConversationRunKind.model,
            protocol: 'chatCompletions',
            model: 'fixture',
          ),
        ],
      );
      final json = jsonDecode(
        ConversationArchive(conversations: [source]).encode(),
      ) as Map<String, dynamic>;
      json['version'] = 6;
      expect(
        () => ConversationArchive.decode(jsonEncode(json)),
        throwsFormatException,
      );
    },
  );

  test('attachment references require message membership and matching conversation metadata', () {
    final reference = _attachmentReference();
    expect(
      () => _message(references: [reference], attachmentIds: const []),
      throwsFormatException,
    );
    expect(
      () => _bareConversation().copyWith(
        messages: [
          _message(references: [reference]),
        ],
      ),
      throwsFormatException,
    );
    for (final invalid in [
      AgentComposerReference.fromJson({
        ...reference.toJson(),
        'conversationId': 'foreign',
      }),
      AgentComposerReference.fromJson({
        ...reference.toJson(),
        'digest': 'b' * 64,
      }),
    ]) {
      expect(
        () => _bareConversation().copyWith(
          attachments: [_attachment()],
          messages: [
            _message(references: [invalid]),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => _bareConversation().copyWith(
          attachments: [_attachment()],
          draftAttachmentIds: ['file'],
          draftReferences: [invalid],
        ),
        throwsFormatException,
      );
      expect(
        () => _bareConversation().copyWith(
          attachments: [_attachment()],
          historyVersions: [
            _history(_message(references: [invalid])),
          ],
        ),
        throwsFormatException,
      );
    }
    expect(
      () => ConversationMessage(
        id: 'assistant',
        role: ConversationRole.assistant,
        text: 'Response',
        createdAt: _now,
        contextReferences: [_resource()],
      ),
      throwsFormatException,
    );
    expect(
      () => _message(
        references: [_resource(), _resource()],
        attachmentIds: const [],
      ),
      throwsFormatException,
    );
    expect(
      _bareConversation()
          .copyWith(
            draftReferences: List.generate(
              21,
              (index) => _resource(id: '$index'),
            ),
          )
          .draftReferences,
      hasLength(21),
    );
  });

  test('removing attached files filters implicit references while explicit conflicts fail', () {
    final source = _conversation();
    final message = source.messages.single;
    final withoutMessageFile = message.copyWith(attachmentIds: const []);
    expect(
      withoutMessageFile.contextReferences.map((reference) => reference.kind),
      [AgentComposerReferenceKind.resource, AgentComposerReferenceKind.skill],
    );
    expect(
      () => message.copyWith(
        attachmentIds: const [],
        contextReferences: message.contextReferences,
      ),
      throwsFormatException,
    );
    final withoutDraftFile = source.copyWith(draftAttachmentIds: const []);
    expect(
      withoutDraftFile.draftReferences.map((reference) => reference.kind),
      [AgentComposerReferenceKind.resource],
    );
    expect(
      () => source.copyWith(
        draftAttachmentIds: const [],
        draftReferences: source.draftReferences,
      ),
      throwsFormatException,
    );
    expect(message.copyWith(contextReferences: const []).attachmentIds, [
      'file',
    ]);
  });

  test('portable current and retired messages retain references while drafts are cleared', () {
    final source = _conversation().copyWith(
      historyVersions: [_history(_message(id: 'old-user'))],
    );
    final portable = conversationAsPortableHistory(source);
    expect(portable.draftReferences, isEmpty);
    expect(portable.draftAttachmentIds, isEmpty);
    expect(portable.executionMessages, isEmpty);
    expect(
      _json(portable.messages.single.contextReferences),
      _json(source.messages.single.contextReferences),
    );
    expect(
      _json(portable.historyVersions.single.messages.single.contextReferences),
      _json(source.historyVersions.single.messages.single.contextReferences),
    );
    final restored = ConversationArchive.decode(
      ConversationArchive(conversations: [portable]).encode(),
    ).conversations.single;
    expect(
      restored.historyVersions.single.messages.single.contextReferences,
      hasLength(3),
    );
    final historyOnly = source.copyWith(
      messages: const [],
      draftAttachmentIds: const [],
      draftReferences: const [],
    );
    expect(conversationAttachmentIds(historyOnly), {'file'});
  });

  test('draft reference updates explicitly reattach owned historical files in one save', () async {
    final storage = _Storage(
      source: ConversationArchive(
        conversations: [
          _conversation().copyWith(
            draftReferences: const [],
            draftAttachmentIds: const [],
          ),
        ],
      ).encode(),
    );
    final repository = ConversationRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    var validated = false;
    final updated = await repository.updateDraftReferences(
      'chat',
      [_attachmentReference()],
      validate: (current) {
        validated = true;
        expect(current.draftAttachmentIds, isEmpty);
      },
    );
    expect(validated, isTrue);
    expect(updated.draftAttachmentIds, ['file']);
    expect(updated.draftReferences.single.attachmentId, 'file');
    expect(
      ConversationArchive.decode(storage.source!)
          .conversations
          .single
          .draftReferences
          .single
          .attachmentDigest,
      'a' * 64,
    );
    final snapshot = storage.source;
    await expectLater(
      repository.updateDraftReferences('chat', [
        AgentComposerReference.fromJson({
          ..._attachmentReference().toJson(),
          'conversationId': 'foreign',
        }),
      ]),
      throwsFormatException,
    );
    expect(storage.source, snapshot);
    expect(
      repository.find('chat')!.draftReferences.single.conversationId,
      'chat',
    );
  });

  test('queued draft replacements freeze inputs and validate the latest conversation', () async {
    final storage = _Storage();
    final repository = ConversationRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    final chat = await repository.create(title: 'References');
    final entered = Completer<void>();
    final release = Completer<void>();
    storage.beforeSave = (_) async {
      if (!entered.isCompleted) {
        entered.complete();
        await release.future;
      }
    };
    final first = repository.updateDraftReferences(chat.id, [
      _resource(id: 'first'),
    ]);
    await entered.future;
    final secondInput = [_resource(id: 'second')];
    final second = repository.updateDraftReferences(
      chat.id,
      secondInput,
      validate: (current) {
        expect(current.draftReferences.single.resourceRef!.id, 'first');
      },
    );
    secondInput.clear();
    release.complete();
    await first;
    await second;
    expect(
      repository.find(chat.id)!.draftReferences.single.resourceRef!.id,
      'second',
    );
  });

  test('failed saves preserve draft references and unsent drafts retain memory-only behavior', () async {
    final storage = _Storage();
    final repository = ConversationRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    final draft = await repository.createDraft(title: 'Unsent');
    await repository.updateDraftReferences(draft.id, [_resource()]);
    expect(repository.draftConversation!.draftReferences, hasLength(1));
    expect(storage.source, isNull);
    final chat = await repository.create(title: 'Durable');
    await repository.updateDraftReferences(chat.id, [_resource(id: 'saved')]);
    final before = storage.source;
    storage.failSave = true;
    await expectLater(
      repository.updateDraftReferences(chat.id, [_resource(id: 'failed')]),
      throwsStateError,
    );
    expect(storage.source, before);
    expect(
      repository.find(chat.id)!.draftReferences.single.resourceRef!.id,
      'saved',
    );
    storage.failSave = false;
    await repository.load();
    expect(
      repository.find(chat.id)!.draftReferences.single.resourceRef!.id,
      'saved',
    );
  });

  test('reference-only durable drafts survive retention', () async {
    var now = DateTime.utc(2026, 1, 1);
    final repository = ConversationRepository(
      storage: _Storage(),
      clock: () => now,
    );
    addTearDown(repository.dispose);
    await repository.load();
    final retained = await repository.create(title: 'Referenced draft');
    final expired = await repository.create(title: 'Completed');
    await repository.updateDraftReferences(retained.id, [_resource()]);
    now = DateTime.utc(2026, 3, 1);
    expect(await repository.pruneHistory(days: 30, canRemove: (_) => true), 1);
    expect(repository.find(retained.id), isNotNull);
    expect(repository.find(expired.id), isNull);
  });
}

AgentComposerReference _resource({String id = 'table'}) =>
    AgentComposerReference.resource(
      ref: ResourceRef(kind: ResourceKind.timetable, id: id),
      datasetGeneration: 'source-generation',
      label: 'Source timetable',
    );

AgentComposerReference _skill() => AgentComposerReference.skill(
  skill: SkillDescriptor.editable(
    id: 'plan-week',
    title: 'Plan week',
    summary: '',
    body: 'Use the current plan.',
    revision: 1,
  ),
);

ConversationAttachment _attachment() => ConversationAttachment(
  id: 'file',
  name: 'week.pdf',
  mediaType: 'application/pdf',
  byteLength: 10,
  digest: 'a' * 64,
);

AgentComposerReference _attachmentReference() =>
    AgentComposerReference.attachment(
      attachment: _attachment(),
      conversationId: 'chat',
    );

ConversationMessage _message({
  String id = 'user',
  List<AgentComposerReference>? references,
  List<String> attachmentIds = const ['file'],
}) => ConversationMessage(
  id: id,
  role: ConversationRole.user,
  text: 'Use the selected context',
  createdAt: _now,
  attachmentIds: attachmentIds,
  contextReferences:
      references ?? [_resource(), _skill(), _attachmentReference()],
);

AgentConversation _bareConversation() => AgentConversation(
  id: 'chat',
  title: 'References',
  createdAt: _now,
  updatedAt: _now,
);

AgentConversation _conversation() => _bareConversation().copyWith(
  attachments: [_attachment()],
  messages: [_message()],
  draftAttachmentIds: ['file'],
  draftReferences: [_resource(), _attachmentReference()],
);

ConversationHistoryVersion _history(ConversationMessage message) =>
    ConversationHistoryVersion(
      id: 'history',
      batchId: 'batch',
      createdAt: _now,
      messages: [message],
      runs: const [],
      turns: const [],
    );

List<Map<String, Object?>> _json(Iterable<AgentComposerReference> references) =>
    references.map((reference) => reference.toJson()).toList();

class _Storage extends ConversationStorage {
  _Storage({this.source}) : super.base();
  String? source;
  bool failSave = false;
  Future<void> Function(String value)? beforeSave;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    if (failSave) throw StateError('Synthetic reference save failure');
    await beforeSave?.call(value);
    source = value;
  }
}
