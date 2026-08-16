import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

GeneralEventOccurrence _buildOccurrence({
  bool hasReminder = true,
  bool repeating = false,
  int sequence = 0,
  String title = 'Planning',
}) {
  final event = GeneralEvent(
    id: 'event-1',
    calendarId: 'calendar-1',
    title: title,
    startDateTimeIso: '2026-05-25T09:00:00.000',
    endDateTimeIso: '2026-05-25T10:00:00.000',
    recurrenceRule: repeating
        ? const GeneralEventRecurrenceRule(type: GeneralEventRecurrence.weekly)
        : const GeneralEventRecurrenceRule(),
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
    sequence: sequence,
  );
}

Future<void> _pumpDetails(
  WidgetTester tester, {
  required GeneralEventOccurrence occurrence,
  FutureOr<void> Function()? onEdit,
  FutureOr<void> Function()? onDuplicate,
  bool isReminderHandled = false,
  FutureOr<void> Function()? onDismissReminder,
  FutureOr<void> Function()? onRestoreReminder,
  FutureOr<void> Function()? onDeleteThis,
  FutureOr<void> Function()? onDeleteFuture,
  FutureOr<void> Function()? onDeleteAll,
  double width = 430,
  double height = 776,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: GeneralEventDetailsSheet(
          occurrence: occurrence,
          onEdit: onEdit,
          onDuplicate: onDuplicate,
          isReminderHandled: isReminderHandled,
          onDismissReminder: onDismissReminder,
          onRestoreReminder: onRestoreReminder,
          onDeleteThis: onDeleteThis,
          onDeleteFuture: onDeleteFuture,
          onDeleteAll: onDeleteAll,
        ),
      ),
    ),
  );
}

Finder _iconButtonInside(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(IconButton),
  );
}

Future<void> _pumpDialogTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('events without reminders do not expose reminder actions', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(hasReminder: false),
      onDismissReminder: () {},
      onRestoreReminder: () {},
    );

    expect(
      find.byKey(const ValueKey('general-event-reminder-action')),
      findsNothing,
    );
    expect(find.text('Mark handled'), findsNothing);
    expect(find.text('Restore in-app reminder'), findsNothing);
  });

  testWidgets('compact actions stay inline and touchable at 320dp and 2x', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      width: 320,
      height: 568,
      textScale: 2,
      occurrence: _buildOccurrence(
        title: 'Planning a long localized event title',
      ),
      onEdit: () {},
      onDuplicate: () {},
      onDismissReminder: () {},
      onDeleteThis: () {},
    );

    const keys = [
      ValueKey('general-event-edit-action'),
      ValueKey('general-event-duplicate-action'),
      ValueKey('general-event-reminder-action'),
      ValueKey('general-event-delete-action'),
    ];
    for (final key in keys) {
      expect(tester.getSize(find.byKey(key)), const Size.square(48));
    }

    final duplicateRect = tester.getRect(find.byKey(keys[1]));
    final reminderRect = tester.getRect(find.byKey(keys[2]));
    final deleteRect = tester.getRect(find.byKey(keys[3]));
    expect(duplicateRect.top, closeTo(reminderRect.top, 0.1));
    expect(reminderRect.top, closeTo(deleteRect.top, 0.1));
    expect(
      tester.getSize(find.byKey(const ValueKey('general-event-action-bar'))),
      const Size(144, 48),
    );
    expect(find.widgetWithText(FilledButton, 'Edit event'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Duplicate'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action buttons ignore rapid duplicate taps', (tester) async {
    final actionCompleter = Completer<void>();
    var duplicateCount = 0;

    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(),
      onDuplicate: () {
        duplicateCount += 1;
        return actionCompleter.future;
      },
    );

    const key = ValueKey('general-event-duplicate-action');
    await tester.tap(find.byKey(key));
    await tester.tap(find.byKey(key), warnIfMissed: false);

    expect(duplicateCount, 1);
    await tester.pump();
    expect(tester.widget<IconButton>(_iconButtonInside(key)).onPressed, isNull);

    actionCompleter.complete();
    await tester.pump();
    expect(duplicateCount, 1);
  });

  testWidgets('ordinary delete confirms and waits for dialog exit', (
    tester,
  ) async {
    var deleteCount = 0;
    var dialogMountedDuringCallback = true;

    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(),
      onDeleteThis: () {
        deleteCount += 1;
        dialogMountedDuringCallback = find
            .byKey(const ValueKey('general-event-delete-dialog'))
            .evaluate()
            .isNotEmpty;
      },
    );

    const deleteKey = ValueKey('general-event-delete-action');
    await tester.tap(find.byKey(deleteKey));
    await _pumpDialogTransition(tester);
    expect(
      find.byKey(const ValueKey('general-event-delete-dialog')),
      findsOneWidget,
    );
    expect(deleteCount, 0);

    await tester.tap(find.text('Cancel'));
    await _pumpDialogTransition(tester);
    expect(deleteCount, 0);
    expect(
      tester.widget<IconButton>(_iconButtonInside(deleteKey)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(deleteKey));
    await _pumpDialogTransition(tester);
    await tester.tap(
      find.byKey(const ValueKey('general-event-confirm-delete')),
    );
    await _pumpDialogTransition(tester);

    expect(deleteCount, 1);
    expect(dialogMountedDuringCallback, isFalse);
  });

  testWidgets('recurring delete chooses one scope after dialog exit', (
    tester,
  ) async {
    var thisCount = 0;
    var followingCount = 0;
    var allCount = 0;
    var dialogMountedDuringCallback = true;

    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(repeating: true, sequence: 2),
      onDeleteThis: () => thisCount += 1,
      onDeleteFuture: () {
        followingCount += 1;
        dialogMountedDuringCallback = find
            .byKey(const ValueKey('general-event-delete-scope-dialog'))
            .evaluate()
            .isNotEmpty;
      },
      onDeleteAll: () => allCount += 1,
    );

    await tester.tap(find.byKey(const ValueKey('general-event-delete-action')));
    await _pumpDialogTransition(tester);
    expect(
      find.byKey(const ValueKey('general-event-delete-this')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('general-event-delete-this-and-following')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('general-event-delete-entire-series')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('general-event-delete-this-and-following')),
    );
    await _pumpDialogTransition(tester);

    expect(thisCount, 0);
    expect(followingCount, 1);
    expect(allCount, 0);
    expect(dialogMountedDuringCallback, isFalse);
  });

  testWidgets('delete scope ignores rapid duplicate selections', (
    tester,
  ) async {
    var deleteCount = 0;

    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(repeating: true, sequence: 2),
      onDeleteThis: () => deleteCount += 1,
      onDeleteFuture: () {},
      onDeleteAll: () {},
    );

    await tester.tap(find.byKey(const ValueKey('general-event-delete-action')));
    await _pumpDialogTransition(tester);
    final option = find.byKey(const ValueKey('general-event-delete-this'));
    await tester.tap(option);
    await tester.tap(option, warnIfMissed: false);
    await _pumpDialogTransition(tester);

    expect(deleteCount, 1);
    expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first recurring occurrence omits duplicate future scope', (
    tester,
  ) async {
    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(repeating: true),
      onDeleteThis: () {},
      onDeleteFuture: () {},
      onDeleteAll: () {},
    );

    await tester.tap(find.byKey(const ValueKey('general-event-delete-action')));
    await _pumpDialogTransition(tester);

    expect(
      find.byKey(const ValueKey('general-event-delete-this')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('general-event-delete-this-and-following')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('general-event-delete-entire-series')),
      findsOneWidget,
    );
  });

  testWidgets('failed delete reports the error and can be retried', (
    tester,
  ) async {
    var deleteCount = 0;

    await _pumpDetails(
      tester,
      occurrence: _buildOccurrence(),
      onDeleteThis: () {
        deleteCount += 1;
        throw StateError('delete failed');
      },
    );

    const deleteKey = ValueKey('general-event-delete-action');
    Future<void> attemptDelete() async {
      await tester.tap(find.byKey(deleteKey));
      await _pumpDialogTransition(tester);
      await tester.tap(
        find.byKey(const ValueKey('general-event-confirm-delete')),
      );
      await _pumpDialogTransition(tester);
    }

    await attemptDelete();
    expect(deleteCount, 1);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester.widget<IconButton>(_iconButtonInside(deleteKey)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);

    await attemptDelete();
    expect(deleteCount, 2);
    expect(
      tester.widget<IconButton>(_iconButtonInside(deleteKey)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
