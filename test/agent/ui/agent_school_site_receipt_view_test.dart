import 'package:sked/agent/operations/tool_outcome.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';

import 'agent_ui_test_support.dart';

const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

const _before = [
  SchoolSite(
    id: 'site-kept',
    name: 'Same campus',
    loginUrl: 'https://campus.invalid',
  ),
  SchoolSite(
    id: 'site-edited',
    name: 'Same campus',
    loginUrl: 'https://campus.invalid',
  ),
  SchoolSite(
    id: 'site-removed',
    name: 'Old campus',
    loginUrl: 'https://old.invalid',
  ),
];

const _after = [
  SchoolSite(
    id: 'site-kept',
    name: 'Same campus',
    loginUrl: 'https://campus.invalid',
  ),
  SchoolSite(
    id: 'site-edited',
    name: 'Renamed campus',
    loginUrl: 'https://campus.invalid',
  ),
  SchoolSite(
    id: 'site-added',
    name: 'Same campus',
    loginUrl: 'https://campus.invalid',
  ),
];

void main() {
  for (final locale in _locales) {
    testWidgets(
      'school-site snapshots show identity-based changes in $locale',
      (tester) async {
        addTearDown(tester.view.reset);
        for (final applied in [false, true]) {
          final receipt = _receipt(_before, _after, applied: applied);
          final original = jsonEncode(receipt);
          final opened = <Map<String, Object?>>[];
          await _mountCard(tester, receipt, locale: locale, opened: opened);
          final l = AppLocalizations.of(
            tester.element(find.byType(AgentOperationCard)),
          );
          expect(
            find.text(applied ? l.agentActionApplied : l.agentPlanReady),
            findsOneWidget,
          );
          expect(find.text(l.agentChangeCount(3)), findsOneWidget);
          for (final item in [
            (name: 'Same campus', action: l.agentChangeCreated),
            (name: 'Renamed campus', action: l.agentChangeUpdated),
            (name: 'Old campus', action: l.agentChangeDeleted),
          ]) {
            expect(
              find.text(applied ? '${item.action} · ${item.name}' : item.name),
              findsOneWidget,
            );
          }
          expect(
            find.text('${l.agentChangeUpdated} · Same campus'),
            findsNothing,
          );
          expect(
            find.text('${l.agentChangeDeleted} · Same campus'),
            findsNothing,
          );
          if (!applied) expect(_completedRows(l), findsNothing);
          expect(find.textContaining('schoolSites'), findsNothing);
          expect(find.textContaining('site-kept'), findsNothing);
          expect(find.byType(ExpansionTile), findsNothing);
          expect(find.byTooltip(l.agentViewObject), findsNothing);
          expect(opened, isEmpty);
          expect(jsonEncode(receipt), original);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }
  testWidgets(
    'school-site create patch and delete rows omit unchanged siblings',
    (tester) async {
      addTearDown(tester.view.reset);
      const first = SchoolSite(
        id: 'temporary-campus',
        name: 'Temporary campus',
        loginUrl: 'https://temporary.invalid',
      );
      const revised = SchoolSite(
        id: 'temporary-campus',
        name: 'Temporary campus',
        loginUrl: 'https://temporary-revised.invalid',
      );
      for (final (action, before, after) in [
        ('create', _before, [..._before, first]),
        ('patch', [..._before, first], [..._before, revised]),
        ('delete', [..._before, revised], _before),
      ]) {
        final receipt = _receipt(before, after);
        final original = jsonEncode(receipt);
        final opened = <Map<String, Object?>>[];
        await _mountCard(
          tester,
          receipt,
          locale: const Locale('en'),
          opened: opened,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        final verb = switch (action) {
          'create' => l.agentChangeCreated,
          'delete' => l.agentChangeDeleted,
          _ => l.agentChangeUpdated,
        };
        expect(find.text('$verb · Temporary campus'), findsOneWidget);
        expect(find.text(l.agentChangeCount(1)), findsOneWidget);
        expect(_completedRows(l), findsOneWidget);
        expect(find.textContaining('Same campus'), findsNothing);
        expect(find.textContaining('Old campus'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.byTooltip(l.agentViewObject), findsNothing);
        expect(opened, isEmpty);
        expect(jsonEncode(receipt), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'identical school-site lists show zero changes and a reorder has one row',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final reorder in [false, true]) {
        final receipt = _receipt(
          _before,
          reorder ? [_before[2], _before[0], _before[1]] : _before,
        );
        final original = jsonEncode(receipt);
        final opened = <Map<String, Object?>>[];
        await _mountCard(
          tester,
          receipt,
          locale: const Locale('en'),
          opened: opened,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        expect(find.text(l.agentActionApplied), findsOneWidget);
        expect(find.text(l.agentChangeCount(reorder ? 1 : 0)), findsOneWidget);
        expect(_completedRows(l), reorder ? findsOneWidget : findsNothing);
        if (reorder) {
          expect(
            find.text('${l.agentChangeUpdated} · ${l.schoolSitesPageTitle}'),
            findsOneWidget,
          );
        }
        expect(find.textContaining('Same campus'), findsNothing);
        expect(find.textContaining('Old campus'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.byTooltip(l.agentViewObject), findsNothing);
        expect(opened, isEmpty);
        expect(jsonEncode(receipt), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}

Map<String, Object?> _receipt(
  List<SchoolSite> before,
  List<SchoolSite> after, {
  bool applied = true,
}) => {
  'operationId': 'ui-school-sites',
  'kind': 'external',
  'status': applied ? 'applied' : 'preview',
  if (applied) 'effectStatus': 'applied',
  'changes': [
    {
      'key': 'schoolSites',
      'before': before.map((value) => value.toJson()).toList(),
      'after': after.map((value) => value.toJson()).toList(),
    },
  ],
};
Finder _completedRows(AppLocalizations l) => find.textContaining(
  RegExp(
    '^(${[l.agentChangeCreated, l.agentChangeUpdated, l.agentChangeDeleted].map(RegExp.escape).join('|')}) · ',
  ),
);
Future<void> _mountCard(
  WidgetTester tester,
  Map<String, Object?> receipt, {
  required Locale locale,
  required List<Map<String, Object?>> opened,
}) => mountAgentUi(
  tester,
  SingleChildScrollView(
    child: AgentOperationCard(
      outcome: ToolOutcome.fromResult(receipt),
      onOpenResource: opened.add,
    ),
  ),
  locale: locale,
  scale: 2,
  size: const Size(390, 844),
);
