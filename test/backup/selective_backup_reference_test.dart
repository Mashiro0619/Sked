import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test('attachment collision remaps current and historical references with their declared files', () {
    final data = buildInitialAppData(buildDefaultPeriodTimes());
    final source = _conversation();
    final sourceInventory = buildSelectiveBackupInventory(
      appData: data,
      conversations: [source],
    );
    final local = AgentConversation(
      id: 'local-chat',
      title: 'Existing',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      attachments: [_attachment(digest: 'b' * 64)],
    );
    final currentInventory = buildSelectiveBackupInventory(
      appData: data,
      conversations: [local],
    );
    final plan = const SelectiveBackupPlanner().prepare(
      source: sourceInventory,
      current: currentInventory,
      selection: BackupSelection(
        objects: const [BackupObjectKey(BackupObjectKind.conversation, 'chat')],
      ),
    );
    final mapped = plan
        .mapping[const BackupObjectKey(BackupObjectKind.attachment, 'file')]!
        .id;
    expect(mapped, isNot('file'));
    final record = plan.changes
        .singleWhere(
          (change) =>
              change.after.key ==
              const BackupObjectKey(BackupObjectKind.conversation, 'chat'),
        )
        .after;
    final restored = restorePortableConversation(
      record,
      currentMode: AgentPermissionMode.plan,
    );
    for (final message in [
      restored.messages.single,
      restored.historyVersions.single.messages.single,
    ]) {
      expect(message.attachmentIds, [mapped]);
      final attachment = message.contextReferences.singleWhere(
        (reference) => reference.kind == AgentComposerReferenceKind.attachment,
      );
      expect(attachment.attachmentId, mapped);
      expect(attachment.conversationId, 'chat');
      expect(attachment.attachmentDigest, 'a' * 64);
      final resource = message.contextReferences.singleWhere(
        (reference) => reference.kind == AgentComposerReferenceKind.resource,
      );
      expect(resource.datasetGeneration, 'original-generation');
      expect(resource.resourceRef!.id, 'original-timetable');
    }
    expect(restored.attachments.single.id, mapped);
    expect(restored.draftReferences, isEmpty);
    expect(restored.executionMessages, isEmpty);
    expect(source.messages.single.attachmentIds, ['file']);
    expect(source.messages.single.contextReferences.last.attachmentId, 'file');
  });

  test('portable reference export clears draft input and preserves readable source identities', () {
    final source = _conversation();
    final data = portableConversationData(source);
    expect(data.containsKey('draftReferences'), isFalse);
    final restored = restorePortableConversation(
      BackupRecord(
        key: const BackupObjectKey(BackupObjectKind.conversation, 'chat'),
        label: 'Chat',
        data: data,
        dependencies: const [
          BackupObjectKey(BackupObjectKind.attachment, 'file'),
        ],
      ),
      currentMode: AgentPermissionMode.ask,
    );
    expect(restored.draftReferences, isEmpty);
    expect(
      restored.messages.single.contextReferences
          .map((reference) => reference.toJson())
          .toList(),
      source.messages.single.contextReferences
          .map((reference) => reference.toJson())
          .toList(),
    );
    expect(restored.executionHistoryStart, restored.messages.length);
  });

  test('restoring a repaired redo keeps cleared live bindings and original historical references', () {
    final original = _conversation();
    final repaired = original.copyWith(
      messages: original.messages.map(
        (message) => message.copyWith(contextReferences: const []),
      ),
      draftReferences: const [],
    );
    final rebound = rebindBackupRecord(
      BackupRecord(
        key: const BackupObjectKey(BackupObjectKind.conversation, 'chat'),
        label: 'Chat',
        data: portableConversationData(repaired),
        dependencies: const [
          BackupObjectKey(BackupObjectKind.attachment, 'file'),
        ],
      ),
      {
        const BackupObjectKey(BackupObjectKind.attachment, 'file'):
            const BackupObjectKey(BackupObjectKind.attachment, 'restored-file'),
      },
    );
    final restored = restorePortableConversation(
      rebound,
      currentMode: AgentPermissionMode.ask,
    );
    expect(restored.messages.single.contextReferences, isEmpty);
    expect(restored.messages.single.attachmentIds, ['restored-file']);
    final historical = restored.historyVersions.single.messages.single;
    expect(historical.contextReferences, hasLength(2));
    expect(
      historical.contextReferences.first.resourceRef!.id,
      'original-timetable',
    );
    expect(historical.contextReferences.last.attachmentId, 'restored-file');
    expect(restored.draftReferences, isEmpty);
    expect(restored.pendingRedo, isNull);
  });

  test('rebind never repairs a foreign attachment owner or enables conversation copies', () {
    final source = _conversation();
    final data = jsonDecode(
      jsonEncode(portableConversationData(source)),
    ) as Map<String, dynamic>;
    final message = (data['messages'] as List).single as Map;
    final references = message['contextReferences'] as List;
    (references.last as Map)['conversationId'] = 'foreign-chat';
    final record = BackupRecord(
      key: const BackupObjectKey(BackupObjectKind.conversation, 'chat'),
      label: 'Chat',
      data: data,
      dependencies: const [
        BackupObjectKey(BackupObjectKind.attachment, 'file'),
      ],
    );
    expect(
      () => rebindBackupRecord(record, {
        const BackupObjectKey(BackupObjectKind.attachment, 'file'):
            const BackupObjectKey(BackupObjectKind.attachment, 'copied-file'),
      }),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(
      () => rebindBackupRecord(record, {
        const BackupObjectKey(BackupObjectKind.conversation, 'chat'):
            const BackupObjectKey(BackupObjectKind.conversation, 'copied-chat'),
      }),
      throwsA(isA<SelectiveBackupException>()),
    );
  });
}

ConversationAttachment _attachment({String? digest}) => ConversationAttachment(
  id: 'file',
  name: 'file.pdf',
  mediaType: 'application/pdf',
  byteLength: 10,
  digest: digest ?? 'a' * 64,
);

AgentConversation _conversation() {
  final now = DateTime.utc(2026, 11, 7);
  final attachment = _attachment();
  final references = [
    AgentComposerReference.resource(
      ref: const ResourceRef(
        kind: ResourceKind.timetable,
        id: 'original-timetable',
      ),
      datasetGeneration: 'original-generation',
      label: 'Original timetable',
    ),
    AgentComposerReference.attachment(
      attachment: attachment,
      conversationId: 'chat',
    ),
  ];
  ConversationMessage message(String id) => ConversationMessage(
    id: id,
    role: ConversationRole.user,
    text: 'Use these inputs',
    createdAt: now,
    attachmentIds: [attachment.id],
    contextReferences: references,
  );
  return AgentConversation(
    id: 'chat',
    title: 'Chat',
    createdAt: now,
    updatedAt: now,
    attachments: [attachment],
    messages: [message('user')],
    draftAttachmentIds: [attachment.id],
    draftReferences: references,
    historyVersions: [
      ConversationHistoryVersion(
        id: 'old-version',
        batchId: 'batch',
        createdAt: now,
        messages: [message('old-user')],
        runs: const [],
        turns: const [],
      ),
    ],
  );
}
