import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/resource_queries.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_projection_service.dart';

Matcher queryProblem(ResourceQueryErrorCode code) =>
    isA<ResourceQueryException>().having((error) => error.code, 'code', code);

void main() {
  test(
    'queries every owner without changing selection, visibility or data',
    () {
      final snapshot = fixture();
      final before = jsonEncode(snapshot.toJson());
      final reader = queries(snapshot);

      expect(ids(reader.query(ResourceQuery(kind: ResourceKind.timetable))), [
        'table-a',
        'table-b',
      ]);
      expect(ids(reader.query(ResourceQuery(kind: ResourceKind.course))), [
        'course-a',
        'course-b',
      ]);
      expect(
        ids(reader.query(ResourceQuery(kind: ResourceKind.periodTimeSet))),
        ['periods'],
      );
      expect(ids(reader.query(ResourceQuery(kind: ResourceKind.calendar))), [
        'calendar-a',
        'calendar-b',
      ]);
      final events = reader.query(ResourceQuery(kind: ResourceKind.event));
      expect(ids(events), ['event-a', 'event-b']);
      expect(
        events.items.map((item) => item.values['workspaceEnabled']),
        everyElement(false),
      );
      expect(
        reader
            .query(
              ResourceQuery(kind: ResourceKind.event, includeDisabled: false),
            )
            .totalMatches,
        0,
      );
      expect(
        ids(
          reader.query(
            ResourceQuery(kind: ResourceKind.event, includeHidden: false),
          ),
        ),
        ['event-a'],
      );
      expect(
        ids(
          reader.query(
            ResourceQuery(kind: ResourceKind.calendar, includeHidden: false),
          ),
        ),
        ['calendar-a'],
      );
      expect(jsonEncode(snapshot.toJson()), before);
      expect(snapshot.activeMode, AppMode.student);
      expect(snapshot.studentMode.activeTimetableId, 'table-a');
      expect(snapshot.generalMode.activeScheduleId, 'calendar-a');
      expect(snapshot.generalMode.schedules.last.isVisible, isFalse);
    },
  );

  test('disabled student resources remain readable and can be excluded', () {
    final reader = queries(fixture(enabled: {AppMode.general}));
    for (final kind in [
      ResourceKind.timetable,
      ResourceKind.course,
      ResourceKind.periodTimeSet,
    ]) {
      expect(reader.query(ResourceQuery(kind: kind)).items, isNotEmpty);
      expect(
        reader.query(ResourceQuery(kind: kind, includeDisabled: false)).items,
        isEmpty,
      );
    }
  });

  test(
    'scoped identity is independent of duplicate names and active owner',
    () {
      final reader = queries(
        fixture(
          tables: [
            table('table-a', [course('same')]),
            table('table-b', [course('same', teacher: 'Second teacher')]),
          ],
        ),
      );
      final record = reader.get(
        const ResourceRef(
          kind: ResourceKind.course,
          id: 'same',
          parentId: 'table-b',
        ),
      );
      expect(record.values['teacher'], 'Second teacher');
      expect(record.ref.parentId, 'table-b');
      expect(
        () => reader.get(
          const ResourceRef(
            kind: ResourceKind.course,
            id: 'same',
            parentId: 'missing',
          ),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.notFound)),
      );
      expect(
        () => reader.get(
          const ResourceRef(kind: ResourceKind.course, id: 'same'),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.invalidArgument)),
      );
      expect(
        () => reader.get(
          const ResourceRef(
            kind: ResourceKind.timetable,
            id: 'table-a',
            parentId: 'table-b',
          ),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.invalidArgument)),
      );
    },
  );

  test('duplicate identities in a raw snapshot fail precise lookup', () {
    final reader = queries(
      fixture(
        tables: [
          table('table-a', [course('same'), course('same')]),
        ],
      ),
    );
    expect(
      () => reader.get(
        const ResourceRef(
          kind: ResourceKind.course,
          id: 'same',
          parentId: 'table-a',
        ),
      ),
      throwsA(queryProblem(ResourceQueryErrorCode.invalidSnapshot)),
    );
  });

  test(
    'summaries omit children and editable fields preserve stored values',
    () {
      final reader = queries(fixture());
      final summary = reader.get(
        const ResourceRef(
          kind: ResourceKind.course,
          id: 'course-a',
          parentId: 'table-a',
        ),
        view: ResourceView.summary,
      );
      expect(summary.values['effectiveTime'], {
        'source': 'periods',
        'startMinutes': 480,
        'endMinutes': 525,
      });
      expect(summary.values, isNot(contains('remarks')));
      final edit = reader.get(summary.ref, view: ResourceView.edit);
      expect(edit.values['startMinutes'], 0);
      expect(edit.values['endMinutes'], 0);
      expect(edit.values['periods'], [1]);
      expect(edit.values['semesterWeeks'], [1, 3]);
      expect(edit.values, isNot(contains('effectiveTime')));
      expect(edit.values, isNot(contains('timeRange')));
      final tableSummary = reader.get(
        const ResourceRef(kind: ResourceKind.timetable, id: 'table-b'),
        view: ResourceView.summary,
      );
      expect(tableSummary.values['courseCount'], 1);
      expect(tableSummary.values, isNot(contains('courses')));
      final periods = reader.get(
        const ResourceRef(kind: ResourceKind.periodTimeSet, id: 'periods'),
      );
      expect(periods.values['timetableCount'], 2);
      expect(periods.values['periodTimes'], [
        {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
      ]);
    },
  );

  test(
    'every view is an explicit projection without app or connection data',
    () {
      final reader = queries(fixture());
      for (final kind in ResourceKind.values) {
        for (final view in ResourceView.values) {
          final page = reader.query(
            ResourceQuery(
              kind: kind,
              view: view,
              startInclusive: kind == ResourceKind.occurrence
                  ? DateTime(2026, 10, 5)
                  : null,
              endExclusive: kind == ResourceKind.occurrence
                  ? DateTime(2026, 10, 6)
                  : null,
            ),
          );
          expect(page.items, isNotEmpty, reason: '$kind/$view');
          for (final item in page.items) {
            expect(
              item.includedFields.toSet(),
              ResourceQueries.fieldsFor(kind, view),
            );
          }
          final encoded = jsonEncode(page.toJson());
          expect(encoded, isNot(contains('runtime-secret')));
          expect(encoded, isNot(contains('customBaseUrl')));
          expect(encoded, isNot(contains('private.example')));
          expect(encoded, isNot(contains('aiApiSettings')));
          expect(encoded, isNot(contains('customApiKey')));
        }
      }
      final edit = reader.get(
        const ResourceRef(
          kind: ResourceKind.event,
          id: 'event-a',
          parentId: 'calendar-a',
        ),
        view: ResourceView.edit,
      );
      expect(edit.values, isNot(contains('createdAt')));
      expect(edit.values, isNot(contains('updatedAt')));
    },
  );

  test('field selection distinguishes omitted, null, empty and ref-only', () {
    final reader = queries(fixture());
    const ref = ResourceRef(
      kind: ResourceKind.event,
      id: 'event-a',
      parentId: 'calendar-a',
    );
    final record = reader.get(
      ref,
      fields: {'colorValue', 'createdAt', 'notes', 'reminders'},
    );
    expect(record.values, {
      'colorValue': null,
      'createdAt': null,
      'notes': '',
      'reminders': [],
    });
    expect(record.values, isNot(contains('title')));
    expect(reader.get(ref, fields: {}).values, isEmpty);
    expect(reader.get(ref, fields: {}).ref, ref);
    expect(
      () => reader.get(ref, fields: {'customApiKey'}),
      throwsA(queryProblem(ResourceQueryErrorCode.invalidField)),
    );
  });

  test('query filters and nested returned values own immutable copies', () {
    final selected = <String>{'course-a'};
    final fields = <String>{'customFields', 'semesterWeeks'};
    final request = ResourceQuery(
      kind: ResourceKind.course,
      ids: selected,
      fields: fields,
    );
    selected.add('course-b');
    fields.clear();
    final sourceValues = <String, dynamic>{
      'nested': <dynamic>[
        {'value': 'original'},
      ],
    };
    final reader = queries(
      fixture(
        tables: [
          table('table-a', [
            course('course-a', customFields: sourceValues),
            course('course-b'),
          ]),
        ],
      ),
    );
    final page = reader.query(request);
    expect(ids(page), ['course-a']);
    final values = page.items.single.values['customFields'] as Map;
    final nested = values['nested'] as List;
    expect(() => values['new'] = true, throwsUnsupportedError);
    expect(() => nested.add('new'), throwsUnsupportedError);
    expect(
      () => (nested.single as Map)['value'] = 'changed',
      throwsUnsupportedError,
    );
    expect(() => page.items.clear(), throwsUnsupportedError);
    (sourceValues['nested'] as List).clear();
    expect(nested, [
      {'value': 'original'},
    ]);
  });

  test('parent, source and search filters apply before event expansion', () {
    final expanded = <String>[];
    final snapshot = fixture(
      calendars: [
        calendar('calendar-a', [
          event('unrelated'),
          event('matching', title: 'Needle'),
        ]),
        calendar('calendar-b', [event('other', title: 'Needle')]),
      ],
    );
    final reader = queries(
      snapshot,
      expandEvent:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            expanded.add('${calendar.id}/${event.id}');
            return expandGeneralEventOccurrences(
              calendar: calendar,
              event: event,
              startInclusive: startInclusive,
              endExclusive: endExclusive,
            );
          },
    );
    final page = reader.query(
      occurrenceQuery(
        parentIds: {'calendar-a'},
        sourceIds: {'matching', 'unrelated'},
        source: OccurrenceSource.event,
        search: '  NEEDLE ',
      ),
    );
    expect(page.totalMatches, 1);
    expect(expanded, ['calendar-a/matching']);
    expanded.clear();
    expect(
      reader
          .query(occurrenceQuery(sourceIds: {}, source: OccurrenceSource.event))
          .items,
      isEmpty,
    );
    expect(expanded, isEmpty);
  });

  test('indexed snapshots find event IDs in non-active hidden owners', () {
    final snapshot = fixture();
    final reader = queries(fixture(general: snapshot.generalMode.normalized()));
    final page = reader.query(
      ResourceQuery(kind: ResourceKind.event, ids: {'event-b'}),
    );
    expect(page.items.single.ref.parentId, 'calendar-b');
    expect(page.items.single.values['calendarVisible'], false);
    expect(
      reader
          .query(
            ResourceQuery(
              kind: ResourceKind.event,
              ids: {'event-b'},
              parentIds: {'calendar-a'},
            ),
          )
          .items,
      isEmpty,
    );
  });

  test('exact occurrence get only expands its canonical source and parent', () {
    final expanded = <String>[];
    final reader = queries(
      fixture(),
      expandEvent:
          ({
            required calendar,
            required event,
            required startInclusive,
            required endExclusive,
          }) {
            expanded.add(event.id);
            return expandGeneralEventOccurrences(
              calendar: calendar,
              event: event,
              startInclusive: startInclusive,
              endExclusive: endExclusive,
            );
          },
    );
    final ref = ResourceRef(
      kind: ResourceKind.occurrence,
      id: buildGeneralOccurrenceKey(
        'calendar-b',
        'event-b',
        DateTime(2026, 10, 5, 9).toIso8601String(),
      ),
      parentId: 'calendar-b',
    );
    final found = reader.get(
      ref,
      startInclusive: DateTime(2026, 10, 5),
      endExclusive: DateTime(2026, 10, 6),
    );
    expect(found.ref, ref);
    expect(expanded, ['event-b']);
    expanded.clear();
    expect(
      () => reader.get(
        ResourceRef(kind: ref.kind, id: ref.id, parentId: 'calendar-a'),
        startInclusive: DateTime(2026, 10, 5),
        endExclusive: DateTime(2026, 10, 6),
      ),
      throwsA(queryProblem(ResourceQueryErrorCode.notFound)),
    );
    expect(expanded, isEmpty);
    expect(
      () => reader.get(ref),
      throwsA(queryProblem(ResourceQueryErrorCode.invalidArgument)),
    );
  });

  test(
    'course occurrence identity handles encoded IDs without enabling a domain',
    () {
      final reader = queries(
        fixture(
          enabled: {AppMode.general},
          tables: [
            table('table | %', [course('course | %')]),
          ],
        ),
        expandEvent: ({
          required calendar,
          required event,
          required startInclusive,
          required endExclusive,
        }) => throw StateError('wrong domain'),
      );
      final ref = ResourceRef(
        kind: ResourceKind.occurrence,
        id: buildCourseAgendaId('table | %', 'course | %', '2026-10-05'),
        parentId: 'table | %',
      );
      final result = reader.get(
        ref,
        startInclusive: DateTime(2026, 10, 5),
        endExclusive: DateTime(2026, 10, 6),
      );
      expect(result.values['week'], 1);
      expect(result.values['workspaceEnabled'], false);
      expect(
        result.values['start'],
        DateTime(2026, 10, 5, 8).toIso8601String(),
      );
    },
  );

  test('course instances respect semester, weeks and period fallback', () {
    final reader = queries(
      fixture(
        tables: [
          table('table-a', [course('course-a')]),
        ],
      ),
    );
    final page = reader.query(
      ResourceQuery(
        kind: ResourceKind.occurrence,
        occurrenceSource: OccurrenceSource.course,
        view: ResourceView.detail,
        startInclusive: DateTime(2026, 9, 28),
        endExclusive: DateTime(2026, 11, 9),
      ),
    );
    expect(page.items.map((item) => item.values['start']), [
      DateTime(2026, 10, 5, 8).toIso8601String(),
      DateTime(2026, 10, 19, 8).toIso8601String(),
    ]);
    expect(page.items.map((item) => item.values['week']), [1, 3]);
    expect(page.items.first.values['reminders'], [
      {'minutesBefore': 5},
    ]);
    expect(
      reader
          .query(
            ResourceQuery(
              kind: ResourceKind.occurrence,
              occurrenceSource: OccurrenceSource.course,
              startInclusive: DateTime(2026, 11, 2),
              endExclusive: DateTime(2026, 11, 9),
            ),
          )
          .items,
      isEmpty,
    );
  });

  test(
    'explicit course time wins and legacy empty weeks repeat every week',
    () {
      final reader = queries(
        fixture(
          tables: [
            table('table-a', [
              course('explicit', weeks: [], start: 600, end: 645),
              course('unresolved', periods: []),
            ]),
          ],
        ),
      );
      final page = reader.query(
        ResourceQuery(
          kind: ResourceKind.occurrence,
          occurrenceSource: OccurrenceSource.course,
          startInclusive: DateTime(2026, 10, 5),
          endExclusive: DateTime(2026, 11, 2),
        ),
      );
      expect(page.items, hasLength(4));
      expect(
        page.items.map(
          (item) => DateTime.parse(item.values['start'] as String).hour,
        ),
        everyElement(10),
      );
      final unresolved = reader.get(
        const ResourceRef(
          kind: ResourceKind.course,
          id: 'unresolved',
          parentId: 'table-a',
        ),
        fields: {'effectiveTime'},
      );
      expect(unresolved.values['effectiveTime'], {
        'source': 'unresolved',
        'startMinutes': null,
        'endMinutes': null,
      });
    },
  );

  test(
    'event recurrence preserves exclusions, sequence and inherited reminders',
    () {
      final reader = queries(
        fixture(
          calendars: [
            calendar('calendar-a', [
              event(
                'weekly',
                recurrenceRule: const GeneralEventRecurrenceRule(
                  type: GeneralEventRecurrence.weekly,
                  count: 3,
                ),
                exceptions: ['2026-10-12'],
                reminderBehavior: GeneralEventReminderBehavior.inherit,
              ),
            ]),
          ],
        ),
      );
      final page = reader.query(
        ResourceQuery(
          kind: ResourceKind.occurrence,
          occurrenceSource: OccurrenceSource.event,
          view: ResourceView.detail,
          startInclusive: DateTime(2026, 10, 1),
          endExclusive: DateTime(2026, 11, 1),
        ),
      );
      expect(page.items.map((item) => item.values['sequence']), [0, 2]);
      expect(page.items.map((item) => item.values['start']), [
        DateTime(2026, 10, 5, 9).toIso8601String(),
        DateTime(2026, 10, 19, 9).toIso8601String(),
      ]);
      expect(page.items.first.values['reminders'], [
        {'minutesBefore': 10},
      ]);
      expect(page.items.first.values['workspaceEnabled'], false);
    },
  );

  test('overlap queries retain all-day dates and UTC instance time basis', () {
    final reader = queries(
      fixture(
        calendars: [
          calendar('calendar-a', [
            event(
              'all-day',
              start: '2026-10-05T00:00:00.000',
              end: '2026-10-07T00:00:00.000',
              allDay: true,
            ),
            event(
              'utc',
              start: '2026-10-06T09:00:00.000Z',
              end: '2026-10-06T10:00:00.000Z',
            ),
          ]),
        ],
      ),
    );
    final page = reader.query(
      ResourceQuery(
        kind: ResourceKind.occurrence,
        occurrenceSource: OccurrenceSource.event,
        startInclusive: DateTime(2026, 10, 6),
        endExclusive: DateTime(2026, 10, 7),
      ),
    );
    final allDay = page.items.firstWhere(
      (item) => item.values['isAllDay'] == true,
    );
    expect(allDay.values['start'], '2026-10-05T00:00:00.000');
    expect(allDay.values['end'], '2026-10-07T00:00:00.000');
    final utc = page.items.firstWhere(
      (item) => item.values['isAllDay'] == false,
    );
    expect(utc.values['start'], '2026-10-06T09:00:00.000Z');
    expect(
      reader
          .query(
            ResourceQuery(
              kind: ResourceKind.occurrence,
              sourceIds: {'utc'},
              occurrenceSource: OccurrenceSource.event,
              startInclusive: DateTime.utc(2026, 10, 6, 10),
              endExclusive: DateTime.utc(2026, 10, 6, 11),
            ),
          )
          .items,
      isEmpty,
    );
  });

  test(
    'cursors page stable IDs without gaps and accept equivalent filters',
    () {
      final reader = queries(
        fixture(
          tables: [
            table('table-a', [course('c'), course('a'), course('b')]),
          ],
        ),
      );
      var page = reader.query(
        ResourceQuery(
          kind: ResourceKind.course,
          ids: {'c', 'a', 'b'},
          search: '  SAME ',
          fields: {'teacher', 'name'},
          limit: 1,
        ),
      );
      final found = ids(page);
      while (page.hasMore) {
        page = reader.query(
          ResourceQuery(
            kind: ResourceKind.course,
            ids: {'b', 'a', 'c'},
            search: 'same',
            fields: {'name', 'teacher'},
            limit: 1,
            cursor: page.nextCursor,
          ),
        );
        found.addAll(ids(page));
        expect(page.totalMatches, 3);
      }
      expect(found, ['a', 'b', 'c']);
      expect(page.nextCursor, isNull);
    },
  );

  test(
    'snapshot changes invalidate continuation independently of the query',
    () {
      final snapshot = fixture();
      final first = queries(snapshot)
          .query(ResourceQuery(kind: ResourceKind.course, limit: 1));
      for (final reader in [
        queries(snapshot, generation: 'restored'),
        queries(snapshot, revision: 8),
      ]) {
        expect(
          () => reader.query(
            ResourceQuery(
              kind: ResourceKind.course,
              limit: 1,
              cursor: first.nextCursor,
            ),
          ),
          throwsA(queryProblem(ResourceQueryErrorCode.staleCursor)),
        );
      }
    },
  );

  test(
    'changed projection, bounds, scope and page size cannot reuse a cursor',
    () {
      final reader = queries(fixture());
      final token = reader
          .query(ResourceQuery(kind: ResourceKind.course, limit: 1))
          .nextCursor;
      final changed = [
        ResourceQuery(kind: ResourceKind.course, limit: 2, cursor: token),
        ResourceQuery(
          kind: ResourceKind.course,
          limit: 1,
          fields: {'name'},
          cursor: token,
        ),
        ResourceQuery(
          kind: ResourceKind.course,
          limit: 1,
          includeDisabled: false,
          cursor: token,
        ),
        ResourceQuery(
          kind: ResourceKind.course,
          limit: 1,
          parentIds: {'table-a'},
          cursor: token,
        ),
        ResourceQuery(
          kind: ResourceKind.course,
          limit: 1,
          view: ResourceView.edit,
          cursor: token,
        ),
      ];
      for (final request in changed) {
        expect(
          () => reader.query(request),
          throwsA(queryProblem(ResourceQueryErrorCode.cursorQueryMismatch)),
        );
      }
      final occurrenceToken = reader
          .query(occurrenceQuery(limit: 1))
          .nextCursor;
      expect(
        () => reader.query(
          ResourceQuery(
            kind: ResourceKind.occurrence,
            startInclusive: DateTime(2026, 10, 5),
            endExclusive: DateTime(2026, 10, 7),
            limit: 1,
            cursor: occurrenceToken,
          ),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.cursorQueryMismatch)),
      );
    },
  );

  test('malformed and exhausted cursor offsets are rejected', () {
    final reader = queries(fixture());
    for (final token in [
      'not-base64',
      '',
      base64Url.encode(utf8.encode('{}')),
    ]) {
      expect(
        () => reader.query(
          ResourceQuery(kind: ResourceKind.course, cursor: token),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.invalidCursor)),
      );
    }
    final token = reader
        .query(ResourceQuery(kind: ResourceKind.course, limit: 1))
        .nextCursor!;
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(token)),
    ) as Map<String, dynamic>;
    for (final offset in [0, -1, 2, 500]) {
      decoded['offset'] = offset;
      final altered = base64Url.encode(utf8.encode(jsonEncode(decoded)));
      expect(
        () => reader.query(
          ResourceQuery(kind: ResourceKind.course, limit: 1, cursor: altered),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.invalidCursor)),
      );
    }
  });

  test(
    'queries reject unbounded dates, invalid filters and unknown fields',
    () {
      final reader = queries(fixture());
      final invalid = [
        ResourceQuery(kind: ResourceKind.course, limit: 0),
        ResourceQuery(kind: ResourceKind.course, limit: 101),
        ResourceQuery(kind: ResourceKind.course, ids: {''}),
        ResourceQuery(kind: ResourceKind.course, ids: {'x' * 2049}),
        ResourceQuery(
          kind: ResourceKind.course,
          ids: {for (var i = 0; i < 513; i++) '$i'},
        ),
        ResourceQuery(kind: ResourceKind.course, search: 'x' * 513),
        ResourceQuery(kind: ResourceKind.timetable, parentIds: {'table-a'}),
        ResourceQuery(kind: ResourceKind.course, sourceIds: {'course-a'}),
        ResourceQuery(
          kind: ResourceKind.course,
          startInclusive: DateTime(2026),
        ),
        ResourceQuery(kind: ResourceKind.occurrence),
        ResourceQuery(
          kind: ResourceKind.occurrence,
          startInclusive: DateTime(2026),
          endExclusive: DateTime(2026),
        ),
        ResourceQuery(
          kind: ResourceKind.occurrence,
          startInclusive: DateTime(2026),
          endExclusive: DateTime(2027, 1, 3),
        ),
        ResourceQuery(
          kind: ResourceKind.occurrence,
          startInclusive: DateTime(0, 1, 1),
          endExclusive: DateTime(0, 1, 2),
        ),
        ResourceQuery(
          kind: ResourceKind.occurrence,
          startInclusive: DateTime(9999, 12, 31),
          endExclusive: DateTime(10000, 1, 1),
        ),
      ];
      for (final request in invalid) {
        expect(
          () => reader.query(request),
          throwsA(queryProblem(ResourceQueryErrorCode.invalidArgument)),
        );
      }
      expect(
        () => reader.query(
          ResourceQuery(kind: ResourceKind.course, fields: {'courses'}),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.invalidField)),
      );
      expect(
        reader.query(ResourceQuery(kind: ResourceKind.course, ids: {})).items,
        isEmpty,
      );
    },
  );

  test('UTF-8 byte budget ends a page with an exact continuation', () {
    final reader = queries(
      fixture(
        calendars: [
          calendar('calendar-a', [
            for (var i = 0; i < 5; i++) event('event-$i', notes: '界' * 9000),
          ]),
        ],
      ),
    );
    var page = reader.query(
      ResourceQuery(kind: ResourceKind.event, fields: {'notes'}, limit: 100),
    );
    expect(page.items, hasLength(2));
    final found = <String>[];
    while (true) {
      expect(
        utf8.encode(jsonEncode(page.toJson())).length,
        lessThanOrEqualTo(ResourceQueryLimits.maxPageBytes),
      );
      found.addAll(ids(page));
      if (!page.hasMore) break;
      page = reader.query(
        ResourceQuery(
          kind: ResourceKind.event,
          fields: {'notes'},
          limit: 100,
          cursor: page.nextCursor,
        ),
      );
    }
    expect(found, ['event-0', 'event-1', 'event-2', 'event-3', 'event-4']);
  });

  test(
    'oversized single detail errors explicitly while summary is readable',
    () {
      final reader = queries(
        fixture(
          calendars: [
            calendar('calendar-a', [event('large', notes: '界' * 30000)]),
          ],
        ),
      );
      expect(
        () => reader.query(
          ResourceQuery(kind: ResourceKind.event, view: ResourceView.detail),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.resultTooLarge)),
      );
      expect(ids(reader.query(ResourceQuery(kind: ResourceKind.event))), [
        'large',
      ]);
    },
  );

  test(
    'match count budget does not silently report a truncated whole dataset',
    () {
      final reader = queries(
        fixture(
          tables: [
            table('table-a', [
              for (var i = 0; i <= ResourceQueryLimits.maxMatches; i++)
                course('course-$i'),
            ]),
          ],
        ),
      );
      expect(
        () =>
            reader.query(ResourceQuery(kind: ResourceKind.course, fields: {})),
        throwsA(queryProblem(ResourceQueryErrorCode.queryTooLarge)),
      );
      expect(
        ids(
          reader.query(
            ResourceQuery(
              kind: ResourceKind.course,
              ids: {'course-20000'},
              fields: {},
            ),
          ),
        ),
        ['course-20000'],
      );
    },
  );

  test(
    'large expansion length is rejected before any occurrence materializes',
    () {
      final reader = queries(
        fixture(),
        expandEvent: ({
          required calendar,
          required event,
          required startInclusive,
          required endExclusive,
        }) => _OversizedOccurrenceList(),
      );
      expect(
        () => reader.query(occurrenceQuery(source: OccurrenceSource.event)),
        throwsA(queryProblem(ResourceQueryErrorCode.queryTooLarge)),
      );
    },
  );

  test(
    'a short query cannot force eager expansion of a century-long daily event',
    () {
      final reader = queries(
        fixture(
          calendars: [
            calendar('calendar-a', [
              event(
                'long',
                start: '1900-01-01T09:00:00.000Z',
                end: '2026-10-05T10:00:00.000Z',
                recurrenceRule: const GeneralEventRecurrenceRule(
                  type: GeneralEventRecurrence.daily,
                ),
              ),
            ]),
          ],
        ),
      );
      expect(
        () => reader.query(
          ResourceQuery(
            kind: ResourceKind.occurrence,
            occurrenceSource: OccurrenceSource.event,
            startInclusive: DateTime.utc(2026, 10, 5),
            endExclusive: DateTime.utc(2026, 10, 6),
          ),
        ),
        throwsA(queryProblem(ResourceQueryErrorCode.queryTooLarge)),
      );
    },
  );

  test('unsupported custom values fail only when that field is requested', () {
    final reader = queries(
      fixture(
        tables: [
          table('table-a', [
            course('course-a', customFields: {'notJson': Object()}),
          ]),
        ],
      ),
    );
    expect(
      reader.query(ResourceQuery(kind: ResourceKind.course)).items,
      hasLength(1),
    );
    expect(
      () => reader.query(
        ResourceQuery(kind: ResourceKind.course, fields: {'customFields'}),
      ),
      throwsA(queryProblem(ResourceQueryErrorCode.invalidSnapshot)),
    );
  });
}

List<String> ids(QueryPage page) =>
    page.items.map((item) => item.ref.id).toList();

ResourceQueries queries(
  AppData snapshot, {
  String generation = 'dataset-1',
  int revision = 7,
  GeneralEventOccurrenceExpander? expandEvent,
}) => ResourceQueries(
  snapshot: snapshot,
  datasetGeneration: generation,
  snapshotRevision: revision,
  expandEvent: expandEvent,
);

ResourceQuery occurrenceQuery({
  Set<String>? parentIds,
  Set<String>? sourceIds,
  OccurrenceSource? source,
  String search = '',
  int limit = 50,
}) => ResourceQuery(
  kind: ResourceKind.occurrence,
  parentIds: parentIds,
  sourceIds: sourceIds,
  occurrenceSource: source,
  search: search,
  limit: limit,
  startInclusive: DateTime(2026, 10, 5),
  endExclusive: DateTime(2026, 10, 6),
);

AppData fixture({
  List<TimetableData>? tables,
  List<GeneralSchedule>? calendars,
  GeneralScheduleData? general,
  Set<AppMode> enabled = const {AppMode.student},
}) => AppData(
  activeMode: enabled.first,
  enabledWorkspaces: enabled,
  studentMode: StudentModeData(
    activeTimetableId: 'table-a',
    timetables:
        tables ??
        [
          table('table-a', [course('course-a')]),
          table('table-b', [course('course-b')]),
        ],
    periodTimeSets: const [
      PeriodTimeSet(
        id: 'periods',
        name: 'Day periods',
        periodTimes: [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
      ),
    ],
  ),
  generalMode:
      general ??
      GeneralScheduleData(
        activeScheduleId: 'calendar-a',
        schedules:
            calendars ??
            [
              calendar('calendar-a', [event('event-a')]),
              calendar('calendar-b', [event('event-b')], visible: false),
            ],
      ),
  aiApiSettings: const AiApiSettings(
    customApiKey: 'runtime-secret',
    customBaseUrl: 'https://private.example',
    customModel: 'private-model',
  ),
  notificationSettings: const NotificationSettings(
    courseDefaultMinutesBefore: 5,
    generalDefaultMinutesBefore: 10,
  ),
);

TimetableData table(String id, List<CourseItem> courses) => TimetableData(
  id: id,
  config: TimetableConfig(
    name: 'Same timetable',
    startDate: DateTime(2026, 10, 5),
    totalWeeks: 4,
    periodTimeSetId: 'periods',
  ),
  courses: courses,
);

CourseItem course(
  String id, {
  String teacher = 'Teacher',
  List<int> weeks = const [1, 3],
  List<int> periods = const [1],
  int start = 0,
  int end = 0,
  Map<String, dynamic> customFields = const {},
}) => CourseItem(
  id: id,
  name: 'Same course',
  teacher: teacher,
  location: 'Room',
  dayOfWeek: 1,
  semesterWeeks: weeks,
  periods: periods,
  startMinutes: start,
  endMinutes: end,
  timeRange: '',
  credit: 1,
  remarks: '',
  customFields: customFields,
);

GeneralSchedule calendar(
  String id,
  List<GeneralEvent> events, {
  bool visible = true,
}) => GeneralSchedule(
  id: id,
  name: 'Same calendar',
  events: events,
  isVisible: visible,
);

GeneralEvent event(
  String id, {
  String title = 'Same event',
  String notes = '',
  String start = '2026-10-05T09:00:00.000',
  String end = '2026-10-05T10:00:00.000',
  bool allDay = false,
  GeneralEventRecurrenceRule? recurrenceRule,
  List<String> exceptions = const [],
  GeneralEventReminderBehavior? reminderBehavior,
}) => GeneralEvent(
  id: id,
  title: title,
  startDateTimeIso: start,
  endDateTimeIso: end,
  isAllDay: allDay,
  notes: notes,
  recurrenceRule: recurrenceRule,
  recurrenceExceptionDateIso: exceptions,
  reminderBehavior: reminderBehavior,
);

class _OversizedOccurrenceList extends ListBase<GeneralEventOccurrence> {
  @override
  int get length => ResourceQueryLimits.maxMatches + 1;
  @override
  set length(int value) => throw UnsupportedError('read-only');
  @override
  GeneralEventOccurrence operator [](int index) =>
      throw StateError('must not materialize');
  @override
  void operator []=(int index, GeneralEventOccurrence value) =>
      throw UnsupportedError('read-only');
}
