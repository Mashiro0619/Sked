import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_activity_summary.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/agent/ui/agent_selectable_text.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/l10n/app_localizations_zh.dart';

import '../tools/tool_adapter_test_support.dart';
import 'agent_ui_test_support.dart';

/// Real registered tools and projections over isolated application data.
Future<AgentTimelineActivity> buildHostActivitySummaryFixture() async {
  final h = ToolAdapterHarness();
  await h.initialize();
  try {
    final plan = await h.call('mutation.prepare', {
      'commands': [
        {
          'kind': 'calendar',
          'action': 'create',
          'values': {'name': '项目计划'},
        },
      ],
    });
    await h.commit(plan);
    final calendar = h.session.committedData.generalMode.schedules.singleWhere(
      (item) => item.name == '项目计划',
    );
    final requests = <(String, Map<String, Object?>)>[
      (
        'agenda.query',
        {'start': '2026-11-05T00:00:00', 'end': '2026-11-06T00:00:00'},
      ),
      (
        'agenda.free_slots',
        {
          'start': '2026-11-09T09:00:00',
          'end': '2026-11-09T17:00:00',
          'minimumMinutes': 30,
        },
      ),
      ('calendars.get', {'id': calendar.id}),
    ];
    final activities = <AgentToolActivity>[];
    for (final (name, arguments) in requests) {
      final result = await h.call(name, arguments);
      activities.add(
        AgentToolActivity(
          id: 'host-${activities.length}',
          name: name,
          arguments: jsonEncode(arguments),
          result: jsonEncode(result),
          status: AgentToolActivityStatus.completed,
        ),
      );
    }
    return AgentTimelineActivity(
      id: 'host-read',
      anchorMessageId: 'read',
      tools: activities,
    );
  } finally {
    await h.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);
  final l = AppLocalizationsZh();
  AgentToolActivity tool(
    String name,
    Map<String, Object?> args, {
    Object? result,
    AgentToolActivityStatus status = AgentToolActivityStatus.completed,
  }) => AgentToolActivity(
    id: 'activity',
    name: name,
    arguments: jsonEncode(args),
    result: result == null ? null : jsonEncode(result),
    status: status,
  );

  test(
    'query summaries distinguish dates, resource kinds and search terms',
    () {
      final first = summarizeAgentToolActivity(
        tool('agenda.query', {
          'start': '2026-11-05T09:00:00',
          'end': '2026-11-05T18:00:00',
          'query': '项目评审',
          'metadata': 'private-metadata',
        }),
        l,
      );
      final second = summarizeAgentToolActivity(
        tool('agenda.query', {
          'start': '2026-11-06T09:00:00',
          'end': '2026-11-06T18:00:00',
        }),
        l,
      );
      expect(first.title, contains(l.workspaceBoth));
      expect(first.detail, contains('2026/11/5 09:00'));
      expect(first.detail, contains('2026/11/5 18:00'));
      expect(first.detail, contains('${l.agentKnowledgeSearch}: 项目评审'));
      expect(first.detail, isNot(contains('private-metadata')));
      expect(first.detail, isNot(second.detail));
      expect(
        summarizeAgentToolActivity(tool('calendars.list', {}), l).title,
        contains(l.calendars),
      );
      expect(
        summarizeAgentToolActivity(tool('timetables.list', {}), l).title,
        contains(l.timetable),
      );
    },
  );

  test(
    'object summaries require matching kind, object and parent identities',
    () {
      final args = {'id': 'event-1', 'parentId': 'calendar-1'};
      Map<String, Object?> result(Map<String, Object?> ref) => {
        'ref': ref,
        'data': {'title': '项目评审', 'notes': 'private-notes'},
        'metadata': {'title': 'private-metadata'},
      };
      final ref = {'kind': 'event', 'id': 'event-1', 'parentId': 'calendar-1'};
      expect(
        summarizeAgentToolActivity(
          tool('events.get', args, result: result(ref)),
          l,
        ).detail,
        '项目评审',
      );
      for (final mismatched in [
        {...ref, 'id': 'other'},
        {...ref, 'parentId': 'other'},
        {...ref, 'kind': 'course'},
      ]) {
        expect(
          summarizeAgentToolActivity(
            tool('events.get', args, result: result(mismatched)),
            l,
          ).detail,
          isNull,
        );
      }
      for (final status in AgentToolActivityStatus.values.where(
        (value) => value != AgentToolActivityStatus.completed,
      )) {
        expect(
          summarizeAgentToolActivity(
            tool('events.get', args, result: result(ref), status: status),
            l,
          ).detail,
          isNull,
        );
      }
    },
  );

  test('unknown tools, source bodies and connection secrets do not become summaries', () {
    for (final name in [
      'unknown.read',
      'sources.read',
      'connection.describe',
      'credentials.request_input',
    ]) {
      final summary = summarizeAgentToolActivity(
        tool(
          name,
          {
            'id': 'secret-id',
            'query': 'secret-query',
            'endpoint': 'https://secret.example',
            'rawKey': 'secret-key',
          },
          result: {
            'id': 'secret-id',
            'title': 'secret-title',
            'text': 'secret-body',
            'metadata': 'secret-metadata',
          },
        ),
        l,
      );
      expect('${summary.title} ${summary.detail}', isNot(contains('secret')));
    }
    final settings = summarizeAgentToolActivity(
      tool('settings.get', {
        'keys': ['agent.maxTotalTokens', 'secret-unknown-key'],
      }),
      l,
    );
    expect(settings.detail, l.agentMaxTotalTokens);
  });

  test('invalid dates, oversized or malformed payloads stay within the detail fallback', () {
    expect(
      summarizeAgentToolActivity(
        tool('agenda.query', {'start': '2026-02-30', 'end': 'not-a-date'}),
        l,
      ).detail,
      isNull,
    );
    for (final raw in ['not JSON', '[]', '{"query":"${'x' * (128 * 1024)}"}']) {
      expect(
        summarizeAgentToolActivity(
          AgentToolActivity(
            id: 'bad',
            name: 'agenda.query',
            arguments: raw,
            status: AgentToolActivityStatus.completed,
          ),
          l,
        ).detail,
        isNull,
      );
    }
    final summary = summarizeAgentToolActivity(
      tool('skills.search', {'query': '\u202e${'长' * 120}\n'}),
      l,
    );
    expect(summary.detail, endsWith('…'));
    expect(summary.detail!.runes.length, lessThan(100));
    expect(summary.detail, isNot(contains('\u202e')));
    expect(summary.detail, isNot(contains('\n')));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'real host activities show targets before raw JSON on $platform',
      (tester) async {
        addTearDown(tester.view.reset);
        final entry = await buildHostActivitySummaryFixture();
        await mountAgentUi(
          tester,
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AgentTurnActivity(activity: entry),
            ),
          ),
          locale: const Locale('zh'),
          size: platform == TargetPlatform.android
              ? const Size(390, 844)
              : const Size(900, 700),
        );
        await tester.tap(
          find.byKey(const ValueKey('agent-activity-toggle-host-read')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('2026/11/5'), findsOneWidget);
        expect(find.textContaining('2026/11/9'), findsOneWidget);
        expect(find.text('项目计划'), findsOneWidget);
        expect(find.byType(AgentSelectableText), findsNothing);
        final objectRow = find.byKey(
          const ValueKey('agent-activity-tool-host-2'),
        );
        await tester.ensureVisible(objectRow);
        await tester.tap(objectRow);
        await tester.pumpAndSettle();
        expect(find.text('calendars.get'), findsOneWidget);
        expect(find.byType(AgentSelectableText), findsWidgets);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
