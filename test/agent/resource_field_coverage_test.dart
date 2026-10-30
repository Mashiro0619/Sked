import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutation_schema.dart';
import 'package:sked/models/timetable_models.dart';

import '../application/resource_queries_test.dart' as samples;

void main() {
  void covers(
    ResourceKind kind,
    Map<String, dynamic> serialized,
    Map<String, String> hostOwned,
  ) {
    final editable = ResourceMutationSchema.fields(kind);
    expect(
      editable.intersection(hostOwned.keys.toSet()),
      isEmpty,
      reason: 'Host facts must not become writable fields.',
    );
    expect(
      serialized.keys.toSet(),
      {...editable, ...hostOwned.keys},
      reason:
          '${kind.name}: classify every new stored field and expose editable values through the shared schema.',
    );
    expect(hostOwned.values.every((reason) => reason.isNotEmpty), isTrue);
  }

  test('all resource fields are editable or have an explicit semantic owner', () {
    final fixture = samples.fixture();
    final table = fixture.studentMode.timetables.first;
    covers(ResourceKind.timetable, table.config.toJson(), {});
    expect(table.toJson().keys.toSet(), {'id', 'config', 'courses'});
    covers(
      ResourceKind.course,
      table.courses.first
          .copyWith(
            reminderSettings: const CourseReminderSettings(
              behavior: CourseReminderBehavior.custom,
              minutesBefore: 5,
            ),
          )
          .toJson(),
      {
        'id': 'The host allocates identity; explicit move/copy preserve or replace it.',
        'timeRange':
            'Derived from the explicit minute or period representation.',
      },
    );
    covers(
      ResourceKind.periodTimeSet,
      fixture.studentMode.periodTimeSets.first.toJson(),
      {
        'id':
            'The host allocates identity and validates references on deletion.',
      },
    );
    final calendar = fixture.generalMode.schedules.first;
    covers(ResourceKind.calendar, calendar.toJson(), {
      'id': 'The host allocates stable calendar identity.',
      'events':
          'Child event resource commands; not whole-list setting replacement.',
    });
    covers(
      ResourceKind.event,
      calendar.events.first
          .copyWith(
            colorValue: 0xff123456,
            createdAtIso: '2026-10-30T08:00:00.000Z',
            updatedAtIso: '2026-10-30T09:00:00.000Z',
          )
          .toJson(),
      {
        'id': 'The host allocates stable event identity.',
        'calendarId':
            'Explicit event move selects and validates the owning calendar.',
        'createdAt': 'Host creation timestamp.',
        'updatedAt': 'Host mutation timestamp.',
      },
    );
    expect(
      ResourceMutationSchema.fields(ResourceKind.occurrence),
      ResourceMutationSchema.fields(ResourceKind.event),
    );
  });

  test('nested period and reminder fields match their tool schemas', () {
    final periodSchema =
        ResourceMutationSchema.properties(
              ResourceKind.periodTimeSet,
            )['periodTimes']
            as Map;
    final periodFields = (periodSchema['items'] as Map)['properties'] as Map;
    expect(
      const CoursePeriodTime(
        index: 1,
        startMinutes: 480,
        endMinutes: 525,
      ).toJson().keys.toSet(),
      periodFields.keys.toSet(),
    );
    final courseReminder =
        ResourceMutationSchema.properties(
              ResourceKind.course,
            )['reminderSettings']
            as Map;
    expect(
      const CourseReminderSettings(
        behavior: CourseReminderBehavior.custom,
        minutesBefore: 5,
      ).toJson().keys.toSet(),
      (courseReminder['properties'] as Map).keys.toSet(),
    );
    final eventReminder =
        ResourceMutationSchema.properties(ResourceKind.event)['reminders']
            as Map;
    expect(
      const GeneralEventReminder(minutesBefore: 5).toJson().keys.toSet(),
      (((eventReminder['items'] as Map)['properties']) as Map).keys.toSet(),
    );
  });
}
