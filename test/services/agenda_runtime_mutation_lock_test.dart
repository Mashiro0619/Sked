import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/services/agenda_runtime_mutation_lock.dart';
import 'package:sked/services/agenda_runtime_mutation_lock_stub.dart' as stub;

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
    // A shard or named run may execute this without an earlier lock request.
    await withAgendaRuntimeMutationLock(() async {});
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

  group('explicit runtime lock scope', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sked-runtime-scope-');
    });
    tearDown(() => _deleteScopeDirectory(directory));

    AgendaRuntimeMutationLockScope scopeFor(String name) =>
        AgendaRuntimeMutationLockScope(
          lockFilePath: path.join(directory.path, '$name.lock'),
        );

    test('rejects relative paths and mismatched broker identities', () {
      final first = scopeFor('first');
      final second = scopeFor('second');
      expect(
        () => AgendaRuntimeMutationLockScope(lockFilePath: 'relative.lock'),
        throwsArgumentError,
      );
      if (Platform.isWindows) {
        expect(
          () => AgendaRuntimeMutationLockScope(
            lockFilePath: r'\root-relative.lock',
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => AgendaRuntimeMutationLockScope(
          lockFilePath: first.lockFilePath,
          brokerNamespace: second.brokerNamespace,
        ),
        throwsArgumentError,
      );
      expect(
        () => AgendaRuntimeMutationLockScope(
          lockFilePath: second.lockFilePath,
          brokerNamespace: first.brokerNamespace,
        ),
        throwsArgumentError,
      );
    });

    test(
      'the same scope serializes isolates and permits nested acquisition',
      () async {
        final scope = scopeFor('shared');
        final alias = AgendaRuntimeMutationLockScope(
          lockFilePath:
              '${directory.path}${Platform.pathSeparator}unused'
              '${Platform.pathSeparator}..${Platform.pathSeparator}shared.lock',
          brokerNamespace: scope.brokerNamespace,
        );
        final events = ReceivePort();
        final exited = ReceivePort();
        final isolate = await Isolate.spawn(
          _holdScopedAgendaRuntimeMutationLock,
          (
            events: events.sendPort,
            lockFilePath: alias.lockFilePath,
            brokerNamespace: alias.brokerNamespace,
          ),
          onExit: exited.sendPort,
        );
        final messages = StreamIterator<dynamic>(events);
        SendPort? releaseRemote;
        try {
          expect(
            await messages.moveNext().timeout(const Duration(seconds: 5)),
            isTrue,
          );
          releaseRemote = messages.current as SendPort;
          expect(
            await messages.moveNext().timeout(const Duration(seconds: 5)),
            isTrue,
          );
          expect(messages.current, 'entered');
          var localEntered = false;
          final local = _lockedIn(scope, () async {
            localEntered = true;
          });
          try {
            await Future<void>.delayed(const Duration(milliseconds: 25));
            expect(localEntered, isFalse);
          } finally {
            releaseRemote.send(null);
            await local.timeout(const Duration(seconds: 5));
          }
          await exited.first.timeout(const Duration(seconds: 5));
          expect(localEntered, isTrue);
          expect(await File(scope.lockFilePath).exists(), isTrue);
          await _lockedIn(
            alias,
            () async {},
          ).timeout(const Duration(seconds: 5));
        } finally {
          releaseRemote?.send(null);
          isolate.kill(priority: Isolate.immediate);
          await messages.cancel();
          events.close();
          exited.close();
        }
      },
    );

    test(
      'different scopes enter concurrently and create distinct lock files',
      () async {
        final firstScope = scopeFor('first');
        final secondScope = scopeFor('second');
        final firstEntered = Completer<void>();
        final releaseFirst = Completer<void>();
        final first = _lockedIn(firstScope, () async {
          firstEntered.complete();
          await releaseFirst.future;
        });
        await firstEntered.future;
        try {
          await _lockedIn(secondScope, () async {
            expect(releaseFirst.isCompleted, isFalse);
            expect(await File(firstScope.lockFilePath).exists(), isTrue);
            expect(await File(secondScope.lockFilePath).exists(), isTrue);
            expect(
              await FileSystemEntity.identical(
                firstScope.lockFilePath,
                secondScope.lockFilePath,
              ),
              isFalse,
            );
          }).timeout(const Duration(seconds: 5));
        } finally {
          releaseFirst.complete();
          await first;
        }
      },
    );

    test('switching scopes cannot borrow the current owner token', () async {
      final firstScope = scopeFor('first');
      final secondScope = scopeFor('second');
      final secondHeld = Completer<void>();
      final releaseSecond = Completer<void>();
      final blocker = _lockedIn(secondScope, () async {
        secondHeld.complete();
        await releaseSecond.future;
      });
      await secondHeld.future;
      final firstEntered = Completer<void>();
      var nestedEntered = false;
      final first = _lockedIn(firstScope, () async {
        firstEntered.complete();
        await _lockedIn(secondScope, () async {
          nestedEntered = true;
        }).timeout(const Duration(seconds: 5));
      });
      try {
        await firstEntered.future;
        await Future<void>.delayed(const Duration(milliseconds: 25));
        expect(nestedEntered, isFalse);
      } finally {
        releaseSecond.complete();
        await Future.wait([blocker, first]);
      }
      expect(nestedEntered, isTrue);
    });

    test('A to B to A reenters its still-active ancestor lock', () async {
      final firstScope = scopeFor('first');
      final secondScope = scopeFor('second');
      final order = <String>[];
      await _lockedIn(firstScope, () async {
        order.add('A');
        await _lockedIn(secondScope, () async {
          order.add('B');
          await _lockedIn(firstScope, () async {
            order.add('A again');
          }).timeout(const Duration(seconds: 5));
        });
      });
      expect(order, ['A', 'B', 'A again']);
      expect(await File(secondScope.lockFilePath).exists(), isTrue);
    });

    test(
      'a retained callback keeps its scope but reacquires a released lease',
      () async {
        final scope = scopeFor('retained');
        final trigger = Completer<void>();
        late Future<void> callback;
        var callbackEntered = false;
        await _lockedIn(scope, () async {
          callback = trigger.future.then((_) {
            return withAgendaRuntimeMutationLock(() async {
              callbackEntered = true;
            });
          });
        });
        final blockerEntered = Completer<void>();
        final releaseBlocker = Completer<void>();
        final blocker = _lockedIn(scope, () async {
          blockerEntered.complete();
          await releaseBlocker.future;
        });
        await blockerEntered.future;
        try {
          trigger.complete();
          await Future<void>.delayed(const Duration(milliseconds: 25));
          expect(callbackEntered, isFalse);
        } finally {
          releaseBlocker.complete();
          await Future.wait([blocker, callback]);
        }
        expect(callbackEntered, isTrue);
      },
    );

    test(
      'an explicit default path shares the legacy broker and reentrancy',
      () async {
        final scope = AgendaRuntimeMutationLockScope(
          lockFilePath: path.join(
            Directory.systemTemp.path,
            'sked_notification_runtime.lock',
          ),
          brokerNamespace: _runtimeMutationBrokerName,
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        var nestedEntered = false;
        final owner = withAgendaRuntimeMutationLock(() async {
          await _lockedIn(scope, () async {
            nestedEntered = true;
          }).timeout(const Duration(seconds: 5));
          entered.complete();
          await release.future;
        });
        var outsideEntered = false;
        Future<void>? outside;
        try {
          await entered.future.timeout(const Duration(seconds: 5));
          outside = _lockedIn(scope, () async {
            outsideEntered = true;
          });
          expect(nestedEntered, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 25));
          expect(outsideEntered, isFalse);
        } finally {
          release.complete();
          await owner;
          if (outside != null) await outside;
        }
        expect(outsideEntered, isTrue);
      },
    );
  });

  test('the non-IO platform still executes the supplied action', () async {
    final result = await stub.withPlatformAgendaRuntimeMutationLock(
      () async => 42,
      lockFilePath: '/isolated/runtime.lock',
      brokerNamespace: 'unused-on-non-io',
    );
    expect(result, 42);
  });
}

Future<T> _lockedIn<T>(
  AgendaRuntimeMutationLockScope scope,
  Future<T> Function() action,
) => withAgendaRuntimeMutationLockScope(
  scope,
  () => withAgendaRuntimeMutationLock(action),
);

Future<void> _holdScopedAgendaRuntimeMutationLock(
  ({SendPort events, String lockFilePath, String brokerNamespace})
  configuration,
) async {
  final scope = AgendaRuntimeMutationLockScope(
    lockFilePath: configuration.lockFilePath,
    brokerNamespace: configuration.brokerNamespace,
  );
  // The helper acquires again in the same scope before it reports entry.
  await _lockedIn(
    scope,
    () => _holdAgendaRuntimeMutationLock(configuration.events),
  );
}

Future<void> _deleteScopeDirectory(Directory directory) async {
  // Release messages and file close run asynchronously in the broker isolate.
  for (var attempt = 0; ; attempt += 1) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 119) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
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
