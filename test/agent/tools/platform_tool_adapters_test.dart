import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/tools/platform_tool_adapters.dart';
import 'package:sked/application/approval_plan.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/school_web_session_service.dart';

import '../../support/agenda_notification_memory.dart';

class _AppStorage implements TimetableStorage {
  _AppStorage(this.data);
  AppData data;
  int saves = 0;
  Object? error;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    saves++;
    if (error != null) throw error!;
    data = AppData.decodeStorageSnapshot(value.encode());
  }

  @override
  Future<String?> filePath() async => null;
}

class _SiteStorage extends SchoolSiteStore {
  _SiteStorage() : super.base();
  String source = encodeSchoolSiteStorageSnapshot(const [
    SchoolSite(
      id: 'fixture-school',
      name: 'School',
      loginUrl: 'https://school.test',
    ),
  ]);
  int saves = 0;
  Object? error;
  @override
  Future<String?> load() async => source;
  @override
  Future<SchoolSiteStoreLoadResult> loadResult() async =>
      SchoolSiteStoreLoadResult(
        candidates: [SchoolSiteStoreCandidate(source: source)],
        hasArtifacts: true,
      );
  @override
  Future<void> save(String source) async {
    saves++;
    if (error != null) throw error!;
    this.source = source;
  }

  @override
  Future<String?> filePath() async => null;
}

class _Gateway extends MemoryAgendaNotificationGateway {
  var platform = AgendaNotificationPlatform.android;
  var permission = AgendaNotificationPermissionState.denied;
  var exact = AgendaNotificationExactAlarmState.inexact;
  int permissionRequests = 0;
  int exactRequests = 0;
  int settingsRequests = 0;
  int scheduleCalls = 0;
  Object? scheduleError;

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    scheduleCalls++;
    if (scheduleError != null) throw scheduleError!;
    await super.schedule(request, exact: exact);
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true; // Compatibility acknowledgement is not grant evidence.
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactRequests++;
    return true;
  }

  @override
  Future<bool> openNotificationSettings() async {
    settingsRequests++;
    return true;
  }

  @override
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot() async =>
      AgendaNotificationPlatformSnapshot(
        sampledAt: DateTime.utc(2026, 10, 30),
        pendingIds: const [],
        activeIds: const [],
        platform: platform,
        permissionState: permission,
        exactAlarmState: exact,
      );
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _AppStorage storage;
  late _SiteStorage siteStorage;
  late SchoolSiteService sites;
  late AppSession session;
  late ExternalOperationCoordinator external;
  late ApplicationToolHost host;
  late OperationScope scope;
  late _Gateway gateway;
  late AgendaNotificationService notifications;
  late SchoolWebSessionService browser;
  var clearCalls = 0;
  var clearFails = false;
  Future<MutationApproval?> Function(ApprovalPlan)? approval;

  Future<Map<String, Object?>> call(
    String name, [
    Map<String, Object?> args = const {},
  ]) => host.execute(
    ProviderToolCall(id: name, name: name, arguments: jsonEncode(args)),
    scope,
    approval ?? (_) async => null,
  );
  Future<Map<String, Object?>> commit(Map<String, Object?> plan) =>
      call('external.commit', {'planId': plan['planId']});

  void register({bool browserSupported = true, bool withNotifications = true}) {
    host = ApplicationToolHost(
      session: session,
      mutations: MutationCoordinator(
        session: session,
        settlePendingChanges: () async {},
        dataSessionRevision: () => 0,
      ),
      conversationForScope: (_) => null,
    );
    registerPlatformTools(
      host,
      external: external,
      notifications: withNotifications ? notifications : null,
      schoolSites: sites,
      schoolWebSession: browser,
      schoolWebSessionSupported: browserSupported,
      loadBundledSchoolSites: () async => '[{"id":"builtin-school","name":"Bundled","loginUrl":"https://bundled.test"}]',
    );
  }

  setUp(() async {
    approval = null;
    clearCalls = 0;
    clearFails = false;
    storage = _AppStorage(buildInitialAppData(buildDefaultPeriodTimes()));
    final repository = AppRepository(storage: storage);
    final loaded = await repository.load();
    session = AppSession(
      repository: repository,
      initialData: loaded!,
      requireMutationAllowed: () {},
    );
    external = ExternalOperationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
    );
    scope = OperationScope(
      id: 'platform-test',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    gateway = _Gateway();
    notifications = AgendaNotificationService(
      gateway: gateway,
      runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      enabled: true,
    );
    siteStorage = _SiteStorage();
    sites = SchoolSiteService(store: siteStorage);
    browser = SchoolWebSessionService(
      platform: TargetPlatform.android,
      isWeb: false,
      clearCookies: () async {
        clearCalls++;
        if (clearFails) throw StateError('fake partial clear');
      },
      clearStorage: () async {},
      clearCache: () async {},
    );
    register();
    addTearDown(() async {
      await session.close();
      notifications.dispose();
      browser.dispose();
    });
  });

  test('notification prepare has no effect and compatibility true cannot fake a grant', () async {
    final plan = await call('notifications.permission.prepare');
    expect(storage.saves, 0);
    expect(gateway.permissionRequests, 0);
    final result = await commit(plan);
    expect(gateway.permissionRequests, 1);
    expect(result['effectStatus'], 'failed');
    expect(
      (result['effectResult'] as Map)['platform'],
      containsPair('permission', 'denied'),
    );
    expect(result['dataStatus'], 'unchanged');
    expect(storage.saves, 2);
  });

  for (final observed in [
    AgendaNotificationExactAlarmState.inexact,
    AgendaNotificationExactAlarmState.exact,
  ]) {
    test(
      'Android exact-alarm request reports observed ${observed.name} and replays without another request',
      () async {
        gateway.exact = observed;
        final original = session.committedData.toJson()
          ..remove('applicationLedger');
        final plan = await call('notifications.exact_alarm.prepare');
        expect(gateway.exactRequests, 0);
        expect(storage.saves, 0);
        final result = await commit(plan);
        expect(gateway.exactRequests, 1);
        expect(
          result['effectStatus'],
          observed == AgendaNotificationExactAlarmState.exact
              ? 'applied'
              : 'failed',
        );
        expect(result['dataStatus'], 'unchanged');
        expect(result['effectResult'], containsPair('requestCompleted', true));
        expect(
          (result['effectResult'] as Map)['platform'],
          containsPair('exactAlarm', observed.name),
        );
        expect(
          session.committedData.toJson()..remove('applicationLedger'),
          original,
        );
        final retry = await call('notifications.exact_alarm.prepare', {
          'operationId': plan['operationId'],
        });
        expect((await commit(retry))['replayed'], isTrue);
        expect(gateway.exactRequests, 1);
      },
    );
  }

  Future<AppData> seedFutureReminder() async {
    final base = session.committedData;
    final data = base.copyWith(
      enabledWorkspaces: {AppMode.student, AppMode.general},
      generalMode: base.generalMode.copyWith(
        activeScheduleId: 'reconcile-calendar',
        schedules: [
          GeneralSchedule(
            id: 'reconcile-calendar',
            name: 'Future reminders',
            events: [
              GeneralEvent(
                id: 'reconcile-event',
                calendarId: 'reconcile-calendar',
                title: 'Only the committed reminder',
                startDateTimeIso: '2026-10-30T09:00:00.000',
                endDateTimeIso: '2026-10-30T10:00:00.000',
                reminderBehavior: GeneralEventReminderBehavior.inherit,
              ),
            ],
          ),
        ],
      ),
      notificationSettings: const NotificationSettings(
        enabled: true,
        generalDefaultMinutesBefore: 10,
        lockScreenShowTitles: true,
      ),
    );
    await session.commitMutation(
      (_) => data,
      expectedEpoch: session.mutationEpoch,
    );
    notifications.dispose();
    notifications = AgendaNotificationService(
      gateway: gateway,
      runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      enabled: true,
      now: () => DateTime(2026, 10, 30, 7),
    )..committedDataReader = () => session.committedData;
    register();
    return session.committedData;
  }

  for (final failSchedule in [false, true]) {
    test(
      'notification reconcile tool ${failSchedule ? 'retains unknown failure without replaying' : 'schedules the committed event without claiming delivery'}',
      () async {
        final data = await seedFutureReminder();
        final original = data.toJson()..remove('applicationLedger');
        final plan = await call('notifications.reconcile.prepare');
        expect(gateway.scheduleCalls, 0);
        expect(gateway.scheduled, isEmpty);
        if (failSchedule) {
          gateway.scheduleError = StateError('Synthetic scheduler failure');
        }
        final result = await commit(plan);
        expect(result['effectStatus'], failSchedule ? 'unknown' : 'applied');
        expect(
          session.committedData.toJson()..remove('applicationLedger'),
          original,
        );
        expect(gateway.scheduleCalls, 1);
        if (failSchedule) {
          expect(result['recoveryRequired'], isTrue);
          expect(
            result['effectResult'],
            containsPair('exactOperationVerified', false),
          );
          expect(gateway.scheduled, isEmpty);
          final checked = await call('external.reconcile', {
            'operationId': plan['operationId'],
          });
          expect(checked['effectStatus'], 'unknown');
          expect(
            checked['effectResult'],
            containsPair('exactOperationVerified', false),
          );
        } else {
          expect(
            result['effectResult'],
            containsPair('deliveryVerified', false),
          );
          expect((result['effectResult'] as Map)['dataVersion'], isNotEmpty);
          final request = gateway.scheduled.values.single;
          expect(request.title, 'Only the committed reminder');
          expect(request.fireAt, DateTime(2026, 10, 30, 8, 50));
          expect(
            result['effectResult'],
            containsPair('directScheduledCount', 1),
          );
          final retry = await call('notifications.reconcile.prepare', {
            'operationId': plan['operationId'],
          });
          expect((await commit(retry))['replayed'], isTrue);
        }
        expect(gateway.scheduleCalls, 1);
      },
    );
  }

  test('diagnostic notifications have permission and replay gates and clear only tests', () async {
    final request = {'action': 'thirty_seconds', 'channel': 'course'};
    final plan = await call('notifications.test.prepare', request);
    expect(gateway.testNotifications, isEmpty);
    scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      commit(plan),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    expect(gateway.testNotifications, isEmpty);
    scope.policy.update(mode: AgentPermissionMode.full);
    final result = await commit(plan);
    expect(result['effectStatus'], 'applied');
    expect((result['effectResult'] as Map)['deliveryVerified'], isFalse);
    expect(gateway.testNotifications.length, 1);
    final retry = await call('notifications.test.prepare', {
      ...request,
      'operationId': plan['operationId'],
    });
    expect((await commit(retry))['replayed'], isTrue);
    expect(gateway.testNotifications.length, 1);
    final productionKeys = gateway.scheduled.keys.toList();
    await commit(
      await call('notifications.test.prepare', {'action': 'clear_tests'}),
    );
    expect(gateway.testNotifications, isEmpty);
    expect(gateway.scheduled.keys.toList(), productionKeys);
  });

  test('snooze requires the current reminder revision and cannot replay a new action', () async {
    final base = session.committedData;
    final table = TimetableData(
      id: 'reminder-table',
      config: TimetableConfig(
        name: 'Term',
        startDate: DateTime(2026, 10, 26),
        totalWeeks: 18,
        periodTimeSetId: base.studentMode.periodTimeSets.first.id,
      ),
      courses: const [],
    );
    final current = DateTime(2026, 10, 30, 7, 55);
    final data = base.copyWith(
      studentMode: base.studentMode.copyWith(
        activeTimetableId: table.id,
        timetables: [
          table.copyWith(
            config: table.config.copyWith(startDate: DateTime(2026, 10, 26)),
            courses: [
              CourseItem(
                id: 'reminder-course',
                name: 'Course',
                teacher: '',
                location: '',
                dayOfWeek: DateTime.friday,
                semesterWeeks: const [1],
                periods: const [],
                startMinutes: 480,
                endMinutes: 540,
                timeRange: '08:00 - 09:00',
                credit: 0,
                remarks: '',
                customFields: const {},
              ),
            ],
          ),
        ],
      ),
      notificationSettings: const NotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
      ),
    );
    await session.commitMutation(
      (_) => data,
      expectedEpoch: session.mutationEpoch,
    );
    notifications.dispose();
    notifications = AgendaNotificationService(
      gateway: gateway,
      runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      enabled: true,
      now: () => current,
    )..committedDataReader = () => session.committedData;
    await notifications.reconcile(data, anchor: DateTime(2026, 10, 30, 7));
    register();
    final listed = await call('notifications.reminders');
    final item = (listed['items'] as List).single as Map;
    final request = {'key': item['key'], 'revision': item['revision']};
    await expectLater(
      call('notifications.snooze.prepare', {...request, 'revision': 'stale'}),
      throwsA(_problem(OperationErrorCode.conflict)),
    );
    final plan = await call('notifications.snooze.prepare', request);
    scope.policy.update(mode: AgentPermissionMode.plan);
    await expectLater(
      commit(plan),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    scope.policy.update(mode: AgentPermissionMode.full);
    final result = await commit(plan);
    expect(result['effectStatus'], 'applied');
    expect(
      (result['effectResult'] as Map)['snoozedUntil'],
      DateTime(2026, 10, 30, 8, 5).toIso8601String(),
    );
    final retry = await call('notifications.snooze.prepare', {
      ...request,
      'operationId': plan['operationId'],
    });
    expect((await commit(retry))['replayed'], isTrue);
    expect(
      gateway.scheduled[item['key']]!.fireAt,
      DateTime(2026, 10, 30, 8, 5),
    );
  });

  test('Windows permission stays unknown while opening settings has its own result', () async {
    gateway.platform = AgendaNotificationPlatform.windows;
    gateway.permission = AgendaNotificationPermissionState.unknown;
    gateway.exact = AgendaNotificationExactAlarmState.notApplicable;
    final requested = await commit(
      await call('notifications.permission.prepare'),
    );
    expect(requested['effectStatus'], 'unknown');
    expect(requested['recoveryRequired'], isTrue);
    final opened = await commit(await call('notifications.settings.prepare'));
    expect(opened['effectStatus'], 'applied');
    expect(
      (opened['effectResult'] as Map)['permissionGrantedByOpening'],
      isFalse,
    );
    expect(gateway.settingsRequests, 1);
    await expectLater(
      call('notifications.exact_alarm.prepare'),
      throwsA(_problem(OperationErrorCode.unsupported)),
    );
  });

  test('permission mode and declined approval prevent native calls and pending writes', () async {
    scope.policy.update(mode: AgentPermissionMode.plan);
    final plan = await call('notifications.permission.prepare');
    await expectLater(
      commit(plan),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    scope.policy.update(mode: AgentPermissionMode.ask);
    await expectLater(
      commit(plan),
      throwsA(_problem(OperationErrorCode.cancelled)),
    );
    expect(storage.saves, 0);
    expect(gateway.permissionRequests, 0);
    approval = (concrete) async {
      expect(concrete.changes.single.before, 'denied');
      expect(concrete.changes.single.after, 'requestPermission');
      return scope.approve(concrete.id);
    };
    gateway.permission = AgendaNotificationPermissionState.granted;
    final result = await commit(plan);
    expect(result['effectStatus'], 'applied');
  });

  test('unsupported notification tools do not call a platform stub', () async {
    register(withNotifications: false);
    final status = await call('notifications.status');
    expect(status['platform'], containsPair('permission', 'unsupported'));
    await expectLater(
      call('notifications.permission.prepare'),
      throwsA(_problem(OperationErrorCode.unsupported)),
    );
    expect(gateway.permissionRequests, 0);
  });

  test(
    'pending receipt storage failure never asks the platform for permission',
    () async {
      final plan = await call('notifications.permission.prepare');
      storage.error = StateError('fake disk error');
      await expectLater(
        commit(plan),
        throwsA(_problem(OperationErrorCode.storageFailure)),
      );
      expect(gateway.permissionRequests, 0);
    },
  );

  test('school site CRUD uses current version handles and shared service persistence', () async {
    final listed = await call('school_sites.list');
    final handle = ((listed['items'] as List).single as Map)['handle'];
    final id = ((listed['items'] as List).single as Map)['id'];
    final plan = await call('school_sites.prepare', {
      'action': 'patch',
      'handle': handle,
      'site': {'name': 'Renamed'},
    });
    expect(siteStorage.saves, 0);
    final result = await commit(plan);
    expect(result['effectStatus'], 'applied');
    expect(decodeSchoolSitesStrict(siteStorage.source).single.name, 'Renamed');
    expect(decodeSchoolSitesStrict(siteStorage.source).single.id, id);
    await expectLater(
      call('school_sites.get', {'handle': handle}),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    final current = await call('school_sites.list');
    final deletion = await call('school_sites.prepare', {
      'action': 'delete',
      'handle': ((current['items'] as List).single as Map)['handle'],
    });
    await commit(deletion);
    expect(decodeSchoolSitesStrict(siteStorage.source), isEmpty);
  });

  test(
    'UI write and reload during approval cannot overwrite a newer school list',
    () async {
      final plan = await call('school_sites.prepare', {
        'action': 'create',
        'site': {'name': 'Agent', 'loginUrl': 'https://agent.test'},
      });
      await sites.saveSites(const [
        SchoolSite(name: 'UI', loginUrl: 'https://ui.test'),
      ]);
      await sites.loadSitesResult();
      await expectLater(
        commit(plan),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(decodeSchoolSitesStrict(siteStorage.source).single.name, 'UI');
      expect(siteStorage.saves, 1);
      expect(storage.saves, 0);
    },
  );

  test(
    'school-site operation retry after state changed returns original receipt',
    () async {
      const request = {
        'action': 'create',
        'site': {'name': 'Agent', 'loginUrl': 'https://agent.test'},
      };
      final plan = await call('school_sites.prepare', request);
      final first = await commit(plan);
      final retry = await call('school_sites.prepare', {
        ...request,
        'operationId': plan['operationId'],
      });
      final second = await commit(retry);
      expect(second['replayed'], isTrue);
      expect(second['operationId'], first['operationId']);
      expect(siteStorage.saves, 1);
      expect(decodeSchoolSitesStrict(siteStorage.source), hasLength(2));
      await expectLater(
        call('school_sites.prepare', {
          'action': 'restore',
          'operationId': plan['operationId'],
        }),
        throwsA(_problem(OperationErrorCode.duplicateMismatch)),
      );
    },
  );

  test('school-site import and restore use actual bundled/text data; export never writes files', () async {
    final plan = await call('school_sites.prepare', {
      'action': 'import',
      'mode': 'replace',
      'source': '[{"name":"Imported","loginUrl":"https://imported.test"}]',
    });
    await commit(plan);
    expect(decodeSchoolSitesStrict(siteStorage.source).single.name, 'Imported');
    final exported = await call('school_sites.export');
    expect(exported['fileWritten'], isFalse);
    expect(
      decodeSchoolSitesStrict(exported['text'] as String).single.name,
      'Imported',
    );
    await commit(await call('school_sites.prepare', {'action': 'restore'}));
    expect(decodeSchoolSitesStrict(siteStorage.source).single.name, 'Bundled');
    expect(
      decodeSchoolSitesStrict(siteStorage.source).single.id,
      'builtin-school',
    );
    await commit(await call('school_sites.prepare', {'action': 'restore'}));
    expect(
      decodeSchoolSitesStrict(siteStorage.source).single.id,
      'builtin-school',
    );
    await expectLater(
      call('school_sites.prepare', {
        'action': 'import',
        'source': '[{"name":"Invalid"}]',
      }),
      throwsA(_problem(OperationErrorCode.invalidArgument)),
    );
  });

  test('appending an exported site copies a colliding ID and duplicate URLs retain separate handles', () async {
    final exported = await call('school_sites.export');
    await commit(
      await call('school_sites.prepare', {
        'action': 'import',
        'mode': 'append',
        'source': exported['text'],
      }),
    );
    final listed = await call('school_sites.list');
    final items = listed['items'] as List;
    expect(items, hasLength(2));
    expect(items[0]['id'], 'fixture-school');
    expect(items[1]['id'], isNot(items[0]['id']));
    expect(items[1]['loginUrl'], items[0]['loginUrl']);
    await commit(
      await call('school_sites.prepare', {
        'action': 'patch',
        'handle': items[1]['handle'],
        'site': {'name': 'Copied school', 'loginUrl': 'https://copy.test'},
      }),
    );
    final saved = decodeSchoolSitesStrict(siteStorage.source);
    expect(saved.first.id, 'fixture-school');
    expect(saved.first.name, 'School');
    expect(saved.last.id, items[1]['id']);
    expect(saved.last.name, 'Copied school');
    await expectLater(
      call('school_sites.prepare', {
        'action': 'create',
        'site': {
          'id': 'caller-id',
          'name': 'Injected',
          'loginUrl': 'https://copy.test',
        },
      }),
      throwsA(_problem(OperationErrorCode.invalidArgument)),
    );
  });

  test('legacy site receipts still reconcile while a new receipt cannot ignore a different ID', () async {
    for (final legacy in [true, false]) {
      final after = [
        {
          if (!legacy) 'id': 'different-school',
          'name': 'School',
          'loginUrl': 'https://school.test',
        },
      ];
      final prepared = external.prepare(
        scope: scope,
        action: 'school_sites.replace',
        arguments: {'before': const [], 'after': after},
        version: 0,
        changes: [
          ResourceChange(key: 'schoolSites', before: const [], after: after),
        ],
        validate: () {},
        execute: (_) async =>
            ExternalEffectResult(state: ExternalEffectState.unknown),
      );
      await external.commit(planId: prepared.id, scope: scope);
      final result = await call('external.reconcile', {
        'operationId': prepared.operationId,
      });
      expect(result['effectStatus'], legacy ? 'applied' : 'unknown');
    }
    expect(siteStorage.saves, 0);
  });

  test('school web cleanup reports local scope and unknown partial cleanup is never replayed', () async {
    clearFails = true;
    final plan = await call('school_session.clear.prepare');
    final failed = await commit(plan);
    expect(failed['effectStatus'], 'unknown');
    expect(clearCalls, 1);
    final recovery = await call('external.reconcile', {
      'operationId': plan['operationId'],
    });
    expect(recovery['effectStatus'], 'unknown');
    expect(clearCalls, 1);
    expect(
      (recovery['effectResult'] as Map)['remoteSessionsAffected'],
      isFalse,
    );
  });

  test(
    'school web cleanup supports only explicitly wired real platforms',
    () async {
      register(browserSupported: false);
      await expectLater(
        call('school_session.clear.prepare'),
        throwsA(_problem(OperationErrorCode.unsupported)),
      );
      expect(clearCalls, 0);
      register();
      final result = await commit(await call('school_session.clear.prepare'));
      expect(result['effectStatus'], 'applied');
      expect(clearCalls, 1);
    },
  );

  test(
    'connection read strips URL query/fragment and credential reference',
    () async {
      session.replaceData(
        session.data.copyWith(
          agentSettings: const AgentSettings(
            endpoint: 'https://api.test/v1?api_key=do-not-return',
            model: 'model',
            credentialRef: 'opaque-secret-ref',
            models: [
              AgentModelConfig(
                id: 'model',
                reasoningEfforts: [AgentReasoningEffort.medium],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              ),
            ],
          ),
        ),
      );
      await session.persist(session.data);
      final result = await call('agent.connection.get');
      expect(result['endpoint'], 'https://api.test/v1');
      expect(jsonEncode(result), isNot(contains('do-not-return')));
      expect(jsonEncode(result), isNot(contains('opaque-secret-ref')));
    },
  );

  test(
    'strict adapter arguments reject invented platform methods or indices',
    () async {
      await expectLater(
        call('notifications.permission.prepare', {
          'method': 'arbitraryNativeCall',
        }),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      await expectLater(
        call('school_sites.prepare', {'action': 'delete', 'index': 0}),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      expect(storage.saves, 0);
      expect(siteStorage.saves, 0);
    },
  );
}
