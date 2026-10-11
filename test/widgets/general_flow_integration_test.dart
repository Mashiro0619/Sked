import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/utils/general_schedule_colors.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_compact_color_picker.dart';

import '../support/desktop_panel_harness.dart';
import '../support/workspace_harness.dart';

class _CountingStorage extends WorkspaceMemoryStorage {
  _CountingStorage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.reset);
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scope in GeneralEventEditScope.values) {
    testWidgets('workspace saves the chosen recurring scope ${scope.name}', (
      tester,
    ) async {
      _viewport(tester);
      final storage = desktopPanelStorage();
      final calendar = storage.data.generalMode.schedules.single;
      final event = calendar.events.single.copyWith(
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 3,
        ),
        reminders: const [],
      );
      storage.data = storage.data.copyWith(
        generalMode: storage.data.generalMode.copyWith(
          defaultView: generalViewDay,
          selectedDateIso: '2026-09-29',
          schedules: [
            calendar.copyWith(events: [event]),
          ],
        ),
      );
      final provider = await workspaceProvider(
        storage: storage,
        mode: AppMode.general,
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(desktopPanelHarness(provider));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey(
            'general-timed-occurrence-panel-event-0-2026-09-29T19:00:00.000',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('general-event-edit-action')),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(ValueKey('event-edit-scope-${scope.name}')),
      );
      await tester.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      expect(tester.widget<GeneralEventEditorSheet>(editor).editScope, scope);
      await tester.enterText(
        find.descendant(of: editor, matching: find.byType(TextFormField)).first,
        'Edited event',
      );
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      final titles = provider
          .generalOccurrencesForRange(
            startInclusive: DateTime(2026, 9, 28),
            endExclusive: DateTime(2026, 10, 1),
          )
          .map((item) => item.event.title)
          .toList();
      expect(titles, switch (scope) {
        GeneralEventEditScope.thisOccurrence => [
          'Review session',
          'Edited event',
          'Review session',
        ],
        GeneralEventEditScope.thisAndFollowing => [
          'Review session',
          'Edited event',
          'Edited event',
        ],
        GeneralEventEditScope.entireSeries => [
          'Edited event',
          'Edited event',
          'Edited event',
        ],
      });
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }

  testWidgets(
    'cancelling an occurrence editor returns to its original details',
    (tester) async {
      _viewport(tester);
      final storage = desktopPanelStorage();
      final calendar = storage.data.generalMode.schedules.single;
      final event = calendar.events.single.copyWith(
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 3,
        ),
        reminders: const [],
      );
      storage.data = storage.data.copyWith(
        generalMode: storage.data.generalMode.copyWith(
          defaultView: generalViewDay,
          selectedDateIso: '2026-09-29',
          schedules: [
            calendar.copyWith(events: [event]),
          ],
        ),
      );
      final provider = await workspaceProvider(
        storage: storage,
        mode: AppMode.general,
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(desktopPanelHarness(provider));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey(
            'general-timed-occurrence-panel-event-0-2026-09-29T19:00:00.000',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('general-event-edit-action')),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('event-edit-scope-thisOccurrence')),
      );
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.descendant(
          of: find.byType(GeneralEventEditorSheet),
          matching: find.widgetWithText(TextButton, 'Cancel'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      expect(provider.generalSchedules.single.events, hasLength(1));
      expect(
        provider.generalSchedules.single.events.single.title,
        'Review session',
      );
      expect(
        provider
            .generalSchedules
            .single
            .events
            .single
            .recurrenceExceptionDateIso,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets('saving to the only hidden category remains discoverable', (
    tester,
  ) async {
    _viewport(tester);
    final storage = desktopPanelStorage(count: 0);
    storage.data = storage.data.copyWith(
      generalMode: storage.data.generalMode.copyWith(
        schedules: [
          storage.data.generalMode.schedules.single.copyWith(isVisible: false),
        ],
      ),
    );
    final provider = await workspaceProvider(
      storage: storage,
      mode: AppMode.general,
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(desktopPanelHarness(provider));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const ValueKey('general-add-event')));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(find.textContaining('Study'), findsWidgets);
    expect(find.textContaining('Hidden'), findsWidgets);
    final title = find
        .descendant(
          of: find.byType(GeneralEventEditorSheet),
          matching: find.byType(TextFormField),
        )
        .first;
    await tester.enterText(title, 'Hidden but saved');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(provider.generalSchedules.single.isVisible, isFalse);
    expect(
      provider.generalSchedules.single.events.single.title,
      'Hidden but saved',
    );
    expect(find.textContaining('Saved to hidden calendar'), findsOneWidget);
    await _tapVisible(tester, find.text('View event'));
    await tester.pumpAndSettle();
    expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
    expect(find.text('Hidden but saved'), findsWidgets);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('general-event-show-calendar')),
    );
    await tester.pumpAndSettle();
    expect(provider.generalSchedules.single.isVisible, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets(
    'appearance previews a theme slot without converting it on confirmation',
    (tester) async {
      _viewport(tester);
      final source = desktopPanelStorage(count: 0).data;
      final storage = WorkspaceMemoryStorage(
        source.copyWith(
          themeColorMode: themeColorModeColorful,
          colorfulUiColorValues: const {
            colorfulGeneralCalendarColor2Key: 0xff778899,
          },
          generalMode: source.generalMode.copyWith(
            schedules: [
              source.generalMode.schedules.single.copyWith(
                colorValue: generalCalendarColorSlot2Value,
              ),
            ],
          ),
        ),
      );
      final provider = await workspaceProvider(
        storage: storage,
        mode: AppMode.general,
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, home: const ThemeSettingsPage()),
      );
      await tester.pumpAndSettle();
      final tile = find.byKey(
        const ValueKey('theme-general-calendar-color-panel-calendar'),
      );
      await tester.ensureVisible(tile);
      final expectedColor = effectiveGeneralCalendarColorValue(
        tester.element(tile),
        generalCalendarColorSlot2Value,
      ).toARGB32();
      await _tapVisible(tester, tile);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SkedCompactColorPicker>(find.byType(SkedCompactColorPicker))
            .colorValue,
        expectedColor,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(SkedCompactColorPicker)),
      );
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, l.themeApplySettings),
      );
      await tester.pumpAndSettle();
      expect(
        provider.generalSchedules.single.colorValue,
        generalCalendarColorSlot2Value,
      );
      expect(
        storage.data.generalMode.schedules.single.colorValue,
        generalCalendarColorSlot2Value,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.windows}),
  );

  test('scope edits persist once, roll back completely and retry without duplicates', () async {
    final source = desktopPanelStorage().data;
    final calendar = source.generalMode.schedules.single;
    final event = calendar.events.single.copyWith(
      recurrenceRule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.weekly,
        count: 4,
      ),
    );
    final storage = _CountingStorage(
      source.copyWith(
        generalMode: source.generalMode.copyWith(
          schedules: [
            calendar.copyWith(events: [event]),
          ],
        ),
      ),
    );
    final provider = await workspaceProvider(
      storage: storage,
      mode: AppMode.general,
    );
    addTearDown(provider.dispose);
    final occurrence = provider
        .generalOccurrencesForRange(
          startInclusive: DateTime(2026, 10, 5),
          endExclusive: DateTime(2026, 10, 6),
        )
        .single;
    final draft = provider
        .prepareGeneralOccurrenceEdit(
          occurrence,
          GeneralEventEditScope.thisAndFollowing,
        )
        .copyWith(location: 'New room');
    final before = storage.data.generalMode.toJson();
    final writes = storage.writes;
    storage.saveError = StateError('disk write failed');
    await expectLater(
      provider.editGeneralOccurrence(
        occurrence,
        draft,
        GeneralEventEditScope.thisAndFollowing,
      ),
      throwsStateError,
    );
    expect(storage.writes, writes + 1);
    expect(storage.data.generalMode.toJson(), before);
    expect(provider.generalSchedules.single.events, hasLength(1));
    final saved = await provider.editGeneralOccurrence(
      occurrence,
      draft,
      GeneralEventEditScope.thisAndFollowing,
    );
    expect(storage.writes, writes + 2);
    expect(saved.id, isNot(event.id));
    expect(provider.generalSchedules.single.events, hasLength(2));
    expect(storage.data.generalMode.schedules.single.events, hasLength(2));
  });

  test('a stale editing source cannot overwrite a newer saved event', () async {
    final storage = desktopPanelStorage();
    final provider = await workspaceProvider(
      storage: storage,
      mode: AppMode.general,
    );
    addTearDown(provider.dispose);
    final occurrence = provider
        .generalOccurrencesForRange(
          startInclusive: DateTime(2026, 9, 28),
          endExclusive: DateTime(2026, 9, 29),
        )
        .single;
    await provider.saveGeneralEvent(
      occurrence.event.copyWith(location: 'Latest room'),
    );
    await expectLater(
      provider.editGeneralOccurrence(
        occurrence,
        occurrence.event.copyWith(title: 'Stale draft'),
        GeneralEventEditScope.entireSeries,
      ),
      throwsA(isA<GeneralEventEditConflictException>()),
    );
    expect(
      provider.generalSchedules.single.events.single.location,
      'Latest room',
    );
    expect(
      provider.generalSchedules.single.events.single.title,
      occurrence.event.title,
    );
  });
}
