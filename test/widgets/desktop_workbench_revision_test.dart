import 'dart:ui' show CheckedState;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/developer_mode_page.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workbench_resource_widgets.dart';

import '../support/workbench_dense_data.dart';
import '../support/workspace_harness.dart';

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Finder occurrence(String id, String start) =>
    find.byKey(ValueKey('general-timed-occurrence-$id-$start'));
void main() {
  testWidgets(
    'desktop commands are independent of mobile hidden preferences and have one settings entry',
    (tester) async {
      viewport(tester, const Size(1440, 900));
      final p = await denseWorkbenchProvider(mobileToolbarHidden: true);
      addTearDown(p.dispose);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      for (final key in [
        'general-date-picker',
        'general-view-switcher',
        'general-today',
        'general-next-period',
        'general-previous-period',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('general-add-event')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('workspace-resource-settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('general-settings-button')),
        findsNothing,
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(
        p.appData.generalMode.hiddenToolbarNavigationIds,
        containsAll(['date', 'view']),
      );
      expect(
        find.byKey(const ValueKey('workspace-actions-general')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-resource-settings')),
      );
      await tester.pumpAndSettle();
      final display = find.byKey(const ValueKey('settings-general-display'));
      await tester.ensureVisible(display);
      await tester.pumpAndSettle();
      await tester.tap(display);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralDisplaySettingsPage), findsOneWidget);
      expect(find.byType(PopupMenuItem<String>), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(GeneralScheduleHomeScreen), findsOneWidget);
      expect(p.showAddEventFab, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'duplicate category names keep independent IDs, checked semantics and compact rows',
    (tester) async {
      viewport(tester, const Size(1440, 900));
      final semantics = tester.ensureSemantics();
      try {
        final p = await denseWorkbenchProvider();
        addTearDown(p.dispose);
        await tester.pumpWidget(WorkspaceHarness(provider: p));
        await tester.pumpAndSettle();
        final first = find.byKey(
          const ValueKey('resource-calendar-dense-cal-0'),
        );
        final duplicate = find.byKey(
          const ValueKey('resource-calendar-dense-cal-3'),
        );
        expect(
          tester.widget<CalendarResourceRow>(first).name,
          tester.widget<CalendarResourceRow>(duplicate).name,
        );
        expect(tester.getSize(first).height, 36);
        expect(
          tester
              .getSemantics(first)
              .getSemanticsData()
              .flagsCollection
              .isChecked,
          CheckedState.isTrue,
        );
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(p.generalSchedules.first.isVisible, isFalse);
        expect(p.generalSchedules[3].isVisible, isTrue);
        expect(tester.widget<CalendarResourceRow>(first).visible, isFalse);
        expect(
          find.descendant(
            of: first,
            matching: find.byIcon(Icons.visibility_off_outlined),
          ),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'wide week shows three real columns; six conflicts use a small count without changing duration',
    (tester) async {
      viewport(tester, const Size(1920, 1080));
      final p = await denseWorkbenchProvider();
      addTearDown(p.dispose);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final three = [
        for (var i = 0; i < 3; i++)
          tester.getRect(
            occurrence('dense-three-$i', '2026-09-08T09:00:00.000'),
          ),
      ];
      three.sort((a, b) => a.left.compareTo(b.left));
      expect(three[0].width, greaterThanOrEqualTo(64));
      for (var i = 1; i < 3; i++) {
        expect(three[i].left, greaterThan(three[i - 1].right));
      }
      expect(three[0].height, closeTo(105, 1));
      final more = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'general-timed-more-occurrences-dense-six-',
            ),
      );
      expect(more, findsOneWidget);
      expect(tester.getSize(more).width, lessThan(three.first.width));
      final short = occurrence('dense-short', '2026-09-10T08:00:00.000');
      expect(tester.getSize(short).height, lessThanOrEqualTo(6));
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('general-more-occurrences-sheet')),
        findsOneWidget,
      );
      for (var i = 0; i < 6; i++) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('general-more-occurrences-sheet')),
            matching: find.text('Parallel session ${i + 1}'),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('general-more-occurrences-sheet')),
          matching: find.text('Parallel session 6'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('general-more-occurrences-sheet')),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'all-day preview is two compact lanes and expansion keeps a bounded scrolling region',
    (tester) async {
      viewport(tester, const Size(1440, 900));
      final p = await denseWorkbenchProvider();
      addTearDown(p.dispose);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final area = find.byKey(const ValueKey('general-all-day-timeline'));
      expect(tester.getSize(area).height, lessThanOrEqualTo(72));
      expect(find.text('Project submission'), findsOneWidget);
      expect(find.text('Research week'), findsNothing);
      expect(find.text('Campus exhibition'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('general-all-day-more-occurrences')),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(area).height, lessThanOrEqualTo(240));
      expect(find.text('Campus exhibition'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('general-all-day-expanded-scroll')),
        findsOneWidget,
      );
      final headerRect = tester.getRect(
        find.byKey(
          const ValueKey('general-week-day-header-2026-09-08T00:00:00.000'),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('general-timeline-grid')),
        const Offset(0, -160),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(
          find.byKey(
            const ValueKey('general-week-day-header-2026-09-08T00:00:00.000'),
          ),
        ),
        headerRect,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 1280),
    const Size(1280, 800),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'dense workbench fits ${size.width} with large text and dark/light themes',
      (tester) async {
        viewport(tester, size);
        final p = await denseWorkbenchProvider();
        addTearDown(p.dispose);
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final brightness in Brightness.values) {
            await tester.pumpWidget(
              WorkspaceHarness(
                provider: p,
                textScale: scale,
                brightness: brightness,
              ),
            );
            await tester.pumpAndSettle();
            final pager = tester.getRect(
              find.byKey(const ValueKey('general-week-pager')),
            );
            final visibleGrids = find
                .byKey(const ValueKey('general-timeline-grid'))
                .evaluate()
                .where((element) {
                  final box = element.renderObject! as RenderBox;
                  final rect = box.localToGlobal(Offset.zero) & box.size;
                  return rect.intersect(pager).width >= pager.width - 2;
                });
            expect(visibleGrids, hasLength(1));
            expect(p.selectedGeneralDate, DateTime(2026, 9, 8));
            expect(
              tester.takeException(),
              isNull,
              reason: '$size $scale $brightness',
            );
          }
        }
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'developer preference opens AI on return, retains input and closes only after a successful save',
    (tester) async {
      viewport(tester, const Size(1920, 1080));
      final p = await denseWorkbenchProvider();
      addTearDown(p.dispose);
      var succeed = true;
      final prefs = DeveloperUiPreferences(
        read: () async => false,
        write: (_) async => succeed,
      );
      await prefs.load();
      addTearDown(prefs.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, developerUiPreferences: prefs),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsNothing);
      final context = tester.element(find.byType(GeneralScheduleHomeScreen));
      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(
          builder: (_) => DeveloperModePage(
            productivityBridge: AndroidProductivityBridge(enabled: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('developer-assistant-visible')),
      );
      await tester.pumpAndSettle();
      expect(prefs.assistantVisible, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-draft')),
        'Local draft, not sent',
      );
      await tester.tap(find.byKey(const ValueKey('general-add-event')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Event draft');
      final state = tester.state(find.byType(GeneralEventEditorSheet));
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPreviewPane), findsNothing);
      expect(prefs.assistantVisible, isTrue);
      expect(tester.state(find.byType(GeneralEventEditorSheet)), same(state));
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('assistant-draft')))
            .controller!
            .text,
        'Local draft, not sent',
      );
      succeed = false;
      final close = find.descendant(
        of: find.byType(AssistantPreviewPane),
        matching: find.byTooltip('Close'),
      );
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(prefs.assistantVisible, isTrue);
      expect(prefs.hasError, isTrue);
      succeed = true;
      await prefs.retry();
      await tester.pumpAndSettle();
      expect(prefs.assistantVisible, isFalse);
      expect(find.byType(AssistantPreviewPane), findsNothing);
      await prefs.setAssistantVisible(true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('assistant-draft')))
            .controller!
            .text,
        'Local draft, not sent',
      );
      expect(tester.state(find.byType(GeneralEventEditorSheet)), same(state));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'dense month uses real font budgets and keeps all dates reachable at two-times text',
    (tester) async {
      viewport(tester, const Size(1280, 800));
      final p = await denseWorkbenchProvider(
        view: generalViewMonth,
        locale: 'zh',
      );
      addTearDown(p.dispose);
      for (final size in [
        const Size(360, 800),
        const Size(800, 1280),
        const Size(1280, 800),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        for (final scale in [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: p,
              locale: const Locale('zh'),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'month $size $scale');
          expect(p.selectedGeneralDate, DateTime(2026, 9, 8));
          final grids = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'general-month-date-grid-',
                ),
          );
          expect(grids, findsOneWidget);
        }
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
  testWidgets(
    'portrait month uses the remaining canvas and keeps selection across rotation',
    (tester) async {
      viewport(tester, const Size(800, 1280));
      final p = await denseWorkbenchProvider(
        view: generalViewMonth,
        locale: 'zh',
      );
      addTearDown(p.dispose);
      for (final scale in [1.0, 1.3]) {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final calendar = find.byKey(
          const ValueKey('general-month-calendar-panel'),
        );
        final agenda = find.byKey(
          const ValueKey('general-month-stacked-agenda'),
        );
        expect(agenda, findsOneWidget);
        expect(tester.getSize(calendar).height, greaterThan(500));
        expect(tester.getRect(agenda).bottom, closeTo(1280, 1));
        expect(
          tester.getRect(calendar).bottom,
          closeTo(tester.getRect(agenda).top, 1),
        );
        final date = find.byKey(
          const ValueKey('general-month-day-cell-2026-9-23'),
        );
        expect(date.hitTestable(), findsOneWidget);
        await tester.tap(date);
        await tester.pumpAndSettle();
        expect(p.selectedGeneralDate, DateTime(2026, 9, 23));
        expect(
          find.descendant(
            of: agenda,
            matching: find.textContaining('2026-09-23'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 9, 23));
      expect(
        find.byKey(const ValueKey('general-month-stacked-agenda')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
