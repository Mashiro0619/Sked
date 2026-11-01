import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/device_preferences_store.dart';

import '../../support/agenda_notification_memory.dart';
import '../../support/workspace_harness.dart';

/// Stable, deliberately ambiguous data: matching course names in two tables,
/// one real timetable conflict, and a hidden calendar that still occupies time.
AppData acceptanceData() {
  final initial = buildInitialAppData(buildDefaultPeriodTimes());
  const periods = PeriodTimeSet(
    id: 'periods',
    name: 'Campus periods',
    periodTimes: [
      CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
      CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 600),
    ],
  );
  CourseItem course(String id, String name, int period) => CourseItem(
    id: id,
    name: name,
    teacher: 'Original teacher',
    location: 'Original room',
    dayOfWeek: 1,
    semesterWeeks: const [1, 2, 3, 4],
    periods: [period],
    startMinutes: 0,
    endMinutes: 0,
    timeRange: '00:00 - 00:00',
    credit: 2,
    remarks: 'Keep this note',
    customFields: const {'group': 'A'},
  );
  TimetableData table(String id, List<CourseItem> courses) => TimetableData(
    id: id,
    config: TimetableConfig(
      name: id,
      startDate: DateTime(2026, 9, 7),
      totalWeeks: 18,
      periodTimeSetId: periods.id,
    ),
    courses: courses,
  );
  return initial.copyWith(
    enabledWorkspaces: {AppMode.student, AppMode.general},
    activeMode: AppMode.student,
    agentSettings: const AgentSettings(
      enabled: true,
      permissionMode: AgentPermissionMode.full,
      endpoint: 'https://acceptance.invalid/v1',
      model: 'deterministic-fixture',
    ),
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: 'current',
      showPastEndedCourses: true,
      showFutureCourses: true,
      periodTimeSets: [periods],
      timetables: [
        table('current', [
          course('algebra', 'Algebra', 1),
          course('physics', 'Physics', 1),
        ]),
        table('other', [course('other-algebra', 'Algebra', 2)]),
      ],
    ),
    generalMode: initial.generalMode.copyWith(
      activeScheduleId: 'visible',
      selectedDateIso: '2026-09-07',
      schedules: [
        const GeneralSchedule(id: 'visible', name: 'Study', events: []),
        GeneralSchedule(
          id: 'hidden',
          name: 'Hidden appointments',
          isVisible: false,
          events: [
            GeneralEvent(
              id: 'appointment',
              calendarId: 'hidden',
              title: 'Hidden appointment',
              startDateTimeIso: '2026-09-07T10:00:00.000',
              endDateTimeIso: '2026-09-07T11:00:00.000',
              notes: 'Preserve private note',
            ),
            GeneralEvent(
              id: 'weekly',
              calendarId: 'hidden',
              title: 'Weekly review',
              startDateTimeIso: '2026-09-07T13:00:00.000',
              endDateTimeIso: '2026-09-07T14:00:00.000',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.weekly,
                count: 4,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class AcceptanceConversationStorage extends ConversationStorage {
  AcceptanceConversationStorage() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}

class _NoNetworkProvider extends ProviderClient {
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) => Stream.error(StateError('Acceptance tasks must not contact a model.'));
}

/// An explicitly synthetic native gateway; these tests do not prove OS grants.
class AcceptanceNotificationGateway extends MemoryAgendaNotificationGateway {
  var permission = AgendaNotificationPermissionState.denied;
  @override
  Future<bool> requestPermission() async {
    permission = AgendaNotificationPermissionState.granted;
    return true;
  }

  @override
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot() async =>
      AgendaNotificationPlatformSnapshot(
        sampledAt: DateTime.utc(2026, 9, 7),
        pendingIds: const [],
        activeIds: const [],
        platform: AgendaNotificationPlatform.android,
        permissionState: permission,
        exactAlarmState: AgendaNotificationExactAlarmState.exact,
      );
}

/// Uses AppRuntime's actual registration, reducers, journals, conversation
/// ownership and commit gates. Only storage, model transport and native UI are
/// replaced. A scenario cannot manufacture a successful domain-tool response.
class AcceptanceHarness {
  final conversations = AcceptanceConversationStorage();
  final credentials = MemoryAgentCredentialStore();
  final layout = DesktopLayoutPreferences.memory();
  final developer = DeveloperUiPreferences.memory();
  final gateway = AcceptanceNotificationGateway();
  late final notifications = AgendaNotificationService(
    enabled: true,
    gateway: gateway,
    runtimeStore: MemoryAgendaNotificationRuntimeStore(),
  );
  final writtenArtifacts = <AgentDataArtifact>[];
  final navigationTargets = <AgentNavigationTarget>[];
  final invokedTools = <String>[];
  late final WorkspaceMemoryStorage storage;
  late final AppRuntime app;
  late String conversationId;
  late OperationScope scope;
  late AgentApprovalRequester approval;

  AppData get saved => AppData.decodeStorageSnapshot(storage.data.encode());

  Future<void> initialize({AppData? data, ProviderClient? provider}) async {
    storage = WorkspaceMemoryStorage(data ?? acceptanceData());
    app = await workspaceProvider(
      storage: storage,
      agentConversationStorage: conversations,
      agentCredentialStore: credentials,
      agentProvider: provider ?? _NoNetworkProvider(),
      devicePreferences: DevicePreferencesStore(
        layout: layout,
        developerUi: developer,
      ),
    );
    await app.agent.initialize();
    conversationId = (await app.agent.conversations.create(
      title: 'Synthetic acceptance',
      mode: AgentPermissionMode.full,
    )).id;
    app.agent.platformTools.bindServices(
      notifications: notifications,
      layout: layout,
      developerUi: developer,
    );
    app.agent.workflowTools.bindServices(
      saveArtifact: (artifact) async {
        writtenArtifacts.add(artifact);
        return const AgentArtifactWriteResult(
          saved: true,
          destination: 'memory://accepted-artifact',
        );
      },
      navigation: (target) async {
        navigationTargets.add(target);
        return ExternalEffectResult(
          state: ExternalEffectState.applied,
          details: {'opened': target.toJson()},
        );
      },
    );
  }

  Future<void> attach(String id, String kind, String text) async {
    await app.agent.conversations.update(
      conversationId,
      (current) => current.copyWith(
        sources: [
          ...current.sources,
          ConversationSource(id: id, kind: kind, text: text),
        ],
      ),
    );
  }

  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    invokedTools.add(name);
    return app.agent.tools.execute(
      ProviderToolCall(
        id: 'acceptance-${invokedTools.length}',
        name: name,
        arguments: jsonEncode(args),
      ),
      scope,
      approval,
    );
  }

  Future<Map<String, Object?>> commit(Map<String, Object?> plan) async {
    final result = await call('mutation.commit', {'planId': plan['planId']});
    expect(result['status'], 'committed');
    final receipt = await call('operations.status', {
      'operationId': plan['operationId'],
    });
    expect(receipt['status'], 'committed');
    expect(receipt['operationId'], plan['operationId']);
    return result;
  }

  Future<Map<String, Object?>> externalCommit(Map<String, Object?> plan) =>
      call('external.commit', {'planId': plan['planId']});

  Future<void> run(Future<void> Function() task, {String? skill}) async {
    Object? failure;
    StackTrace? failureStack;
    await app.agent.runtime.runHostAction(conversationId, (
      operation,
      ask,
    ) async {
      scope = operation;
      approval = ask;
      try {
        if (skill != null) {
          expect(
            await call('skills.load', {'id': skill}),
            containsPair('status', 'loaded'),
          );
        }
        await task();
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      }
      return {'status': failure == null ? 'complete' : 'failed'};
    });
    // Runtime intentionally normalizes host errors. Preserve test failures and
    // their original stacks instead of letting a failed assertion look passed.
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }

  Future<void> close() async {
    await app.agent.quiesce();
    app.dispose();
    notifications.dispose();
    layout.dispose();
    developer.dispose();
  }
}
