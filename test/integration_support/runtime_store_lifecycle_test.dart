import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/app_runtime.dart';

import '../support/agent_store_test_lifecycle.dart';

class _FailingCloseExecutor implements QueryExecutor {
  int closes = 0;

  @override
  Future<void> close() async {
    closes++;
    throw StateError('Synthetic close failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('This fixture only closes a database.');
}

void main() {
  late Zone lifecycleZone;
  setUp(() => lifecycleZone = Zone.current);

  testWidgets(
    'runtime disposal keeps its cached store close awaitable outside FakeAsync',
    (tester) async {
      final app = AppRuntime();
      app.dispose();
      await tester.pump();
      await tester.runAsync(() => app.agent.store!.close());
    },
  );

  testWidgets(
    'database close failures stay catchable in the fixture error zone',
    (tester) async {
      final executor = _FailingCloseExecutor();
      final store = TestLifecycleAgentStore(
        AgentDatabase(executor),
        lifecycleZone: lifecycleZone,
      );
      await tester.runAsync(() => expectLater(store.close(), throwsStateError));
      await tester.runAsync(() => expectLater(store.close(), throwsStateError));
      expect(executor.closes, 1);
    },
  );
}
