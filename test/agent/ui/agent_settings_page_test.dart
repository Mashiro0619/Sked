import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/agent/ui/agent_model_settings_form.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/agent_settings_page.dart';

import '../../support/workspace_harness.dart';

void main() {
  late AppRuntime app;

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> mount(WidgetTester tester, {double height = 560}) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(1200, height);
    await tester.runAsync(() async {
      app = await workspaceProvider();
      // Load the real bundled knowledge before entering FakeAsync so its
      // cached asset Futures also remain usable by later application tests.
      await app.agent.initialize();
      await app.agent.knowledge.initialize();
    });
    addTearDown(app.dispose);
    await tester.pumpWidget(
      WorkspaceHarness(provider: app, home: const AgentSettingsPage()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectKnowledge(WidgetTester tester, KnowledgeKind kind) async {
    await tester.tap(
      key(
        'agent-settings-${kind == KnowledgeKind.skill ? 'skills' : 'memories'}',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AgentKnowledgeView>(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is AgentKnowledgeView && widget.kind == kind,
                )
                .hitTestable(),
          )
          .service,
      same(app.agent.knowledge),
    );
  }

  Finder skillView() => find
      .byWidgetPredicate(
        (widget) =>
            widget is AgentKnowledgeView && widget.kind == KnowledgeKind.skill,
      )
      .hitTestable();

  ScrollableState verticalScroll(WidgetTester tester, Finder owner) =>
      tester.state<ScrollableState>(
        find.descendant(of: owner, matching: find.byType(Scrollable)).first,
      );

  Future<void> wheel(WidgetTester tester, Finder owner, double amount) async {
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(owner),
        scrollDelta: Offset(0, amount),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.agent.quiesce);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop knowledge wheel scrolling keeps other settings tabs intact',
    (tester) async {
      await mount(tester);
      final endpoint = key('agent-endpoint');
      await tester.enterText(endpoint, 'https://settings-draft.invalid/v1');
      await tester.pumpAndSettle();
      final modelView = find.byType(AgentModelSettingsForm);
      final modelScroll = verticalScroll(tester, modelView);
      await wheel(tester, modelView, 160);
      final modelOffset = modelScroll.position.pixels;
      expect(modelOffset, greaterThan(0));

      await selectKnowledge(tester, KnowledgeKind.memory);
      await selectKnowledge(tester, KnowledgeKind.skill);
      final skills = skillView();
      final skillScroll = verticalScroll(tester, skills);
      final before = skillScroll.position.pixels;
      expect(skillScroll.position.maxScrollExtent, greaterThan(before));
      expect(
        find.descendant(of: skills, matching: find.byType(Scrollbar)),
        findsOneWidget,
      );
      await wheel(tester, skills, 180);
      expect(skillScroll.position.pixels, greaterThan(before));
      expect(tester.takeException(), isNull);
      expect(modelScroll.position.pixels, closeTo(modelOffset, 0.01));

      await tester.tap(find.byType(Tab).first);
      await tester.pumpAndSettle();
      expect(verticalScroll(tester, modelView), same(modelScroll));
      expect(modelScroll.position.pixels, closeTo(modelOffset, 0.01));
      expect(
        tester.widget<TextFormField>(endpoint).controller!.text,
        'https://settings-draft.invalid/v1',
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    timeout: const Timeout(Duration(seconds: 45)),
  );

  testWidgets(
    'desktop keyboard traversal reveals settings fields after visiting knowledge tabs',
    (tester) async {
      await mount(tester, height: 460);
      await selectKnowledge(tester, KnowledgeKind.memory);
      await selectKnowledge(tester, KnowledgeKind.skill);
      await tester.tap(find.byType(Tab).first);
      await tester.pumpAndSettle();
      final endpoint = key('agent-endpoint');
      expect(endpoint.hitTestable(), findsOneWidget);
      await tester.tap(endpoint);
      await tester.pumpAndSettle();
      final modelView = find.byType(AgentModelSettingsForm);
      final modelScroll = verticalScroll(tester, modelView);
      final before = modelScroll.position.pixels;
      final apiKey = find.descendant(
        of: key('agent-api-key'),
        matching: find.byType(EditableText),
      );
      var reachedApiKey = false;
      for (var attempt = 0; attempt < 12; attempt++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (tester.widget<EditableText>(apiKey).focusNode.hasFocus) {
          reachedApiKey = true;
          break;
        }
      }
      expect(reachedApiKey, isTrue);
      expect(key('agent-api-key').hitTestable(), findsOneWidget);
      expect(modelScroll.position.pixels, greaterThan(before));
      expect(
        find.descendant(of: modelView, matching: find.byType(Scrollbar)),
        findsOneWidget,
      );
      expect(app.agent.runtime.state.value.runs, isEmpty);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
