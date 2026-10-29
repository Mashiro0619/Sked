import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_storage_codec.dart';
import 'package:sked/agent/conversations/conversation_storage_io.dart'
    as native;
import 'package:sked/agent/conversations/conversation_storage_stub.dart'
    as browser;
import 'package:sked/services/app_storage_layout_io.dart';

void main() {
  final first = ConversationArchive(revision: 1).encode();
  final second = ConversationArchive(revision: 2).encode();

  test(
    'slots choose the latest validated revision and report torn-write recovery',
    () {
      final old = encodeConversationSlot(first, 1);
      final next = encodeConversationSlot(second, 2);
      expect(decodeConversationSlots([next, old]).source, second);
      final recovered = decodeConversationSlots(['{"version":1', old]);
      expect(recovered.source, first);
      expect(recovered.recovered, isTrue);
      expect(
        () => decodeConversationSlots(['broken', null]),
        throwsA(isA<ConversationStorageException>()),
      );
    },
  );

  test('checksum damage cannot win over an intact previous slot', () {
    final tampered =
        jsonDecode(encodeConversationSlot(second, 2)) as Map<String, dynamic>;
    tampered['source'] = first;
    final loaded = decodeConversationSlots([
      jsonEncode(tampered),
      encodeConversationSlot(first, 1),
    ]);
    expect(loaded.source, first);
    expect(loaded.recovered, isTrue);
  });

  test('a future slot blocks fallback so an older app cannot overwrite it', () {
    expect(
      () => decodeConversationSlots([
        jsonEncode({'version': 2}),
        encodeConversationSlot(first, 1),
      ]),
      throwsA(isA<ConversationStorageException>()),
    );
  });

  test('native storage verifies round trip and recovers from a partial alternate slot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-agent-storage-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final storage = native.PlatformConversationStorage(
      layout: AppStorageLayout(directoryProvider: () async => directory),
    );
    expect((await storage.load()).source, isNull);
    await storage.save(first, revision: 1);
    await storage.save(second, revision: 2);
    expect((await storage.load()).source, second);
    await File('${directory.path}/Sked_agent_conversations.1.json')
        .writeAsString('{torn');
    final recovered = await storage.load();
    expect(recovered.source, second);
    expect(recovered.recovered, isTrue);
  });

  test('browser adapter verifies the same two-slot format', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = browser.PlatformConversationStorage();
    await storage.save(first, revision: 1);
    await storage.save(second, revision: 2);
    expect((await storage.load()).source, second);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${browser.PlatformConversationStorage.storageKeyPrefix}0',
      'broken',
    );
    final recovered = await storage.load();
    expect(recovered.source, second);
    expect(recovered.recovered, isTrue);
  });

  test(
    'successful deletion cannot be resurrected from the other native slot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-agent-delete-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = native.PlatformConversationStorage(
        layout: AppStorageLayout(directoryProvider: () async => directory),
      );
      final repository = ConversationRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      final conversation = await repository.create(
        title: 'private-deleted-title',
      );
      await repository.delete(conversation.id);
      for (var i = 0; i < 2; i++) {
        final contents = await File(
          '${directory.path}/Sked_agent_conversations.$i.json',
        ).readAsString();
        expect(contents, isNot(contains('private-deleted-title')));
      }
      await File('${directory.path}/Sked_agent_conversations.0.json')
          .writeAsString('{damaged');
      final recovered = ConversationArchive.decode(
        (await storage.load()).source!,
      );
      expect(recovered.conversations, isEmpty);
      expect(recovered.terminatedIds, contains(conversation.id));
    },
  );
}
