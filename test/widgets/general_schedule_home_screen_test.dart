import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://general-home-test';
}

class _BlockingTimetableStorage implements TimetableStorage {
  _BlockingTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> _allowFirstSave = Completer<void>();

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
    if (saveCount == 1) {
      firstSaveStarted.complete();
      await _allowFirstSave.future;
    }
  }

  @override
  Future<String?> filePath() async => 'memory://general-home-blocking-test';

  void completeFirstSave() {
    if (!_allowFirstSave.isCompleted) {
      _allowFirstSave.complete();
    }
  }
}

class _FailingTimetableStorage implements TimetableStorage {
  _FailingTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    throw StateError('calendar save failed');
  }

  @override
  Future<String?> filePath() async => 'memory://general-home-failing-test';
}

class _FailOnceTimetableStorage implements TimetableStorage {
  _FailOnceTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;
  bool failNextSave = false;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('retryable calendar save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://general-home-fail-once-test';
}

AppData _buildGeneralDataWithCalendars(
  List<GeneralSchedule> calendars, {
  required String activeId,
}) {
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: defaultLocaleCode,
  ).copyWith(
    activeMode: AppMode.general,
    generalMode: GeneralScheduleData(
      activeScheduleId: activeId,
      schedules: calendars,
      selectedDateIso: '2026-06-16',
      defaultView: generalViewWeek,
    ),
  );
}

Future<TimetableProvider> _createProvider() async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  return provider;
}

Future<TimetableProvider> _createGeneralProvider(AppData data) async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(data),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  return provider;
}

Future<TimetableProvider> _createProviderWithStorage(
  TimetableStorage storage,
) async {
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpGeneralScheduleHomeScreen(
  WidgetTester tester,
  TimetableProvider provider, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  addTearDown(provider.dispose);
  PackageInfo.setMockInitialValues(
    appName: 'Sked',
    packageName: 'com.example.sked',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: appLocaleFromCode(provider.localeCode),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const GeneralScheduleHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

const _generalWeekPagerKey = ValueKey<String>('general-week-pager');
const _generalDayPagerKey = ValueKey<String>('general-day-pager');
const _generalDayWeekPickerPagerKey = ValueKey<String>(
  'general-day-week-picker-pager',
);
const _generalDayPickerSelectionIndicatorKey = ValueKey<String>(
  'general-day-picker-selection-indicator',
);
const _generalMonthCompactSelectedDayFeedbackKey = ValueKey<String>(
  'general-month-compact-selected-day-feedback',
);

void main() {
  testWidgets('add event entry ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.tap(fab, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(find.text('Add event'), findsWidgets);
    final editorSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(editorSheet.enableDrag, isFalse);
    expect(editorSheet.showDragHandle, isFalse);
  });

  testWidgets('settings entry ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final settingsButton = find.byTooltip('Settings');
    expect(settingsButton, findsOneWidget);

    await tester.tap(settingsButton);
    await tester.tap(settingsButton, warnIfMissed: false);
    await _pumpRouteTransition(tester);

    expect(find.byType(SettingsPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('calendar manager add ignores rapid duplicate taps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final initialData = buildInitialAppData(
      buildDefaultPeriodTimes(),
      localeCode: defaultLocaleCode,
    );
    final storage = _BlockingTimetableStorage(initialData);
    final provider = await _createProviderWithStorage(storage);
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final calendarsButton = find.byTooltip('Calendars');
    expect(calendarsButton, findsOneWidget);

    await tester.tap(calendarsButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Add calendar'), findsOneWidget);
    final addCalendarButton = find.byTooltip('Add calendar');
    expect(addCalendarButton, findsOneWidget);

    await tester.tap(addCalendarButton);
    await tester.tap(addCalendarButton, warnIfMissed: false);
    await storage.firstSaveStarted.future;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(provider.generalSchedules, hasLength(2));
    final managerSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(managerSheet.enableDrag, isFalse);
    expect(managerSheet.showDragHandle, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();

    expect(find.byTooltip('Add calendar'), findsOneWidget);
    expect(storage.saveCount, 1);

    storage.completeFirstSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.generalSchedules, hasLength(2));
  });

  testWidgets('calendar manager fits narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final semantics = tester.ensureSemantics();
    final calendars = [
      const GeneralSchedule(
        id: 'cal1',
        name: 'Primary planning calendar with a very long name',
        colorValue: 0xFF6750A4,
        events: [],
      ),
      const GeneralSchedule(
        id: 'cal2',
        name: 'Hidden shared family errands and reminders',
        colorValue: 0xFF386A20,
        isVisible: false,
        events: [],
      ),
      const GeneralSchedule(
        id: 'cal3',
        name: 'Work travel and appointments',
        colorValue: 0xFFB3261E,
        events: [],
      ),
    ];
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: calendars,
          selectedDateIso: '2026-06-16',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    await tester.tap(find.byTooltip('Calendars'));
    await tester.pumpAndSettle();

    expect(find.text('Calendars'), findsWidgets);
    expect(find.byTooltip('Add calendar'), findsOneWidget);
    final activeCalendar = tester.getSemantics(
      find.byKey(const ValueKey('calendar-manager-tile-cal1')),
    );
    final flags = activeCalendar.getSemanticsData().flagsCollection;
    expect(flags.isSelected, ui.Tristate.isTrue);
    expect(flags.isButton, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('calendar manager reports save failure and remains usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _FailingTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    );
    final provider = await _createProviderWithStorage(storage);
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.byTooltip('Calendars'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add calendar'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.generalSchedules, hasLength(1));
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add calendar'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar rename failure keeps the dialog draft for retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Original calendar',
      events: [],
    );
    final storage = _FailOnceTimetableStorage(
      _buildGeneralDataWithCalendars([calendar], activeId: calendar.id),
    );
    final provider = await _createProviderWithStorage(storage);
    final baselineSaveCount = storage.saveCount;
    storage.failNextSave = true;
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.byTooltip('Calendars'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.byTooltip('Rename'));
    await _pumpRouteTransition(tester);

    final nameField = find.byKey(const ValueKey('rename-calendar-field'));
    await tester.enterText(nameField, 'Retry draft');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpRouteTransition(tester);

    expect(nameField, findsOneWidget);
    expect(find.text('Retry draft'), findsOneWidget);
    expect(provider.generalSchedules.single.name, 'Original calendar');
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _pumpRouteTransition(tester);

    expect(nameField, findsNothing);
    expect(provider.generalSchedules.single.name, 'Retry draft');
    expect(storage.saveCount, baselineSaveCount + 2);
  });

  testWidgets('calendar delete failure keeps confirmation open for retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const primary = GeneralSchedule(
      id: 'cal1',
      name: 'Primary calendar',
      events: [],
    );
    const secondary = GeneralSchedule(
      id: 'cal2',
      name: 'Secondary calendar',
      events: [],
    );
    final storage = _FailOnceTimetableStorage(
      _buildGeneralDataWithCalendars([
        primary,
        secondary,
      ], activeId: primary.id),
    );
    final provider = await _createProviderWithStorage(storage);
    final baselineSaveCount = storage.saveCount;
    storage.failNextSave = true;
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.byTooltip('Calendars'));
    await _pumpRouteTransition(tester);
    await tester.tap(find.byTooltip('Delete').last);
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _pumpRouteTransition(tester);

    expect(find.text('Delete calendar'), findsOneWidget);
    expect(provider.generalSchedules, hasLength(2));
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _pumpRouteTransition(tester);

    expect(find.text('Delete calendar'), findsNothing);
    expect(provider.generalSchedules.map((item) => item.id), [primary.id]);
    expect(storage.saveCount, baselineSaveCount + 2);
  });

  testWidgets('week view swipes horizontally to change week', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.fling(
      find.byKey(_generalWeekPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 23);
    expect(find.byType(GeneralEventEditorSheet), findsNothing);
  });

  testWidgets('week view keeps selected day visible when weekends are hidden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-20',
          defaultView: generalViewWeek,
          showWeekends: false,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 22);
    expect(find.text('22'), findsWidgets);
    expect(find.text('20'), findsNothing);
    expect(find.text('21'), findsNothing);

    await tester.fling(
      find.byKey(_generalWeekPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 29);
    expect(find.text('29'), findsWidgets);
    expect(find.text('27'), findsNothing);
    expect(find.text('28'), findsNothing);
  });

  testWidgets('day view normalizes hidden weekend selection to visible day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-21',
          defaultView: generalViewDay,
          showWeekends: false,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 22);
    expect(find.text('22'), findsWidgets);
    expect(find.text('20'), findsNothing);
    expect(find.text('21'), findsNothing);
  });

  testWidgets('week and day views show month rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-05-25',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('5月'), findsWidgets);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    expect(find.text('5月'), findsWidgets);
  });

  testWidgets('week view month rail label is centered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-07-20',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final labelBox = tester.getRect(find.text('7月').first);
    expect(labelBox.center.dx, closeTo(26, 1));
  });

  testWidgets('week view keeps the final time label inside the grid', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-07-20',
          defaultView: generalViewWeek,
          dayStartHour: 6,
          dayEndHour: 23,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final gridRect = tester.getRect(
      find.byKey(const ValueKey('general-timeline-grid')),
    );
    final finalLabelRect = tester.getRect(find.text('23:00'));

    expect(finalLabelRect.top, greaterThanOrEqualTo(gridRect.top));
    expect(finalLabelRect.bottom, lessThanOrEqualTo(gridRect.bottom));
  });

  testWidgets('week header stays static when tapping a day label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-05-18',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.byKey(_generalWeekPagerKey), findsOneWidget);
    expect(find.text('All day'), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey('general-week-day-header-2026-05-20T00:00:00.000'),
      ),
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 5);
    expect(provider.selectedGeneralDate.day, 18);
    expect(find.byKey(_generalWeekPagerKey), findsOneWidget);
    expect(find.byKey(_generalDayPagerKey), findsNothing);
  });

  testWidgets('week view lays overlapping timed events side by side', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title: 'Alpha',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
        GeneralEvent(
          id: 'evt2',
          calendarId: 'cal1',
          title: 'Beta',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final cardFinders = [
      find.byKey(
        const ValueKey('general-timed-occurrence-evt1-2026-06-17T08:00:00.000'),
      ),
      find.byKey(
        const ValueKey('general-timed-occurrence-evt2-2026-06-17T08:00:00.000'),
      ),
    ];
    final rects = [for (final finder in cardFinders) tester.getRect(finder)]
      ..sort((a, b) => a.left.compareTo(b.left));

    expect(rects[1].width, closeTo(rects[0].width, 0.5));
    expect(rects[1].left, greaterThanOrEqualTo(rects[0].right));
    expect(
      find.byKey(
        const ValueKey(
          'general-timed-more-occurrences-evt1-2026-06-17T08:00:00.000',
        ),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('week view collapses three crowded timed events into more card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title: 'Alpha',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
        GeneralEvent(
          id: 'evt2',
          calendarId: 'cal1',
          title: 'Beta',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
        GeneralEvent(
          id: 'evt3',
          calendarId: 'cal1',
          title: 'Gamma',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    const firstCardKey = ValueKey(
      'general-timed-occurrence-evt1-2026-06-17T08:00:00.000',
    );
    const secondCardKey = ValueKey(
      'general-timed-occurrence-evt2-2026-06-17T08:00:00.000',
    );
    const thirdCardKey = ValueKey(
      'general-timed-occurrence-evt3-2026-06-17T08:00:00.000',
    );
    const moreCardKey = ValueKey(
      'general-timed-more-occurrences-evt1-2026-06-17T08:00:00.000',
    );

    expect(find.byKey(firstCardKey), findsOneWidget);
    expect(find.byKey(secondCardKey), findsNothing);
    expect(find.byKey(thirdCardKey), findsNothing);
    expect(find.byKey(moreCardKey), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.byKey(moreCardKey));
    await tester.pumpAndSettle();

    expect(find.text('17, 3 events'), findsOneWidget);
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);

    await tester.tap(find.text('Gamma'));
    await tester.pumpAndSettle();

    expect(find.text('17, 3 events'), findsNothing);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Edit event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week view collapses partial events in a crowded time group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title: 'Long',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T10:00:00.000',
        ),
        GeneralEvent(
          id: 'evt2',
          calendarId: 'cal1',
          title: 'Short A',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
        GeneralEvent(
          id: 'evt3',
          calendarId: 'cal1',
          title: 'Short B',
          startDateTimeIso: '2026-06-17T08:30:00.000',
          endDateTimeIso: '2026-06-17T09:30:00.000',
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    const primaryCardKey = ValueKey(
      'general-timed-occurrence-evt1-2026-06-17T08:00:00.000',
    );
    const shortACardKey = ValueKey(
      'general-timed-occurrence-evt2-2026-06-17T08:00:00.000',
    );
    const shortBCardKey = ValueKey(
      'general-timed-occurrence-evt3-2026-06-17T08:30:00.000',
    );
    const moreCardKey = ValueKey(
      'general-timed-more-occurrences-evt1-2026-06-17T08:00:00.000',
    );

    expect(find.byKey(primaryCardKey), findsOneWidget);
    expect(find.byKey(shortACardKey), findsNothing);
    expect(find.byKey(shortBCardKey), findsNothing);
    expect(find.byKey(moreCardKey), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    final primaryRect = tester.getRect(find.byKey(primaryCardKey));
    final moreRect = tester.getRect(find.byKey(moreCardKey));
    expect(moreRect.width, closeTo(primaryRect.width, 0.5));
    expect(moreRect.left, greaterThanOrEqualTo(primaryRect.right));

    await tester.tap(find.byKey(moreCardKey));
    await tester.pumpAndSettle();

    expect(find.text('17, 3 events'), findsOneWidget);
    expect(find.text('Long'), findsWidgets);
    expect(find.text('Short A'), findsOneWidget);
    expect(find.text('Short B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week view empty slots open editor only on long press', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final slot = find.byKey(
      const ValueKey('general-timeline-empty-slot-2026-06-17T00:00:00.000'),
    );
    final slotRect = tester.getRect(slot);
    final slotPoint = Offset(slotRect.center.dx, slotRect.top + 160);

    await tester.tapAt(slotPoint);
    await tester.pumpAndSettle();

    expect(find.byType(GeneralEventEditorSheet), findsNothing);

    await tester.longPressAt(slotPoint);
    await tester.pumpAndSettle();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
  });

  testWidgets('general schedule home hides search and filter controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-05-25',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('Search events'), findsNothing);
    expect(find.byTooltip('Filter by color'), findsNothing);
  });

  testWidgets('list view event cards fit narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar with a long display name',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title:
              'Planning session with a very long event title that should wrap safely',
          startDateTimeIso: '2026-06-16T09:00:00.000',
          endDateTimeIso: '2026-06-16T10:00:00.000',
          location:
              'Conference room with a very long location name and extra notes',
          recurrenceRule: GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.weekly,
          ),
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewList,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Pick date'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('day view selects a day from the week strip', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.text('18').first);
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 18);
  });

  testWidgets('day view empty slots open editor only on long press', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final slot = find.byKey(
      const ValueKey('general-timeline-empty-slot-2026-06-16T00:00:00.000'),
    );
    final slotRect = tester.getRect(slot);
    final slotPoint = Offset(slotRect.center.dx, slotRect.top + 160);

    await tester.tapAt(slotPoint);
    await tester.pumpAndSettle();

    expect(find.byType(GeneralEventEditorSheet), findsNothing);

    await tester.longPressAt(slotPoint);
    await tester.pumpAndSettle();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
  });

  testWidgets('day view swipes the week strip to change week', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.fling(
      find.byKey(_generalDayWeekPickerPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 23);
  });

  testWidgets('day view swipes horizontally to change day', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.fling(
      find.byKey(_generalDayPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 17);
  });

  testWidgets('day view picker selection follows horizontal drag progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final indicator = find.byKey(_generalDayPickerSelectionIndicatorKey);
    expect(indicator, findsOneWidget);
    final initialLeft = tester.getTopLeft(indicator).dx;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_generalDayPagerKey)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-240, 0));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.getTopLeft(indicator).dx, greaterThan(initialLeft));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('day view picker selection wraps during cross-week drag', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-21',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final indicator = find.byKey(_generalDayPickerSelectionIndicatorKey);
    expect(indicator, findsOneWidget);
    final initialLeft = tester.getTopLeft(indicator).dx;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_generalDayPagerKey)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-520, 0));
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.getTopLeft(indicator).dx, lessThan(initialLeft));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 22);
  });

  testWidgets('day view skips weekends when weekends are hidden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-19',
          defaultView: generalViewDay,
          showWeekends: false,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.fling(
      find.byKey(_generalDayPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 22);
    expect(find.text('22'), findsWidgets);
    expect(find.text('20'), findsNothing);
    expect(find.text('21'), findsNothing);
  });

  testWidgets('day timeline buckets UTC timed events by calendar date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'utc-timed',
          calendarId: 'cal1',
          title: 'UTC planning',
          startDateTimeIso: DateTime.utc(2026, 6, 15, 9).toIso8601String(),
          endDateTimeIso: DateTime.utc(2026, 6, 15, 10).toIso8601String(),
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-15',
          defaultView: generalViewDay,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('UTC planning'), findsWidgets);
  });

  testWidgets('month view trims trailing calendar weeks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-01-15',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('month view title opens quick date picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final titleButton = find.byKey(const ValueKey('general-date-title-button'));
    expect(titleButton, findsOneWidget);

    await tester.tap(titleButton);
    await tester.tap(titleButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 16);
  });

  testWidgets('month view omits weekend cells when weekends are hidden', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-15',
          defaultView: generalViewMonth,
          showWeekends: false,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('6'), findsNothing);
    expect(find.text('7'), findsNothing);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('month view normalizes hidden weekend selection to visible day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-21',
          defaultView: generalViewMonth,
          showWeekends: false,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(provider.selectedGeneralDate.year, 2026);
    expect(provider.selectedGeneralDate.month, 6);
    expect(provider.selectedGeneralDate.day, 22);
    expect(find.text('22'), findsWidgets);
    expect(find.text('21'), findsNothing);
  });

  testWidgets('month view keeps selected day agenda', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title: 'Dentist',
          startDateTimeIso: '2026-06-15T09:00:00.000',
          endDateTimeIso: '2026-06-15T10:00:00.000',
        ),
        GeneralEvent(
          id: 'evt2',
          calendarId: 'cal1',
          title: 'Review',
          startDateTimeIso: '2026-06-15T11:00:00.000',
          endDateTimeIso: '2026-06-15T12:00:00.000',
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-15',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('Dentist'), findsWidgets);
    expect(find.text('Review'), findsWidgets);
  });

  testWidgets('month view buckets UTC all-day events by calendar date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'utc-all-day',
          calendarId: 'cal1',
          title: 'UTC holiday',
          startDateTimeIso: DateTime.utc(2026, 6, 15).toIso8601String(),
          endDateTimeIso: DateTime.utc(2026, 6, 16).toIso8601String(),
          isAllDay: true,
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-15',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('UTC holiday'), findsWidgets);
  });

  testWidgets('month view does not show all-day exclusive end date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title: 'Conference',
          startDateTimeIso: '2026-06-15T00:00:00.000',
          endDateTimeIso: '2026-06-16T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('Conference'), findsNothing);

    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    expect(find.text('Conference'), findsWidgets);
  });

  testWidgets('month view empty agenda add opens editor on selected date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-15',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final addButtons = find.byTooltip('Add event');
    expect(addButtons, findsWidgets);
    await tester.tap(addButtons.last);
    await tester.pumpAndSettle();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
  });

  testWidgets('month view fits narrow mobile height without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(tester.takeException(), isNull);
    expect(find.text('June 2026'), findsWidgets);
    expect(find.text('No upcoming events'), findsWidgets);
  });

  testWidgets('month view agenda cards fit compact phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar with a very long display name',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title:
              'Recurring project review with a very long event title for agenda',
          startDateTimeIso: '2026-06-16T09:00:00.000',
          endDateTimeIso: '2026-06-16T10:00:00.000',
          location:
              'Conference room with a very long location name and extra notes',
          recurrenceRule: GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.weekly,
          ),
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(tester.takeException(), isNull);
    expect(find.text('June 2026'), findsWidgets);
    expect(find.textContaining('Recurring project review'), findsWidgets);
  });

  testWidgets('month view fits wide short height without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1125, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-07-15',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(tester.takeException(), isNull);
    expect(find.text('July 2026'), findsWidgets);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('month view keeps the calendar panel dense on wide screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-07-15',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final panelSize = tester.getSize(
      find.byKey(const ValueKey('general-month-calendar-panel')),
    );
    expect(panelSize.width, lessThanOrEqualTo(940));
    expect(panelSize.height, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('month view shows lunar labels on Android phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh').copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(tester.takeException(), isNull);
    expect(find.text('芒种'), findsOneWidget);
    expect(find.text('端午节'), findsOneWidget);
    expect(find.text('夏至'), findsOneWidget);
  });

  testWidgets('month view compact selected day clips ripple to the selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh').copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-05',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final feedback = find.byKey(_generalMonthCompactSelectedDayFeedbackKey);
    expect(feedback, findsOneWidget);

    final feedbackSize = tester.getSize(feedback);
    final inkWell = find.descendant(
      of: feedback,
      matching: find.byType(InkWell),
    );
    expect(inkWell, findsOneWidget);
    final inkWellSize = tester.getSize(inkWell);
    final material = tester.widget<Material>(feedback);

    expect(material.shape, isA<CircleBorder>());
    expect(feedbackSize.width, closeTo(feedbackSize.height, 0.01));
    expect(inkWellSize.width, feedbackSize.width);
    expect(inkWellSize.height, feedbackSize.height);
  });

  testWidgets('month view lunar special labels follow theme colors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const festivalColor = Color(0xFF2255CC);
    const solarTermColor = Color(0xFF8844CC);
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: festivalColor,
      ).copyWith(primary: festivalColor, tertiary: solarTermColor),
    );
    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh').copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider, theme: theme);

    final festival = tester.widget<Text>(find.text('端午节'));
    final solarTerm = tester.widget<Text>(find.text('芒种'));

    expect(festival.style?.color, festivalColor);
    expect(solarTerm.style?.color, solarTermColor);
  });

  testWidgets('month view lunar labels use custom colorful text colors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const lunarColor = Color(0xFF223344);
    const festivalColor = Color(0xFFAA5500);
    const solarTermColor = Color(0xFF336600);
    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh').copyWith(
        activeMode: AppMode.general,
        themeColorMode: themeColorModeColorful,
        colorfulUiColorValues: const {
          colorfulGeneralLunarTextColorKey: 0xFF223344,
          colorfulGeneralFestivalTextColorKey: 0xFFAA5500,
          colorfulGeneralSolarTermTextColorKey: 0xFF336600,
        },
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );
    final theme = buildAppTheme(
      seedColor: Color(provider.themeSeedColorValue),
      brightness: Brightness.light,
      themeColorMode: provider.themeColorMode,
      colorfulUiColorValues: provider.colorfulUiColorValues,
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider, theme: theme);

    final festival = tester.widget<Text>(find.text('端午节'));
    final solarTerm = tester.widget<Text>(find.text('芒种'));

    expect(festival.style?.color, festivalColor);
    expect(solarTerm.style?.color, solarTermColor);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.style?.color == lunarColor,
        description: 'Text using the custom lunar date color',
      ),
      findsWidgets,
    );
  });

  testWidgets('month view shows lunar labels for traditional Chinese locale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(496, 1052));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = const GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'zh-Hant',
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(tester.takeException(), isNull);
    expect(find.text('芒种'), findsOneWidget);
    expect(find.text('端午节'), findsOneWidget);
    expect(find.text('夏至'), findsOneWidget);
  });
}
