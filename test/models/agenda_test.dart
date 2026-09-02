import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/agenda.dart';

void main() {
  group('Agenda contracts', () {
    test(
      'normalizes occurrences into an immutable effective representation',
      () {
        final start = DateTime(2026, 8, 3, 8);
        final occurrence = AgendaOccurrence(
          stableId: '  exam-1  ',
          sourceType: '  exam  ',
          start: start,
          end: start,
          title: '  Final exam  ',
          location: '  Hall A  ',
          target: const AgendaTarget(sourceType: 'exam'),
          reminders: const [
            AgendaReminder(minutesBefore: 15),
            AgendaReminder(minutesBefore: -3),
            AgendaReminder(minutesBefore: 15),
          ],
          metadata: const {'kind': 'final'},
        );

        final normalized = occurrence.normalized();

        expect(normalized.stableId, 'exam-1');
        expect(normalized.sourceType, 'exam');
        expect(normalized.title, 'Final exam');
        expect(normalized.location, 'Hall A');
        expect(normalized.end, start.add(const Duration(minutes: 1)));
        expect(normalized.reminders, const [
          AgendaReminder(minutesBefore: 0),
          AgendaReminder(minutesBefore: 15),
        ]);
        expect(normalized.metadata, const {'kind': 'final'});
        expect(
          () =>
              normalized.reminders.add(const AgendaReminder(minutesBefore: 5)),
          throwsUnsupportedError,
        );
        expect(
          () => normalized.metadata['source'] = 'manual',
          throwsUnsupportedError,
        );
      },
    );

    test(
      'target copies nullable fields explicitly and serializes only values',
      () {
        const target = AgendaTarget(
          sourceType: AgendaSourceType.course,
          timetableId: 'table',
          courseId: 'course',
          dateIso: '2026-08-03',
        );

        final cleared = target.copyWith(courseId: null, dateIso: null);

        expect(cleared.sourceType, AgendaSourceType.course);
        expect(cleared.timetableId, 'table');
        expect(cleared.courseId, isNull);
        expect(cleared.dateIso, isNull);
        expect(cleared.toJson(), {
          'sourceType': AgendaSourceType.course,
          'timetableId': 'table',
        });
      },
    );

    test(
      'reminders calculate their fire time and normalize negative offsets',
      () {
        final start = DateTime(2026, 8, 3, 8);
        const reminder = AgendaReminder(minutesBefore: -5);

        expect(reminder.normalized(), const AgendaReminder(minutesBefore: 0));
        expect(
          const AgendaReminder(minutesBefore: 10).fireAt(start),
          DateTime(2026, 8, 3, 7, 50),
        );
      },
    );
  });
}
