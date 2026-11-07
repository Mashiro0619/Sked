import '../context/context_checkpoint.dart';
import 'agent_store.dart';

class SqliteContextCheckpointStore implements ContextCheckpointStore {
  const SqliteContextCheckpointStore(this.store);
  final AgentStore store;

  @override
  Future<ContextCheckpoint?> latest(String conversationId) async {
    final value = await store.latestContextCheckpoint(conversationId);
    return value == null ? null : ContextCheckpoint.fromJson(value);
  }

  @override
  Future<void> append(
    ContextCheckpoint checkpoint, {
    void Function()? validate,
  }) => store.appendContextCheckpoint(checkpoint.toJson(), validate: validate);

  @override
  Future<void> clear(String conversationId) =>
      store.clearContextCheckpoints(conversationId);

  @override
  Future<ContextCompactionFailure?> failedSource(
    String conversationId,
    String sourceKey,
  ) async {
    final value = await store.readRecord(
      'context_failure',
      conversationId,
      sourceKey,
    );
    return value == null ? null : ContextCompactionFailure.fromJson(value);
  }

  @override
  Future<void> saveFailure(ContextCompactionFailure failure) => store.putRecord(
    'context_failure',
    failure.conversationId,
    failure.sourceKey,
    failure.toJson(),
  );

  @override
  Future<void> clearFailure(String conversationId, String sourceKey) =>
      store.deleteRecord('context_failure', conversationId, sourceKey);
}
