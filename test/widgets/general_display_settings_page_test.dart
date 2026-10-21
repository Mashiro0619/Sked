import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';

import '../support/workspace_harness.dart';

import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/data_transfer_codec.dart';

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

Future<AppRuntime> _createProvider({
  String localeCode = defaultLocaleCode,
}) async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: WorkspaceMemoryStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: localeCode,
      ).copyWith(activeMode: AppMode.general),
      path: 'memory://general-display-settings-test',
    ),
    systemLocaleCodeResolver: () => localeCode,
  );
  await provider.lifecycle.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  AppRuntime provider, {
  Locale locale = const Locale('en'),
  EdgeInsets viewPadding = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    AppScope(
      app: provider,
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
  final verticalScrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(
    titleFinder,
    120,
    scrollable: verticalScrollable,
  );
  await tester.pumpAndSettle();
  final tile = find.ancestor(
    of: titleFinder,
    matching: find.byType(SettingsSwitchTile),
  );
  await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'general fit toggle defaults on, persists independently and reports failure',
    (tester) async {
      final storage = WorkspaceMemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes())
            .copyWith(activeMode: AppMode.general),
      );
      final provider = await workspaceProvider(storage: storage);
      addTearDown(provider.dispose);
      await _pumpPage(tester, provider);
      expect(provider.generalView.data.fitWeekColumnsToWidth, isTrue);
      final studentFit =
          provider.workspaceView.data.studentMode.fitWeekColumnsToWidth;
      await _toggleSwitch(tester, 'Fit week view to screen');
      expect(provider.generalView.data.fitWeekColumnsToWidth, isFalse);
      expect(storage.data.generalMode.fitWeekColumnsToWidth, isFalse);
      expect(
        provider.workspaceView.data.studentMode.fitWeekColumnsToWidth,
        studentFit,
      );
      storage.saveError = StateError('phone setting save failed');
      await _toggleSwitch(tester, 'Fit week view to screen');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        storage.data.generalMode.fitWeekColumnsToWidth,
        isFalse,
        reason: 'Failed writes must not appear in persisted data',
      );
      expect(tester.takeException(), isNull);
    },
  );

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

    final list = find.byKey(const ValueKey('general-display-settings-list'));
    expect(tester.getSize(list).width, 1024);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('responsive-settings-content')))
          .width,
      lessThanOrEqualTo(1120),
    );
    expect(tester.getRect(list).bottom, closeTo(720, 0.01));
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final content = find.byKey(const ValueKey('responsive-settings-content'));
    expect(
      tester.getRect(list).bottom - tester.getRect(content).bottom,
      closeTo(24, 0.01),
    );
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
    expect(
      find.byKey(const ValueKey('general-toolbar-hidden-behavior')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('general-default-view')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month').last);
    await tester.pumpAndSettle();

    expect(provider.generalView.data.defaultView, generalViewMonth);

    await tester.scrollUntilVisible(
      find.text('Popup behavior'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
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
    await tester.scrollUntilVisible(
      title,
      160,
      scrollable: find.byType(Scrollable).first,
    );
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
    await tester.scrollUntilVisible(
      tile,
      160,
      scrollable: find.byType(Scrollable).first,
    );
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
    expect(provider.generalView.data.timeGridHourHeight, 72);
    expect(find.text('76 dp'), findsOneWidget);

    slider = tester.widget<Slider>(sliderFinder);
    slider.onChangeEnd!(75);
    await tester.pumpAndSettle();
    expect(provider.generalView.data.timeGridHourHeight, 76);
    expect(tester.takeException(), isNull);
  });

  testWidgets('persists the view switch behavior setting', (tester) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    final dropdown = find.byKey(const ValueKey('general-view-switch-behavior'));
    expect(
      tester.widget<SettingsChoiceTile<String>>(dropdown).value,
      generalViewSwitchBehaviorMenu,
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cycle through views').last);
    await tester.pumpAndSettle();

    expect(
      provider.generalView.data.viewSwitchBehavior,
      generalViewSwitchBehaviorCycle,
    );
  });

  testWidgets('persists the general toolbar hidden-items behavior', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    final dropdown = find.byKey(
      const ValueKey('general-toolbar-hidden-behavior'),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move into More').last);
    await tester.pumpAndSettle();

    expect(
      provider.generalView.data.toolbarHiddenItemsBehavior,
      toolbarHiddenItemsBehaviorMore,
    );
  });

  testWidgets(
    'pending save keeps switch enabled-looking and blocks duplicate input',
    (tester) async {
      final initialData = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ).copyWith(activeMode: AppMode.general);
      final storage = _PendingTimetableStorage(initialData);
      final provider = AppRuntime(
        dataTransferCodec: inlineDataTransferCodec,
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      await provider.lifecycle.load();
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
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();

      await tester.tap(toggle);
      await tester.pump();

      expect(storage.saveCount, 1);
      expect(provider.generalView.data.showWeekends, isFalse);
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
      expect(provider.generalView.data.showWeekends, isFalse);

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
      provider.generalView.data.toolbarWidthPolicy,
      generalToolbarWidthPolicyContent,
    );

    const options = [
      (generalToolbarWidthPolicyBalanced, 'Balanced'),
      (generalToolbarWidthPolicyCalendarPriority, 'Category priority'),
      (generalToolbarWidthPolicyDatePriority, 'Date priority'),
      (generalToolbarWidthPolicyContent, 'Automatic allocation'),
    ];

    for (final option in options) {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option.$2).last);
      await tester.pumpAndSettle();

      expect(provider.generalView.data.toolbarWidthPolicy, option.$1);
    }
  });

  testWidgets(
    'default view dropdown follows its value control, not the full row',
    (tester) async {
      final provider = await _createProvider();

      await _pumpPage(tester, provider);

      final dropdown = find.byKey(const ValueKey('general-default-view'));
      final dropdownRect = tester.getRect(dropdown);
      final anchorRect = tester.getRect(
        find.descendant(of: dropdown, matching: find.byType(MenuAnchor)),
      );

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final firstMenuItem = find
          .ancestor(
            of: find.text('Week').last,
            matching: find.byType(MenuItemButton),
          )
          .first;
      final menuItemRect = tester.getRect(firstMenuItem);

      expect(menuItemRect.left, closeTo(anchorRect.left + 4, 1));
      expect(menuItemRect.top, greaterThanOrEqualTo(anchorRect.bottom + 4));
      expect(menuItemRect.width, lessThan(dropdownRect.width / 2));
    },
  );

  testWidgets('persists schedule, time-grid, and popup controls', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    await _toggleSwitch(tester, 'Show weekends');
    expect(provider.generalView.data.showWeekends, isFalse);

    final startSlider = tester.widget<Slider>(find.byType(Slider).first);
    startSlider.onChangeEnd!(7);
    await tester.pumpAndSettle();
    expect(provider.generalView.data.dayStartHour, 7);

    final endHourTile = find.ancestor(
      of: find.text('End hour'),
      matching: find.byType(SettingsSliderTile),
    );
    final endSlider = tester.widget<Slider>(
      find.descendant(of: endHourTile, matching: find.byType(Slider)),
    );
    endSlider.onChangeEnd!(22);
    await tester.pumpAndSettle();
    expect(provider.generalView.data.dayEndHour, 22);

    final gridMenu = find.byKey(const ValueKey('general-time-grid'));
    await tester.scrollUntilVisible(
      gridMenu,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(gridMenu), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(gridMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min').last);
    await tester.pumpAndSettle();
    expect(provider.generalView.data.timeGridMinutes, 30);

    await _toggleSwitch(tester, 'Close popup on tap outside');
    expect(provider.generalView.data.closeEventPopupOnOutsideTap, isFalse);

    await _toggleSwitch(tester, 'Show floating add event button');
    expect(provider.generalView.data.showAddEventFab, isFalse);
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
    expect(provider.generalView.data.enableLongPressAddEvent, isFalse);
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

    expect(provider.generalView.data.showLunarCalendar, isFalse);
  });
}
