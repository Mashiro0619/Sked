import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'query and aggregate execution use their published defaults and types',
    () async {
      final h = CoreToolHarness();
      await h.initialize();
      addTearDown(h.close);
      addTearDown(h.tools.dispose);
      final scope = OperationScope(
        id: 'query-field-metadata',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      );
      var callId = 0;
      Future<Map<String, Object?>> call(
        String name,
        Map<String, Object?> args,
      ) => h.tools.execute(
        ProviderToolCall(
          id: 'call-${callId++}',
          name: name,
          arguments: jsonEncode(args),
        ),
        scope,
        (_) async => fail('Read tools and full mode need no approval.'),
      );
      final plan = h.mutations.prepare(
        scope: scope,
        resources: [
          for (var index = 0; index < 55; index++)
            ResourceMutation(
              kind: ResourceKind.calendar,
              action: ResourceMutationAction.create,
              values: {'name': 'Fixture $index', 'isVisible': index.isEven},
            ),
        ],
      );
      await h.mutations.commit(planId: plan.id, scope: scope);
      final catalog = await call('capabilities.describe', {
        'names': [
          'calendars.list',
          'calendars.get',
          'agenda.free_slots',
          'courses.conflicts',
        ],
      });
      final definitions = <String, Map>{
        for (final tool in (catalog['tools'] as List).cast<Map>())
          tool['name'] as String:
              (tool['parameters'] as Map)['properties'] as Map,
      };
      final listFields = definitions['calendars.list']!;
      final defaults = <String, Object?>{
        for (final entry in listFields.entries)
          if ((entry.value as Map).containsKey('default'))
            entry.key as String: entry.value['default'],
      };
      expect(defaults, {
        'query': '',
        'view': 'summary',
        'limit': 50,
        'includeHidden': true,
        'includeDisabled': true,
      });
      final page = await call('calendars.list', {});
      expect(page, await call('calendars.list', defaults));
      expect(page['items'], hasLength(50));
      expect(page['hasMore'], isTrue);
      expect(
        (await call('calendars.list', {
          'includeHidden': false,
        }))['totalMatches'],
        29,
      );
      final first = (page['items'] as List).first as Map;
      final detail = await call('calendars.get', {'id': first['ref']['id']});
      expect(detail['view'], definitions['calendars.get']!['view']['default']);

      const shortRange = {
        'start': '2026-11-07T08:00:00Z',
        'end': '2026-11-07T08:20:00Z',
      };
      final aggregate = definitions['agenda.free_slots']!;
      expect(aggregate['minimumMinutes']['default'], 30);
      expect(aggregate['limit']['default'], 20);
      expect(aggregate['offset']['default'], 0);
      expect((await call('agenda.free_slots', shortRange))['items'], isEmpty);
      expect(
        (await call('agenda.free_slots', {
          ...shortRange,
          'minimumMinutes': 1,
        }))['items'],
        hasLength(1),
      );

      for (final (name, args, field)
          in <(String, Map<String, Object?>, String)>[
            ('calendars.list', {'query': false}, 'query'),
            ('calendars.list', {'includeHidden': 'yes'}, 'includeHidden'),
            ('calendars.list', {'view': 'unknown'}, 'view'),
            ('calendars.list', {'limit': 1.5}, 'limit'),
            (
              'calendars.list',
              {
                'ids': [42],
              },
              'ids',
            ),
            ('agenda.query', {...shortRange, 'source': 'unknown'}, 'source'),
            (
              'agenda.free_slots',
              {...shortRange, 'minimumMinutes': 0},
              'minimumMinutes',
            ),
            ('courses.conflicts', {...shortRange, 'offset': -1}, 'offset'),
          ]) {
        await expectLater(
          call(name, args),
          throwsA(
            isA<OperationProblem>().having(
              (error) => error.field,
              'field',
              field,
            ),
          ),
        );
      }
    },
  );

  test(
    'discovered page bounds are accepted and enforced by their tools',
    () async {
      final h = CoreToolHarness();
      await h.initialize();
      addTearDown(h.close);
      final scope = OperationScope(
        id: 'pagination-contract',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
      );
      final sourceText = '首🙂尾' * 9001;
      final conversation = AgentConversation(
        id: 'conversation',
        title: 'Fixture',
        createdAt: DateTime.utc(2026, 10, 30),
        updatedAt: DateTime.utc(2026, 10, 30),
        sources: [
          ConversationSource(id: 'source', kind: 'text', text: sourceText),
        ],
        messages: [
          ConversationMessage(
            id: 'message',
            role: ConversationRole.user,
            text: 'Synthetic pagination fixture',
            createdAt: DateTime.utc(2026, 10, 30),
          ),
        ],
      );
      final host = ApplicationToolHost(
        session: h.session,
        mutations: h.mutations,
        conversationForScope: (_) => conversation,
      );
      addTearDown(host.dispose);
      Future<Map<String, Object?>> call(
        String name,
        Map<String, Object?> args,
      ) => host.executeInternal(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        (_) async => null,
      );
      const bounds = {
        'capabilities.describe': 16,
        'skills.search': 24,
        'conversation.history': 50,
        'conversation.read': 8000,
        'sources.read': 12000,
      };
      final catalog = await call('capabilities.describe', {
        'names': bounds.keys.toList(),
      });
      for (final tool in (catalog['tools'] as List).cast<Map>()) {
        final name = tool['name'] as String;
        final limit = (tool['parameters'] as Map)['properties']['limit'] as Map;
        expect(limit['minimum'], 1, reason: name);
        expect(limit['maximum'], bounds[name], reason: name);
        final args = <String, Object?>{
          if (name == 'capabilities.describe') 'names': [name],
          if (name == 'conversation.read') 'id': 'message',
          if (name == 'sources.read') 'id': 'source',
        };
        await call(name, {...args, 'limit': limit['maximum']});
        for (final invalid in [0, (limit['maximum'] as int) + 1]) {
          await expectLater(
            call(name, {...args, 'limit': invalid}),
            throwsA(
              isA<OperationProblem>().having(
                (problem) => problem.code,
                'code',
                OperationErrorCode.invalidArgument,
              ),
            ),
            reason: name,
          );
        }
      }
      expect((catalog['tools'] as List), hasLength(bounds.length));
      final reconstructed = StringBuffer();
      var offset = 0;
      while (true) {
        final page = await call('sources.read', {
          'id': 'source',
          'offset': offset,
          'limit': 12000,
        });
        reconstructed.write(page['text']);
        if (page['hasMore'] == false) {
          expect(page['nextOffset'], isNull);
          break;
        }
        final next = page['nextOffset'] as int;
        expect(next, greaterThan(offset));
        offset = next;
      }
      expect(reconstructed.toString(), sourceText);
      expect(h.session.committedData.applicationLedger, isNull);
    },
  );

  test(
    'aggregate schemas only expose fields consumed by each calculation',
    () async {
      final h = CoreToolHarness();
      await h.initialize();
      addTearDown(h.close);
      addTearDown(h.tools.dispose);
      final scope = OperationScope(
        id: 'aggregate-contract',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.plan),
      );
      Future<Map<String, Object?>> call(
        String name,
        Map<String, Object?> args,
      ) => h.tools.execute(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        (_) async => null,
      );
      final catalog = await call('capabilities.describe', {
        'names': ['agenda.free_slots', 'courses.conflicts'],
      });
      final definitions = {
        for (final tool in (catalog['tools'] as List).cast<Map>())
          tool['name']: (tool['parameters'] as Map)['properties'] as Map,
      };
      expect(definitions['agenda.free_slots']!['minimumMinutes'], {
        'type': 'integer',
        'minimum': 1,
        'default': 30,
      });
      expect(
        definitions['courses.conflicts'],
        isNot(contains('minimumMinutes')),
      );
      const range = {
        'start': '2026-11-07T00:00:00Z',
        'end': '2026-11-08T00:00:00Z',
      };
      await call('agenda.free_slots', {...range, 'minimumMinutes': 1});
      await call('courses.conflicts', range);
      for (final (name, value) in [
        ('agenda.free_slots', 0),
        ('courses.conflicts', 30),
      ]) {
        await expectLater(
          call(name, {...range, 'minimumMinutes': value}),
          throwsA(
            isA<OperationProblem>().having(
              (error) => error.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
        );
      }
      expect(h.session.committedData.applicationLedger, isNull);
    },
  );
}
