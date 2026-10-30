import 'dart:convert';

import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/tools/platform_tool_adapters.dart';
import 'package:sked/application/approval_plan.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/timetable_storage_fakes.dart';

class PlatformToolHarness {
  late final MemoryTimetableStorage storage;
  late final AppSession session;
  late final MutationCoordinator mutations;
  late final ExternalOperationCoordinator external;
  late final ApplicationToolHost host;
  late final PlatformToolAdapters platform;
  final scope = OperationScope(
    id: 'adapter-run',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );
  final sources = <ConversationSource>[];
  Future<MutationApproval?> Function(ApprovalPlan)? approval;

  Future<void> initialize({
    AppData? data,
    MemoryTimetableStorage? storageOverride,
  }) async {
    storage =
        storageOverride ??
        MemoryTimetableStorage(
          initialData:
              data ??
              buildInitialAppData(
                buildDefaultPeriodTimes(),
              ).copyWith(enabledWorkspaces: {AppMode.student, AppMode.general}),
        );
    final repository = AppRepository(storage: storage);
    final loaded = await repository.load();
    session = AppSession(
      repository: repository,
      initialData: loaded!,
      requireMutationAllowed: () {},
    );
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
    );
    external = ExternalOperationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
      fallbackGeneration: () => mutations.generation,
    );
    host = ApplicationToolHost(
      session: session,
      mutations: mutations,
      conversationForScope: (operation) => identical(operation, scope)
          ? AgentConversation(
              id: 'conversation',
              title: 'Test',
              createdAt: DateTime.utc(2026, 10, 30),
              updatedAt: DateTime.utc(2026, 10, 30),
              sources: sources,
            )
          : null,
    );
    platform = registerPlatformTools(host, external: external);
  }

  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) => host.execute(
    ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
    scope,
    approval ?? (_) async => null,
  );
  Future<Map<String, Object?>> externalCommit(Map<String, Object?> plan) =>
      call('external.commit', {'planId': plan['planId']});
  Future<Map<String, Object?>> commit(Map<String, Object?> plan) =>
      call('mutation.commit', {'planId': plan['planId']});
  Future<void> close() async {
    scope.cancel();
    await external.waitForPendingWrites();
    await mutations.waitForPendingWrites();
    await session.close();
  }
}
