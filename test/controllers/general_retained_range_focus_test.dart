import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_data_maintenance.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/workspace_harness.dart';

final _range = GeneralDateRange(DateTime(2026, 9, 3), DateTime(2026, 9, 12));
final _initialDate = DateTime(2026, 9, 8);

class _WriteGate {
  _WriteGate({this.error});

  final Object? error;
  final entered = Completer<void>();
  final released = Completer<void>();

  void release() {
    if (!released.isCompleted) released.complete();
  }
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  int writes = 0;
  _WriteGate? nextGate;

  _WriteGate holdNextWrite({Object? error}) {
    final gate = _WriteGate(error: error);
    nextGate = gate;
    addTearDown(gate.release);
    return gate;
  }

  @override
  Future<void> save(AppData value) async {
    writes++;
    final gate = nextGate;
    nextGate = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.released.future;
      if (gate.error != null) throw gate.error!;
    }
    await super.save(value);
  }
}

Future<(AppRuntime, _Storage)> _setup() async {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'zh',
  );
  final storage = _Storage(
    initial.copyWith(
      activeMode: AppMode.general,
      generalMode: initial.generalMode.copyWith(
        selectedDateIso: '2026-09-08',
        customDateRange: _range,
        defaultView: generalViewMonth,
      ),
    ),
  );
  final provider = AppRuntime(
    storage: storage,
    systemLocaleCodeResolver: () => 'zh',
    // These tests explicitly flush; the widget regression covers the real
    // 450 ms debounce without relying on wall-clock timing here.
    uiStateSaveDelay: const Duration(hours: 1),
    workspaceMutationLock: (action) => action(),
  );
  await provider.lifecycle.load();
  addTearDown(provider.dispose);
  storage.writes = 0;
  return (provider, storage);
}

Future<void> _focus(AppRuntime provider, DateTime date) =>
    provider.generalNavigation.setSelectedDate(date, moveCustomRange: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'retained range focus publishes immediately and saves only the latest date',
    () async {
      final (provider, storage) = await _setup();
      final observed = <DateTime>[];
      provider.generalView.addListener(
        () => observed.add(provider.generalView.selectedDate),
      );
      final dates = [
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 17),
        DateTime(2026, 9, 11),
      ];
      for (final date in dates) {
        final focus = _focus(provider, date);
        expect(provider.generalView.selectedDate, date);
        expect(provider.generalView.customDateRange, _range);
        await focus;
      }
      expect(observed, dates);
      expect(storage.writes, 0);
      expect(storage.data.generalMode.selectedDate, _initialDate);
      await provider.persistence.flushPendingUiStateSaves();
      expect(storage.writes, 1);
      expect(storage.data.generalMode.selectedDate, dates.last);
      expect(storage.data.generalMode.customDateRange, _range);
    },
  );

  test(
    'retained range focus does not wait for an older ordinary save',
    () async {
      final (provider, storage) = await _setup();
      final gate = storage.holdNextWrite();
      final olderSave = provider.persistence.save(emitCommit: false);
      await gate.entered.future;
      final date = DateTime(2026, 9, 17);
      var completed = false;
      final focus = _focus(provider, date).then((_) => completed = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(completed, isTrue);
        expect(provider.generalView.selectedDate, date);
        expect(provider.generalView.customDateRange, _range);
        expect(storage.writes, 1);
      } finally {
        gate.release();
        await olderSave;
        await focus;
      }
      expect(provider.generalView.selectedDate, date);
      await provider.persistence.flushPendingUiStateSaves();
      expect(storage.writes, 2);
      expect(storage.data.generalMode.selectedDate, date);
      expect(storage.data.generalMode.customDateRange, _range);
    },
  );

  test(
    'moving a retained range still publishes only after storage succeeds',
    () async {
      final (provider, storage) = await _setup();
      final gate = storage.holdNextWrite();
      final focus = provider.generalNavigation.setSelectedDate(
        DateTime(2026, 10, 1),
      );
      await gate.entered.future;
      try {
        expect(provider.generalView.selectedDate, _initialDate);
        expect(provider.generalView.customDateRange, _range);
      } finally {
        gate.release();
        await focus;
      }
      expect(provider.generalView.selectedDate, DateTime(2026, 10, 1));
      expect(
        provider.generalView.customDateRange,
        GeneralDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 10)),
      );
      expect(
        storage.data.generalMode.customDateRange,
        provider.generalView.customDateRange,
      );
    },
  );

  for (final fails in [false, true]) {
    test(
      'retained focus follows an active range clear, failure=$fails',
      () async {
        final (provider, storage) = await _setup();
        final gate = storage.holdNextWrite(
          error: fails ? StateError('clear failed') : null,
        );
        final clearing = provider.generalNavigation.clearDateRange();
        final clearResult = clearing.then<Object?>(
          (_) => null,
          onError: (Object error) => error,
        );
        await gate.entered.future;
        var completed = false;
        final date = DateTime(2026, 9, 17);
        final focus = _focus(provider, date).then((_) => completed = true);
        try {
          await Future<void>.delayed(Duration.zero);
          expect(completed, isFalse);
          expect(provider.generalView.selectedDate, _initialDate);
          expect(provider.generalView.customDateRange, _range);
        } finally {
          gate.release();
        }
        expect(await clearResult, fails ? isStateError : isNull);
        await focus;
        expect(provider.generalView.selectedDate, date);
        expect(provider.generalView.customDateRange, fails ? _range : null);
        expect(storage.data.generalMode.selectedDate, date);
        expect(storage.data.generalMode.customDateRange, fails ? _range : null);
      },
    );
  }

  test(
    'retained focus stays behind a range queued by a workspace transaction',
    () async {
      final (provider, storage) = await _setup();
      final gate = storage.holdNextWrite();
      final switchMode = provider.workspaces.switchMode(AppMode.student);
      await gate.entered.future;
      final nextRange = GeneralDateRange(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 5),
      );
      final changingRange = provider.generalNavigation.setDateRange(
        nextRange,
        focusedDate: nextRange.start,
      );
      var completed = false;
      final date = DateTime(2026, 10, 3);
      final focus = _focus(provider, date).then((_) => completed = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        expect(provider.generalView.selectedDate, _initialDate);
        expect(provider.generalView.customDateRange, _range);
      } finally {
        gate.release();
        await switchMode;
        await changingRange;
        await focus;
      }
      expect(provider.generalView.selectedDate, date);
      expect(provider.generalView.customDateRange, nextRange);
      expect(storage.data.generalMode.selectedDate, date);
      expect(storage.data.generalMode.customDateRange, nextRange);
    },
  );

  for (final newerFocus in [false, true]) {
    test(
      'failed retained focus save rolls back only without a newer focus: $newerFocus',
      () async {
        final (provider, storage) = await _setup();
        await _focus(provider, DateTime(2026, 9, 16));
        final gate = storage.holdNextWrite(
          error: StateError('focus save failed'),
        );
        final flush = provider.persistence.flushPendingUiStateSaves();
        final rejected = expectLater(flush, throwsStateError);
        await gate.entered.future;
        final latest = DateTime(2026, 9, 17);
        Future<void>? focus;
        try {
          if (newerFocus) {
            focus = _focus(provider, latest);
            expect(provider.generalView.selectedDate, latest);
          }
        } finally {
          gate.release();
          await rejected;
          await focus;
        }
        expect(
          provider.generalView.selectedDate,
          newerFocus ? latest : _initialDate,
        );
        expect(provider.generalView.customDateRange, _range);
        expect(storage.data.generalMode.selectedDate, _initialDate);
        expect(storage.data.generalMode.customDateRange, _range);
        if (newerFocus) {
          await provider.persistence.flushPendingUiStateSaves();
          expect(storage.data.generalMode.selectedDate, latest);
          expect(storage.data.generalMode.customDateRange, _range);
        }
      },
    );
  }

  test('retained focus cannot overtake a pending workspace disable', () async {
    final (provider, storage) = await _setup();
    final guard = Completer<bool>();
    final entered = Completer<void>();
    final unregister = provider.workspaces.registerExitGuard(
      AppMode.general,
      () {
        entered.complete();
        return guard.future;
      },
    );
    addTearDown(unregister);
    final disabling = provider.workspaces.setEnabled(AppMode.general, false);
    await entered.future;
    final focus = _focus(provider, DateTime(2026, 9, 17));
    final rejected = expectLater(focus, throwsStateError);
    expect(provider.generalView.selectedDate, _initialDate);
    guard.complete(true);
    await disabling;
    await rejected;
    expect(provider.generalView.isEnabled, isFalse);
    expect(provider.generalView.selectedDate, _initialDate);
    expect(storage.writes, 1);
    await expectLater(
      _focus(provider, DateTime(2026, 9, 18)),
      throwsStateError,
    );
    expect(storage.writes, 1);
  });

  test(
    'retained focus rejects maintenance and an expired queued session',
    () async {
      final (provider, storage) = await _setup();
      final token = provider.maintenance.reserve();
      await expectLater(
        _focus(provider, DateTime(2026, 9, 17)),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      provider.maintenance.release(token);
      expect(provider.generalView.selectedDate, _initialDate);
      expect(storage.writes, 0);

      final gate = storage.holdNextWrite();
      final switchMode = provider.workspaces.switchMode(AppMode.student);
      await gate.entered.future;
      final focus = _focus(provider, DateTime(2026, 9, 17));
      final rejected = expectLater(focus, throwsStateError);
      final nextSession = provider.maintenance.reserve();
      provider.maintenance.release(nextSession);
      gate.release();
      await switchMode;
      await rejected;
      expect(provider.generalView.selectedDate, _initialDate);
      expect(provider.generalView.customDateRange, _range);
      expect(storage.writes, 1);
    },
  );
}
