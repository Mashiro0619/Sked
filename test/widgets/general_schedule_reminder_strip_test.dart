import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

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
  Future<String?> filePath() async => 'memory://reminder-strip-test';
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;

  DateTime now() => value;
}

class _TrackingTimerFactory {
  int cancellationCount = 0;

  Timer create(Duration delay, VoidCallback callback) {
    return _TrackingTimer(
      Timer(delay, callback),
      onCancel: () => cancellationCount += 1,
    );
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
  final initial =
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'calendar',
          selectedDateIso: '2026-06-16',
          defaultView: generalViewWeek,
          schedules: [
            GeneralSchedule(
              id: 'calendar',
              name: 'Calendar',
              events: [
                GeneralEvent(
                  id: 'exam',
                  calendarId: 'calendar',
                  title: 'Exam',
                  startDateTimeIso: '2026-06-16T10:00:00.000',
                  endDateTimeIso: '2026-06-16T11:00:00.000',
                  reminders: const [GeneralEventReminder(minutesBefore: 10)],
                ),
              ],
            ),
          ],
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

Future<void> _pumpReminderScreen(
  WidgetTester tester, {
  required TimetableProvider provider,
  required _MutableClock clock,
  required _TrackingTimerFactory timers,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GeneralReminderTimeScope(
          now: clock.now,
          createTimer: timers.create,
          child: const GeneralScheduleHomeScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('refreshes reminder status at the next minute boundary', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final clock = _MutableClock(DateTime(2026, 6, 16, 9, 49, 30));
    final timers = _TrackingTimerFactory();
    await _pumpReminderScreen(
      tester,
      provider: provider,
      clock: clock,
      timers: timers,
    );

    expect(find.text('Upcoming - Exam'), findsNothing);

    clock.value = DateTime(2026, 6, 16, 9, 50);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Upcoming - Exam'), findsOneWidget);

    clock.value = DateTime(2026, 6, 16, 10, 0, 30);
    await tester.pump(const Duration(minutes: 1));

    expect(find.text('Upcoming - Exam'), findsNothing);
    expect(find.text('In progress - Exam'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(timers.cancellationCount, greaterThan(0));
  });

  testWidgets('refreshes immediately when the app resumes', (tester) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final clock = _MutableClock(DateTime(2026, 6, 16, 9, 55));
    final timers = _TrackingTimerFactory();
    await _pumpReminderScreen(
      tester,
      provider: provider,
      clock: clock,
      timers: timers,
    );

    expect(find.text('Upcoming - Exam'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final cancellationsAfterPause = timers.cancellationCount;
    expect(cancellationsAfterPause, greaterThan(0));

    clock.value = DateTime(2026, 6, 16, 10, 5);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Upcoming - Exam'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Upcoming - Exam'), findsNothing);
    expect(find.text('In progress - Exam'), findsOneWidget);
    expect(timers.cancellationCount, cancellationsAfterPause);
  });

  testWidgets('refreshes immediately when its workspace ticker is reenabled', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final clock = _MutableClock(DateTime(2026, 6, 16, 9, 55));
    final timers = _TrackingTimerFactory();
    final tickerEnabled = ValueNotifier(true);
    addTearDown(tickerEnabled.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GeneralReminderTimeScope(
            now: clock.now,
            createTimer: timers.create,
            child: ValueListenableBuilder<bool>(
              valueListenable: tickerEnabled,
              child: const GeneralScheduleHomeScreen(active: true),
              builder: (context, enabled, child) =>
                  TickerMode(enabled: enabled, child: child!),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Upcoming - Exam'), findsOneWidget);

    tickerEnabled.value = false;
    await tester.pump();
    final cancellationsWhileHidden = timers.cancellationCount;
    expect(cancellationsWhileHidden, greaterThan(0));

    clock.value = DateTime(2026, 6, 16, 10, 5);
    tickerEnabled.value = true;
    await tester.pump();

    expect(find.text('Upcoming - Exam'), findsNothing);
    expect(find.text('In progress - Exam'), findsOneWidget);
    expect(timers.cancellationCount, cancellationsWhileHidden);
  });
}
