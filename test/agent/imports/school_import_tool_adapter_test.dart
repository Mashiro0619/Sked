import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/imports/school_import_tool_adapter.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/approval_plan.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';

class _Storage implements TimetableStorage {
  _Storage(this.data);
  AppData data;
  var saves = 0;
  bool fail = false;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    saves++;
    if (fail) throw StateError('synthetic save failure');
    data = AppData.decodeStorageSnapshot(value.encode());
  }

  @override
  Future<String?> filePath() async => null;
}

Map<String, Object?> _candidate() => {
  'name': 'Imported semester',
  'startDate': '2026-09-07',
  'totalWeeks': 18,
  'periodTimeSet': {
    'name': 'School periods',
    'periodTimes': [
      {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
      {'index': 2, 'startMinutes': 535, 'endMinutes': 580},
    ],
  },
  'courses': [
    {
      'name': 'Algebra',
      'dayOfWeek': 1,
      'semesterWeeks': [1, 2, 3],
      'periods': [1, 2],
      'teacher': 'Teacher',
      'location': 'Room 101',
      'customFields': {'group': 'A'},
    },
    {
      'name': 'Languages',
      'dayOfWeek': 3,
      'semesterWeeks': [1, 3, 5],
      'startMinutes': 600,
      'endMinutes': 660,
    },
  ],
};

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late AppSession session;
  late ApplicationToolHost host;
  late OperationScope scope;
  AgentConversation? conversation;
  Future<MutationApproval?> Function(ApprovalPlan)? approve;
  Future<Map<String, Object?>> call(String name, Map<String, Object?> args) =>
      host.execute(
        ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
        scope,
        approve ?? (_) async => null,
      );
  void configureHost() {
    host = ApplicationToolHost(
      session: session,
      mutations: MutationCoordinator(
        session: session,
        settlePendingChanges: () async {},
        dataSessionRevision: () => 0,
      ),
      conversationForScope: (_) => conversation,
    );
    registerSchoolImportTools(host);
  }

  setUp(() async {
    approve = null;
    conversation = null;
    final initial = buildInitialAppData(buildDefaultPeriodTimes());
    storage = _Storage(
      initial.copyWith(
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: 'existing-timetable',
          timetables: [
            TimetableData(
              id: 'existing-timetable',
              config: TimetableConfig(
                name: 'Existing semester',
                startDate: DateTime(2026, 9, 7),
                totalWeeks: 18,
                periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
              ),
              courses: const [],
            ),
          ],
        ),
      ),
    );
    final repository = AppRepository(storage: storage);
    session = AppSession(
      repository: repository,
      initialData: (await repository.load())!,
      requireMutationAllowed: () {},
    );
    addTearDown(() => session.close());
    scope = OperationScope(
      id: 'import-run',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    configureHost();
  });

  for (final reused in [true, false]) {
    test(
      'approval references freeze the exact ${reused ? 'reused' : 'created'} period set',
      () async {
        final existing = session.data.studentMode.periodTimeSets.first;
        final summary = await call('imports.prepare', {
          'action': 'create',
          'candidate': _candidate(),
          if (reused) 'periodTimeSetId': existing.id,
        });
        final plan = host.mutations.plan(summary['planId'] as String)!;
        final preview = plan.referencePreview();
        final sets = preview['periodTimeSets'] as Map;
        expect(sets, hasLength(1));
        final reference = sets.values.single as Map;
        final value = reference['value'] as Map;
        expect(reference['status'], reused ? 'reused' : 'created');
        expect(value['name'], reused ? existing.name : 'School periods');
        expect(
          value['periodTimes'],
          reused
              ? existing.toJson()['periodTimes']
              : (_candidate()['periodTimeSet'] as Map)['periodTimes'],
        );
        if (reused) expect(sets.keys.single, existing.id);
        expect(
          summary.containsKey('references'),
          isFalse,
          reason: 'Review context is not appended to the model reply.',
        );
        expect(() => value['name'] = 'Mutated preview', throwsUnsupportedError);
        final frozen = jsonEncode(preview);
        session.replaceData(
          session.data.copyWith(
            studentMode: session.data.studentMode.copyWith(
              periodTimeSets: [
                for (final set in session.data.studentMode.periodTimeSets)
                  set.copyWith(name: 'Changed after preparation'),
              ],
            ),
          ),
        );
        expect(jsonEncode(plan.referencePreview()), frozen);
        expect(storage.saves, 0);
      },
    );
  }

  test('a complete parent and children save once and undo together', () async {
    final before = storage.data.toJson();
    final originalActive = storage.data.studentMode.activeTimetableId;
    final plan = await call('imports.prepare', {
      'action': 'create',
      'candidate': _candidate(),
    });
    expect(storage.saves, 0);
    final result = await call('mutation.commit', {'planId': plan['planId']});
    expect(result['status'], 'committed');
    expect(storage.saves, 1);
    final table = storage.data.studentMode.timetables.last;
    expect(table.config.name, 'Imported semester');
    expect(table.courses.map((course) => course.name), [
      'Algebra',
      'Languages',
    ]);
    expect(table.courses.first.startMinutes, 0);
    expect(table.courses.first.endMinutes, 0);
    expect(table.courses.first.periods, [1, 2]);
    expect(storage.data.studentMode.activeTimetableId, originalActive);
    expect(
      (result['changes'] as List).any(
        (change) => (change as Map)['label'] == 'Imported semester',
      ),
      isTrue,
    );
    final inverse = host.mutations.prepareUndo(
      scope: scope,
      operationId: plan['operationId']! as String,
    );
    await host.mutations.commit(planId: inverse.id, scope: scope);
    final restored = storage.data.toJson()..remove('applicationLedger');
    before.remove('applicationLedger');
    expect(restored, before);
  });

  test('durable retries return the original import without new IDs', () async {
    final args = {'action': 'create', 'candidate': _candidate()};
    final plan = await call('imports.prepare', args);
    await call('mutation.commit', {'planId': plan['planId']});
    final ids = storage.data.studentMode.timetables
        .map((table) => table.id)
        .toList();
    configureHost();
    final retry = await call('imports.prepare', {
      ...args,
      'operationId': plan['operationId'],
    });
    expect(retry['alreadyCommitted'], isTrue);
    await call('mutation.commit', {'planId': retry['planId']});
    expect(storage.data.studentMode.timetables.map((table) => table.id), ids);
    expect(storage.saves, 1);
    await expectLater(
      call('imports.prepare', {
        ...args,
        'operationId': plan['operationId'],
        'candidate': {..._candidate(), 'name': 'Different'},
      }),
      throwsA(_problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test(
    'replacement addresses a fixed target and preserves its identity',
    () async {
      final target = storage.data.studentMode.timetables.first.id;
      final setId = storage.data.studentMode.periodTimeSets.first.id;
      final candidate = _candidate()..remove('periodTimeSet');
      final plan = await call('imports.prepare', {
        'action': 'replace',
        'candidate': candidate,
        'targetTimetableId': target,
        'periodTimeSetId': setId,
      });
      await call('mutation.commit', {'planId': plan['planId']});
      expect(storage.data.studentMode.timetables.first.id, target);
      expect(storage.data.studentMode.timetables.first.courses.length, 2);
      expect(storage.data.studentMode.periodTimeSets.length, 1);
      await expectLater(
        call('imports.prepare', {
          'action': 'replace',
          'candidate': candidate,
          'targetTimetableId': 'missing',
          'periodTimeSetId': setId,
        }),
        throwsA(_problem(OperationErrorCode.notFound)),
      );
    },
  );

  for (final missing in ['startDate', 'totalWeeks', 'periodTimeSet']) {
    test('missing $missing is not replaced with a guessed default', () async {
      final candidate = _candidate()..remove(missing);
      await expectLater(
        call('imports.prepare', {'action': 'create', 'candidate': candidate}),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      expect(storage.saves, 0);
    });
  }

  test(
    'invalid or incomplete course records never silently disappear',
    () async {
      for (final invalid in [
        {
          'name': 'Missing weeks',
          'dayOfWeek': 1,
          'periods': [1],
        },
        {
          'name': 'Bad time',
          'dayOfWeek': 1,
          'semesterWeeks': [1],
          'startMinutes': 660,
          'endMinutes': 600,
        },
        {
          'name': '',
          'dayOfWeek': 1,
          'semesterWeeks': [1],
          'periods': [1],
        },
      ]) {
        final candidate = _candidate();
        (candidate['courses']! as List).add(invalid);
        await expectLater(
          call('imports.prepare', {'action': 'create', 'candidate': candidate}),
          throwsA(_problem(OperationErrorCode.invalidArgument)),
        );
        expect(storage.saves, 0);
      }
    },
  );

  test(
    'planning, approval, cancellation, conflicts and failure preserve data',
    () async {
      final before = storage.data.toJson();
      final plan = await call('imports.prepare', {
        'action': 'create',
        'candidate': _candidate(),
      });
      scope.policy.update(mode: AgentPermissionMode.plan);
      await expectLater(
        call('mutation.commit', {'planId': plan['planId']}),
        throwsA(_problem(OperationErrorCode.readOnly)),
      );
      scope.policy.update(mode: AgentPermissionMode.ask);
      await expectLater(
        call('mutation.commit', {'planId': plan['planId']}),
        throwsA(_problem(OperationErrorCode.cancelled)),
      );
      approve = (plan) async => scope.approve(plan.id);
      storage.fail = true;
      await expectLater(
        call('mutation.commit', {'planId': plan['planId']}),
        throwsA(_problem(OperationErrorCode.storageFailure)),
      );
      expect(storage.data.toJson(), before);
      storage.fail = false;
      scope.cancel();
      await expectLater(
        call('mutation.commit', {'planId': plan['planId']}),
        throwsA(_problem(OperationErrorCode.cancelled)),
      );
      expect(storage.data.toJson(), before);
    },
  );

  test('UI edits after preparation invalidate a replacement plan', () async {
    final target = session.data.studentMode.timetables.first;
    final plan = await call('imports.prepare', {
      'action': 'replace',
      'candidate': _candidate(),
      'targetTimetableId': target.id,
    });
    session.replaceData(
      session.data.copyWith(
        studentMode: session.data.studentMode.copyWith(
          timetables: [
            target.copyWith(
              config: target.config.copyWith(name: 'Manual draft'),
            ),
          ],
        ),
      ),
    );
    await expectLater(
      call('mutation.commit', {'planId': plan['planId']}),
      throwsA(_problem(OperationErrorCode.conflict)),
    );
    expect(
      session.data.studentMode.timetables.first.config.name,
      'Manual draft',
    );
    expect(storage.saves, 0);
  });

  test('attached source provenance and truncation cannot be omitted', () async {
    final now = DateTime.utc(2026, 10, 30);
    conversation = AgentConversation(
      id: 'school-source',
      title: 'Source',
      createdAt: now,
      updatedAt: now,
      sources: [
        ConversationSource(
          id: 'page',
          text: 'Partial source',
          kind: 'school_web',
          truncated: true,
          provenance: ConversationSourceProvenance(
            title: 'Page',
            capturedAt: now,
            reviewedAt: now,
            datasetGeneration: host.mutations.generation,
            localeCode: 'en',
          ),
        ),
      ],
    );
    final plan = await call('imports.prepare', {
      'action': 'create',
      'candidate': _candidate(),
    });
    expect(plan['sourceTruncated'], isTrue);
    expect(plan['warningCount'], 1);
    host.mutations.invalidate();
    await expectLater(
      call('imports.prepare', {'action': 'create', 'candidate': _candidate()}),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    expect(storage.saves, 0);
  });
}
