import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/conversations/conversation_storage_io.dart'
    as native;
import 'package:sked/agent/conversations/conversation_storage_stub.dart'
    as browser;
import 'package:sked/services/app_storage_layout_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native marker survives recreation and damaged admission fails closed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-history-marker-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final layout = AppStorageLayout(directoryProvider: () async => directory);
      final first = native.PlatformConversationStorage(layout: layout);
      expect(await first.pendingHistoryBatch(), isNull);
      await first.writePendingHistoryBatch('batch-1');
      final restarted = native.PlatformConversationStorage(layout: layout);
      expect(await restarted.pendingHistoryBatch(), 'batch-1');
      await restarted.writePendingHistoryBatch(null);
      expect(await first.pendingHistoryBatch(), isNull);
      await File('${directory.path}/Sked_agent_conversations.pending')
          .writeAsString('');
      await expectLater(
        first.pendingHistoryBatch(),
        throwsA(isA<ConversationStorageException>()),
      );
    },
  );
  test(
    'browser marker survives adapter recreation and rejects corrupt type',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = browser.PlatformConversationStorage();
      expect(await first.pendingHistoryBatch(), isNull);
      await first.writePendingHistoryBatch('batch-1');
      final restarted = browser.PlatformConversationStorage();
      expect(await restarted.pendingHistoryBatch(), 'batch-1');
      await restarted.writePendingHistoryBatch(null);
      expect(await first.pendingHistoryBatch(), isNull);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '${browser.PlatformConversationStorage.storageKeyPrefix}pending',
        42,
      );
      await expectLater(
        first.pendingHistoryBatch(),
        throwsA(isA<ConversationStorageException>()),
      );
    },
  );
}
