import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/application/operation_contracts.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();

  String? source;
  int saves = 0;
  bool failBeforeSave = false;
  bool failAfterSave = false;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    saves++;
    if (failBeforeSave) throw StateError('synthetic save refused');
    source = value;
    if (failAfterSave) throw StateError('synthetic save acknowledgement lost');
  }
}

void main() {
  late _Storage storage;
  late ConversationRepository repository;
  final now = DateTime.utc(2026, 11, 5);

  ConversationMessage firstMessage({String text = 'First request'}) =>
      ConversationMessage(
        id: 'first-message',
        role: ConversationRole.user,
        text: text,
        createdAt: now,
      );

  Future<void> promote(String id) async {
    await repository.update(
      id,
      (current) => current.copyWith(messages: [firstMessage()], draft: ''),
    );
  }

  setUp(() async {
    storage = _Storage();
    var sequence = 0;
    repository = ConversationRepository(
      storage: storage,
      clock: () => now,
      idGenerator: () => 'conversation-${sequence++}',
    );
    await repository.load();
  });
  tearDown(() => repository.dispose());

  test(
    'opening and reusing new chat never writes or creates history rows',
    () async {
      final first = await repository.createDraft(title: 'New chat');
      await repository.update(
        first.id,
        (current) => current.copyWith(draft: 'Keep this input'),
      );
      final repeated = await repository.createDraft(title: 'New chat');
      expect(repeated.id, first.id);
      expect(repeated.draft, 'Keep this input');
      expect(repository.selectedId, first.id);
      expect(repository.draftConversation, repeated);
      expect(repository.isDraft(first.id), isTrue);
      expect(repository.conversations, isEmpty);
      expect(repository.ownedConversations, [repeated]);
      expect(storage.saves, 0);
      expect(storage.source, isNull);
    },
  );

  test(
    'saved selection and unrelated writes do not persist or lose the draft',
    () async {
      final saved = await repository.create(title: 'Saved');
      final draft = await repository.createDraft(title: 'New chat');
      await repository.update(
        draft.id,
        (current) => current.copyWith(draft: 'Only in memory'),
      );
      final savedWrites = storage.saves;
      await repository.select(saved.id);
      expect(storage.saves, savedWrites);
      expect(repository.selectedId, saved.id);
      await repository.update(
        saved.id,
        (current) => current.copyWith(title: 'Renamed'),
      );
      final archive = ConversationArchive.decode(storage.source!);
      expect(archive.conversations.map((item) => item.id), [saved.id]);
      expect(archive.selectedId, saved.id);
      await repository.createDraft(title: 'New chat');
      expect(repository.selectedId, draft.id);
      expect(repository.selected!.draft, 'Only in memory');
      expect(storage.saves, savedWrites + 1);
    },
  );

  test(
    'the first accepted user message promotes the draft as one durable unit',
    () async {
      final draft = await repository.createDraft(title: 'New chat');
      await repository.update(
        draft.id,
        (current) => current.copyWith(
          draft: 'First request',
          mode: AgentPermissionMode.plan,
        ),
      );
      await promote(draft.id);
      expect(storage.saves, 1);
      expect(repository.isDraft(draft.id), isFalse);
      expect(repository.draftConversation, isNull);
      expect(repository.selectedId, draft.id);
      final archive = ConversationArchive.decode(storage.source!);
      expect(archive.conversations, hasLength(1));
      expect(
        archive.conversations.single.messages.single.text,
        'First request',
      );
      expect(archive.conversations.single.draft, isEmpty);
      expect(archive.conversations.single.mode, AgentPermissionMode.plan);
      await repository.update(
        draft.id,
        (current) => current.copyWith(draft: 'Next input'),
      );
      expect(storage.saves, 2);
      final nextDraft = await repository.createDraft(title: 'New chat');
      expect(nextDraft.id, isNot(draft.id));
      expect(repository.conversations, hasLength(1));
      expect(storage.saves, 2);
    },
  );

  test(
    'late first-message acceptance does not override a newer saved selection',
    () async {
      final saved = await repository.create(title: 'Saved');
      final draft = await repository.createDraft(title: 'New chat');
      await repository.select(saved.id);
      await promote(draft.id);
      expect(repository.selectedId, saved.id);
      expect(repository.find(draft.id)!.messages.single.text, 'First request');
      expect(ConversationArchive.decode(storage.source!).selectedId, saved.id);
      expect(repository.draftConversation, isNull);
    },
  );

  test('a rejected first save retains input and retries only after actual recovery', () async {
    final draft = await repository.createDraft(title: 'New chat');
    await repository.update(
      draft.id,
      (current) => current.copyWith(draft: 'Keep me'),
    );
    storage.failBeforeSave = true;
    await expectLater(promote(draft.id), throwsStateError);
    expect(storage.source, isNull);
    expect(repository.conversations, isEmpty);
    expect(repository.selected!.draft, 'Keep me');
    expect(repository.blocked, isTrue);
    storage.failBeforeSave = false;
    await repository.load();
    expect(repository.isDraft(draft.id), isTrue);
    expect(repository.selected!.draft, 'Keep me');
    await promote(draft.id);
    expect(repository.conversations, hasLength(1));
    expect(repository.draftConversation, isNull);
  });

  test(
    'lost save acknowledgement reconciles the same draft identity on reload',
    () async {
      final draft = await repository.createDraft(title: 'New chat');
      storage.failAfterSave = true;
      await expectLater(promote(draft.id), throwsStateError);
      expect(repository.isDraft(draft.id), isTrue);
      storage.failAfterSave = false;
      await repository.load();
      expect(repository.isDraft(draft.id), isFalse);
      expect(repository.conversations, hasLength(1));
      expect(repository.selectedId, draft.id);
      expect(repository.selected!.messages.single.text, 'First request');
      expect(storage.saves, 1);
    },
  );

  test(
    'a restart preserves saved chats and drops all unsent conversation state',
    () async {
      final saved = await repository.create(title: 'Saved');
      final draft = await repository.createDraft(title: 'New chat');
      await repository.update(
        draft.id,
        (current) => current.copyWith(draft: 'Unsent'),
      );
      final restarted = ConversationRepository(storage: storage);
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.find(draft.id), isNull);
      expect(restarted.draftConversation, isNull);
      expect(restarted.selectedId, saved.id);
      expect(storage.saves, 1);
    },
  );

  test(
    'dropping an unsent chat never writes a tombstone or alters saved history',
    () async {
      final saved = await repository.create(title: 'Saved');
      final draft = await repository.createDraft(title: 'New chat');
      final source = storage.source;
      await repository.delete(draft.id);
      expect(repository.selectedId, saved.id);
      expect(repository.find(draft.id), isNull);
      expect(storage.source, source);
      expect(storage.saves, 1);
      expect(
        ConversationArchive.decode(storage.source!).terminatedIds,
        isEmpty,
      );
      await expectLater(
        repository.update(draft.id, (current) => current),
        throwsA(isA<OperationProblem>()),
      );
    },
  );

  test('history retention never leaks the selected unsent identity into the archive', () async {
    var date = DateTime.utc(2026, 1, 1);
    final history = ConversationRepository(storage: storage, clock: () => date);
    addTearDown(history.dispose);
    await history.load();
    final expired = await history.create(title: 'Expired');
    date = now;
    final draft = await history.createDraft(title: 'New chat');
    expect(await history.pruneHistory(days: 30, canRemove: (_) => true), 1);
    expect(history.find(expired.id), isNull);
    expect(history.selectedId, draft.id);
    final archive = ConversationArchive.decode(storage.source!);
    expect(archive.conversations, isEmpty);
    expect(archive.selectedId, isNull);
    expect(archive.terminatedIds, {expired.id});
  });

  test('ordinary backup reads preserve draft but successful restore invalidates it', () async {
    await repository.create(title: 'Saved');
    final draft = await repository.createDraft(title: 'New chat');
    await repository.update(
      draft.id,
      (current) => current.copyWith(draft: 'Unsent'),
    );
    repository.freeze();
    final archive = await repository.readFrozenForRestore(validateOwner: () {});
    expect(archive.conversations, hasLength(1));
    expect(repository.draftConversation!.draft, 'Unsent');
    repository.resumeAfterMaintenance();
    expect(repository.selectedId, draft.id);
    repository.freeze();
    await repository.replaceFrozenForRestore(
      ConversationArchive(revision: archive.revision + 1),
      validateOwner: () {},
    );
    repository.resumeAfterMaintenance();
    expect(repository.draftConversation, isNull);
    expect(repository.selected, isNull);
    expect(repository.conversations, isEmpty);
  });

  test(
    'failed data clear invalidates unsent input before storage recovery',
    () async {
      final draft = await repository.createDraft(title: 'New chat');
      repository.freeze();
      repository.resumeAfterFailedDataClear();
      expect(repository.find(draft.id), isNull);
      expect(repository.blocked, isTrue);
      await repository.load();
      expect(repository.draftConversation, isNull);
      expect(storage.saves, 0);
    },
  );

  test('reviewed school handoff persists its first message without consuming the draft', () async {
    final draft = await repository.createDraft(title: 'New chat');
    final accepted = await repository.handoff(
      handoffId: 'school-handoff',
      source: const ConversationSource(
        id: 'school-source',
        text: '<table>synthetic timetable</table>',
        kind: 'schoolWeb',
      ),
      title: 'School import',
      prompt: 'Import the reviewed timetable',
    );
    expect(storage.saves, 1);
    expect(repository.selectedId, accepted.conversation.id);
    expect(repository.draftConversation!.id, draft.id);
    final archive = ConversationArchive.decode(storage.source!);
    expect(
      archive.conversations.single.messages.single.text,
      'Import the reviewed timetable',
    );
    expect(archive.handoffs.single.conversationId, accepted.conversation.id);
    expect(archive.conversations.any((item) => item.id == draft.id), isFalse);
  });
}
