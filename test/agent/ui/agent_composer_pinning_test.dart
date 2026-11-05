import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_model_picker.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/models/agent_settings.dart';

import 'agent_ui_test_support.dart';

void main() {
  const model = AgentModelConfig(
    id: 'model-a',
    reasoningEfforts: [AgentReasoningEffort.low],
    defaultReasoningEffort: AgentReasoningEffort.low,
  );
  final draft = List.generate(
    8,
    (index) => '第 ${index + 1} 项：保留课程名称、时间和地点。',
  ).join('\n');
  late ConversationRepository repository;
  late ConversationAttachments files;
  late UiDelegate delegate;
  late String id;
  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> initialize({bool running = false}) async {
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    id = (await repository.create(title: 'Pinned composer')).id;
    await repository.update(
      id,
      (current) => current.copyWith(
        draft: draft,
        attachments: [
          for (var index = 0; index < 3; index++)
            ConversationAttachment(
              id: 'file-$index',
              name: '2026 学期课程安排 $index.csv',
              mediaType: 'text/csv',
              byteLength: 128,
              digest: '0' * 64,
            ),
        ],
        draftAttachmentIds: ['file-0', 'file-1', 'file-2'],
      ),
    );
    files = ConversationAttachments(
      conversations: repository,
      repository: AttachmentRepository(storage: MemoryAttachmentStorage()),
    );
    delegate = UiDelegate(repository);
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      availableModels: const [model],
      defaultModelSelection: model.defaultSelection,
      runs: {
        if (running) id: const AgentUiRunState(phase: AgentUiPhase.running),
      },
    );
  }

  Widget view() => AgentConversationView(
    repository: repository,
    delegate: delegate,
    binaryAttachments: files,
    modelPickerBuilder: (conversation, _, layout) => AgentModelPicker(
      conversationId: conversation.id,
      delegate: delegate,
      layoutBuilder: layout,
    ),
  );
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await repository.waitForPendingWrites();
    await tester.pumpAndSettle();
  }

  tearDown(() {
    files.dispose();
    repository.dispose();
    delegate.state.dispose();
  });

  for (final scene in [
    (size: const Size(390, 844), scale: 1.0, keyboard: 0.0),
    (size: const Size(320, 740), scale: 2.0, keyboard: 0.0),
    (size: const Size(320, 740), scale: 2.0, keyboard: 280.0),
    (size: const Size(1440, 900), scale: 2.0, keyboard: 0.0),
  ]) {
    testWidgets(
      'attachments and a multiline draft scroll above pinned send at $scene',
      (tester) async {
        addTearDown(tester.view.reset);
        await initialize();
        await mountAgentUi(
          tester,
          view(),
          size: scene.size,
          scale: scene.scale,
          keyboard: scene.keyboard,
          locale: const Locale('zh'),
        );
        final actions = key('agent-composer-actions');
        final before = tester.getRect(actions);
        final body = key('agent-composer-body-scroll');
        expect(body, findsOneWidget);
        expect(key('agent-send').hitTestable(), findsOneWidget);
        expect(
          before.bottom,
          lessThanOrEqualTo(scene.size.height - scene.keyboard),
        );
        final field = tester.widget<TextField>(key('agent-composer'));
        final controller = field.controller;
        await tester.drag(body, const Offset(0, -400));
        await settle(tester);
        expect(tester.getRect(actions), before);
        expect(
          tester.widget<TextField>(key('agent-composer')).controller,
          same(controller),
        );
        expect(controller!.text, draft);
        expect(key('agent-send').hitTestable(), findsOneWidget);
        if (Theme.of(tester.element(actions)).platform ==
            TargetPlatform.android) {
          expect((field.decoration!.contentPadding! as EdgeInsets).bottom, 36);
        }
        await tester.tap(key('agent-send'));
        await settle(tester);
        expect(delegate.calls, ['send:$id:$draft']);
        expect(tester.takeException(), isNull);
        await files.close();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'running draft keeps stop pinned and preserves steering and follow-up actions',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize(running: true);
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 740),
        scale: 2,
        keyboard: 280,
        locale: const Locale('zh'),
      );
      final actions = key('agent-composer-actions');
      final before = tester.getRect(actions);
      expect(key('agent-stop').hitTestable(), findsOneWidget);
      await tester.tap(key('agent-stop'));
      await settle(tester);
      expect(delegate.calls, ['stop:$id']);
      await tester.ensureVisible(key('agent-steer'));
      await settle(tester);
      expect(tester.getRect(actions), before);
      await tester.tap(key('agent-steer'));
      await settle(tester);
      expect(delegate.calls.last, 'steer:$id:$draft');
      await tester.enterText(key('agent-composer'), '再安排下一条');
      await settle(tester);
      await tester.ensureVisible(key('agent-queue'));
      await settle(tester);
      expect(key('agent-stop').hitTestable(), findsOneWidget);
      await tester.tap(key('agent-queue'));
      await settle(tester);
      expect(delegate.calls.last, 'queue:$id:再安排下一条');
      expect(tester.takeException(), isNull);
      await files.close();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'very short windows use transcript scrolling and retain the draft across layout changes',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 740),
        scale: 2,
        locale: const Locale('zh'),
      );
      final controller = tester
          .widget<TextField>(key('agent-composer'))
          .controller!;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 5,
      );
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 210),
        scale: 2,
        locale: const Locale('zh'),
      );
      expect(key('agent-composer-body-scroll'), findsNothing);
      await tester.ensureVisible(key('agent-send'));
      await settle(tester);
      expect(key('agent-send').hitTestable(), findsOneWidget);
      expect(controller.text, draft);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 740),
        scale: 2,
        locale: const Locale('zh'),
      );
      expect(key('agent-composer-body-scroll'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('agent-composer')).controller,
        same(controller),
      );
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(key('agent-send').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await files.close();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  for (final scene in [
    (name: 'tall keyboard', size: const Size(320, 740), keyboard: 400.0),
    (name: 'short window', size: const Size(320, 210), keyboard: 0.0),
    (name: 'reading history', size: const Size(320, 740), keyboard: 400.0),
  ]) {
    testWidgets(
      'IME client and composing text survive $scene and returning to pinned input',
      (tester) async {
        addTearDown(tester.view.reset);
        await initialize();
        if (scene.name == 'reading history') {
          await repository.update(
            id,
            (value) => value.copyWith(
              messages: [
                for (var index = 0; index < 30; index++)
                  ConversationMessage(
                    id: 'history-$index',
                    role: ConversationRole.user,
                    text: 'Earlier message $index',
                    createdAt: DateTime.utc(2026, 11, 5),
                  ),
              ],
            ),
          );
        }
        await mountAgentUi(
          tester,
          view(),
          size: const Size(320, 740),
          scale: 2,
        );
        if (scene.name == 'reading history') {
          await tester.drag(key('agent-transcript-$id'), const Offset(0, 1200));
          await tester.pumpAndSettle();
        }
        final field = tester.widget<TextField>(key('agent-composer'));
        final editable = find.descendant(
          of: find.byKey(const ValueKey('agent-composer'), skipOffstage: false),
          matching: find.byType(EditableText, skipOffstage: false),
          skipOffstage: false,
        );
        final originalState = tester.state<EditableTextState>(editable);
        final reading = tester
            .widget<AgentTranscript>(find.byType(AgentTranscript))
            .position;
        final anchor = reading.anchor;
        if (scene.name == 'reading history') {
          expect(reading.followLatest, isFalse);
          expect(anchor, isNotNull);
        }
        field.focusNode!.requestFocus();
        await tester.pumpAndSettle();
        await tester.showKeyboard(key('agent-composer'));
        int clientAttachments() => tester.testTextInput.log
            .where((call) => call.method == 'TextInput.setClient')
            .length;
        final originalClientAttachments = clientAttachments();
        const selection = TextSelection(baseOffset: 2, extentOffset: 5);
        const composing = TextRange(start: 1, end: 6);
        var value = TextEditingValue(
          text: draft,
          selection: selection,
          composing: composing,
        );
        tester.testTextInput.updateEditingValue(value);
        await settle(tester);
        void expectConnected() {
          expect(
            tester.state<EditableTextState>(editable),
            same(originalState),
          );
          expect(field.focusNode!.hasFocus, isTrue);
          expect(tester.testTextInput.hasAnyClients, isTrue);
          expect(clientAttachments(), originalClientAttachments);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(field.controller!.value, value);
        }

        expectConnected();
        await mountAgentUi(
          tester,
          view(),
          size: const Size(320, 740),
          scale: 2,
          keyboard: 280,
        );
        expect(key('agent-composer-body-scroll'), findsOneWidget);
        expectConnected();
        await mountAgentUi(
          tester,
          view(),
          size: scene.size,
          scale: 2,
          keyboard: scene.keyboard,
        );
        expect(key('agent-composer-body-scroll'), findsNothing);
        expectConnected();
        if (scene.name == 'reading history') expect(reading.anchor, anchor);
        // Send through the existing client while the editor may be below the
        // visible history; showing the keyboard again would mask a disconnect.
        value = value.copyWith(text: '$draft\n窗口变化期间继续输入');
        tester.testTextInput.updateEditingValue(value);
        await settle(tester);
        expectConnected();
        expect(repository.selected!.draft, value.text);
        await mountAgentUi(
          tester,
          view(),
          size: const Size(320, 740),
          scale: 2,
        );
        expect(key('agent-composer-body-scroll'), findsOneWidget);
        expectConnected();
        // Deliver through the existing platform client. enterText/showKeyboard
        // would reconnect a disposed EditableText and conceal this regression.
        tester.testTextInput.updateEditingValue(
          value.copyWith(text: '$draft\n继续输入'),
        );
        await settle(tester);
        expect(field.controller!.text, '$draft\n继续输入');
        expect(repository.selected!.draft, '$draft\n继续输入');
        expect(tester.takeException(), isNull);
        await files.close();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
