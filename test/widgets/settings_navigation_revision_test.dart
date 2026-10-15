import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/language_settings_page.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/period_time_set_manager.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

import '../support/workspace_harness.dart';
import '../support/period_time_assets.dart';

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
  testWidgets(
    'picker opens the shared manager and cancellation never assigns a timetable',
    (t) async {
      _viewport(t, const Size(600, 900));
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final bindings = p.timetables
          .map((item) => item.config.periodTimeSetId)
          .toList();
      final writes = storage.writes;
      var completed = false;
      String? selected;
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          textScale: 2,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showPeriodTimeSetPickerDialog(
                    context,
                    selectedPeriodTimeSetId: p.periodTimeSets.first.id,
                  );
                  completed = true;
                },
                child: const Text('Choose periods'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Choose periods'));
      await t.pumpAndSettle();
      await _open(t, 'period-time-set-manage');
      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(completed, isTrue);
      expect(selected, isNull);
      expect(
        p.timetables.map((item) => item.config.periodTimeSetId).toList(),
        bindings,
      );
      expect(storage.writes, writes);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  for (final width in [393.0, 1280.0]) {
    testWidgets(
      'settings leave timetable period assignment in its owning form at $width',
      (t) async {
        _viewport(t, Size(width, 900));
        final (p, storage) = await _fixture();
        addTearDown(p.dispose);
        final before = p.activeTimetable.config.periodTimeSetId;
        final writes = storage.writes;
        await t.pumpWidget(
          WorkspaceHarness(provider: p, home: const SettingsPage()),
        );
        await t.pumpAndSettle();
        expect(_key('settings-period-times'), findsNothing);
        expect(find.byType(PeriodTimeSetPickerDialogView), findsNothing);
        expect(p.activeTimetable.config.periodTimeSetId, before);
        expect(storage.writes, writes);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'student resource menu manages shared periods without assignment',
    (t) async {
      _viewport(t, const Size(1440, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final other = await p.addPeriodTimeSet(
        name: 'Evening',
        periodTimes: buildDefaultPeriodTimes(),
      );
      final original = p.activeTimetable.config.periodTimeSetId;
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      await _open(t, 'student-resource-menu');
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == 'periods',
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      expect(find.byType(PeriodTimeSetPickerDialogView), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
      await t.tap(find.text(other.name));
      await t.pumpAndSettle();
      expect(find.byType(PeriodTimesPage), findsOneWidget);
      await t.enterText(_key('period-times-name'), 'Renamed evening');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(p.periodTimeSetForId(other.id)!.name, 'Renamed evening');
      expect(p.activeTimetable.config.periodTimeSetId, original);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final empty in [false, true]) {
    testWidgets(
      'phone menu retains period management with empty timetable: $empty',
      (t) async {
        mockDefaultPeriodTimeAsset();
        _viewport(t, const Size(393, 900));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        if (empty) {
          for (final timetable in p.timetables.toList()) {
            await p.deleteTimetable(timetable.id);
          }
          for (final set in p.periodTimeSets.toList()) {
            await p.deletePeriodTimeSet(set.id);
          }
        }
        final before = p.activeTimetableOrNull?.config.periodTimeSetId;
        await t.pumpWidget(WorkspaceHarness(provider: p));
        await t.pumpAndSettle();
        await _open(t, 'student-toolbar-more-button');
        await _open(t, 'student-more-periods');
        expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
        expect(find.byType(PeriodTimeSetPickerDialogView), findsNothing);
        if (empty) {
          expect(find.text('No available period time set'), findsOneWidget);
          await _open(t, 'period-time-set-create');
          expect(p.periodTimeSets, hasLength(1));
          expect(find.byType(PeriodTimesPage), findsOneWidget);
          expect(p.activeTimetableOrNull, isNull);
        } else {
          expect(p.activeTimetable.config.periodTimeSetId, before);
        }
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'period selection returns a draft and cancellation never assigns',
    (t) async {
      _viewport(t, const Size(393, 900));
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final other = await p.addPeriodTimeSet(
        name: 'Evening',
        periodTimes: buildDefaultPeriodTimes(),
      );
      final original = p.activeTimetable.config.periodTimeSetId;
      final writes = storage.writes;
      String? result;
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPeriodTimeSetPickerDialog(
                    context,
                    selectedPeriodTimeSetId: original,
                  );
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Choose'));
      await t.pumpAndSettle();
      t
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onSelect(other.id);
      await t.pumpAndSettle();
      expect(result, other.id);
      expect(p.activeTimetable.config.periodTimeSetId, original);
      expect(storage.writes, writes);
      await t.tap(find.text('Choose'));
      await t.pumpAndSettle();
      t
          .widget<PeriodTimeSetPickerDialogView>(
            find.byType(PeriodTimeSetPickerDialogView),
          )
          .onCancel();
      await t.pumpAndSettle();
      expect(result, isNull);
      expect(p.activeTimetable.config.periodTimeSetId, original);
      expect(storage.writes, writes);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('creating a timetable requires an existing period set', (
    t,
  ) async {
    _viewport(t, const Size(393, 900));
    final (p, storage) = await _fixture();
    addTearDown(p.dispose);
    for (final table in p.timetables.toList()) {
      await p.deleteTimetable(table.id);
    }
    for (final set in p.periodTimeSets.toList()) {
      await p.deletePeriodTimeSet(set.id);
    }
    final writes = storage.writes;
    await t.pumpWidget(WorkspaceHarness(provider: p));
    await t.pumpAndSettle();
    final l10n = AppLocalizations.of(
      t.element(_key('student-workspace-toolbar')),
    );
    await t.tap(find.text(l10n.createTimetable));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(p.timetables, isEmpty);
    expect(p.periodTimeSets, isEmpty);
    expect(storage.writes, writes);
    await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await t.pumpAndSettle();
    expect(p.timetables, isEmpty);
    expect(storage.writes, writes);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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
