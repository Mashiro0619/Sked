import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('receipt actions stay reachable at $scale text scale', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      var undone = false;
      const receipt = <String, Object?>{
        'status': 'committed',
        'operationId': 'layout/receipt',
        'changeCount': 1,
        'changes': [
          {'action': 'created', 'label': 'Mathematics'},
        ],
        'notificationEffect': {'state': 'pending'},
      };
      await mountAgentUi(
        tester,
        SingleChildScrollView(
          child: AgentOperationCard(
            receipt: receipt,
            onUndo: () => undone = true,
          ),
        ),
        size: Size(scale == 1 ? 390 : 320, 844),
        scale: scale,
        locale: const Locale('zh'),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      final undo = find.widgetWithText(TextButton, l.agentUndo);
      final detail = find.byKey(const ValueKey('agent-receipt-details'));
      expect(tester.getSize(undo).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(detail).height, greaterThanOrEqualTo(48));
      if (scale == 1) {
        expect(
          (tester.getRect(undo).top - tester.getRect(detail).top).abs(),
          lessThan(1),
        );
      }
      expect(find.text(l.agentNotificationEffect('pending')), findsOneWidget);
      expect(find.text(l.agentChangesSaved), findsOneWidget);
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(
        find.text(const JsonEncoder.withIndent('  ').convert(receipt)),
        findsOneWidget,
      );
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(
        find.text(const JsonEncoder.withIndent('  ').convert(receipt)),
        findsNothing,
      );
      await tester.tap(undo);
      expect(undone, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'a committed receipt shows real object labels and actionable undo',
    (tester) async {
      var undone = false;
      Map<String, Object?>? opened;
      await mountAgentUi(
        tester,
        AgentOperationCard(
          receipt: const {
            'status': 'committed',
            'operationId': 'data/1/action',
            'changeCount': 1,
            'changes': [
              {
                'action': 'created',
                'label': 'Review mathematics',
                'ref': {
                  'kind': 'event',
                  'id': 'event-1',
                  'parentId': 'calendar-1',
                },
              },
            ],
          },
          onUndo: () => undone = true,
          onOpenResource: (ref) => opened = ref,
        ),
        scale: 2,
        size: const Size(390, 844),
      );
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Added · Review mathematics'), findsOneWidget);
      await tester.tap(find.byTooltip('View item'));
      expect(opened?['id'], 'event-1');
      await tester.tap(find.text('Undo these changes'));
      expect(undone, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a persisted pending effect is never described as applied', (
    tester,
  ) async {
    await mountAgentUi(
      tester,
      AgentOperationCard(
        receipt: const {
          'kind': 'external',
          'operationId': 'data/2/permission',
          'status': 'partial',
          'effectStatus': 'unknown',
          'dataStatus': 'committed',
        },
        onUndo: () {},
      ),
    );
    expect(find.text('Result needs checking'), findsOneWidget);
    expect(find.text('Action completed'), findsNothing);
    expect(find.text('Undo these changes'), findsNothing);
  });

  testWidgets('a prepared plan and a rejected result have distinct outcomes', (
    tester,
  ) async {
    await mountAgentUi(
      tester,
      const Column(
        children: [
          AgentOperationCard(
            receipt: {
              'planId': 'plan',
              'operationId': 'data/1/plan',
              'changeCount': 2,
            },
          ),
          AgentOperationCard(
            receipt: {
              'status': 'error',
              'error': {'code': 'readOnly'},
            },
          ),
        ],
      ),
    );
    expect(find.text('Changes prepared'), findsOneWidget);
    expect(find.text('Change details'), findsOneWidget);
    expect(find.text('Activity details'), findsOneWidget);
    expect(find.text('Action not completed'), findsOneWidget);
    expect(find.text('Changes saved'), findsNothing);
  });

  test('assistant prose is not parsed as an operation receipt', () {
    expect(AgentOperationCard.parse('Everything was saved.'), isNull);
    expect(AgentOperationCard.parse('{"text":"Saved"}'), isNull);
  });

  testWidgets('pending reminders do not hide a confirmed business save', (
    tester,
  ) async {
    await mountAgentUi(
      tester,
      const AgentOperationCard(
        receipt: {
          'status': 'committed',
          'operationId': 'data/1/action',
          'changeCount': 1,
          'notificationEffect': {'state': 'pending'},
        },
      ),
    );
    expect(find.text('Changes saved'), findsOneWidget);
    expect(find.text('Reminder scheduling is pending.'), findsOneWidget);
    expect(find.text('Result needs checking'), findsNothing);
  });

  for (final status in ['outcome_unknown', 'outcomeUnknown']) {
    testWidgets(
      'a persisted $status error remains uncertain and cannot claim or open a changed target',
      (tester) async {
        addTearDown(tester.view.reset);
        final receipt = <String, Object?>{
          'operationId': 'data/legacy/uncertain',
          'status': status,
          'error': {'code': 'operationRecoveryRequired'},
          'changes': [
            {
              'action': 'created',
              'label': 'Unconfirmed study event',
              'ref': {
                'kind': 'event',
                'id': 'unconfirmed',
                'parentId': 'calendar',
              },
            },
          ],
        };
        final before = jsonEncode(receipt);
        var undone = false;
        Map<String, Object?>? opened;
        await mountAgentUi(
          tester,
          AgentOperationCard(
            receipt: receipt,
            onUndo: () => undone = true,
            onOpenResource: (ref) => opened = ref,
          ),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        expect(find.text(l.agentActionUncertain), findsOneWidget);
        expect(find.byIcon(Icons.pending_outlined), findsOneWidget);
        expect(find.text(l.agentActionFailed), findsNothing);
        expect(find.text(l.agentActionApplied), findsNothing);
        expect(find.text(l.agentChangesSaved), findsNothing);
        expect(find.byIcon(Icons.check_circle_outline), findsNothing);
        expect(find.text('Unconfirmed study event'), findsOneWidget);
        expect(
          find.text('${l.agentChangeCreated} · Unconfirmed study event'),
          findsNothing,
        );
        expect(find.byTooltip(l.agentViewObject), findsNothing);
        expect(find.text(l.agentUndo), findsNothing);
        expect(undone, isFalse);
        expect(opened, isNull);
        expect(jsonEncode(receipt), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final state in [
    (
      label: 'unknown effect',
      fields: <String, Object?>{'effectStatus': 'unknown'},
    ),
    (
      label: 'pending effect',
      fields: <String, Object?>{'effectStatus': 'pending'},
    ),
    (
      label: 'recovery reservation',
      fields: <String, Object?>{'recoveryRequired': true},
    ),
    (
      label: 'unfinished receipt',
      fields: <String, Object?>{'receiptFinalized': false},
    ),
    (
      label: 'unknown data write',
      fields: <String, Object?>{
        'status': 'applied',
        'effectStatus': 'applied',
        'dataStatus': 'unknown',
        'receiptFinalized': true,
        'recoveryRequired': false,
      },
    ),
    (
      label: 'pending effect status',
      fields: <String, Object?>{'status': 'effectsPending'},
    ),
  ]) {
    testWidgets(
      'an external ${state.label} uses the durable runtime review wording',
      (tester) async {
        addTearDown(tester.view.reset);
        final receipt = <String, Object?>{
          'kind': 'external',
          'operationId': 'data/external/review',
          ...state.fields,
        };
        final before = jsonEncode(receipt);
        await mountAgentUi(
          tester,
          AgentOperationCard(receipt: receipt, onUndo: () {}),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        expect(find.text(l.agentActionUncertain), findsOneWidget);
        expect(find.byIcon(Icons.pending_outlined), findsOneWidget);
        expect(find.text(l.agentActionFailed), findsNothing);
        expect(find.text(l.agentActionApplied), findsNothing);
        expect(find.text(l.agentChangesSaved), findsNothing);
        expect(find.text(l.agentUndo), findsNothing);
        expect(jsonEncode(receipt), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final status in <String?>['failed', 'not_executed', null]) {
    testWidgets(
      'a ${status ?? 'plain'} error is not a completed or uncertain action',
      (tester) async {
        addTearDown(tester.view.reset);
        final receipt = <String, Object?>{
          'status': ?status,
          'error': {
            'code': status == 'not_executed' ? 'cancelled' : 'toolFailed',
          },
        };
        await mountAgentUi(
          tester,
          AgentOperationCard(receipt: receipt, onUndo: () {}),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        expect(find.text(l.agentActionFailed), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text(l.agentActivityDetails), findsOneWidget);
        expect(find.text(l.agentPlanDetails), findsNothing);
        await tester.tap(find.text(l.agentActivityDetails));
        await tester.pumpAndSettle();
        expect(
          find.text(const JsonEncoder.withIndent('  ').convert(receipt)),
          findsOneWidget,
        );
        expect(find.text(l.agentActionUncertain), findsNothing);
        expect(find.text(l.agentActionApplied), findsNothing);
        expect(find.text(l.agentChangesSaved), findsNothing);
        expect(find.text(l.agentUndo), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a finalized external effect remains completed without a main-data undo',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        AgentOperationCard(
          receipt: const {
            'kind': 'external',
            'operationId': 'data/external/applied',
            'status': 'applied',
            'effectStatus': 'applied',
            'dataStatus': 'unchanged',
            'receiptFinalized': true,
            'recoveryRequired': false,
          },
          onUndo: () {},
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      expect(find.text(l.agentActionApplied), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text(l.agentActionUncertain), findsNothing);
      expect(find.text(l.agentActionFailed), findsNothing);
      expect(find.text(l.agentChangesSaved), findsNothing);
      expect(find.text(l.agentUndo), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
