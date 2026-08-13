import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/timetable_grid.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async {
    return StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  }

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://timetable-live-refresh-test';
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;

  DateTime now() => value;
}

class _TrackingTimerFactory {
  final delays = <Duration>[];
  final _timers = <_TrackingTimer>[];
  int cancellationCount = 0;

  int get creationCount => _timers.length;

  int get activeCount => _timers.where((timer) => timer.isActive).length;

  Timer create(Duration delay, VoidCallback callback) {
    delays.add(delay);
    final timer = _TrackingTimer(
      Timer(delay, callback),
      onCancel: () => cancellationCount += 1,
    );
    _timers.add(timer);
    return timer;
  }
}

class _TrackingTimer implements Timer {
  _TrackingTimer(this._timer, {required this.onCancel});

  final Timer _timer;
  final VoidCallback onCancel;
  bool _wasCancelled = false;

  @override
  bool get isActive => _timer.isActive;

  @override
  int get tick => _timer.tick;

  @override
  void cancel() {
    if (!_wasCancelled && _timer.isActive) {
      _wasCancelled = true;
      onCancel();
    }
    _timer.cancel();
  }
}

Future<TimetableProvider> _createProvider() async {
  final timetable = TimetableData(
    id: 'live-refresh-table',
    config: TimetableConfig(
      name: 'Live refresh timetable',
      startDate: DateTime(2026, 6, 15),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  final base = buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en');
  final initial = base.copyWith(
    activeMode: AppMode.student,
    studentMode: base.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
    ),
  );
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(initial),
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpTimetableScreen(
  WidgetTester tester, {
  required TimetableProvider provider,
  required _MutableClock clock,
  required _TrackingTimerFactory timers,
  ValueNotifier<bool>? tickerEnabled,
}) async {
  final home = tickerEnabled == null
      ? const HomeScreen()
      : ValueListenableBuilder<bool>(
          valueListenable: tickerEnabled,
          child: const HomeScreen(),
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
        );
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimetableLiveRefreshScope(
          now: clock.now,
          createTimer: timers.create,
          child: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'live timetable refresh uses elapsed time within the current minute',
    () {
      expect(
        timetableLiveRefreshDelayUntilNextMinute(
          DateTime.utc(2026, 11, 1, 1, 59, 30, 250, 500),
        ),
        const Duration(seconds: 29, milliseconds: 749, microseconds: 500),
      );
      expect(
        timetableLiveRefreshDelayUntilNextMinute(DateTime.utc(2026, 11, 1, 2)),
        const Duration(minutes: 1),
      );
      expect(
        timetableLiveRefreshDelayUntilNextMinute(
          DateTime.utc(2026, 11, 1, 2, 0, 59, 999, 999),
        ),
        const Duration(microseconds: 1),
      );
    },
  );

  testWidgets('refreshes once at each minute boundary', (tester) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final clock = _MutableClock(DateTime(2026, 6, 16, 9, 49, 30));
    final timers = _TrackingTimerFactory();
    await _pumpTimetableScreen(
      tester,
      provider: provider,
      clock: clock,
      timers: timers,
    );

    expect(timers.creationCount, 1);
    expect(timers.activeCount, 1);
    expect(timers.delays.single, const Duration(seconds: 30));
    final gridBeforeRefresh = tester.widget<TimetableGrid>(
      find.byType(TimetableGrid),
    );

    clock.value = DateTime(2026, 6, 16, 9, 50);
    await tester.pump(const Duration(seconds: 30));

    expect(timers.creationCount, 2);
    expect(timers.activeCount, 1);
    expect(timers.delays.last, const Duration(minutes: 1));
    expect(
      identical(
        gridBeforeRefresh,
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)),
      ),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox());
    expect(timers.cancellationCount, greaterThan(0));
  });

  testWidgets('pauses in the background and refreshes immediately on resume', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final clock = _MutableClock(DateTime(2026, 6, 16, 9, 55));
    final timers = _TrackingTimerFactory();
    await _pumpTimetableScreen(
      tester,
      provider: provider,
      clock: clock,
      timers: timers,
    );
    final gridBeforePause = tester.widget<TimetableGrid>(
      find.byType(TimetableGrid),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final cancellationsAfterPause = timers.cancellationCount;
    expect(cancellationsAfterPause, greaterThan(0));
    expect(timers.activeCount, 0);

    clock.value = DateTime(2026, 6, 16, 10, 5);
    await tester.pump(const Duration(minutes: 5));
    expect(timers.creationCount, 1);
    expect(
      identical(
        gridBeforePause,
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)),
      ),
      isTrue,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(timers.creationCount, 2);
    expect(timers.activeCount, 1);
    expect(timers.cancellationCount, cancellationsAfterPause);
    expect(
      identical(
        gridBeforePause,
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)),
      ),
      isFalse,
    );
  });

  testWidgets('ticker changes cancel and recreate exactly one refresh timer', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final clock = _MutableClock(DateTime(2026, 6, 16, 9, 55));
    final timers = _TrackingTimerFactory();
    final tickerEnabled = ValueNotifier(true);
    addTearDown(tickerEnabled.dispose);
    await _pumpTimetableScreen(
      tester,
      provider: provider,
      clock: clock,
      timers: timers,
      tickerEnabled: tickerEnabled,
    );
    final gridBeforeDisable = tester.widget<TimetableGrid>(
      find.byType(TimetableGrid),
    );

    tickerEnabled.value = false;
    await tester.pump();
    expect(timers.creationCount, 1);
    expect(timers.activeCount, 0);
    expect(timers.cancellationCount, 1);

    clock.value = DateTime(2026, 6, 16, 10, 5);
    tickerEnabled.value = true;
    await tester.pump();
    expect(timers.creationCount, 2);
    expect(timers.activeCount, 1);
    expect(
      identical(
        gridBeforeDisable,
        tester.widget<TimetableGrid>(find.byType(TimetableGrid)),
      ),
      isFalse,
    );

    provider.notifyListeners();
    await tester.pump();
    expect(timers.creationCount, 2);
    expect(timers.activeCount, 1);
  });
}
