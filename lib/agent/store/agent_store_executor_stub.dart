import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openAgentStoreExecutor({String? filePath}) =>
    DatabaseConnection.delayed(
      Future(() async {
        final result = await WasmDatabase.open(
          databaseName: 'Sked_agent',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        );
        if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
          await result.resolvedExecutor.close();
          throw StateError('The browser cannot persist the Agent database.');
        }
        return result.resolvedExecutor;
      }),
    );
