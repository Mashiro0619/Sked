import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_setting_labels.dart';
import 'package:sked/application/approval_plan.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/desktop_layout_preferences.dart';

import '../acceptance/acceptance_harness.dart';
import 'agent_ui_test_support.dart';

const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every writable registered setting has a readable label without claiming support', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final missing = [
      for (final descriptor in SettingRegistry().descriptors)
        if (!descriptor.readOnly &&
            agentSettingLabel({'key': descriptor.key}, l) == null)
          descriptor.key,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'New writable settings need an explicit user-facing name.',
    );
    expect(
      agentSettingLabel({'key': 'device.layout.unregistered.width'}, l),
      isNull,
    );
    expect(
      agentSettingLabel({'key': 'device.layout.assistant.unregistered'}, l),
      isNull,
    );
    expect(agentSettingLabel({'key': 'unregistered.futureSetting'}, l), isNull);
  });

  for (final locale in _locales) {
    for (final kind in [
      'layout',
      'legacyPreview',
      'connection',
      'appSettings',
      'agentPreferences',
      'scheduleDisplay',
    ]) {
      testWidgets(
        'actual $kind plans and receipts have readable names in $locale',
        (tester) async {
          addTearDown(tester.view.reset);
          final h = AcceptanceHarness();
          await _realAsync(tester, h.initialize);
          try {
            late Map<String, Object?> prepared;
            late Map<String, Object?> receipt;
            late Map<String, Object?> approval;
            final enabledBefore = h.saved.agentSettings.enabled;
            final localeTarget = h.saved.localeCode == 'zh' ? 'en' : 'zh';
            final hideTarget = !h.saved.hideHomeWorkspaceNavigation;
            final weekendsTarget = !h.saved.generalMode.showWeekends;
            await _realAsync(
              tester,
              () => h.run(() async {
                final before = h.saved.encode();
                final (tool, arguments, external) = switch (kind) {
                  'layout' => (
                    'device.layout.prepare',
                    <String, Object?>{
                      'region': 'assistant',
                      'action': 'set',
                      'values': {
                        'width': 420,
                        'height': 620,
                        'dockedWidth': 440,
                      },
                    },
                    true,
                  ),
                  'legacyPreview' => (
                    'device.preferences.prepare',
                    <String, Object?>{'action': 'set', 'value': true},
                    true,
                  ),
                  'connection' => (
                    'connection.prepare',
                    <String, Object?>{
                      'action': 'set',
                      'endpoint': 'https://receipt.invalid/v1',
                      'model': 'receipt-model',
                      'models': [
                        {
                          'id': 'receipt-model',
                          'reasoningEfforts': ['medium'],
                          'defaultReasoningEffort': 'medium',
                        },
                      ],
                    },
                    true,
                  ),
                  'appSettings' => (
                    'settings.prepare',
                    <String, Object?>{
                      'edits': [
                        {
                          'key': 'app.localeCode',
                          'action': 'set',
                          'value': localeTarget,
                        },
                        {
                          'key': 'app.hideHomeWorkspaceNavigation',
                          'action': 'set',
                          'value': hideTarget,
                        },
                      ],
                    },
                    false,
                  ),
                  'agentPreferences' => (
                    'agent_settings.prepare',
                    <String, Object?>{
                      'edits': [
                        {
                          'key': 'agent.systemInstructions',
                          'action': 'set',
                          'value': 'Use confirmed host receipts.',
                        },
                        {
                          'key': 'agent.maxModelRounds',
                          'action': 'set',
                          'value': 7,
                        },
                      ],
                    },
                    false,
                  ),
                  _ => (
                    'settings.prepare',
                    <String, Object?>{
                      'edits': [
                        {
                          'key': 'general.dayStartHour',
                          'action': 'set',
                          'value': 7,
                        },
                        {
                          'key': 'general.showWeekends',
                          'action': 'set',
                          'value': weekendsTarget,
                        },
                      ],
                    },
                    false,
                  ),
                };
                prepared = await h.call(tool, arguments);
                expect(h.saved.encode(), before);
                final id = prepared['planId'] as String;
                final ApprovalPlan plan = external
                    ? h.app.agent.external.plan(id)!
                    : h.app.agent.tools.mutations.plan(id)!;
                // Use the actual host plan's concrete changes, as the runtime does
                // when publishing an approval; do not add invented display labels.
                approval = {
                  ...plan.summary(),
                  'changes': [
                    for (final change in plan.changes) change.toJson(),
                  ],
                };
                receipt = external
                    ? await h.externalCommit(prepared)
                    : await h.commit(prepared);
                if (external) expect(receipt['effectStatus'], 'applied');
              }),
            );
            switch (kind) {
              case 'layout':
                expect(
                  h.layout.preferenceFor(DesktopLayoutRegion.assistant),
                  const PreferredRegionSize(
                    width: 420,
                    height: 620,
                    dockedWidth: 440,
                  ),
                );
              case 'legacyPreview':
                expect(h.developer.assistantVisible, isTrue);
                expect(h.saved.agentSettings.enabled, enabledBefore);
              case 'connection':
                expect(
                  h.saved.agentSettings.endpoint,
                  'https://receipt.invalid/v1',
                );
                expect(h.saved.agentSettings.model, 'receipt-model');
              case 'appSettings':
                expect(h.saved.localeCode, localeTarget);
                expect(h.saved.hideHomeWorkspaceNavigation, hideTarget);
              case 'agentPreferences':
                expect(
                  h.saved.agentSettings.systemInstructions,
                  'Use confirmed host receipts.',
                );
                expect(h.saved.agentSettings.maxModelRounds, 7);
              case 'scheduleDisplay':
                expect(h.saved.generalMode.dayStartHour, 7);
                expect(h.saved.generalMode.showWeekends, weekendsTarget);
            }
            final saved = h.saved.encode();
            final conversations = h.conversations.source;
            for (final (frame, applied) in [
              (prepared, false),
              (receipt, true),
            ]) {
              final original = jsonEncode(frame);
              await mountAgentUi(
                tester,
                SingleChildScrollView(
                  child: AgentOperationCard(receipt: frame),
                ),
                locale: locale,
                scale: 2,
                size: const Size(390, 844),
              );
              final l = AppLocalizations.of(
                tester.element(find.byType(AgentOperationCard)),
              );
              for (final label in _labels(kind, l)) {
                expect(
                  find.text(
                    applied ? '${l.agentChangeUpdated} · $label' : label,
                  ),
                  findsOneWidget,
                );
              }
              for (final change in (frame['changes'] as List).cast<Map>()) {
                expect(
                  find.textContaining(change['key'] as String),
                  findsNothing,
                );
              }
              expect(jsonEncode(frame), original);
              expect(h.saved.encode(), saved);
              expect(h.conversations.source, conversations);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
            }
            final originalApproval = jsonEncode(approval);
            await mountAgentUi(
              tester,
              SingleChildScrollView(child: AgentPlanPreview(details: approval)),
              locale: locale,
              scale: 2,
              size: const Size(390, 844),
            );
            final l = AppLocalizations.of(
              tester.element(find.byType(AgentPlanPreview)),
            );
            for (final label in _labels(kind, l)) {
              expect(find.widgetWithText(ExpansionTile, label), findsOneWidget);
            }
            expect(jsonEncode(approval), originalApproval);
            expect(h.saved.encode(), saved);
            expect(h.conversations.source, conversations);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await _realAsync(
              tester,
              () => h.close().timeout(const Duration(seconds: 10)),
            );
          }
        },
      );
    }
  }

  testWidgets(
    'unknown historical keys stay inspectable and unsupported outcomes stay failed',
    (tester) async {
      addTearDown(tester.view.reset);
      // This is a historical UI envelope, not a claim that an unsupported tool
      // was admitted. New metadata must not manufacture support or a success.
      final receipt = <String, Object?>{
        'operationId': 'historical-unsupported',
        'kind': 'external',
        'status': 'failed',
        'effectStatus': 'failed',
        'effectResult': {'code': 'unsupported'},
        'changes': [
          {
            'key': 'device.layout.futureRegion.width',
            'before': 300,
            'after': 420,
          },
        ],
      };
      final original = jsonEncode(receipt);
      await mountAgentUi(
        tester,
        SingleChildScrollView(child: AgentOperationCard(receipt: receipt)),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      expect(find.text(l.agentActionFailed), findsOneWidget);
      expect(find.text(l.agentActionApplied), findsNothing);
      expect(find.text('device.layout.futureRegion.width'), findsOneWidget);
      await tester.tap(find.text(l.agentPlanDetails));
      await tester.pumpAndSettle();
      expect(find.textContaining('unsupported'), findsOneWidget);
      expect(jsonEncode(receipt), original);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

List<String> _labels(String kind, AppLocalizations l) => switch (kind) {
  'layout' => [
    '${l.agentTitle} · ${l.agentLayoutWidth}',
    '${l.agentTitle} · ${l.agentLayoutHeight}',
    '${l.agentTitle} · ${l.agentLayoutDockedWidth}',
  ],
  'legacyPreview' => [l.assistantLayoutPreview],
  'connection' => [l.agentModelSettings],
  'appSettings' => [l.language, l.hideHomeWorkspaceNavigation],
  'agentPreferences' => [l.agentSystemInstructions, l.agentMaxModelRounds],
  _ => [
    '${l.themeWorkspaceSchedule} · ${l.startHour}',
    '${l.themeWorkspaceSchedule} · ${l.showWeekends}',
  ],
};

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
