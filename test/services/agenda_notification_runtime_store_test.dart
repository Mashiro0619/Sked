import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';

void main() {
  test(
    'memory action ids are collision-resistant and queue is bounded',
    () async {
      var now = DateTime(2026, 8, 1, 12);
      final store = MemoryAgendaNotificationRuntimeStore(clock: () => now);

      for (var index = 0; index < 40; index++) {
        await store.enqueueAction(
          payload: 'payload-$index',
          actionId: 'handled',
        );
      }

      final pending = await store.readPendingActions();
      expect(pending, hasLength(32));
      expect(pending.map((item) => item.id).toSet(), hasLength(32));
      expect(
        pending.every(
          (item) => RegExp(r'^action-[0-9a-f]{64}$').hasMatch(item.id),
        ),
        isTrue,
      );

      now = now.add(const Duration(hours: 25));
      expect(await store.readPendingActions(), isEmpty);
    },
  );

  test('memory handled occurrences expire after their runtime ttl', () async {
    var now = DateTime(2026, 8, 1);
    final store = MemoryAgendaNotificationRuntimeStore(clock: () => now);

    await store.addHandledOccurrence('occurrence');
    expect(await store.readHandledOccurrenceIds(), contains('occurrence'));

    now = now.add(const Duration(days: 31));
    expect(await store.readHandledOccurrenceIds(), isEmpty);
  });

  test(
    'shared preferences migrates legacy handled ids and removes expired data',
    () async {
      final now = DateTime(2026, 8, 31);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAgendaNotificationRuntimeStore.handledKey: [
          'legacy-occurrence',
        ],
        SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey:
            '{"expired":"2026-07-01T00:00:00.000"}',
      });
      final store = SharedPreferencesAgendaNotificationRuntimeStore(
        clock: () => now,
      );

      expect(
        await store.readHandledOccurrenceIds(),
        contains('legacy-occurrence'),
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getStringList(
          SharedPreferencesAgendaNotificationRuntimeStore.handledKey,
        ),
        ['legacy-occurrence'],
      );
      expect(
        preferences.getString(
          SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey,
        ),
        contains('legacy-occurrence'),
      );
      expect(
        preferences
            .getString(
              SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey,
            )
            .toString(),
        isNot(contains('expired')),
      );
    },
  );

  test('runtime action decoding rejects malformed platform queue entries', () {
    final action = AgendaNotificationAction(
      id: 'action-id',
      payload: 'payload',
      actionId: 'handled',
      enqueuedAt: DateTime(2026, 8, 3, 8),
    );

    final decoded = AgendaNotificationAction.tryDecode(action.toJson());
    expect(decoded, isNotNull);
    expect(decoded!.id, action.id);
    expect(decoded.payload, action.payload);
    expect(decoded.actionId, action.actionId);
    expect(decoded.enqueuedAt, action.enqueuedAt);
    expect(
      AgendaNotificationAction.tryDecode({...action.toJson(), 'payload': ''}),
      isNull,
    );
    expect(
      AgendaNotificationAction.tryDecode({
        ...action.toJson(),
        'enqueuedAt': 'not-a-date',
      }),
      isNull,
    );
    expect(AgendaNotificationAction.tryDecode('not-a-map'), isNull);
  });

  test(
    'shared runtime queue cleans stale entries and canonicalizes ids',
    () async {
      final now = DateTime(2026, 8, 3, 12);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAgendaNotificationRuntimeStore.actionsKey: jsonEncode([
          {
            'id': 'legacy-id',
            'payload': 'keep',
            'actionId': 'handled',
            'enqueuedAt': now.toIso8601String(),
          },
          {
            'id': 'expired-id',
            'payload': 'expired',
            'actionId': 'handled',
            'enqueuedAt': now
                .subtract(const Duration(hours: 25))
                .toIso8601String(),
          },
          {
            'id': 'future-id',
            'payload': 'future',
            'actionId': 'handled',
            'enqueuedAt': now.add(const Duration(minutes: 6)).toIso8601String(),
          },
        ]),
      });
      final store = SharedPreferencesAgendaNotificationRuntimeStore(
        clock: () => now,
      );

      final pending = await store.readPendingActions();

      expect(pending, hasLength(1));
      expect(pending.single.payload, 'keep');
      expect(
        RegExp(r'^action-[0-9a-f]{64}$').hasMatch(pending.single.id),
        isTrue,
      );
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString(
        SharedPreferencesAgendaNotificationRuntimeStore.actionsKey,
      )!;
      expect(stored, isNot(contains('expired')));
      expect(stored, isNot(contains('future')));
      expect(stored, isNot(contains('legacy-id')));
    },
  );

  test(
    'shared runtime mutations are serialized and clear all runtime state',
    () async {
      final now = DateTime(2026, 8, 3, 12);
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesAgendaNotificationRuntimeStore(
        clock: () => now,
      );

      await Future.wait([
        store.setSnooze('first', now.add(const Duration(minutes: 10))),
        store.setSnooze('second', now.add(const Duration(minutes: 20))),
        store.addHandledOccurrence('first-occurrence'),
        store.addHandledOccurrence('second-occurrence'),
        store.enqueueAction(payload: 'payload', actionId: 'handled'),
        store.enqueueAction(payload: 'payload', actionId: 'handled'),
      ]);

      expect(
        (await store.readSnoozes()).keys,
        containsAll(['first', 'second']),
      );
      expect(
        await store.readHandledOccurrenceIds(),
        containsAll(['first-occurrence', 'second-occurrence']),
      );
      expect(await store.readPendingActions(), hasLength(1));

      await store.clear();

      expect(await store.readSnoozes(), isEmpty);
      expect(await store.readHandledOccurrenceIds(), isEmpty);
      expect(await store.readPendingActions(), isEmpty);
    },
  );

  test('memory runtime store removes individual state and bounds oversized data', () async {
    var now = DateTime(2026, 8, 3, 12);
    final store = MemoryAgendaNotificationRuntimeStore(clock: () => now);

    await store.setSnooze('snooze', now.add(const Duration(minutes: 10)));
    await store.removeSnooze('snooze');
    expect(await store.readSnoozes(), isEmpty);

    await store.addHandledOccurrence('removed-occurrence');
    await store.removeHandledOccurrence('removed-occurrence');
    expect(await store.readHandledOccurrenceIds(), isEmpty);

    for (
      var index = 0;
      index <= MemoryAgendaNotificationRuntimeStore.maxHandledOccurrences;
      index++
    ) {
      now = now.add(const Duration(seconds: 1));
      await store.addHandledOccurrence('handled-$index');
    }
    final handled = await store.readHandledOccurrenceIds();
    expect(
      handled,
      hasLength(MemoryAgendaNotificationRuntimeStore.maxHandledOccurrences),
    );
    expect(handled, isNot(contains('handled-0')));
    expect(
      handled,
      contains(
        'handled-${MemoryAgendaNotificationRuntimeStore.maxHandledOccurrences}',
      ),
    );

    for (
      var index = 0;
      index <= MemoryAgendaNotificationRuntimeStore.maxPendingActions;
      index++
    ) {
      store.pendingActions.add(
        AgendaNotificationAction(
          id: 'queued-$index',
          payload: 'payload-$index',
          actionId: 'handled',
          enqueuedAt: now,
        ),
      );
    }
    expect(
      await store.readPendingActions(),
      hasLength(MemoryAgendaNotificationRuntimeStore.maxPendingActions),
    );

    await store.clear();
    expect(await store.readSnoozes(), isEmpty);
    expect(await store.readHandledOccurrenceIds(), isEmpty);
    expect(await store.readPendingActions(), isEmpty);
  });

  test(
    'shared runtime removes individual records and self-heals stale snoozes',
    () async {
      final now = DateTime(2026, 8, 3, 12);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAgendaNotificationRuntimeStore.snoozeKey: jsonEncode({
          'future': now.add(const Duration(minutes: 10)).toIso8601String(),
          'expired': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        }),
      });
      final store = SharedPreferencesAgendaNotificationRuntimeStore(
        clock: () => now,
      );

      expect(await store.readSnoozes(), {
        'future': now.add(const Duration(minutes: 10)),
      });
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(
          SharedPreferencesAgendaNotificationRuntimeStore.snoozeKey,
        ),
        isNot(contains('expired')),
      );

      await store.removeSnooze('future');
      expect(await store.readSnoozes(), isEmpty);

      await store.addHandledOccurrence('handled');
      await store.removeHandledOccurrence('handled');
      expect(await store.readHandledOccurrenceIds(), isEmpty);
      expect(
        preferences.containsKey(
          SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey,
        ),
        isFalse,
      );

      await store.enqueueAction(payload: 'payload', actionId: 'handled');
      final pending = await store.readPendingActions();
      await store.removePendingAction(pending.single.id);
      expect(await store.readPendingActions(), isEmpty);
      expect(
        preferences.containsKey(
          SharedPreferencesAgendaNotificationRuntimeStore.actionsKey,
        ),
        isFalse,
      );
    },
  );

  test('shared runtime persists background snooze requests and removes stale records', () async {
    final now = DateTime(2026, 8, 3, 12);
    const key = 'course|table|course|2026-08-03|10';
    final request = AgendaNotificationBackgroundRequest(
      key: key,
      notificationId: 42,
      title: 'Mathematics',
      body: '08:00',
      payload: 'sked.agenda.v1:payload',
      fireAt: now.add(const Duration(minutes: 10)),
      localeCode: 'zh-Hant',
      lockScreenShowTitles: true,
      channelId: 'sked_course_reminders',
      channelName: 'Course reminders',
      channelDescription: 'Course reminders from Sked.',
    );
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesAgendaNotificationRuntimeStore(
      clock: () => now,
    );

    await store.setSnooze(key, now.add(const Duration(minutes: 10)));
    await store.saveBackgroundRequest(request);

    expect(await store.readSnoozes(), {
      key: now.add(const Duration(minutes: 10)),
    });
    final restored = await store.readBackgroundRequest(key);
    expect(restored, isNotNull);
    expect(restored!.notificationId, request.notificationId);
    expect(restored.payload, request.payload);
    expect(restored.localeCode, 'zh-Hant');
    expect(restored.channelId, request.channelId);

    await store.removeBackgroundRequest(key);
    expect(await store.readBackgroundRequest(key), isNull);

    await store.saveBackgroundRequest(
      request.copyWith(fireAt: now.subtract(const Duration(days: 3))),
    );
    await store.pruneBackgroundRequests(now: now);
    expect(await store.readBackgroundRequest(key), isNull);
  });

  test('shared runtime rejects malformed serialized state without blocking startup', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesAgendaNotificationRuntimeStore.snoozeKey: '{invalid',
      SharedPreferencesAgendaNotificationRuntimeStore.handledRecordsKey:
          '{invalid',
      SharedPreferencesAgendaNotificationRuntimeStore.actionsKey: '{invalid',
    });
    final store = SharedPreferencesAgendaNotificationRuntimeStore(
      clock: () => DateTime(2026, 8, 3, 12),
    );

    expect(await store.readSnoozes(), isEmpty);
    expect(await store.readHandledOccurrenceIds(), isEmpty);
    expect(await store.readPendingActions(), isEmpty);
  });

  test('shared runtime surfaces failed preference writes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final failingStringStore = SharedPreferencesAgendaNotificationRuntimeStore(
      preferencesProvider: () async => preferences,
      stringWriter: (_, _, _) async => false,
    );

    await expectLater(
      failingStringStore.setSnooze(
        'failed-snooze',
        DateTime(2026, 8, 3, 12, 10),
      ),
      throwsA(isA<AgendaNotificationRuntimeStorageException>()),
    );
    await expectLater(
      failingStringStore.enqueueAction(payload: 'payload', actionId: 'handled'),
      throwsA(isA<AgendaNotificationRuntimeStorageException>()),
    );

    final failingStringListStore =
        SharedPreferencesAgendaNotificationRuntimeStore(
          preferencesProvider: () async => preferences,
          stringListWriter: (_, _, _) async => false,
        );
    await expectLater(
      failingStringListStore.addHandledOccurrence('failed-occurrence'),
      throwsA(isA<AgendaNotificationRuntimeStorageException>()),
    );
  });
}
