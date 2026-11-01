import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/history/conversation_redo_coordinator.dart';

void main() {
  test(
    'repeated edit submission shares one preparation and reserves one batch',
    () async {
      final fixture = _Fixture();
      fixture.store.persisted = null;
      final entered = Completer<void>(), release = Completer<void>();
      fixture.host.beforeStop = () async {
        entered.complete();
        await release.future;
      };
      Future<ConversationRedoBatch> prepare() => fixture.coordinator.prepare(
        batchId: 'redo',
        conversationId: 'chat',
        historyVersionId: 'history',
        replayRunId: 'run',
        createdAt: DateTime.utc(2026, 10, 31),
        readSelection: () async => _selection(),
        text: 'Changed',
        attachmentIds: [],
      );
      final first = prepare();
      await entered.future;
      final second = prepare();
      expect(identical(first, second), isTrue);
      release.complete();
      await Future.wait([first, second]);
      expect(fixture.host.stops, 1);
      expect(fixture.main.preparations, 1);
      expect(fixture.knowledge.preparations, 1);
      expect((await prepare()).id, 'redo');
      expect(fixture.host.stops, 1);
    },
  );

  test('a refused preflight can be cancelled without changing data', () async {
    final fixture = _Fixture();
    fixture.knowledge.conflict = true;
    await expectLater(
      fixture.coordinator.resume('redo'),
      throwsA(isA<ConversationHistoryException>()),
    );
    await fixture.coordinator.cancelPrepared('redo');
    expect(fixture.store.read('redo'), isNull);
    expect(fixture.main.value, 1);
    expect(fixture.knowledge.value, 1);
  });

  test(
    'conflict in the second owner leaves every business record unchanged',
    () async {
      final fixture = _Fixture();
      fixture.knowledge.conflict = true;
      await expectLater(
        fixture.coordinator.resume('redo'),
        throwsA(isA<ConversationHistoryException>()),
      );
      expect(fixture.main.value, 1);
      expect(fixture.knowledge.value, 1);
      expect(fixture.main.commitCount, 0);
      expect(fixture.host.replays, isEmpty);
      expect(fixture.store.read('redo')!.phase, ConversationRedoPhase.prepared);
    },
  );

  test('unknown knowledge save recovers the same batch without repeating main undo', () async {
    final fixture = _Fixture();
    fixture.knowledge.failAfterWrite = true;
    await expectLater(fixture.coordinator.resume('redo'), throwsStateError);
    expect(fixture.main.value, 0);
    expect(fixture.knowledge.value, 0);
    expect(fixture.host.replays, isEmpty);
    expect(fixture.store.read('redo')!.phase, ConversationRedoPhase.undoing);
    expect(fixture.store.read('redo')!.completedOwners, [
      ConversationUndoOwner.main,
    ]);

    // A process restart loses all in-process futures. Owners and the chat
    // expose only their durable state; neither inverse is prepared again.
    final restarted = ConversationRedoCoordinator(
      store: fixture.store,
      host: fixture.host,
      participants: [fixture.main, fixture.knowledge],
    );
    final completed = await restarted.resume('redo');
    expect(completed.phase, ConversationRedoPhase.completed);
    expect(fixture.main.commitCount, 1);
    expect(fixture.knowledge.commitCount, 1);
    expect(fixture.host.replays, ['reserved-run']);
    expect(fixture.store.published, 1);
  });

  test(
    'lost journal update after main save is reconciled from the owner receipt',
    () async {
      final fixture = _Fixture();
      fixture.store.failOnceWhen = (batch) =>
          batch.phase == ConversationRedoPhase.undoing &&
          batch.completedOwners.contains(ConversationUndoOwner.main);
      await expectLater(fixture.coordinator.resume('redo'), throwsStateError);
      expect(fixture.main.commitCount, 1);
      expect(fixture.knowledge.commitCount, 0);
      await fixture.coordinator.resume('redo');
      expect(fixture.main.commitCount, 1);
      expect(fixture.knowledge.commitCount, 1);
      expect(
        fixture.store.read('redo')!.phase,
        ConversationRedoPhase.completed,
      );
    },
  );

  test('duplicate clicks share one undo and one reserved run', () async {
    final fixture = _Fixture();
    final entered = Completer<void>(), release = Completer<void>();
    fixture.main.beforeCommit = () async {
      entered.complete();
      await release.future;
    };
    final first = fixture.coordinator.resume('redo');
    await entered.future;
    final second = fixture.coordinator.resume('redo');
    expect(identical(first, second), isTrue);
    release.complete();
    await Future.wait([first, second]);
    expect(fixture.main.commitCount, 1);
    expect(fixture.knowledge.commitCount, 1);
    expect(fixture.host.replays, ['reserved-run']);
  });

  test(
    'stopping the new run preserves completed undo and resumes only that run',
    () async {
      final fixture = _Fixture();
      fixture.host.outcome = ConversationReplayOutcome.interrupted;
      final stopped = await fixture.coordinator.resume('redo');
      expect(stopped.phase, ConversationRedoPhase.running);
      expect(stopped.lastError, ConversationHistoryError.cancelled.name);
      fixture.host.outcome = ConversationReplayOutcome.completed;
      await fixture.coordinator.resume('redo');
      expect(fixture.main.commitCount, 1);
      expect(fixture.knowledge.commitCount, 1);
      expect(fixture.store.published, 1);
      expect(fixture.host.replays, ['reserved-run', 'reserved-run']);
      expect(fixture.host.stops, 1);
      expect(fixture.store.read('redo')!.lastError, isNull);
    },
  );

  test(
    'a changed transcript is rejected before any owner begins undo',
    () async {
      final fixture = _Fixture();
      fixture.store.contextChanged = true;
      await expectLater(
        fixture.coordinator.resume('redo'),
        throwsA(isA<ConversationHistoryException>()),
      );
      expect(fixture.main.commitCount, 0);
      expect(fixture.knowledge.commitCount, 0);
      expect(fixture.store.published, 0);
    },
  );
}

class _Fixture {
  final main = _Participant(ConversationUndoOwner.main);
  final knowledge = _Participant(ConversationUndoOwner.knowledge);
  final store = _Store();
  final host = _Host();
  late final coordinator = ConversationRedoCoordinator(
    store: store,
    host: host,
    participants: [main, knowledge],
  );
}

class _Store implements ConversationRedoStore {
  _Store() {
    _save(
      ConversationRedoBatch(
        id: 'redo',
        conversationId: 'chat',
        sourceTurnId: 'turn',
        sourceMessageId: 'request',
        historyVersionId: 'version',
        replayRunId: 'reserved-run',
        createdAt: DateTime.utc(2026, 10, 31),
        text: 'Move the event to Tuesday',
        contextDigest: 'a' * 64,
        turnIds: ['turn'],
        attachmentIds: [],
        tickets: [
          for (final owner in ConversationUndoOwner.values)
            ConversationUndoTicket(
              owner: owner,
              token: 'redo-${owner.name}',
              digest: 'a' * 64,
              operationIds: ['${owner.name}-operation'],
            ),
        ],
      ),
    );
  }
  String? persisted;
  bool contextChanged = false;
  int published = 0;
  bool Function(ConversationRedoBatch)? failOnceWhen;

  void _save(ConversationRedoBatch batch) =>
      persisted = jsonEncode(batch.toJson());

  @override
  ConversationRedoBatch? read(String batchId) {
    if (persisted == null) return null;
    final batch = ConversationRedoBatch.fromJson(jsonDecode(persisted!));
    return batch.id == batchId ? batch : null;
  }

  @override
  Future<void> replace(
    ConversationRedoBatch next, {
    required ConversationRedoBatch? previous,
  }) async {
    if (jsonEncode(read(next.id)?.toJson()) != jsonEncode(previous?.toJson())) {
      throw const ConversationHistoryException(
        ConversationHistoryError.conflict,
      );
    }
    if (failOnceWhen?.call(next) == true) {
      failOnceWhen = null;
      throw StateError('journal write failed');
    }
    _save(next);
  }

  @override
  Future<void> discard(ConversationRedoBatch batch) async {
    if (jsonEncode(read(batch.id)?.toJson()) != jsonEncode(batch.toJson())) {
      throw const ConversationHistoryException(
        ConversationHistoryError.conflict,
      );
    }
    if (batch.phase != ConversationRedoPhase.prepared) {
      throw const ConversationHistoryException(ConversationHistoryError.busy);
    }
    persisted = null;
  }

  @override
  Future<void> validateContext(ConversationRedoBatch batch) async {
    if (contextChanged) {
      throw const ConversationHistoryException(
        ConversationHistoryError.conflict,
      );
    }
  }

  @override
  Future<ConversationRedoBatch> publishRequest(
    ConversationRedoBatch batch,
  ) async {
    final next = batch.copyWith(phase: ConversationRedoPhase.ready);
    await replace(next, previous: batch);
    published++;
    return next;
  }
}

class _Participant implements ConversationUndoParticipant {
  _Participant(this.owner);
  @override
  final ConversationUndoOwner owner;
  int value = 1;
  int commitCount = 0;
  int preparations = 0;
  bool conflict = false, failAfterWrite = false;
  Future<void> Function()? beforeCommit;

  @override
  Future<ConversationUndoTicket> prepare({
    required String batchId,
    required List<String> operationIds,
  }) async {
    preparations++;
    return ConversationUndoTicket(
      owner: owner,
      token: '$batchId-${owner.name}',
      digest: 'a' * 64,
      operationIds: operationIds,
    );
  }

  @override
  Future<ConversationUndoState> readState(
    ConversationUndoTicket ticket,
  ) async => value == 0
      ? ConversationUndoState.applied
      : ConversationUndoState.prepared;

  @override
  Future<void> validate(ConversationUndoTicket ticket) async {
    if (conflict) {
      throw const ConversationHistoryException(
        ConversationHistoryError.conflict,
      );
    }
  }

  @override
  Future<void> commit(ConversationUndoTicket ticket) async {
    await beforeCommit?.call();
    commitCount++;
    if (value != 1) throw StateError('inverse repeated');
    value = 0;
    if (failAfterWrite) {
      failAfterWrite = false;
      throw StateError('write completed without acknowledgment');
    }
  }
}

class _Host implements ConversationRedoHost {
  final replays = <String>[];
  int stops = 0;
  Future<void> Function()? beforeStop;
  ConversationReplayOutcome outcome = ConversationReplayOutcome.completed;
  @override
  Future<void> stopAndDiscardQueues(String conversationId) async {
    stops++;
    await beforeStop?.call();
  }

  @override
  Future<T> withUndoBarrier<T>(String batchId, Future<T> Function() action) =>
      action();
  @override
  Future<ConversationReplayOutcome> replay(ConversationRedoBatch batch) async {
    replays.add(batch.replayRunId);
    return outcome;
  }
}

ConversationHistorySelection _selection() {
  final request = ConversationMessage(
    id: 'request',
    role: ConversationRole.user,
    text: 'Original',
    createdAt: DateTime.utc(2026, 10, 31),
  );
  return ConversationHistorySelection(
    conversationId: 'chat',
    sourceTurnId: 'turn',
    requestMessage: request,
    sourceDigest: 'a' * 64,
    retainedMessages: [],
    retiredMessages: [request],
    retiredRuns: [],
    retiredTurns: [
      ConversationTurn(
        id: 'turn',
        requestMessageId: 'request',
        ownershipComplete: true,
        messageIds: ['request'],
        runIds: ['original-run'],
      ),
    ],
    operations: [
      for (final owner in ConversationUndoOwner.values)
        ConversationHistoryOperation(
          binding: ConversationOperationBinding(
            operationId: '${owner.name}-original',
            store: owner == ConversationUndoOwner.main
                ? ConversationOperationStore.main
                : ConversationOperationStore.external,
            runId: 'original-run',
            toolCallId: 'call-${owner.name}',
          ),
          effect: owner == ConversationUndoOwner.main
              ? ConversationHistoryEffect.main
              : ConversationHistoryEffect.knowledge,
          digest: 'a' * 64,
        ),
    ],
  );
}
