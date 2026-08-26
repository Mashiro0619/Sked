import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_expressive_components.dart';

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
  String localeCode = defaultLocaleCode,
}) {
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: localeCode,
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
  TextDirection? textDirection,
  bool showSettingsAction = true,
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
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        builder: (context, child) {
          final mediaQuery = MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
          return textDirection == null
              ? mediaQuery
              : Directionality(textDirection: textDirection, child: mediaQuery);
        },
        home: GeneralScheduleHomeScreen(showSettingsAction: showSettingsAction),
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

String _visibleDateNavigationLabel(WidgetTester tester) {
  final labels = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('general-date-title-button')),
          matching: find.byType(Text),
        ),
      )
      .map((widget) => widget.data)
      .whereType<String>()
      .toList();
  expect(labels, hasLength(1));
  return labels.single;
}

void main() {
  testWidgets(
    'general workspace has one navigation group and one primary add action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = await _createProvider();
      await _pumpGeneralScheduleHomeScreen(tester, provider);

      expect(find.byType(SkedPrimaryFab), findsOneWidget);
      expect(find.byTooltip('Add event'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(
        find.byKey(const ValueKey('general-view-switcher')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('general-date-title-button')),
        findsOneWidget,
      );
      expect(find.byTooltip('Previous page'), findsNothing);
      expect(find.byTooltip('Next page'), findsNothing);
      expect(find.text('Today'), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date navigation shows its period without arrow controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-06-19',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      textDirection: TextDirection.rtl,
    );

    final dateButton = find.byKey(const ValueKey('general-date-title-button'));
    expect(_visibleDateNavigationLabel(tester), '2026/6/15\u20132026/6/21');
    expect(
      find.descendant(
        of: dateButton,
        matching: find.byIcon(Icons.event_outlined),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Previous page'), findsNothing);
    expect(find.byTooltip('Next page'), findsNothing);
    expect(find.text('Pick date'), findsNothing);
  });

  testWidgets('compact week date shows both months across a boundary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-09-02',
          defaultView: generalViewWeek,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final dateButton = find.byKey(const ValueKey('general-date-title-button'));
    expect(
      find.descendant(of: dateButton, matching: find.text('8/31\u20139/6')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ISO compact week candidates keep zero-padded month and day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-07-01',
          defaultView: generalViewWeek,
          dateLabelFormat: generalDateLabelFormatIso,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final label = _visibleDateNavigationLabel(tester);
    // A compressed ISO candidate may omit the year or the first endpoint's
    // month, but it must never turn 06/07 or 05 into unpadded values.
    expect(
      RegExp(r'(?<!\d)[1-9]-(?:0?[1-9]|[12]\d|3[01])(?!\d)').hasMatch(label),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'embedded inactive general workspace has no standalone scaffold or FAB',
    (tester) async {
      final base = _buildGeneralDataWithCalendars([
        const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
      ], activeId: 'cal1');
      final provider = await _createGeneralProvider(
        base.copyWith(
          generalMode: base.generalMode.copyWith(
            defaultView: generalViewDay,
            selectedDateIso: '2026-06-16',
          ),
        ),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: appLocaleFromCode(provider.localeCode),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Material(
              child: GeneralScheduleHomeScreen(
                embedded: true,
                active: false,
                interactive: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectedBeforeTap = provider.selectedGeneralDate;
      await tester.tap(find.byKey(const ValueKey('general-date-title-button')));
      await tester.pump();

      expect(find.byType(Scaffold), findsNothing);
      expect(find.byType(SkedPrimaryFab), findsNothing);
      expect(provider.selectedGeneralDate, selectedBeforeTap);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inactive embedded general workspace hides its FAB', (
    tester,
  ) async {
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(showAddEventFab: true),
      ),
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: appLocaleFromCode(provider.localeCode),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Material(
            child: GeneralScheduleHomeScreen(
              embedded: true,
              active: false,
              interactive: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(provider.showAddEventFab, isTrue);
    expect(find.byType(SkedPrimaryFab), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active calendar state does not filter or rename the visible scope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final calendars = [
        GeneralSchedule(
          id: 'cal1',
          name: 'Primary calendar',
          events: [
            GeneralEvent(
              id: 'primary-event',
              calendarId: 'cal1',
              title: 'Primary event',
              startDateTimeIso: '2026-06-16T09:00:00.000',
              endDateTimeIso: '2026-06-16T10:00:00.000',
            ),
          ],
        ),
        GeneralSchedule(
          id: 'cal2',
          name: 'Secondary calendar',
          events: [
            GeneralEvent(
              id: 'secondary-event',
              calendarId: 'cal2',
              title: 'Secondary event',
              startDateTimeIso: '2026-06-16T11:00:00.000',
              endDateTimeIso: '2026-06-16T12:00:00.000',
            ),
          ],
        ),
      ];
      final initialData = _buildGeneralDataWithCalendars(
        calendars,
        activeId: 'cal1',
      );
      final provider = await _createGeneralProvider(
        initialData.copyWith(
          generalMode: initialData.generalMode.copyWith(
            defaultView: generalViewList,
          ),
        ),
      );
      await _pumpGeneralScheduleHomeScreen(tester, provider);

      final selector = find.byKey(const ValueKey('general-calendar-selector'));
      final l10n = AppLocalizations.of(tester.element(selector));
      expect(
        find.descendant(
          of: selector,
          matching: find.text(l10n.visibleCategoryCount(2)),
        ),
        findsOneWidget,
      );
      expect(find.text('Primary event'), findsOneWidget);
      expect(find.text('Secondary event'), findsOneWidget);

      await provider.switchGeneralSchedule('cal2');
      await tester.pump();

      expect(
        find.descendant(
          of: selector,
          matching: find.text(l10n.visibleCategoryCount(2)),
        ),
        findsOneWidget,
      );
      expect(find.text('Primary event'), findsOneWidget);
      expect(find.text('Secondary event'), findsOneWidget);
    },
  );

  testWidgets('shared date navigation works across week and month views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-06-19',
          showWeekends: false,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final initialDate = provider.selectedGeneralDate;
    await tester.fling(
      find.byKey(_generalWeekPagerKey),
      const Offset(-600, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(provider.selectedGeneralDate, isNot(initialDate));

    await tester.fling(
      find.byKey(_generalWeekPagerKey),
      const Offset(600, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(provider.selectedGeneralDate, initialDate);

    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await provider.setSelectedGeneralDate(DateTime(2026, 6, 19));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byKey(_generalDayPagerKey),
      const Offset(-600, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(provider.selectedGeneralDate, DateTime(2026, 6, 22));
    await tester.fling(
      find.byKey(_generalDayPagerKey),
      const Offset(600, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(provider.selectedGeneralDate, DateTime(2026, 6, 19));

    await tester.longPress(
      find.byKey(const ValueKey('general-date-title-button')),
    );
    await tester.pumpAndSettle();
    var today = normalizeDateOnly(DateTime.now());
    if (!provider.generalShowWeekends && today.weekday > DateTime.friday) {
      today = addCalendarDays(today, 8 - today.weekday);
    }
    expect(provider.selectedGeneralDate.year, today.year);
    expect(provider.selectedGeneralDate.month, today.month);
    expect(provider.selectedGeneralDate.day, today.day);

    await tester.tap(find.byKey(const ValueKey('general-date-title-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Previous month'), findsNothing);
    expect(find.byTooltip('Next month'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact date button keeps its date semantics', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final base = _buildGeneralDataWithCalendars(
      [const GeneralSchedule(id: 'cal1', name: 'Calendar', events: [])],
      activeId: 'cal1',
      localeCode: 'zh',
    );
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-08-11',
          defaultView: generalViewDay,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final dateButton = find.byKey(const ValueKey('general-date-title-button'));
    expect(tester.getSize(dateButton).height, greaterThanOrEqualTo(48));
    expect(_visibleDateNavigationLabel(tester), '2026/8/11');
    expect(
      find.descendant(
        of: dateButton,
        matching: find.textContaining(RegExp('[\u5e74\u6708\u65e5]')),
      ),
      findsNothing,
    );
    final dateSemantics = tester.getSemantics(dateButton).getSemanticsData();
    expect(dateSemantics.label, contains('2026'));
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(of: dateButton, matching: find.byType(Tooltip)).first,
    );
    expect(tooltip.message, contains('2026'));
    await tester.longPress(dateButton);
    await tester.pumpAndSettle();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('view switching leaves the selected date unchanged', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-06-16',
          defaultView: generalViewWeek,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final initialDate = provider.selectedGeneralDate;
    final dateButton = find.byKey(const ValueKey('general-date-title-button'));
    expect(_visibleDateNavigationLabel(tester), '2026/6/15\u20132026/6/21');
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: dateButton, matching: find.text('2026/6/16')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: dateButton, matching: find.text('2026/6/16')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: dateButton, matching: find.text('2026/6')),
      findsOneWidget,
    );
    expect(provider.selectedGeneralDate, initialDate);
    expect(find.byTooltip('Previous month'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('view switch button cycles through every view and wraps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await _createProvider();
    await _pumpGeneralScheduleHomeScreen(tester, provider);
    final initialDate = provider.selectedGeneralDate;

    Future<void> tapNext() async {
      await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
      await tester.pumpAndSettle();
    }

    String switchTooltip() {
      return tester
          .widget<Tooltip>(
            find.descendant(
              of: find.byKey(const ValueKey('general-view-switcher')),
              matching: find.byType(Tooltip),
            ),
          )
          .message!;
    }

    expect(switchTooltip(), 'Switch view: Week -> Day');
    await tapNext();
    expect(switchTooltip(), 'Switch view: Day -> List');
    await tapNext();
    expect(switchTooltip(), 'Switch view: List -> Month');
    await tapNext();
    expect(switchTooltip(), 'Switch view: Month -> Week');
    await tapNext();
    expect(switchTooltip(), 'Switch view: Week -> Day');
    expect(provider.selectedGeneralDate, initialDate);
  });

  testWidgets('menu view switcher opens, cancels, and selects once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          viewSwitchBehavior: generalViewSwitchBehaviorMenu,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final switcher = find.byKey(const ValueKey('general-view-switcher'));
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(find.text('Day').last, findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(find.byTooltip('Choose view: Week'), findsOneWidget);

    await tester.tap(switcher);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Choose view: Month'), findsOneWidget);
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(provider.selectedGeneralDate, DateTime(2026, 6, 16));
  });

  testWidgets('compact navigation keeps settings and date controls reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(
        id: 'cal1',
        name: 'A deliberately long calendar name',
        events: [],
      ),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(base);
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    for (final size in const [
      Size(320, 568),
      Size(390, 844),
      Size(430, 776),
      Size(600, 680),
      Size(900, 360),
      Size(1120, 680),
      Size(1268, 680),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();

      final calendar = find.byKey(const ValueKey('general-calendar-selector'));
      final switcher = find.byKey(const ValueKey('general-view-switcher'));
      final dateButton = find.byKey(
        const ValueKey('general-date-title-button'),
      );
      final settings = find.byKey(const ValueKey('general-settings-button'));
      final toolbar = find.byKey(const ValueKey('general-workspace-toolbar'));
      final calendarRect = tester.getRect(calendar);
      final switcherRect = tester.getRect(switcher);
      final dateRect = tester.getRect(dateButton);
      final settingsRect = tester.getRect(settings);

      expect(settingsRect.size, const Size(48, 48), reason: '$size');
      expect(calendarRect.height, greaterThanOrEqualTo(48), reason: '$size');
      expect(switcherRect.height, greaterThanOrEqualTo(48), reason: '$size');
      expect(dateRect.height, greaterThanOrEqualTo(48), reason: '$size');
      expect(calendarRect.width, inInclusiveRange(48, 280), reason: '$size');
      expect(dateRect.width, greaterThanOrEqualTo(72), reason: '$size');
      expect(
        calendarRect.width + dateRect.width + 108,
        lessThanOrEqualTo(size.width - (size.width < 360 ? 16 : 24)),
        reason: '$size',
      );
      expect(
        calendarRect.center.dy,
        closeTo(settingsRect.center.dy, 1),
        reason: '$size',
      );
      expect(
        switcherRect.center.dy,
        closeTo(settingsRect.center.dy, 1),
        reason: '$size',
      );
      expect(
        dateRect.center.dy,
        closeTo(settingsRect.center.dy, 1),
        reason: '$size',
      );
      expect(calendarRect.right, lessThanOrEqualTo(dateRect.left));
      expect(dateRect.right, lessThanOrEqualTo(switcherRect.left));
      expect(switcherRect.right, lessThanOrEqualTo(settingsRect.left));
      expect(tester.getSize(toolbar).height, lessThanOrEqualTo(64));
      final calendarButton = tester.widget<TextButton>(calendar);
      expect(calendarButton, isNot(isA<OutlinedButton>()), reason: '$size');
      expect(calendarButton.style?.side, isNull, reason: '$size');
      expect(
        find.descendant(
          of: calendar,
          matching: find.byIcon(Icons.calendar_month_outlined),
        ),
        findsNothing,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('wide content layout caps calendar and expands numeric date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(
        id: 'cal1',
        name: 'A deliberately long calendar name',
        events: [],
      ),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(base);
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      showSettingsAction: false,
    );

    final calendar = find.byKey(const ValueKey('general-calendar-selector'));
    final switcher = find.byKey(const ValueKey('general-view-switcher'));
    final dateButton = find.byKey(const ValueKey('general-date-title-button'));
    final toolbar = find.byKey(const ValueKey('general-workspace-toolbar'));
    final calendarRect = tester.getRect(calendar);
    final switcherRect = tester.getRect(switcher);
    final dateRect = tester.getRect(dateButton);

    expect(calendarRect.width, lessThanOrEqualTo(280));
    expect(calendarRect.width, lessThan(tester.getSize(toolbar).width / 2));
    expect(dateRect.width, greaterThan(320));
    expect(calendarRect.center.dy, closeTo(dateRect.center.dy, 1));
    expect(switcherRect.center.dy, closeTo(dateRect.center.dy, 1));
    expect(
      find.descendant(
        of: calendar,
        matching: find.byIcon(Icons.calendar_month_outlined),
      ),
      findsNothing,
    );
    expect(_visibleDateNavigationLabel(tester), '2026/6/15\u20132026/6/21');
    expect(find.byKey(const ValueKey('general-settings-button')), findsNothing);

    await provider.setSelectedGeneralDate(DateTime(2026, 9, 2));
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026/8/31\u20132026/9/6');

    await provider.setSelectedGeneralDate(DateTime(2027, 1, 1));
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026/12/28\u20132027/1/3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar width policies reallocate calendar and date slots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(
        id: 'cal1',
        name: 'A deliberately long calendar name for width allocation',
        events: [],
      ),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(base);
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      showSettingsAction: false,
    );

    final initialDate = provider.selectedGeneralDate;
    final initialView = provider.generalDefaultView;
    final calendar = find.byKey(const ValueKey('general-calendar-selector'));
    final dateButton = find.byKey(const ValueKey('general-date-title-button'));

    Future<(double, double)> measure() async {
      await tester.pumpAndSettle();
      return (tester.getSize(calendar).width, tester.getSize(dateButton).width);
    }

    final content = await measure();
    expect(content.$1, lessThanOrEqualTo(280));
    expect(content.$2, greaterThan(content.$1));

    await provider.updateGeneralDisplaySettings(
      toolbarWidthPolicy: generalToolbarWidthPolicyBalanced,
    );
    final balanced = await measure();
    expect(balanced.$1, closeTo(balanced.$2, 1));

    await provider.updateGeneralDisplaySettings(
      toolbarWidthPolicy: generalToolbarWidthPolicyCalendarPriority,
    );
    final calendarPriority = await measure();
    expect(calendarPriority.$1 / calendarPriority.$2, closeTo(1.5, 0.03));

    await provider.updateGeneralDisplaySettings(
      toolbarWidthPolicy: generalToolbarWidthPolicyDatePriority,
    );
    final datePriority = await measure();
    expect(datePriority.$2 / datePriority.$1, closeTo(1.5, 0.03));
    expect(provider.selectedGeneralDate, initialDate);
    expect(provider.generalDefaultView, initialView);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date format preference drives every general schedule view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1120, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars(
      const [GeneralSchedule(id: 'cal1', name: 'Calendar', events: [])],
      activeId: 'cal1',
      localeCode: 'zh',
    );
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-07-15',
          dateLabelFormat: generalDateLabelFormatSlash,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      showSettingsAction: false,
    );

    expect(_visibleDateNavigationLabel(tester), '2026/7/13\u20132026/7/19');

    await provider.updateGeneralDisplaySettings(
      dateLabelFormat: generalDateLabelFormatIso,
    );
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026-07-13\u20132026-07-19');

    final switcher = find.byKey(const ValueKey('general-view-switcher'));
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026-07-15');

    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026-07-15');

    await tester.tap(switcher);
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026-07');

    await provider.updateGeneralDisplaySettings(
      dateLabelFormat: generalDateLabelFormatLocalized,
    );
    await tester.pumpAndSettle();
    expect(_visibleDateNavigationLabel(tester), '2026\u5e747\u6708');
    expect(tester.takeException(), isNull);
  });

  testWidgets('toolbar minima shrink continuously at the soft-width boundary', (
    tester,
  ) async {
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          toolbarWidthPolicy: generalToolbarWidthPolicyDatePriority,
        ),
      ),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    Future<(double, double)> measureAt(double width) async {
      await tester.binding.setSurfaceSize(Size(width, 568));
      await tester.pumpAndSettle();
      return (
        tester
            .getSize(find.byKey(const ValueKey('general-calendar-selector')))
            .width,
        tester
            .getSize(find.byKey(const ValueKey('general-date-title-button')))
            .width,
      );
    }

    final before = await measureAt(291);
    final after = await measureAt(292);
    expect((after.$1 - before.$1).abs(), lessThan(2));
    expect((after.$2 - before.$2).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty list view renders its empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(defaultView: generalViewList),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('No upcoming events'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each schedule view opens a tapped event from the shared home', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'view-event',
          calendarId: 'cal1',
          title: 'View event',
          startDateTimeIso: '2026-06-16T09:00:00.000',
          endDateTimeIso: '2026-06-16T10:00:00.000',
        ),
      ],
    );
    final base = _buildGeneralDataWithCalendars([calendar], activeId: 'cal1');
    final provider = await _createGeneralProvider(base);
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    Future<void> openAndCloseDetails(Finder target) async {
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(GeneralEventDetailsSheet))).pop();
      await tester.pumpAndSettle();
    }

    final timedKey = find.byKey(
      const ValueKey(
        'general-timed-occurrence-view-event-2026-06-16T09:00:00.000',
      ),
    );
    await openAndCloseDetails(timedKey);

    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await openAndCloseDetails(
      find.byKey(
        const ValueKey(
          'general-timed-occurrence-view-event-2026-06-16T09:00:00.000',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await openAndCloseDetails(find.text('View event'));

    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();
    await openAndCloseDetails(find.text('View event'));

    expect(tester.takeException(), isNull);
  });

  testWidgets('day view exposes the more-events action for crowded slots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final events = [
      for (var index = 0; index < 3; index++)
        GeneralEvent(
          id: 'day-more-$index',
          calendarId: 'cal1',
          title: 'Day event $index',
          startDateTimeIso: '2026-06-16T08:00:00.000',
          endDateTimeIso: '2026-06-16T09:00:00.000',
        ),
    ];
    final base = _buildGeneralDataWithCalendars([
      GeneralSchedule(id: 'cal1', name: 'Calendar', events: events),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(defaultView: generalViewDay),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final more = find.byKey(
      const ValueKey(
        'general-timed-more-occurrences-day-more-0-2026-06-16T08:00:00.000',
      ),
    );
    expect(more, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('16, 3 events'), findsOneWidget);
    await tester.tap(find.text('Day event 1'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(GeneralEventDetailsSheet))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
    expect(editorSheet.clipBehavior, Clip.antiAlias);
    final title = find.descendant(
      of: find.byType(GeneralEventEditorSheet),
      matching: find.text('Add event'),
    );
    expect(title, findsOneWidget);
    final sheetRect = tester.getRect(find.byType(BottomSheet));
    expect(
      tester.getTopLeft(title).dy - sheetRect.top,
      greaterThanOrEqualTo(20),
    );
  });

  testWidgets('add event FAB setting rebuilds the home screen immediately', (
    tester,
  ) async {
    final base = _buildGeneralDataWithCalendars([
      const GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(showAddEventFab: false),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(provider.showAddEventFab, isFalse);
    expect(find.byType(SkedPrimaryFab), findsNothing);

    await provider.updateGeneralDisplaySettings(showAddEventFab: true);
    await tester.pumpAndSettle();

    expect(provider.showAddEventFab, isTrue);
    expect(find.byType(SkedPrimaryFab), findsOneWidget);

    await provider.updateGeneralDisplaySettings(showAddEventFab: false);
    await tester.pumpAndSettle();

    expect(provider.showAddEventFab, isFalse);
    expect(find.byType(SkedPrimaryFab), findsNothing);
    expect(tester.takeException(), isNull);
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
    final initialScheduleId = provider.generalSchedules.single.id;
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final selector = find.byKey(const ValueKey('general-calendar-selector'));
    final l10n = AppLocalizations.of(tester.element(selector));
    final calendarsButton = find.byTooltip(l10n.calendars);
    expect(calendarsButton, findsOneWidget);

    await tester.tap(calendarsButton);
    await tester.pumpAndSettle();

    final addCalendarButton = find.byTooltip(l10n.addCalendar);
    expect(addCalendarButton, findsOneWidget);
    expect(tester.getSize(addCalendarButton), const Size(48, 48));
    expect(
      tester
          .getSize(
            find.byKey(ValueKey('calendar-manager-tile-$initialScheduleId')),
          )
          .height,
      closeTo(64, 1),
    );

    await tester.tap(addCalendarButton);
    await tester.tap(addCalendarButton, warnIfMissed: false);
    await storage.firstSaveStarted.future;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(provider.generalSchedules, hasLength(2));
    final managerSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(managerSheet.enableDrag, isFalse);
    expect(managerSheet.showDragHandle, isFalse);
    expect(
      tester
          .getSize(
            find.byKey(ValueKey('calendar-manager-tile-$initialScheduleId')),
          )
          .width,
      lessThanOrEqualTo(536),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();

    expect(find.byTooltip(l10n.addCalendar), findsOneWidget);
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

    final selector = find.byKey(const ValueKey('general-calendar-selector'));
    final l10n = AppLocalizations.of(tester.element(selector));
    await tester.tap(find.byTooltip(l10n.calendars));
    await tester.pumpAndSettle();

    expect(find.text(l10n.calendars), findsWidgets);
    expect(find.byTooltip(l10n.addCalendar), findsOneWidget);
    final firstCalendar = tester.getSemantics(
      find.byKey(const ValueKey('calendar-manager-tile-cal1')),
    );
    final flags = firstCalendar.getSemanticsData().flagsCollection;
    expect(flags.isSelected, ui.Tristate.none);
    expect(flags.isToggled, ui.Tristate.isTrue);
    expect(flags.isButton, isTrue);
    final visibilityButton = find.byKey(
      const ValueKey('calendar-visibility-cal1'),
    );
    final actionsButton = find.byKey(const ValueKey('calendar-actions-cal1'));
    expect(tester.getSize(visibilityButton), const Size(48, 48));
    expect(tester.getSize(actionsButton), const Size(48, 48));
    expect(
      tester.getCenter(visibilityButton).dy,
      closeTo(tester.getCenter(actionsButton).dy, 1),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('calendar manager keeps actions inline in RTL', (tester) async {
    await tester.binding.setSurfaceSize(const Size(560, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const schedule = GeneralSchedule(
      id: 'cal1',
      name: 'A long category name that still leaves both actions reachable',
      events: [],
    );
    final provider = await _createGeneralProvider(
      _buildGeneralDataWithCalendars(const [schedule], activeId: schedule.id),
    );
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      textScaler: const TextScaler.linear(1.3),
      textDirection: TextDirection.rtl,
    );

    await tester.tap(find.byKey(const ValueKey('general-calendar-selector')));
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('calendar-manager-tile-cal1'));
    final visibility = find.byKey(const ValueKey('calendar-visibility-cal1'));
    final actions = find.byKey(const ValueKey('calendar-actions-cal1'));
    expect(tester.getSize(tile).width, lessThanOrEqualTo(536));
    expect(tester.getSize(visibility), const Size(48, 48));
    expect(tester.getSize(actions), const Size(48, 48));
    expect(
      tester.getCenter(visibility).dy,
      closeTo(tester.getCenter(actions).dy, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar row and visibility action each save once', (
    tester,
  ) async {
    const primary = GeneralSchedule(
      id: 'cal1',
      name: 'Primary category',
      events: [],
    );
    const secondary = GeneralSchedule(
      id: 'cal2',
      name: 'Secondary category',
      events: [],
    );
    final storage = _FailOnceTimetableStorage(
      _buildGeneralDataWithCalendars(const [
        primary,
        secondary,
      ], activeId: primary.id),
    );
    final provider = await _createProviderWithStorage(storage);
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.byKey(const ValueKey('general-calendar-selector')));
    await tester.pumpAndSettle();
    final baselineSaveCount = storage.saveCount;

    await tester.tap(find.byKey(const ValueKey('calendar-manager-tile-cal2')));
    await tester.pumpAndSettle();
    expect(storage.saveCount, baselineSaveCount + 1);
    expect(provider.generalSchedules.last.isVisible, isFalse);
    expect(provider.activeGeneralSchedule.id, primary.id);

    await tester.tap(find.byKey(const ValueKey('calendar-visibility-cal2')));
    await tester.pumpAndSettle();
    expect(storage.saveCount, baselineSaveCount + 2);
    expect(provider.generalSchedules.last.isVisible, isTrue);
    expect(provider.activeGeneralSchedule.id, primary.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar selector summarizes all visible categories', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 776));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const primary = GeneralSchedule(
      id: 'cal1',
      name: 'Primary category',
      events: [],
    );
    const secondary = GeneralSchedule(
      id: 'cal2',
      name: 'Secondary category',
      isVisible: false,
      events: [],
    );
    final provider = await _createGeneralProvider(
      _buildGeneralDataWithCalendars([
        primary,
        secondary,
      ], activeId: primary.id),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final selector = find.byKey(const ValueKey('general-calendar-selector'));
    final l10n = AppLocalizations.of(tester.element(selector));
    expect(
      find.descendant(of: selector, matching: find.text(primary.name)),
      findsOneWidget,
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-manager-tile-cal2')));
    await tester.pumpAndSettle();
    expect(provider.generalSchedules.last.isVisible, isTrue);
    expect(provider.activeGeneralSchedule.id, primary.id);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: selector,
        matching: find.text(l10n.visibleCategoryCount(2)),
      ),
      findsOneWidget,
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-visibility-cal1')));
    await tester.pumpAndSettle();
    expect(provider.generalSchedules.first.isVisible, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: selector, matching: find.text(secondary.name)),
      findsOneWidget,
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-visibility-cal2')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: selector,
        matching: find.text(l10n.noVisibleCategories),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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

    final selector = find.byKey(const ValueKey('general-calendar-selector'));
    final l10n = AppLocalizations.of(tester.element(selector));
    await tester.tap(find.byTooltip(l10n.calendars));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.addCalendar));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.generalSchedules, hasLength(1));
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    final addButton = find.widgetWithIcon(IconButton, Icons.add);
    expect(tester.widget<IconButton>(addButton).onPressed, isNotNull);
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

    final selector = find.byKey(const ValueKey('general-calendar-selector'));
    final l10n = AppLocalizations.of(tester.element(selector));
    await tester.tap(find.byTooltip(l10n.calendars));
    await _pumpRouteTransition(tester);
    await tester.tap(find.byKey(const ValueKey('calendar-actions-cal1')));
    await _pumpRouteTransition(tester);
    await tester.tap(find.text(l10n.rename).last);
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

    final selector = find.byKey(const ValueKey('general-calendar-selector'));
    final l10n = AppLocalizations.of(tester.element(selector));
    await tester.tap(find.byTooltip(l10n.calendars));
    await _pumpRouteTransition(tester);
    await tester.tap(find.byKey(const ValueKey('calendar-actions-cal2')));
    await _pumpRouteTransition(tester);
    await tester.tap(find.text(l10n.delete).last);
    await _pumpRouteTransition(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _pumpRouteTransition(tester);

    expect(find.text(l10n.deleteCalendar), findsOneWidget);
    expect(provider.generalSchedules, hasLength(2));
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _pumpRouteTransition(tester);

    expect(find.text(l10n.deleteCalendar), findsNothing);
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

  testWidgets('week pager commits its date only after the page settles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const calendar = GeneralSchedule(id: 'cal1', name: 'Calendar', events: []);
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewWeek,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final initialDate = provider.selectedGeneralDate;
    final pageController = tester
        .widget<PageView>(find.byKey(_generalWeekPagerKey))
        .controller!;
    final initialPage = pageController.page!;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_generalWeekPagerKey)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 16));

    final draggingPage = pageController.page!;
    expect(draggingPage, greaterThan(initialPage + 0.5));
    expect(draggingPage, lessThan(initialPage + 1));
    expect(provider.selectedGeneralDate, initialDate);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate, DateTime(2026, 6, 23));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an external date change during a drag is not overwritten by the gesture',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const calendar = GeneralSchedule(
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
          generalMode: const GeneralScheduleData(
            activeScheduleId: 'cal1',
            schedules: [calendar],
            selectedDateIso: '2026-06-16',
            defaultView: generalViewWeek,
          ),
        ),
      );
      await _pumpGeneralScheduleHomeScreen(tester, provider);

      final controller = tester
          .widget<PageView>(find.byKey(_generalWeekPagerKey))
          .controller!;
      final initialPage = controller.page!;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_generalWeekPagerKey)),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-610, 0));
      await tester.pump();
      expect(controller.page, greaterThan(initialPage + 0.5));

      await provider.setSelectedGeneralDate(DateTime(2026, 6, 23));
      await tester.pump();

      await gesture.moveBy(const Offset(650, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(provider.selectedGeneralDate, DateTime(2026, 6, 23));
      expect(controller.page, closeTo(initialPage + 1, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed pager save returns to the committed week and can retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const calendar = GeneralSchedule(id: 'cal1', name: 'Calendar', events: []);
    final storage = _FailOnceTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewWeek,
        ),
      ),
    );
    final provider = await _createProviderWithStorage(storage);
    await _pumpGeneralScheduleHomeScreen(tester, provider);
    final controller = tester
        .widget<PageView>(find.byKey(_generalWeekPagerKey))
        .controller!;
    final initialPage = controller.page!;

    storage.failNextSave = true;
    await tester.fling(
      find.byKey(_generalWeekPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate, DateTime(2026, 6, 16));
    expect(controller.page, closeTo(initialPage, 0.01));
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);

    await tester.fling(
      find.byKey(_generalWeekPagerKey),
      const Offset(-700, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate, DateTime(2026, 6, 23));
    expect(tester.takeException(), isNull);
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

    expect(find.text('May'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
    await tester.pumpAndSettle();

    expect(find.text('May'), findsWidgets);
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

    final labelBox = tester.getRect(find.text('Jul').first);
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

  testWidgets('day timeline scales with the configured hour height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'short-a',
          calendarId: 'cal1',
          title: 'Short A',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T08:15:00.000',
        ),
        GeneralEvent(
          id: 'short-b',
          calendarId: 'cal1',
          title: 'Short B',
          startDateTimeIso: '2026-06-17T08:15:00.000',
          endDateTimeIso: '2026-06-17T08:30:00.000',
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
          defaultView: generalViewDay,
          dayStartHour: 8,
          dayEndHour: 10,
          timeGridMinutes: 15,
          timeGridHourHeight: generalTimeGridHourHeightMin,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final grid = find.byKey(const ValueKey('general-timeline-grid'));
    expect(tester.getSize(grid).height, closeTo(2 * 36 + 24, 0.1));
    final firstCard = tester.getRect(
      find.byKey(
        const ValueKey(
          'general-timed-occurrence-short-a-2026-06-17T08:00:00.000',
        ),
      ),
    );
    final secondCard = tester.getRect(
      find.byKey(
        const ValueKey(
          'general-timed-occurrence-short-b-2026-06-17T08:15:00.000',
        ),
      ),
    );
    expect(firstCard.bottom, lessThanOrEqualTo(secondCard.top));
    expect(find.bySemanticsLabel('Short A'), findsOneWidget);

    await provider.updateGeneralDisplaySettings(
      timeGridHourHeight: generalTimeGridHourHeightMax,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(grid).height, closeTo(2 * 120 + 24, 0.1));
    expect(find.text('Short A'), findsOneWidget);
    expect(provider.selectedGeneralDate, DateTime(2026, 6, 17));
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing hour height preserves the visible top time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const calendar = GeneralSchedule(id: 'cal1', name: 'Calendar', events: []);
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewDay,
          dayStartHour: 0,
          dayEndHour: 24,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final scrollView = find.byKey(
      const ValueKey('general-timeline-scroll-view'),
    );
    await tester.drag(scrollView, const Offset(0, -360));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: scrollView,
      matching: find.byType(Scrollable),
    );
    final oldOffset = tester.state<ScrollableState>(scrollable).position.pixels;
    final visibleMinutes = (oldOffset - 12) * 60 / 72;

    await provider.updateGeneralDisplaySettings(timeGridHourHeight: 120);
    await tester.pumpAndSettle();

    final newOffset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(newOffset, closeTo(12 + visibleMinutes * 120 / 60, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL timeline keeps headers, rail, and event columns aligned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'rtl-event',
          calendarId: 'cal1',
          title: 'RTL event',
          startDateTimeIso: '2026-06-17T08:00:00.000',
          endDateTimeIso: '2026-06-17T09:00:00.000',
        ),
        GeneralEvent(
          id: 'rtl-all-day',
          calendarId: 'cal1',
          title: 'RTL all-day',
          startDateTimeIso: '2026-06-17T00:00:00.000',
          endDateTimeIso: '2026-06-18T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final base = buildInitialAppData(
      buildDefaultPeriodTimes(),
      localeCode: 'en',
    );
    final provider = await _createGeneralProvider(
      base.copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewWeek,
          timeGridMinutes: 30,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      textDirection: TextDirection.rtl,
    );

    final header = tester.getRect(
      find.byKey(
        const ValueKey('general-week-day-header-2026-06-17T00:00:00.000'),
      ),
    );
    final card = tester.getRect(
      find.byKey(
        const ValueKey(
          'general-timed-occurrence-rtl-event-2026-06-17T08:00:00.000',
        ),
      ),
    );
    expect(card.center.dx, closeTo(header.center.dx, 1));

    final monthRail = tester.getRect(find.text('Jun').last);
    expect(monthRail.right, greaterThan(header.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'week all-day events span dates and keep Chinese labels legible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final calendar = GeneralSchedule(
        id: 'cal1',
        name: '分类',
        events: [
          GeneralEvent(
            id: 'single-all-day',
            calendarId: 'cal1',
            title: '中文全天事项',
            startDateTimeIso: '2026-06-16T00:00:00.000',
            endDateTimeIso: '2026-06-17T00:00:00.000',
            isAllDay: true,
            colorValue: 0xFFFFC1CC,
          ),
          GeneralEvent(
            id: 'spanning-all-day',
            calendarId: 'cal1',
            title: '跨天活动',
            startDateTimeIso: '2026-06-18T00:00:00.000',
            endDateTimeIso: '2026-06-21T00:00:00.000',
            isAllDay: true,
            colorValue: 0xFFC4DDF8,
          ),
        ],
      );
      final provider = await _createGeneralProvider(
        buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'zh',
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

      final timeline = find.byKey(const ValueKey('general-all-day-timeline'));
      expect(timeline, findsOneWidget);
      expect(tester.getSize(timeline).height, lessThan(74));
      expect(find.text('中文全天事项'), findsOneWidget);
      expect(find.text('跨天活动'), findsOneWidget);

      final spanningChip = find.byKey(
        const ValueKey(
          'general-all-day-occurrence-'
          'spanning-all-day-2026-06-18T00:00:00.000',
        ),
      );
      final dayHeader = find.byKey(
        const ValueKey('general-week-day-header-2026-06-18T00:00:00.000'),
      );
      expect(
        tester.getSize(spanningChip).width,
        greaterThan(tester.getSize(dayHeader).width * 2.5),
      );

      final singleChip = find.byKey(
        const ValueKey(
          'general-all-day-occurrence-'
          'single-all-day-2026-06-16T00:00:00.000',
        ),
      );
      final material = tester.widget<Material>(singleChip);
      final title = tester.widget<Text>(
        find.descendant(of: singleChip, matching: find.text('中文全天事项')),
      );
      final backgroundLuminance = material.color!.computeLuminance();
      final foregroundLuminance = title.style!.color!.computeLuminance();
      final lighter = backgroundLuminance > foregroundLuminance
          ? backgroundLuminance
          : foregroundLuminance;
      final darker = backgroundLuminance < foregroundLuminance
          ? backgroundLuminance
          : foregroundLuminance;
      expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));

      await tester.tap(singleChip);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(GeneralEventDetailsSheet))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('week all-day labels fit 320dp at 2x text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: '分类',
      events: [
        GeneralEvent(
          id: 'compact-all-day',
          calendarId: 'cal1',
          title: '中文全天事项',
          startDateTimeIso: '2026-06-16T00:00:00.000',
          endDateTimeIso: '2026-06-17T00:00:00.000',
          isAllDay: true,
          colorValue: 0xFFFFC1CC,
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh').copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-17',
          defaultView: generalViewWeek,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey('general-all-day-timeline')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(
          'general-all-day-occurrence-'
          'compact-all-day-2026-06-16T00:00:00.000',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('中文全天事项'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one all-day event stays expanded and cannot be collapsed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'only-all-day',
          calendarId: 'cal1',
          title: 'Only all-day event',
          startDateTimeIso: '2026-06-17T00:00:00.000',
          endDateTimeIso: '2026-06-18T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final base = _buildGeneralDataWithCalendars([calendar], activeId: 'cal1');
    final storage = _FailOnceTimetableStorage(
      base.copyWith(
        generalMode: base.generalMode.copyWith(allDayTimelineCollapsed: true),
      ),
    );
    final provider = await _createProviderWithStorage(storage);
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final label = find.text('All-day');
    expect(label, findsOneWidget);
    expect(find.text('Only all-day event'), findsOneWidget);
    expect(
      find.ancestor(of: label, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('general-all-day-collapsed')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all-day label collapses, persists, and expands multiple events',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final calendar = GeneralSchedule(
        id: 'cal1',
        name: 'Calendar',
        events: [
          GeneralEvent(
            id: 'first-all-day',
            calendarId: 'cal1',
            title: 'First all-day event',
            startDateTimeIso: '2026-06-16T00:00:00.000',
            endDateTimeIso: '2026-06-17T00:00:00.000',
            isAllDay: true,
          ),
          GeneralEvent(
            id: 'second-all-day',
            calendarId: 'cal1',
            title: 'Second all-day event',
            startDateTimeIso: '2026-06-18T00:00:00.000',
            endDateTimeIso: '2026-06-19T00:00:00.000',
            isAllDay: true,
          ),
        ],
      );
      final storage = _FailOnceTimetableStorage(
        _buildGeneralDataWithCalendars([calendar], activeId: 'cal1'),
      );
      final provider = await _createProviderWithStorage(storage);
      await _pumpGeneralScheduleHomeScreen(tester, provider);
      final baselineSaveCount = storage.saveCount;

      await tester.tap(find.text('All-day'));
      await tester.pumpAndSettle();

      final collapsed = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'general-all-day-collapsed',
            ),
      );
      expect(collapsed, findsNWidgets(2));
      expect(
        find.descendant(of: collapsed, matching: find.text('1')),
        findsNWidgets(2),
      );
      expect(find.text('First all-day event'), findsNothing);
      expect(find.text('Second all-day event'), findsNothing);
      expect(provider.allDayTimelineCollapsed, isTrue);
      expect(storage.data!.generalMode.allDayTimelineCollapsed, isTrue);
      expect(storage.saveCount, baselineSaveCount + 1);

      await tester.tap(find.text('All-day'));
      await tester.pumpAndSettle();

      expect(collapsed, findsNothing);
      expect(find.text('First all-day event'), findsOneWidget);
      expect(find.text('Second all-day event'), findsOneWidget);
      expect(provider.allDayTimelineCollapsed, isFalse);
      expect(storage.data!.generalMode.allDayTimelineCollapsed, isFalse);
      expect(storage.saveCount, baselineSaveCount + 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('day view collapses all all-day events into one count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'day-all-day-first',
          calendarId: 'cal1',
          title: 'Day all-day first',
          startDateTimeIso: '2026-06-17T00:00:00.000',
          endDateTimeIso: '2026-06-18T00:00:00.000',
          isAllDay: true,
        ),
        GeneralEvent(
          id: 'day-all-day-second',
          calendarId: 'cal1',
          title: 'Day all-day second',
          startDateTimeIso: '2026-06-17T00:00:00.000',
          endDateTimeIso: '2026-06-18T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final base = _buildGeneralDataWithCalendars([calendar], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          selectedDateIso: '2026-06-17',
          defaultView: generalViewDay,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(find.text('Day all-day first'), findsOneWidget);
    expect(find.text('Day all-day second'), findsOneWidget);

    final expandedTransition = find.byKey(
      const ValueKey('general-all-day-transition'),
    );
    final expandedHeight = tester.getSize(expandedTransition).height;

    await tester.tap(find.text('All-day'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(provider.allDayTimelineCollapsed, isTrue);
    await tester.pump(const Duration(milliseconds: 120));
    final midTransitionHeight = tester.getSize(expandedTransition).height;
    expect(midTransitionHeight, lessThan(expandedHeight));
    expect(midTransitionHeight, greaterThan(48));
    await tester.pumpAndSettle();

    final collapsed = find.byKey(const ValueKey('general-all-day-collapsed'));
    expect(collapsed, findsOneWidget);
    expect(
      find.descendant(of: collapsed, matching: find.text('2')),
      findsOneWidget,
    );
    expect(find.text('Day all-day first'), findsNothing);
    expect(find.text('Day all-day second'), findsNothing);

    await tester.tap(find.text('All-day'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(provider.allDayTimelineCollapsed, isFalse);
    await tester.pump(const Duration(milliseconds: 120));
    final midExpandHeight = tester.getSize(expandedTransition).height;
    expect(midExpandHeight, greaterThan(48));
    expect(midExpandHeight, lessThan(expandedHeight));
    await tester.pumpAndSettle();
    expect(find.text('Day all-day first'), findsOneWidget);
    expect(find.text('Day all-day second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapsed week blocks open the events for their own day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        GeneralEvent(
          id: 'collapsed-tuesday',
          calendarId: 'cal1',
          title: 'Tuesday all-day',
          startDateTimeIso: '2026-06-16T00:00:00.000',
          endDateTimeIso: '2026-06-17T00:00:00.000',
          isAllDay: true,
        ),
        GeneralEvent(
          id: 'collapsed-thursday',
          calendarId: 'cal1',
          title: 'Thursday all-day',
          startDateTimeIso: '2026-06-18T00:00:00.000',
          endDateTimeIso: '2026-06-19T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      _buildGeneralDataWithCalendars([calendar], activeId: 'cal1'),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.text('All-day'));
    await tester.pumpAndSettle();

    final tuesday = find.byKey(const ValueKey('general-all-day-collapsed-1'));
    expect(tuesday, findsOneWidget);
    await tester.tap(tuesday);
    await tester.pumpAndSettle();

    expect(find.text('Tuesday all-day'), findsOneWidget);
    expect(find.text('Thursday all-day'), findsNothing);
    expect(
      find.byKey(const ValueKey('general-more-occurrences-sheet')),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('general-more-occurrences-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('all-day overflow chip matches its Wednesday-to-Saturday range', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        for (var index = 1; index <= 3; index++)
          GeneralEvent(
            id: 'week-lane-$index',
            calendarId: 'cal1',
            title: 'Week lane $index',
            startDateTimeIso: '2026-06-15T00:00:00.000',
            endDateTimeIso: '2026-06-22T00:00:00.000',
            isAllDay: true,
          ),
        GeneralEvent(
          id: 'hidden-wed-sat',
          calendarId: 'cal1',
          title: 'Hidden Wednesday to Saturday',
          startDateTimeIso: '2026-06-17T00:00:00.000',
          endDateTimeIso: '2026-06-21T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      _buildGeneralDataWithCalendars([calendar], activeId: 'cal1'),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final more = find.byKey(const ValueKey('general-all-day-more-occurrences'));
    final wednesday = find.byKey(
      const ValueKey('general-week-day-header-2026-06-17T00:00:00.000'),
    );
    final saturday = find.byKey(
      const ValueKey('general-week-day-header-2026-06-20T00:00:00.000'),
    );
    final tuesday = find.byKey(
      const ValueKey('general-week-day-header-2026-06-16T00:00:00.000'),
    );
    final sunday = find.byKey(
      const ValueKey('general-week-day-header-2026-06-21T00:00:00.000'),
    );

    expect(more, findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    final moreRect = tester.getRect(more);
    final wednesdayRect = tester.getRect(wednesday);
    final saturdayRect = tester.getRect(saturday);
    expect(moreRect.left, closeTo(wednesdayRect.left + 3, 1));
    expect(moreRect.right, closeTo(saturdayRect.right - 3, 1));
    expect(moreRect.left, greaterThan(tester.getRect(tuesday).right));
    expect(moreRect.right, lessThan(tester.getRect(sunday).left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-contiguous all-day overflow ranges stay separate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        for (var index = 1; index <= 3; index++)
          GeneralEvent(
            id: 'full-week-$index',
            calendarId: 'cal1',
            title: 'Full week $index',
            startDateTimeIso: '2026-06-15T00:00:00.000',
            endDateTimeIso: '2026-06-22T00:00:00.000',
            isAllDay: true,
          ),
        GeneralEvent(
          id: 'hidden-monday',
          calendarId: 'cal1',
          title: 'Hidden Monday',
          startDateTimeIso: '2026-06-15T00:00:00.000',
          endDateTimeIso: '2026-06-16T00:00:00.000',
          isAllDay: true,
        ),
        GeneralEvent(
          id: 'hidden-wednesday',
          calendarId: 'cal1',
          title: 'Hidden Wednesday',
          startDateTimeIso: '2026-06-17T00:00:00.000',
          endDateTimeIso: '2026-06-18T00:00:00.000',
          isAllDay: true,
        ),
      ],
    );
    final provider = await _createGeneralProvider(
      _buildGeneralDataWithCalendars([calendar], activeId: 'cal1'),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(
      find.byKey(const ValueKey('general-all-day-more-occurrences-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('general-all-day-more-occurrences-2-2')),
      findsOneWidget,
    );
    expect(find.text('+1'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('general-all-day-more-occurrences')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('crowded all-day lanes expose hidden events through more', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = GeneralSchedule(
      id: 'cal1',
      name: 'Calendar',
      events: [
        for (var index = 1; index <= 4; index++)
          GeneralEvent(
            id: 'all-day-$index',
            calendarId: 'cal1',
            title: 'All-day $index',
            startDateTimeIso: '2026-06-16T00:00:00.000',
            endDateTimeIso: index == 1
                ? '2026-06-18T00:00:00.000'
                : '2026-06-17T00:00:00.000',
            isAllDay: true,
          ),
      ],
    );
    final provider = await _createGeneralProvider(
      _buildGeneralDataWithCalendars([calendar], activeId: 'cal1'),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final more = find.byKey(const ValueKey('general-all-day-more-occurrences'));
    expect(more, findsOneWidget);
    expect(find.text('All-day 4'), findsNothing);

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('All-day 4'), findsOneWidget);
    await tester.tap(find.text('All-day 4'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(GeneralEventDetailsSheet))).pop();
    await tester.pumpAndSettle();
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
    expect(
      find.byKey(const ValueKey('general-event-edit-action')),
      findsOneWidget,
    );
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

  testWidgets(
    'long-press add setting removes day and week grid recognizers immediately',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final view in const [generalViewWeek, generalViewDay]) {
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
              defaultView: view,
              enableLongPressAddEvent: false,
            ),
          ),
        );
        await _pumpGeneralScheduleHomeScreen(tester, provider);

        final slot = find.byKey(
          const ValueKey('general-timeline-empty-slot-2026-06-17T00:00:00.000'),
        );
        expect(slot, findsOneWidget);
        expect(tester.widget<GestureDetector>(slot).onLongPressStart, isNull);

        final slotRect = tester.getRect(slot);
        await tester.longPressAt(
          Offset(slotRect.center.dx, slotRect.top + 160),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GeneralEventEditorSheet), findsNothing);

        await provider.updateGeneralDisplaySettings(
          enableLongPressAddEvent: true,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<GestureDetector>(slot).onLongPressStart,
          isNotNull,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

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
          title: 'Planning session with a very long event title that should wrap safely',
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

    expect(find.text('Today'), findsNothing);
    expect(find.text('Pick date'), findsNothing);
    expect(
      find.byKey(const ValueKey('general-date-title-button')),
      findsOneWidget,
    );
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

  testWidgets('day pager keeps Provider date stable during a partial drag', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const calendar = GeneralSchedule(id: 'cal1', name: 'Calendar', events: []);
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: const GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-16',
          defaultView: generalViewDay,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final initialDate = provider.selectedGeneralDate;
    final pageController = tester
        .widget<PageView>(find.byKey(_generalDayPagerKey))
        .controller!;
    final initialPage = pageController.page!;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_generalDayPagerKey)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 16));

    final draggingPage = pageController.page!;
    expect(draggingPage, greaterThan(initialPage + 0.5));
    expect(draggingPage, lessThan(initialPage + 1));
    expect(provider.selectedGeneralDate, initialDate);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate, DateTime(2026, 6, 17));
    expect(tester.takeException(), isNull);
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

  testWidgets('month navigation moves backward to the prior visible weekday', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const calendar = GeneralSchedule(id: 'cal1', name: 'Calendar', events: []);
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-30',
          defaultView: generalViewMonth,
          showWeekends: false,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.fling(
      find.byKey(const ValueKey('general-month-calendar-panel')),
      const Offset(480, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate, DateTime(2026, 5, 29));
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

  testWidgets('month view empty agenda keeps only header and FAB add actions', (
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
    expect(addButtons, findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Add event'), findsNothing);
    expect(find.byType(SkedPrimaryFab), findsOneWidget);
    final headerAdd = find.widgetWithIcon(IconButton, Icons.add);
    expect(headerAdd, findsOneWidget);

    await tester.tap(headerAdd);
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
    expect(find.text('2026/6'), findsWidgets);
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
          title: 'Recurring project review with a very long event title for agenda',
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
    expect(find.text('26/6'), findsWidgets);
    expect(find.textContaining('Recurring project review'), findsWidgets);
  });

  testWidgets('compact month selection brings the agenda back into view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const calendar = GeneralSchedule(id: 'cal1', name: 'Calendar', events: []);
    final provider = await _createGeneralProvider(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(
        activeMode: AppMode.general,
        generalMode: GeneralScheduleData(
          activeScheduleId: 'cal1',
          schedules: [calendar],
          selectedDateIso: '2026-06-01',
          defaultView: generalViewMonth,
        ),
      ),
    );

    await _pumpGeneralScheduleHomeScreen(tester, provider);
    final monthScroll = find.byWidgetPredicate(
      (widget) =>
          widget is ListView &&
          widget.padding == const EdgeInsets.fromLTRB(12, 6, 12, 88),
    );
    expect(monthScroll, findsOneWidget);
    final day = find.text('29').first;
    await tester.drag(monthScroll, const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();

    expect(provider.selectedGeneralDate, DateTime(2026, 6, 29));
    expect(
      find.byKey(const ValueKey('general-month-compact-agenda')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
    expect(find.text('2026/7'), findsWidgets);
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
      colorScheme: ColorScheme.fromSeed(seedColor: festivalColor)
          .copyWith(primary: festivalColor, tertiary: solarTermColor),
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

  testWidgets(
    'general toolbar follows custom order and keeps settings reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final base = _buildGeneralDataWithCalendars(const [
        GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
      ], activeId: 'cal1');
      final provider = await _createGeneralProvider(
        base.copyWith(
          generalMode: base.generalMode.copyWith(
            toolbarNavigationOrder: const [
              'view',
              'settings',
              'date',
              'category',
            ],
          ),
        ),
      );
      await _pumpGeneralScheduleHomeScreen(tester, provider);

      final view = tester.getRect(
        find.byKey(const ValueKey('general-view-switcher')),
      );
      final settings = tester.getRect(
        find.byKey(const ValueKey('general-settings-button')),
      );
      final date = tester.getRect(
        find.byKey(const ValueKey('general-date-title-button')),
      );
      final category = tester.getRect(
        find.byKey(const ValueKey('general-calendar-selector')),
      );
      expect(view.left, lessThan(settings.left));
      expect(settings.left, lessThan(date.left));
      expect(date.left, lessThan(category.left));
      expect(
        find.byKey(const ValueKey('general-toolbar-more-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('general category selector stays leading on wide screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars(const [
      GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(base);
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    final category = tester.getRect(
      find.byKey(const ValueKey('general-calendar-selector')),
    );
    final date = tester.getRect(
      find.byKey(const ValueKey('general-date-title-button')),
    );
    final view = tester.getRect(
      find.byKey(const ValueKey('general-view-switcher')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('general-settings-button')),
    );

    expect(category.left, lessThan(date.left));
    expect(category.right, lessThan(date.left));
    expect(date.left, lessThan(view.left));
    expect(view.left, lessThan(settings.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('general toolbar removes hidden items or exposes them in More', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars(const [
      GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          hiddenToolbarNavigationIds: const ['category', 'date', 'view'],
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    expect(
      find.byKey(const ValueKey('general-calendar-selector')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('general-toolbar-more-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('general-settings-button')),
      findsOneWidget,
    );

    await provider.updateGeneralToolbarHiddenItemsBehavior(
      toolbarHiddenItemsBehaviorMore,
    );
    await tester.pumpAndSettle();
    final more = find.byKey(const ValueKey('general-toolbar-more-button'));
    expect(more, findsOneWidget);
    expect(
      find.byKey(const ValueKey('general-calendar-selector')),
      findsNothing,
    );

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Categories').last, findsOneWidget);
    expect(find.text('Pick date').last, findsOneWidget);
    expect(find.text('View switcher').last, findsOneWidget);

    await tester.tap(find.text('View switcher').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('general-day-pager')), findsOneWidget);

    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick date').last);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    expect(find.text('Categories').last, findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);

    await provider.updateGeneralToolbarNavigationVisibility('more', false);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('general-toolbar-more-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('general-calendar-selector')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('general-settings-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden view in More opens the configured view menu behavior', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final base = _buildGeneralDataWithCalendars(const [
      GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
    ], activeId: 'cal1');
    final provider = await _createGeneralProvider(
      base.copyWith(
        generalMode: base.generalMode.copyWith(
          viewSwitchBehavior: generalViewSwitchBehaviorMenu,
          hiddenToolbarNavigationIds: const ['view'],
          toolbarHiddenItemsBehavior: toolbarHiddenItemsBehaviorMore,
        ),
      ),
    );
    await _pumpGeneralScheduleHomeScreen(tester, provider);

    await tester.tap(find.byKey(const ValueKey('general-toolbar-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View switcher').last);
    await tester.pumpAndSettle();

    expect(find.text('Day').last, findsOneWidget);
    expect(find.text('Month').last, findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Week').last, findsOneWidget);
  });

  testWidgets(
    'general toolbar scrolls horizontally when all actions cannot fit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(100, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final base = _buildGeneralDataWithCalendars(const [
        GeneralSchedule(id: 'cal1', name: 'Calendar', events: []),
      ], activeId: 'cal1');
      final provider = await _createGeneralProvider(base);
      await _pumpGeneralScheduleHomeScreen(tester, provider);

      final toolbar = find.byKey(const ValueKey('general-workspace-toolbar'));
      expect(toolbar, findsOneWidget);
      expect(
        find.descendant(
          of: toolbar,
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
