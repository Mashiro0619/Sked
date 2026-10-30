import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/imports/conversation_file_attachments.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  bool fail = false;
  bool loseAcknowledgement = false;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    if (fail) throw StateError('storage failure');
    source = value;
    if (loseAcknowledgement) throw StateError('acknowledgement lost');
  }
}

void main() {
  late _Storage storage;
  late ConversationRepository repository;
  late ConversationFileAttachments attachments;
  late String id;
  setUp(() async {
    storage = _Storage();
    repository = ConversationRepository(storage: storage);
    await repository.load();
    id = (await repository.create(title: 'Attachment test')).id;
    attachments = ConversationFileAttachments(repository);
  });
  tearDown(() => repository.dispose());

  Future<void> attach(String text, {String name = 'calendar.ics'}) =>
      attachments.attach(
        id,
        PickedTextFile(name: name, text: text),
        generation: 'dataset',
        locale: 'en',
        canModify: () => true,
      );

  test('attachment is immutable local material and removable only before a later input boundary', () async {
    const text = 'BEGIN:VCALENDAR\nEND:VCALENDAR';
    await attach(text);
    var conversation = repository.find(id)!;
    final source = conversation.sources.single;
    expect(source.kind, 'structured_file');
    expect(source.text, text);
    expect(source.truncated, isFalse);
    expect(conversation.messages, isEmpty);
    expect(ConversationFileAttachments.canRemove(conversation, source), isTrue);
    final restored = ConversationArchive.decode(storage.source!)
        .conversations
        .single
        .sources
        .single;
    expect(restored.digest, source.digest);
    expect(restored.provenance!.title, 'calendar.ics');
    await repository.update(id, (value) => value.copyWith(runId: 'later-run'));
    conversation = repository.find(id)!;
    expect(
      ConversationFileAttachments.canRemove(conversation, source),
      isFalse,
    );
    await expectLater(
      attachments.remove(id, source.id, canModify: () => true),
      throwsStateError,
    );
    expect(repository.find(id)!.sources.single.text, text);
  });

  test('new files after prior runs record both boundaries and can be removed before reuse', () async {
    await repository.update(
      id,
      (value) => value.copyWith(
        runId: 'prior-run',
        messages: [
          ConversationMessage(
            id: 'prior-message',
            role: ConversationRole.user,
            text: 'Earlier request',
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    await attach('{"courses":[]}', name: 'classes.json');
    final source = repository.find(id)!.sources.single;
    final restored = ConversationSource.fromJson(
      Map<String, dynamic>.from(source.toJson()),
    );
    expect(restored.attachedAfterRunId, 'prior-run');
    expect(restored.attachedAfterMessageId, 'prior-message');
    await attachments.remove(id, source.id, canModify: () => true);
    expect(repository.find(id)!.sources, isEmpty);
    expect(repository.find(id)!.messages.single.text, 'Earlier request');
  });

  test('byte limits reject content without silently truncating or accepting binary formats', () async {
    await expectLater(
      attach('中' * (ConversationFileAttachments.maxBytes ~/ 3 + 1)),
      throwsA(isA<TextFileTooLargeException>()),
    );
    await expectLater(
      attach('text', name: 'document.pdf'),
      throwsFormatException,
    );
    expect(repository.find(id)!.sources, isEmpty);
    expect(attachments.pending(id), isNull);
  });

  test('explicit recovery retries the same source id after failure and acknowledgement loss', () async {
    storage.fail = true;
    await expectLater(
      attach('first file', name: 'notes.txt'),
      throwsStateError,
    );
    final sourceId = attachments.pending(id)!.id;
    expect(repository.canWrite, isFalse);
    expect(repository.find(id)!.sources, isEmpty);
    storage.fail = false;
    await repository.load();
    storage.loseAcknowledgement = true;
    await expectLater(
      attachments.retry(id, generation: 'dataset', canModify: () => true),
      throwsStateError,
    );
    storage.loseAcknowledgement = false;
    await repository.load();
    await attachments.retry(id, generation: 'dataset', canModify: () => true);
    expect(repository.find(id)!.sources.map((source) => source.id), [sourceId]);
    expect(attachments.pending(id), isNull);
  });

  test(
    'a changed target or restored dataset rejects pending attachments',
    () async {
      storage.fail = true;
      await expectLater(attach('pending', name: 'notes.txt'), throwsStateError);
      storage.fail = false;
      await repository.load();
      await expectLater(
        attachments.retry(
          id,
          generation: 'restored-dataset',
          canModify: () => true,
        ),
        throwsStateError,
      );
      await repository.update(
        id,
        (value) => value.copyWith(runId: 'another-run'),
      );
      await expectLater(
        attachments.retry(id, generation: 'dataset', canModify: () => true),
        throwsStateError,
      );
      expect(repository.find(id)!.sources, isEmpty);
      attachments.discardPending(id);
      expect(attachments.pending(id), isNull);
    },
  );

  test('optional attachment boundaries leave legacy webpage JSON and digest unchanged', () {
    const source = ConversationSource(
      id: 'web-source',
      kind: 'school_web',
      text: 'Reviewed webpage',
    );
    final encoded = jsonEncode(source.toJson());
    expect(encoded, isNot(contains('attachedAfter')));
    expect(
      ConversationSource.fromJson(jsonDecode(encoded) as Map<String, dynamic>)
          .digest,
      source.digest,
    );
  });
}
