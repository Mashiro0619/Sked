import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/timetable_storage_fakes.dart';

/// Core tool tests use the same session and durable reducers without requiring
/// a mounted application or unrelated platform adapters.
class CoreToolHarness {
  late final AppSession session;
  late final MutationCoordinator mutations;
  late final ApplicationToolHost tools;

  Future<void> initialize() async {
    final repository = AppRepository(
      storage: MemoryTimetableStorage(
        initialData: buildInitialAppData(buildDefaultPeriodTimes()),
      ),
    );
    session = AppSession(
      repository: repository,
      initialData: (await repository.load())!,
      requireMutationAllowed: () {},
    );
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
    );
    tools = ApplicationToolHost(
      session: session,
      mutations: mutations,
      conversationForScope: (_) => null,
    );
  }

  Future<void> close() async {
    await mutations.waitForPendingWrites();
    await session.close();
  }
}
