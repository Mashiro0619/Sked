import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';

import 'platform_tool_test_support.dart';

class _Android extends AndroidProductivityBridge {
  _Android() : super(enabled: true);
  var batteryRequests = 0, autostartRequests = 0;
  @override
  Future<AndroidNotificationDiagnostics> notificationDiagnostics() async =>
      const AndroidNotificationDiagnostics(
        isSupported: true,
        appNotificationsEnabled: true,
        postNotificationsGranted: true,
        exactAlarmsAllowed: true,
        batteryOptimizationIgnored: false,
        channels: [],
      );
  @override
  Future<AndroidAutostartSupport> getAutostartSupport() async =>
      const AndroidAutostartSupport(
        vendorId: 'test',
        vendorEntryAvailable: true,
        fallbackAvailable: true,
      );
  @override
  Future<bool> openBatteryOptimizationSettings() async {
    batteryRequests++;
    return false;
  }

  @override
  Future<AndroidAutostartOpenResult> openAutostartSettings() async {
    autostartRequests++;
    return const AndroidAutostartOpenResult(
      vendorId: 'test',
      opened: true,
      target: AndroidAutostartSettingsTarget.vendor,
    );
  }
}

class _Window extends DesktopWindowBridge {
  _Window() {
    available = true;
  }
  final calls = <String>[];
  @override
  Future<void> command(String name) async {
    calls.add(name);
    if (name == 'toggleMaximize') maximized = !maximized;
  }
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlatformToolHarness h;
  setUp(() async {
    h = PlatformToolHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  test('layout preparation is pure and a committed patch preserves other dimensions', () async {
    final layout = DesktopLayoutPreferences.memory(
      initialValues: {
        DesktopLayoutRegion.assistant: const PreferredRegionSize(
          width: 360,
          height: 600,
          dockedWidth: 420,
        ),
      },
    );
    addTearDown(layout.dispose);
    h.platform.bindServices(layout: layout);
    final plan = await h.call('device.layout.prepare', {
      'region': 'assistant',
      'action': 'set',
      'values': {'width': 480, 'height': null},
    });
    expect(h.storage.saveCount, 0);
    expect(layout.preferenceFor(DesktopLayoutRegion.assistant)!.width, 360);
    final result = await h.externalCommit(plan);
    expect(result['effectStatus'], 'applied');
    expect(
      layout.preferenceFor(DesktopLayoutRegion.assistant),
      const PreferredRegionSize(width: 480, dockedWidth: 420),
    );
    expect(layout.hasUnsavedChanges, isFalse);
    final replayPlan = await h.call('device.layout.prepare', {
      'region': 'assistant',
      'action': 'set',
      'values': {'width': 480, 'height': null},
      'operationId': plan['operationId'],
    });
    final replay = await h.externalCommit(replayPlan);
    expect(replay['replayed'], isTrue);
    expect(h.storage.saveCount, 2);
    await expectLater(
      h.call('device.layout.prepare', {
        'region': 'assistant',
        'action': 'set',
        'values': {'width': 600},
        'operationId': plan['operationId'],
      }),
      throwsA(_problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test(
    'ordinary reset removes all role preferences without freezing later writes',
    () async {
      final layout = DesktopLayoutPreferences.memory(
        initialValues: {
          DesktopLayoutRegion.assistant: const PreferredRegionSize(width: 500),
          DesktopLayoutRegion.resources: const PreferredRegionSize(
            dockedWidth: 240,
          ),
        },
      );
      addTearDown(layout.dispose);
      h.platform.bindServices(layout: layout);
      final reset = await h.call('device.layout.prepare', {
        'region': 'all',
        'action': 'reset',
      });
      await h.externalCommit(reset);
      for (final region in DesktopLayoutRegion.values) {
        expect(layout.preferenceFor(region), isNull);
      }
      final next = await h.call('device.layout.prepare', {
        'region': 'resources',
        'action': 'set',
        'values': {'width': 280},
      });
      expect((await h.externalCommit(next))['effectStatus'], 'applied');
      expect(layout.preferenceFor(DesktopLayoutRegion.resources)!.width, 280);
    },
  );

  test(
    'planning and declined ask modes never save device preferences',
    () async {
      final layout = DesktopLayoutPreferences.memory();
      addTearDown(layout.dispose);
      h.platform.bindServices(layout: layout);
      final plan = await h.call('device.layout.prepare', {
        'region': 'assistant',
        'action': 'set',
        'values': {'width': 400},
      });
      h.scope.policy.update(mode: AgentPermissionMode.plan);
      await expectLater(
        h.externalCommit(plan),
        throwsA(_problem(OperationErrorCode.readOnly)),
      );
      h.scope.policy.update(mode: AgentPermissionMode.ask);
      await expectLater(
        h.externalCommit(plan),
        throwsA(_problem(OperationErrorCode.cancelled)),
      );
      expect(layout.preferenceFor(DesktopLayoutRegion.assistant), isNull);
      expect(h.storage.saveCount, 0);
    },
  );

  test(
    'an intervening manual resize or service rebinding invalidates the plan',
    () async {
      final layout = DesktopLayoutPreferences.memory();
      addTearDown(layout.dispose);
      h.platform.bindServices(layout: layout);
      final plan = await h.call('device.layout.prepare', {
        'region': 'assistant',
        'action': 'set',
        'values': {'width': 400},
      });
      layout.setPreferredSize(
        DesktopLayoutRegion.assistant,
        const PreferredRegionSize(width: 500),
      );
      await layout.flush();
      await expectLater(
        h.externalCommit(plan),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      final second = await h.call('device.layout.prepare', {
        'region': 'assistant',
        'action': 'set',
        'values': {'width': 600},
      });
      h.platform.bindServices();
      await expectLater(
        h.externalCommit(second),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(layout.preferenceFor(DesktopLayoutRegion.assistant)!.width, 500);
    },
  );

  test('failed geometry persistence is not reported as applied', () async {
    final layout = DesktopLayoutPreferences(
      read: () async => null,
      write: (_) async => false,
      remove: () async => true,
    );
    addTearDown(layout.dispose);
    h.platform.bindServices(layout: layout);
    final plan = await h.call('device.layout.prepare', {
      'region': 'assistant',
      'action': 'set',
      'values': {'width': 400},
    });
    final result = await h.externalCommit(plan);
    expect(result['effectStatus'], 'unknown');
    expect(result['recoveryRequired'], isTrue);
    expect(layout.hasUnsavedChanges, isTrue);
  });

  test('legacy developer preview preference does not enable Agent', () async {
    final preferences = DeveloperUiPreferences.memory();
    addTearDown(preferences.dispose);
    h.platform.bindServices(developerUi: preferences);
    final plan = await h.call('device.preferences.prepare', {
      'action': 'set',
      'value': true,
    });
    expect((await h.externalCommit(plan))['effectStatus'], 'applied');
    expect(preferences.assistantVisible, isTrue);
    expect(h.session.committedData.agentSettings.enabled, isFalse);
  });

  test('OEM settings can open while grant stays unknown and battery requests are not grants', () async {
    final android = _Android();
    addTearDown(android.dispose);
    h.platform.bindServices(android: android);
    final battery = await h.call('platform.request_action', {
      'action': 'batteryOptimization',
    });
    expect(android.batteryRequests, 0);
    final result = await h.externalCommit(battery);
    expect(result['effectStatus'], 'unknown');
    expect(android.batteryRequests, 1);
    final auto = await h.call('platform.request_action', {
      'action': 'autostart',
    });
    final opened = await h.externalCommit(auto);
    expect(opened['effectStatus'], 'applied');
    expect((opened['effectResult'] as Map)['grant'], 'unknown');
    expect(android.autostartRequests, 1);
  });

  test(
    'window actions use a fixed command vocabulary and guarded close host',
    () async {
      final window = _Window();
      var closeCalls = 0;
      h.platform.bindServices(
        desktopWindow: window,
        closeWindow: (scope) async {
          expect(scope, same(h.scope));
          closeCalls++;
          return ExternalEffectResult(
            state: ExternalEffectState.unknown,
            details: {'closeRequestCompleted': true},
          );
        },
      );
      final maximize = await h.call('window.prepare', {'action': 'maximize'});
      expect(window.calls, isEmpty);
      await h.externalCommit(maximize);
      expect(window.calls, ['toggleMaximize']);
      final retry = await h.call('window.prepare', {
        'action': 'maximize',
        'operationId': maximize['operationId'],
      });
      expect((await h.externalCommit(retry))['replayed'], isTrue);
      expect(window.calls, ['toggleMaximize']);
      final close = await h.call('window.prepare', {'action': 'close'});
      expect((await h.externalCommit(close))['effectStatus'], 'unknown');
      expect(closeCalls, 1);
      await expectLater(
        h.call('window.prepare', {'action': 'confirmClose'}),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test('unbound platform and device services report unsupported', () async {
    expect((await h.call('window.status'))['supported'], isFalse);
    expect((await h.call('platform.status'))['supported'], isFalse);
    await expectLater(
      h.call('device.layout.prepare', {'region': 'all', 'action': 'reset'}),
      throwsA(_problem(OperationErrorCode.unsupported)),
    );
  });
}
