import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';

import 'package:sked/screens/timetable_display_settings_page.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/settings_page_header.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';

Future<AppRuntime> _createProvider() async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: WorkspaceMemoryStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
      path: 'memory://timetable-display-settings-test',
    ),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.lifecycle.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  AppRuntime provider, {
  EdgeInsets viewPadding = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    AppScope(
      app: provider,
      child: MaterialApp(
        locale: const Locale('en'),
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
        home: const TimetableDisplaySettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggleSetting(WidgetTester tester, String title) async {
  final titleFinder = find.text(title);
  final verticalScrollable = find
      .descendant(
        of: find.byKey(const ValueKey('timetable-display-settings-list')),
        matching: find.byType(Scrollable),
      )
      .first;
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
  await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
  await tester.pumpAndSettle();
  final toggle = find.descendant(of: tile, matching: find.byType(Switch));
  expect(toggle.hitTestable(), findsOneWidget);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows the floating add preference only on touch platforms without saving on resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = MemoryTimetableStorage(
        initialData: initial.copyWith(
          studentMode: initial.studentMode.copyWith(showAddCourseFab: false),
        ),
      );
      final provider = AppRuntime(
        dataTransferCodec: inlineDataTransferCodec,
        storage: storage,
        systemLocaleCodeResolver: () => defaultLocaleCode,
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      final saved = storage.encodedData;
      final saves = storage.saveCount;
      final desktop = switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux => true,
        _ => false,
      };
      for (final width in [320.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        await _pumpPage(tester, provider);
        final addButton = find.byKey(
          const ValueKey('show-add-course-fab-setting'),
        );
        expect(addButton, desktop ? findsNothing : findsOneWidget);
        expect(
          find.byKey(const ValueKey('enable-long-press-add-course-setting')),
          findsOneWidget,
        );
        if (!desktop) {
          expect(tester.widget<SettingsSwitchTile>(addButton).value, isFalse);
        }
        expect(provider.settingsView.showAddCourseFab, isFalse);
        expect(storage.saveCount, saves);
        expect(storage.encodedData, saved);
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
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

    final list = find.byKey(const ValueKey('timetable-display-settings-list'));
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

  testWidgets('keeps the long title reachable on a compact Android viewport', (
    tester,
  ) async {
    // Use physical dimensions equivalent to a 320x568dp phone at 2x density.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(640, 1136);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();

    await _pumpPage(tester, provider);

    final expanded = find.byKey(const ValueKey('settings-expanded-title'));
    expect(
      tester.widget<Text>(expanded).data,
      'Timetable display and interaction',
    );
    expect(tester.getSize(expanded).width, lessThanOrEqualTo(288));
    expect(tester.getSize(expanded).height, greaterThan(40));
    final list = find.byKey(const ValueKey('timetable-display-settings-list'));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    final titleScroll = find.byKey(
      const ValueKey('settings-compact-title-scroll'),
    );
    final title = find.descendant(
      of: titleScroll,
      matching: find.text('Timetable display and interaction'),
    );
    expect(title, findsOneWidget);
    expect(titleScroll, findsOneWidget);
    expect(
      tester.getSize(title).width,
      greaterThan(tester.getSize(titleScroll).width),
    );
    await tester.drag(titleScroll, const Offset(-160, 0));
    await tester.pumpAndSettle();
    final horizontalScrollable = tester.state<ScrollableState>(
      find.descendant(of: titleScroll, matching: find.byType(Scrollable)),
    );
    expect(horizontalScrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact large text keeps the switch beside its text block', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();

    await _pumpPage(tester, provider, textScaler: const TextScaler.linear(2));

    final title = find.text('Allow outside tap to close course popup');
    final subtitle = find.text(
      'Turning this off also disables swipe-down dismissal.',
    );
    final tile = find.ancestor(
      of: title,
      matching: find.byType(SettingsSwitchTile),
    );
    final toggle = find.descendant(of: tile, matching: find.byType(Switch));
    final titleRect = tester.getRect(title);
    final subtitleRect = tester.getRect(subtitle);
    final switchRect = tester.getRect(toggle);

    expect(switchRect.left, greaterThan(titleRect.right));
    expect(switchRect.left, greaterThan(subtitleRect.right));
    expect(
      switchRect.center.dy,
      closeTo((titleRect.top + subtitleRect.bottom) / 2, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('persists every timetable display and interaction toggle', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    final header = find.byType(SettingsPageHeader);
    expect(header, findsOneWidget);
    expect(
      tester.widget<SettingsPageHeader>(header).title,
      'Timetable display and interaction',
    );

    await _toggleSetting(tester, 'Allow outside tap to close course popup');
    expect(provider.settingsView.closeCoursePopupOnOutsideTap, isFalse);

    await _toggleSetting(tester, 'Preserve timetable gaps');
    expect(provider.settingsView.preserveTimetableGaps, isTrue);

    await _toggleSetting(tester, 'Show past-ended courses');
    expect(provider.settingsView.showPastEndedCourses, isTrue);

    await _toggleSetting(tester, 'Show future courses');
    expect(provider.settingsView.showFutureCourses, isFalse);

    await _toggleSetting(tester, 'Fit day selector to screen');
    expect(provider.settingsView.fitDaySelectorToWidth, isFalse);

    await _toggleSetting(tester, 'Fit week columns to screen');
    expect(provider.settingsView.fitWeekColumnsToWidth, isFalse);

    await _toggleSetting(tester, 'Swipe to change weeks');
    expect(provider.settingsView.enableWeekSwipeNavigation, isFalse);

    await _toggleSetting(tester, 'Show timetable grid lines');
    expect(provider.settingsView.showTimetableGridLines, isFalse);

    await _toggleSetting(tester, 'Show floating add course button');
    expect(provider.settingsView.showAddCourseFab, isFalse);
    final longPressSetting = find.byKey(
      const ValueKey('enable-long-press-add-course-setting'),
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
        'Long-press an empty area of the timetable grid to add a course.',
      ),
      findsOneWidget,
    );
    await _toggleSetting(tester, 'Long-press blank grid to add courses');
    expect(provider.settingsView.enableLongPressAddCourse, isFalse);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('persists the timetable toolbar hidden-items behavior', (
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
      const ValueKey('timetable-toolbar-hidden-behavior'),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move into More').last);
    await tester.pumpAndSettle();

    expect(
      provider.settingsView.studentToolbarHiddenItemsBehavior,
      toolbarHiddenItemsBehaviorMore,
    );
  });

  testWidgets('toolbar navigation can be reordered from the settings page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 1800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpPage(tester, provider);

    final editor = find.byKey(
      const ValueKey('timetable-toolbar-navigation-editor'),
    );
    final handles = find.descendant(
      of: editor,
      matching: find.byIcon(Icons.drag_indicator),
    );
    expect(handles, findsNWidgets(6));

    final gesture = await tester.startGesture(
      tester.getCenter(handles.at(0)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    for (var step = 0; step < 5; step++) {
      await gesture.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(provider.settingsView.studentToolbarNavigationOrder.first, 'week');
    expect(tester.takeException(), isNull);
  });
}
