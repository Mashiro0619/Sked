import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';

import 'agent_receipt_view_support.dart';
import 'agent_ui_test_support.dart';

const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

void main() {
  for (final locale in _locales) {
    testWidgets('resource preparation keeps changes unconfirmed in $locale', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final changes = <Map<String, Object?>>[
        {
          'action': 'created',
          'ref': {'kind': 'calendar', 'id': 'new'},
          'before': null,
          'after': {'name': 'Uncommitted calendar'},
        },
        {
          'action': 'updated',
          'ref': {'kind': 'calendar', 'id': 'visible'},
          'before': {'name': 'Studies'},
          'after': {'name': 'Planned studies'},
        },
        {
          'action': 'deleted',
          'ref': {'kind': 'calendar', 'id': 'remove-me'},
          'before': {'name': 'Remove calendar'},
          'after': null,
        },
      ];
      final prepared = <String, Object?>{
        'planId': 'ui-plan',
        'changes': changes,
      };
      final source = jsonEncode(prepared);
      final opened = <Map<String, Object?>>[];
      await mountReceiptView(tester, prepared, locale: locale, opened: opened);
      var l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      expect(find.text(l.agentPlanReady), findsOneWidget);
      for (final name in [
        'Uncommitted calendar',
        'Planned studies',
        'Remove calendar',
      ]) {
        expect(find.text(name), findsOneWidget);
      }
      expect(_completedRows(l), findsNothing);
      expect(find.byTooltip(l.agentViewObject), findsNothing);
      expect(opened, isEmpty);
      expect(jsonEncode(prepared), source);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await mountAgentUi(
        tester,
        SingleChildScrollView(child: AgentPlanPreview(details: prepared)),
        locale: locale,
        scale: 2,
        size: const Size(390, 844),
      );
      l = AppLocalizations.of(tester.element(find.byType(AgentPlanPreview)));
      for (final completed in [
        l.agentChangeCreated,
        l.agentChangeUpdated,
        l.agentChangeDeleted,
      ]) {
        expect(find.text(completed), findsNothing);
      }
      final items = [
        (name: 'Uncommitted calendar', verb: l.agentKnowledgeAdd),
        (name: 'Planned studies', verb: l.agentKnowledgeEdit),
        (name: 'Remove calendar', verb: l.delete),
      ];
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final tile = find.byKey(ValueKey('agent-plan-preview-change-$index'));
        expect(
          find.descendant(of: tile, matching: find.text(item.verb)),
          findsOneWidget,
        );
        await tester.ensureVisible(tile);
        await tester.tap(find.text(item.name).first);
        await tester.pumpAndSettle();
        final details = find.descendant(
          of: tile,
          matching: find.widgetWithText(ExpansionTile, l.agentPlanDetails),
        );
        await tester.ensureVisible(details);
        await tester.tap(
          find.descendant(of: details, matching: find.text(l.agentPlanDetails)),
        );
        await tester.pumpAndSettle();
        final displayed = tester.widget<SelectableText>(
          find.descendant(of: details, matching: find.byType(SelectableText)),
        );
        expect(jsonDecode(displayed.data!), {
          l.agentValueBefore: changes[index]['before'],
          l.agentValueAfter: changes[index]['after'],
        });
        await tester.ensureVisible(find.text(item.name).first);
        await tester.tap(find.text(item.name).first);
        await tester.pumpAndSettle();
      }
      expect(jsonEncode(prepared), source);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'committed resources open with unknown reminder observation in $locale',
      (tester) async {
        addTearDown(tester.view.reset);
        final initial = buildInitialAppData(buildDefaultPeriodTimes());
        final app = await receiptWorkspace(
          tester,
          initial.copyWith(
            generalMode: initial.generalMode.copyWith(
              schedules: const [
                GeneralSchedule(
                  id: 'saved',
                  name: 'Saved calendar',
                  events: [],
                ),
              ],
            ),
          ),
        );
        const expectedRef = <String, Object?>{
          'kind': 'calendar',
          'id': 'saved',
        };
        final receipt = <String, Object?>{
          'status': 'committed',
          'operationId': 'ui-resource',
          'generation': 'ui',
          'sequence': 1,
          'changes': [
            {
              'action': 'created',
              'ref': expectedRef,
              'label': 'Saved calendar',
              'before': null,
              'after': {'name': 'Saved calendar'},
            },
          ],
        };
        app.agent.tools.bindNotificationEffects();
        final described = app.agent.tools.describeCommitResult(receipt);
        expect((described['notificationEffect'] as Map)['state'], 'unknown');
        final source = jsonEncode(receipt);
        final saved = app.session.committedData.encode();
        final opened = <Map<String, Object?>>[];
        await mountReceiptView(
          tester,
          receipt,
          locale: locale,
          opened: opened,
          app: app,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        expect(find.text(l.agentChangesSaved), findsOneWidget);
        expect(find.text(l.agentActionUncertain), findsNothing);
        expect(find.text(l.agentNotificationEffect('unknown')), findsNothing);
        expect(
          find.text('${l.agentChangeCreated} · Saved calendar'),
          findsOneWidget,
        );
        final button = find.byTooltip(l.agentViewObject);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(opened, [expectedRef]);
        expect(
          tester
              .widget<AgentResourceView>(find.byType(AgentResourceView))
              .ref
              .toJson(),
          expectedRef,
        );
        expect(find.text('Saved calendar'), findsOneWidget);
        expect(jsonEncode(receipt), source);
        expect(app.session.committedData.encode(), saved);
        Navigator.of(tester.element(find.byType(AgentResourceView))).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'an applied export retains its effect while receipt finalization is partial',
    (tester) async {
      addTearDown(tester.view.reset);
      final receipt = <String, Object?>{
        'operationId': 'ui-export',
        'kind': 'external',
        'status': 'partial',
        'effectStatus': 'applied',
        'receiptFinalized': false,
        'recoveryRequired': true,
        'changes': [
          {
            'key': 'export.artifact',
            'before': null,
            'after': {'destination': 'memory://confirmed-export'},
          },
        ],
      };
      final source = jsonEncode(receipt);
      final opened = <Map<String, Object?>>[];
      await mountReceiptView(
        tester,
        receipt,
        locale: const Locale('en'),
        opened: opened,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      expect(find.text(l.agentActionUncertain), findsOneWidget);
      expect(_completedRows(l), findsNothing);
      expect(
        tester
            .widget<AgentOperationCard>(find.byType(AgentOperationCard))
            .receipt['effectStatus'],
        'applied',
      );
      expect(opened, isEmpty);
      expect(jsonEncode(receipt), source);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _completedRows(AppLocalizations l) {
  final actions = [
    l.agentChangeCreated,
    l.agentChangeUpdated,
    l.agentChangeDeleted,
  ].map(RegExp.escape).join('|');
  return find.textContaining(RegExp('^($actions) · '));
}
