import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/agent/ui/agent_selectable_text.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/color_contrast.dart';

import 'agent_ui_test_support.dart';

void main() {
  AgentTimelineActivity activity({
    int count = 1,
    AgentToolActivityStatus status = AgentToolActivityStatus.completed,
    String output = '{"items":[]}',
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

  for (final direction in TextDirection.values) {
    testWidgets('inline activity controls fit their text in $direction', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        Directionality(
          textDirection: direction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [AgentTurnActivity(activity: activity(count: 2))],
          ),
        ),
        size: const Size(900, 700),
      );
      final toggle = key('agent-activity-toggle-turn');
      final text = find.descendant(of: toggle, matching: find.byType(Text));
      final arrow = find.descendant(
        of: toggle,
        matching: find.byIcon(
          direction == TextDirection.ltr
              ? Icons.chevron_right_rounded
              : Icons.chevron_left_rounded,
        ),
      );
      expect(tester.getSize(toggle).width, lessThan(300));
      expect(tester.getSize(toggle).height, 32);
      final textBounds = tester.getRect(text);
      final arrowBounds = tester.getRect(arrow);
      final gap = direction == TextDirection.ltr
          ? arrowBounds.left - textBounds.right
          : textBounds.left - arrowBounds.right;
      expect(gap, closeTo(4, .01));
      await tester.tapAt(
        Offset(
          direction == TextDirection.ltr ? 700 : 100,
          tester.getCenter(toggle).dy,
        ),
      );
      await tester.pump();
      expect(key('agent-activity-list-turn'), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final branch = key('agent-activity-branch-turn');
      expect(
        (tester.widget<DecoratedBox>(branch).decoration as BoxDecoration)
            .border,
        isNull,
      );
      final leading = find.descendant(
        of: toggle,
        matching: find.byIcon(Icons.check_rounded),
      );
      final branchEdge = direction == TextDirection.ltr
          ? tester.getRect(branch).left
          : tester.getRect(branch).right;
      expect(branchEdge, closeTo(tester.getCenter(leading).dx, .01));
      final childToggle = key('agent-activity-toggle-tool-0');
      expect(tester.getSize(childToggle).width, lessThan(600));
      final indent = direction == TextDirection.ltr
          ? tester.getRect(childToggle).left - tester.getRect(toggle).left
          : tester.getRect(toggle).right - tester.getRect(childToggle).right;
      expect(indent, closeTo(24, .01));
      await tester.tap(childToggle);
      await tester.pumpAndSettle();
      final childBranch = key('agent-activity-branch-tool-0');
      final childDecoration =
          tester.widget<DecoratedBox>(childBranch).decoration as BoxDecoration;
      expect(childDecoration.border, isNull);
      final childLeading = find.descendant(
        of: childToggle,
        matching: find.byIcon(Icons.check_rounded),
      );
      final childBranchEdge = direction == TextDirection.ltr
          ? tester.getRect(childBranch).left
          : tester.getRect(childBranch).right;
      expect(childBranchEdge, closeTo(tester.getCenter(childLeading).dx, .01));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'running activity text remains readable on a dark narrow surface',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        AgentTurnActivity(
          activity: activity(status: AgentToolActivityStatus.running),
        ),
        size: const Size(360, 800),
        scale: 2,
        brightness: Brightness.dark,
      );
      final row = key('agent-activity-toggle-tool-0');
      final text = tester.widget<Text>(
        find.descendant(of: row, matching: find.byType(Text)).first,
      );
      final surface = Theme.of(tester.element(row)).colorScheme.surface;
      expect(
        colorContrastRatio(text.style!.color!, surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a single read opens inline without an activity-count wrapper', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mountAgentUi(tester, AgentTurnActivity(activity: activity()));
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentTurnActivity)),
    );
    expect(find.text(l.agentActivitySummary(1)), findsNothing);
    expect(find.byType(AgentSelectableText), findsNothing);
    await tester.tap(key('agent-activity-toggle-tool-0'));
    await tester.pumpAndSettle();
    expect(find.text('notifications.reminders'), findsOneWidget);
    expect(key('agent-activity-detail-tool-0'), findsOneWidget);
    final branch = tester.widget<DecoratedBox>(
      key('agent-activity-branch-tool-0'),
    );
    final decoration = branch.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    await tester.tap(key('agent-activity-toggle-tool-0'));
    await tester.pumpAndSettle();
    expect(find.byType(AgentSelectableText), findsNothing);
  });

  testWidgets(
    'finished read groups collapse and open each detail at its own row',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        SingleChildScrollView(
          child: AgentTurnActivity(activity: activity(count: 8)),
        ),
        size: const Size(760, 900),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentTurnActivity)),
      );
      expect(find.text(l.agentActivitySummary(8)), findsOneWidget);
      expect(key('agent-activity-list-turn'), findsNothing);
      expect(tester.getSize(key('agent-activity-toggle-turn')).height, 32);
      await tester.tap(key('agent-activity-toggle-turn'));
      await tester.pumpAndSettle();
      await tester.tap(key('agent-activity-toggle-tool-0'));
      await tester.pumpAndSettle();
      expect(key('agent-activity-detail-tool-0'), findsOneWidget);
      expect(key('agent-activity-list-turn'), findsOneWidget);
      expect(key('agent-activity-tool-tool-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final chosen in [false, true]) {
    testWidgets('completion preserves reader expansion=$chosen', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      var current = activity(count: 2, status: AgentToolActivityStatus.running);
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, update) {
            change = update;
            return AgentTurnActivity(activity: current);
          },
        ),
      );
      expect(key('agent-activity-list-turn'), findsOneWidget);
      if (chosen) {
        await tester.tap(key('agent-activity-toggle-turn'));
        await tester.pump();
        await tester.tap(key('agent-activity-toggle-turn'));
        await tester.pump();
      }
      change(() => current = activity(count: 2));
      await tester.pump();
      expect(
        key('agent-activity-list-turn'),
        chosen ? findsOneWidget : findsNothing,
      );
    });
  }

  for (final removes in [false, true]) {
    testWidgets('stale copy cannot act after source change removes=$removes', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final copied = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      var current = activity(output: 'Before');
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, update) {
            change = update;
            return AgentTurnActivity(activity: current);
          },
        ),
      );
      await tester.tap(key('agent-activity-toggle-tool-0'));
      await tester.pump();
      final stale = tester
          .widget<IconButton>(key('agent-activity-copy-tool-0'))
          .onPressed!;
      change(() => current = activity(count: removes ? 0 : 1, output: 'After'));
      await tester.pump();
      stale();
      await tester.pump();
      expect(copied, isEmpty);
      if (!removes) {
        await tester.tap(key('agent-activity-copy-tool-0'));
        await tester.pump();
        expect(copied.single, contains('After'));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('copy acknowledgement expires across disabled view', (
    tester,
  ) async {
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
    final current = activity();
    await mountAgentUi(
      tester,
      StatefulBuilder(
        builder: (context, update) {
          change = update;
          return AgentTurnActivity(activity: current, active: active);
        },
      ),
    );
    await tester.tap(key('agent-activity-toggle-tool-0'));
    await tester.pump();
    await tester.tap(key('agent-activity-copy-tool-0'));
    await tester.pump();
    change(() => active = false);
    await tester.pump();
    change(() => active = true);
    await tester.pump();
    gate.complete();
    await tester.pump();
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentTurnActivity)),
    );
    expect(find.byTooltip(l.agentCopied), findsNothing);
    expect(key('agent-activity-detail-tool-0'), findsOneWidget);
  });

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('pressed row is retired across visibility changes for $kind', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      var active = true;
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, update) {
            change = update;
            return AgentTurnActivity(activity: activity(), active: active);
          },
        ),
      );
      final pressed = await tester.startGesture(
        tester.getCenter(key('agent-activity-toggle-tool-0')),
        kind: kind,
      );
      change(() => active = false);
      await tester.pump();
      change(() => active = true);
      await tester.pump();
      await pressed.up();
      if (kind == PointerDeviceKind.mouse) await pressed.removePointer();
      await tester.pump();
      expect(key('agent-activity-detail-tool-0'), findsNothing);
    });
  }

  for (final direction in TextDirection.values) {
    testWidgets('narrow 2x $direction detail keeps touch targets', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        Directionality(
          textDirection: direction,
          child: SingleChildScrollView(
            child: AgentTurnActivity(
              activity: activity(output: 'Full output ' * 80),
            ),
          ),
        ),
        size: const Size(320, 740),
        scale: 2,
        brightness: Brightness.dark,
      );
      final toggle = key('agent-activity-toggle-tool-0');
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      await tester.tap(toggle);
      await tester.pump();
      final copy = key('agent-activity-copy-tool-0');
      expect(tester.getSize(copy).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));
      expect(copy.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
}
