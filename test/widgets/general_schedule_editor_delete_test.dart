import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_task_session.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _editor => find.byType(GeneralEventEditorSheet);
Finder get _confirmation => _key('editor-delete-confirmation');
Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

class _DeleteStorage extends WorkspaceMemoryStorage {
  _DeleteStorage(super.data);

  int saveCalls = 0;
  Completer<void>? saveStarted;
  Completer<void>? saveGate;

  @override
  Future<void> save(AppData value) async {
    saveCalls += 1;
    if (saveGate case final gate?) {
      saveStarted?.complete();
      await gate.future;
      saveGate = null;
    }
    await super.save(value);
  }
}

AppData _sample({required bool repeating}) =>
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
                id: 'event',
                calendarId: 'work',
                title: 'Weekly review',
                startDateTimeIso: repeating
                    ? '2026-10-01T09:00:00.000'
                    : '2026-10-08T09:00:00.000',
                endDateTimeIso: repeating
                    ? '2026-10-01T10:00:00.000'
                    : '2026-10-08T10:00:00.000',
                recurrenceRule: repeating
                    ? const GeneralEventRecurrenceRule(
                        type: GeneralEventRecurrence.weekly,
                        count: 4,
                      )
                    : const GeneralEventRecurrenceRule(),
              ),
              GeneralEvent(
                id: 'other',
                calendarId: 'work',
                title: 'Unrelated event',
                startDateTimeIso: '2026-10-08T13:00:00.000',
                endDateTimeIso: '2026-10-08T14:00:00.000',
              ),
            ],
          ),
        ],
      ),
    );

Future<TimetableProvider> _mount(
  WidgetTester tester,
  _DeleteStorage storage, {
  required bool phone,
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
    final gate = storage.saveGate;
    if (gate != null && !gate.isCompleted) gate.complete();
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
    _key('general-timed-occurrence-event-2026-10-08T09:00:00.000'),
  );
  await _tap(
    tester,
    _inside(
      find.byType(GeneralEventDetailsSheet),
      _key('general-event-edit-action'),
    ),
  );
  expect(_editor, findsOneWidget);
  return provider;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _deleteButton() => find.ancestor(
  of: _inside(_editor, find.text('Delete')),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

void main() {
  for (final phone in [true, false]) {
    for (final repeating in [true, false]) {
      testWidgets(
        '${phone ? 'phone' : 'desktop'} ${repeating ? 'recurring' : 'one-off'} editor confirms deletion and cancel preserves the draft',
        (tester) async {
          final storage = _DeleteStorage(_sample(repeating: repeating));
          final provider = await _mount(tester, storage, phone: phone);
          final baselineWrites = storage.saveCalls;
          final committed = <AppData>[];
          final subscription = provider.committedData.listen(
            (commit) => committed.add(commit.snapshot),
          );
          addTearDown(subscription.cancel);
          await tester.enterText(
            _inside(_editor, find.byType(EditableText)).first,
            'Unsaved draft title',
          );
          if (repeating) {
            await _tap(tester, _key('event-recurrence-field'));
            await _tap(tester, find.text('Does not repeat'));
            await _tap(tester, find.widgetWithText(FilledButton, 'Confirm'));
          }

          await _tap(tester, _deleteButton());
          expect(_confirmation, findsOneWidget);
          expect(
            _inside(
              _confirmation,
              find.text(repeating ? 'Delete entire series' : 'Delete event'),
            ),
            findsWidgets,
          );
          expect(
            _inside(_confirmation, find.text('Weekly review')),
            findsOneWidget,
          );
          expect(
            storage.data.generalMode.schedules.single.events,
            hasLength(2),
          );
          expect(storage.saveCalls, baselineWrites);
          expect(committed, isEmpty);
          await _tap(tester, _inside(_confirmation, find.text('Cancel')));
          expect(_confirmation, findsNothing);
          expect(
            _inside(_editor, find.text('Unsaved draft title')),
            findsOneWidget,
          );
          expect(storage.saveCalls, baselineWrites);
          expect(committed, isEmpty);

          await _tap(tester, _deleteButton());
          final confirm = _inside(_confirmation, find.byType(FilledButton));
          await tester.tap(confirm);
          await tester.tap(confirm, warnIfMissed: false);
          await tester.pumpAndSettle();

          expect(storage.saveCalls, baselineWrites + 1);
          expect(
            storage.data.generalMode.schedules.single.events.map(
              (event) => event.id,
            ),
            ['other'],
          );
          expect(committed, hasLength(1));
          expect(
            committed.single.generalMode.schedules.single.events.map(
              (event) => event.id,
            ),
            ['other'],
          );
          expect(_editor, findsNothing);
          expect(_confirmation, findsNothing);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(
          phone ? TargetPlatform.android : TargetPlatform.windows,
        ),
      );
    }

    testWidgets(
      '${phone ? 'phone' : 'desktop'} editor deletion blocks duplicate actions and supports retry after a failed write',
      (tester) async {
        final storage = _DeleteStorage(_sample(repeating: true));
        await _mount(tester, storage, phone: phone);
        final baselineWrites = storage.saveCalls;
        storage.saveGate = Completer<void>();
        storage.saveStarted = Completer<void>();
        storage.saveError = StateError('retryable delete failure');

        await _tap(tester, _deleteButton());
        await tester.tap(_inside(_confirmation, find.byType(FilledButton)));
        await _transition(tester);

        expect(storage.saveStarted!.isCompleted, isTrue);
        expect(
          SkedTaskSessionScope.isCurrent(tester.element(_editor)),
          isTrue,
          reason: 'The editor must remain current while its own deletion can still fail.',
        );
        expect(storage.data.generalMode.schedules.single.events, hasLength(2));
        expect(
          tester.widget<ButtonStyleButton>(_deleteButton()).onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
                _inside(_editor, find.widgetWithText(TextButton, 'Cancel')),
              )
              .onPressed,
          isNull,
        );
        await tester.binding.handlePopRoute();
        await _transition(tester);
        expect(_editor, findsOneWidget);
        storage.saveGate!.complete();
        await tester.pumpAndSettle();

        expect(_editor, findsOneWidget);
        expect(_key('ui-command-failure-notice'), findsOneWidget);
        expect(storage.saveCalls, baselineWrites + 1);
        expect(storage.data.generalMode.schedules.single.events, hasLength(2));
        await _tap(tester, _key('ui-command-failure-dismiss'));
        await _tap(tester, _deleteButton());
        await _tap(tester, _inside(_confirmation, find.byType(FilledButton)));

        expect(_editor, findsNothing);
        expect(storage.saveCalls, baselineWrites + 2);
        expect(
          storage.data.generalMode.schedules.single.events.map(
            (event) => event.id,
          ),
          ['other'],
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        phone ? TargetPlatform.android : TargetPlatform.windows,
      ),
    );
  }
}
