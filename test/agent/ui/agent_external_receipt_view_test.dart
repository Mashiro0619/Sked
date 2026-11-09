import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/models/timetable_models.dart';

import 'agent_receipt_view_support.dart';

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

Map<String, Object?> _receipt(
  List<Map<String, Object?>> changes, {
  String status = 'committed',
  String? effectStatus = 'applied',
}) => {
  'operationId': 'ui-knowledge',
  'kind': 'external',
  'status': status,
  'effectStatus': ?effectStatus,
  'changes': changes,
};

void main() {
  for (final language in _languages) {
    for (final kind in KnowledgeKind.values) {
      testWidgets(
        '${kind.name} receipt actions and names in ${language.locale}',
        (tester) async {
          addTearDown(tester.view.reset);
          const title = 'Shared study preference';
          const revised = '$title revised';
          for (final action in ['create', 'update', 'delete']) {
            final before = action == 'create'
                ? null
                : {'title': action == 'update' ? title : revised};
            final after = action == 'delete'
                ? null
                : {'title': action == 'create' ? title : revised};
            final receipt = _receipt([
              {
                'key': 'knowledge.${kind.name}:ui',
                'before': before,
                'after': after,
              },
            ]);
            final source = jsonEncode(receipt);
            final opened = <Map<String, Object?>>[];
            await mountReceiptView(
              tester,
              receipt,
              locale: language.locale,
              opened: opened,
            );
            final verb = action == 'create'
                ? language.added
                : action == 'delete'
                ? language.deleted
                : language.updated;
            expect(
              find.text('$verb · ${action == 'create' ? title : revised}'),
              findsOneWidget,
            );
            expect(find.textContaining('knowledge.'), findsNothing);
            expect(find.byTooltip(language.view), findsNothing);
            expect(find.byType(ExpansionTile), findsNothing);
            expect(opened, isEmpty);
            expect(jsonEncode(receipt), source);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        },
      );
    }

    for (final action in ['update', 'setEnabled', 'restoreOriginal']) {
      testWidgets('built-in $action remains an update in ${language.locale}', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        final after = {
          'title': action == 'update' ? 'Read agenda reviewed' : 'Read agenda',
          'builtIn': true,
          'usesOriginal': action == 'restoreOriginal',
          'enabled': false,
        };
        final receipt = _receipt([
          {
            'key': 'knowledge.skill:read-agenda',
            'before': {'title': 'Read agenda', 'builtIn': true},
            'after': after,
          },
        ]);
        final source = jsonEncode(receipt);
        final opened = <Map<String, Object?>>[];
        await mountReceiptView(
          tester,
          receipt,
          locale: language.locale,
          opened: opened,
        );
        expect(
          find.text('${language.updated} · ${after['title']}'),
          findsOneWidget,
        );
        expect(find.textContaining('${language.added} · '), findsNothing);
        expect(find.textContaining('${language.deleted} · '), findsNothing);
        expect(find.byTooltip(language.view), findsNothing);
        expect(opened, isEmpty);
        expect(jsonEncode(receipt), source);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'knowledge and restore previews keep neutral rows in ${language.locale}',
      (tester) async {
        addTearDown(tester.view.reset);
        final cases = [
          (
            key: 'knowledge.skill:ui',
            after: <String, Object?>{'kind': 'skill'},
            label: language.skills,
          ),
          (
            key: 'knowledge.memory:ui',
            after: <String, Object?>{'kind': 'memory'},
            label: language.memories,
          ),
          (
            key: 'backup.calendar:visible',
            after: <String, Object?>{
              'kind': 'calendar',
              'id': 'visible',
              'label': 'Planned studies',
            },
            label: 'Planned studies',
          ),
        ];
        for (final item in cases) {
          final receipt = _receipt(
            [
              {'key': item.key, 'before': null, 'after': item.after},
            ],
            status: 'preview',
            effectStatus: null,
          );
          final source = jsonEncode(receipt);
          final opened = <Map<String, Object?>>[];
          await mountReceiptView(
            tester,
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
          expect(jsonEncode(receipt), source);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    for (final uncertain in [false, true]) {
      testWidgets(
        'knowledge ${uncertain ? 'unknown' : 'failed'} result remains unconfirmed in ${language.locale}',
        (tester) async {
          addTearDown(tester.view.reset);
          const title = 'Requested study preference';
          final receipt = _receipt(
            [
              {
                'key': 'knowledge.memory:requested',
                'before': null,
                'after': {'title': title},
              },
            ],
            status: uncertain ? 'outcome_unknown' : 'failed',
            effectStatus: uncertain ? 'unknown' : 'failed',
          );
          final source = jsonEncode(receipt);
          final opened = <Map<String, Object?>>[];
          await mountReceiptView(
            tester,
            receipt,
            locale: language.locale,
            opened: opened,
          );
          expect(
            find.text(uncertain ? language.uncertain : language.failed),
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
          expect(opened, isEmpty);
          expect(jsonEncode(receipt), source);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'restore receipts open added and updated targets in ${language.locale}',
      (tester) async {
        addTearDown(tester.view.reset);
        final initial = buildInitialAppData(buildDefaultPeriodTimes());
        final period = initial.studentMode.periodTimeSets.first;
        final data = initial.copyWith(
          studentMode: initial.studentMode.copyWith(
            timetables: [
              TimetableData(
                id: 'other',
                config: TimetableConfig(
                  name: 'Restored term',
                  startDate: DateTime(2026, 9, 7),
                  totalWeeks: 18,
                  periodTimeSetId: period.id,
                ),
                courses: const [],
              ),
            ],
            periodTimeSets: [
              period,
              PeriodTimeSet(
                id: 'recovered-periods',
                name: 'Recovered periods',
                periodTimes: period.periodTimes,
              ),
            ],
          ),
          generalMode: initial.generalMode.copyWith(
            schedules: const [
              GeneralSchedule(
                id: 'visible',
                name: 'Restored studies',
                events: [],
              ),
              GeneralSchedule(
                id: 'recovered-calendar',
                name: 'Recovered projects',
                events: [],
              ),
            ],
          ),
        );
        final app = await receiptWorkspace(tester, data);
        final expected = [
          (
            added: false,
            title: 'Restored term',
            ref: const ResourceRef(kind: ResourceKind.timetable, id: 'other'),
          ),
          (
            added: true,
            title: 'Recovered periods',
            ref: const ResourceRef(
              kind: ResourceKind.periodTimeSet,
              id: 'recovered-periods',
            ),
          ),
          (
            added: false,
            title: 'Restored studies',
            ref: const ResourceRef(kind: ResourceKind.calendar, id: 'visible'),
          ),
          (
            added: true,
            title: 'Recovered projects',
            ref: const ResourceRef(
              kind: ResourceKind.calendar,
              id: 'recovered-calendar',
            ),
          ),
        ];
        final receipt = _receipt([
          for (final item in expected)
            {
              'key': 'backup.${item.ref.kind.name}:${item.ref.id}',
              'before': item.added ? null : {'label': 'Previous name'},
              'after': {...item.ref.toJson(), 'label': item.title},
            },
        ]);
        final source = jsonEncode(receipt);
        final saved = app.session.committedData.encode();
        final opened = <Map<String, Object?>>[];
        await mountReceiptView(
          tester,
          receipt,
          locale: language.locale,
          opened: opened,
          app: app,
        );
        expect(find.textContaining('backup.'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        for (final item in expected) {
          final row = find.ancestor(
            of: find.text(
              '${item.added ? language.added : language.updated} · ${item.title}',
            ),
            matching: find.byType(Row),
          );
          final button = find.descendant(
            of: row,
            matching: find.byTooltip(language.view),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(opened.last, item.ref.toJson());
          expect(
            tester
                .widget<AgentResourceView>(find.byType(AgentResourceView))
                .ref,
            item.ref,
          );
          expect(find.text(item.title), findsOneWidget);
          expect(app.session.committedData.encode(), saved);
          Navigator.of(tester.element(find.byType(AgentResourceView))).pop();
          await tester.pumpAndSettle();
        }
        expect(jsonEncode(receipt), source);
        expect(app.session.committedData.encode(), saved);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
