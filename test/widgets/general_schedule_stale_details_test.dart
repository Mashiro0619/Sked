import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _detail => find.byType(GeneralEventDetailsSheet);
Finder get _editor => find.byType(GeneralEventEditorSheet);
Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

AppData _sample() =>
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'work',
        defaultView: generalViewDay,
        selectedDateIso: '2026-10-08',
        schedules: [
          GeneralSchedule(
            id: 'work',
            name: 'Work',
            events: [
              GeneralEvent(
                id: 'series',
                calendarId: 'work',
                title: 'Weekly review',
                notes: 'Original note',
                startDateTimeIso: '2026-10-01T09:00:00.000',
                endDateTimeIso: '2026-10-01T10:00:00.000',
                recurrenceRule: const GeneralEventRecurrenceRule(
                  type: GeneralEventRecurrence.weekly,
                  count: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );

Future<TimetableProvider> _mount(
  WidgetTester tester,
  WorkspaceMemoryStorage storage, {
  bool phone = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = phone
      ? const Size(430, 950)
      : const Size(1600, 1000);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      home: GeneralReminderTimeScope(
        now: () => DateTime(2026, 10, 8, 8),
        createTimer: (delay, callback) => Timer(delay, callback),
        child: const GeneralScheduleHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(
    tester,
    _key('general-timed-occurrence-series-2026-10-08T09:00:00.000'),
  );
  expect(_detail, findsOneWidget);
  return provider;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapConfirmation(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  // The detail remains busy behind its confirmation route.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _renameThroughAgenda(WidgetTester tester) async {
  await _tap(tester, _key('general-day-agenda-toggle'));
  final agenda = _key('general-selected-day-agenda');
  await _tap(tester, _inside(agenda, find.text('Weekly review')));
  await _tap(tester, _inside(_detail, _key('general-event-edit-action')));
  await tester.enterText(
    _inside(_editor, find.byType(EditableText)).first,
    'Updated through day agenda',
  );
  await _tap(tester, _inside(_editor, find.text('Save')));
  await _tap(tester, _inside(agenda, _key('workspace-inspector-close')));
  expect(_detail, findsOneWidget);
}

void main() {
  for (final future in [false, true]) {
    testWidgets(
      'calendar detail preserves agenda edits when deleting ${future ? 'future occurrences' : 'one occurrence'}',
      (tester) async {
        final storage = WorkspaceMemoryStorage(_sample());
        final provider = await _mount(tester, storage);
        final committedTitles = <String>[];
        final subscription = provider.committedData.listen((commit) {
          committedTitles.add(
            commit.snapshot.generalMode.schedules.single.events.single.title,
          );
        });
        addTearDown(subscription.cancel);

        await _renameThroughAgenda(tester);
        expect(
          tester
              .widget<GeneralEventDetailsSheet>(_detail)
              .occurrence
              .event
              .title,
          'Updated through day agenda',
        );
        await _tapConfirmation(
          tester,
          _inside(_detail, _key('general-event-delete-action')),
        );
        await _tapConfirmation(
          tester,
          _key(
            future
                ? 'general-event-delete-this-and-following'
                : 'general-event-delete-this',
          ),
        );
        await tester.pumpAndSettle();

        final saved = storage.data.generalMode.schedules.single.events.single;
        expect(saved.title, 'Updated through day agenda');
        expect(saved.notes, 'Original note');
        if (future) {
          expect(saved.recurrenceRule.untilDateIso, '2026-10-07');
        } else {
          expect(saved.recurrenceExceptionDateIso, ['2026-10-08']);
        }
        expect(committedTitles, isNotEmpty);
        expect(committedTitles, everyElement('Updated through day agenda'));
        expect(_detail, findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('an already captured edit action opens the latest saved event', (
    tester,
  ) async {
    final storage = WorkspaceMemoryStorage(_sample());
    final provider = await _mount(tester, storage);
    final opened = tester.widget<GeneralEventDetailsSheet>(_detail);
    final edited = opened.occurrence.event.copyWith(title: 'Updated elsewhere');
    await provider.saveGeneralEvent(edited);

    unawaited(Future<void>.sync(() => opened.onEdit!()));
    await tester.pumpAndSettle();

    expect(_editor, findsOneWidget);
    expect(
      tester.widget<GeneralEventEditorSheet>(_editor).initialEvent!.title,
      'Updated elsewhere',
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'a removed occurrence retires its detail and captured commands stay inert',
    (tester) async {
      final storage = WorkspaceMemoryStorage(_sample());
      final provider = await _mount(tester, storage);
      final opened = tester.widget<GeneralEventDetailsSheet>(_detail);
      final edited = opened.occurrence.event.copyWith(
        recurrenceExceptionDateIso: const ['2026-10-08'],
      );
      await provider.saveGeneralEvent(edited);
      await tester.pumpAndSettle();

      expect(_detail, findsNothing);
      await opened.onDeleteThis!();
      await opened.onDeleteFuture!();
      await opened.onDeleteAll!();
      await opened.onDuplicate!();
      await tester.pumpAndSettle();

      expect(storage.data.generalMode.schedules.single.events, hasLength(1));
      expect(
        storage.data.generalMode.schedules.single.events.single.toJson(),
        edited.normalized(fallbackCalendarId: 'work').toJson(),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final phone in [false, true]) {
    testWidgets(
      'failed occurrence deletion keeps the ${phone ? 'phone' : 'desktop'} detail available for retry',
      (tester) async {
        final storage = WorkspaceMemoryStorage(_sample());
        await _mount(tester, storage, phone: phone);
        storage.saveError = StateError('retryable write failure');

        Future<void> deleteOccurrence() async {
          await _tapConfirmation(
            tester,
            _inside(_detail, _key('general-event-delete-action')),
          );
          await _tapConfirmation(tester, _key('general-event-delete-this'));
          await tester.pumpAndSettle();
        }

        await deleteOccurrence();
        expect(_detail, findsOneWidget);
        expect(
          storage
              .data
              .generalMode
              .schedules
              .single
              .events
              .single
              .recurrenceExceptionDateIso,
          isEmpty,
        );
        expect(_key('ui-command-failure-notice'), findsOneWidget);
        await _tap(tester, _key('ui-command-failure-dismiss'));

        await deleteOccurrence();
        expect(_detail, findsNothing);
        expect(
          storage
              .data
              .generalMode
              .schedules
              .single
              .events
              .single
              .recurrenceExceptionDateIso,
          ['2026-10-08'],
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        phone ? TargetPlatform.android : TargetPlatform.windows,
      ),
    );
  }
}
