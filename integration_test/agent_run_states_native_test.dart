import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/agent_settings.dart';

import '../test/support/agent_workspace_navigation.dart';
import '../test/support/workspace_harness.dart';
import 'support/agent_overhaul_states.dart';

const _sourceSha = String.fromEnvironment('SKED_SOURCE_SHA');
const _output = String.fromEnvironment('SKED_AGENT_STATES_CAPTURE_DIR');
const _accessible = bool.fromEnvironment('SKED_AGENT_STATES_ACCESSIBLE');
const _dark = bool.fromEnvironment(
  'SKED_AGENT_STATES_DARK',
  defaultValue: _accessible,
);
const _rtl = bool.fromEnvironment('SKED_AGENT_STATES_RTL');
const _keyboard = bool.fromEnvironment('SKED_AGENT_STATES_KEYBOARD');
final _boundaryKey = GlobalKey();

class _NoHttp extends http.BaseClient {
  var attempts = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError('Native state fixtures must not send HTTP.');
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });
  testWidgets(
    'six Agent states use the native main-shell surface',
    (tester) async {
      expect(Platform.isWindows || Platform.isAndroid, isTrue);
      expect(
        Platform.resolvedExecutable.toLowerCase().contains('flutter_tester'),
        isFalse,
      );
      expect(_sourceSha, matches(RegExp(r'^[a-f0-9]{40}$')));
      expect(
        !_keyboard || Platform.isAndroid,
        isTrue,
        reason: 'The native software-keyboard scenario is Android-specific.',
      );
      final textScale =
          double.tryParse(
            const String.fromEnvironment('SKED_AGENT_STATES_TEXT_SCALE'),
          ) ??
          (_accessible ? 2.0 : 1.0);
      expect(textScale, greaterThan(0));
      final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
      if (_output.isNotEmpty &&
          (!path.isAbsolute(_output) ||
              !path.isWithin(temporaryRoot, path.normalize(_output)))) {
        throw ArgumentError(
          'State captures require an isolated directory inside system temp.',
        );
      }
      final output = _output.isEmpty
          ? await Directory.systemTemp.createTemp('sked-agent-states-captures-')
          : await Directory(_output).create(recursive: true);
      if (!path.isWithin(temporaryRoot, await output.resolveSymbolicLinks())) {
        throw ArgumentError(
          'State capture directory resolves outside system temp.',
        );
      }
      final data = await Directory.systemTemp.createTemp(
        'sked-agent-states-data-',
      );
      final store = AgentStore.open(
        filePath: path.join(data.path, 'agent.sqlite'),
      );
      final transport = _NoHttp();
      final provider = AgentOverhaulStateProvider(transport);
      final report = <String, Object?>{
        'sourceSha': _sourceSha,
        'platform': Platform.operatingSystem,
        'surface': 'native runner; no physical or logical size override',
        'input': 'runtime commands and framework Stop taps',
        'fixture':
            'synthetic main data and credentials; isolated background SQLite',
        'brightness': _dark ? 'dark' : 'light',
        'textScale': textScale,
        'direction': _rtl ? 'rtl' : 'ltr',
        'directionSource': 'explicit framework layout direction; Chinese copy',
        'keyboardRequested': _keyboard,
        'keyboardSource': _keyboard
            ? 'Android IME and native View.viewInsets'
            : 'none',
        'captures': <Map<String, Object?>>[],
        'status': 'running',
      };
      AppRuntime? app;
      if (!_keyboard) binding.testTextInput.register();
      try {
        SharedPreferences.setMockInitialValues({});
        PackageInfo.setMockInitialValues(
          appName: 'Sked acceptance',
          packageName: 'com.mashiro.sked.agent_states',
          version: '0',
          buildNumber: '0',
          buildSignature: '',
        );
        app = await workspaceProvider(
          locale: 'zh',
          agentStore: store,
          agentProvider: provider,
        );
        await app.agent.configure(
          const AgentSettings(
            enabled: true,
            endpoint: 'https://native-state.example.invalid/v1',
            model: 'native-state',
            models: [
              AgentModelConfig(
                id: 'native-state',
                reasoningEfforts: [AgentReasoningEffort.medium],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              ),
            ],
          ),
        );
        await app.agent.initialize();
        await tester.pumpWidget(
          RepaintBoundary(
            key: _boundaryKey,
            child: WorkspaceHarness(
              provider: app,
              locale: const Locale('zh'),
              brightness: _dark ? Brightness.dark : Brightness.light,
              textScale: textScale,
              textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await selectAgentShellDestination(tester, 'agent');
        report['states'] = await exerciseAgentOverhaulStates(
          tester: tester,
          app: app,
          store: store,
          provider: provider,
          capture: (name, settle) async {
            if (_keyboard) {
              final composer = find.byKey(const ValueKey('agent-composer'));
              await tester.ensureVisible(composer);
              await tester.tap(composer);
              await SystemChannels.textInput.invokeMethod<void>(
                'TextInput.show',
              );
              final watch = Stopwatch()..start();
              while (tester.view.viewInsets.bottom == 0) {
                if (watch.elapsed > const Duration(seconds: 20)) {
                  fail(
                    'Android did not publish a visible native keyboard inset.',
                  );
                }
                await tester.pump(const Duration(milliseconds: 16));
              }
            }
            if (settle) {
              await tester.pumpAndSettle();
            } else {
              await tester.pump(const Duration(milliseconds: 32));
            }
            expect(tester.takeException(), isNull);
            final boundary =
                _boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(
              pixelRatio: tester.view.devicePixelRatio,
            );
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(path.join(output.path, '$name.png'));
              await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
              (report['captures']! as List<Map<String, Object?>>).add({
                'name': name,
                'path': file.path,
                'logicalWidth': boundary.size.width,
                'logicalHeight': boundary.size.height,
                'pixelWidth': image.width,
                'pixelHeight': image.height,
                'devicePixelRatio': tester.view.devicePixelRatio,
                'nativeKeyboardInset': tester.view.viewInsets.bottom,
              });
            } finally {
              image.dispose();
            }
          },
        );
        expect(transport.attempts, 0);
        report['providerRequests'] = provider.requests;
        report['httpAttempts'] = transport.attempts;
        report['status'] = 'passed';
      } catch (error) {
        report['status'] = 'failed';
        report['failureType'] = error.runtimeType.toString();
        rethrow;
      } finally {
        if (!_keyboard) binding.testTextInput.unregister();
        if (_keyboard) {
          await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        if (app != null) {
          await app.shutdown.quiesce();
          app.dispose();
          await app.session.close();
          await provider.closed;
        } else {
          provider.close();
        }
        await store.close();
        await data.delete(recursive: true);
        await File(path.join(output.path, 'agent-states-evidence.json'))
            .writeAsString(
              const JsonEncoder.withIndent('  ').convert(report),
              flush: true,
            );
        binding.reportData = {'agentRunStates': report};
        if (_output.isEmpty) await output.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    semanticsEnabled: false,
  );
}
