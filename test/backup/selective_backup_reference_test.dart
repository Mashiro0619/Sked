import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/backup/selective_backup_agent_data.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';

const _chat = BackupObjectKey(BackupObjectKind.conversation, 'chat');
const _file = BackupObjectKey(BackupObjectKind.attachment, 'file');

void main() {
  test(
    'attachment collision rebinds current and historical native references',
    () {
      final source = _inventory('chat', 'a' * 64);
      final current = _inventory('local-chat', 'b' * 64);
      final plan = const SelectiveBackupPlanner().prepare(
        source: source,
        current: current,
        selection: BackupSelection(objects: const [_chat]),
      );
      final mapped = plan.mapping[_file]!.id;
      expect(mapped, isNot('file'));
      final restored = plan.changes
          .singleWhere((change) => change.after.key == _chat)
          .after
          .data;
      for (final message in [
        (restored['messages'] as List).single as Map,
        (((restored['historyVersions'] as List).single as Map)['messages']
                    as List)
                .single
            as Map,
      ]) {
        expect(message['attachmentIds'], [mapped]);
        final references = message['contextReferences'] as List;
        final attachment = references.last as Map;
        expect(attachment['attachmentId'], mapped);
        expect(attachment['id'], 'attachment-reference');
        expect(attachment['conversationId'], 'chat');
        expect(attachment['attachmentDigest'], 'a' * 64);
        final resource = references.first as Map;
        expect(resource['datasetGeneration'], 'original-generation');
        expect((resource['resource'] as Map)['id'], 'original-timetable');
      }
      expect((restored['attachments'] as List).single['id'], mapped);
      expect(
        (source.byKey[_chat]!.data['messages'] as List).single['attachmentIds'],
        ['file'],
      );
      expect(current.byKey[_file]!.data['sha256'], 'b' * 64);
    },
  );

  test(
    'repaired live references stay cleared while historical references rebind',
    () {
      final data = _snapshot('chat', 'a' * 64);
      ((data['messages'] as List).single as Map)['contextReferences'] = [];
      final rebound = rebindBackupRecord(
        BackupRecord(
          key: _chat,
          label: 'Chat',
          data: data,
          dependencies: const [_file],
        ),
        {
          _file: const BackupObjectKey(
            BackupObjectKind.attachment,
            'copied-file',
          ),
        },
      );
      final message = (rebound.data['messages'] as List).single as Map;
      final historical =
          (((rebound.data['historyVersions'] as List).single as Map)['messages']
                      as List)
                  .single
              as Map;
      expect(message['contextReferences'], isEmpty);
      expect(message['attachmentIds'], ['copied-file']);
      final references = historical['contextReferences'] as List;
      expect(references.last['attachmentId'], 'copied-file');
      expect(references.first['resource']['id'], 'original-timetable');
    },
  );

  test('rebind rejects a foreign attachment owner and implicit conversation copies', () {
    final data = _snapshot('chat', 'a' * 64);
    final message = (data['messages'] as List).single as Map;
    ((message['contextReferences'] as List).last as Map)['conversationId'] =
        'foreign-chat';
    final record = BackupRecord(
      key: _chat,
      label: 'Chat',
      data: data,
      dependencies: const [_file],
    );
    expect(
      () => rebindBackupRecord(record, {
        _file: const BackupObjectKey(
          BackupObjectKind.attachment,
          'copied-file',
        ),
      }),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(
      () => rebindBackupRecord(record, {
        _chat: const BackupObjectKey(
          BackupObjectKind.conversation,
          'copied-chat',
        ),
      }),
      throwsA(isA<SelectiveBackupException>()),
    );
  });
}

SelectiveBackupBundle _inventory(String id, String digest) {
  final snapshot = _snapshot(id, digest);
  return SelectiveBackupBundle(
    records: nativeAgentBackupRecords({
      'conversations': [snapshot],
      'knowledge': const [],
      'attachments': snapshot['attachments'],
    }),
    roots: [BackupObjectKey(BackupObjectKind.conversation, id)],
  );
}

Map<String, Object?> _snapshot(String id, String digest) {
  Map<String, Object?> message() => {
    'id': 'message',
    'attachmentIds': ['file'],
    'contextReferences': [
      {
        'kind': 'resource',
        'id': 'resource-reference',
        'datasetGeneration': 'original-generation',
        'resource': {'kind': 'timetable', 'id': 'original-timetable'},
      },
      {
        'kind': 'attachment',
        'id': 'attachment-reference',
        'attachmentId': 'file',
        'conversationId': id,
        'attachmentDigest': digest,
      },
    ],
  };
  return jsonDecode(
    jsonEncode({
      'conversation': {'id': id, 'title': 'Chat', 'draftAttachmentIds': []},
      'messages': [message()],
      'historyVersions': [
        {
          'id': 'history',
          'messages': [message()],
        },
      ],
      'attachments': [
        {
          'id': 'file',
          'name': 'file.pdf',
          'mediaType': 'application/pdf',
          'byteLength': 10,
          'sha256': digest,
          'createdAt': 1790812800000,
        },
      ],
    }),
  ) as Map<String, Object?>;
}
