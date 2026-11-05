import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'a timetable preview names and opens its referenced times at $scale',
      (tester) async {
        addTearDown(tester.view.reset);
        await mountAgentUi(
          tester,
          const SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AgentPlanPreview(
                details: {
                  'planId': 'reference-plan',
                  'changes': [
                    {
                      'before': null,
                      'after': {
                        'config': {
                          'name': 'Autumn timetable',
                          'periodTimeSetId': 'set-1',
                        },
                      },
                    },
                  ],
                  'references': {
                    'periodTimeSets': {
                      'set-1': {
                        'status': 'reused',
                        'value': {
                          'id': 'set-1',
                          'name': 'North campus',
                          'periodTimes': [
                            {
                              'index': 1,
                              'startMinutes': 480,
                              'endMinutes': 525,
                            },
                            {
                              'index': 2,
                              'startMinutes': 535,
                              'endMinutes': 580,
                            },
                          ],
                        },
                      },
                    },
                  },
                },
              ),
            ),
          ),
          size: const Size(320, 844),
          scale: scale,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentPlanPreview)),
        );
        await tester.tap(find.text('Autumn timetable'));
        await tester.pumpAndSettle();
        final title = find.text('${l.periodTimeSets}: North campus');
        expect(title, findsOneWidget);
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(
          find.text('${l.periodNumberLabel(1)} · 08:00–08:45'),
          findsOneWidget,
        );
        expect(
          find.text('${l.periodNumberLabel(2)} · 08:55–09:40'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing or mismatched references never fall back to another set',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        const SingleChildScrollView(
          child: AgentPlanPreview(
            details: {
              'planId': 'missing-reference',
              'changes': [
                {
                  'before': null,
                  'after': {
                    'config': {
                      'name': 'Timetable',
                      'periodTimeSetId': 'required-id',
                    },
                  },
                },
              ],
              'references': {
                'periodTimeSets': {
                  'required-id': {
                    'status': 'reused',
                    'value': {'id': 'other-id', 'name': 'Wrong campus'},
                  },
                  'active-id': {
                    'status': 'reused',
                    'value': {'id': 'active-id', 'name': 'Active set'},
                  },
                },
              },
            },
          ),
        ),
      );
      await tester.tap(find.text('Timetable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('required-id'), findsOneWidget);
      expect(find.textContaining('Wrong campus'), findsNothing);
      expect(find.textContaining('Active set'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
