import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';

import 'agent_ui_test_support.dart';

void main() {
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
    expect(find.text('Action not completed'), findsOneWidget);
    expect(find.text('Changes saved'), findsNothing);
  });

  test('assistant prose is not parsed as an operation receipt', () {
    expect(AgentOperationCard.parse('Everything was saved.'), isNull);
    expect(AgentOperationCard.parse('{"text":"Saved"}'), isNull);
  });
}
