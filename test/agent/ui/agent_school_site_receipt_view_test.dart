import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';

import '../acceptance/acceptance_harness.dart';
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
      'real school-site import receipts show only identity-based changes in $locale',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        await _realAsync(
          tester,
          () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
        );
        addTearDown(h.close);
        await _realAsync(tester, () => h.run(() => _replaceSites(h, _before)));
        for (final applied in [false, true]) {
          late Map<String, Object?> receipt;
          await _realAsync(tester, () async {
            await h.run(() async {
              final plan = await _prepareSites(h, _after);
              receipt = applied ? await h.externalCommit(plan) : plan;
              if (applied) {
                expect(receipt['effectStatus'], 'applied');
              } else {
                expect(receipt['status'], isNull);
                expect(receipt['effectStatus'], isNull);
              }
              expect(await _readSites(h), _json(applied ? _after : _before));
            });
          });
          // Preparation counts the whole-list change; the committed external
          // receipt carries the same snapshots without a top-level count.
          expect(receipt['changeCount'], applied ? isNull : equals(1));
          final change = (receipt['changes'] as List).single as Map;
          expect(change['key'], 'schoolSites');
          expect(change['before'], _json(_before));
          expect(change['after'], _json(_after));
          expect(change.containsKey('label'), isFalse);
          expect(change.containsKey('action'), isFalse);
          expect(change.containsKey('ref'), isFalse);
          final originalReceipt = jsonEncode(receipt);
          final originalData = h.saved.encode();
          final opened = <Map<String, Object?>>[];
          await _mountCard(tester, h, receipt, locale: locale, opened: opened);
          final l = AppLocalizations.of(
            tester.element(find.byType(AgentOperationCard)),
          );
          expect(
            find.text(applied ? l.agentActionApplied : l.agentPlanReady),
            findsOneWidget,
          );
          // One stored whole-list change expands into three actual object rows.
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
          expect(jsonEncode(receipt), originalReceipt);
          expect(h.saved.encode(), originalData);
          expect(h.writtenArtifacts, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }

  testWidgets(
    'real school-site create patch and delete receipts retain unchanged siblings',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = AcceptanceHarness();
      await _realAsync(
        tester,
        () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
      );
      addTearDown(h.close);
      await _realAsync(tester, () => h.run(() => _replaceSites(h, _before)));
      late String targetId;
      for (final action in ['create', 'patch', 'delete']) {
        late Map<String, Object?> receipt;
        await _realAsync(tester, () async {
          await h.run(() async {
            final Map<String, Object?> arguments;
            if (action == 'create') {
              arguments = {
                'action': action,
                'site': {
                  'name': 'Temporary campus',
                  'loginUrl': 'https://temporary.invalid',
                },
              };
            } else {
              final listed = await h.call('school_sites.list');
              final target = (listed['items'] as List).cast<Map>().singleWhere(
                (site) => site['id'] == targetId,
              );
              arguments = {
                'action': action,
                'handle': target['handle'],
                if (action == 'patch')
                  'site': {'loginUrl': 'https://temporary-revised.invalid'},
              };
            }
            final prepared = await h.call('school_sites.prepare', arguments);
            receipt = await h.externalCommit(prepared);
            expect(receipt['effectStatus'], 'applied');
            final stored = await _readSites(h);
            final originalIds = _before.map((site) => site.id).toSet();
            expect(
              stored.where((site) => originalIds.contains(site['id'])).toList(),
              _json(_before),
            );
            if (action == 'create') {
              targetId =
                  stored.singleWhere(
                        (site) => !originalIds.contains(site['id']),
                      )['id']
                      as String;
              expect(validSchoolSiteId(targetId), isTrue);
            } else if (action == 'delete') {
              expect(stored.any((site) => site['id'] == targetId), isFalse);
            } else {
              expect(
                stored.singleWhere((site) => site['id'] == targetId)['name'],
                'Temporary campus',
              );
              expect(
                stored.singleWhere(
                  (site) => site['id'] == targetId,
                )['loginUrl'],
                'https://temporary-revised.invalid',
              );
            }
          });
        });
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
        expect(jsonEncode(receipt), originalReceipt);
        expect(h.saved.encode(), originalData);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'identical school-site lists show zero changes and a reorder has one list result',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = AcceptanceHarness();
      await _realAsync(
        tester,
        () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
      );
      addTearDown(h.close);
      await _realAsync(tester, () => h.run(() => _replaceSites(h, _before)));
      for (final reorder in [false, true]) {
        late Map<String, Object?> receipt;
        final target = reorder ? [_before[2], _before[0], _before[1]] : _before;
        await _realAsync(tester, () async {
          await h.run(() async {
            receipt = await h.externalCommit(await _prepareSites(h, target));
            expect(receipt['effectStatus'], 'applied');
            expect(await _readSites(h), _json(target));
          });
        });
        expect(receipt['changeCount'], isNull);
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
        expect(jsonEncode(receipt), originalReceipt);
        expect(h.saved.encode(), originalData);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}

List<Map<String, dynamic>> _json(List<SchoolSite> sites) =>
    sites.map((site) => site.toJson()).toList();

Future<Map<String, Object?>> _prepareSites(
  AcceptanceHarness h,
  List<SchoolSite> sites,
) => h.call('school_sites.prepare', {
  'action': 'import',
  'mode': 'replace',
  'source': jsonEncode(_json(sites)),
});

Future<void> _replaceSites(AcceptanceHarness h, List<SchoolSite> sites) async {
  final result = await h.externalCommit(await _prepareSites(h, sites));
  expect(result['effectStatus'], 'applied');
  expect(await _readSites(h), _json(sites));
}

Future<List<Map<String, dynamic>>> _readSites(AcceptanceHarness h) async {
  final exported = await h.call('school_sites.export');
  return _json(decodeSchoolSitesStrict(exported['text'] as String));
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
  SingleChildScrollView(
    child: AgentOperationCard(
      receipt: h.app.agent.tools.describeCommitResult(receipt),
      onOpenResource: opened.add,
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
