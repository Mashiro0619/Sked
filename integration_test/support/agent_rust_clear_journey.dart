import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/agent/bridge/generated/api.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/generated/api/models.dart' as view;
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';

import 'agent_rust_offline_workspace.dart';

Future<void> runRustAgentClearJourney(
  Directory root,
  AppData seed,
  List<String> checkpoints,
) async {
  final workspace = OfflineAgentWorkspace(
    Directory(path.join(root.path, 'clear-lifecycle')),
  );
  await workspace.open(seed: seed);
  final app = workspace.app;
  final id = (await app.agent.conversations.createManagedConversation(
    id: 'clear-lifecycle',
    title: '原生清空生命周期',
    mode: AgentPermissionMode.full,
  )).id;
  final firstCore = await workspace.client.core;
  AgentCore? replacement;
  native.HostRequest? firstRequest;
  final subscription = workspace.client.events.listen((event) {
    final request = event.hostRequest;
    if (firstRequest == null &&
        request?.kind == native.HostRequestKind.execute &&
        request?.toolName == 'maintenance.clear') {
      firstRequest = request;
    }
  });
  var attempts = 0;
  var closedBeforeClear = 0;
  var exited = false;
  app.agent.workflowTools.bindServices(
    clearData: (scope) => app.agent.runMaintenanceFromAgent(scope, () async {
      attempts++;
      final activeCore = await workspace.client.core;
      try {
        await app.dataClear.run(
          clear: () async {
            expect(workspace.client.isInitialized, isFalse);
            await expectLater(
              activeCore.query(
                query: native.AgentQuery(
                  kind: native.QueryKind.readConversation,
                  conversationId: id,
                ),
              ),
              throwsA(isA<Object>()),
            );
            closedBeforeClear++;
            if (attempts == 1) {
              throw StateError(
                'Synthetic clear failed before deleting Agent files.',
              );
            }
            await workspace.agentDirectory.delete(recursive: true);
            expect(await workspace.agentDirectory.exists(), isFalse);
          },
          exit: () async {
            exited = true;
          },
        );
      } catch (error) {
        if (attempts != 1) rethrow;
        expect(error, isA<StateError>());
        expect(app.dataClear.isActive, isFalse);
        expect(app.agent.isInitialized, isFalse);
        await app.agent.initialize();
        replacement = await workspace.client.core;
        expect(identical(replacement, activeCore), isFalse);
        return ExternalEffectResult(
          // This injected failure precedes the deletion call, so the owner
          // can report a known failure without an uncertain external effect.
          state: ExternalEffectState.failed,
          dataStatus: ExternalDataState.unchanged,
          details: const {'dataCleared': false, 'processExitObserved': false},
        );
      }
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        dataStatus: ExternalDataState.committed,
        details: const {'dataCleared': true, 'processExitObserved': false},
      );
    }),
  );
  try {
    await expectLater(
      app.agent.runtime
          .runHostTool(id, toolName: 'maintenance.clear', arguments: const {})
          .timeout(const Duration(seconds: 20)),
      throwsA(isNot(isA<TimeoutException>())),
    );
    expect(firstRequest, isNotNull);
    expect(replacement, isNotNull);
    expect(closedBeforeClear, 1);
    expect(await workspace.agentDirectory.exists(), isTrue);
    expect(app.session.canWrite, isTrue);
    final beforeLate = (await replacement!.query(
      query: native.AgentQuery(
        kind: native.QueryKind.readConversation,
        conversationId: id,
      ),
    )).snapshot!;
    await expectLater(
      firstCore.submitHostResult(
        result: native.HostResult(
          requestId: firstRequest!.id,
          modelContent: const [],
          outcome: native.HostOutcome.success,
        ),
      ),
      throwsA(isA<Object>()),
    );
    final afterLate = (await replacement!.query(
      query: native.AgentQuery(
        kind: native.QueryKind.readConversation,
        conversationId: id,
      ),
    )).snapshot!;
    expect(afterLate.sequence, beforeLate.sequence);
    expect(afterLate.operations, beforeLate.operations);
    checkpoints.add('清空先关闭原生库；删除失败后重开，迟到旧核心回执不进入新核心');

    final interrupted = afterLate.operations.single;
    final operationId = interrupted.binding!.operationId;
    expect(interrupted.binding!.store, view.ViewOperationStore.external_);
    expect(interrupted.phase, view.ViewOperationPhase.unresolved);
    // The maintenance lease changed the write revision, leaving the original
    // receipt pending. Its owner reconciles the observed pre-deletion failure
    // after the first execution has left the external operation queue.
    final reconciled = await app.agent.external.reconcile(
      operationId: operationId,
      readBack: (operation) async {
        expect(operation.operationId, operationId);
        expect(attempts, 1);
        expect(await workspace.agentDirectory.exists(), isTrue);
        return ExternalEffectResult(
          state: ExternalEffectState.failed,
          dataStatus: ExternalDataState.unchanged,
          details: const {'dataCleared': false, 'processExitObserved': false},
        );
      },
    );
    expect(reconciled.receiptFinalized, isTrue);
    expect(reconciled.receipt.operationId, operationId);
    expect(reconciled.receipt.result['effectStatus'], 'failed');

    await expectLater(
      app.agent.runtime
          .runHostTool(id, toolName: 'maintenance.clear', arguments: const {})
          .timeout(const Duration(seconds: 20)),
      throwsA(isNot(isA<TimeoutException>())),
    );
    expect(closedBeforeClear, 2);
    expect(exited, isTrue);
    expect(app.dataClear.isCommitted, isTrue);
    await app.agent.quiesce();
    expect(await workspace.agentDirectory.exists(), isFalse);
    checkpoints.add('Agent自行清空无需等待自身；迟到收尾不重建已删除原生库');
  } finally {
    await subscription.cancel();
    await workspace.close();
  }
}
