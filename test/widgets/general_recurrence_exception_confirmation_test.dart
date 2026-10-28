import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_task_session.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _editor => find.byType(GeneralEventEditorSheet);
Finder get _confirmation => _key('event-recurrence-exceptions-confirmation');
Finder get _confirm => _key('event-recurrence-exceptions-save');
Finder get _cancel => _key('event-recurrence-exceptions-cancel');
Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  int writes = 0;
  Completer<void>? started;
  Completer<void>? gate;

  @override
  Future<void> save(AppData value) async {
    writes += 1;
    if (gate case final pending?) {
      if (started?.isCompleted == false) started!.complete();
      await pending.future;
      gate = null;
    }
    await super.save(value);
  }
}

AppData _sample({bool exceptions = true, bool equivalentCustom = false}) =>
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
                startDateTimeIso: '2026-10-01T09:00:00.000',
                endDateTimeIso: '2026-10-01T10:00:00.000',
                recurrenceRule: equivalentCustom
                    ? const GeneralEventRecurrenceRule(
                        type: GeneralEventRecurrence.custom,
                        unit: GeneralEventRecurrenceUnit.day,
                        interval: 7,
                        count: 30,
                      )
                    : const GeneralEventRecurrenceRule(
                        type: GeneralEventRecurrence.weekly,
                        count: 30,
                      ),
                recurrenceExceptionDateIso: exceptions
                    ? const ['2026-10-01', '2026-10-15', '2026-10-22']
                    : const [],
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

Future<AppRuntime> _mount(
  WidgetTester tester,
  _Storage storage, {
  GeneralEventEditScope scope = GeneralEventEditScope.entireSeries,
  Size size = const Size(430, 950),
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage,
  );
  addTearDown(() async {
    final gate = storage.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: locale,
      textScale: textScale,
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
  await _tap(tester, _key('event-edit-scope-${scope.name}'));
  expect(_editor, findsOneWidget);
  return provider;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(_editor));

Finder _save(WidgetTester tester) =>
    _inside(_editor, find.widgetWithText(FilledButton, _l10n(tester).save));

Future<void> _changeRule(
  WidgetTester tester,
  GeneralEventRecurrence type,
) async {
  final l10n = _l10n(tester);
  final label = switch (type) {
    GeneralEventRecurrence.daily => l10n.recurrenceDaily,
    GeneralEventRecurrence.weekly => l10n.recurrenceWeekly,
    _ => l10n.recurrenceNone,
  };
  await _tap(tester, _key('event-recurrence-field'));
  await _tap(tester, find.text(label));
  await _tap(tester, find.widgetWithText(FilledButton, l10n.confirm));
}

Future<void> _editTitle(WidgetTester tester) async {
  await tester.enterText(
    _inside(_editor, find.byType(EditableText)).first,
    'Unsaved repeat draft',
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void _expectSaved(_Storage storage, GeneralEventEditScope scope) {
  final events = storage.data.generalMode.schedules.single.events;
  expect(
    events.singleWhere((event) => event.id == 'other').toJson(),
    _sample().generalMode.schedules.single.events.last.toJson(),
  );
  final saved = events.singleWhere(
    (event) => event.title == 'Unsaved repeat draft',
  );
  expect(saved.recurrenceRule.type, GeneralEventRecurrence.daily);
  if (scope == GeneralEventEditScope.thisAndFollowing) {
    expect(events, hasLength(3));
    final prefix = events.singleWhere((event) => event.id == 'event');
    expect(prefix.recurrenceRule.type, GeneralEventRecurrence.weekly);
    expect(prefix.recurrenceRule.count, 1);
    expect(prefix.recurrenceExceptionDateIso, ['2026-10-01']);
    expect(saved.recurrenceExceptionDateIso, ['2026-10-15', '2026-10-22']);
    expect(saved.recurrenceRule.count, 29);
  } else {
    expect(events, hasLength(2));
    expect(saved.id, 'event');
    expect(saved.recurrenceExceptionDateIso, [
      '2026-10-01',
      '2026-10-15',
      '2026-10-22',
    ]);
    expect(saved.recurrenceRule.count, 30);
  }
}

void main() {
  for (final (size, locale, platform) in [
    (const Size(320, 800), const Locale('en'), TargetPlatform.android),
    (const Size(430, 950), const Locale('zh'), TargetPlatform.android),
    (const Size(1600, 1000), const Locale('en'), TargetPlatform.windows),
  ]) {
    for (final scope in [
      GeneralEventEditScope.entireSeries,
      GeneralEventEditScope.thisAndFollowing,
    ]) {
      testWidgets(
        '$platform $size $locale at 2x cancels then saves $scope exceptions',
        (tester) async {
          final storage = _Storage(_sample());
          final provider = await _mount(
            tester,
            storage,
            scope: scope,
            size: size,
            textScale: 2,
            locale: locale,
          );
          final baseline = storage.data.generalMode.toJson();
          final writes = storage.writes;
          final commits = <AppData>[];
          final subscription = provider.session.commits.listen(
            (commit) => commits.add(commit.snapshot),
          );
          addTearDown(subscription.cancel);
          await _editTitle(tester);
          await _changeRule(tester, GeneralEventRecurrence.daily);
          await _tap(tester, _save(tester));
          expect(_confirmation, findsOneWidget);
          expect(
            _inside(
              _confirmation,
              find.text(_l10n(tester).eventRecurrenceExceptionsChangeMessage),
            ),
            findsOneWidget,
          );
          expect(storage.data.generalMode.toJson(), baseline);
          expect(storage.writes, writes);
          expect(commits, isEmpty);
          expect(tester.takeException(), isNull);
          await _tap(tester, _cancel);
          expect(_confirmation, findsNothing);
          expect(
            _inside(_editor, find.text('Unsaved repeat draft')),
            findsOneWidget,
          );
          expect(
            _inside(
              _key('event-recurrence-field'),
              find.textContaining(_l10n(tester).repeatsDaily),
            ),
            findsOneWidget,
          );
          expect(storage.data.generalMode.toJson(), baseline);
          expect(storage.writes, writes);
          expect(commits, isEmpty);
          await _tap(tester, _save(tester));
          await tester.ensureVisible(_confirm);
          await tester.pumpAndSettle();
          await tester.tap(_confirm);
          await tester.tap(_confirm, warnIfMissed: false);
          await tester.pumpAndSettle();
          expect(storage.writes, writes + 1);
          expect(commits, hasLength(1));
          _expectSaved(storage, scope);
          expect(_confirmation, findsNothing);
          expect(_editor, findsNothing);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  for (final equivalent in [false, true]) {
    testWidgets(
      '${equivalent ? 'equivalent step' : 'no exclusions'} saves without confirmation',
      (tester) async {
        final storage = _Storage(
          _sample(exceptions: equivalent, equivalentCustom: equivalent),
        );
        await _mount(tester, storage);
        final writes = storage.writes;
        final exclusions = storage
            .data
            .generalMode
            .schedules
            .single
            .events
            .first
            .recurrenceExceptionDateIso;
        await _changeRule(
          tester,
          equivalent
              ? GeneralEventRecurrence.weekly
              : GeneralEventRecurrence.daily,
        );
        await _tap(tester, _save(tester));
        expect(_confirmation, findsNothing);
        expect(_editor, findsNothing);
        expect(storage.writes, writes + 1);
        expect(
          storage
              .data
              .generalMode
              .schedules
              .single
              .events
              .first
              .recurrenceExceptionDateIso,
          exclusions,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('turning repeats off confirms and clears exclusions', (
    tester,
  ) async {
    final storage = _Storage(_sample());
    await _mount(tester, storage);
    final writes = storage.writes;
    await _changeRule(tester, GeneralEventRecurrence.none);
    await _tap(tester, _save(tester));
    expect(_confirmation, findsOneWidget);
    expect(storage.writes, writes);
    await _tap(tester, _confirm);
    final event = storage.data.generalMode.schedules.single.events.first;
    expect(event.recurrenceRule.isRepeating, isFalse);
    expect(event.recurrenceExceptionDateIso, isEmpty);
    expect(storage.writes, writes + 1);
    expect(_editor, findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'following edits do not prompt for exceptions only in the prefix',
    (tester) async {
      final sample = _sample();
      final calendar = sample.generalMode.schedules.single;
      final storage = _Storage(
        sample.copyWith(
          generalMode: sample.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: [
                  calendar.events.first.copyWith(
                    recurrenceExceptionDateIso: const ['2026-10-01'],
                  ),
                  calendar.events.last,
                ],
              ),
            ],
          ),
        ),
      );
      await _mount(
        tester,
        storage,
        scope: GeneralEventEditScope.thisAndFollowing,
      );
      final writes = storage.writes;
      await _changeRule(tester, GeneralEventRecurrence.daily);
      await _tap(tester, _save(tester));
      expect(_confirmation, findsNothing);
      expect(_editor, findsNothing);
      expect(storage.writes, writes + 1);
      final events = storage.data.generalMode.schedules.single.events;
      expect(events, hasLength(3));
      expect(
        events
            .singleWhere((event) => event.id == 'event')
            .recurrenceExceptionDateIso,
        ['2026-10-01'],
      );
      expect(
        events
            .singleWhere(
              (event) =>
                  event.recurrenceRule.type == GeneralEventRecurrence.daily,
            )
            .recurrenceExceptionDateIso,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('confirmation cannot overwrite an externally updated source', (
    tester,
  ) async {
    final storage = _Storage(_sample());
    final provider = await _mount(tester, storage);
    await _editTitle(tester);
    await _changeRule(tester, GeneralEventRecurrence.daily);
    await _tap(tester, _save(tester));
    await provider.generalCommands.saveEvent(
      provider.generalView.schedules.single.events.first.copyWith(
        location: 'Updated externally',
      ),
    );
    await tester.pumpAndSettle();
    final baseline = storage.data.generalMode.toJson();
    final writes = storage.writes;
    await _tap(tester, _confirm);
    expect(_editor, findsOneWidget);
    expect(_key('ui-command-failure-notice'), findsOneWidget);
    expect(_inside(_editor, find.text('Unsaved repeat draft')), findsOneWidget);
    expect(storage.data.generalMode.toJson(), baseline);
    expect(storage.writes, writes);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'data session retirement rejects an already captured confirmation',
    (tester) async {
      final storage = _Storage(_sample());
      final provider = await _mount(tester, storage);
      final originalEvents = storage.data.generalMode.schedules.single.events
          .map((event) => event.toJson())
          .toList();
      await _changeRule(tester, GeneralEventRecurrence.daily);
      await _tap(tester, _save(tester));
      final staleConfirm = tester.widget<FilledButton>(_confirm).onPressed!;
      final writes = storage.writes;
      final reservation = provider.maintenance.reserve();
      provider.maintenance.release(reservation);
      staleConfirm();
      await tester.pumpAndSettle();
      expect(_confirmation, findsNothing);
      expect(_editor, findsNothing);
      expect(storage.writes, writes);
      expect(
        storage.data.generalMode.schedules.single.events
            .map((event) => event.toJson())
            .toList(),
        originalEvents,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final phone in [true, false]) {
    testWidgets(
      '${phone ? 'phone' : 'desktop'} failed following save retains draft and retries without duplicate suffixes',
      (tester) async {
        final storage = _Storage(_sample());
        final provider = await _mount(
          tester,
          storage,
          scope: GeneralEventEditScope.thisAndFollowing,
          size: phone ? const Size(430, 950) : const Size(1600, 1000),
        );
        final baseline = storage.data.generalMode.toJson();
        final writes = storage.writes;
        final commits = <AppData>[];
        final subscription = provider.session.commits.listen(
          (commit) => commits.add(commit.snapshot),
        );
        addTearDown(subscription.cancel);
        await _editTitle(tester);
        await _changeRule(tester, GeneralEventRecurrence.daily);
        await _tap(tester, _save(tester));
        storage.gate = Completer<void>();
        storage.started = Completer<void>();
        storage.saveError = StateError('retryable repeat save failure');
        await tester.tap(_confirm);
        await tester.tap(_confirm, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(storage.started!.isCompleted, isTrue);
        expect(storage.writes, writes + 1);
        expect(storage.data.generalMode.toJson(), baseline);
        expect(commits, isEmpty);
        expect(SkedTaskSessionScope.isCurrent(tester.element(_editor)), isTrue);
        expect(tester.widget<FilledButton>(_save(tester)).onPressed, isNull);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(_editor, findsOneWidget);
        storage.gate!.complete();
        await tester.pumpAndSettle();
        expect(storage.data.generalMode.toJson(), baseline);
        expect(commits, isEmpty);
        expect(_key('ui-command-failure-notice'), findsOneWidget);
        expect(
          _inside(_editor, find.text('Unsaved repeat draft')),
          findsOneWidget,
        );
        await _tap(tester, _key('ui-command-failure-dismiss'));
        await _tap(tester, _save(tester));
        expect(_confirmation, findsOneWidget);
        await _tap(tester, _confirm);
        expect(storage.writes, writes + 2);
        expect(commits, hasLength(1));
        _expectSaved(storage, GeneralEventEditScope.thisAndFollowing);
        expect(_editor, findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        phone ? TargetPlatform.android : TargetPlatform.windows,
      ),
    );
  }
}
