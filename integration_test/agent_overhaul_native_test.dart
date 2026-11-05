import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/agent_connection_settings_page.dart';
import 'package:sked/screens/agent_model_settings_page.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/agent_settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../test/support/agent_workspace_navigation.dart';
import '../test/support/memory_conversation_storage.dart';
import '../test/support/workspace_harness.dart';

// Windows native rendering and Win32 resize are real. Taps, text and Back are
// framework-injected. History, storage and credentials are synthetic; this
// entry does not call a model, replay tools or open personal application data.
const _sourceSha = String.fromEnvironment('SKED_SOURCE_SHA');
const _windowScriptPath = String.fromEnvironment(
  'SKED_AGENT_OVERHAUL_WINDOW_SCRIPT',
);
const _settings = AgentSettings(
  enabled: true,
  endpoint: 'https://native-overhaul.example.invalid/v1',
  model: 'm1',
  models: [
    AgentModelConfig(
      id: 'm1',
      reasoningEfforts: [AgentReasoningEffort.low, AgentReasoningEffort.high],
      defaultReasoningEffort: AgentReasoningEffort.low,
    ),
  ],
);
const _turnId = 'native-overhaul-turn';
const _runId = 'native-overhaul-run';
final _captureBoundary = GlobalKey();

typedef _Scene = ({
  String name,
  Brightness brightness,
  double scale,
  Size requestedSize,
});

const _scenes = <_Scene>[
  (
    name: 'light',
    brightness: Brightness.light,
    scale: 1,
    requestedSize: Size(1440, 900),
  ),
  (
    name: 'dark-2x',
    brightness: Brightness.dark,
    scale: 2,
    requestedSize: Size(1280, 820),
  ),
];

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready()) {
    if (elapsed.elapsed > const Duration(seconds: 20)) {
      fail('Timed out waiting for $description.');
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _until(tester, () => target.evaluate().isNotEmpty, '$target');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

Finder _header() {
  Element? row;
  _key('agent-conversation-menu').evaluate().single.visitAncestorElements((e) {
    if (e.widget is Row) {
      row = e;
      return false;
    }
    return true;
  });
  expect(row, isNotNull);
  return find.byElementPredicate((element) => identical(element, row));
}

class _RejectingTransport extends http.BaseClient {
  int attempts = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError('The Agent overhaul fixture must not use HTTP.');
  }
}

class _NoNetworkProvider extends ProviderClient {
  _NoNetworkProvider(this.transport) : super(client: transport);
  final _RejectingTransport transport;
  int requests = 0;
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests++;
    throw StateError('The Agent overhaul fixture must not request a model.');
  }
}

class _Captures {
  _Captures(this.directory, this.owned, this.temporaryRoot);
  final Directory directory;
  final bool owned;
  final String temporaryRoot;
  final report = <String, Object?>{
    'sourceSha': _sourceSha,
    'sourceShaOrigin': 'SKED_SOURCE_SHA dart define',
    'windowScript': _windowScriptPath,
    'platform': Platform.operatingSystem,
    'surfaceOverrides': false,
    'input': 'framework taps, registered test keyboard and framework Back',
    'fixture': 'memory main and side stores; seeded persistent tool history',
    'status': 'running',
    'scenes': <Map<String, Object?>>[],
    'captures': <Map<String, Object?>>[],
  };

  static Future<_Captures> open() async {
    const defined = String.fromEnvironment('SKED_AGENT_OVERHAUL_CAPTURE_DIR');
    final configured =
        (defined.isEmpty
                ? Platform.environment['SKED_AGENT_OVERHAUL_CAPTURE_DIR'] ?? ''
                : defined)
            .trim();
    final logicalRoot = path.normalize(Directory.systemTemp.absolute.path);
    final resolvedRoot = path.normalize(
      await Directory.systemTemp.resolveSymbolicLinks(),
    );
    if (configured.isEmpty) {
      final created = await Directory.systemTemp.createTemp(
        'sked-agent-overhaul-native-',
      );
      return _Captures(created, true, resolvedRoot);
    }
    if (!path.isAbsolute(configured) ||
        !path.isWithin(logicalRoot, path.normalize(configured))) {
      throw ArgumentError(
        'SKED_AGENT_OVERHAUL_CAPTURE_DIR must be an isolated absolute path '
        'inside the system temporary directory.',
      );
    }
    final target = Directory(path.normalize(configured));
    var ancestor = target;
    while (!await ancestor.exists()) {
      ancestor = Directory(path.dirname(ancestor.path));
    }
    final resolvedAncestor = path.normalize(
      await ancestor.resolveSymbolicLinks(),
    );
    if (!path.equals(resolvedRoot, resolvedAncestor) &&
        !path.isWithin(resolvedRoot, resolvedAncestor)) {
      throw ArgumentError(
        'The capture directory resolves outside system temp.',
      );
    }
    await target.create(recursive: true);
    final resolvedTarget = path.normalize(await target.resolveSymbolicLinks());
    if (!path.isWithin(resolvedRoot, resolvedTarget)) {
      throw ArgumentError(
        'The capture directory resolves outside system temp.',
      );
    }
    return _Captures(Directory(resolvedTarget), false, resolvedRoot);
  }

  Future<void> capture(WidgetTester tester, _Scene scene, String name) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        _captureBoundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await _until(
      tester,
      () => !boundary.debugNeedsPaint,
      'a painted native shell',
    );
    final context = tester.element(find.byType(Navigator).first);
    final view = View.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    expect(scale, closeTo(scene.scale, 0.001));
    expect(Localizations.localeOf(context).languageCode, 'zh');
    expect(Theme.of(context).brightness, scene.brightness);
    expect(
      boundary.size.width,
      closeTo(view.physicalSize.width / view.devicePixelRatio, 2),
    );
    expect(
      boundary.size.height,
      closeTo(view.physicalSize.height / view.devicePixelRatio, 2),
    );
    final image = await boundary.toImage(pixelRatio: view.devicePixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final file = File(path.join(directory.path, '${scene.name}-$name.png'));
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      final entry = <String, Object?>{
        'name': name,
        'file': file.absolute.path,
        'sourceSha': _sourceSha,
        'platform': Platform.operatingSystem,
        'logicalWidth': boundary.size.width,
        'logicalHeight': boundary.size.height,
        'physicalViewWidth': view.physicalSize.width,
        'physicalViewHeight': view.physicalSize.height,
        'pixelWidth': image.width,
        'pixelHeight': image.height,
        'devicePixelRatio': view.devicePixelRatio,
        'textScale': scale,
        'locale': Localizations.localeOf(context).toLanguageTag(),
        'brightness': scene.brightness.name,
        'surfaceOverrides': false,
      };
      (report['captures']! as List<Map<String, Object?>>).add(entry);
      debugPrint(jsonEncode(entry));
    } finally {
      image.dispose();
    }
  }

  Future<void> persist() =>
      File(path.join(directory.path, 'agent-overhaul-evidence.json'))
          .writeAsString(
            const JsonEncoder.withIndent('  ').convert(report),
            flush: true,
          )
          .then<void>((_) {});

  Future<void> captureFailure(WidgetTester tester, _Scene scene) async {
    report['failedScene'] = scene.name;
    final composer = _key('agent-composer');
    report['failureView'] = {
      'physicalSize': '${tester.view.physicalSize}',
      'devicePixelRatio': tester.view.devicePixelRatio,
      'agentHosts': find.byType(AgentPage).evaluate().length,
      'composers': composer.evaluate().length,
      'interactiveComposers': composer.hitTestable().evaluate().length,
      if (composer.evaluate().length == 1)
        'composerRect': '${tester.getRect(composer)}',
    };
    try {
      final boundary =
          _captureBoundary.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.debugNeedsPaint) return;
      final image = await boundary.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return;
        final file = File(
          path.join(directory.path, '${scene.name}-failure.png'),
        );
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        report['failureCapture'] = file.absolute.path;
      } finally {
        image.dispose();
      }
    } catch (error) {
      report['failureCaptureError'] = '${error.runtimeType}';
    }
  }

  Future<void> close() async {
    if (!owned) return;
    final resolved = path.normalize(await directory.resolveSymbolicLinks());
    if (!path.isWithin(temporaryRoot, resolved) ||
        !path.basename(resolved).startsWith('sked-agent-overhaul-native-')) {
      throw StateError('Refusing to delete an unowned capture directory.');
    }
    await Directory(resolved).delete(recursive: true);
  }
}

Future<Map<String, dynamic>> _resizeWindow(
  WidgetTester tester,
  _Scene scene,
) async {
  if (!path.isAbsolute(_windowScriptPath)) {
    throw ArgumentError(
      'Pass the absolute window script with SKED_AGENT_OVERHAUL_WINDOW_SCRIPT.',
    );
  }
  final script = File(_windowScriptPath);
  expect(await script.exists(), isTrue);
  final chrome = WorkbenchChromeMetrics(desktop: true, textScale: scene.scale);
  final result = await tester.runAsync(
    () => Process.run('powershell', [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
      '-ProcessId',
      '$pid',
      '-Action',
      'resize',
      '-WidthDp',
      '${scene.requestedSize.width}',
      '-HeightDp',
      '${scene.requestedSize.height}',
      '-CaptionHeightDp',
      '${chrome.toolbarHeight}',
      '-CaptionButtonWidthDp',
      '${chrome.captionButtonWidth}',
    ]),
  );
  expect(result, isNotNull);
  expect(result!.exitCode, 0, reason: '${result.stderr}');
  final geometry =
      jsonDecode('${result.stdout}'.trim()) as Map<String, dynamic>;
  await _until(tester, () {
    final logical = tester.view.physicalSize / tester.view.devicePixelRatio;
    return (logical.width - (geometry['clientWidthDp'] as num)).abs() < 2 &&
        (logical.height - (geometry['clientHeightDp'] as num)).abs() < 2;
  }, 'the real Win32 resize to reach Flutter');
  return geometry;
}

Future<String> _seedToolTurn(AppRuntime app) async {
  final conversation = await app.agent.conversations.create(
    title: '八项合成检查',
    mode: AgentPermissionMode.plan,
  );
  final start = DateTime.utc(2026, 11, 5, 9);
  final messages = [
    ConversationMessage(
      id: 'native-overhaul-input',
      role: ConversationRole.user,
      text: '查看这八项合成检查。',
      createdAt: start,
    ),
    ConversationMessage(
      id: 'native-overhaul-calls',
      role: ConversationRole.assistant,
      text: '',
      toolCalls: [
        for (var index = 0; index < 8; index++)
          ConversationToolCall(
            id: 'native-overhaul-tool-$index',
            name: 'events.list',
            arguments: jsonEncode({'limit': 20, 'page': index}),
          ),
      ],
      createdAt: start.add(const Duration(seconds: 1)),
    ),
    for (var index = 0; index < 8; index++)
      ConversationMessage(
        id: 'native-overhaul-result-$index',
        role: ConversationRole.tool,
        toolCallId: 'native-overhaul-tool-$index',
        text: jsonEncode({
          'items': [
            for (var row = 0; row < 48; row++)
              {
                'title': '合成条目 $index / $row',
                'description': '用于核对完整工具输出的本地合成内容。',
              },
          ],
          'complete': true,
        }),
        createdAt: start.add(Duration(seconds: index + 2)),
      ),
    ConversationMessage(
      id: 'native-overhaul-reply',
      role: ConversationRole.assistant,
      text: '八项检查已完成，需要时可查看详情。',
      createdAt: start.add(const Duration(seconds: 10)),
    ),
  ];
  await app.agent.conversations.update(
    conversation.id,
    (current) => current.copyWith(
      runId: _runId,
      messages: messages,
      turns: [
        ConversationTurn(
          id: _turnId,
          requestMessageId: messages.first.id,
          ownershipComplete: false,
          messageIds: messages.map((message) => message.id),
          runIds: const [_runId],
        ),
      ],
      runs: [
        ConversationRunUsage(
          id: _runId,
          startedAt: start,
          settledAt: start.add(const Duration(seconds: 10)),
          kind: ConversationRunKind.model,
          status: ConversationRunStatus.completed,
          protocol: _settings.protocol.name,
          model: 'm1',
          reasoningEffort: AgentReasoningEffort.low,
          tools: [
            for (var index = 0; index < 8; index++)
              ConversationToolUsage(
                id: 'native-overhaul-tool-$index',
                name: 'events.list',
                outcome: ConversationAttemptOutcome.completed,
              ),
          ],
        ),
      ],
    ),
  );
  return conversation.id;
}

Future<void> _settingsJourney(
  WidgetTester tester,
  AppRuntime app,
  _Captures captures,
  _Scene scene,
) async {
  await _tap(tester, _key('agent-conversation-menu'));
  await _tap(tester, _key('agent-settings'));
  await _until(
    tester,
    () => find.byType(AgentSettingsPage).hitTestable().evaluate().isNotEmpty,
    'the Agent settings overview',
  );
  expect(find.byType(TabBar), findsNothing);
  expect(find.byType(TabBarView), findsNothing);
  await captures.capture(tester, scene, 'settings-overview');
  await _tap(tester, _key('agent-settings-connection'));
  final parent = tester.state(find.byType(AgentConnectionSettingsPage));
  const endpoint = 'https://unsaved-native.example.invalid/v1';
  const keyDraft = 'synthetic-unsaved-native-key';
  await tester.enterText(_key('agent-endpoint'), endpoint);
  await tester.enterText(_key('agent-api-key'), keyDraft);
  await _tap(tester, _key('agent-configured-model-m1'));
  expect(find.byType(AgentModelSettingsPage), findsOneWidget);
  expect(find.byType(TabBar), findsNothing);
  await _tap(tester, _key('agent-model-effort-high'));
  expect(
    tester.widget<CheckboxListTile>(_key('agent-model-effort-high')).value,
    isFalse,
  );
  await _back(tester);
  final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
  expect(find.text(l.unsavedChangesMessage), findsOneWidget);
  await captures.capture(tester, scene, 'model-unsaved-confirmation');
  await _tap(tester, find.widgetWithText(TextButton, l.cancel));
  expect(find.byType(AgentModelSettingsPage), findsOneWidget);
  await _tap(tester, _key('agent-save-model'));
  await app.agent.quiesce();
  await _until(
    tester,
    () => find.byType(AgentModelSettingsPage).evaluate().isEmpty,
    'the saved model to complete only its own route',
  );
  expect(tester.state(find.byType(AgentConnectionSettingsPage)), same(parent));
  expect(
    tester.widget<TextFormField>(_key('agent-endpoint')).controller!.text,
    endpoint,
  );
  expect(
    tester.widget<TextFormField>(_key('agent-api-key')).controller!.text,
    keyDraft,
  );
  expect(app.agent.settings.endpoint, _settings.endpoint);
  expect(app.agent.settings.credentialRef, isNull);
  expect(app.agent.settings.modelConfig('m1')!.reasoningEfforts, [
    AgentReasoningEffort.low,
  ]);
  await _tap(tester, _key('agent-endpoint'));
  await captures.capture(tester, scene, 'connection-draft-preserved');
  await _back(tester);
  expect(find.text(l.unsavedChangesMessage), findsOneWidget);
  await _tap(tester, find.widgetWithText(TextButton, l.cancel));
  expect(find.byType(AgentConnectionSettingsPage), findsOneWidget);
  await _back(tester);
  await _tap(
    tester,
    find.widgetWithText(FilledButton, l.discardChangesAndExit),
  );
  expect(find.byType(AgentConnectionSettingsPage), findsNothing);
  expect(_key('agent-settings-connection').hitTestable(), findsOneWidget);
  expect(app.agent.settings.endpoint, _settings.endpoint);
  expect(await app.agent.connections.readKeyFor(app.agent.settings), isEmpty);
  await _back(tester);
  await _until(
    tester,
    () => _key('agent-composer').hitTestable().evaluate().isNotEmpty,
    'the same embedded chat after settings Back',
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.shouldPropagateDevicePointerEvents = true;
  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });
  testWidgets(
    'Windows Agent overhaul keeps empty chats, grouped activity and hierarchical settings in the main shell',
    (tester) async {
      if (!Platform.isWindows ||
          Platform.resolvedExecutable.toLowerCase().contains(
            'flutter_tester',
          )) {
        throw StateError(
          'This entry requires the real Windows Flutter runner.',
        );
      }
      if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(_sourceSha)) {
        throw ArgumentError(
          'Pass the full source commit with SKED_SOURCE_SHA.',
        );
      }
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Sked',
        packageName: 'com.mashiro.sked.agent_overhaul_native',
        version: '3.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: '',
      );
      await DesktopWindowBridge.instance.initialize();
      expect(DesktopWindowBridge.instance.available, isTrue);
      final captures = await _Captures.open();
      binding.reportData = {'agentOverhaul': captures.report};
      binding.testTextInput.register();
      try {
        for (final scene in _scenes) {
          final transport = _RejectingTransport();
          final provider = _NoNetworkProvider(transport);
          final storage = MemoryConversationStorage();
          AppRuntime? app;
          try {
            final geometry = await _resizeWindow(tester, scene);
            app = await workspaceProvider(
              locale: 'zh',
              agentConversationStorage: storage,
              agentProvider: provider,
            );
            await app.agent.configure(_settings);
            await app.agent.initialize();
            await tester.pumpWidget(
              RepaintBoundary(
                key: _captureBoundary,
                child: WorkspaceHarness(
                  provider: app,
                  locale: const Locale('zh'),
                  brightness: scene.brightness,
                  textScale: scene.scale,
                ),
              ),
            );
            DesktopWindowBridge.instance.prepareClose =
                app.shutdown.prepareForWindowClose;
            await selectAgentShellDestination(tester, 'agent');
            await _until(
              tester,
              () => _key('agent-composer').hitTestable().evaluate().isNotEmpty,
              'the unsent embedded composer',
            );
            expect(find.byType(AdaptiveSkedShell), findsOneWidget);
            expect(
              tester.widget<AgentPage>(find.byType(AgentPage)).embedded,
              true,
            );
            expect(
              tester
                  .widget<WorkspaceFrame>(_key('agent-workspace-frame'))
                  .active,
              true,
            );
            final l = AppLocalizations.of(
              tester.element(_key('agent-conversation-menu')),
            );
            expect(
              find.descendant(of: _header(), matching: find.text(l.agentTitle)),
              findsOneWidget,
            );
            expect(app.agent.conversations.conversations, isEmpty);
            final source = storage.source;
            await tester.enterText(_key('agent-composer'), '尚未发送的草稿。');
            await tester.pumpAndSettle();
            expect(
              tester.widget<TextField>(_key('agent-composer')).enabled,
              isNot(false),
            );
            expect(storage.source, source);
            expect(app.agent.conversations.conversations, isEmpty);
            expect(
              find.descendant(of: _header(), matching: find.text(l.agentTitle)),
              findsOneWidget,
            );
            await captures.capture(tester, scene, 'unsent-main-shell');
            await openAgentShellHistory(tester);
            expect(_key('agent-history-new'), findsOneWidget);
            expect(_key('agent-history-new').hitTestable(), findsOneWidget);
            await captures.capture(tester, scene, 'unsent-resources');
            final resources = WorkspaceResourceScope.maybeOf(
              tester.element(_key('agent-composer')),
            );
            if (resources?.drawerOpen == true) await _back(tester);
            final id = await _seedToolTurn(app);
            final durable = ConversationArchive.decode(storage.source!)
                .conversations
                .single;
            expect(durable.turns.single.messageIds, hasLength(11));
            expect(durable.runs.single.tools, hasLength(8));
            await openAgentShellHistory(tester);
            await _tap(tester, _key('agent-history-$id'));
            await _until(
              tester,
              () =>
                  _key('agent-activity-toggle-$_turnId').evaluate().isNotEmpty,
              'one activity entry for the saved eight-tool turn',
            );
            expect(find.byType(AgentTurnActivity), findsOneWidget);
            final toggle = _key('agent-activity-toggle-$_turnId');
            expect(_key('agent-activity-list-$_turnId'), findsNothing);
            await captures.capture(tester, scene, 'activity-collapsed');
            await _tap(tester, toggle);
            final list = _key('agent-activity-list-$_turnId');
            expect(tester.getSize(list).height, lessThanOrEqualTo(280));
            final scroll = find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first;
            final listPosition = tester.state<ScrollableState>(scroll).position;
            if (listPosition.maxScrollExtent > 0) {
              await tester.drag(list, const Offset(0, -180));
              await tester.pumpAndSettle();
              expect(listPosition.pixels, greaterThan(0));
            }
            final listExtent = listPosition.maxScrollExtent;
            await captures.capture(tester, scene, 'activity-list');
            await tester.scrollUntilVisible(
              _key('agent-activity-tool-native-overhaul-tool-7'),
              100,
              scrollable: scroll,
              maxScrolls: 20,
            );
            await _tap(
              tester,
              _key('agent-activity-tool-native-overhaul-tool-7'),
            );
            final detail = _key('agent-activity-detail-native-overhaul-tool-7');
            expect(tester.getSize(detail).height, lessThanOrEqualTo(320));
            final detailScroll = find
                .descendant(of: detail, matching: find.byType(Scrollable))
                .first;
            final detailPosition = tester
                .state<ScrollableState>(detailScroll)
                .position;
            expect(detailPosition.maxScrollExtent, greaterThan(0));
            await tester.ensureVisible(detail);
            await tester.drag(detail, const Offset(0, -220));
            await tester.pumpAndSettle();
            expect(detailPosition.pixels, greaterThan(0));
            final detailExtent = detailPosition.maxScrollExtent;
            await captures.capture(tester, scene, 'activity-detail-scrolled');
            await _tap(tester, _key('agent-activity-back'));
            expect(list, findsOneWidget);
            expect(detail, findsNothing);
            await _tap(tester, toggle);
            expect(list, findsNothing);
            await _settingsJourney(tester, app, captures, scene);
            expect(provider.requests, 0);
            expect(transport.attempts, 0);
            expect(
              ConversationArchive.decode(storage.source!).conversations,
              hasLength(1),
            );
            (captures.report['scenes']! as List<Map<String, Object?>>).add({
              'name': scene.name,
              'requestedWidth': scene.requestedSize.width,
              'requestedHeight': scene.requestedSize.height,
              'nativeWindow': geometry,
              'textScale': scene.scale,
              'brightness': scene.brightness.name,
              'savedConversationCount': 1,
              'groupedToolCount': 8,
              'activityListMaxScrollExtent': listExtent,
              'activityDetailMaxScrollExtent': detailExtent,
              'providerRequests': provider.requests,
              'httpAttempts': transport.attempts,
              'status': 'passed',
            });
            expect(tester.takeException(), isNull);
          } catch (_) {
            await captures.captureFailure(tester, scene);
            rethrow;
          } finally {
            try {
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              DesktopWindowBridge.instance.prepareClose = null;
              try {
                if (app != null) {
                  try {
                    await app.shutdown.quiesce();
                  } finally {
                    app.dispose();
                    await app.session.close();
                  }
                }
              } finally {
                provider.close();
              }
            }
          }
        }
        captures.report['status'] = 'passed';
      } catch (_) {
        captures.report['status'] = 'failed';
        rethrow;
      } finally {
        binding.testTextInput.unregister();
        try {
          await captures.persist();
          debugPrint(
            jsonEncode({
              'agentOverhaulEvidence': captures.directory.absolute.path,
              'retained': !captures.owned,
              'status': captures.report['status'],
              'sourceSha': _sourceSha,
            }),
          );
        } finally {
          await captures.close();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    semanticsEnabled: false,
  );
}
