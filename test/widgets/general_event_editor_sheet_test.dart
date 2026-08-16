import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

Widget _localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _localizedZhApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Widget _localizedCompactApp(
  Widget child, {
  Locale? locale,
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, builtChild) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: textScaler, viewInsets: viewInsets),
      child: builtChild!,
    ),
    home: Scaffold(body: child),
  );
}

Finder _dialogTextButton(String label) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.widgetWithText(TextButton, label),
);

Finder _dialogSurface() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byWidgetPredicate(
    (widget) => widget is Material && widget.type == MaterialType.card,
  ),
);

void _setTestViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

void _resetTestViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

Future<FocusNode> _focusTextFormField(WidgetTester tester, Finder field) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.showKeyboard(field);
  await tester.pump();
  final editable = tester.widget<EditableText>(
    find.descendant(of: field, matching: find.byType(EditableText)),
  );
  expect(editable.focusNode.hasFocus, isTrue);
  expect(tester.testTextInput.isVisible, isTrue);
  return editable.focusNode;
}

void _expectInputFocusDismissed(WidgetTester tester, FocusNode previousFocus) {
  expect(previousFocus.hasFocus, isFalse);
  expect(FocusManager.instance.primaryFocus, isNot(same(previousFocus)));
  expect(tester.testTextInput.isVisible, isFalse);
}

void main() {
  testWidgets('lays out on narrow screens', (tester) async {
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));

    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work calendar', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Long planning session',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.custom,
              interval: 2,
              unit: GeneralEventRecurrenceUnit.week,
              count: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses compact grouped date controls', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(scrollView.padding, const EdgeInsets.fromLTRB(16, 20, 16, 12));
    expect(find.byType(Divider), findsOneWidget);
    expect(find.byTooltip('Pick date'), findsNWidgets(2));
    expect(find.byTooltip('Pick time'), findsNWidgets(2));
    final allDayLabel = find.text('All-day');
    final allDaySwitch = find.byType(Switch).first;
    expect(
      (tester.getRect(allDaySwitch).center.dy -
              tester.getRect(allDayLabel).center.dy)
          .abs(),
      lessThan(24),
    );
    final reminderField = find.byKey(const ValueKey('event-reminder-field'));
    final reminderChevron = find.descendant(
      of: reminderField,
      matching: find.byIcon(Icons.chevron_right),
    );
    expect(
      tester.getRect(reminderChevron).center.dy,
      lessThan(tester.getRect(reminderField).bottom - 16),
    );
    final detailsSection = find.byType(ExpansionTile).last;
    await tester.ensureVisible(detailsSection);
    await tester.tap(detailsSection);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byTooltip('#FFE57373')).size,
      const Size(48, 48),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final notes = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((field) => field.decoration?.labelText == l10n.eventNotes);
    expect(notes.minLines, 2);
    expect(notes.maxLines, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps time actions inline on common Android widths', (
    tester,
  ) async {
    addTearDown(() => _resetTestViewport(tester));

    for (final width in [360.0, 393.0]) {
      _setTestViewport(tester, Size(width, 700));
      await tester.pumpWidget(
        _localizedApp(
          GeneralEventEditorSheet(
            calendars: const [
              GeneralSchedule(id: 'work', name: 'Work', events: []),
            ],
            activeCalendarId: 'work',
          ),
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );
      final startLabel = tester.getRect(find.text(l10n.eventStartTime));
      final dateAction = tester.getRect(find.byTooltip(l10n.pickDate).first);
      expect(
        dateAction.center.dy,
        lessThanOrEqualTo(startLabel.bottom + 16),
        reason: '$width dp should keep date actions in the start row',
      );
      expect(dateAction.width, greaterThanOrEqualTo(48));
      expect(dateAction.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('keeps every event field reachable in a scaled compact sheet', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));

    final calendars = const [
      GeneralSchedule(id: 'work', name: 'Work', events: []),
      GeneralSchedule(id: 'home', name: 'Home', events: []),
    ];
    await tester.pumpWidget(
      _localizedCompactApp(
        GeneralEventEditorSheet(
          calendars: calendars,
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'scaled-event',
            calendarId: 'work',
            title: 'Scaled event',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.custom,
              interval: 2,
              unit: GeneralEventRecurrenceUnit.week,
              count: 4,
            ),
          ),
        ),
        textScaler: const TextScaler.linear(1.8),
        viewInsets: const EdgeInsets.only(bottom: 220),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final startLabel = tester.getRect(find.text(l10n.eventStartTime));
    final dateAction = tester.getRect(find.byTooltip(l10n.pickDate).first);
    expect(
      dateAction.center.dy,
      greaterThan(startLabel.bottom + 8),
      reason: 'Large text should move the actions below the date summary',
    );
    for (final label in [
      l10n.eventTitle,
      l10n.place,
      l10n.calendar,
      l10n.allDay,
      l10n.eventStartTime,
      l10n.eventEndTime,
      l10n.eventRecurrence,
      l10n.reminder,
      l10n.eventNotes,
      l10n.eventColor,
    ]) {
      expect(find.text(label), findsWidgets, reason: 'Missing field: $label');
    }

    final scrollView = find.byType(SingleChildScrollView).first;
    await tester.ensureVisible(find.text(l10n.eventColor));
    await tester.ensureVisible(find.text(l10n.eventNotes));
    expect(scrollView, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds with an empty calendar list', (tester) async {
    await tester.pumpWidget(
      _localizedApp(const GeneralEventEditorSheet(calendars: [])),
    );
    await tester.pump();

    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(find.byType(SkedDropdownMenu<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides calendar picker when only one calendar exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkedDropdownMenu<String>), findsNothing);
    expect(find.text('Work'), findsNothing);
  });

  testWidgets('shows event place field below title in Chinese locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedZhApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('地点'), findsOneWidget);
    expect(find.text('上课地点'), findsNothing);

    final titleTop = tester.getTopLeft(find.text('日程标题')).dy;
    final placeTop = tester.getTopLeft(find.text('地点')).dy;
    expect(placeTop, greaterThan(titleTop));
  });

  testWidgets('all-day switch tap changes once', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pick time'), findsNWidgets(2));

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(find.byTooltip('Pick time'), findsNothing);
  });

  testWidgets('trims the initial event calendar id', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
            GeneralSchedule(id: 'home', name: 'Home', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: ' home ',
            title: 'Dinner',
            startDateTimeIso: '2026-05-25T18:00:00.000',
            endDateTimeIso: '2026-05-25T19:00:00.000',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('shows calendar picker when multiple calendars exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
            GeneralSchedule(id: 'home', name: 'Home', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkedDropdownMenu<String>), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('save / cancel / delete cannot pop twice on rapid tap', (
    tester,
  ) async {
    final results = <GeneralEventEditorResult?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final outcome =
                      await showModalBottomSheet<GeneralEventEditorResult>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => GeneralEventEditorSheet(
                          calendars: const [
                            GeneralSchedule(
                              id: 'work',
                              name: 'Work',
                              events: [],
                            ),
                          ],
                          activeCalendarId: 'work',
                          initialEvent: GeneralEvent(
                            id: 'event',
                            calendarId: 'work',
                            title: 'Meeting',
                            startDateTimeIso: '2026-05-25T09:00:00.000',
                            endDateTimeIso: '2026-05-25T10:00:00.000',
                          ),
                        ),
                      );
                  results.add(outcome);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final cancelFinder = find.widgetWithText(TextButton, l10n.cancel);
    expect(cancelFinder, findsOneWidget);

    await tester.tap(cancelFinder);
    await tester.tap(cancelFinder, warnIfMissed: false);
    await tester.pump();

    expect(
      (tester.widget(cancelFinder) as TextButton).onPressed,
      isNull,
      reason:
          'Cancel button must be disabled after first tap to block re-entry.',
    );

    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single, isNull);
    expect(
      find.text('Open'),
      findsOneWidget,
      reason: 'Parent route must remain after double-tap on cancel.',
    );
  });

  testWidgets('save failure keeps the event draft for retry', (tester) async {
    final results = <GeneralEventEditorResult?>[];
    var saveCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result =
                    await showModalBottomSheet<GeneralEventEditorResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => GeneralEventEditorSheet(
                        calendars: const [
                          GeneralSchedule(id: 'work', name: 'Work', events: []),
                        ],
                        activeCalendarId: 'work',
                        onSave: (_) async {
                          saveCount += 1;
                          if (saveCount == 1) {
                            throw StateError('retryable event save failed');
                          }
                        },
                      ),
                    );
                results.add(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Retry draft');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(find.text('Retry draft'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(results, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saveCount, 2);
    expect(find.byType(GeneralEventEditorSheet), findsNothing);
    expect(results.single?.event?.title, 'Retry draft');
  });

  testWidgets('delete failure keeps the event editor open for retry', (
    tester,
  ) async {
    final results = <GeneralEventEditorResult?>[];
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result =
                    await showModalBottomSheet<GeneralEventEditorResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => GeneralEventEditorSheet(
                        calendars: const [
                          GeneralSchedule(id: 'work', name: 'Work', events: []),
                        ],
                        activeCalendarId: 'work',
                        initialEvent: GeneralEvent(
                          id: 'event',
                          calendarId: 'work',
                          title: 'Meeting',
                          startDateTimeIso: '2026-05-25T09:00:00.000',
                          endDateTimeIso: '2026-05-25T10:00:00.000',
                        ),
                        onDelete: () async {
                          deleteCount += 1;
                          if (deleteCount == 1) {
                            throw StateError('retryable event delete failed');
                          }
                        },
                      ),
                    );
                results.add(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteCount, 1);
    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(find.text('Meeting'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(results, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteCount, 2);
    expect(find.byType(GeneralEventEditorSheet), findsNothing);
    expect(results.single?.delete, isTrue);
  });

  testWidgets('date picker ignores rapid duplicate taps', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pickDateButton = find.byTooltip('Pick date').first;
    await tester.tap(pickDateButton);
    await tester.tap(pickDateButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets(
    'secondary pickers do not restore a previously focused editor field',
    (tester) async {
      GeneralEvent? savedEvent;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showAppModalSheet<void>(
                  context: context,
                  enableDrag: false,
                  builder: (_) => GeneralEventEditorSheet(
                    calendars: const [
                      GeneralSchedule(id: 'work', name: 'Work', events: []),
                    ],
                    activeCalendarId: 'work',
                    onSave: (event) async => savedEvent = event,
                  ),
                ),
                child: const Text('Open event editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open event editor'));
      await tester.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      final l10n = AppLocalizations.of(tester.element(editor));
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Focus-safe draft');

      Future<void> expectDismissedAfter(
        Future<void> Function() interaction,
      ) async {
        final previousFocus = await _focusTextFormField(tester, titleField);
        await interaction();
        _expectInputFocusDismissed(tester, previousFocus);
        expect(find.text('Focus-safe draft'), findsOneWidget);
      }

      await expectDismissedAfter(() async {
        final recurrenceField = find.byKey(
          const ValueKey('event-recurrence-field'),
        );
        await tester.ensureVisible(recurrenceField);
        await tester.tap(recurrenceField);
        await tester.pumpAndSettle();
        await tester.tap(_dialogTextButton(l10n.cancel));
        await tester.pumpAndSettle();
      });

      await expectDismissedAfter(() async {
        final reminderField = find.byKey(
          const ValueKey('event-reminder-field'),
        );
        await tester.ensureVisible(reminderField);
        await tester.tap(reminderField);
        await tester.pumpAndSettle();
        await tester.tap(_dialogTextButton(l10n.cancel));
        await tester.pumpAndSettle();
      });

      await expectDismissedAfter(() async {
        final dateButton = find.byTooltip('Pick date').first;
        await tester.ensureVisible(dateButton);
        await tester.tap(dateButton);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.widgetWithText(TextButton, l10n.cancel),
          ),
        );
        await tester.pumpAndSettle();
      });

      await expectDismissedAfter(() async {
        final timeButton = find.byTooltip('Pick time').first;
        await tester.ensureVisible(timeButton);
        await tester.tap(timeButton);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(TimePickerDialog),
            matching: find.widgetWithText(TextButton, l10n.cancel),
          ),
        );
        await tester.pumpAndSettle();
      });

      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pumpAndSettle();
      expect(savedEvent?.title, 'Focus-safe draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recurrence end-date picker does not restore repeat-count input focus',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showAppModalSheet<void>(
                  context: context,
                  enableDrag: false,
                  builder: (_) => GeneralEventEditorSheet(
                    calendars: const [
                      GeneralSchedule(id: 'work', name: 'Work', events: []),
                    ],
                    activeCalendarId: 'work',
                  ),
                ),
                child: const Text('Open event editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open event editor'));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );
      final recurrenceField = find.byKey(
        const ValueKey('event-recurrence-field'),
      );
      await tester.ensureVisible(recurrenceField);
      await tester.tap(recurrenceField);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.recurrenceWeekly).last);
      await tester.pumpAndSettle();

      final repeatCountField = find.widgetWithText(
        TextFormField,
        l10n.recurrenceRepeatCount,
      );
      await tester.ensureVisible(repeatCountField);
      await tester.enterText(repeatCountField, '4');
      final previousFocus = await _focusTextFormField(tester, repeatCountField);

      final endDateButton = find.widgetWithText(
        FilledButton,
        l10n.recurrenceEndDate,
      );
      await tester.ensureVisible(endDateButton);
      await tester.tap(endDateButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.widgetWithText(TextButton, l10n.cancel),
        ),
      );
      await tester.pumpAndSettle();

      _expectInputFocusDismissed(tester, previousFocus);
      expect(find.widgetWithText(TextFormField, '4'), findsOneWidget);
      await tester.tap(_dialogTextButton(l10n.cancel));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recurrence end picker starts no earlier than event start', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Meeting',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.weekly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();
    final endDateButton = find.widgetWithText(FilledButton, 'End date');
    await tester.tap(endDateButton);
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, DateTime(2026, 5, 25));
  });

  testWidgets('keeps recurrence and reminder details behind compact fields', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(430, 776));
    addTearDown(() => _resetTestViewport(tester));
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.custom,
              interval: 2,
              unit: GeneralEventRecurrenceUnit.week,
              untilDateIso: '2026-06-30',
              count: 4,
            ),
            reminders: const [
              GeneralEventReminder(minutesBefore: 5),
              GeneralEventReminder(minutesBefore: 60),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    final reminderField = find.byKey(const ValueKey('event-reminder-field'));
    expect(tester.getSize(recurrenceField).height, greaterThanOrEqualTo(56));
    expect(tester.getSize(reminderField).height, greaterThanOrEqualTo(56));
    expect(
      find.textContaining(l10n.repeatsEvery(2, l10n.recurrenceWeeks)),
      findsOneWidget,
    );
    expect(find.textContaining(l10n.reminderHourBefore), findsOneWidget);
    expect(find.text(l10n.recurrenceRepeatCount), findsNothing);
    expect(find.byType(FilterChip), findsNothing);

    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.recurrenceRepeatCount), findsOneWidget);
    await tester.tap(_dialogTextButton(l10n.cancel));
    await tester.pumpAndSettle();

    await tester.ensureVisible(reminderField);
    await tester.tap(reminderField);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('recurrence dialog validates and applies one draft', (
    tester,
  ) async {
    GeneralEvent? savedEvent;
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
          ),
          onSave: (event) async => savedEvent = event,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurrenceWeekly).last);
    await tester.pumpAndSettle();
    final countField = find.widgetWithText(
      TextFormField,
      l10n.recurrenceRepeatCount,
    );
    await tester.enterText(countField, '0');
    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pump();
    expect(find.text(l10n.recurrencePositiveNumber), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(countField, '3');
    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining(l10n.repeatsWeekly), findsOneWidget);
    expect(find.textContaining(l10n.recurrenceCountTimes(3)), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, l10n.save));
    await tester.pumpAndSettle();
    expect(savedEvent?.recurrenceRule.type, GeneralEventRecurrence.weekly);
    expect(savedEvent?.recurrenceRule.count, 3);
  });

  testWidgets('compact recurrence dialog saves the complete custom draft', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));
    GeneralEvent? savedEvent;
    await tester.pumpWidget(
      _localizedCompactApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
          ),
          onSave: (event) async => savedEvent = event,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurrenceCustom).last);
    await tester.pumpAndSettle();

    final intervalStepper = find.byKey(
      const ValueKey('recurrence-interval-stepper'),
    );
    final intervalIncrement = find.byKey(
      const ValueKey('recurrence-interval-increment'),
    );
    await tester.ensureVisible(intervalStepper);
    await tester.tap(intervalIncrement);
    await tester.pump();
    await tester.tap(intervalIncrement);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('recurrence-interval-value')),
          )
          .controller
          ?.text,
      '3',
    );
    expect(find.byType(SkedDropdownMenu<int>), findsNothing);

    final unitMenu = find.byType(SkedDropdownMenu<GeneralEventRecurrenceUnit>);
    await tester.ensureVisible(unitMenu);
    await tester.tap(unitMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurrenceMonths).last);
    await tester.pumpAndSettle();

    final repeatCountField = find.widgetWithText(
      TextFormField,
      l10n.recurrenceRepeatCount,
    );
    await tester.ensureVisible(repeatCountField);
    await tester.enterText(repeatCountField, '5');

    final endDateButton = find.widgetWithText(
      FilledButton,
      l10n.recurrenceEndDate,
    );
    await tester.ensureVisible(endDateButton);
    await tester.tap(endDateButton);
    await tester.pumpAndSettle();
    final datePicker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    datePicker.onDateChanged(DateTime(2026, 8, 31));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.widgetWithText(TextButton, 'OK'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, l10n.save));
    await tester.tap(find.widgetWithText(FilledButton, l10n.save));
    await tester.pumpAndSettle();

    expect(savedEvent?.recurrenceRule.type, GeneralEventRecurrence.custom);
    expect(savedEvent?.recurrenceRule.interval, 3);
    expect(savedEvent?.recurrenceRule.unit, GeneralEventRecurrenceUnit.month);
    expect(savedEvent?.recurrenceRule.untilDateIso, '2026-08-31');
    expect(savedEvent?.recurrenceRule.count, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom recurrence interval enforces the model boundaries', (
    tester,
  ) async {
    GeneralEvent? savedEvent;
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.custom,
            ),
          ),
          onSave: (event) async => savedEvent = event,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();

    final decrement = find.byKey(
      const ValueKey('recurrence-interval-decrement'),
    );
    final valueField = find.byKey(const ValueKey('recurrence-interval-value'));
    final increment = find.byKey(
      const ValueKey('recurrence-interval-increment'),
    );
    expect(tester.widget<IconButton>(decrement).onPressed, isNull);

    await tester.enterText(valueField, '999');
    await tester.pump();
    expect(tester.widget<TextField>(valueField).controller?.text, '999');
    expect(tester.widget<IconButton>(increment).onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, l10n.save));
    await tester.tap(find.widgetWithText(FilledButton, l10n.save));
    await tester.pumpAndSettle();

    expect(savedEvent?.recurrenceRule.interval, 999);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom recurrence interval fits compact 2x text layouts', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));
    await tester.pumpWidget(
      _localizedCompactApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.custom,
              interval: 12,
            ),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();

    final stepper = find.byKey(const ValueKey('recurrence-interval-stepper'));
    final decrement = find.byKey(
      const ValueKey('recurrence-interval-decrement'),
    );
    final increment = find.byKey(
      const ValueKey('recurrence-interval-increment'),
    );
    await tester.ensureVisible(stepper);
    await tester.pumpAndSettle();

    final dialogRect = tester.getRect(_dialogSurface());
    final stepperRect = tester.getRect(stepper);
    expect(stepperRect.left, greaterThanOrEqualTo(dialogRect.left));
    expect(stepperRect.right, lessThanOrEqualTo(dialogRect.right));
    expect(tester.getSize(decrement).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(decrement).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(increment).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(increment).height, greaterThanOrEqualTo(48));
    expect(find.byType(SkedDropdownMenu<int>), findsNothing);
    expect(
      find.byType(SkedDropdownMenu<GeneralEventRecurrenceUnit>),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('recurrence dialog cancel and barrier keep the original draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.daily,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final field = find.byKey(const ValueKey('event-recurrence-field'));

    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurrenceMonthly).last);
    await tester.tap(_dialogTextButton(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.textContaining(l10n.repeatsDaily), findsOneWidget);

    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.recurrenceMonthly).last);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining(l10n.repeatsDaily), findsOneWidget);
  });

  testWidgets('reminder dialog applies sorted choices and supports none', (
    tester,
  ) async {
    GeneralEvent? savedEvent;
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
          initialEvent: GeneralEvent(
            id: 'event',
            calendarId: 'work',
            title: 'Planning',
            startDateTimeIso: '2026-05-25T09:00:00.000',
            endDateTimeIso: '2026-05-25T10:00:00.000',
            reminders: const [GeneralEventReminder(minutesBefore: 5)],
          ),
          onSave: (event) async => savedEvent = event,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );
    final field = find.byKey(const ValueKey('event-reminder-field'));

    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, l10n.reminderHourBefore));
    await tester.tap(
      find.widgetWithText(FilterChip, l10n.reminderMinutesBefore(5)),
    );
    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reminderHourBefore), findsOneWidget);

    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, l10n.none));
    await tester.tap(_dialogTextButton(l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text(l10n.reminderHourBefore), findsOneWidget);

    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, l10n.none));
    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n.none), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, l10n.save));
    await tester.pumpAndSettle();
    expect(savedEvent?.reminders, isEmpty);
  });

  testWidgets('rapid taps open only one selection dialog', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('event-recurrence-field'));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.tap(field, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recurrence dialog shrink-wraps short content', (tester) async {
    _setTestViewport(tester, const Size(484, 967));
    addTearDown(() => _resetTestViewport(tester));
    await tester.pumpWidget(
      _localizedZhApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    final compactHeight = tester.getSize(_dialogSurface()).height;
    expect(compactHeight, lessThan(600));

    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    await tester.tap(find.text(l10n.recurrenceMonthly).last);
    await tester.pumpAndSettle();

    final monthlyHeight = tester.getSize(_dialogSurface()).height;
    final endDateButton = find.widgetWithText(
      FilledButton,
      l10n.recurrenceEndDate,
    );
    final confirmButton = find.widgetWithText(FilledButton, l10n.confirm);
    expect(monthlyHeight, greaterThan(compactHeight));
    expect(monthlyHeight, lessThan(720));
    expect(
      tester.getRect(confirmButton).top - tester.getRect(endDateButton).bottom,
      lessThan(120),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection dialogs cap their surface width on wide screens', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(1120, 680));
    addTearDown(() => _resetTestViewport(tester));
    await tester.pumpWidget(
      _localizedApp(
        GeneralEventEditorSheet(
          calendars: const [
            GeneralSchedule(id: 'work', name: 'Work', events: []),
          ],
          activeCalendarId: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(GeneralEventEditorSheet)),
    );

    final recurrenceField = find.byKey(
      const ValueKey('event-recurrence-field'),
    );
    await tester.ensureVisible(recurrenceField);
    await tester.tap(recurrenceField);
    await tester.pumpAndSettle();
    expect(tester.getSize(_dialogSurface()).width, lessThanOrEqualTo(520));
    await tester.tap(_dialogTextButton(l10n.cancel));
    await tester.pumpAndSettle();

    final reminderField = find.byKey(const ValueKey('event-reminder-field'));
    await tester.ensureVisible(reminderField);
    await tester.tap(reminderField);
    await tester.pumpAndSettle();
    expect(tester.getSize(_dialogSurface()).width, lessThanOrEqualTo(520));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection dialogs fit compact scaled localized layouts', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));

    for (final locale in const [Locale('de')]) {
      await tester.pumpWidget(
        _localizedCompactApp(
          GeneralEventEditorSheet(
            calendars: const [
              GeneralSchedule(id: 'work', name: 'Work', events: []),
            ],
            activeCalendarId: 'work',
            initialEvent: GeneralEvent(
              id: 'event',
              calendarId: 'work',
              title: 'Planning',
              startDateTimeIso: '2026-05-25T09:00:00.000',
              endDateTimeIso: '2026-05-25T10:00:00.000',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.custom,
                interval: 2,
                unit: GeneralEventRecurrenceUnit.week,
                count: 4,
              ),
            ),
          ),
          locale: locale,
          textScaler: const TextScaler.linear(2),
          viewInsets: const EdgeInsets.only(bottom: 180),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );

      final recurrenceField = find.byKey(
        const ValueKey('event-recurrence-field'),
      );
      await tester.ensureVisible(recurrenceField);
      await tester.tap(recurrenceField);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final surface = _dialogSurface();
      expect(surface, findsOneWidget);
      final dialogRect = tester.getRect(surface);
      expect(dialogRect.left, greaterThanOrEqualTo(16));
      expect(dialogRect.right, lessThanOrEqualTo(304));
      expect(tester.takeException(), isNull);
      await tester.tap(_dialogTextButton(l10n.cancel));
      await tester.pumpAndSettle();

      final reminderField = find.byKey(const ValueKey('event-reminder-field'));
      await tester.ensureVisible(reminderField);
      await tester.tap(reminderField);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(_dialogTextButton(l10n.cancel));
      await tester.pumpAndSettle();
    }
  });
}
