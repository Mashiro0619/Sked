import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/application/resource_contracts.dart';

final _now = DateTime.utc(2026, 11, 7);

void main() {
  test('message and draft reference DTOs round trip immutably', () {
    final source = _conversation();
    final restored = AgentConversation.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
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
