import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/store/agent_store.dart';

import '../../../integration_test/support/agent_history_readback.dart';
import '../../../integration_test/support/agent_native_session.dart';

const _source = ConversationSource(
  id: 'source',
  text: 'Stored source',
  kind: 'text',
);

ConversationAttachment _attachment(String id) => ConversationAttachment(
  id: id,
  name: '$id.png',
  mediaType: 'image/png',
  byteLength: 1,
  digest: '0' * 64,
);

class _Fixture {
  _Fixture(this.store, this.repository);
  final AgentStore store;
  final ConversationRepository repository;

  Future<AgentConversation> readSaved() async => ConversationArchive.decode(
    (await store.conversations.readArchive()).encode(),
  ).conversations.singleWhere((item) => item.id == agentNativeLongId);

  Future<Map<String, Object?>> verify({AgentConversation? cached}) async =>
      verifyAgentHistoryReadback(
        saved: await readSaved(),
        cached: cached ?? repository.find(agentNativeLongId)!,
        fullyLoaded: repository.isConversationLoaded(agentNativeLongId),
        visibleMessages: repository.visibleMessages(agentNativeLongId),
        visibleTurns: repository.visibleTurns(agentNativeLongId),
      );
}

Future<_Fixture> _fixture({
  int executionHistoryStart = 0,
  bool withDraftAttachment = false,
}) async {
  final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
  final repository = ConversationRepository(storage: store.conversations);
  addTearDown(() async {
    repository.dispose();
    await store.close();
  });
  final original = agentNativeConversationFixture();
  final long = original.conversations.first;
  final messages = [...long.messages];
  messages[0] = messages[0].copyWith(attachmentIds: ['old']);
  messages[500] = messages[500].copyWith(attachmentIds: ['visible', 'second']);
  final stored = long.copyWith(
    messages: messages,
    sources: const [_source],
    attachments: [
      _attachment('old'),
      _attachment('second'),
      _attachment('visible'),
      _attachment('draft'),
    ],
    draftAttachmentIds: withDraftAttachment ? ['draft'] : [],
    executionHistoryStart: executionHistoryStart,
  );
  await store.conversations.writeArchive(
    ConversationArchive(
      selectedId: agentNativeLongId,
      conversations: [stored, original.conversations.last],
    ),
    previous: ConversationArchive(),
  );
  await repository.load();
  return _Fixture(store, repository);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compares all fields of the actual 512-message fixture page without hydrating it', () async {
    final fixture = await _fixture();
    final saved = await fixture.readSaved();
    final cached = fixture.repository.find(agentNativeLongId)!;
    final window = fixture.repository.visibleMessages(agentNativeLongId);
    expect(saved.messages, hasLength(512));
    expect(cached.messages, hasLength(50));
    expect(jsonEncode(cached.toJson()), isNot(jsonEncode(saved.toJson())));
    expect(cached.attachments.map((item) => item.id), ['visible', 'second']);
    expect(cached.sources, isEmpty);
    final result = await fixture.verify();
    expect(result['mode'], 'paged');
    expect(result['visibleStart'], 462);
    expect(fixture.repository.isConversationLoaded(agentNativeLongId), isFalse);
    expect(fixture.repository.find(agentNativeLongId), same(cached));
    expect(fixture.repository.visibleMessages(agentNativeLongId), same(window));
    expect(
      jsonEncode((await fixture.readSaved()).toJson()),
      jsonEncode(saved.toJson()),
    );
  });

  test(
    'a direct SQLite page puts draft attachments before message attachments',
    () async {
      final fixture = await _fixture(withDraftAttachment: true);
      expect(
        fixture.repository.isConversationLoaded(agentNativeLongId),
        isTrue,
      );
      final page = await fixture.store.readConversationPage(agentNativeLongId);
      expect(page.conversation.attachments.map((item) => item.id), [
        'draft',
        'visible',
        'second',
      ]);
      final result = verifyAgentHistoryReadback(
        saved: await fixture.readSaved(),
        cached: page.conversation,
        fullyLoaded: false,
        visibleMessages: page.conversation.messages,
        visibleTurns: page.turns,
      );
      expect(result['mode'], 'paged');
      expect(
        fixture.repository.isConversationLoaded(agentNativeLongId),
        isTrue,
      );
    },
  );

  test('expanded and fully paginated windows remain paged objects', () async {
    final fixture = await _fixture();
    await fixture.repository.loadEarlierMessages(agentNativeLongId);
    expect((await fixture.verify())['cachedMessageCount'], 100);
    while (fixture.repository.hasEarlierMessages(agentNativeLongId)) {
      await fixture.repository.loadEarlierMessages(agentNativeLongId);
    }
    final result = await fixture.verify();
    expect(result['mode'], 'paged');
    expect(result['cachedMessageCount'], 512);
    expect(result['visibleStart'], 0);
    expect(fixture.repository.isConversationLoaded(agentNativeLongId), isFalse);
    expect(fixture.repository.find(agentNativeLongId)!.sources, isEmpty);
  });

  test('a real mutation hydrates complete collections and retains the visible anchor', () async {
    final fixture = await _fixture();
    final firstVisible = fixture.repository
        .visibleMessages(agentNativeLongId)
        .first
        .id;
    await fixture.repository.update(
      agentNativeLongId,
      (value) => value.copyWith(draft: 'Saved next draft'),
    );
    await fixture.repository.waitForPendingWrites();
    final result = await fixture.verify();
    expect(result['mode'], 'full');
    expect(result['cachedMessageCount'], 512);
    expect(fixture.repository.find(agentNativeLongId)!.sources, hasLength(1));
    expect(
      fixture.repository.visibleMessages(agentNativeLongId).first.id,
      firstVisible,
    );
  });

  test(
    'imported execution boundaries are relative to the actual page',
    () async {
      final fixture = await _fixture(executionHistoryStart: 480);
      expect((await fixture.verify())['cachedExecutionHistoryStart'], 18);
      await fixture.repository.loadEarlierMessages(agentNativeLongId);
      expect((await fixture.verify())['cachedExecutionHistoryStart'], 68);
      final wrong = fixture.repository
          .find(agentNativeLongId)!
          .copyWith(executionHistoryStart: 67);
      await expectLater(fixture.verify(cached: wrong), throwsStateError);
    },
  );

  test(
    'rejects changed page metadata and leaked unloaded collections',
    () async {
      final fixture = await _fixture();
      final cached = fixture.repository.find(agentNativeLongId)!;
      await expectLater(
        fixture.verify(cached: cached.copyWith(draft: 'Wrong draft')),
        throwsStateError,
      );
      await expectLater(
        fixture.verify(cached: cached.copyWith(sources: const [_source])),
        throwsStateError,
      );
      await expectLater(
        fixture.verify(
          cached: cached.copyWith(attachments: cached.attachments.reversed),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'full-object comparison catches changed history outside the visible page',
    () async {
      final fixture = await _fixture();
      await fixture.repository.update(
        agentNativeLongId,
        (value) => value.copyWith(draft: 'Hydrated draft'),
      );
      final cached = fixture.repository.find(agentNativeLongId)!;
      final messages = [...cached.messages];
      messages[0] = messages[0].copyWith(text: 'Wrong hidden history');
      await expectLater(
        fixture.verify(cached: cached.copyWith(messages: messages)),
        throwsStateError,
      );
    },
  );
}
