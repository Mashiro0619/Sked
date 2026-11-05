import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_model_picker.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
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
}
