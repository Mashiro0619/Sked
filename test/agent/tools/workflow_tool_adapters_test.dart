import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/developer_sample_data_service.dart';

import '../../support/data_transfer_codec.dart';
import 'tool_adapter_test_support.dart';

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolAdapterHarness h;
  setUp(() async {
    final sample = DeveloperSampleDataService.append(
      current: buildInitialAppData(buildDefaultPeriodTimes())
          .copyWith(enabledWorkspaces: {AppMode.student, AppMode.general}),
      language: DeveloperSampleLanguage.english,
      now: DateTime(2026, 10, 30, 9),
    );
    h = ToolAdapterHarness();
    await h.initialize(data: sample.data);
  });
  tearDown(() => h.close());

  Future<String> attachCalendar() async {
    final calendar = h.session.committedData.generalMode.schedules.last;
    final source = h.session.committedData.generalMode.withSchedule(
      calendar.copyWith(
        events: [
          for (final event in calendar.events)
            event.copyWith(title: 'Imported ${event.title}'),
        ],
      ),
    );
    final text = await inlineDataTransferCodec.encodeSchedules(source, [
      calendar.id,
    ], localeCode: 'en');
    h.sources.add(ConversationSource(id: 'file', text: text, kind: 'json'));
    return calendar.id;
  }

  test('file inspection is read-only and atomic import preserves current selection', () async {
    final original = h.session.committedData;
    final id = await attachCalendar();
    final inspect = await h.call('file_imports.inspect', {
      'sourceId': 'file',
      'format': 'schedules_json',
    });
    expect(inspect['itemCount'], 1);
    expect((inspect['rows'] as List).single['id'], id);
    expect(h.storage.saveCount, 0);
    final args = {
      'sourceId': 'file',
      'format': 'schedules_json',
      'action': 'add',
      'ids': [id],
    };
    final plan = await h.call('file_imports.prepare', args);
    expect(h.storage.saveCount, 0);
    final result = await h.commit(plan);
    expect(result['status'], 'committed');
    expect(h.storage.saveCount, 1);
    expect(
      h.session.committedData.generalMode.schedules.length,
      original.generalMode.schedules.length + 1,
    );
    expect(
      h.session.committedData.generalMode.activeScheduleId,
      original.generalMode.activeScheduleId,
    );
    final added = h.session.committedData.generalMode.schedules.last;
    expect(added.id, isNot(id));
    expect(added.events, isNotEmpty);
    final replay = await h.call('file_imports.prepare', {
      ...args,
      'operationId': plan['operationId'],
    });
    await h.commit(replay);
    expect(h.storage.saveCount, 1);
    final undo = await h.call('undo.prepare', {
      'operationId': plan['operationId'],
    });
    await h.commit(undo);
    expect(
      h.session.committedData.generalMode.toJson(),
      original.generalMode.toJson(),
    );
  });

  test(
    'file import retains the direct importer duplicate-content semantics',
    () async {
      final before = h.session.committedData.generalMode;
      final calendar = before.schedules.last;
      final text = await inlineDataTransferCodec.encodeSchedules(before, [
        calendar.id,
      ], localeCode: 'en');
      h.sources.add(
        ConversationSource(id: 'duplicate-file', text: text, kind: 'json'),
      );
      final plan = await h.call('file_imports.prepare', {
        'sourceId': 'duplicate-file',
        'format': 'schedules_json',
        'action': 'add',
        'ids': [calendar.id],
      });
      await h.commit(plan);
      expect(h.session.committedData.generalMode.toJson(), before.toJson());
    },
  );

  test(
    'imports manage disabled data without enabling or navigating its workspace',
    () async {
      final id = await attachCalendar();
      final before = h.session.committedData;
      await h.session.commitMutation(
        (data) => data.copyWith(
          enabledWorkspaces: {AppMode.student},
          activeMode: AppMode.student,
        ),
        expectedEpoch: h.session.mutationEpoch,
      );
      final plan = await h.call('file_imports.prepare', {
        'sourceId': 'file',
        'format': 'schedules_json',
        'action': 'add',
        'ids': [id],
      });
      await h.commit(plan);
      expect(
        h.session.committedData.isWorkspaceEnabled(AppMode.general),
        isFalse,
      );
      expect(h.session.committedData.activeMode, AppMode.student);
      expect(
        h.session.committedData.generalMode.activeScheduleId,
        before.generalMode.activeScheduleId,
      );
    },
  );

  test(
    'unknown selected IDs and deleted replacement targets never fall back',
    () async {
      final id = await attachCalendar();
      for (final args in [
        {
          'sourceId': 'file',
          'format': 'schedules_json',
          'action': 'add',
          'ids': [id, 'missing'],
        },
        {
          'sourceId': 'file',
          'format': 'schedules_json',
          'action': 'replace',
          'ids': [id],
          'targetId': 'missing',
        },
      ]) {
        await expectLater(
          h.call('file_imports.prepare', args),
          throwsA(_problem(OperationErrorCode.notFound)),
        );
      }
      expect(h.storage.saveCount, 0);
    },
  );

  test(
    'stale source generations and malformed explicit dates are rejected',
    () async {
      final id = await attachCalendar();
      final source = h.sources.single;
      h.sources[0] = ConversationSource(
        id: 'file',
        text: source.text,
        kind: 'json',
        provenance: ConversationSourceProvenance(
          title: 'Old source',
          capturedAt: DateTime.utc(2026, 10, 29),
          reviewedAt: DateTime.utc(2026, 10, 29),
          datasetGeneration: 'old-generation',
          localeCode: 'en',
        ),
      );
      await expectLater(
        h.call('file_imports.prepare', {
          'sourceId': 'file',
          'format': 'schedules_json',
          'action': 'add',
          'ids': [id],
        }),
        throwsA(_problem(OperationErrorCode.expired)),
      );
      h.sources[0] = source;
      await expectLater(
        h.call('file_imports.prepare', {
          'sourceId': 'file',
          'format': 'schedules_json',
          'action': 'add',
          'ids': [id],
          'confirmedStartDates': {id: '2026-02-31'},
        }),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      expect(h.storage.saveCount, 0);
    },
  );

  test(
    'timetable files import once with courses and bound time sets and can undo',
    () async {
      final before = h.session.committedData;
      final table = before.studentMode.timetables.last;
      final source = await inlineDataTransferCodec.encodeTimetables(
        before.studentMode,
        [table.id],
        localeCode: 'en',
      );
      h.sources.add(
        ConversationSource(id: 'timetable-file', text: source, kind: 'json'),
      );
      final plan = await h.call('file_imports.prepare', {
        'sourceId': 'timetable-file',
        'format': 'timetables_json',
        'action': 'add',
        'ids': [table.id],
      });
      await h.commit(plan);
      final after = h.session.committedData;
      expect(
        after.studentMode.timetables.length,
        before.studentMode.timetables.length + 1,
      );
      expect(
        after.studentMode.timetables.last.courses.length,
        table.courses.length,
      );
      expect(
        after.studentMode.activeTimetableId,
        before.studentMode.activeTimetableId,
      );
      await h.commit(
        await h.call('undo.prepare', {'operationId': plan['operationId']}),
      );
      expect(
        h.session.committedData.studentMode.toJson(),
        before.studentMode.toJson(),
      );
    },
  );

  test(
    'a syntactically valid but truncated attachment cannot be imported',
    () async {
      final id = await attachCalendar();
      final source = h.sources.single;
      h.sources[0] = ConversationSource(
        id: source.id,
        text: source.text,
        kind: source.kind,
        truncated: true,
      );
      await expectLater(
        h.call('file_imports.prepare', {
          'sourceId': source.id,
          'format': 'schedules_json',
          'action': 'add',
          'ids': [id],
        }),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      expect(h.storage.saveCount, 0);
    },
  );

  test('period-time file addition uses strict mutation and preserves existing bound sets', () async {
    final before = h.session.committedData;
    final source = await inlineDataTransferCodec.encodePeriodTimes(
      buildDefaultPeriodTimes(),
    );
    h.sources.add(
      ConversationSource(id: 'period-file', text: source, kind: 'json'),
    );
    final plan = await h.call('file_imports.prepare', {
      'sourceId': 'period-file',
      'format': 'period_times_json',
      'action': 'add',
      'name': 'Imported times',
    });
    await h.commit(plan);
    expect(
      h.session.committedData.studentMode.periodTimeSets.length,
      before.studentMode.periodTimeSets.length + 1,
    );
    expect(
      h.session.committedData.studentMode.timetables.map(
        (t) => t.config.periodTimeSetId,
      ),
      before.studentMode.timetables.map((t) => t.config.periodTimeSetId),
    );
  });

  test('file artifacts are actual export content and saving has an independent permission gate', () async {
    final id = h.session.committedData.generalMode.schedules.last.id;
    AgentDataArtifact? saved;
    h.workflows.bindServices(
      saveArtifact: (artifact) async {
        saved = artifact;
        return const AgentArtifactWriteResult(
          saved: true,
          destination: 'chosen-destination.json',
        );
      },
    );
    final artifact = await h.call('exports.prepare', {
      'format': 'schedules_json',
      'ids': [id],
    });
    expect(artifact['fileWritten'], isFalse);
    expect(saved, isNull);
    final write = await h.call('exports.write', {
      'artifactId': artifact['artifactId'],
    });
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      h.externalCommit(write),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    expect(saved, isNull);
    h.scope.policy.update(mode: AgentPermissionMode.ask);
    h.approval = (plan) async => h.scope.approve(plan.id);
    final result = await h.externalCommit(write);
    expect(result['effectStatus'], 'applied');
    expect((result['effectResult'] as Map)['sharedExternally'], isFalse);
    final decoded = await inlineDataTransferCodec.decodeSchedules(
      saved!.text,
      localeCode: 'en',
    );
    expect(decoded.schedules.single.id, id);
    expect(jsonDecode(saved!.text), isA<Map>());
    h.workflows.bindServices();
    final replay = await h.call('exports.write', {
      'artifactId': artifact['artifactId'],
      'operationId': write['operationId'],
    });
    expect((await h.externalCommit(replay))['replayed'], isTrue);
  });

  test('destination cancellation and service rebinding never fabricate a saved file', () async {
    h.workflows.bindServices(
      saveArtifact: (_) async =>
          const AgentArtifactWriteResult(saved: false, cancelled: true),
    );
    final id = h.session.committedData.studentMode.timetables.last.id;
    final artifact = await h.call('exports.prepare', {
      'format': 'timetables_json',
      'ids': [id],
    });
    final write = await h.call('exports.write', {
      'artifactId': artifact['artifactId'],
    });
    final result = await h.externalCommit(write);
    expect(result['effectStatus'], 'failed');
    expect((result['effectResult'] as Map)['cancelled'], isTrue);
    final next = await h.call('exports.write', {
      'artifactId': artifact['artifactId'],
    });
    h.workflows.bindServices();
    await expectLater(
      h.externalCommit(next),
      throwsA(_problem(OperationErrorCode.conflict)),
    );
  });

  test('clear and navigation callbacks run only after the concrete external plan is accepted', () async {
    var cleared = 0, navigated = 0;
    h.workflows.bindServices(
      clearData: (scope) async {
        expect(scope, same(h.scope));
        cleared++;
        return ExternalEffectResult(
          state: ExternalEffectState.applied,
          dataStatus: ExternalDataState.committed,
          details: {'cleared': true},
        );
      },
      navigation: (target) async {
        expect(
          target.ref!.id,
          h.session.committedData.studentMode.timetables.last.id,
        );
        navigated++;
        return ExternalEffectResult(state: ExternalEffectState.applied);
      },
    );
    final navigate = await h.call('navigation.open', {
      'workspace': 'student',
      'ref': {
        'kind': 'timetable',
        'id': h.session.committedData.studentMode.timetables.last.id,
      },
    });
    expect(navigated, 0);
    await h.externalCommit(navigate);
    expect(navigated, 1);
    final clear = await h.call('maintenance.prepare_clear');
    expect(cleared, 0);
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      h.externalCommit(clear),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    h.scope.policy.update(mode: AgentPermissionMode.full);
    await h.externalCommit(clear);
    expect(cleared, 1);
  });

  test('unavailable backup and destination hosts fail explicitly', () async {
    expect((await h.call('backups.describe'))['supported'], isFalse);
    await expectLater(
      h.call('backups.prepare_restore', {'sourceId': 'missing'}),
      throwsA(_problem(OperationErrorCode.unsupported)),
    );
    await expectLater(
      h.call('maintenance.prepare_clear'),
      throwsA(_problem(OperationErrorCode.unsupported)),
    );
    await expectLater(
      h.call('workspaces.prepare', {
        'workspace': 'student',
        'action': 'disable',
      }),
      throwsA(_problem(OperationErrorCode.unsupported)),
    );
  });
}
