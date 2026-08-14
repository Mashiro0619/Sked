import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/settings_list.dart';

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
  Future<String?> filePath() async => 'memory://general-display-settings-test';
}

class _PendingTimetableStorage implements TimetableStorage {
  _PendingTimetableStorage(this.data);

  AppData data;
  Completer<void>? pendingSave;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData next) async {
    saveCount += 1;
    final pending = Completer<void>();
    pendingSave = pending;
    await pending.future;
    data = next;
  }

  @override
  Future<String?> filePath() async =>
      'memory://pending-general-display-settings-test';

  void completePendingSave() {
    final pending = pendingSave;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}

Future<TimetableProvider> _createProvider({
  String localeCode = defaultLocaleCode,
}) async {
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: localeCode,
      ).copyWith(activeMode: AppMode.general),
    ),
    systemLocaleCodeResolver: () => localeCode,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  TimetableProvider provider, {
  Locale locale = const Locale('en'),
  EdgeInsets viewPadding = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: viewPadding,
            viewPadding: viewPadding,
            textScaler: textScaler,
          ),
          child: child!,
        ),
        home: const GeneralDisplaySettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggleSwitch(WidgetTester tester, String title) async {
  final titleFinder = find.text(title);
  await tester.scrollUntilVisible(titleFinder, 120);
  final tile = find.ancestor(
    of: titleFinder,
    matching: find.byType(SettingsSwitchTile),
  );
  await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('caps wide content and consumes Android navigation inset once', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();

    await _pumpPage(
      tester,
      provider,
      viewPadding: const EdgeInsets.only(bottom: 48),
    );

    final list = find.byType(ListView);
    expect(tester.getSize(list).width, 1024);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('responsive-settings-content')))
          .width,
      lessThanOrEqualTo(1120),
    );
    expect(tester.getRect(list).bottom, lessThanOrEqualTo(720));
    expect((tester.widget<ListView>(list).padding! as EdgeInsets).bottom, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows default view as a setting instead of page tabs', (
    tester,
  ) async {
    final provider = await _createProvider();

    await _pumpPage(tester, provider);

    expect(find.text('Startup'), findsOneWidget);
    expect(find.text('Default view'), findsOneWidget);
    expect(find.text('Schedule display'), findsOneWidget);
    expect(find.text('Time grid'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.byType(SkedDropdownMenu<String>), findsNWidgets(4));

    await tester.tap(find.byKey(const ValueKey('general-default-view')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();

    expect(provider.generalDefaultView, generalViewMonth);

    await tester.scrollUntilVisible(find.text('Popup behavior'), 160);
    expect(find.text('Popup behavior'), findsOneWidget);
  });

  testWidgets('compact large text keeps the slider value beside its title', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();

    await _pumpPage(tester, provider, textScaler: const TextScaler.linear(2));

    final title = find.text('Start hour');
    await tester.scrollUntilVisible(title, 160);
    final tile = find.ancestor(
      of: title,
      matching: find.byType(SettingsSliderTile),
    );
    final value = find.descendant(of: tile, matching: find.text('06:00'));
    final titleRect = tester.getRect(title);
    final valueRect = tester.getRect(value);

    expect(valueRect.left, greaterThan(titleRect.right));
    expect(valueRect.center.dy, closeTo(titleRect.center.dy, 1));
    expect(tester.widget<Text>(value).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hour height slider steps by four and saves on release', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();
    addTearDown(provider.dispose);

    await _pumpPage(tester, provider, textScaler: const TextScaler.linear(2));

    final tile = find.byKey(const ValueKey('general-time-grid-hour-height'));
    await tester.scrollUntilVisible(tile, 160);
    final sliderFinder = find.descendant(
      of: tile,
      matching: find.byType(Slider),
    );
    var slider = tester.widget<Slider>(sliderFinder);
    expect(slider.divisions, 21);
    expect(
      find.text(
        'Adjusts the vertical scale of day and week views without changing '
        'the 15, 30, or 60 minute grid interval.',
      ),
      findsOneWidget,
    );

    slider.onChanged!(75);
    await tester.pump();
    expect(provider.generalTimeGridHourHeight, 72);
    expect(find.text('76 dp'), findsOneWidget);

    slider = tester.widget<Slider>(sliderFinder);
    slider.onChangeEnd!(75);
    await tester.pumpAndSettle();
    expect(provider.generalTimeGridHourHeight, 76);
    expect(tester.takeException(), isNull);
  });

  testWidgets('persists the view switch behavior setting', (tester) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    final dropdown = find.byKey(const ValueKey('general-view-switch-behavior'));
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open view menu').last);
    await tester.pumpAndSettle();

    expect(provider.generalViewSwitchBehavior, generalViewSwitchBehaviorMenu);
  });

  testWidgets(
    'pending save keeps switch enabled-looking and blocks duplicate input',
    (tester) async {
      final initialData = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(activeMode: AppMode.general);
      final storage = _PendingTimetableStorage(initialData);
      final provider = TimetableProvider(
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      await provider.load();
      addTearDown(() {
        storage.completePendingSave();
        provider.dispose();
      });
      await _pumpPage(tester, provider);

      final title = find.text('Show weekends');
      final tile = find.ancestor(
        of: title,
        matching: find.byType(SettingsSwitchTile),
      );
      final toggle = find.descendant(of: tile, matching: find.byType(Switch));
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);

      await tester.tap(toggle);
      await tester.pump();

      expect(storage.saveCount, 1);
      expect(provider.generalShowWeekends, isFalse);
      expect(
        tester
            .widget<SettingsInteractionBlocker>(
              find.byType(SettingsInteractionBlocker),
            )
            .blocked,
        isTrue,
      );
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);

      await tester.tap(toggle, warnIfMissed: false);
      await tester.pump();
      expect(storage.saveCount, 1);
      expect(provider.generalShowWeekends, isFalse);

      storage.completePendingSave();
      await tester.pumpAndSettle();

      expect(storage.saveCount, 1);
      expect(
        tester
            .widget<SettingsInteractionBlocker>(
              find.byType(SettingsInteractionBlocker),
            )
            .blocked,
        isFalse,
      );
      expect(tester.widget<Switch>(toggle).onChanged, isNotNull);
    },
  );

  testWidgets('persists all toolbar width policy options', (tester) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    final dropdown = find.byKey(const ValueKey('general-toolbar-width-policy'));
    expect(
      provider.generalToolbarWidthPolicy,
      generalToolbarWidthPolicyContent,
    );

    const options = [
      (generalToolbarWidthPolicyBalanced, 'Balanced'),
      (generalToolbarWidthPolicyCalendarPriority, 'Calendar priority'),
      (generalToolbarWidthPolicyDatePriority, 'Date priority'),
      (generalToolbarWidthPolicyContent, 'Automatic allocation'),
    ];

    for (final option in options) {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option.$2).last);
      await tester.pumpAndSettle();

      expect(provider.generalToolbarWidthPolicy, option.$1);
    }
  });

  testWidgets('default view dropdown opens with a full field-width menu', (
    tester,
  ) async {
    final provider = await _createProvider();

    await _pumpPage(tester, provider);

    final dropdown = find.byKey(const ValueKey('general-default-view'));
    final dropdownRect = tester.getRect(dropdown);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final firstMenuItem = find
        .ancestor(
          of: find.text('Week').last,
          matching: find.byType(MenuItemButton),
        )
        .first;
    final menuItemRect = tester.getRect(firstMenuItem);

    expect(menuItemRect.left, closeTo(dropdownRect.left, 1));
    expect(menuItemRect.width, greaterThanOrEqualTo(dropdownRect.width - 16));
  });

  testWidgets('persists schedule, time-grid, and popup controls', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    await _toggleSwitch(tester, 'Show weekends');
    expect(provider.generalShowWeekends, isFalse);

    final startSlider = tester.widget<Slider>(find.byType(Slider).first);
    startSlider.onChangeEnd!(7);
    await tester.pumpAndSettle();
    expect(provider.generalDayStartHour, 7);

    final endHourTile = find.ancestor(
      of: find.text('End hour'),
      matching: find.byType(SettingsSliderTile),
    );
    final endSlider = tester.widget<Slider>(
      find.descendant(of: endHourTile, matching: find.byType(Slider)),
    );
    endSlider.onChangeEnd!(22);
    await tester.pumpAndSettle();
    expect(provider.generalDayEndHour, 22);

    final gridMenu = find.byKey(const ValueKey('general-time-grid'));
    await tester.scrollUntilVisible(gridMenu, 120);
    await tester.tap(gridMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min').last);
    await tester.pumpAndSettle();
    expect(provider.generalTimeGridMinutes, 30);

    await _toggleSwitch(tester, 'Close popup on tap outside');
    expect(provider.closeGeneralEventPopupOnOutsideTap, isFalse);

    await _toggleSwitch(tester, 'Show floating add event button');
    expect(provider.showAddEventFab, isFalse);
    final longPressSetting = find.byKey(
      const ValueKey('enable-long-press-add-event-setting'),
    );
    expect(
      find.descendant(
        of: longPressSetting,
        matching: find.byIcon(Icons.touch_app_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'In day or week view, long-press an empty area of the time grid to add an event.',
      ),
      findsOneWidget,
    );
    await _toggleSwitch(tester, 'Long-press blank grid to add events');
    expect(provider.enableLongPressAddEvent, isFalse);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('Chinese locale exposes and persists the lunar toggle', (
    tester,
  ) async {
    final provider = await _createProvider(localeCode: 'zh');
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider, locale: const Locale('zh'));

    expect(find.text('长按空白网格添加日程'), findsOneWidget);
    expect(find.text('在日视图或周视图中，长按空白时间网格即可添加日程。'), findsOneWidget);
    await _toggleSwitch(tester, '显示农历');

    expect(provider.generalShowLunarCalendar, isFalse);
  });
}
