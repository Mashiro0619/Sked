import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_runtime_mutation_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a queued outside writer cannot block a mutation by the current runtime-lock owner', () async {
    final store = SharedPreferencesAgendaNotificationRuntimeStore();
    final entered = Completer<void>();
    final startNested = Completer<void>();
    final releaseOwner = Completer<void>();
    final nestedFinished = Completer<void>();
    Future<void>? nested;
    final owner = withAgendaRuntimeMutationLock(() async {
      entered.complete();
      await startNested.future;
      nested = store
          .initializeRegistrationEpoch(
            DateTime.utc(2026, 9, 16),
            AgendaNotificationProjectionFence.initial,
          )
          .then<void>((_) => nestedFinished.complete());
      await releaseOwner.future;
    });
    await entered.future;
    final outsider = store.setSnoozeForRuntimeFence(
      'outside',
      DateTime.now().add(const Duration(minutes: 10)),
      AgendaNotificationProjectionFence.initial,
    );
    startNested.complete();
    var completedWhileOwnerHeldLock = false;
    try {
      await nestedFinished.future.timeout(const Duration(seconds: 2));
      completedWhileOwnerHeldLock = true;
    } on TimeoutException {
      // Release the fixture's owner to avoid leaking a lock into later tests.
    } finally {
      releaseOwner.complete();
      await owner;
      await outsider;
      await nested;
    }
    expect(
      completedWhileOwnerHeldLock,
      isTrue,
      reason: 'The global runtime lock must be acquired before reserving the store queue.',
    );
    expect((await store.readSnoozes()).keys, contains('outside'));
  });

  test(
    'reentrant-zone callers still serialize the store read-modify-write queue',
    () async {
      final now = DateTime.utc(2026, 9, 16, 9);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var writes = 0;
      final store = SharedPreferencesAgendaNotificationRuntimeStore(
        clock: () => now,
        stringWriter: (preferences, key, value) async {
          writes++;
          if (writes == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          }
          return preferences.setString(key, value);
        },
      );
      await withAgendaRuntimeMutationLock(() async {
        final first = store.setSnoozeForRuntimeFence(
          'first',
          now.add(const Duration(minutes: 10)),
          AgendaNotificationProjectionFence.initial,
        );
        await firstStarted.future;
        final following = [
          for (var i = 0; i < 8; i++)
            store.setSnoozeForRuntimeFence(
              'following-$i',
              now.add(const Duration(minutes: 20)),
              AgendaNotificationProjectionFence.initial,
            ),
        ];
        try {
          await Future<void>.delayed(Duration.zero);
          expect(writes, 1);
        } finally {
          releaseFirst.complete();
          await Future.wait([first, ...following]);
        }
      });
      expect(writes, 9);
      expect(
        (await store.readSnoozes()).keys,
        unorderedEquals(['first', for (var i = 0; i < 8; i++) 'following-$i']),
      );
    },
  );

  test(
    'a failed queued write does not poison the local tail or global lease',
    () async {
      final now = DateTime.utc(2026, 9, 16, 9);
      var writes = 0;
      final store = SharedPreferencesAgendaNotificationRuntimeStore(
        clock: () => now,
        stringWriter: (preferences, key, value) async {
          if (++writes == 1) return false;
          return preferences.setString(key, value);
        },
      );
      await withAgendaRuntimeMutationLock(() async {
        final failed = expectLater(
          store.setSnoozeForRuntimeFence(
            'failed',
            now.add(const Duration(minutes: 10)),
            AgendaNotificationProjectionFence.initial,
          ),
          throwsA(isA<AgendaNotificationRuntimeStorageException>()),
        );
        final next = store.setSnoozeForRuntimeFence(
          'next',
          now.add(const Duration(minutes: 20)),
          AgendaNotificationProjectionFence.initial,
        );
        await Future.wait([failed, next]);
      });
      await store.setSnooze('outside', now.add(const Duration(minutes: 30)));
      expect(
        (await store.readSnoozes()).keys,
        unorderedEquals(['next', 'outside']),
      );
    },
  );

  test('removing a snooze with expired siblings never queues cleanup behind itself', () async {
    final now = DateTime.utc(2026, 9, 16, 9);
    SharedPreferences.setMockInitialValues({
      SharedPreferencesAgendaNotificationRuntimeStore.snoozeKey: jsonEncode({
        'expired': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'remove': now.add(const Duration(minutes: 10)).toIso8601String(),
        'keep': now.add(const Duration(minutes: 20)).toIso8601String(),
      }),
    });
    final store = SharedPreferencesAgendaNotificationRuntimeStore(
      clock: () => now,
    );
    await _expectRemovalCompletes(() => store.removeSnooze('remove'));
    expect((await store.readSnoozes()).keys, ['keep']);
  });

  for (final legacy in [false, true]) {
    test(
      'removing a handled occurrence with ${legacy ? 'legacy' : 'expired'} siblings never self-waits',
      () async {
        final now = DateTime.utc(2026, 9, 16, 9);
        SharedPreferences.setMockInitialValues({
          SharedPreferencesAgendaNotificationRuntimeStore.handledKey: [
            if (!legacy) 'expired',
            'remove',
            'keep',
          ],
          if (!legacy)
            SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey:
                jsonEncode({
                  'expired': now
                      .subtract(const Duration(days: 31))
                      .toIso8601String(),
                  'remove': now.toIso8601String(),
                  'keep': now.toIso8601String(),
                }),
        });
        final store = SharedPreferencesAgendaNotificationRuntimeStore(
          clock: () => now,
        );
        await _expectRemovalCompletes(
          () => store.removeHandledOccurrence('remove'),
        );
        final preferences = await SharedPreferences.getInstance();
        final records = jsonDecode(
          preferences.getString(
            SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey,
          )!,
        ) as Map<String, dynamic>;
        expect(records.keys, ['keep']);
        expect(await store.readHandledOccurrenceIds(), {'keep'});
      },
    );
  }

  test('removing a queued action with expired siblings never queues cleanup behind itself', () async {
    final now = DateTime.utc(2026, 9, 16, 9);
    AgendaNotificationAction action(String payload, DateTime timestamp) =>
        AgendaNotificationAction(
          id: 'action-${sha256.convert(utf8.encode('handled\u0000$payload'))}',
          payload: payload,
          actionId: 'handled',
          enqueuedAt: timestamp,
        );
    final remove = action('remove', now);
    SharedPreferences.setMockInitialValues({
      SharedPreferencesAgendaNotificationRuntimeStore.actionsKey: jsonEncode([
        action('expired', now.subtract(const Duration(days: 2))).toJson(),
        remove.toJson(),
        action('keep', now).toJson(),
      ]),
    });
    final store = SharedPreferencesAgendaNotificationRuntimeStore(
      clock: () => now,
    );
    await _expectRemovalCompletes(() => store.removePendingAction(remove.id));
    expect((await store.readPendingActions()).map((item) => item.payload), [
      'keep',
    ]);
  });
}

Future<void> _expectRemovalCompletes(Future<void> Function() action) async {
  var completed = false;
  // The fixture owns the outer lease so even a regressed self-wait can be
  // detected with a bounded timeout without leaking a broker heartbeat.
  await withAgendaRuntimeMutationLock(() async {
    try {
      await action().timeout(const Duration(seconds: 1));
      completed = true;
    } on TimeoutException {
      // Release the fixture's global lease before reporting the regression.
    }
  });
  expect(
    completed,
    isTrue,
    reason: 'A store mutation must not enqueue and await its own cleanup.',
  );
}
