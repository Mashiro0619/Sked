import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/agenda_runtime_mutation_lock.dart';

const _runtimeMutationBrokerName =
    'com.mashiro.sked.agenda-runtime-mutation-lock.v1';

void main() {
  test('serializes overlapping notification mutations', () async {
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondEntered = Completer<void>();

    final first = withAgendaRuntimeMutationLock(() async {
      firstEntered.complete();
      await releaseFirst.future;
    });
    await firstEntered.future;
    final second = withAgendaRuntimeMutationLock(() async {
      secondEntered.complete();
    });

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(secondEntered.isCompleted, isFalse);

    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(secondEntered.isCompleted, isTrue);
  });

  test('a callback retained by an old zone reacquires after release', () async {
    final trigger = Completer<void>();
    final delayedMutationEntered = Completer<void>();
    final delayedMutationFinished = Completer<void>();
    await withAgendaRuntimeMutationLock(() async {
      unawaited(
        trigger.future.then((_) async {
          await withAgendaRuntimeMutationLock(() async {
            delayedMutationEntered.complete();
          });
          delayedMutationFinished.complete();
        }),
      );
    });

    final blockerEntered = Completer<void>();
    final releaseBlocker = Completer<void>();
    final blocker = withAgendaRuntimeMutationLock(() async {
      blockerEntered.complete();
      await releaseBlocker.future;
    });
    await blockerEntered.future;
    trigger.complete();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(delayedMutationEntered.isCompleted, isFalse);

    releaseBlocker.complete();
    await blocker;
    await delayedMutationFinished.future;
    expect(delayedMutationEntered.isCompleted, isTrue);
  });

  test('serializes mutations from separate isolates in one process', () async {
    final events = ReceivePort();
    final exited = ReceivePort();
    final isolate = await Isolate.spawn(
      _holdAgendaRuntimeMutationLock,
      events.sendPort,
      onExit: exited.sendPort,
    );
    final eventIterator = StreamIterator<dynamic>(events);
    try {
      expect(await eventIterator.moveNext(), isTrue);
      final releaseRemote = eventIterator.current as SendPort;
      expect(await eventIterator.moveNext(), isTrue);
      expect(eventIterator.current, 'entered');

      final localEntered = Completer<void>();
      final localMutation = withAgendaRuntimeMutationLock(() async {
        localEntered.complete();
      });
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(localEntered.isCompleted, isFalse);

      releaseRemote.send(null);
      await localMutation;
      expect(localEntered.isCompleted, isTrue);
      await exited.first.timeout(const Duration(seconds: 5));

      var reacquiredAfterOwnerExit = false;
      await withAgendaRuntimeMutationLock(() async {
        reacquiredAfterOwnerExit = true;
      }).timeout(const Duration(seconds: 5));
      expect(reacquiredAfterOwnerExit, isTrue);
    } finally {
      isolate.kill(priority: Isolate.immediate);
      await eventIterator.cancel();
      events.close();
      exited.close();
    }
  });

  test('recovers from a stale process broker registration', () async {
    IsolateNameServer.removePortNameMapping(_runtimeMutationBrokerName);
    final stalePort = RawReceivePort();
    addTearDown(stalePort.close);
    expect(
      IsolateNameServer.registerPortWithName(
        stalePort.sendPort,
        _runtimeMutationBrokerName,
      ),
      isTrue,
    );

    var entered = false;
    await withAgendaRuntimeMutationLock(() async {
      entered = true;
    });

    expect(entered, isTrue);
  });

  test('cancels active and queued broker requests safely', () async {
    final broker = IsolateNameServer.lookupPortByName(
      _runtimeMutationBrokerName,
    );
    expect(broker, isNotNull);

    final activeId = 'test-active-${DateTime.now().microsecondsSinceEpoch}';
    final activeReply = ReceivePort();
    final activeMessages = StreamIterator<dynamic>(activeReply);
    addTearDown(activeReply.close);
    addTearDown(activeMessages.cancel);
    broker!.send(<Object?>['acquire', activeId, activeReply.sendPort]);
    expect(await activeMessages.moveNext(), isTrue);
    expect((activeMessages.current as List<Object?>).first, 'acknowledged');
    expect(await activeMessages.moveNext(), isTrue);
    expect((activeMessages.current as List<Object?>).first, 'granted');
    broker.send(<Object?>['cancel', activeId]);

    final heldId = 'test-held-${DateTime.now().microsecondsSinceEpoch}';
    final queuedId = 'test-queued-${DateTime.now().microsecondsSinceEpoch}';
    final heldReply = ReceivePort();
    final queuedReply = ReceivePort();
    final heldMessages = StreamIterator<dynamic>(heldReply);
    final queuedMessages = StreamIterator<dynamic>(queuedReply);
    addTearDown(heldReply.close);
    addTearDown(queuedReply.close);
    addTearDown(heldMessages.cancel);
    addTearDown(queuedMessages.cancel);
    broker.send(<Object?>['acquire', heldId, heldReply.sendPort]);
    expect(await heldMessages.moveNext(), isTrue);
    expect((heldMessages.current as List<Object?>).first, 'acknowledged');
    expect(await heldMessages.moveNext(), isTrue);
    expect((heldMessages.current as List<Object?>).first, 'granted');
    broker.send(<Object?>['acquire', queuedId, queuedReply.sendPort]);
    expect(await queuedMessages.moveNext(), isTrue);
    expect((queuedMessages.current as List<Object?>).first, 'acknowledged');
    broker.send(<Object?>['cancel', queuedId]);
    broker.send(<Object?>['release', heldId]);

    await withAgendaRuntimeMutationLock(() async {});
  });

  test('reclaims a lease after its owner isolate is terminated', () async {
    final events = ReceivePort();
    final exited = ReceivePort();
    final isolate = await Isolate.spawn(
      _holdAgendaRuntimeMutationLock,
      events.sendPort,
      onExit: exited.sendPort,
    );
    final eventIterator = StreamIterator<dynamic>(events);
    try {
      expect(await eventIterator.moveNext(), isTrue);
      expect(eventIterator.current, isA<SendPort>());
      expect(await eventIterator.moveNext(), isTrue);
      expect(eventIterator.current, 'entered');

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      isolate.kill(priority: Isolate.immediate);
      await exited.first.timeout(const Duration(seconds: 5));

      var recovered = false;
      await withAgendaRuntimeMutationLock(() async {
        recovered = true;
      }).timeout(const Duration(seconds: 7));
      expect(recovered, isTrue);
    } finally {
      isolate.kill(priority: Isolate.immediate);
      await eventIterator.cancel();
      events.close();
      exited.close();
    }
  });
}

Future<void> _holdAgendaRuntimeMutationLock(SendPort events) async {
  final release = ReceivePort();
  events.send(release.sendPort);
  await withAgendaRuntimeMutationLock(() async {
    events.send('entered');
    await release.first;
  });
  release.close();
}
