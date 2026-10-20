import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/data_transfer_codec.dart';
import '../support/workspace_harness.dart';

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  int writes = 0;
  Completer<void>? nextGate;
  final entered = Completer<void>();

  @override
  Future<void> save(AppData value) async {
    writes++;
    final gate = nextGate;
    nextGate = null;
    if (gate != null) {
      entered.complete();
      await gate.future;
    }
    await super.save(value);
  }
}

void main() {
  testWidgets(
    'month day clicks update before a slow save and debounce the retained-range focus',
    (tester) async {
      tester.view.devicePixelRatio = 1.25;
      tester.view.physicalSize = const Size(1440, 900) * 1.25;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final range = GeneralDateRange(
        DateTime(2026, 9, 3),
        DateTime(2026, 9, 12),
      );
      final initial = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'zh',
      );
      final storage = _Storage(
        initial.copyWith(
          activeMode: AppMode.general,
          generalMode: initial.generalMode.copyWith(
            selectedDateIso: '2026-09-08',
            customDateRange: range,
            defaultView: generalViewMonth,
            showLunarCalendar: true,
            showWeekends: true,
            schedules: [
              GeneralSchedule(id: 'empty', name: 'Calendar', events: const []),
            ],
            activeScheduleId: 'empty',
          ),
        ),
      );
      final provider = AppRuntime(
        storage: storage,
        dataTransferCodec: inlineDataTransferCodec,
        systemLocaleCodeResolver: () => 'zh',
      );
      await provider.lifecycle.load();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
      });
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, locale: const Locale('zh')),
      );
      await tester.pumpAndSettle();
      final before = storage.writes;
      final gate = Completer<void>();
      storage.nextGate = gate;
      final earlierSave = provider.persistence.save(emitCommit: false);
      await tester.pump();
      expect(storage.entered.isCompleted, isTrue);
      try {
        for (final day in [16, 17, 11, 8, 17]) {
          await tester.tap(
            find.byKey(ValueKey('general-month-day-cell-2026-9-$day')),
            kind: ui.PointerDeviceKind.mouse,
          );
          await tester.pump();
          expect(provider.generalView.selectedDate, DateTime(2026, 9, day));
          expect(provider.generalView.customDateRange, range);
          final agenda = find.byKey(
            const ValueKey('general-selected-day-agenda'),
          );
          expect(
            find.descendant(
              of: agenda,
              matching: find.text('2026-09-${day.toString().padLeft(2, '0')}'),
            ),
            findsOneWidget,
          );
          expect(storage.writes, before + 1);
          expect(storage.data.generalMode.selectedDate, DateTime(2026, 9, 8));
        }
      } finally {
        gate.complete();
        await earlierSave;
      }
      await tester.pump(const Duration(milliseconds: 449));
      expect(storage.writes, before + 1);
      await tester.pump(const Duration(milliseconds: 1));
      await provider.persistence.flushPendingUiStateSaves();
      expect(storage.writes, before + 2);
      expect(storage.data.generalMode.selectedDate, DateTime(2026, 9, 17));
      expect(storage.data.generalMode.customDateRange, range);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
