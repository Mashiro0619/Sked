import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/agent/ui/agent_model_settings_form.dart';
import 'package:sked/agent/ui/agent_preferences_form.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_settings_page.dart';

import '../../support/workspace_harness.dart';

class _PausedSettingsStorage extends WorkspaceMemoryStorage {
  _PausedSettingsStorage()
    : super(buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'));

  bool pause = false;
  final entered = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> save(AppData value) async {
    if (pause) {
      if (!entered.isCompleted) entered.complete();
      await resume.future;
      pause = false;
    }
    await super.save(value);
  }
}

void main() {
  late AppRuntime app;

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> mount(
    WidgetTester tester, {
    double height = 560,
    WorkspaceMemoryStorage? storage,
  }) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(1200, height);
    await tester.runAsync(() async {
      app = await workspaceProvider(storage: storage);
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

  SemanticsOwner tabSemanticsOwner(WidgetTester tester) =>
      tester.renderObject(find.byType(TabBar)).owner!.semanticsOwner!;

  List<SemanticsNode> publishedTabs(WidgetTester tester) {
    final result = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      if (!node.isMergedIntoParent &&
          node.getSemanticsData().role == ui.SemanticsRole.tab) {
        result.add(node);
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tabSemanticsOwner(tester).rootSemanticsNode!);
    return result;
  }

  testWidgets(
    'settings tabs retain distinct roles and actions across selection',
    (tester) async {
      await mount(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentSettingsPage)),
      );
      final labels = [
        l.agentModelSettings,
        l.agentRunPreferences,
        l.agentSkills,
        l.agentMemories,
      ];
      final compatibilityButton =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
      void expectTabs(int selected) {
        final nodes = publishedTabs(tester);
        expect(nodes, hasLength(labels.length));
        expect(nodes.map((node) => node.id).toSet(), hasLength(labels.length));
        for (var index = 0; index < labels.length; index++) {
          final node = nodes[index];
          final data = node.getSemanticsData();
          expect(node.parent!.getSemanticsData().role, ui.SemanticsRole.tabBar);
          expect(data.label, contains(labels[index]));
          expect(data.flagsCollection.isButton, compatibilityButton);
          expect(
            data.flagsCollection.isSelected == ui.Tristate.isTrue,
            index == selected,
          );
          expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
          expect(data.flagsCollection.isHidden, isFalse);
        }
      }

      expectTabs(0);
      for (final index in [1, 2, 3, 0]) {
        await tester.tap(find.byType(Tab).at(index));
        await tester.pumpAndSettle();
        expectTabs(index);
      }
      // The merged action still belongs to the real TabBar controller.
      tabSemanticsOwner(tester)
          .performAction(publishedTabs(tester)[2].id, ui.SemanticsAction.tap);
      await tester.pumpAndSettle();
      expectTabs(2);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }),
    timeout: const Timeout(Duration(seconds: 45)),
  );

  testWidgets(
    'Windows settings tabs remain blocked during an accepted save',
    (tester) async {
      late _PausedSettingsStorage storage;
      await tester.runAsync(() async {
        storage = _PausedSettingsStorage();
      });
      await mount(tester, height: 900, storage: storage);
      try {
        await tester.tap(find.byType(Tab).at(1));
        await tester.pumpAndSettle();
        await tester.enterText(
          key('agent-system-instructions'),
          'Synthetic preference awaiting its real save',
        );
        final save = find.descendant(
          of: find.byType(AgentPreferencesForm).hitTestable(),
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        final tabFocus = Focus.of(tester.element(find.byType(Tab).at(2)));
        expect(tabFocus.canRequestFocus, isTrue);
        storage.pause = true;
        expect(save.hitTestable(), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(save.hitTestable());
          await storage.entered.future.timeout(const Duration(seconds: 10));
        });
        await tester.pump();
        final controller = DefaultTabController.of(
          tester.element(find.byType(TabBar)),
        );
        for (final node in publishedTabs(tester)) {
          final data = node.getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
        }
        await tester.tap(find.byType(Tab).at(2), warnIfMissed: false);
        tabSemanticsOwner(tester)
            .performAction(publishedTabs(tester)[3].id, ui.SemanticsAction.tap);
        expect(tabFocus.canRequestFocus, isFalse);
        tabFocus.requestFocus();
        await tester.pump();
        expect(tabFocus.hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(controller.index, 1);
        expect(
          publishedTabs(
            tester,
          )[1].getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );

        await tester.runAsync(() async {
          storage.resume.complete();
          await app.agent.quiesce();
        });
        await tester.pumpAndSettle();
        for (final node in publishedTabs(tester)) {
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
        }
        await tester.tap(find.byType(Tab).at(2));
        await tester.pumpAndSettle();
        expect(controller.index, 2);
        expect(
          app.agent.settings.systemInstructions,
          'Synthetic preference awaiting its real save',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.runAsync(() async {
          if (!storage.resume.isCompleted) storage.resume.complete();
          await app.agent.quiesce();
        });
        await unmount(tester);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    timeout: const Timeout(Duration(seconds: 45)),
  );

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
