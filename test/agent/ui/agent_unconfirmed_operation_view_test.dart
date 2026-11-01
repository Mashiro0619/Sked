import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';

import '../acceptance/acceptance_harness.dart';
import 'agent_ui_test_support.dart';

const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

void main() {
  for (final locale in _locales) {
    testWidgets(
      'real resource preparation and approval keep changes unconfirmed in $locale',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        await _realAsync(
          tester,
          () => h.initialize(
            data: _previewData(),
            knowledgeStorage: MemoryKnowledgeStorage(),
          ),
        );
        addTearDown(h.close);
        final originalData = h.saved.encode();
        final originalKnowledge = h.app.agent.knowledgeRepository.snapshot
            .encode();
        late Map<String, Object?> prepared;
        late AgentUiApproval approval;
        await _realAsync(tester, () async {
          final runtime = h.app.agent.runtime;
          await runtime.setMode(h.conversationId, AgentPermissionMode.ask);
          final announced = Completer<AgentUiApproval>();
          void captureApproval() {
            final pending = runtime.state.value
                .runFor(h.conversationId)
                .pendingApproval;
            if (pending != null && !announced.isCompleted) {
              announced.complete(pending);
            }
          }

          runtime.state.addListener(captureApproval);
          try {
            final running = h.run(() async {
              prepared = await h.call('mutation.prepare', {
                'commands': [
                  {
                    'kind': 'calendar',
                    'action': 'create',
                    'values': {'name': 'Uncommitted calendar'},
                  },
                  {
                    'kind': 'calendar',
                    'action': 'patch',
                    'target': {'id': 'visible'},
                    'values': {'name': 'Planned studies'},
                  },
                  {
                    'kind': 'calendar',
                    'action': 'delete',
                    'target': {'id': 'remove-me'},
                  },
                ],
              });
              await expectLater(
                h.call('mutation.commit', {'planId': prepared['planId']}),
                throwsA(
                  isA<OperationProblem>().having(
                    (error) => error.code,
                    'code',
                    OperationErrorCode.cancelled,
                  ),
                ),
              );
            });
            approval = await Future.any<AgentUiApproval>([
              announced.future,
              running.then<AgentUiApproval>(
                (_) => throw StateError('The real approval was not presented.'),
              ),
            ]);
            await runtime.reject(h.conversationId, approval.id);
            await running;
          } finally {
            runtime.state.removeListener(captureApproval);
          }
        });
        expect(prepared['status'], isNull);
        expect(approval.id, prepared['planId']);
        final changes = (prepared['changes'] as List).cast<Map>();
        expect(
          changes.map((change) => change['action']),
          containsAll(['created', 'updated', 'deleted']),
        );
        expect(
          changes.firstWhere((change) => change['action'] == 'created')['ref'],
          isA<Map>(),
        );
        final preparedJson = jsonEncode(prepared);
        final approvalJson = jsonEncode(approval.details);
        final opened = <Map<String, Object?>>[];
        await _mountCard(tester, h, prepared, locale: locale, opened: opened);
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
        expect(jsonEncode(prepared), preparedJson);
        expect(h.saved.encode(), originalData);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await mountAgentUi(
          tester,
          SingleChildScrollView(
            child: AgentPlanPreview(details: approval.details),
          ),
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
        for (final item in [
          (name: 'Uncommitted calendar', verb: l.agentKnowledgeAdd),
          (name: 'Planned studies', verb: l.agentKnowledgeEdit),
          (name: 'Remove calendar', verb: l.delete),
        ]) {
          final tile = find.widgetWithText(ExpansionTile, item.name);
          expect(
            find.descendant(of: tile, matching: find.text(item.verb)),
            findsOneWidget,
          );
          await tester.ensureVisible(tile);
          await tester.tap(find.text(item.name));
          await tester.pumpAndSettle();
          final displayed = tester.widget<SelectableText>(
            find.descendant(of: tile, matching: find.byType(SelectableText)),
          );
          final original = (approval.details['changes'] as List)
              .cast<Map>()
              .singleWhere((change) {
                final after = change['after'], before = change['before'];
                return (after is Map && after['name'] == item.name) ||
                    (before is Map && before['name'] == item.name);
              });
          expect(jsonDecode(displayed.data!), {
            l.agentValueBefore: original['before'],
            l.agentValueAfter: original['after'],
          });
          await tester.tap(find.text(item.name));
          await tester.pumpAndSettle();
        }
        expect(jsonEncode(prepared), preparedJson);
        expect(jsonEncode(approval.details), approvalJson);
        expect(h.saved.encode(), originalData);
        expect(
          h.app.agent.knowledgeRepository.snapshot.encode(),
          originalKnowledge,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a real committed resource stays saved and opens with unknown reminder observation in $locale',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        await _realAsync(
          tester,
          () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
        );
        addTearDown(h.close);
        late Map<String, Object?> receipt;
        await _realAsync(tester, () async {
          await h.run(() async {
            final prepared = await h.call('mutation.prepare', {
              'commands': [
                {
                  'kind': 'calendar',
                  'action': 'create',
                  'values': {'name': 'Saved calendar'},
                },
              ],
            });
            receipt = await h.commit(prepared);
          });
        });
        expect(receipt['status'], 'committed');
        // An unbound observer supplies the real host's unknown notification
        // projection. It does not change the already committed business result.
        h.app.agent.tools.bindNotificationEffects();
        final described = h.app.agent.tools.describeCommitResult(receipt);
        expect((described['notificationEffect'] as Map)['state'], 'unknown');
        expect(described['status'], 'committed');
        final change = (receipt['changes'] as List).single as Map;
        final expectedRef = Map<String, Object?>.from(change['ref'] as Map);
        final originalReceipt = jsonEncode(receipt);
        final originalData = h.saved.encode();
        final opened = <Map<String, Object?>>[];
        await _mountCard(tester, h, receipt, locale: locale, opened: opened);
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        expect(find.text(l.agentChangesSaved), findsOneWidget);
        expect(find.text(l.agentActionUncertain), findsNothing);
        expect(find.text(l.agentNotificationEffect('unknown')), findsOneWidget);
        expect(
          find.text('${l.agentChangeCreated} · Saved calendar'),
          findsOneWidget,
        );
        final button = find.byTooltip(l.agentViewObject);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(opened, [expectedRef]);
        final view = tester.widget<AgentResourceView>(
          find.byType(AgentResourceView),
        );
        expect(view.ref.toJson(), expectedRef);
        expect(find.text('Saved calendar'), findsOneWidget);
        expect(jsonEncode(receipt), originalReceipt);
        expect(h.saved.encode(), originalData);
        Navigator.of(tester.element(find.byType(AgentResourceView))).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'a real applied export keeps its confirmed effect when final receipt storage is partial',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = AcceptanceHarness();
      await _realAsync(
        tester,
        () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
      );
      addTearDown(h.close);
      late Map<String, Object?> receipt;
      await _realAsync(tester, () async {
        h.app.agent.workflowTools.bindServices(
          saveArtifact: (artifact) async {
            h.writtenArtifacts.add(artifact);
            h.storage.saveError = StateError(
              'Synthetic final receipt failure.',
            );
            return const AgentArtifactWriteResult(
              saved: true,
              destination: 'memory://confirmed-export',
            );
          },
        );
        await h.run(() async {
          final artifact = await h.call('exports.prepare', {
            'format': 'schedules_json',
            'ids': ['visible'],
          });
          final prepared = await h.call('exports.write', {
            'artifactId': artifact['artifactId'],
          });
          receipt = await h.externalCommit(prepared);
        });
      });
      expect(receipt['status'], 'partial');
      expect(receipt['effectStatus'], 'applied');
      expect(receipt['receiptFinalized'], isFalse);
      expect(receipt['recoveryRequired'], isTrue);
      expect(h.writtenArtifacts, hasLength(1));
      expect(h.writtenArtifacts.single.text, isNotEmpty);
      expect(
        h.app.agent.external
            .status(receipt['operationId'] as String)!
            .result['effectStatus'],
        'pending',
      );
      final originalReceipt = jsonEncode(receipt);
      final originalData = h.saved.encode();
      final opened = <Map<String, Object?>>[];
      await _mountCard(
        tester,
        h,
        receipt,
        locale: const Locale('en'),
        opened: opened,
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      expect(find.text(l.agentActionUncertain), findsOneWidget);
      expect(_completedRows(l), findsOneWidget);
      expect(opened, isEmpty);
      expect(jsonEncode(receipt), originalReceipt);
      expect(h.saved.encode(), originalData);
      expect(h.writtenArtifacts, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

AppData _previewData() {
  final data = acceptanceData();
  return data.copyWith(
    generalMode: data.generalMode.copyWith(
      schedules: [
        ...data.generalMode.schedules,
        const GeneralSchedule(
          id: 'remove-me',
          name: 'Remove calendar',
          events: [],
        ),
      ],
    ),
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

Future<void> _mountCard(
  WidgetTester tester,
  AcceptanceHarness h,
  Map<String, Object?> receipt, {
  required Locale locale,
  required List<Map<String, Object?>> opened,
}) => mountAgentUi(
  tester,
  Provider<AppSession>.value(
    value: h.app.session,
    child: Builder(
      builder: (context) => SingleChildScrollView(
        child: AgentOperationCard(
          receipt: h.app.agent.tools.describeCommitResult(receipt),
          onOpenResource: (ref) {
            opened.add(ref);
            unawaited(AgentResourceView.open(context, ref));
          },
        ),
      ),
    ),
  ),
  locale: locale,
  scale: 2,
  size: const Size(390, 844),
);

Future<void> _realAsync(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    try {
      await action();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
  });
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}
