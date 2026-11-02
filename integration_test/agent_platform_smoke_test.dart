import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/screens/agent_page.dart';

import '../test/agent/acceptance/acceptance_harness.dart';
import '../test/support/workspace_harness.dart';

// Run on a dedicated emulator/device, for example:
// flutter test --no-pub -d emulator-5562 integration_test/agent_platform_smoke_test.dart
//
// This renders the real product page on the native Flutter surface. Data,
// credentials, provider transport and native side effects are synthetic. Text
// uses the registered test keyboard and taps are framework-injected; passing
// does not constitute IME, physical-device keyboard, accessibility, gesture or
// notification acceptance.
Finder _key(String value) => find.byKey(ValueKey(value));

class _Entry extends StatelessWidget {
  const _Entry();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('open-product-agent'),
        onPressed: () => unawaited(AgentPage.open(context)),
        child: const Text('Open Agent'),
      ),
    ),
  );
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String description, {
  String Function()? diagnostics,
}) async {
  final deadline = Stopwatch()..start();
  while (!ready()) {
    if (deadline.elapsed > const Duration(seconds: 20)) {
      fail(
        'Timed out waiting for $description.'
        '${diagnostics == null ? '' : ' ${diagnostics()}'}',
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  await _tap(tester, _key('open-product-agent'));
  await _until(
    tester,
    () => _key('agent-composer').evaluate().isNotEmpty,
    'the product Agent composer',
  );
  await tester.pumpAndSettle();
}

Future<void> _selectHistory(WidgetTester tester, String id) async {
  final list = find
      .byKey(const PageStorageKey('agent-conversation-list'))
      .hitTestable();
  if (list.evaluate().isEmpty) {
    await _tap(tester, _key('agent-history'));
  }
  await _until(
    tester,
    () => list.evaluate().length == 1,
    'the actual conversation sidebar or drawer',
  );
  final row = _key('agent-history-$id');
  await _until(
    tester,
    () => row.evaluate().length == 1,
    'the actual conversation history row',
  );
  await _tap(tester, row);
}

Future<void> _sendRequest(WidgetTester tester, String text) async {
  await tester.enterText(_key('agent-composer'), text);
  // Text entry schedules the frame that enables Send. Wait for that actual
  // button state before tapping, as an injected tap does not pump the frame.
  await _until(
    tester,
    () => tester.widget<IconButton>(_key('agent-send')).onPressed != null,
    'the Send button to become enabled',
  );
  await _tap(tester, _key('agent-send'));
}

class _WriteProvider extends ProviderClient {
  final requestedTools = <String>[];
  final requests = <ProviderRequest>[];
  Map<String, dynamic>? committedResult;

  ProviderResponse _call(String tool, Map<String, Object?> arguments) {
    requestedTools.add(tool);
    return ProviderResponse(
      text: '',
      toolCalls: [
        ProviderToolCall(
          id: 'smoke-${requests.length}',
          name: tool,
          arguments: jsonEncode(arguments),
        ),
      ],
      finishReason: 'tool_calls',
    );
  }

  Map<String, dynamic> _lastTool(ProviderRequest request) => jsonDecode(
    request.messages.lastWhere((m) => m.role == ProviderRole.tool).text,
  ) as Map<String, dynamic>;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    expect(apiKey, isEmpty);
    requests.add(request);
    final ProviderResponse response;
    switch (requests.length) {
      case 1:
        response = _call('capabilities.describe', {
          'names': ['mutation.prepare', 'mutation.commit'],
        });
      case 2:
        expect(
          (_lastTool(request)['tools'] as List).map((tool) => tool['name']),
          containsAll(['mutation.prepare', 'mutation.commit']),
        );
        response = _call('mutation.prepare', {
          'commands': [
            {
              'kind': 'event',
              'action': 'create',
              'destinationParentId': 'visible',
              'values': {
                'title': 'Native Agent smoke event',
                'start': '2026-09-07T15:00:00.000',
                'end': '2026-09-07T16:00:00.000',
                'reminderBehavior': 'custom',
                'reminders': [
                  {'minutesBefore': 10},
                ],
              },
            },
          ],
        });
      case 3:
        response = _call('mutation.commit', {
          'planId': _lastTool(request)['planId'],
        });
      default:
        committedResult = _lastTool(request);
        response = ProviderResponse(
          text: 'Added the native smoke event.',
          toolCalls: const [],
          finishReason: 'stop',
        );
    }
    yield ProviderCompleted(response);
  }
}

class _WaitingProvider extends ProviderClient {
  final started = Completer<void>();
  final detached = Completer<void>();
  late final events = StreamController<ProviderEvent>(
    onCancel: () {
      if (!detached.isCompleted) {
        detached.complete();
      }
    },
  );
  ProviderCancellationToken? cancellation;
  var requests = 0;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    expect(apiKey, isEmpty);
    requests++;
    this.cancellation = cancellation;
    events.add(const ProviderTextDelta('Waiting for synthetic model output'));
    // Honor the same cancellation contract as the production provider. The
    // runtime signals the token; its provider must end the active stream.
    unawaited(
      cancellation!.whenCancelled.then((_) {
        if (events.isClosed) return;
        events.addError(const ProviderException(ProviderError.cancelled));
        unawaited(events.close());
      }),
    );
    started.complete();
    return events.stream;
  }

  Future<void> finish() async {
    if (requests != 0) {
      await events.close();
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // IntegrationTest normally leaves the real IME connected. Mixing it with
    // tester.enterText can overwrite injected input, so this smoke explicitly
    // owns the test input channel and makes no claim about Android IME behavior.
    binding.testTextInput.register();
  });
  tearDown(() => binding.testTextInput.unregister());

  testWidgets(
    'native Agent sends, approves a real mutation, retains drafts and switches conversations',
    (tester) async {
      final provider = _WriteProvider();
      final h = AcceptanceHarness();
      await h.initialize(provider: provider);
      final firstId = h.conversationId;
      try {
        await tester.pumpWidget(
          WorkspaceHarness(provider: h.app, home: const _Entry()),
        );
        await tester.pumpAndSettle();
        await _open(tester);
        // Exercise the actual product permission selector instead of injecting
        // an approval or changing OperationScope directly from the test.
        await _tap(tester, _key('agent-mode-picker'));
        await _until(
          tester,
          () => _key('agent-mode-ask').hitTestable().evaluate().isNotEmpty,
          'the permission menu',
        );
        await _tap(tester, _key('agent-mode-ask'));
        await _until(
          tester,
          () =>
              h.app.agent.conversations.selected!.mode ==
              AgentPermissionMode.ask,
          'the saved ask mode',
        );
        await _sendRequest(
          tester,
          'Add Native Agent smoke event in Study on 2026-09-07 from 15:00 to 16:00, remind me ten minutes before.',
        );
        await _until(
          tester,
          () =>
              h.app.agent.runtime.state.value.runFor(firstId).pendingApproval !=
              null,
          'a real pending mutation approval',
        );
        expect(h.saved.generalMode.schedules.first.events, isEmpty);
        expect(provider.requests, hasLength(3));
        expect(_key('agent-approve'), findsOneWidget);
        FocusManager.instance.primaryFocus?.unfocus();
        await _tap(tester, _key('agent-approve'));
        await _until(
          tester,
          () =>
              h.saved.generalMode.schedules.first.events.length == 1 &&
              !h.app.agent.runtime.state.value.runFor(firstId).isActive,
          'the actual saved event and completed run',
        );
        final event = h.saved.generalMode.schedules.first.events.single;
        expect(event.title, 'Native Agent smoke event');
        expect(event.startDateTimeIso, '2026-09-07T15:00:00.000');
        expect(event.endDateTimeIso, '2026-09-07T16:00:00.000');
        expect(event.reminders.single.minutesBefore, 10);
        expect(provider.requestedTools, [
          'capabilities.describe',
          'mutation.prepare',
          'mutation.commit',
        ]);
        expect(provider.committedResult!['status'], 'committed');
        expect(
          h.saved.applicationLedger!.receipts.any(
            (receipt) =>
                receipt.operationId == provider.committedResult!['operationId'],
          ),
          isTrue,
        );
        expect(find.byType(AgentOperationCard), findsWidgets);

        await h.app.agent.runtime.waitForIdle();
        await h.app.agent.conversations.waitForPendingWrites();
        await _until(
          tester,
          () =>
              h.app.agent.conversations.find(firstId)!.status ==
                  ConversationStatus.idle &&
              _key('agent-send').evaluate().isNotEmpty &&
              tester.widget<TextField>(_key('agent-composer')).enabled == true,
          'the completed send and editable composer frame',
        );
        const firstDraft = 'Keep this first conversation draft';
        await tester.enterText(_key('agent-composer'), firstDraft);
        await _until(
          tester,
          () => h.app.agent.conversations.find(firstId)!.draft == firstDraft,
          'the first persisted draft',
          diagnostics: () => jsonEncode({
            'composer': tester
                .widget<TextField>(_key('agent-composer'))
                .controller!
                .text,
            'storedDraft': h.app.agent.conversations.find(firstId)!.draft,
            'status': h.app.agent.conversations.find(firstId)!.status.name,
            'selectedId': h.app.agent.conversations.selectedId,
            'expectedId': firstId,
          }),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pageBack();
        await _until(
          tester,
          () => find.byType(AgentPage).evaluate().isEmpty,
          'the Agent route to close',
        );
        await tester.pumpAndSettle();
        await _open(tester);
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          firstDraft,
        );
        expect(h.app.agent.conversations.selectedId, firstId);
        expect(provider.requests, hasLength(4));

        await _tap(tester, _key('agent-new'));
        await _until(
          tester,
          () =>
              h.app.agent.conversations.conversations.length == 2 &&
              h.app.agent.conversations.selectedId != firstId,
          'a separate second conversation',
        );
        final secondId = h.app.agent.conversations.selectedId!;
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          isEmpty,
        );
        const secondDraft = 'A separate second conversation draft';
        await tester.enterText(_key('agent-composer'), secondDraft);
        await _until(
          tester,
          () => h.app.agent.conversations.find(secondId)!.draft == secondDraft,
          'the second persisted draft',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await _selectHistory(tester, firstId);
        await _until(
          tester,
          () =>
              h.app.agent.conversations.selectedId == firstId &&
              _key('agent-history-drawer').evaluate().isEmpty &&
              _key('agent-composer').hitTestable().evaluate().length == 1,
          'the original conversation',
        );
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          firstDraft,
        );
        await _selectHistory(tester, secondId);
        await _until(
          tester,
          () =>
              h.app.agent.conversations.selectedId == secondId &&
              _key('agent-history-drawer').evaluate().isEmpty &&
              _key('agent-composer').hitTestable().evaluate().length == 1,
          'the second conversation',
        );
        expect(
          tester.widget<TextField>(_key('agent-composer')).controller!.text,
          secondDraft,
        );
        expect(h.app.agent.conversations.find(firstId)!.messages, isNotEmpty);
        expect(h.app.agent.conversations.find(secondId)!.messages, isEmpty);
        expect(provider.requests, hasLength(4));
        expect(tester.takeException(), isNull);
        binding.reportData = {
          ...?binding.reportData,
          'mutationAndDrafts': 'passed',
          'platform': defaultTargetPlatform.name,
          'inputScope': 'framework-injected on native Flutter surface',
          'dataScope': 'synthetic storage and provider only',
        };
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await h.close();
      }
    },
  );

  testWidgets(
    'native Agent Stop cancels an active provider without committing or replaying',
    (tester) async {
      final provider = _WaitingProvider();
      final h = AcceptanceHarness();
      await h.initialize(provider: provider);
      try {
        final before = h.saved.encode();
        await tester.pumpWidget(
          WorkspaceHarness(provider: h.app, home: const _Entry()),
        );
        await tester.pumpAndSettle();
        await _open(tester);
        await _sendRequest(tester, 'Keep thinking until I stop this request.');
        await _until(
          tester,
          () =>
              provider.started.isCompleted &&
              h.app.agent.runtime.state.value.runFor(h.conversationId).isActive,
          'the live synthetic provider',
        );
        await _tap(tester, _key('agent-stop'));
        expect(provider.cancellation!.isCancelled, isTrue);
        await _until(
          tester,
          () =>
              provider.detached.isCompleted &&
              !h.app.agent.runtime.state.value
                  .runFor(h.conversationId)
                  .isActive,
          'provider cancellation and runtime settlement',
        );
        await h.app.agent.runtime.waitForIdle();
        expect(h.saved.encode(), before);
        expect(provider.requests, 1);
        expect(
          h.app.agent.conversations.selected!.status,
          ConversationStatus.interrupted,
        );
        expect(_key('agent-continue'), findsOneWidget);
        expect(tester.takeException(), isNull);
        binding.reportData = {...?binding.reportData, 'stop': 'passed'};
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await h.close();
        await provider.finish();
      }
    },
  );
}
