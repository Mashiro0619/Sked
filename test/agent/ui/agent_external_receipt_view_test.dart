import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/models/timetable_models.dart';

import '../acceptance/acceptance_harness.dart';
import 'agent_ui_test_support.dart';

const _languages = [
  (
    locale: Locale('en'),
    added: 'Added',
    updated: 'Updated',
    deleted: 'Deleted',
    view: 'View item',
    prepared: 'Changes prepared',
    uncertain: 'Result needs checking',
    failed: 'Action not completed',
    skills: 'Skills',
    memories: 'Memory',
  ),
  (
    locale: Locale('zh'),
    added: '已添加',
    updated: '已更新',
    deleted: '已删除',
    view: '查看对象',
    prepared: '更改已准备好',
    uncertain: '需要核对操作结果',
    failed: '操作未完成',
    skills: '技能',
    memories: '记忆',
  ),
  (
    locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    added: '已新增',
    updated: '已更新',
    deleted: '已刪除',
    view: '查看項目',
    prepared: '變更已準備好',
    uncertain: '需要核對操作結果',
    failed: '操作未完成',
    skills: '技能',
    memories: '記憶',
  ),
];

void main() {
  for (final language in _languages) {
    for (final kind in KnowledgeKind.values) {
      testWidgets(
        'real ${kind.name} receipts show stored actions and names in ${language.locale}',
        (tester) async {
          addTearDown(tester.view.reset);
          final h = AcceptanceHarness();
          await _realAsync(
            tester,
            () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
          );
          addTearDown(h.close);
          final family = kind == KnowledgeKind.skill ? 'skills' : 'memories';
          final originalTitle = kind == KnowledgeKind.skill
              ? 'Shared rehearsal'
              : 'Shared study preference';
          final updatedTitle = '$originalTitle revised';
          late String id;
          for (final action in ['create', 'update', 'delete']) {
            late Map<String, Object?> receipt;
            await _realAsync(tester, () async {
              await h.run(() async {
                final current = action == 'create'
                    ? null
                    : h.app.agent.knowledgeRepository.records.singleWhere(
                        (record) => record.id == id,
                      );
                final plan = await h.call('$family.prepare', {
                  'action': action,
                  if (current == null) ...{
                    'title': originalTitle,
                    'body': 'Synthetic content for the receipt view.',
                  } else ...{
                    'id': current.id,
                    'revision': current.revision,
                    if (action == 'update') 'title': updatedTitle,
                  },
                });
                receipt = await h.externalCommit(plan);
                expect(receipt['effectStatus'], 'applied');
                if (action == 'create') {
                  id = h.app.agent.knowledgeRepository.records.single.id;
                }
              });
            });
            final rawChange = (receipt['changes'] as List).single as Map;
            expect(rawChange.containsKey('action'), isFalse);
            expect(rawChange.containsKey('label'), isFalse);
            expect(rawChange.containsKey('ref'), isFalse);
            final originalReceipt = jsonEncode(receipt);
            final originalData = h.saved.encode();
            final originalKnowledge = h.app.agent.knowledgeRepository.snapshot
                .encode();
            final opened = <Map<String, Object?>>[];
            await _mountReceipt(
              tester,
              h,
              receipt,
              locale: language.locale,
              opened: opened,
            );
            final actionLabel = switch (action) {
              'create' => language.added,
              'delete' => language.deleted,
              _ => language.updated,
            };
            final title = action == 'create' ? originalTitle : updatedTitle;
            expect(find.text('$actionLabel · $title'), findsOneWidget);
            expect(find.textContaining('knowledge.'), findsNothing);
            expect(find.byTooltip(language.view), findsNothing);
            expect(find.byType(ExpansionTile), findsNothing);
            expect(opened, isEmpty);
            expect(jsonEncode(receipt), originalReceipt);
            expect(h.saved.encode(), originalData);
            expect(
              h.app.agent.knowledgeRepository.snapshot.encode(),
              originalKnowledge,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        },
      );
    }

    for (final firstAction in ['update', 'setEnabled']) {
      testWidgets(
        'the first built-in $firstAction and restore-original receipts remain updates in ${language.locale}',
        (tester) async {
          addTearDown(tester.view.reset);
          final h = AcceptanceHarness();
          await _realAsync(
            tester,
            () => h.initialize(knowledgeStorage: MemoryKnowledgeStorage()),
          );
          addTearDown(h.close);
          late Map<String, Object?> firstReceipt;
          late String originalTitle;
          late String expectedTitle;
          await _realAsync(tester, () async {
            await h.run(() async {
              final original = await h.call('skills.get', {
                'id': 'read-agenda',
              });
              originalTitle = original['title'] as String;
              expectedTitle = firstAction == 'update'
                  ? '$originalTitle reviewed'
                  : originalTitle;
              expect(
                h.app.agent.knowledgeRepository.records.where(
                  (record) => record.id == 'read-agenda',
                ),
                isEmpty,
              );
              final plan = await h.call('skills.prepare', {
                'action': firstAction,
                'id': 'read-agenda',
                'revision': original['revision'],
                if (firstAction == 'update')
                  'title': expectedTitle
                else
                  'enabled': false,
              });
              firstReceipt = await h.externalCommit(plan);
              expect(firstReceipt['effectStatus'], 'applied');
            });
          });
          final firstChange = (firstReceipt['changes'] as List).single as Map;
          expect(firstChange['before'], isNull);
          expect((firstChange['after'] as Map)['builtIn'], isTrue);
          final firstRawReceipt = jsonEncode(firstReceipt);
          final opened = <Map<String, Object?>>[];
          await _mountReceipt(
            tester,
            h,
            firstReceipt,
            locale: language.locale,
            opened: opened,
          );
          expect(
            find.text('${language.updated} · $expectedTitle'),
            findsOneWidget,
          );
          expect(find.text('${language.added} · $expectedTitle'), findsNothing);
          expect(find.textContaining('knowledge.'), findsNothing);
          expect(find.byTooltip(language.view), findsNothing);
          expect(jsonEncode(firstReceipt), firstRawReceipt);
          await tester.pumpWidget(const SizedBox());

          late Map<String, Object?> restoredReceipt;
          await _realAsync(tester, () async {
            await h.run(() async {
              final edited = await h.call('skills.get', {'id': 'read-agenda'});
              final plan = await h.call('skills.prepare', {
                'action': 'restoreOriginal',
                'id': 'read-agenda',
                'revision': edited['revision'],
              });
              restoredReceipt = await h.externalCommit(plan);
              expect(restoredReceipt['effectStatus'], 'applied');
            });
          });
          final restoredChange =
              (restoredReceipt['changes'] as List).single as Map;
          final restoredRecord = restoredChange['after'] as Map;
          expect(restoredRecord['builtIn'], isTrue);
          expect(restoredRecord['usesOriginal'], isTrue);
          expect(restoredRecord['enabled'], firstAction != 'setEnabled');
          final restoredRawReceipt = jsonEncode(restoredReceipt);
          final saved = h.saved.encode();
          final knowledge = h.app.agent.knowledgeRepository.snapshot.encode();
          await _mountReceipt(
            tester,
            h,
            restoredReceipt,
            locale: language.locale,
            opened: opened,
          );
          expect(
            find.text('${language.updated} · $originalTitle'),
            findsOneWidget,
          );
          expect(find.text('${language.added} · $originalTitle'), findsNothing);
          expect(
            find.text('${language.deleted} · $originalTitle'),
            findsNothing,
          );
          expect(find.textContaining('knowledge.'), findsNothing);
          expect(opened, isEmpty);
          expect(jsonEncode(restoredReceipt), restoredRawReceipt);
          expect(h.saved.encode(), saved);
          expect(h.app.agent.knowledgeRepository.snapshot.encode(), knowledge);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'real prepared knowledge and restore receipts keep rows neutral in ${language.locale}',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        final storage = MemoryKnowledgeStorage();
        await _realAsync(tester, () => h.initialize(knowledgeStorage: storage));
        addTearDown(h.close);
        final initialData = h.saved.encode();
        final initialKnowledge = h.app.agent.knowledgeRepository.snapshot
            .encode();
        final prepared = <({Map<String, Object?> receipt, String label})>[];
        await _realAsync(tester, () async {
          for (final kind in KnowledgeKind.values) {
            await h.run(() async {
              final isSkill = kind == KnowledgeKind.skill;
              final plan = await h.call(
                '${isSkill ? 'skills' : 'memories'}.prepare',
                {
                  'action': 'create',
                  'title': 'Planned ${kind.name}',
                  'body': 'Synthetic content awaiting confirmation.',
                },
              );
              final change = (plan['changes'] as List).single as Map;
              expect((change['after'] as Map)['title'], isNull);
              prepared.add((
                receipt: plan,
                label: isSkill ? language.skills : language.memories,
              ));
            });
          }
          final original = h.saved;
          final source = original.copyWith(
            generalMode: original.generalMode.copyWith(
              schedules: [
                for (final calendar in original.generalMode.schedules)
                  calendar.id == 'visible'
                      ? calendar.copyWith(name: 'Planned studies')
                      : calendar,
              ],
            ),
          );
          await h.attach(
            'receipt-view-restore-preview',
            'structured_file',
            encodeAppBackup(source, const []),
          );
          await h.run(() async {
            final plan = await h.call('backups.prepare_restore', {
              'sourceId': 'receipt-view-restore-preview',
              'objects': [
                {'kind': 'calendar', 'id': 'visible'},
              ],
            });
            final change = (plan['changes'] as List).single as Map;
            expect((change['after'] as Map)['label'], 'Planned studies');
            prepared.add((receipt: plan, label: 'Planned studies'));
          });
        });
        final opened = <Map<String, Object?>>[];
        expect(prepared, hasLength(3));
        for (final item in prepared) {
          final receipt = item.receipt;
          expect(receipt['planId'], isA<String>());
          expect(receipt['status'], isNull);
          expect(receipt['effectStatus'], isNull);
          final change = (receipt['changes'] as List).single as Map;
          expect(change.containsKey('action'), isFalse);
          expect(change.containsKey('label'), isFalse);
          expect(change.containsKey('ref'), isFalse);
          final originalReceipt = jsonEncode(receipt);
          await _mountReceipt(
            tester,
            h,
            receipt,
            locale: language.locale,
            opened: opened,
          );
          expect(find.text(language.prepared), findsOneWidget);
          expect(find.text(item.label), findsOneWidget);
          for (final action in [
            language.added,
            language.updated,
            language.deleted,
          ]) {
            expect(find.textContaining('$action · '), findsNothing);
          }
          expect(find.byTooltip(language.view), findsNothing);
          expect(find.byType(ExpansionTile), findsNothing);
          expect(find.textContaining('knowledge.'), findsNothing);
          expect(find.textContaining('backup.'), findsNothing);
          expect(opened, isEmpty);
          expect(jsonEncode(receipt), originalReceipt);
          expect(h.saved.encode(), initialData);
          expect(
            h.app.agent.knowledgeRepository.snapshot.encode(),
            initialKnowledge,
          );
          expect(storage.source, isNull);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    for (final afterWrite in [false, true]) {
      testWidgets(
        'real knowledge ${afterWrite ? 'unknown' : 'failed'} receipt keeps its name without completion claims in ${language.locale}',
        (tester) async {
          addTearDown(tester.view.reset);
          final h = AcceptanceHarness();
          final storage = _FailingKnowledgeStorage(afterWrite: afterWrite);
          await _realAsync(
            tester,
            () => h.initialize(knowledgeStorage: storage),
          );
          addTearDown(h.close);
          late Map<String, Object?> receipt;
          const title = 'Requested study preference';
          await _realAsync(tester, () async {
            await h.run(() async {
              final plan = await h.call('memories.prepare', {
                'action': 'create',
                'title': title,
                'body': 'Synthetic content for an unconfirmed receipt.',
              });
              receipt = await h.externalCommit(plan);
              expect(
                receipt['effectStatus'],
                afterWrite ? 'unknown' : 'failed',
              );
              expect(
                receipt['dataStatus'],
                afterWrite ? 'unknown' : 'unchanged',
              );
            });
            expect(storage.writes, 1);
            expect(h.app.agent.knowledgeRepository.blocked, isTrue);
            expect(h.app.agent.knowledgeRepository.records, isEmpty);
            if (afterWrite) {
              // Read storage directly without reconciling the live repository.
              // The UI must still reflect the actual unknown tool result.
              final durable = await storage.load();
              expect(durable.archive.records.single.title, title);
            } else {
              expect(storage.source, isNull);
            }
          });
          final rawChange = (receipt['changes'] as List).single as Map;
          expect((rawChange['after'] as Map)['title'], title);
          expect(rawChange.containsKey('action'), isFalse);
          expect(rawChange.containsKey('label'), isFalse);
          expect(rawChange.containsKey('ref'), isFalse);
          final originalReceipt = jsonEncode(receipt);
          final originalData = h.saved.encode();
          final originalKnowledge = h.app.agent.knowledgeRepository.snapshot
              .encode();
          final originalStorage = storage.source;
          final opened = <Map<String, Object?>>[];
          await _mountReceipt(
            tester,
            h,
            receipt,
            locale: language.locale,
            opened: opened,
          );
          expect(
            find.text(afterWrite ? language.uncertain : language.failed),
            findsOneWidget,
          );
          expect(find.text(title), findsOneWidget);
          for (final action in [
            language.added,
            language.updated,
            language.deleted,
          ]) {
            expect(find.textContaining('$action · '), findsNothing);
          }
          expect(find.byTooltip(language.view), findsNothing);
          expect(find.byType(ExpansionTile), findsNothing);
          expect(find.textContaining('knowledge.'), findsNothing);
          expect(opened, isEmpty);
          expect(jsonEncode(receipt), originalReceipt);
          expect(h.saved.encode(), originalData);
          expect(
            h.app.agent.knowledgeRepository.snapshot.encode(),
            originalKnowledge,
          );
          expect(storage.source, originalStorage);
          expect(storage.writes, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'real selective restore names added and updated objects and opens stored targets in ${language.locale}',
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
          final original = h.saved;
          final source = original.copyWith(
            studentMode: original.studentMode.copyWith(
              timetables: [
                for (final timetable in original.studentMode.timetables)
                  timetable.id == 'other'
                      ? timetable.copyWith(
                          config: timetable.config.copyWith(
                            name: 'Restored term',
                          ),
                        )
                      : timetable,
              ],
              periodTimeSets: [
                ...original.studentMode.periodTimeSets,
                PeriodTimeSet(
                  id: 'recovered-periods',
                  name: 'Recovered periods',
                  periodTimes:
                      original.studentMode.periodTimeSets.single.periodTimes,
                ),
              ],
            ),
            generalMode: original.generalMode.copyWith(
              schedules: [
                for (final calendar in original.generalMode.schedules)
                  calendar.id == 'visible'
                      ? calendar.copyWith(name: 'Restored studies')
                      : calendar,
                const GeneralSchedule(
                  id: 'recovered-calendar',
                  name: 'Recovered projects',
                  events: [],
                ),
              ],
            ),
          );
          await h.attach(
            'receipt-view-restore',
            'structured_file',
            encodeAppBackup(source, const []),
          );
          await h.run(() async {
            final plan = await h.call('backups.prepare_restore', {
              'sourceId': 'receipt-view-restore',
              'objects': [
                {'kind': 'timetable', 'id': 'other'},
                {'kind': 'periodTimeSet', 'id': 'recovered-periods'},
                {'kind': 'calendar', 'id': 'visible'},
                {'kind': 'calendar', 'id': 'recovered-calendar'},
              ],
            });
            receipt = await h.externalCommit(plan);
            expect(receipt['effectStatus'], 'applied');
          });
        });
        final rawChanges = receipt['changes'] as List;
        expect(rawChanges, hasLength(4));
        for (final change in rawChanges.cast<Map>()) {
          expect(change.containsKey('action'), isFalse);
          expect(change.containsKey('label'), isFalse);
          expect(change.containsKey('ref'), isFalse);
        }
        final originalReceipt = jsonEncode(receipt);
        final originalData = h.saved.encode();
        final opened = <Map<String, Object?>>[];
        await _mountReceipt(
          tester,
          h,
          receipt,
          locale: language.locale,
          opened: opened,
        );
        expect(find.textContaining('backup.'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        final expected = [
          (
            action: language.updated,
            title: 'Restored term',
            ref: const ResourceRef(kind: ResourceKind.timetable, id: 'other'),
          ),
          (
            action: language.added,
            title: 'Recovered periods',
            ref: const ResourceRef(
              kind: ResourceKind.periodTimeSet,
              id: 'recovered-periods',
            ),
          ),
          (
            action: language.updated,
            title: 'Restored studies',
            ref: const ResourceRef(kind: ResourceKind.calendar, id: 'visible'),
          ),
          (
            action: language.added,
            title: 'Recovered projects',
            ref: const ResourceRef(
              kind: ResourceKind.calendar,
              id: 'recovered-calendar',
            ),
          ),
        ];
        for (final item in expected) {
          final text = find.text('${item.action} · ${item.title}');
          expect(text, findsOneWidget);
          final row = find.ancestor(of: text, matching: find.byType(Row));
          final button = find.descendant(
            of: row,
            matching: find.byTooltip(language.view),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(opened.last, item.ref.toJson());
          final view = tester.widget<AgentResourceView>(
            find.byType(AgentResourceView),
          );
          expect(view.ref, item.ref);
          expect(find.text(item.title), findsOneWidget);
          expect(h.saved.encode(), originalData);
          Navigator.of(tester.element(find.byType(AgentResourceView))).pop();
          await tester.pumpAndSettle();
        }
        expect(jsonEncode(receipt), originalReceipt);
        expect(h.saved.encode(), originalData);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

Future<void> _mountReceipt(
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

class _FailingKnowledgeStorage extends MemoryKnowledgeStorage {
  _FailingKnowledgeStorage({required this.afterWrite});

  final bool afterWrite;
  int writes = 0;

  @override
  Future<void> save(KnowledgeArchive archive) async {
    writes++;
    if (afterWrite) {
      await super.save(archive);
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Synthetic failure after durable storage.',
      );
    }
    throw const KnowledgeException(
      KnowledgeError.conflict,
      'Synthetic rejection before storage.',
    );
  }
}
