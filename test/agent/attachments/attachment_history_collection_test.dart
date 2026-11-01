import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';

void main() {
  test('replaced history keeps its only binary reference until durable history and metadata removal', () async {
    final storage = _ConversationMemory();
    final conversations = ConversationRepository(storage: storage);
    await conversations.load();
    final id = (await conversations.create(title: 'History references')).id;
    final repository = AttachmentRepository(storage: MemoryAttachmentStorage());
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    addTearDown(() async {
      files.dispose();
      await repository.close();
      conversations.dispose();
    });
    await files.attach(
      id,
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        path: 'history.pdf',
        name: 'history.pdf',
      ),
      canModify: () => true,
    );
    final attachment = conversations.find(id)!.attachments.single;
    await conversations.update(
      id,
      (current) => current.copyWith(
        draftAttachmentIds: const [],
        historyVersions: [
          ConversationHistoryVersion(
            id: 'version',
            batchId: 'redo',
            createdAt: DateTime.utc(2026),
            messages: [
              ConversationMessage(
                id: 'old-request',
                role: ConversationRole.user,
                text: 'Read the attachment',
                createdAt: DateTime.utc(2026),
                attachmentIds: [attachment.id],
              ),
            ],
            runs: const [],
            turns: const [],
          ),
        ],
      ),
    );
    await conversations.load();
    await files.collectGarbage();
    expect(conversations.find(id)!.messages, isEmpty);
    expect(conversations.find(id)!.attachments.single.id, attachment.id);
    expect(await repository.readBytes(attachment), [1, 2, 3]);

    await conversations.update(
      id,
      (current) => current.copyWith(historyVersions: const []),
    );
    storage.failNextSave = true;
    await expectLater(files.collectGarbage(), throwsStateError);
    expect(await repository.storage.ids(), {attachment.id});
    expect(await repository.readBytes(attachment), [1, 2, 3]);

    await conversations.load();
    await files.collectGarbage();
    expect(conversations.find(id)!.attachments, isEmpty);
    expect(await repository.storage.ids(), isEmpty);
  });
}

class _ConversationMemory extends ConversationStorage {
  _ConversationMemory() : super.base();
  String? source;
  bool failNextSave = false;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Synthetic failure before metadata persistence.');
    }
    source = value;
  }
}
