import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_runtime_mutation_lock.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _dateButton => _key('general-date-title-button');
Finder get _viewButton => _key('general-view-switcher');
Finder get _viewMenu => find.descendant(
  of: _viewButton,
  matching: find.byType(SkedPopupMenuButton<String>),
);

class _NavigationStorage extends WorkspaceMemoryStorage {
  _NavigationStorage(super.data);

  int writes = 0;
  Completer<void>? saveGate;
  Completer<void>? saveEntered;

  @override
  Future<void> save(AppData value) async {
    writes++;
    final gate = saveGate;
    saveGate = null;
    if (gate != null) {
      saveEntered?.complete();
      await gate.future;
    }
    await super.save(value);
  }
}

GeneralDateRange get _customRange =>
    GeneralDateRange(DateTime(2026, 9, 3), DateTime(2026, 9, 12));

Future<(TimetableProvider, _NavigationStorage)> _setup() async {
  final base = mobileLayoutData();
  final storage = _NavigationStorage(
    base.copyWith(
      generalMode: base.generalMode.copyWith(
        selectedDateIso: '2026-09-03',
        customDateRange: _customRange,
        viewSwitchBehavior: generalViewSwitchBehaviorMenu,
        schedules: [
          // Match the reported empty calendar with no visible categories.
          GeneralSchedule(
            id: base.generalMode.activeScheduleId,
            name: 'Hidden calendar',
            isVisible: false,
            events: const [],
          ),
        ],
      ),
    ),
  );
  final provider = await workspaceProvider(
    storage: storage,
    locale: 'zh',
    // The shared harness normally bypasses this production lock. Keep it real
    // here so notification/UI contention cannot silently disappear in tests.
    workspaceMutationLock: withAgendaRuntimeMutationLock<void>,
  );
  addTearDown(provider.dispose);
  return (provider, storage);
}

Future<void> _phone(WidgetTester t, TimetableProvider provider) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(393, 852);
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
  await t.pumpWidget(
    WorkspaceHarness(provider: provider, locale: const Locale('zh')),
  );
  await t.pumpAndSettle();
}

Future<void> _chooseWeek(WidgetTester t) async {
  await t.tap(_viewButton);
  await t.pumpAndSettle();
  await t.tap(
    find.byWidgetPredicate(
      (widget) =>
          widget is SkedPopupMenuItem<String> &&
          widget.value == generalViewWeek,
    ),
  );
  await t.pumpAndSettle();
}

void _expectNavigationEnabled(WidgetTester t) {
  expect(t.widget<OutlinedButton>(_dateButton).onPressed, isNotNull);
  expect(t.widget<SkedPopupMenuButton<String>>(_viewMenu).enabled, isTrue);
  expect(_key('workspace-switch-busy'), findsNothing);
}

void main() {
  testWidgets(
    'phone custom to week, date picker and workspace switch work while notifications hold the runtime lock',
    (t) async {
      final (provider, storage) = await _setup();
      await _phone(t, provider);
      expect(provider.customGeneralDateRange, _customRange);
      final before = storage.writes;
      late Completer<void> release;
      Future<void>? notificationProjection;
      var projectionFinished = false;
      try {
        await t.runAsync(() async {
          final entered = Completer<void>();
          release = Completer<void>();
          notificationProjection =
              withAgendaRuntimeMutationLock(() async {
                entered.complete();
                await release.future;
              }).then<void>((_) {
                projectionFinished = true;
              });
          await entered.future.timeout(const Duration(seconds: 3));
        });
        expect(
          t.takeException(),
          isNull,
          reason: 'The real notification lock must be acquired before testing the UI.',
        );
        await _chooseWeek(t);
        expect(provider.customGeneralDateRange, isNull);
        expect(storage.data.generalMode.customDateRange, isNull);
        expect(storage.writes, before + 1);
        _expectNavigationEnabled(t);
        expect(projectionFinished, isFalse);

        await t.tap(_dateButton);
        await t.pumpAndSettle();
        expect(find.byType(SkedDatePicker), findsOneWidget);
        Navigator.of(t.element(find.byType(SkedDatePicker))).pop();
        await t.pumpAndSettle();
        await t.tap(_key('adaptive-shell-student-destination'));
        await t.pumpAndSettle();
        expect(provider.activeMode, AppMode.student);
        expect(_key('workspace-switch-busy'), findsNothing);
        await t.tap(_key('adaptive-shell-general-destination'));
        await t.pumpAndSettle();
        expect(provider.activeMode, AppMode.general);
        expect(provider.customGeneralDateRange, isNull);
        _expectNavigationEnabled(t);
        expect(projectionFinished, isFalse);
        expect(t.takeException(), isNull);
      } finally {
        release.complete();
        await t.runAsync(() async => await notificationProjection);
        await t.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'failed custom to week save keeps the old view, releases controls and permits one explicit retry',
    (t) async {
      final (provider, storage) = await _setup();
      await _phone(t, provider);
      final before = storage.writes;
      final gate = Completer<void>();
      storage.saveGate = gate;
      storage.saveEntered = Completer<void>();
      storage.saveError = StateError('calendar storage failed');
      try {
        await _chooseWeek(t);
        expect(storage.saveEntered!.isCompleted, isTrue);
        expect(provider.customGeneralDateRange, _customRange);
        expect(storage.data.generalMode.customDateRange, _customRange);
        expect(t.widget<OutlinedButton>(_dateButton).onPressed, isNull);
        expect(
          t.widget<SkedPopupMenuButton<String>>(_viewMenu).enabled,
          isFalse,
        );
        expect(storage.writes, before + 1);
      } finally {
        gate.complete();
        await t.pumpAndSettle();
      }
      expect(provider.customGeneralDateRange, _customRange);
      expect(storage.data.generalMode.customDateRange, _customRange);
      _expectNavigationEnabled(t);
      final l10n = AppLocalizations.of(t.element(_dateButton));
      expect(find.text(l10n.saveFailedRetry), findsOneWidget);
      expect(storage.writes, before + 1);

      await _chooseWeek(t);
      expect(provider.customGeneralDateRange, isNull);
      expect(storage.data.generalMode.customDateRange, isNull);
      expect(storage.writes, before + 2);
      _expectNavigationEnabled(t);
      await t.tap(_key('adaptive-shell-student-destination'));
      await t.pumpAndSettle();
      expect(provider.activeMode, AppMode.student);
      expect(_key('workspace-switch-busy'), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
