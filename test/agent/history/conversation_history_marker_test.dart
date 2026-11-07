import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/store/agent_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'history ownership marker survives SQLite reopen and clears atomically',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-history-marker-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = '${directory.path}/agent.sqlite';
      final first = AgentStore.open(filePath: file);
      expect(await first.conversations.pendingHistoryBatch(), isNull);
      await first.conversations.writePendingHistoryBatch('batch-1');
      await first.close();
      final restarted = AgentStore.open(filePath: file);
      addTearDown(restarted.close);
      expect(await restarted.conversations.pendingHistoryBatch(), 'batch-1');
      await restarted.conversations.writePendingHistoryBatch(null);
      expect(await restarted.conversations.pendingHistoryBatch(), isNull);
    },
  );
}
