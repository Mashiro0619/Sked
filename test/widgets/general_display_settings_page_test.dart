import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
    expect(tester.getSize(list).width, lessThanOrEqualTo(720));
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

    final endSlider = tester.widget<Slider>(find.byType(Slider).last);
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
  });

  testWidgets('Chinese locale exposes and persists the lunar toggle', (
    tester,
  ) async {
    final provider = await _createProvider(localeCode: 'zh');
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider, locale: const Locale('zh'));

    await _toggleSwitch(tester, '显示农历');

    expect(provider.generalShowLunarCalendar, isFalse);
  });
}
