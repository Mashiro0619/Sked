import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

const _visibleCalendar = GeneralSchedule(id: 'work', name: 'Work', events: []);
const _hiddenCalendar = GeneralSchedule(
  id: 'work',
  name: 'Archive',
  isVisible: false,
  events: [],
);

GeneralEvent _event({
  GeneralEventReminderBehavior? behavior,
  List<int> minutes = const [],
}) => GeneralEvent(
  id: 'event',
  calendarId: 'work',
  title: 'Planning',
  startDateTimeIso: '2026-08-03T10:00:00.000',
  endDateTimeIso: '2026-08-03T11:00:00.000',
  reminderBehavior: behavior,
  reminders: [
    for (final minute in minutes) GeneralEventReminder(minutesBefore: minute),
  ],
);

GeneralEventOccurrence _occurrence(GeneralEvent event, {bool hidden = false}) =>
    GeneralEventOccurrence(
      event: event,
      calendar: hidden ? _hiddenCalendar : _visibleCalendar,
      start: DateTime(2026, 8, 3, 10),
      end: DateTime(2026, 8, 3, 11),
      sequence: 0,
    );

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child));
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.widgetWithText(FilledButton, 'Save'));

void main() {
  testWidgets(
    'inherited preview refreshes without replacing the editor draft',
    (tester) async {
      final defaultMinutes = ValueNotifier<int?>(15);
      addTearDown(defaultMinutes.dispose);
      GeneralEvent? saved;
      await _mount(
        tester,
        ValueListenableBuilder<int?>(
          valueListenable: defaultMinutes,
          builder: (_, value, _) => GeneralEventEditorSheet(
            key: const ValueKey('editor'),
            calendars: const [_visibleCalendar],
            activeCalendarId: 'work',
            initialDate: DateTime(2026, 8, 3, 10),
            defaultReminderMinutesBefore: value,
            onSave: (event) async => saved = event,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'My unsaved draft',
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );
      final reminderField = _key('event-reminder-field');
      await tester.ensureVisible(reminderField);
      expect(
        find.descendant(
          of: reminderField,
          matching: find.text(
            l.courseReminderInherit(l.reminderMinutesBefore(15)),
          ),
        ),
        findsOneWidget,
      );
      defaultMinutes.value = 30;
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: reminderField,
          matching: find.text(
            l.courseReminderInherit(l.reminderMinutesBefore(30)),
          ),
        ),
        findsOneWidget,
      );
      await _save(tester);
      expect(saved?.title, 'My unsaved draft');
      expect(saved?.reminderBehavior, GeneralEventReminderBehavior.inherit);
      expect(saved?.reminders, isEmpty);
    },
  );

  testWidgets('an open inherited reminder picker refreshes a changed default', (
    tester,
  ) async {
    final defaultMinutes = ValueNotifier<int?>(15);
    addTearDown(defaultMinutes.dispose);
    await _mount(
      tester,
      ValueListenableBuilder<int?>(
        valueListenable: defaultMinutes,
        builder: (_, value, _) => GeneralEventEditorSheet(
          key: const ValueKey('editor'),
          initialEvent: _event(behavior: GeneralEventReminderBehavior.inherit),
          calendars: const [_visibleCalendar],
          activeCalendarId: 'work',
          defaultReminderMinutesBefore: value,
        ),
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    await _tap(tester, _key('event-reminder-field'));
    defaultMinutes.value = 30;
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _key('general-reminder-inherit'),
        matching: find.text(
          l.courseReminderInherit(l.reminderMinutesBefore(30)),
        ),
      ),
      findsOneWidget,
    );
    await _tap(tester, _key('general-reminder-custom'));
    expect(
      tester.widget<FilterChip>(_key('general-reminder-choice-30')).selected,
      isTrue,
    );
    await _tap(tester, _key('general-reminder-choice-5'));
    defaultMinutes.value = 60;
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _key('general-reminder-inherit'),
        matching: find.text(l.courseReminderInherit(l.reminderHourBefore)),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<FilterChip>(_key('general-reminder-choice-30')).selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(_key('general-reminder-choice-5')).selected,
      isTrue,
    );
    expect(
      tester.widget<FilterChip>(_key('general-reminder-choice-60')).selected,
      isFalse,
    );
    await _tap(tester, _key('general-reminder-cancel'));
  });

  testWidgets('custom picker edits imported minutes outside the preset list', (
    tester,
  ) async {
    final legacyJson = _event(minutes: const [17, 60]).toJson()
      ..remove('reminderBehavior');
    final original = GeneralEvent.fromJson(legacyJson);
    GeneralEvent? saved;
    await _mount(
      tester,
      GeneralEventEditorSheet(
        initialEvent: original,
        calendars: const [_visibleCalendar],
        activeCalendarId: 'work',
        defaultReminderMinutesBefore: 30,
        onSave: (event) async => saved = event,
      ),
    );
    await _tap(tester, _key('event-reminder-field'));
    expect(_key('general-reminder-choice-17'), findsOneWidget);
    expect(
      tester.widget<FilterChip>(_key('general-reminder-choice-17')).selected,
      isTrue,
    );
    await _tap(tester, _key('general-reminder-choice-5'));
    await _tap(tester, _key('general-reminder-choice-17'));
    await _tap(tester, _key('general-reminder-confirm'));
    expect(saved, isNull);
    await _save(tester);
    expect(saved?.reminderBehavior, GeneralEventReminderBehavior.custom);
    expect(saved?.reminders.map((item) => item.minutesBefore), [5, 60]);
    expect(original.reminders.map((item) => item.minutesBefore), [17, 60]);
  });

  testWidgets(
    'cancelling a policy change preserves an explicitly disabled event',
    (tester) async {
      final original = _event();
      GeneralEvent? saved;
      await _mount(
        tester,
        GeneralEventEditorSheet(
          initialEvent: original,
          calendars: const [_visibleCalendar],
          activeCalendarId: 'work',
          defaultReminderMinutesBefore: 15,
          onSave: (event) async => saved = event,
        ),
      );
      await _tap(tester, _key('event-reminder-field'));
      await _tap(tester, _key('general-reminder-custom'));
      expect(_key('general-reminder-choice-15'), findsOneWidget);
      await _tap(tester, _key('general-reminder-choice-5'));
      await _tap(tester, _key('general-reminder-cancel'));
      await _save(tester);
      expect(saved?.reminderBehavior, GeneralEventReminderBehavior.disabled);
      expect(saved?.reminders, isEmpty);
    },
  );

  testWidgets(
    'a single hidden category remains named and hidden while editing',
    (tester) async {
      GeneralEvent? saved;
      await _mount(
        tester,
        GeneralEventEditorSheet(
          initialEvent: _event(),
          calendars: const [_hiddenCalendar],
          activeCalendarId: 'work',
          onSave: (event) async => saved = event,
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );
      expect(find.byType(SkedDropdownMenu<String>), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text(l.categoryHidden), findsOneWidget);
      await _save(tester);
      expect(saved?.calendarId, 'work');
      expect(_hiddenCalendar.isVisible, isFalse);
    },
  );

  testWidgets('only-this editing shows scope and cannot change recurrence', (
    tester,
  ) async {
    GeneralEvent? saved;
    await _mount(
      tester,
      GeneralEventEditorSheet(
        initialEvent: _event(behavior: GeneralEventReminderBehavior.inherit),
        editScope: GeneralEventEditScope.thisOccurrence,
        calendars: const [_visibleCalendar],
        activeCalendarId: 'work',
        onSave: (event) async => saved = event,
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    expect(
      tester.widget<Text>(_key('event-editor-edit-scope')).data,
      l.eventEditThisOccurrence,
    );
    await _tap(tester, _key('event-recurrence-field'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(_key('general-recurrence-panel'), findsNothing);
    await _save(tester);
    expect(saved?.recurrenceRule.isRepeating, isFalse);
    expect(saved?.reminderBehavior, GeneralEventReminderBehavior.inherit);
  });

  testWidgets(
    'details refresh inherited reminders and expose actions only when effective',
    (tester) async {
      final defaultMinutes = ValueNotifier<int?>(null);
      addTearDown(defaultMinutes.dispose);
      final occurrence = _occurrence(
        _event(behavior: GeneralEventReminderBehavior.inherit),
      );
      await _mount(
        tester,
        ValueListenableBuilder<int?>(
          valueListenable: defaultMinutes,
          builder: (_, value, _) => GeneralEventDetailsSheet(
            occurrence: occurrence,
            notificationSettings: NotificationSettings(
              generalDefaultMinutesBefore: value,
            ),
            onDismissReminder: () {},
          ),
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(GeneralEventDetailsSheet)),
      );
      expect(find.text(l.courseReminderInherit(l.none)), findsOneWidget);
      expect(_key('general-event-reminder-action'), findsNothing);
      defaultMinutes.value = 15;
      await tester.pumpAndSettle();
      expect(
        find.text(l.courseReminderInherit(l.reminderMinutesBefore(15))),
        findsOneWidget,
      );
      expect(_key('general-event-reminder-action'), findsOneWidget);
      defaultMinutes.value = null;
      await tester.pumpAndSettle();
      expect(_key('general-event-reminder-action'), findsNothing);
    },
  );

  testWidgets(
    'editing a UTC event title preserves its instants and creation metadata',
    (tester) async {
      final original = _event(minutes: const [17, 60]).copyWith(
        startDateTimeIso: '2026-08-03T23:30:00.000Z',
        endDateTimeIso: '2026-08-04T00:30:00.000Z',
        createdAtIso: '2026-08-01T12:00:00.000Z',
        location: 'Room A',
      );
      GeneralEvent? saved;
      await _mount(
        tester,
        GeneralEventEditorSheet(
          initialEvent: original,
          calendars: const [_visibleCalendar],
          activeCalendarId: 'work',
          onSave: (event) async => saved = event,
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Updated title');
      await _save(tester);
      expect(saved?.title, 'Updated title');
      expect(saved?.startDateTimeIso, original.startDateTimeIso);
      expect(saved?.endDateTimeIso, original.endDateTimeIso);
      expect(saved?.createdAtIso, original.createdAtIso);
      expect(saved?.location, original.location);
      expect(saved?.reminderBehavior, GeneralEventReminderBehavior.custom);
      expect(saved?.reminders.map((item) => item.minutesBefore), [17, 60]);
    },
  );

  testWidgets(
    'hidden details show their category and reveal it only on explicit action',
    (tester) async {
      var showCalls = 0;
      await _mount(
        tester,
        GeneralEventDetailsSheet(
          occurrence: _occurrence(_event(), hidden: true),
          onShowCalendar: () => showCalls++,
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(GeneralEventDetailsSheet)),
      );
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text(l.categoryHidden), findsOneWidget);
      expect(showCalls, 0);
      await _tap(tester, _key('general-event-show-calendar'));
      expect(showCalls, 1);
      expect(_hiddenCalendar.isVisible, isFalse);
    },
  );
}
