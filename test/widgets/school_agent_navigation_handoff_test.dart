import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/imports/school_web_handoff.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/settings_commands.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/controllers/workspace_commands.dart';
import 'package:sked/controllers/workspace_view_state.dart';
import 'package:sked/models/app_mode.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/timetable_import_flow.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/widgets/sked_task_route.dart';

import '../support/notification_test_scope.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  required String reason,
  String Function()? diagnostics,
}) async {
  for (var attempt = 0; attempt < 180 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final complete = ready();
  expect(
    complete,
    isTrue,
    reason: !complete && diagnostics != null
        ? '$reason\n${diagnostics()}'
        : reason,
  );
}

class _SchoolNavigationFixture {
  _SchoolNavigationFixture({
    required this.app,
    required this.initialConversationId,
    required this.targetConversationId,
    required bool allowSettingsExit,
  }) : settingsCanPop = ValueNotifier(allowSettingsExit);

  final AppRuntime app;
  final String initialConversationId;
  final String targetConversationId;
  final ValueNotifier<bool> settingsCanPop;

  late BuildContext shellContext;
  late NavigatorState rootNavigator;
  late ModalRoute<dynamic> rootRoute;
  BuildContext? sitesContext;
  ModalRoute<dynamic>? settingsRoute;
  ModalRoute<dynamic>? sourceRoute;
  ModalRoute<dynamic>? sitesRoute;

  SchoolWebHandoffRouteResult get successResult =>
      SchoolWebHandoffRouteResult(conversationId: targetConversationId);

  String describeNavigation() {
    String routeState(String name, ModalRoute<dynamic>? route) =>
        '$name: active=${route?.isActive}, current=${route?.isCurrent}, '
        'disposition=${route?.popDisposition}, '
        'navigatorCanPop=${route?.navigator?.canPop()}';
    return [
      routeState('root', rootRoute),
      routeState('settings', settingsRoute),
      routeState('source', sourceRoute),
      routeState('sites', sitesRoute),
      'Agent: enabled=${app.agent.settings.enabled}, '
          'initialized=${app.agent.isInitialized}, '
          'navigationRevision=${app.agent.navigationRevision}, '
          'targetSelected=${app.agent.conversations.selectedId == targetConversationId}, '
          'mounted=${find.byType(AgentPage, skipOffstage: false).evaluate().length}, '
          'composerInteractive=${_key('agent-composer').hitTestable().evaluate().isNotEmpty}',
    ].join('\n');
  }

  Widget buildShell(BuildContext context) {
    shellContext = context;
    rootNavigator = Navigator.of(context);
    rootRoute = ModalRoute.of(context)!;
    return Consumer2<WorkspaceViewState, SettingsViewState>(
      builder: (_, workspace, settings, _) => AdaptiveSkedShell(
        workspace: workspace,
        workspaces: context.read<WorkspaceCommands>(),
        settings: settings,
        settingsCommands: context.read<SettingsCommands>(),
        activeMode: workspace.activeMode,
        onOpenSettings: _openSettings,
      ),
    );
  }

  Future<void> _openSettings() => rootNavigator.push<void>(
    MaterialPageRoute<void>(
      builder: (context) {
        settingsRoute = ModalRoute.of(context);
        return ValueListenableBuilder<bool>(
          valueListenable: settingsCanPop,
          builder: (_, canPop, child) =>
              PopScope<void>(canPop: canPop, child: child!),
          child: SettingsPage(
            key: const ValueKey('school-handoff-settings-owner'),
            packageInfoLoader: () async => PackageInfo(
              appName: 'Sked',
              packageName: 'com.mashiro.sked.handoff-test',
              version: '3.0.0',
              buildNumber: '1',
            ),
            updateDistribution: const UpdateDistribution(UpdateChannel.github),
            schoolSitesPageBuilder: _buildSites,
          ),
        );
      },
    ),
  );

  // Persistence failures belong to the handoff service and source-page suites.
  // This substitute returns only the typed result of a completed school flow.
  Widget _buildSites(BuildContext context) => Builder(
    builder: (context) {
      sitesContext = context;
      sitesRoute = ModalRoute.of(context);
      return Scaffold(
        key: const ValueKey('school-handoff-sites'),
        appBar: AppBar(title: const Text('School source fixture')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                key: const ValueKey('school-handoff-complete'),
                onPressed: () => completeSkedTaskRoute(context, successResult),
                child: const Text('Complete school handoff'),
              ),
              TextButton(
                key: const ValueKey('school-handoff-cancel'),
                onPressed: () =>
                    completeSkedTaskRoute<SchoolWebHandoffRouteResult>(context),
                child: const Text('Cancel school handoff'),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<SchoolWebHandoffRouteResult?> openFromRoot() {
    if (!shellContext.mounted) {
      throw StateError('The school flow requires its mounted root shell.');
    }
    return TimetableImportFlow.openSchoolSitesPage(
      shellContext,
      schoolSitesPageBuilder: _buildSites,
    );
  }

  void coverWithEditor() {
    unawaited(
      rootNavigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: ValueKey('school-handoff-new-editor'),
            body: Center(child: Text('New editor owns navigation')),
          ),
        ),
      ),
    );
  }

  void completeBeforeNewEditor() {
    final context = sitesContext!;
    if (!context.mounted) {
      throw StateError('The school result requires its mounted source.');
    }
    // A new user destination arrives before the completed flow's continuation.
    completeSkedTaskRoute(context, successResult);
    coverWithEditor();
  }
}

class _FlowResult {
  _FlowResult(Future<SchoolWebHandoffRouteResult?> operation) {
    unawaited(
      operation.then((value) {
        result = value;
        completed = true;
      }),
    );
  }

  bool completed = false;
  SchoolWebHandoffRouteResult? result;
}

Future<_SchoolNavigationFixture> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 850),
  bool allowSettingsExit = true,
}) async {
  final app = await workspaceProvider();
  addTearDown(app.dispose);
  await app.agent.initialize();
  final initial = await app.agent.conversations.create(
    title: 'Existing conversation',
  );
  final target = await app.agent.conversations.create(title: 'School handoff');
  await app.agent.conversations.select(initial.id);
  final fixture = _SchoolNavigationFixture(
    app: app,
    initialConversationId: initial.id,
    targetConversationId: target.id,
    allowSettingsExit: allowSettingsExit,
  );
  addTearDown(fixture.settingsCanPop.dispose);
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: app,
      home: Builder(builder: fixture.buildShell),
    ),
  );
  await tester.pumpAndSettle();
  expect(fixture.rootRoute.isCurrent, isTrue);
  expect(fixture.rootNavigator.canPop(), isFalse);
  expect(find.byType(AgentPage), findsNothing);
  return fixture;
}

Finder _visibleSettingsEntry() {
  for (final name in [
    'workspace-resource-settings',
    'adaptive-shell-settings-action',
    'student-settings-button',
  ]) {
    final entry = _key(name).hitTestable();
    if (entry.evaluate().isNotEmpty) return entry.first;
  }
  return _key('school-handoff-missing-settings-entry');
}

Future<void> _tap(
  WidgetTester tester,
  String name, {
  Finder? scrollable,
}) async {
  final target = _key(name);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: scrollable ?? find.byType(Scrollable).hitTestable().last,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openSettingsSchoolFlow(
  WidgetTester tester,
  _SchoolNavigationFixture fixture,
) async {
  // Enter through the real button so the shell's settings gate participates.
  if (_visibleSettingsEntry().evaluate().isEmpty) {
    final menu = _key('workspace-main-navigation').hitTestable();
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await _until(
      tester,
      () => _visibleSettingsEntry().evaluate().isNotEmpty,
      reason: 'The main navigation must expose its settings action.',
    );
  }
  await tester.ensureVisible(_visibleSettingsEntry());
  await tester.tap(_visibleSettingsEntry());
  await tester.pumpAndSettle();
  expect(_key('school-handoff-settings-owner'), findsOneWidget);
  final overviewScroll = find.descendant(
    of: find.byKey(const PageStorageKey('settings-overview-scroll')),
    matching: find.byType(Scrollable),
  );
  await _tap(
    tester,
    'settings-student-transfer',
    scrollable: overviewScroll.first,
  );
  fixture.sourceRoute = ModalRoute.of(
    tester.element(_key('transfer-school-web')),
  );
  expect(fixture.sourceRoute!.isCurrent, isTrue);
  await _tap(tester, 'transfer-school-web');
  expect(_key('school-handoff-sites'), findsOneWidget);
}

void _expectNoAgent(_SchoolNavigationFixture fixture) {
  expect(find.byType(AgentPage), findsNothing);
  expect(_key('agent-composer').hitTestable(), findsNothing);
  expect(
    fixture.app.agent.conversations.selectedId,
    fixture.initialConversationId,
  );
}

void _expectRootAgent(WidgetTester tester, _SchoolNavigationFixture fixture) {
  expect(fixture.rootRoute.isCurrent, isTrue);
  expect(fixture.rootNavigator.canPop(), isFalse);
  expect(fixture.app.workspaceView.activeMode, AppMode.student);
  expect(
    fixture.app.agent.conversations.selectedId,
    fixture.targetConversationId,
  );
  expect(find.byType(AgentPage), findsOneWidget);
  expect(tester.widget<AgentPage>(find.byType(AgentPage)).embedded, isTrue);
  expect(_key('agent-composer').hitTestable(), findsOneWidget);
}

void main() {
  setUpNotificationTestPlatform();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  for (final size in [const Size(390, 850), const Size(1200, 800)]) {
    final width = size.width.toInt();
    testWidgets(
      'settings school success retires its owning routes and activates the root Agent at $width dp',
      (tester) async {
        final fixture = await _mount(tester, size: size);
        final before = fixture.app.workspaceView.data.toJson();
        await _openSettingsSchoolFlow(tester, fixture);
        await _tap(tester, 'school-handoff-complete');
        await _until(
          tester,
          () =>
              fixture.sitesRoute?.isActive == false &&
              fixture.sourceRoute?.isActive == false &&
              fixture.settingsRoute?.isActive == false,
          reason: 'School success must retire each route owned by its settings flow.',
          diagnostics: fixture.describeNavigation,
        );
        await _until(
          tester,
          () => _key('agent-composer').hitTestable().evaluate().isNotEmpty,
          reason: 'School success must release the settings gate and activate Agent.',
          diagnostics: fixture.describeNavigation,
        );
        expect(fixture.sitesRoute!.isActive, isFalse);
        expect(fixture.sourceRoute!.isActive, isFalse);
        expect(fixture.settingsRoute!.isActive, isFalse);
        expect(_key('school-handoff-settings-owner'), findsNothing);
        _expectRootAgent(tester, fixture);
        expect(fixture.app.workspaceView.data.toJson(), before);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'settings school cancel keeps its source destination and conversation at $width dp',
      (tester) async {
        final fixture = await _mount(tester, size: size);
        await _openSettingsSchoolFlow(tester, fixture);
        await _tap(tester, 'school-handoff-cancel');
        expect(fixture.sitesRoute!.isActive, isFalse);
        expect(fixture.sourceRoute!.isCurrent, isTrue);
        expect(fixture.settingsRoute!.isCurrent, isTrue);
        expect(_key('transfer-school-web').hitTestable(), findsOneWidget);
        _expectNoAgent(fixture);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'settings school success respects the outer exit guard at $width dp',
      (tester) async {
        final fixture = await _mount(
          tester,
          size: size,
          allowSettingsExit: false,
        );
        await _openSettingsSchoolFlow(tester, fixture);
        await _tap(tester, 'school-handoff-complete');
        expect(fixture.sitesRoute!.isActive, isFalse);
        expect(fixture.sourceRoute!.isActive, isFalse);
        expect(fixture.settingsRoute!.isCurrent, isTrue);
        expect(_key('school-handoff-settings-owner'), findsOneWidget);
        _expectNoAgent(fixture);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'a settings school result cannot retire a newer editor or activate Agent',
    (tester) async {
      final fixture = await _mount(tester);
      await _openSettingsSchoolFlow(tester, fixture);
      fixture.completeBeforeNewEditor();
      await tester.pumpAndSettle();
      expect(fixture.sitesRoute!.isActive, isFalse);
      expect(fixture.sourceRoute!.isActive, isTrue);
      expect(fixture.settingsRoute!.isActive, isTrue);
      expect(fixture.settingsRoute!.isCurrent, isFalse);
      expect(_key('school-handoff-new-editor').hitTestable(), findsOneWidget);
      _expectNoAgent(fixture);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'root school flow returns the selected conversation only after embedded activation',
    (tester) async {
      final fixture = await _mount(tester);
      final operation = _FlowResult(fixture.openFromRoot());
      await tester.pumpAndSettle();
      await _tap(tester, 'school-handoff-complete');
      await _until(
        tester,
        () => operation.completed,
        reason: 'The school flow must acknowledge the root Agent activation.',
      );
      expect(operation.result?.conversationId, fixture.targetConversationId);
      expect(fixture.sitesRoute!.isActive, isFalse);
      _expectRootAgent(tester, fixture);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('root school cancel returns no result and keeps the workspace', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    final operation = _FlowResult(fixture.openFromRoot());
    await tester.pumpAndSettle();
    await _tap(tester, 'school-handoff-cancel');
    expect(operation.completed, isTrue);
    expect(operation.result, isNull);
    expect(fixture.rootRoute.isCurrent, isTrue);
    expect(fixture.rootNavigator.canPop(), isFalse);
    _expectNoAgent(fixture);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'root school result is discarded after its data session expires',
    (tester) async {
      final fixture = await _mount(tester);
      final operation = _FlowResult(fixture.openFromRoot());
      await tester.pumpAndSettle();
      final reservation = fixture.app.maintenance.reserve();
      fixture.app.maintenance.release(reservation);
      await _tap(tester, 'school-handoff-complete');
      expect(operation.completed, isTrue);
      expect(operation.result, isNull);
      expect(fixture.rootRoute.isCurrent, isTrue);
      _expectNoAgent(fixture);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'root school result is discarded when another route covers its caller',
    (tester) async {
      final fixture = await _mount(tester);
      final operation = _FlowResult(fixture.openFromRoot());
      await tester.pumpAndSettle();
      fixture.completeBeforeNewEditor();
      await tester.pumpAndSettle();
      expect(operation.completed, isTrue);
      expect(operation.result, isNull);
      expect(fixture.sitesRoute!.isActive, isFalse);
      expect(_key('school-handoff-new-editor').hitTestable(), findsOneWidget);
      _expectNoAgent(fixture);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
