import 'package:sked/agent/operations/tool_outcome.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_inline_disclosure_header.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_setting_labels.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/l10n/app_localizations.dart';

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
      testWidgets('$kind plans and receipts have readable names in $locale', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        final changes = [
          for (final key in _keys(kind)) {'key': key, 'before': 0, 'after': 1},
        ];
        for (final applied in [false, true]) {
          final frame = <String, Object?>{
            'operationId': 'ui-setting',
            'kind': 'external',
            'status': applied ? 'applied' : 'preview',
            if (applied) 'effectStatus': 'applied',
            'changes': changes,
          };
          final original = jsonEncode(frame);
          await mountAgentUi(
            tester,
            SingleChildScrollView(
              child: AgentOperationCard(outcome: ToolOutcome.fromResult(frame)),
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
              find.text(applied ? '${l.agentChangeUpdated} · $label' : label),
              findsOneWidget,
            );
          }
          for (final change in changes) {
            expect(find.textContaining(change['key'] as String), findsNothing);
          }
          expect(jsonEncode(frame), original);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
        final approval = <String, Object?>{
          'planId': 'ui-approval',
          'changes': changes,
        };
        final original = jsonEncode(approval);
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
          expect(
            find.widgetWithText(AgentInlineDisclosureHeader, label),
            findsOneWidget,
          );
        }
        expect(jsonEncode(approval), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
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
        SingleChildScrollView(
          child: AgentOperationCard(outcome: ToolOutcome.fromResult(receipt)),
        ),
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
  'agentPreferences' => [
    l.agentSystemInstructions,
    l.agentHistoryRetentionDays,
  ],
  _ => [
    '${l.themeWorkspaceSchedule} · ${l.startHour}',
    '${l.themeWorkspaceSchedule} · ${l.showWeekends}',
  ],
};

List<String> _keys(String kind) => switch (kind) {
  'layout' => [
    'device.layout.assistant.width',
    'device.layout.assistant.height',
    'device.layout.assistant.dockedWidth',
  ],
  'legacyPreview' => ['device.assistantPreviewEnabled'],
  'connection' => ['agent.connection'],
  'appSettings' => ['app.localeCode', 'app.hideHomeWorkspaceNavigation'],
  'agentPreferences' => [
    'agent.systemInstructions',
    'agent.historyRetentionDays',
  ],
  _ => ['general.dayStartHour', 'general.showWeekends'],
};
