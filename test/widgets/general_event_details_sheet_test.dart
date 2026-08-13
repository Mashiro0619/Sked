import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

GeneralEventOccurrence _buildOccurrence({bool hasReminder = true}) {
  final event = GeneralEvent(
    id: 'event-1',
    calendarId: 'calendar-1',
    title: 'Planning',
    startDateTimeIso: '2026-05-25T09:00:00.000',
    endDateTimeIso: '2026-05-25T10:00:00.000',
    reminders: hasReminder
        ? const [GeneralEventReminder(minutesBefore: 10)]
        : const [],
  );
  final calendar = GeneralSchedule(
    id: 'calendar-1',
    name: 'Work',
    events: [event],
  );
  return GeneralEventOccurrence(
    event: event,
    calendar: calendar,
    start: DateTime(2026, 5, 25, 9),
    end: DateTime(2026, 5, 25, 10),
    sequence: 0,
  );
}

void main() {
  testWidgets('events without reminders do not expose reminder actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GeneralEventDetailsSheet(
            occurrence: _buildOccurrence(hasReminder: false),
            onDismissReminder: () {},
            onRestoreReminder: () {},
          ),
        ),
      ),
    );

    expect(find.text('Mark handled'), findsNothing);
    expect(find.text('Restore reminder'), findsNothing);
  });

  testWidgets('action buttons prioritize primary actions and group delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 460,
              child: GeneralEventDetailsSheet(
                occurrence: _buildOccurrence(),
                onEdit: () {},
                onDuplicate: () {},
                onDismissReminder: () {},
                onDeleteThis: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final edit = find.widgetWithText(FilledButton, 'Edit event');
    final duplicate = find.widgetWithText(FilledButton, 'Duplicate');
    final handled = find.widgetWithText(OutlinedButton, 'Mark handled');
    final delete = find.widgetWithText(OutlinedButton, 'Delete');

    final editRect = tester.getRect(edit);
    final duplicateRect = tester.getRect(duplicate);
    final handledRect = tester.getRect(handled);
    final deleteRect = tester.getRect(delete);

    expect(editRect.width, greaterThan(duplicateRect.width * 1.8));
    expect(deleteRect.width, closeTo(editRect.width, 0.1));
    expect(editRect.left, closeTo(deleteRect.left, 0.1));
    expect(duplicateRect.width, closeTo(handledRect.width, 0.1));
    expect(duplicateRect.top, closeTo(handledRect.top, 0.1));
    expect(editRect.top, lessThan(duplicateRect.top));
    expect(deleteRect.top, greaterThan(handledRect.top));
  });

  testWidgets('action buttons ignore rapid duplicate taps', (tester) async {
    final actionCompleter = Completer<void>();
    var duplicateCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GeneralEventDetailsSheet(
            occurrence: _buildOccurrence(),
            onDuplicate: () {
              duplicateCount += 1;
              return actionCompleter.future;
            },
          ),
        ),
      ),
    );

    final duplicateButton = find.widgetWithText(FilledButton, 'Duplicate');
    expect(duplicateButton, findsOneWidget);

    await tester.tap(duplicateButton);
    await tester.tap(duplicateButton, warnIfMissed: false);

    expect(duplicateCount, 1);

    await tester.pump();
    expect(tester.widget<FilledButton>(duplicateButton).onPressed, isNull);

    actionCompleter.complete();
    await tester.pump();

    expect(duplicateCount, 1);
  });

  testWidgets('failed action reports the error and can be retried', (
    tester,
  ) async {
    var duplicateCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GeneralEventDetailsSheet(
            occurrence: _buildOccurrence(),
            onDuplicate: () {
              duplicateCount += 1;
              throw StateError('duplicate failed');
            },
          ),
        ),
      ),
    );

    final duplicateButton = find.widgetWithText(FilledButton, 'Duplicate');
    await tester.tap(duplicateButton);
    await tester.pumpAndSettle();

    expect(duplicateCount, 1);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.widget<FilledButton>(duplicateButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(duplicateButton);
    await tester.pumpAndSettle();

    expect(duplicateCount, 2);
    expect(tester.widget<FilledButton>(duplicateButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
