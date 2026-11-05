import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/agent/ui/agent_selectable_text.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  AgentTimelineActivity activity({
    int count = 8,
    AgentToolActivityStatus status = AgentToolActivityStatus.completed,
    String output = '{"items":[],"candidateCount":0}',
  }) => AgentTimelineActivity(
    id: 'turn',
    anchorMessageId: 'calls',
    tools: [
      for (var index = 0; index < count; index++)
        AgentToolActivity(
          id: 'tool-$index',
          name: 'notifications.reminders',
          arguments: '{"limit":20}',
          result: output,
          status: status,
        ),
    ],
  );
  Finder key(String value) => find.byKey(ValueKey(value));

  testWidgets(
    'completed turn occupies one row and builds raw output only on request',
    (tester) async {
      addTearDown(tester.view.reset);
      final entry = activity();
      await mountAgentUi(
        tester,
        Align(
          alignment: AlignmentDirectional.topStart,
          child: AgentTurnActivity(activity: entry),
        ),
        size: const Size(760, 900),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentTurnActivity)),
      );
      expect(
        find.text('${l.agentActivitySummary(8)} · ${l.agentActivityCompleted}'),
        findsOneWidget,
      );
      expect(tester.getSize(key('agent-activity-toggle-turn')).height, 32);
      expect(find.byType(AgentSelectableText), findsNothing);
      expect(key('agent-activity-list-turn'), findsNothing);

      await tester.tap(key('agent-activity-toggle-turn'));
      await tester.pumpAndSettle();
      expect(key('agent-activity-list-turn'), findsOneWidget);
      expect(find.byType(AgentSelectableText), findsNothing);
      expect(find.text('notifications.reminders'), findsNothing);
      expect(
        tester.getSize(key('agent-activity-list-turn')).height,
        lessThanOrEqualTo(280),
      );
      await tester.tap(key('agent-activity-tool-tool-0'));
      await tester.pumpAndSettle();
      expect(find.text('notifications.reminders'), findsOneWidget);
      expect(
        find.text(const JsonEncoder.withIndent('  ').convert({'limit': 20})),
        findsOneWidget,
      );
      expect(key('agent-activity-detail-tool-0'), findsOneWidget);
      expect(key('agent-activity-list-turn'), findsNothing);
      await tester.tap(key('agent-activity-back'));
      await tester.pumpAndSettle();
      expect(key('agent-activity-list-turn'), findsOneWidget);
      expect(find.byType(AgentSelectableText), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final state in [
    AgentToolActivityStatus.failed,
    AgentToolActivityStatus.uncertain,
  ]) {
    testWidgets('collapsed activity publishes its real $state status', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        await mountAgentUi(
          tester,
          AgentTurnActivity(activity: activity(status: state)),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentTurnActivity)),
        );
        final expected = agentToolActivityStatusLabel(state, l);
        expect(
          find.text('${l.agentActivitySummary(8)} · $expected'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(expected))),
          findsWidgets,
        );
        expect(find.byType(AgentSelectableText), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'late copy acknowledgement cannot reappear after hiding and reopening details',
    (tester) async {
      addTearDown(tester.view.reset);
      final gate = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') await gate.future;
        return null;
      });
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      var active = true;
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return AgentTurnActivity(activity: activity(), active: active);
          },
        ),
      );
      await tester.tap(key('agent-activity-toggle-turn'));
      await tester.pumpAndSettle();
      await tester.tap(key('agent-activity-tool-tool-0'));
      await tester.pumpAndSettle();
      await tester.tap(key('agent-activity-copy-tool-0'));
      await tester.pump();
      change(() => active = false);
      await tester.pump();
      change(() => active = true);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(key('agent-activity-detail-tool-0'), findsNothing);
      await tester.tap(key('agent-activity-toggle-turn'));
      await tester.pumpAndSettle();
      await tester.tap(key('agent-activity-tool-tool-0'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentTurnActivity)),
      );
      expect(find.byTooltip(l.agentCopied), findsNothing);
      expect(find.byTooltip(l.agentCopyActivity), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final removesTool in [false, true]) {
    testWidgets(
      'a detail copy callback expires when its ${removesTool ? 'tool disappears' : 'output changes'}',
      (tester) async {
        addTearDown(tester.view.reset);
        final copied = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        var current = activity(count: 1, output: 'First output');
        late StateSetter change;
        await mountAgentUi(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return AgentTurnActivity(activity: current);
            },
          ),
        );
        await tester.tap(key('agent-activity-toggle-turn'));
        await tester.pumpAndSettle();
        await tester.tap(key('agent-activity-tool-tool-0'));
        await tester.pumpAndSettle();
        final stale = tester
            .widget<IconButton>(key('agent-activity-copy-tool-0'))
            .onPressed!;
        change(
          () => current = activity(
            count: removesTool ? 0 : 1,
            output: 'Current output',
          ),
        );
        await tester.pumpAndSettle();
        stale();
        await tester.pumpAndSettle();
        expect(copied, isEmpty);
        if (!removesTool) {
          await tester.tap(key('agent-activity-copy-tool-0'));
          await tester.pumpAndSettle();
          expect(copied, hasLength(1));
          expect(copied.single, contains('Current output'));
          expect(copied.single, isNot(contains('First output')));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    for (final hideActive in [true, false]) {
      testWidgets(
        'a pressed activity from $kind expires across ${hideActive ? 'active' : 'interactive'} reentry',
        (tester) async {
          addTearDown(tester.view.reset);
          var enabled = true;
          late StateSetter change;
          await mountAgentUi(
            tester,
            StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return AgentTurnActivity(
                  activity: activity(),
                  active: hideActive ? enabled : true,
                  interactive: hideActive ? true : enabled,
                );
              },
            ),
          );
          final pressed = await tester.startGesture(
            tester.getCenter(key('agent-activity-toggle-turn')),
            kind: kind,
          );
          await tester.pump();
          change(() => enabled = false);
          await tester.pump();
          change(() => enabled = true);
          await tester.pump();
          await pressed.up();
          if (kind == PointerDeviceKind.mouse) await pressed.removePointer();
          await tester.pumpAndSettle();
          expect(key('agent-activity-list-turn'), findsNothing);
          await tester.tap(key('agent-activity-toggle-turn'));
          await tester.pumpAndSettle();
          expect(key('agent-activity-list-turn'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'narrow 2x $direction detail stays bounded and keeps full touch targets',
      (tester) async {
        addTearDown(tester.view.reset);
        final entry = activity(
          count: 1,
          output: jsonEncode({
            'items': [for (var index = 0; index < 80; index++) '完整输出 $index'],
          }),
        );
        await mountAgentUi(
          tester,
          Directionality(
            textDirection: direction,
            child: SingleChildScrollView(
              child: AgentTurnActivity(activity: entry),
            ),
          ),
          size: const Size(320, 740),
          scale: 2,
          brightness: Brightness.dark,
        );
        final toggle = key('agent-activity-toggle-turn');
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
        expect(toggle.hitTestable(), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final row = key('agent-activity-tool-tool-0');
        expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        await tester.tap(row);
        await tester.pumpAndSettle();
        final detail = key('agent-activity-detail-tool-0');
        expect(tester.getSize(detail).height, lessThanOrEqualTo(320));
        for (final control in [
          'agent-activity-back',
          'agent-activity-copy-tool-0',
        ]) {
          expect(tester.getSize(key(control)).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(key(control)).height, greaterThanOrEqualTo(48));
          expect(key(control).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
