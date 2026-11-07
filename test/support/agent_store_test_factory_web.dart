import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sked/agent/store/agent_store.dart';

import 'agent_store_test_lifecycle.dart';

var _sequence = 0;

AgentStore createTestAgentStore({Zone? lifecycleZone}) =>
    TestLifecycleAgentStore(
      AgentDatabase(
        LazyDatabase(() async {
          final name = 'sked-agent-test-${_sequence++}';
          final probe = await WasmDatabase.probe(
            databaseName: name,
            sqlite3Uri: Uri.parse('/sqlite3.wasm'),
            driftWorkerUri: Uri.parse('/drift_worker.js'),
          );
          final connection = await probe.open(
            WasmStorageImplementation.inMemory,
            name,
          );
          return connection.executor;
        }),
      ),
      lifecycleZone: lifecycleZone,
    );
