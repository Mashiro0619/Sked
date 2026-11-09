import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/imports/conversation_file_attachments.dart';

import '../../support/agent_memory_conversations.dart';

void main() {
  late MemoryConversationRepository repository;
  late ConversationFileAttachments attachments;
  late String id;
  setUp(() async {
    repository = MemoryConversationRepository();
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

  test('structured source retains provenance and is removable until bound to input', () async {
    const text = 'BEGIN:VCALENDAR\nEND:VCALENDAR';
    await attach(text);
    final source = repository.find(id)!.sources.single;
    expect(source.kind, 'structured_file');
    expect(source.text, text);
    expect(source.provenance!.title, 'calendar.ics');
    expect(
      ConversationFileAttachments.canRemove(repository.find(id)!, source),
      isTrue,
    );
    final bound = ConversationSource.fromJson({
      ...source.toJson(),
      'boundInputId': 'queued-input',
    });
    await repository.update(
      id,
      (current) => current.copyWith(sources: [bound]),
    );
    expect(
      ConversationFileAttachments.canRemove(repository.find(id)!, bound),
      isFalse,
    );
    await expectLater(
      attachments.remove(id, source.id, canModify: () => true),
      throwsStateError,
    );
  });

  test(
    'unused sources remain removable after earlier execution boundaries',
    () async {
      await repository.update(
        id,
        (current) => current.copyWith(
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
      expect(source.attachedAfterRunId, 'prior-run');
      expect(source.attachedAfterMessageId, 'prior-message');
      await attachments.remove(id, source.id, canModify: () => true);
      expect(repository.find(id)!.sources, isEmpty);
      expect(repository.find(id)!.messages.single.text, 'Earlier request');
    },
  );

  test('large structured text remains complete and binary formats use binary attachment flow', () async {
    final text = '中' * (512 * 1024 ~/ 3 + 1);
    await attach(text);
    expect(repository.find(id)!.sources.single.text, text);
    await attachments.remove(
      id,
      repository.find(id)!.sources.single.id,
      canModify: () => true,
    );
    await expectLater(
      attach('text', name: 'document.pdf'),
      throwsFormatException,
    );
    expect(repository.find(id)!.sources, isEmpty);
    expect(attachments.pending(id), isNull);
  });

  test(
    'source ownership metadata does not change the reviewed content digest',
    () {
      const source = ConversationSource(
        id: 'source',
        kind: 'school_web',
        text: 'Reviewed webpage',
      );
      final bound = ConversationSource.fromJson({
        ...source.toJson(),
        'boundInputId': 'queued',
        'boundMessageId': 'message',
      });
      expect(bound.digest, source.digest);
      expect(
        ConversationSource.fromJson(
          jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
        ).digest,
        source.digest,
      );
    },
  );
}
