import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/language_settings_page.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/period_time_set_manager.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

import '../support/workspace_harness.dart';

Finder _key(String id) => find.byKey(ValueKey(id));
void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _open(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  Completer<void>? pending;
  @override
  Future<void> save(AppData data) async {
    writes++;
    await pending?.future;
    await super.save(data);
  }
}

Future<(TimetableProvider, _Storage)> _fixture() async {
  final seed = await workspaceProvider();
  final storage = _Storage(seed.appData);
  seed.dispose();
  return (await workspaceProvider(storage: storage), storage);
}

void main() {
  for (final width in [393.0, 1280.0]) {
    testWidgets(
      'period set entry uses the existing dialog at $width, not a manager page',
      (t) async {
        _viewport(t, Size(width, 900));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final before = p.activeTimetable.config.periodTimeSetId;
        await t.pumpWidget(
          WorkspaceHarness(provider: p, home: const SettingsPage()),
        );
        await t.pumpAndSettle();
        await _open(t, 'settings-period-times');
        expect(find.byType(PeriodTimeSetPickerDialogView), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(PeriodTimeSetManagerPage), findsNothing);
        final picker = t.widget<PeriodTimeSetPickerDialogView>(
          find.byType(PeriodTimeSetPickerDialogView),
        );
        expect(picker.selectedPeriodTimeSetId, before);
        picker.onCancel();
        await t.pumpAndSettle();
        expect(p.activeTimetable.config.periodTimeSetId, before);
        expect(_key('settings-period-times').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('student resource menu selects a period set in a dialog', (
    t,
  ) async {
    _viewport(t, const Size(1440, 900));
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    await t.pumpWidget(WorkspaceHarness(provider: p));
    await t.pumpAndSettle();
    await _open(t, 'student-resource-menu');
    await t.tap(
      find.byWidgetPredicate(
        (w) => w is PopupMenuItem<String> && w.value == 'periods',
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(PeriodTimeSetPickerDialogView), findsOneWidget);
    expect(find.byType(PeriodTimeSetManagerPage), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'period selection waits for one save, blocks back, and can retry failures',
    (t) async {
      _viewport(t, const Size(393, 900));
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final other = await p.addPeriodTimeSet(
        name: 'Evening',
        periodTimes: buildDefaultPeriodTimes(),
      );
      final original = p.activeTimetable.config.periodTimeSetId;
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      await _open(t, 'settings-period-times');
      final view = find.byType(PeriodTimeSetPickerDialogView);
      var picker = t.widget<PeriodTimeSetPickerDialogView>(view);
      storage.pending = Completer<void>();
      storage.saveError = StateError('disk full');
      final writes = storage.writes;
      picker.onSelect(other.id);
      picker.onSelect(other.id);
      await t.pump(const Duration(milliseconds: 200));
      expect(storage.writes, writes + 1);
      expect(t.widget<PeriodTimeSetPickerDialogView>(view).blocked, isTrue);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(view, findsOneWidget);
      storage.pending!.complete();
      await t.pumpAndSettle();
      storage.pending = null;
      expect(view, findsOneWidget);
      expect(p.activeTimetable.config.periodTimeSetId, original);
      picker = t.widget<PeriodTimeSetPickerDialogView>(view);
      expect(picker.blocked, isFalse);
      picker.onSelect(other.id);
      await t.pumpAndSettle();
      expect(p.activeTimetable.config.periodTimeSetId, other.id);
      expect(view, findsNothing);
      expect(storage.writes, writes + 2);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('period selection stays bound to its original timetable', (
    t,
  ) async {
    _viewport(t, const Size(393, 900));
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final original = p.activeTimetable.id;
    final other = await p.addPeriodTimeSet(
      name: 'Evening',
      periodTimes: buildDefaultPeriodTimes(),
    );
    await p.addTimetable(
      p.activeTimetable.config.copyWith(name: 'Another timetable'),
    );
    final second = p.activeTimetable.id;
    final secondSet = p.activeTimetable.config.periodTimeSetId;
    await p.switchTimetable(original);
    await t.pumpWidget(
      WorkspaceHarness(provider: p, home: const SettingsPage()),
    );
    await t.pumpAndSettle();
    await _open(t, 'settings-period-times');
    await p.switchTimetable(second);
    await t.pumpAndSettle();
    t
        .widget<PeriodTimeSetPickerDialogView>(
          find.byType(PeriodTimeSetPickerDialogView),
        )
        .onSelect(other.id);
    await t.pumpAndSettle();
    expect(
      p.timetables
          .firstWhere((table) => table.id == original)
          .config
          .periodTimeSetId,
      other.id,
    );
    expect(p.activeTimetable.config.periodTimeSetId, secondSet);
    expect(p.activeTimetable.id, second);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'period dialog retains editing even without an active timetable',
    (t) async {
      _viewport(t, const Size(393, 900));
      final (seed, storage) = await _fixture();
      storage.data = seed.appData.copyWith(
        studentMode: seed.appData.studentMode.copyWith(
          timetables: [],
          activeTimetableId: '',
        ),
      );
      seed.dispose();
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      await _open(t, 'settings-period-times');
      final picker = t.widget<PeriodTimeSetPickerDialogView>(
        find.byType(PeriodTimeSetPickerDialogView),
      );
      picker.onEdit(p.periodTimeSets.first);
      await t.pumpAndSettle();
      expect(find.byType(PeriodTimesPage), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.byType(PeriodTimeSetPickerDialogView), findsOneWidget);
      t
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onSelect(p.periodTimeSets.first.id);
      await t.pumpAndSettle();
      expect(p.activeTimetableOrNull, isNull);
      expect(find.byType(PeriodTimeSetPickerDialogView), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'language search survives resizing; wide selection stays on its independent page',
    (t) async {
      _viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      await _open(t, 'settings-language');
      expect(find.byType(LanguageSettingsPage), findsOneWidget);
      await t.enterText(_key('language-search'), 'Deutsch');
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(1280, 900);
      await t.pumpAndSettle();
      expect(
        t
            .widget<EditableText>(
              find.descendant(
                of: _key('language-search'),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'Deutsch',
      );
      await t.tap(_key('language-option-de'));
      await t.pumpAndSettle();
      expect(p.localeCode, 'de');
      expect(find.byType(LanguageSettingsPage), findsOneWidget);
      t.view.physicalSize = const Size(393, 900);
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
      expect(_key('settings-language').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'language selection guards back during save and retains its page after failure',
    (t) async {
      _viewport(t, const Size(393, 900));
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      await _open(t, 'settings-language');
      await t.enterText(_key('language-search'), 'Deutsch');
      await t.pumpAndSettle();
      storage.pending = Completer<void>();
      storage.saveError = StateError('disk full');
      await t.tap(_key('language-option-de'));
      await t.pump(const Duration(milliseconds: 200));
      await t.pageBack();
      await t.pump();
      expect(find.byType(LanguageSettingsPage), findsOneWidget);
      storage.pending!.complete();
      await t.pumpAndSettle();
      storage.pending = null;
      expect(p.localeCode, 'en');
      expect(find.byType(LanguageSettingsPage), findsOneWidget);
      await t.tap(_key('language-option-de'));
      await t.pumpAndSettle();
      expect(p.localeCode, 'de');
      expect(find.byType(LanguageSettingsPage), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
