import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/generated/api/models.dart' as view;
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_data_maintenance.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/agent_settings.dart';

import 'agent_rust_offline_workspace.dart';

const _calendar = 'native-history-calendar';
const _model = 'native-history-model';
const _settings = AgentSettings(
  endpoint: 'https://offline.invalid/history',
  model: _model,
  permissionMode: AgentPermissionMode.full,
  models: [
    AgentModelConfig(
      id: _model,
      reasoningEfforts: [AgentReasoningEffort.medium],
      defaultReasoningEffort: AgentReasoningEffort.medium,
      autoCompact: false,
    ),
  ],
);

Future<void> runRustHistoryJourney(
  Directory journeyRoot,
  List<String> checkpoints,
) async {
  final directory = Directory(
    path.join(journeyRoot.path, 'history-maintenance'),
  );
  var workspace = OfflineAgentWorkspace(directory);
  var events = <native.AgentEvent>[];
  StreamSubscription<native.AgentEvent>? subscription;
  try {
    final seed =
        buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'zh_CN',
        ).copyWith(
          activeMode: AppMode.general,
          agentSettings: _settings,
          generalMode: const GeneralScheduleData(
            activeScheduleId: _calendar,
            selectedDateIso: '2026-11-09',
            schedules: [
              GeneralSchedule(id: _calendar, name: '历史恢复', events: []),
            ],
          ),
        );
    await workspace.open(
      seed: seed,
      replies: [
        _reply(
          tool: 'capabilities.describe',
          callId: 'history-discover',
          arguments: {
            'names': ['mutation.apply'],
          },
        ),
        _reply(
          tool: 'mutation.apply',
          callId: 'history-create',
          arguments: {
            'commands': [
              {
                'kind': 'event',
                'action': 'create',
                'destinationParentId': _calendar,
                'values': {
                  'title': '原始安排',
                  'start': '2026-11-09T16:00:00',
                  'end': '2026-11-09T17:00:00',
                },
              },
            ],
          },
        ),
        _reply(text: '原始安排已保存。'),
      ],
    );
    subscription = workspace.client.events.listen(events.add);
    final conversation = await workspace.app.agent.conversations.createDraft(
      title: '历史维护旅程',
      mode: AgentPermissionMode.full,
    );
    final id = conversation.id;
    await workspace.app.agent.runtime.send(id, '创建原始安排');
    final first = (await workspace.app.agent.runtime.loadConversation(id))!;
    final firstRun = first.conversation.runId!;
    await _settled(workspace, events, firstRun);
    final original = (await workspace.app.agent.runtime.loadConversation(id))!;
    final user = original.messages.firstWhere(
      (message) => message.role == view.ViewMessageRole.user,
    );
    expect(
      workspace.app.session.committedData.generalMode.schedules.single.events,
      hasLength(1),
    );
    await workspace.app.persistence.flushPendingUiStateSaves();
    await workspace.app.agent.quiesce();

    workspace.writeGate.arm();
    workspace.writeGate.loseNextReply = true;
    final redo = workspace.app.agent.history.editAndRedo(
      id,
      user.id,
      '重新整理这条安排',
    );
    await workspace.writeGate.entered.future.timeout(
      const Duration(seconds: 20),
    );
    expect(workspace.app.maintenance.isReserved, isTrue);
    expect(workspace.app.agent.history.ownsMaintenance, isTrue);
    expect(workspace.app.agent.conversations.canWrite, isFalse);
    expect(
      workspace.app.maintenance.ensureMutationAllowed,
      throwsA(isA<AppBackupRestoreInProgressException>()),
    );
    final inverseRun = (await workspace.app.agent.runtime.loadConversation(id))!
        .conversation
        .runId!;
    workspace.writeGate.release();
    await redo;
    await _settled(workspace, events, inverseRun);
    final interrupted = (await workspace.app.agent.runtime.loadConversation(
      id,
    ))!;
    final batchId = interrupted.redoBatches.last.id;
    expect(interrupted.redoBatches.last.phase, view.ViewRedoPhase.undoing);
    expect(workspace.writeGate.lostReplies, 1);
    expect(workspace.app.agent.history.ownsMaintenance, isTrue);
    expect(workspace.app.session.repository.isWriteStateUnknown, isTrue);
    expect(workspace.app.agent.history.canEndRedo(id), isFalse);
    expect(interrupted.runs.last.requests, isEmpty);
    final durable = (await IoTimetableStorage(
      layout: workspace.layout,
    ).load()).data!;
    expect(durable.generalMode.schedules.single.events, isEmpty);
    final receiptIds = durable.applicationLedger!.receipts
        .map((receipt) => receipt.operationId)
        .toSet();
    expect(receiptIds, hasLength(2));
    final runCount = interrupted.runs.length;
    checkpoints.add('历史逆变更持有实际业务租约，已保存但回执丢失时保留恢复门禁');

    await subscription.cancel();
    subscription = null;
    await workspace.close();
    workspace = OfflineAgentWorkspace(directory);
    await workspace.open(replies: [_reply(text: '已根据恢复后的状态继续处理。')]);
    events = [];
    subscription = workspace.client.events.listen(events.add);
    final recovered = (await workspace.app.agent.runtime.loadConversation(id))!;
    expect(recovered.redoBatches.last.id, batchId);
    expect(recovered.redoBatches.last.phase, view.ViewRedoPhase.ready);
    expect(recovered.runs, hasLength(runCount));
    expect(workspace.app.maintenance.isReserved, isFalse);
    expect(workspace.app.agent.history.ownsMaintenance, isFalse);
    expect(
      workspace.app.session.committedData.applicationLedger!.receipts
          .map((receipt) => receipt.operationId)
          .toSet(),
      receiptIds,
    );
    expect(workspace.app.agent.history.canEndRedo(id), isTrue);
    final references = await workspace.app.agent.validateComposerReferences(
      id,
      [
        AgentComposerReference.resource(
          ref: const ResourceRef(kind: ResourceKind.calendar, id: _calendar),
          datasetGeneration: workspace.app.agent.mutations.generation,
          label: '恢复后的日历',
        ),
      ],
    );
    await workspace.app.agent.history.replacePendingReferences(id, references);
    expect(
      workspace.app.agent.history.pendingRedoRequest(id)!.contextReferences,
      hasLength(1),
    );
    await workspace.app.agent.history.continueRedo(id);
    final continued = (await workspace.app.agent.runtime.loadConversation(id))!;
    await _settled(workspace, events, continued.conversation.runId!);
    final completed = (await workspace.app.agent.runtime.loadConversation(id))!;
    expect(completed.redoBatches.last.phase, view.ViewRedoPhase.completed);
    expect(
      workspace.app.session.committedData.applicationLedger!.receipts
          .map((receipt) => receipt.operationId)
          .toSet(),
      receiptIds,
    );
    checkpoints.add('重新打开仅恢复既定逆变更并保留回执，重新绑定引用后由用户继续模型重放');
  } finally {
    workspace.writeGate.release();
    await subscription?.cancel();
    await workspace.close();
  }
}

Future<void> _settled(
  OfflineAgentWorkspace workspace,
  List<native.AgentEvent> events,
  String runId,
) async {
  bool matches(native.AgentEvent event) =>
      event.kind == native.EventKind.runSettled && event.runId == runId;
  if (events.any(matches)) return;
  await workspace.client.events
      .firstWhere(matches)
      .timeout(const Duration(seconds: 20));
}

native.OfflineModelReply _reply({
  String text = '',
  String? tool,
  String? callId,
  Map<String, Object?>? arguments,
}) {
  final delta = tool == null
      ? {'role': 'assistant', 'content': text}
      : {
          'role': 'assistant',
          'tool_calls': [
            {
              'index': 0,
              'id': callId,
              'type': 'function',
              'function': {
                'name': tool.replaceAll('_', '_u').replaceAll('.', '__'),
                'arguments': jsonEncode(arguments),
              },
            },
          ],
        };
  Map<String, Object?> chunk(Map<String, Object?> part, String? finish) => {
    'id': 'history-${callId ?? 'answer'}',
    'object': 'chat.completion.chunk',
    'created': 0,
    'model': _model,
    'choices': [
      {'index': 0, 'delta': part, 'finish_reason': finish},
    ],
  };
  return native.OfflineModelReply(
    status: 200,
    contentType: 'text/event-stream',
    body:
        'data: ${jsonEncode(chunk(delta, null))}\n\n'
        'data: ${jsonEncode(chunk({}, tool == null ? 'stop' : 'tool_calls'))}\n\n'
        'data: [DONE]\n\n',
  );
}
