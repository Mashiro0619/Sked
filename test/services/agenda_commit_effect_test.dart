import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_effect_ticket.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';

import '../support/agenda_coordinator_harness.dart';
import '../support/agenda_notification_memory.dart';
import '../support/workspace_harness.dart';

class _Gateway extends MemoryAgendaNotificationGateway {
  bool failReads = false;

  @override
  Future<Map<String, DateTime>> pendingPlan() async {
    if (failReads) throw StateError('Synthetic notification read failure.');
    return super.pendingPlan();
  }
}

class _GatedStore extends MemoryAgendaNotificationRuntimeStore {
  Future<void> Function()? beforeNextRead;

  @override
  Future<AgendaNotificationProjectionFence> readProjectionFence() async {
    final gate = beforeNextRead;
    beforeNextRead = null;
    await gate?.call();
    return super.readProjectionFence();
  }
}

class _Fixture {
  late AppRuntime app;
  late AgendaCoordinator agenda;
  final gateway = _Gateway();
  final store = _GatedStore();
  final scope = OperationScope(
    id: 'effect-test',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );

  Future<void> initialize({bool supported = true}) async {
    app = await workspaceProvider();
    final enable = app.agent.mutations.prepare(
      scope: scope,
      settings: [const SettingEdit.set('app.notifications.enabled', true)],
    );
    await app.agent.mutations.commit(planId: enable.id, scope: scope);
    final service = AgendaNotificationService(
      gateway: gateway,
      runtimeStore: store,
      enabled: supported,
      now: () => DateTime(2026, 9, 8, 9),
    );
    agenda = buildTestAgendaCoordinator(
      provider: app,
      notificationService: service,
      productivityBridge: AndroidProductivityBridge(enabled: false),
      clock: () => DateTime(2026, 9, 8, 9),
    );
    app.agent.tools.readNotificationEffect = agenda.effectForOperation;
    addTearDown(() async {
      scope.cancel();
      agenda.dispose();
      await app.shutdown.quiesce();
      app.dispose();
      await app.session.close();
    });
    await agenda.start();
  }

  Future<MutationCommitResult> set(String key, Object value) async {
    final nextCommit = app.session.commits.first;
    final plan = app.agent.mutations.prepare(
      scope: scope,
      settings: [SettingEdit.set(key, value)],
    );
    final result = await app.agent.mutations.commit(
      planId: plan.id,
      scope: scope,
    );
    await nextCommit;
    return result;
  }

  Map<String, Object?> effect(MutationCommitResult result) =>
      app.agent.tools.describeCommitResult(
            result.toJson(),
          )['notificationEffect']
          as Map<String, Object?>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a real committed preference has its own notification observation',
    () async {
      final fixture = _Fixture();
      await fixture.initialize();
      final result = await fixture.set('app.notifications.enabled', false);
      await fixture.agenda.waitForPendingProjections();
      final effect = fixture.effect(result);
      expect(result.toJson()['status'], 'committed');
      expect(
        fixture.app.session.committedData.notificationSettings.enabled,
        isFalse,
      );
      expect(effect['operationId'], result.receipt.operationId);
      expect(effect['generation'], result.receipt.result['generation']);
      expect(effect['desiredRevision'], isA<int>());
      expect(effect['state'], 'applied');
      expect(effect['deliveryObserved'], isFalse);
    },
  );

  test(
    'an unrelated setting does not borrow the latest notification result',
    () async {
      final fixture = _Fixture();
      await fixture.initialize();
      final first = await fixture.set('app.notifications.enabled', false);
      await fixture.agenda.waitForPendingProjections();
      final second = await fixture.set('app.localeCode', 'zh');
      await fixture.agenda.waitForPendingProjections();
      // Locale changes affect notification copy. A subsequent display-only
      // preference is separately classified, even if the last plan succeeded.
      final third = await fixture.set('general.showWeekends', false);
      await fixture.agenda.waitForPendingProjections();
      expect(fixture.effect(first)['state'], 'applied');
      expect(fixture.effect(second)['id'], isNot(fixture.effect(first)['id']));
      expect(fixture.effect(third)['state'], 'notRequired');
    },
  );

  test(
    'a later commit supersedes queued work without changing the save receipt',
    () async {
      final fixture = _Fixture();
      await fixture.initialize();
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.store.beforeNextRead = () async {
        entered.complete();
        await release.future;
      };
      final first = await fixture.set('app.notifications.enabled', false);
      await entered.future;
      expect(fixture.effect(first)['state'], 'pending');
      final second = await fixture.set('app.notifications.enabled', true);
      expect(fixture.effect(first)['state'], 'superseded');
      release.complete();
      await fixture.agenda.waitForPendingProjections();
      expect(fixture.effect(first)['state'], 'superseded');
      expect(fixture.effect(second)['state'], 'applied');
      expect(first.receipt.result['status'], 'committed');
    },
  );

  test(
    'a scheduling failure is attached to its commit while data stays saved',
    () async {
      final fixture = _Fixture();
      await fixture.initialize();
      await fixture.set('app.notifications.enabled', false);
      await fixture.agenda.waitForPendingProjections();
      fixture.gateway.failReads = true;
      final result = await fixture.set('app.notifications.enabled', true);
      await fixture.agenda.waitForPendingProjections();
      expect(
        fixture.app.session.committedData.notificationSettings.enabled,
        isTrue,
      );
      expect(fixture.effect(result)['state'], 'failed');
      expect(result.receipt.result['status'], 'committed');
    },
  );

  test(
    'unsupported projection and lost history cannot report applied',
    () async {
      final fixture = _Fixture();
      await fixture.initialize(supported: false);
      final result = await fixture.set('app.notifications.enabled', false);
      await fixture.agenda.waitForPendingProjections();
      expect(fixture.effect(result)['state'], 'unsupported');
      fixture.app.agent.tools.readNotificationEffect = null;
      final afterRestart = fixture.effect(result);
      expect(afterRestart['state'], 'unknown');
      expect(afterRestart['id'], '${result.receipt.operationId}/notifications');
      expect(afterRestart['deliveryObserved'], isFalse);
    },
  );

  test(
    'closing a coordinator does not leave accepted work pending forever',
    () async {
      final fixture = _Fixture();
      await fixture.initialize();
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.store.beforeNextRead = () async {
        entered.complete();
        await release.future;
      };
      final result = await fixture.set('app.notifications.enabled', false);
      await entered.future;
      final revision = fixture.effect(result)['desiredRevision'] as int;
      fixture.agenda.dispose();
      release.complete();
      expect(
        fixture.agenda.effectForRevision(revision)!.state,
        AgendaEffectState.unknown,
      );
    },
  );
}
