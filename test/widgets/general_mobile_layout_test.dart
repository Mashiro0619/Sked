import 'dart:async';

import 'package:flutter/gestures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/workspace_navigation.dart';
import 'package:sked/screens/general_display_settings_page.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _header(int day) => _key(
  'general-week-day-header-2026-09-$day'
  'T00:00:00.000',
);

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
}

Future<void> _home(
  WidgetTester t,
  TimetableProvider p, {
  double scale = 1,
  Brightness brightness = Brightness.light,
  Widget? wrapper,
}) async {
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('zh'),
      textScale: scale,
      brightness: brightness,
      home: wrapper ?? const GeneralScheduleHomeScreen(),
    ),
  );
  await t.pumpAndSettle();
}

ScrollPosition _horizontal(WidgetTester t) => t
    .widget<SingleChildScrollView>(
      _key('general-timeline-horizontal-scroll').hitTestable().first,
    )
    .controller!
    .position;

ScrollPosition _vertical(WidgetTester t) => t
    .widget<SingleChildScrollView>(
      _key('general-timeline-scroll-view').hitTestable().first,
    )
    .controller!
    .position;

Future<void> _more(WidgetTester t) async {
  await t.tap(_key('general-toolbar-more-button'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'home custom range accepts direct touch drag and previews with zero writes',
    (t) async {
      _size(t, const Size(393, 852));
      final storage = _Storage(mobileLayoutData());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      final original = GeneralDateRange(
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 27),
      );
      await p.setGeneralDateRange(original);
      await _home(t, p);
      await t.tap(_key('general-date-title-button'));
      await t.pumpAndSettle();
      final before = storage.writes;
      final gesture = await t.startGesture(
        t.getCenter(_key('sked-date-2026-09-22')),
        kind: PointerDeviceKind.touch,
      );
      await gesture.moveBy(const Offset(25, 0));
      await gesture.moveTo(t.getCenter(_key('sked-date-2026-09-26')));
      await t.pump();
      expect(p.customGeneralDateRange, original);
      expect(storage.writes, before);
      await gesture.up();
      await t.pumpAndSettle();
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
      );
      expect(storage.writes, before + 1);
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'phone $width scale $scale $brightness fits a whole week in two rows',
          (t) async {
            _size(t, Size(width, 850));
            final storage = _Storage(mobileLayoutData());
            final p = await workspaceProvider(storage: storage, locale: 'zh');
            addTearDown(p.dispose);
            final before = storage.writes;
            await _home(t, p, scale: scale, brightness: brightness);
            expect(p.generalFitWeekColumnsToWidth, isTrue);
            final viewport = t.getRect(_key('general-week-pager'));
            for (var day = 21; day <= 27; day++) {
              expect(_header(day).hitTestable(), findsOneWidget);
              final rect = t.getRect(_header(day));
              expect(rect.left, greaterThanOrEqualTo(viewport.left));
              expect(rect.right, lessThanOrEqualTo(viewport.right + .01));
            }
            expect(_horizontal(t).maxScrollExtent, 0);
            expect(
              t.widget<PageView>(_key('general-week-pager')).physics,
              isA<PageScrollPhysics>(),
            );
            final toolbar = _key('general-workspace-toolbar');
            final rows = t.widget<Column>(_key('general-compact-toolbar-rows'));
            expect(
              rows.children.length,
              3,
              reason: 'Exactly two rows plus their gap',
            );
            final first = t.getRect(
              _key('general-compact-toolbar-management-row'),
            );
            final second = t.getRect(
              _key('general-compact-toolbar-navigation-row'),
            );
            expect(first.bottom, lessThanOrEqualTo(second.top));
            if (scale == 1) {
              expect(t.getSize(toolbar).height, lessThanOrEqualTo(112));
            }
            expect(_key('general-previous-period'), findsNothing);
            expect(_key('general-next-period'), findsNothing);
            expect(_key('general-reminders-action'), findsNothing);
            expect(_key('general-day-agenda-toggle'), findsNothing);
            expect(
              storage.writes,
              before,
              reason: 'Layout must not rewrite preferences',
            );
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }

  testWidgets(
    'fit setting preserves date and vertical position, clamps horizontal offset',
    (t) async {
      _size(t, const Size(360, 800));
      final p = await workspaceProvider(
        storage: _Storage(mobileLayoutData()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await _home(t, p);
      await t.drag(_key('general-timeline-scroll-view'), const Offset(0, -210));
      await t.pumpAndSettle();
      final top = _vertical(t).pixels;
      final date = p.selectedGeneralDate;
      expect(top, greaterThan(0));
      await p.updateGeneralDisplaySettings(fitWeekColumnsToWidth: false);
      await t.pumpAndSettle();
      expect(_horizontal(t).maxScrollExtent, greaterThan(300));
      expect(
        t.widget<PageView>(_key('general-week-pager')).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await t.drag(
        _key('general-timeline-horizontal-scroll').hitTestable(),
        const Offset(-240, 0),
      );
      await t.pumpAndSettle();
      expect(_horizontal(t).pixels, greaterThan(0));
      expect(
        p.selectedGeneralDate,
        date,
        reason: 'Browsing columns cannot also turn the week',
      );
      expect(_vertical(t).pixels, closeTo(top, .1));
      await p.updateGeneralDisplaySettings(fitWeekColumnsToWidth: true);
      await t.pumpAndSettle();
      expect(_horizontal(t).pixels, 0);
      expect(_horizontal(t).maxScrollExtent, 0);
      expect(_vertical(t).pixels, closeTo(top, .1));
      expect(p.selectedGeneralDate, date);
      await t.drag(
        _key('general-timeline-horizontal-scroll').hitTestable(),
        const Offset(-260, 0),
      );
      await t.pumpAndSettle();
      expect(p.selectedGeneralDate, addCalendarDays(date, 7));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'five-day week fits and custom ranges over seven days still browse',
    (t) async {
      _size(t, const Size(320, 800));
      final p = await workspaceProvider(
        storage: _Storage(mobileLayoutData()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await p.updateGeneralDisplaySettings(showWeekends: false);
      await _home(t, p);
      expect(_header(25).hitTestable(), findsOneWidget);
      expect(_header(26), findsNothing);
      expect(_horizontal(t).maxScrollExtent, 0);
      await p.setGeneralDateRange(
        GeneralDateRange(DateTime(2026, 9, 23), DateTime(2026, 9, 29)),
      );
      await t.pumpAndSettle();
      expect(_header(29).hitTestable(), findsOneWidget);
      expect(
        _header(21),
        findsNothing,
        reason: 'A custom seven days is not a natural week',
      );
      expect(_horizontal(t).maxScrollExtent, 0);
      await p.setGeneralDateRange(
        GeneralDateRange(DateTime(2026, 9, 23), DateTime(2026, 10, 6)),
      );
      await t.pumpAndSettle();
      expect(_horizontal(t).maxScrollExtent, greaterThan(800));
      expect(
        t.widget<PageView>(_key('general-week-pager')).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'landscape phone remains fit while desktop sizing is unaffected',
    (t) async {
      _size(t, const Size(800, 360));
      final p = await workspaceProvider(
        storage: _Storage(mobileLayoutData()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await _home(t, p);
      expect(_horizontal(t).maxScrollExtent, 0);
      expect(_key('general-compact-toolbar-single-row'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'full mobile workbench at 2x text survives short landscape and all-day rows',
    (t) async {
      _size(t, const Size(740, 320));
      final p = await workspaceProvider(
        storage: _Storage(mobileLayoutData(locale: 'en')),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p, textScale: 2));
      await t.pumpAndSettle();
      expect(
        t.getSize(_key('general-timeline-scroll-view')).height,
        greaterThanOrEqualTo(95.99),
      );
      expect(_key('general-all-day-timeline').hitTestable(), findsOneWidget);
      for (var day = 21; day <= 27; day++) {
        expect(_header(day).hitTestable(), findsOneWidget);
      }
      expect(_horizontal(t).maxScrollExtent, 0);
      expect(t.takeException(), isNull);
      for (final days in [1, 7, 14]) {
        await p.setGeneralDateRange(
          GeneralDateRange(
            DateTime(2026, 9, 23),
            addCalendarDays(DateTime(2026, 9, 23), days - 1),
          ),
        );
        await t.pumpAndSettle();
        final chrome = _key('general-timeline-height-scroll');
        final chromePosition = t
            .state<ScrollableState>(
              find
                  .descendant(of: chrome, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        chromePosition.jumpTo(0);
        await t.pumpAndSettle();
        final chromeRect = t.getRect(chrome);
        // Start on the pinned month gutter, not behind it in a scrolled day.
        await t.dragFrom(
          Offset(chromeRect.left + 16, chromeRect.top + 40),
          const Offset(0, -180),
        );
        await t.pumpAndSettle();
        expect(chromePosition.pixels, greaterThan(0));
        final visibleTime = t
            .getRect(_key('general-timeline-scroll-view'))
            .intersect(t.getRect(_key('general-week-pager')));
        expect(visibleTime.height, greaterThanOrEqualTo(95.99));
        expect(visibleTime.width, greaterThan(0));
        final timePosition = t
            .widget<SingleChildScrollView>(_key('general-timeline-scroll-view'))
            .controller!
            .position;
        final before = timePosition.pixels;
        await t.dragFrom(visibleTime.center, const Offset(0, -40));
        await t.pumpAndSettle();
        expect(timePosition.pixels, greaterThan(before));
        expect(p.customGeneralDateRange!.dayCount, days);
        expect(t.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('desktop fit preference does not change its width strategy', (
    t,
  ) async {
    _size(t, const Size(560, 850));
    final p = await workspaceProvider(
      storage: _Storage(mobileLayoutData()),
      locale: 'zh',
    );
    addTearDown(p.dispose);
    await _home(t, p);
    final extent = _horizontal(t).maxScrollExtent;
    expect(extent, greaterThan(0));
    expect(_key('general-compact-toolbar-rows'), findsNothing);
    await p.updateGeneralDisplaySettings(fitWeekColumnsToWidth: false);
    await t.pumpAndSettle();
    expect(_horizontal(t).maxScrollExtent, extent);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'narrow titles are bounded, true event height and overlap details remain',
    (t) async {
      _size(t, const Size(393, 850));
      final p = await workspaceProvider(
        storage: _Storage(mobileLayoutData()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await _home(t, p);
      final card = _key(
        'general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000',
      );
      final title = t.widget<Text>(
        find.descendant(of: card, matching: find.byType(Text)).first,
      );
      expect(title.maxLines, lessThanOrEqualTo(3));
      expect(
        t.getSize(card).height,
        closeTo(70 * p.generalTimeGridHourHeight / 60 - 3, .01),
      );
      await t.tap(card);
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      expect(find.text('图书馆东区三层综合研讨室 A-301（靠近电梯）'), findsWidgets);
      final context = t.element(find.byType(GeneralEventDetailsSheet));
      Navigator.of(context).pop();
      await t.pumpAndSettle();
      final more = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'general-timed-more-occurrences-',
            ),
      );
      await t.ensureVisible(more.first);
      await t.tap(more.first);
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        expect(find.text('产品设计评审与研发同步会议 $i'), findsWidgets);
      }
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'More retains reminders, agenda, management and guarded workspace navigation',
    (t) async {
      _size(t, const Size(360, 800));
      final storage = _Storage(mobileLayoutData());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      final selected = <AppMode>[];
      await _home(
        t,
        p,
        wrapper: WorkspaceNavigationScope(
          enabled: true,
          integrated: true,
          onSelect: selected.add,
          onToggleResources: () {},
          child: const GeneralScheduleHomeScreen(),
        ),
      );
      final before = storage.writes;
      await _more(t);
      expect(_key('general-reminders-action').hitTestable(), findsOneWidget);
      expect(_key('general-day-agenda-toggle'), findsOneWidget);
      expect(_key('general-calendar-manager-action'), findsOneWidget);
      expect(_key('workspace-actions-general'), findsOneWidget);
      await t.tap(_key('general-reminders-action'));
      await t.pumpAndSettle();
      expect(_key('general-reminders-list'), findsOneWidget);
      Navigator.of(t.element(_key('general-reminders-list'))).pop();
      await t.pumpAndSettle();
      await _more(t);
      await t.tap(_key('general-day-agenda-toggle'));
      await t.pumpAndSettle();
      expect(_key('general-selected-day-agenda'), findsOneWidget);
      Navigator.of(t.element(_key('general-selected-day-agenda'))).pop();
      await t.pumpAndSettle();
      await _more(t);
      await t.tap(_key('general-more-workspace-student'));
      await t.pumpAndSettle();
      expect(selected, [AppMode.student]);
      expect(storage.writes, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'More badge refreshes and opens a reminder occurrence without a third row',
    (t) async {
      _size(t, const Size(393, 852));
      final p = await workspaceProvider(
        storage: _Storage(mobileLayoutData()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await p.saveGeneralEvent(
        GeneralEvent(
          id: 'phone-reminder',
          calendarId: p.activeGeneralSchedule.id,
          title: '手机提醒详情',
          startDateTimeIso: '2026-09-23T10:00:00',
          endDateTimeIso: '2026-09-23T11:00:00',
          reminders: const [GeneralEventReminder(minutesBefore: 10)],
        ),
      );
      var now = DateTime(2026, 9, 23, 9, 49, 30);
      await t.pumpWidget(
        GeneralReminderTimeScope(
          now: () => now,
          createTimer: Timer.new,
          child: WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            home: const GeneralScheduleHomeScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final badge = find.descendant(
        of: _key('general-toolbar-more-button'),
        matching: find.byType(Badge),
      );
      expect(t.widget<Badge>(badge).isLabelVisible, isFalse);
      now = DateTime(2026, 9, 23, 9, 50);
      await t.pump(const Duration(seconds: 30));
      expect(t.widget<Badge>(badge).isLabelVisible, isTrue);
      expect((t.widget<Badge>(badge).label! as Text).data, '1');
      expect(
        t.getSize(_key('general-workspace-toolbar')).height,
        lessThanOrEqualTo(112),
      );
      await _more(t);
      await t.tap(_key('general-reminders-action'));
      await t.pumpAndSettle();
      final occurrence = find.descendant(
        of: _key('general-reminders-list'),
        matching: find.text('手机提醒详情'),
      );
      await t.tap(occurrence);
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('More preferences and today remain actionable', (t) async {
    _size(t, const Size(393, 900));
    final p = await workspaceProvider(
      storage: _Storage(mobileLayoutData()),
      locale: 'zh',
    );
    addTearDown(p.dispose);
    await _home(t, p);
    await _more(t);
    await t.tap(_key('workspace-actions-general'));
    await t.pumpAndSettle();
    expect(find.byType(GeneralDisplaySettingsPage), findsOneWidget);
    Navigator.of(t.element(find.byType(GeneralDisplaySettingsPage))).pop();
    await t.pumpAndSettle();
    await _more(t);
    final today = find.byWidgetPredicate(
      (w) => w is SkedPopupMenuItem<String> && w.value == 'today',
    );
    await t.tap(today);
    await t.pumpAndSettle();
    expect(p.selectedGeneralDate, DateUtils.dateOnly(DateTime.now()));
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final hiddenBehavior in [
    toolbarHiddenItemsBehaviorMore,
    toolbarHiddenItemsBehaviorRemove,
  ]) {
    testWidgets(
      'custom order stays in two semantic rows; hidden shortcut behavior $hiddenBehavior',
      (t) async {
        _size(t, const Size(320, 850));
        final storage = _Storage(mobileLayoutData());
        final p = await workspaceProvider(storage: storage, locale: 'zh');
        addTearDown(p.dispose);
        await p.updateGeneralDisplaySettings(
          toolbarNavigationOrder: [
            'view',
            'settings',
            'date',
            'category',
            'more',
          ],
          hiddenToolbarNavigationIds: ['date', 'view'],
          toolbarHiddenItemsBehavior: hiddenBehavior,
        );
        final order = p.generalToolbarNavigationOrder;
        final before = storage.writes;
        await _home(t, p, scale: 2);
        expect(_key('general-date-title-button'), findsNothing);
        expect(_key('general-view-switcher'), findsNothing);
        expect(
          t.getRect(_key('general-settings-button')).left,
          lessThan(t.getRect(_key('general-calendar-selector')).left),
        );
        await _more(t);
        final items = t.widgetList<SkedPopupMenuItem<String>>(
          find.byType(SkedPopupMenuItem<String>),
        );
        expect(
          items.any((i) => i.value == 'date'),
          hiddenBehavior == toolbarHiddenItemsBehaviorMore,
        );
        expect(
          items.any((i) => i.value == 'view'),
          hiddenBehavior == toolbarHiddenItemsBehaviorMore,
        );
        expect(p.generalToolbarNavigationOrder, order);
        expect(storage.writes, before);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('hidden date shortcut opens picker from a live More anchor', (
    t,
  ) async {
    _size(t, const Size(360, 850));
    final p = await workspaceProvider(
      storage: _Storage(mobileLayoutData()),
      locale: 'zh',
    );
    addTearDown(p.dispose);
    await p.updateGeneralDisplaySettings(
      hiddenToolbarNavigationIds: ['date'],
      toolbarHiddenItemsBehavior: toolbarHiddenItemsBehaviorMore,
    );
    await _home(t, p);
    await _more(t);
    final item = find.byWidgetPredicate(
      (w) => w is SkedPopupMenuItem<String> && w.value == 'date',
    );
    await t.tap(item);
    await t.pumpAndSettle();
    expect(find.byType(SkedDatePicker), findsOneWidget);
    await t.tap(_key('sked-date-picker-close'));
    await t.pumpAndSettle();
    expect(find.byType(SkedDatePicker), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
