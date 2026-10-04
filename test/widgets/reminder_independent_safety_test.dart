import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/reminder_summary_harness.dart';
import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
Finder get details => find.byType(GeneralEventDetailsSheet);
Finder get list => k('general-reminders-list');
Finder get editor => find.byType(GeneralEventEditorSheet);
Finder inside(String key) => find.descendant(of: details, matching: k(key));
Finder row(String title) =>
    find.descendant(of: list, matching: find.text(title));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

class _GatedStorage extends WorkspaceMemoryStorage {
  _GatedStorage(super.data);
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await gate?.future;
    await super.save(value);
  }
}

WorkspaceMemoryStorage fixture({
  bool repeating = false,
  bool longNotes = false,
}) {
  final storage = reminderSummaryStorage();
  final calendar = storage.data.generalMode.schedules.single;
  storage.data = storage.data.copyWith(
    generalMode: storage.data.generalMode.copyWith(
      schedules: [
        calendar.copyWith(
          events: [
            for (final e in calendar.events)
              e.id != 'study'
                  ? e
                  : e.copyWith(
                      recurrenceRule: repeating
                          ? const GeneralEventRecurrenceRule(
                              type: GeneralEventRecurrence.daily,
                              count: 3,
                            )
                          : e.recurrenceRule,
                      notes: longNotes
                          ? List.filled(60, 'Long note').join('\n')
                          : e.notes,
                    ),
          ],
        ),
      ],
    ),
  );
  return storage;
}

Future<TimetableProvider> mount(
  WidgetTester t, {
  WorkspaceMemoryStorage? storage,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1440, 900);
  addTearDown(t.view.reset);
  final p = await workspaceProvider(
    mode: AppMode.general,
    storage: storage ?? fixture(),
  );
  addTearDown(p.dispose);
  await t.pumpWidget(
    reminderSummaryHarness(
      p,
      ReminderSummaryClock(),
      scale: scale,
      direction: direction,
      session: GeneralReminderStartupSession(),
    ),
  );
  await t.pumpAndSettle();
  // Repeating events can have two identically titled reminder rows.
  await t.tap(
    k(
      'general-reminder-${buildGeneralOccurrenceKey('summary', 'study', '2026-10-01T18:30:00.000')}',
    ),
  );
  await t.pumpAndSettle();
  return p;
}

Future<void> closeList(WidgetTester t) async {
  await t.tap(
    find.descendant(of: list, matching: k('workspace-inspector-close')),
  );
  await t.pumpAndSettle();
  expect(list, findsNothing);
}

GeneralEvent study(TimetableProvider p) =>
    p.generalSchedules.single.events.firstWhere((e) => e.id == 'study');

Future<void> confirmDelete(WidgetTester t, {bool repeating = false}) async {
  await t.tap(inside('general-event-delete-action'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
  if (repeating) {
    await t.tap(k('general-event-delete-this'));
  } else {
    await t.tap(k('general-event-confirm-delete'));
  }
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  for (final rebuild in [false, true]) {
    testWidgets(
      'independent edit resolves latest event even before rebuilding: $rebuild',
      (t) async {
        final p = await mount(t);
        await closeList(t);
        final element = t.element(details);
        final latest = study(p)
            .copyWith(notes: 'Latest saved note', title: 'Updated study');
        await p.saveGeneralEvent(latest);
        if (rebuild) {
          await t.pumpAndSettle();
          expect(t.element(details), same(element));
          expect(
            t.widget<GeneralEventDetailsSheet>(details).occurrence.event.notes,
            latest.notes,
          );
        }
        await t.tap(inside('general-event-edit-action'));
        await t.pumpAndSettle();
        expect(
          t.widget<GeneralEventEditorSheet>(editor).initialEvent!.notes,
          latest.notes,
        );
        await t.enterText(
          find
              .descendant(of: editor, matching: find.byType(TextFormField))
              .at(1),
          'Updated location',
        );
        await t.tap(find.descendant(of: editor, matching: find.text('Save')));
        await t.pumpAndSettle();
        expect(study(p).notes, latest.notes);
        expect(study(p).title, latest.title);
        expect(study(p).location, 'Updated location');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'recurrence delete re-resolves fields and exceptions after child confirmation',
    (t) async {
      final p = await mount(t, storage: fixture(repeating: true));
      await closeList(t);
      await t.tap(inside('general-event-delete-action'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await p.saveGeneralEvent(
        study(p).copyWith(
          notes: 'Updated during confirmation',
          recurrenceExceptionDateIso: ['2026-10-03'],
        ),
      );
      // Deliberately do not rebuild the detail before invoking the confirmation.
      await t.tap(k('general-event-delete-this'));
      await t.pumpAndSettle();
      expect(study(p).notes, 'Updated during confirmation');
      expect(study(p).recurrenceExceptionDateIso, ['2026-10-01', '2026-10-03']);
      expect(details, findsNothing);
      expect(list, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final removedBy in ['start', 'exception', 'count']) {
    testWidgets(
      'retire invalid instance even when the event ID still exists: $removedBy',
      (t) async {
        final p = await mount(t, storage: fixture(repeating: true));
        await closeList(t);
        final e = study(p);
        await p.saveGeneralEvent(switch (removedBy) {
          'start' => e.copyWith(startDateTimeIso: '2026-10-01T19:00:00.000'),
          'exception' => e.copyWith(recurrenceExceptionDateIso: ['2026-10-01']),
          _ => e.copyWith(
            startDateTimeIso: '2026-09-30T18:30:00.000',
            endDateTimeIso: '2026-09-30T20:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.daily,
              count: 1,
            ),
          ),
        });
        await t.pumpAndSettle();
        expect(study(p).id, 'study');
        expect(details, findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'data replacement retires the old detail and permits new activation',
    (t) async {
      final p = await mount(t);
      final backup = await p.exportAppDataJson();
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      await t.pumpAndSettle();
      expect(details, findsNothing);
      if (list.evaluate().isEmpty) {
        await t.tap(k('general-reminders-action'));
        await t.pumpAndSettle();
      }
      await t.tap(row('Study group'));
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'independent duplicate resolves the latest fields before rebuilding',
    (t) async {
      final p = await mount(t);
      await closeList(t);
      await p.saveGeneralEvent(
        study(p).copyWith(notes: 'Current duplicate notes'),
      );
      await t.tap(inside('general-event-duplicate-action'));
      await t.pumpAndSettle();
      final duplicates = p.generalSchedules.single.events.where(
        (e) => e.id != 'study' && e.title == 'Study group',
      );
      expect(duplicates, hasLength(1));
      expect(duplicates.single.notes, 'Current duplicate notes');
      expect(details, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'floating editor suspends detail without destroying it, then allows retry',
    (t) async {
      await mount(t);
      final detailElement = t.element(details);
      final oldActivate = t
          .widget<FilledButton>(inside('general-event-edit-action'))
          .onPressed!;
      await t.tap(k('general-add-event'));
      await t.pumpAndSettle();
      final originalEditor = t.element(editor);
      expect(details, findsNothing);
      final suspended = find.byType(
        GeneralEventDetailsSheet,
        skipOffstage: false,
      );
      expect(t.element(suspended), same(detailElement));
      // A callback retained from before the rebuild must also reject safely.
      oldActivate();
      await t.pumpAndSettle();
      expect(t.element(suspended), same(detailElement));
      expect(t.element(editor), same(originalEditor));
      expect(t.widget<GeneralEventEditorSheet>(editor).initialEvent, isNull);
      await t.tap(find.descendant(of: editor, matching: find.text('Cancel')));
      await t.pumpAndSettle();
      expect(editor, findsNothing);
      expect(
        t.widget<FilledButton>(inside('general-event-edit-action')).onPressed,
        isNotNull,
      );
      await t.tap(inside('general-event-edit-action'));
      await t.pumpAndSettle();
      expect(details, findsNothing);
      expect(
        t.widget<GeneralEventEditorSheet>(editor).initialEvent!.id,
        'study',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final repeating in [false, true]) {
    testWidgets(
      'pending delete survives source close, resize and failure retry: repeating=$repeating',
      (t) async {
        final storage = _GatedStorage(fixture(repeating: repeating).data);
        final p = await mount(t, storage: storage);
        final gate = Completer<void>();
        storage.gate = gate;
        storage.saveError = StateError('Expected delete failure');
        final element = t.element(details);
        await confirmDelete(t, repeating: repeating);
        // The model already reflects deletion but its write has not completed.
        final count = storage.writes;
        await t.tap(
          find.descendant(of: list, matching: k('workspace-inspector-close')),
        );
        await t.pump();
        await t.pump(const Duration(seconds: 1));
        t.view.physicalSize = const Size(1250, 800);
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(t.element(details), same(element));
        await t.tap(inside('workspace-inspector-close'));
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.tap(inside('general-event-delete-action'));
        await t.pump();
        expect(details, findsOneWidget);
        expect(storage.writes, count);
        gate.complete();
        await t.pumpAndSettle();
        expect(t.element(details), same(element));
        expect(list, findsNothing);
        expect(k('ui-command-failure-notice'), findsOneWidget);
        expect(study(p).recurrenceExceptionDateIso, isEmpty);
        await t.tap(k('ui-command-failure-dismiss'));
        await t.pumpAndSettle();
        storage.gate = null;
        await confirmDelete(t, repeating: repeating);
        await t.pumpAndSettle();
        expect(details, findsNothing);
        expect(list, findsNothing);
        if (repeating) {
          expect(study(p).recurrenceExceptionDateIso, ['2026-10-01']);
        } else {
          expect(
            p.generalSchedules.single.events.any((e) => e.id == 'study'),
            isFalse,
          );
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'pending delete does not exempt a mounted inactive workspace from retirement',
    (t) async {
      final storage = _GatedStorage(fixture().data);
      final p = await mount(t, storage: storage);
      final gate = Completer<void>();
      storage.gate = gate;
      await confirmDelete(t);
      await t.pumpWidget(
        reminderSummaryHarness(p, ReminderSummaryClock(), active: false),
      );
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(details, findsNothing);
      gate.complete();
      await t.pumpAndSettle();
      await t.pumpWidget(reminderSummaryHarness(p, ReminderSummaryClock()));
      await t.pumpAndSettle();
      expect(details, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'independent long-body size and scroll detach from source at 2x $direction',
      (t) async {
        await mount(
          t,
          storage: fixture(longNotes: true),
          scale: 2,
          direction: direction,
        );
        await t.drag(inside('workspace-view-body'), const Offset(0, -140));
        await t.pumpAndSettle();
        final surface = k('workspace-companion-view-surface');
        final element = t.element(details);
        final before = t.getRect(surface);
        final body = t.state<ScrollableState>(
          find.descendant(of: details, matching: find.byType(Scrollable)).last,
        );
        final scroll = body.position.pixels;
        expect(scroll, greaterThan(0));
        await closeList(t);
        expect(t.getRect(surface), before);
        expect(t.element(details), same(element));
        expect(body.position.pixels, scroll);
        t.view.physicalSize = const Size(1100, 650);
        await t.pumpAndSettle();
        final smaller = t.getRect(surface);
        expect(smaller.bottom, lessThanOrEqualTo(642));
        expect(smaller.left, greaterThanOrEqualTo(8));
        expect(smaller.right, lessThanOrEqualTo(1092));
        t.view.physicalSize = const Size(1440, 900);
        await t.pumpAndSettle();
        expect(t.getRect(surface), before);
        expect(body.position.pixels, scroll);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }
}
