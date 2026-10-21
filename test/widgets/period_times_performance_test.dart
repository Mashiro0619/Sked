import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/sked_time_picker.dart';

import '../support/workspace_harness.dart';

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  var writes = 0;
  Completer<void>? pending;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await pending?.future;
    await super.save(value);
  }

  void release() {
    final operation = pending;
    pending = null;
    if (operation != null && !operation.isCompleted) operation.complete();
  }
}

Finder _key(String value) => find.byKey(ValueKey(value));

bool _canPop(WidgetTester tester) => tester
    .widget<PopScope<void>>(
      find.descendant(
        of: find.byType(PeriodTimesPage),
        matching: find.byType(PopScope<void>),
      ),
    )
    .canPop;

void main() {
  for (final count in [12, 48]) {
    testWidgets(
      'typing with $count periods retains the table and updates save guards',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final periods = count == 12
            ? buildDefaultPeriodTimes()
            : List.generate(
                count,
                (index) => CoursePeriodTime(
                  index: index + 1,
                  startMinutes: index * 15,
                  endMinutes: index * 15 + 10,
                ),
              );
        final storage = _Storage(
          buildInitialAppData(periods, localeCode: 'en'),
        );
        addTearDown(storage.release);
        final app = await workspaceProvider(storage: storage);
        addTearDown(app.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            home: const PeriodTimesPage(
              periodTimeSetId: defaultPeriodTimeSetId,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final name = _key('period-times-name');
        await tester.tap(name);
        await tester.pumpAndSettle();
        final table = tester.widget(_key('period-times-list'));
        final builds = <String, int>{};
        final previousHook = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          final type = element.widget.runtimeType.toString();
          builds.update(type, (count) => count + 1, ifAbsent: () => 1);
          previousHook?.call(element, builtOnce);
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previousHook);

        expect(_canPop(tester), isTrue);
        for (var index = 0; index < 8; index++) {
          await tester.enterText(name, 'Period name $index');
          await tester.pump(const Duration(milliseconds: 30));
          expect(_canPop(tester), isFalse);
          expect(tester.widget(_key('period-times-list')), same(table));
        }
        expect(builds['_PeriodEditorRow'] ?? 0, 0);
        expect(builds['_PeriodEditorTable'] ?? 0, 0);
        expect(builds['PeriodTimesPage'], 8);
        expect(find.text('Waiting to save…'), findsOneWidget);
        expect(storage.writes, 0);

        storage.pending = Completer<void>();
        await tester.pump(const Duration(milliseconds: 410));
        await tester.pump();
        expect(storage.writes, 1);
        expect(find.text('Saving changes...'), findsOneWidget);
        expect(
          tester
              .widget<SkedPopupMenuButton>(_key('period-time-set-menu'))
              .enabled,
          isFalse,
        );
        expect(_canPop(tester), isFalse);
        storage.release();
        await tester.pumpAndSettle();
        expect(find.text('Period times saved'), findsOneWidget);
        expect(_canPop(tester), isTrue);
        expect(
          tester
              .widget<SkedPopupMenuButton>(_key('period-time-set-menu'))
              .enabled,
          isTrue,
        );
        expect(builds['_PeriodEditorRow'] ?? 0, 0);
        expect(builds['_PeriodEditorTable'] ?? 0, 0);

        // A successful save must not leave PopScope open for a later draft.
        await tester.enterText(name, 'A new unsaved name');
        await tester.pump();
        expect(_canPop(tester), isFalse);
        expect(storage.writes, 1);
        expect(tester.widget(_key('period-times-list')), same(table));
        await tester.pump(const Duration(milliseconds: 410));
        await tester.pumpAndSettle();
        expect(storage.writes, 2);
        expect(_canPop(tester), isTrue);
        expect(builds['_PeriodEditorRow'] ?? 0, 0);
        expect(tester.takeException(), isNull);
        debugOnRebuildDirtyWidget = previousHook;
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'retained period table updates for time edits and inherited geometry',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _Storage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
      );
      final app = await workspaceProvider(storage: storage);
      addTearDown(app.dispose);
      const page = PeriodTimesPage(periodTimeSetId: defaultPeriodTimeSetId);
      await tester.pumpWidget(WorkspaceHarness(provider: app, home: page));
      await tester.pumpAndSettle();
      final first = _key('period-row-1');
      final rowElement = tester.element(first);
      final wideWidth = tester.getSize(first).width;
      await tester.tap(_key('period-end-time-action').first);
      await tester.pumpAndSettle();
      tester
          .widget<SkedTimePicker>(find.byType(SkedTimePicker))
          .onSelected(const TimeOfDay(hour: 8, minute: 50));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: first, matching: find.text('08:50')),
        findsOneWidget,
      );
      expect(tester.element(first), same(rowElement));
      expect(
        storage
            .data
            .studentMode
            .periodTimeSets
            .first
            .periodTimes
            .first
            .endMinutes,
        530,
      );

      tester.view.physicalSize = const Size(393, 800);
      await tester.pumpAndSettle();
      expect(tester.getSize(first).width, lessThan(wideWidth));
      final compactHeight = tester.getSize(first).height;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          home: page,
          textScale: 2,
          locale: const Locale('zh'),
          fontFamily: 'Ahem',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(first).height, greaterThan(compactHeight));
      expect(tester.element(first), same(rowElement));
      expect(tester.getRect(first).right, lessThanOrEqualTo(393));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
