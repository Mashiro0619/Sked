import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_queries.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CoreToolHarness app;
  late OperationScope scope;
  const families = {
    'timetables': ResourceKind.timetable,
    'courses': ResourceKind.course,
    'period_sets': ResourceKind.periodTimeSet,
    'calendars': ResourceKind.calendar,
    'events': ResourceKind.event,
    'occurrences': ResourceKind.occurrence,
  };
  const occurrenceRange = {
    'start': '2026-11-07T00:00:00',
    'end': '2026-11-08T00:00:00',
  };

  setUp(() async {
    app = CoreToolHarness();
    await app.initialize();
    scope = OperationScope(
      id: 'resource-projection',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
    );
  });
  tearDown(() async {
    app.tools.finishScope(scope);
    scope.cancel();
    app.tools.dispose();
    await app.close();
  });

  Future<Map<String, Object?>> call(String name, Map<String, Object?> args) =>
      app.tools.execute(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        (_) async => null,
      );

  test(
    'discovery and provider tools expose exact projection field enums',
    () async {
      final kindsByTool = {
        for (final family in families.entries) ...{
          '${family.key}.list': family.value,
          '${family.key}.get': family.value,
        },
        'agenda.query': ResourceKind.occurrence,
      };
      final catalog = await call('capabilities.describe', {
        'names': [
          ...kindsByTool.keys,
          'selection.create',
          'resources.describe',
        ],
      });
      final tools = (catalog['tools'] as List).cast<Map>();
      expect(tools, hasLength(kindsByTool.length + 2));
      final providerTools = app.tools.toolsFor(scope);
      for (final tool in tools) {
        final name = tool['name'] as String;
        final parameters = tool['parameters'] as Map;
        expect(
          providerTools.singleWhere((tool) => tool.name == name).parameters,
          parameters,
          reason: name,
        );
        final kind = kindsByTool[name];
        if (kind == null) continue;
        final properties = parameters['properties'] as Map;
        final isGet = name.endsWith('.get');
        final occurrence = kind == ResourceKind.occurrence;
        final child = const {
          ResourceKind.course,
          ResourceKind.event,
          ResourceKind.occurrence,
        }.contains(kind);
        expect(properties.containsKey('start'), occurrence, reason: name);
        expect(properties.containsKey('end'), occurrence, reason: name);
        expect(
          properties.containsKey(isGet ? 'parentId' : 'parentIds'),
          child,
          reason: name,
        );
        if (!isGet) {
          expect(properties.containsKey('sourceIds'), occurrence, reason: name);
          expect(properties.containsKey('source'), occurrence, reason: name);
        }
        if (occurrence) {
          expect(parameters['required'], containsAll(['start', 'end']));
        }
        if (isGet && child) {
          expect(parameters['required'], contains('parentId'));
        }
        final fields = properties['fields'] as Map;
        expect(fields['description'], contains('Omit'));
        expect(fields['description'], contains('ref'));
        expect(
          (fields['items'] as Map)['enum'],
          unorderedEquals(ResourceQueries.allowedFieldsFor(kind)),
          reason: name,
        );
        expect(parameters['required'] as List, isNot(contains('fields')));
      }
      final selection = tools.singleWhere(
        (tool) => tool['name'] == 'selection.create',
      );
      final selectionFields =
          (selection['parameters'] as Map)['properties']['fields'] as Map;
      expect(selectionFields['description'], contains('references only'));
      final describe = tools.singleWhere(
        (tool) => tool['name'] == 'resources.describe',
      );
      expect(describe['description'], contains('query fields'));
    },
  );

  test(
    'resource discovery provides every allowed field and default view',
    () async {
      for (final kind in ResourceKind.values) {
        final descriptor = await call('resources.describe', {
          'kind': kind.name,
        });
        expect(
          descriptor['queryFields'],
          unorderedEquals(ResourceQueries.allowedFieldsFor(kind)),
        );
        final views = descriptor['queryViews'] as Map;
        for (final view in ResourceView.values) {
          expect(
            views[view.name],
            unorderedEquals(ResourceQueries.fieldsFor(kind, view)),
          );
        }
      }
    },
  );

  test(
    'invalid projections give bounded corrections through the tool host',
    () async {
      final unknownField = 'untrusted-${List.filled(8192, 'x').join()}';
      for (final family in families.entries) {
        final args = <String, Object?>{
          if (family.value == ResourceKind.occurrence) ...occurrenceRange,
          'fields': [unknownField],
        };
        final allowed = ResourceQueries.allowedFieldsFor(family.value).toList()
          ..sort();
        await expectLater(
          call('${family.key}.list', args),
          throwsA(
            isA<OperationProblem>()
                .having(
                  (problem) => problem.code,
                  'code',
                  OperationErrorCode.invalidArgument,
                )
                .having((problem) => problem.field, 'field', 'fields')
                .having(
                  (problem) => problem.message,
                  'message',
                  allOf(
                    contains(family.value.name),
                    contains(allowed.join(', ')),
                    contains('Omit fields'),
                    contains('ref'),
                    isNot(contains(unknownField)),
                    hasLength(lessThan(2048)),
                  ),
                ),
          ),
          reason: family.key,
        );
        final corrected = await call('${family.key}.list', {
          ...args,
          'fields': allowed,
        });
        expect(corrected['items'], isA<List>());
      }
    },
  );

  test('resource filters are validated against the advertised kind-specific properties', () async {
    for (final name in [
      'events.list',
      'courses.list',
      'calendars.list',
      'timetables.list',
      'period_sets.list',
    ]) {
      await call(name, {});
      for (final args in [
        occurrenceRange,
        {'source': 'event'},
        {
          'sourceIds': ['fixture'],
        },
      ]) {
        await expectLater(call(name, args), throwsA(isA<OperationProblem>()));
      }
    }
    final result = await call('agenda.query', occurrenceRange);
    expect(result['items'], isA<List>());
  });

  test(
    'legacy null query arguments keep list get and selection behavior',
    () async {
      const nullQuery = <String, Object?>{
        'ids': null,
        'parentIds': null,
        'sourceIds': null,
        'source': null,
        'query': null,
        'view': null,
        'fields': null,
        'start': null,
        'end': null,
        'limit': null,
        'cursor': null,
        'includeHidden': null,
        'includeDisabled': null,
      };
      for (final family in families.entries) {
        final args = <String, Object?>{
          if (family.value == ResourceKind.occurrence) ...occurrenceRange,
        };
        final expected = await call('${family.key}.list', args);
        final page = await call('${family.key}.list', {...nullQuery, ...args});
        expect(page, expected, reason: family.key);
        final selection = await call('selection.create', {
          ...nullQuery,
          ...args,
          'kind': family.value.name,
        });
        expect(
          selection['items'],
          (page['items'] as List).map((item) => item['ref']).toList(),
          reason: family.key,
        );
      }
      for (final family in ['calendars', 'timetables', 'period_sets']) {
        final page = await call('$family.list', {});
        for (final item in page['items'] as List) {
          final id = item['ref']['id'];
          final expected = await call('$family.get', {'id': id});
          expect(
            await call('$family.get', {
              'id': id,
              'parentId': null,
              'view': null,
              'fields': null,
              'start': null,
              'end': null,
            }),
            expected,
          );
        }
      }
    },
  );

  test(
    'legacy null compatibility still rejects unknown and inapplicable values',
    () async {
      final invalid = throwsA(
        isA<OperationProblem>().having(
          (error) => error.code,
          'code',
          OperationErrorCode.invalidArgument,
        ),
      );
      for (final extra in <Map<String, Object?>>[
        {'unknown': null},
        {'parentIds': <String>[]},
        {'start': occurrenceRange['start']},
        {'source': 'event'},
        {'sourceIds': <String>[]},
      ]) {
        await expectLater(call('calendars.list', extra), invalid);
        await expectLater(
          call('selection.create', {'kind': 'calendar', ...extra}),
          invalid,
        );
      }
      for (final extra in <Map<String, Object?>>[
        {'unknown': null},
        {'parentId': 'fixture'},
        {'start': occurrenceRange['start']},
        {'end': occurrenceRange['end']},
      ]) {
        await expectLater(
          call('calendars.get', {'id': 'fixture', ...extra}),
          invalid,
        );
      }
    },
  );

  test('null required resource arguments remain invalid', () async {
    final invalid = throwsA(
      isA<OperationProblem>().having(
        (error) => error.code,
        'code',
        OperationErrorCode.invalidArgument,
      ),
    );
    for (final family in families.keys) {
      await expectLater(call('$family.get', {'id': null}), invalid);
    }
    for (final family in ['courses', 'events', 'occurrences']) {
      await expectLater(
        call('$family.get', {'id': 'fixture', 'parentId': null}),
        invalid,
      );
    }
    for (final key in ['start', 'end']) {
      final range = <String, Object?>{...occurrenceRange, key: null};
      await expectLater(call('occurrences.list', range), invalid);
      await expectLater(call('agenda.query', range), invalid);
      await expectLater(
        call('selection.create', {'kind': 'occurrence', ...range}),
        invalid,
      );
      await expectLater(
        call('occurrences.get', {
          'id': 'course|fixture-parent|fixture|2026-11-07',
          'parentId': 'fixture-parent',
          ...range,
        }),
        invalid,
      );
    }
    await expectLater(call('selection.create', {'kind': null}), invalid);
  });

  test(
    'default, explicit and reference-only projections preserve their meaning',
    () async {
      final page = await call('calendars.list', {});
      final item = (page['items'] as List).single as Map;
      final ref = item['ref'] as Map;
      expect(
        item['includedFields'],
        unorderedEquals(
          ResourceQueries.fieldsFor(
            ResourceKind.calendar,
            ResourceView.summary,
          ),
        ),
      );
      final defaults = await call('calendars.get', {'id': ref['id']});
      expect(
        defaults['includedFields'],
        unorderedEquals(
          ResourceQueries.fieldsFor(ResourceKind.calendar, ResourceView.detail),
        ),
      );
      final explicit = await call('calendars.get', {
        'id': ref['id'],
        'fields': ['name'],
      });
      expect(explicit['includedFields'], ['name']);
      expect((explicit['data'] as Map)['name'], (item['data'] as Map)['name']);
      final referenceOnly = await call('calendars.get', {
        'id': ref['id'],
        'fields': <String>[],
      });
      expect(referenceOnly['ref'], ref);
      expect(referenceOnly['data'], isEmpty);
      expect(referenceOnly['includedFields'], isEmpty);
      final selection = await call('selection.create', {
        'kind': 'calendar',
        'fields': ['name'],
      });
      expect((selection['items'] as List).single, ref);
    },
  );
}
