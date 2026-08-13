import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/timetable_display_settings_page.dart';
import 'package:sked/widgets/settings_list.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData data;

  @override
  Future<String?> filePath() async =>
      'memory://timetable-display-settings-test';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }
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
  );
  await provider.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  TimetableProvider provider, {
  EdgeInsets viewPadding = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
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
        home: const TimetableDisplaySettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _toggleSetting(WidgetTester tester, String title) async {
  final titleFinder = find.text(title);
  final verticalScrollable = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  await tester.scrollUntilVisible(
    titleFinder,
    120,
    scrollable: verticalScrollable,
  );
  final tile = find.ancestor(
    of: titleFinder,
    matching: find.byType(SettingsSwitchTile),
  );
  await tester.ensureVisible(tile);
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

    final title = find.text('Timetable display and interaction');
    final titleScroll = find.byKey(
      const ValueKey('timetable-display-settings-title-scroll'),
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

    expect(find.text('Timetable display and interaction'), findsOneWidget);

    await _toggleSetting(tester, 'Allow outside tap to close course popup');
    expect(provider.closeCoursePopupOnOutsideTap, isFalse);

    await _toggleSetting(tester, 'Preserve timetable gaps');
    expect(provider.preserveTimetableGaps, isTrue);

    await _toggleSetting(tester, 'Show past-ended courses');
    expect(provider.showPastEndedCourses, isTrue);

    await _toggleSetting(tester, 'Show future courses');
    expect(provider.showFutureCourses, isFalse);

    await _toggleSetting(tester, 'Fit day selector to screen');
    expect(provider.fitDaySelectorToWidth, isFalse);

    await _toggleSetting(tester, 'Fit week columns to screen');
    expect(provider.fitWeekColumnsToWidth, isFalse);

    await _toggleSetting(tester, 'Swipe to change weeks');
    expect(provider.enableWeekSwipeNavigation, isFalse);

    await _toggleSetting(tester, 'Show timetable grid lines');
    expect(provider.showTimetableGridLines, isFalse);

    await _toggleSetting(tester, 'Show floating add course button');
    expect(provider.showAddCourseFab, isFalse);
    expect(find.text('Quick actions'), findsOneWidget);
  });
}
