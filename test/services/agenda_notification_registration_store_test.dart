import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';

const fence = AgendaNotificationProjectionFence.initial;
final original = DateTime.utc(2026, 9, 14, 0, 55);
AgendaNotificationRegistration record({
  DateTime? originalAt,
  DateTime? fireAt,
  AgendaNotificationRegistrationState state =
      AgendaNotificationRegistrationState.pending,
}) => AgendaNotificationRegistration(
  key: 'v1|test|entry|5',
  originalFireAt: originalAt ?? original,
  fireAt: fireAt ?? original.add(const Duration(seconds: 6)),
  recordedAt: original.add(const Duration(seconds: 1)),
  state: state,
  kind: AgendaNotificationRegistrationKind.lateRecovery,
  notificationId: 23,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final persistent in [false, true]) {
    group(
      persistent ? 'SharedPreferences registrations' : 'memory registrations',
      () {
        late AgendaNotificationRuntimeStore runtime;
        late AgendaNotificationRegistrationStore store;
        setUp(() {
          runtime = persistent
              ? SharedPreferencesAgendaNotificationRuntimeStore()
              : MemoryAgendaNotificationRuntimeStore();
          store = runtime as AgendaNotificationRegistrationStore;
        });

        test(
          'claim and acceptance round trip without changing logical identity',
          () async {
            await store.initializeRegistrationEpoch(
              original.subtract(const Duration(minutes: 1)),
              fence,
            );
            expect(await store.writeRegistration(record(), fence), isTrue);
            var snapshot = await store.readRegistrationSnapshot(
              fence,
              now: original,
            );
            expect(
              snapshot.records.values.single.state,
              AgendaNotificationRegistrationState.pending,
            );
            await store.writeRegistration(
              record().copyWith(
                state: AgendaNotificationRegistrationState.accepted,
              ),
              fence,
            );
            if (persistent) {
              store = SharedPreferencesAgendaNotificationRuntimeStore();
            }
            snapshot = await store.readRegistrationSnapshot(
              fence,
              now: original,
            );
            expect(snapshot.records, hasLength(1));
            expect(
              snapshot.forReminder(record().key, original.toLocal())?.state,
              AgendaNotificationRegistrationState.accepted,
            );
            expect(
              snapshot.initializedAt,
              original.subtract(const Duration(minutes: 1)),
            );
            expect(
              jsonEncode(snapshot.records.values.single.toJson()),
              isNot(contains('title')),
            );
          },
        );

        test(
          'ordinary runtime cleanup preserves registration and action receipts',
          () async {
            final receipt = AgendaNotificationSnoozeReceipt(
              actionIdentity: 'a' * 64,
              fireAt: original.add(const Duration(minutes: 10)),
            );
            await store.initializeRegistrationEpoch(original, fence);
            await store.writeRegistration(record(), fence);
            await store.writeSnoozeReceipt(receipt, fence);
            await runtime.clear();
            final snapshot = await store.readRegistrationSnapshot(
              fence,
              now: original,
            );
            expect(snapshot.records, hasLength(1));
            expect(
              snapshot.snoozeReceipts[receipt.actionIdentity]?.fireAt,
              receipt.fireAt,
            );
            expect(snapshot.initializedAt, original);
          },
        );

        test('data clear fences late writes and a new generation has separate history', () async {
          final fences = runtime as AgendaNotificationProjectionFenceStore;
          await store.writeRegistration(record(), fence);
          await fences.blockProjectionForDataClear();
          await runtime.clear();
          expect(await store.writeRegistration(record(), fence), isFalse);
          final fresh = await fences.activateProjectionAfterDurableData();
          expect(await store.writeRegistration(record(), fence), isFalse);
          expect(
            (await store.readRegistrationSnapshot(
              fresh,
              now: original,
            )).records,
            isEmpty,
          );
          await store.writeRegistration(record(), fresh);
          expect(
            (await store.readRegistrationSnapshot(
              fresh,
              now: original,
            )).records,
            hasLength(1),
          );
          expect(
            (await store.readRegistrationSnapshot(
              fence,
              now: original,
            )).records,
            isEmpty,
          );
        });

        test('retention uses the later original/scheduled instant and preserves the cutoff', () async {
          final future = record(
            originalAt: original.add(const Duration(days: 1)),
            fireAt: original,
          );
          await store.initializeRegistrationEpoch(original, fence);
          await store.writeRegistration(future, fence);
          var snapshot = await store.readRegistrationSnapshot(
            fence,
            now: original.add(const Duration(days: 2, hours: 1)),
          );
          expect(snapshot.records, hasLength(1));
          snapshot = await store.readRegistrationSnapshot(
            fence,
            now: original.add(const Duration(days: 3, seconds: 1)),
          );
          expect(snapshot.records, isEmpty);
          expect(snapshot.initializedAt, original);
        });
      },
    );
  }

  test('failed claim persistence is observable; accepted-write failure preserves the pending claim', () async {
    var fail = true;
    final store = SharedPreferencesAgendaNotificationRuntimeStore(
      stringWriter: (prefs, key, value) async {
        if (key.contains('.entry.') && fail) return false;
        return prefs.setString(key, value);
      },
    );
    await expectLater(
      store.writeRegistration(record(), fence),
      throwsA(isA<AgendaNotificationRuntimeStorageException>()),
    );
    fail = false;
    await store.writeRegistration(record(), fence);
    fail = true;
    await expectLater(
      store.writeRegistration(
        record(state: AgendaNotificationRegistrationState.accepted),
        fence,
      ),
      throwsA(isA<AgendaNotificationRuntimeStorageException>()),
    );
    final fresh = SharedPreferencesAgendaNotificationRuntimeStore();
    final snapshot = await fresh.readRegistrationSnapshot(fence, now: original);
    expect(
      snapshot.records.values.single.state,
      AgendaNotificationRegistrationState.pending,
    );
  });

  test(
    'malformed records and cutoff fail closed rather than allowing a replay',
    () async {
      final store = SharedPreferencesAgendaNotificationRuntimeStore();
      final prefs = await SharedPreferences.getInstance();
      const prefix =
          SharedPreferencesAgendaNotificationRuntimeStore.registrationKeyPrefix;
      await prefs.setString('${prefix}g0.epoch', 'not a date');
      await expectLater(
        store.readRegistrationSnapshot(fence, now: original),
        throwsA(isA<AgendaNotificationRuntimeStorageException>()),
      );
      await prefs.remove('${prefix}g0.epoch');
      await prefs.setString('${prefix}g0.entry.corrupt', '{');
      await expectLater(
        store.readRegistrationSnapshot(fence, now: original),
        throwsA(isA<AgendaNotificationRuntimeStorageException>()),
      );
    },
  );

  test(
    'diagnostic extensions are optional and explicitly report unknown display',
    () {
      final value = AgendaNotificationDiagnostics(
        recordedAt: original,
        mode: AgendaNotificationReconcileMode.recovery,
        result: AgendaNotificationDiagnosticResult.success,
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
        directScheduledCount: 1,
        directCapacity: 450,
        plan: const [],
        registrationDecisions: [
          AgendaNotificationRegistrationDiagnostic(
            key: record().key,
            originalFireAt: original,
            reason: 'suppressed_registered',
            state: AgendaNotificationRegistrationState.accepted,
          ),
        ],
        duplicatePendingRemoved: 2,
      );
      final json = value.toJson();
      expect(
        AgendaNotificationDiagnostics.tryDecode(json)?.duplicatePendingRemoved,
        2,
      );
      expect(jsonEncode(json), contains('"displayed":"unknown"'));
      json.remove('registrationDecisions');
      json.remove('duplicatePendingRemoved');
      expect(
        AgendaNotificationDiagnostics.tryDecode(json)?.registrationDecisions,
        isEmpty,
      );
    },
  );
  test(
    'record codecs reject malformed identity, dates, states, ids and receipts',
    () {
      for (final patch in <Map<String, Object?>>[
        {'v': 2},
        {'key': ''},
        {'key': 'x' * 1025},
        {'originalFireAt': 'invalid'},
        {'fireAt': null},
        {'recordedAt': 4},
        {'state': 'delivered'},
        {'kind': 'unknown'},
        {'notificationId': -1},
        {'notificationId': 1.5},
      ]) {
        expect(
          AgendaNotificationRegistration.tryDecode({
            ...record().toJson(),
            ...patch,
          }),
          isNull,
        );
      }
      expect(AgendaNotificationRegistration.tryDecode('bad'), isNull);
      expect(AgendaNotificationSnoozeReceipt.tryDecode(null), isNull);
      expect(
        AgendaNotificationSnoozeReceipt.tryDecode({
          'v': 1,
          'actionIdentity': 'bad',
          'fireAt': original.toIso8601String(),
        }),
        isNull,
      );
      final diagnostic = AgendaNotificationRegistrationDiagnostic(
        key: 'test',
        originalFireAt: original,
        reason: 'test',
        state: AgendaNotificationRegistrationState.pending,
        fireAt: original,
        notificationId: 23,
      ).toJson();
      for (final patch in <Map<String, Object?>>[
        {'key': ''},
        {'reason': ''},
        {'originalFireAt': 'bad'},
        {'fireAt': 'bad'},
        {'state': 'delivered'},
        {'notificationId': -1},
      ]) {
        expect(
          AgendaNotificationRegistrationDiagnostic.tryDecode({
            ...diagnostic,
            ...patch,
          }),
          isNull,
        );
      }
      expect(AgendaNotificationRegistrationDiagnostic.tryDecode(null), isNull);
    },
  );
}
