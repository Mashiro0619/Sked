import '../support/agenda_notification_memory.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/agenda_notification_service.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';

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

Future<AppRuntime> _createProvider() async {
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
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: WorkspaceMemoryStorage(
      initial,
      path: 'memory://reminder-strip-test',
    ),
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: Duration.zero,
  );
  await provider.lifecycle.load();
  return provider;
}

Future<void> _pumpReminderScreen(
  WidgetTester tester, {
  required AppRuntime provider,
  required _MutableClock clock,
  required _TrackingTimerFactory timers,
  AgendaNotificationService? notificationService,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AgendaNotificationService?>.value(
      value: notificationService,
      child: AppScope(
        app: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GeneralReminderTimeScope(
            now: clock.now,
            createTimer: timers.create,
            child: const GeneralScheduleHomeScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('general-reminders-action')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'reminder panel reports blocked delivery and clears after repair',
    (tester) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final clock = _MutableClock(DateTime(2026, 6, 16, 9, 55));
      final gateway = MemoryAgendaNotificationGateway()
        ..exactAlarmGranted = false;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        now: clock.now,
      );
      addTearDown(service.dispose);
      await tester.runAsync(() async {
        await provider.settingsCommands.updateNotificationsEnabled(true);
        await service.reconcile(
          provider.session.committedData,
          anchor: clock.now(),
        );
      });
      await _pumpReminderScreen(
        tester,
        provider: provider,
        clock: clock,
        timers: _TrackingTimerFactory(),
        notificationService: service,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.notificationCoverageBlocked), findsOneWidget);

      gateway.exactAlarmGranted = true;
      await tester.runAsync(
        () => service.reconcile(
          provider.session.committedData,
          anchor: clock.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('general-reminder-delivery-notice')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('general-reminders-list')),
          matching: find.text('Exam'),
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );

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

    expect(find.text('Upcoming'), findsNothing);

    clock.value = DateTime(2026, 6, 16, 9, 50);
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('Upcoming'), findsOneWidget);

    clock.value = DateTime(2026, 6, 16, 10, 0, 30);
    await tester.pump(const Duration(minutes: 1));

    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('In progress'), findsOneWidget);

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

    expect(find.text('Upcoming'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final cancellationsAfterPause = timers.cancellationCount;
    expect(cancellationsAfterPause, greaterThan(0));

    clock.value = DateTime(2026, 6, 16, 10, 5);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Upcoming'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('In progress'), findsOneWidget);
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
      AppScope(
        app: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
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
    await tester.tap(find.byKey(const ValueKey('general-reminders-action')));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);

    tickerEnabled.value = false;
    await tester.pump();
    final cancellationsWhileHidden = timers.cancellationCount;
    expect(cancellationsWhileHidden, greaterThan(0));

    clock.value = DateTime(2026, 6, 16, 10, 5);
    tickerEnabled.value = true;
    await tester.pump();

    expect(find.text('Upcoming'), findsNothing);
    expect(find.text('In progress'), findsOneWidget);
    expect(timers.cancellationCount, cancellationsWhileHidden);
  });
}
