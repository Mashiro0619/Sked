import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_model_picker.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/workspace_frame.dart';

import 'agent_ui_test_support.dart';

class _ModelDelegate extends UiDelegate {
  _ModelDelegate(super.repository);
  final choices = <AgentModelSelection>[];
  Future<void>? selectionWrite;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> setModelSelection(String id, AgentModelSelection selection) =>
      selectionWrite = _persistSelection(id, selection);
  Future<void> _persistSelection(
    String id,
    AgentModelSelection selection,
  ) async {
    choices.add(selection);
    await gate?.future;
    if (fail) throw StateError('private error');
    await repository.update(
      id,
      (value) => value.copyWith(modelSelection: selection),
    );
    final previous = state.value;
    state.value = AgentUiState(
      enabled: previous.enabled,
      configured: previous.configured,
      availableModels: previous.availableModels,
      defaultModelSelection: previous.defaultModelSelection,
      modelSelections: {...previous.modelSelections, id: selection},
      runs: previous.runs,
    );
  }
}

void main() {
  const modelA = AgentModelConfig(
    id: 'model-a',
    reasoningEfforts: [AgentReasoningEffort.high, AgentReasoningEffort.low],
    defaultReasoningEffort: AgentReasoningEffort.low,
  );
  const modelB = AgentModelConfig(
    id: 'model-b',
    reasoningEfforts: [AgentReasoningEffort.medium],
    defaultReasoningEffort: AgentReasoningEffort.medium,
  );
  const low = AgentModelSelection(
    modelId: 'model-a',
    reasoningEffort: AgentReasoningEffort.low,
  );
  late ConversationRepository repository;
  late _ModelDelegate delegate;
  late String id;
  Future<void> initialize(
    WidgetTester tester, {
    List<AgentModelConfig> models = const [modelA, modelB],
    AgentModelSelection? selection = low,
    bool running = false,
  }) async {
    addTearDown(tester.view.reset);
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    id = (await repository.create(title: 'Model choice')).id;
    delegate = _ModelDelegate(repository);
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      availableModels: models,
      defaultModelSelection: selection,
      runs: {
        if (running)
          id: const AgentUiRunState(
            phase: AgentUiPhase.running,
            modelSelection: low,
          ),
      },
    );
    addTearDown(() {
      delegate.state.dispose();
      repository.dispose();
    });
  }

  Widget view({bool active = true, bool interactive = true}) =>
      AgentModelPicker(
        conversationId: id,
        delegate: delegate,
        active: active,
        interactive: interactive,
      );
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('agent-model-picker')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseB(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-model-choice-model-b')));
    await tester.pumpAndSettle();
  }

  Rect expectMenuSurfaceVisible(WidgetTester tester, Finder item) {
    Element? surface;
    tester.element(item).visitAncestorElements((element) {
      if (element.widget is Material) {
        surface = element;
        return false;
      }
      return true;
    });
    expect(surface, isNotNull);
    final box = surface!.findRenderObject()! as RenderBox;
    final localBounds = Offset.zero & box.size;
    final bounds = MatrixUtils.transformRect(
      box.getTransformTo(null),
      localBounds,
    );
    final window =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    expect(bounds.intersect(window), bounds);
    for (RenderObject child = box; child.parent != null;) {
      final parent = child.parent!;
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        final paintedBounds = MatrixUtils.transformRect(
          box.getTransformTo(parent),
          localBounds,
        );
        expect(
          clip.inflate(0.01).contains(paintedBounds.topLeft) &&
              clip.inflate(0.01).contains(paintedBounds.bottomRight),
          isTrue,
          reason:
              'The complete menu surface $paintedBounds must fit the ${parent.runtimeType} clip $clip.',
        );
      }
      child = parent;
    }
    return bounds;
  }

  for (final scene in [
    (size: const Size(1440, 900), scale: 1.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 740), scale: 2.0),
  ]) {
    testWidgets(
      'complete model menu surface stays visible at ${scene.size} ${scene.scale}x',
      (tester) async {
        const longModel = AgentModelConfig(
          id: 'local-reasoning-model-with-a-long-display-name',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        );
        await initialize(tester, models: const [modelA, longModel]);
        await mountAgentUi(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(width: 180, child: view()),
            ),
          ),
          size: scene.size,
          scale: scene.scale,
        );
        await open(tester);
        final modelSwitch = find.byKey(const ValueKey('agent-model-switch'));
        expectMenuSurfaceVisible(tester, modelSwitch);
        await tester.tap(modelSwitch);
        await tester.pumpAndSettle();
        final choice = find.byKey(
          ValueKey('agent-model-choice-${longModel.id}'),
        );
        expectMenuSurfaceVisible(tester, choice);
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(choice.hitTestable(), findsOneWidget);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        await delegate.selectionWrite;
        expect(repository.selected!.modelSelection, longModel.defaultSelection);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }

  for (final changesActivity in [true, false]) {
    testWidgets(
      'retained picker drops its old token after ${changesActivity ? 'activity' : 'interaction'} falls',
      (tester) async {
        await initialize(tester);
        await mountAgentUi(tester, view());
        final retainedState = tester.state(find.byType(AgentModelPicker));
        await open(tester);
        final previousSlider = tester.widget<Slider>(find.byType(Slider));
        previousSlider.onChanged!(1);
        await tester.pump();
        await mountAgentUi(
          tester,
          view(active: !changesActivity, interactive: changesActivity),
        );
        await mountAgentUi(tester, view());
        expect(
          tester.state(find.byType(AgentModelPicker)),
          same(retainedState),
        );
        await open(tester);
        previousSlider.onChangeEnd!(1);
        await tester.pumpAndSettle();
        expect(delegate.choices, isEmpty);
        expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
        final freshSlider = tester.widget<Slider>(find.byType(Slider));
        freshSlider.onChanged!(1);
        freshSlider.onChangeEnd!(1);
        await tester.pumpAndSettle();
        expect(delegate.choices, hasLength(1));
        expect(
          delegate.choices.single.reasoningEffort,
          AgentReasoningEffort.high,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact menu keeps effort above model and names slider values at ${scale}x',
      (tester) async {
        await initialize(tester);
        await mountAgentUi(
          tester,
          view(),
          size: const Size(320, 740),
          scale: scale,
        );
        await open(tester);
        final modelSwitch = find.byKey(const ValueKey('agent-model-switch'));
        final modelName = find.byKey(const ValueKey('agent-model-name'));
        final current = find.byKey(const ValueKey('agent-effort-value'));
        expect(
          tester.getRect(current).bottom,
          lessThanOrEqualTo(tester.getRect(modelName).top),
        );
        expect(
          tester.getCenter(current).dx,
          closeTo(tester.getCenter(modelSwitch).dx, .1),
        );
        expect(tester.widget<Text>(current).data, 'Low');
        expect(find.text('Thinking effort'), findsNothing);
        expect(find.text('Medium'), findsNothing);
        final slider = tester.widget<Slider>(find.byType(Slider));
        expect(slider.divisions, 1);
        expect(slider.semanticFormatterCallback!(0), 'Low');
        expect(slider.semanticFormatterCallback!(1), 'High');
        if (scale == 1) {
          final surface = expectMenuSurfaceVisible(
            tester,
            find.byKey(const ValueKey('agent-model-panel')),
          );
          expect(surface.width, closeTo(244, .1));
          expect(surface.height, lessThanOrEqualTo(116));
        }
        expect(tester.getSize(modelSwitch).height, greaterThanOrEqualTo(48));
        final semantics = tester
            .getSemantics(find.byType(Slider))
            .getSemanticsData();
        expect(semantics.label, contains('Thinking effort'));
        expect(semantics.value, 'Low');
        slider.onChanged!(1);
        await tester.pump();
        expect(tester.widget<Text>(current).data, 'High');
        expect(delegate.choices, isEmpty);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'a single configured effort is a labeled value without a slider range',
    (tester) async {
      await initialize(
        tester,
        models: const [modelB],
        selection: modelB.defaultSelection,
      );
      await mountAgentUi(tester, view(), size: const Size(320, 740), scale: 2);
      await open(tester);
      expect(find.text('model-b'), findsWidgets);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('agent-effort-value')))
            .data,
        'Medium',
      );
      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(const ValueKey('agent-effort-minimum')), findsNothing);
      expect(find.byKey(const ValueKey('agent-effort-maximum')), findsNothing);
      final modelSwitch = find.byKey(const ValueKey('agent-model-switch'));
      expect(modelSwitch.hitTestable(), findsOneWidget);
      expect(
        find.descendant(
          of: modelSwitch,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(modelSwitch);
      await tester.pumpAndSettle();
      final onlyModel = find.byKey(
        const ValueKey('agent-model-choice-model-b'),
      );
      expect(onlyModel.hitTestable(), findsOneWidget);
      await tester.tap(onlyModel);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-model-panel')), findsOneWidget);
      expect(delegate.choices, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'model list waits for save and keeps failures available for retry',
    (tester) async {
      await initialize(tester);
      delegate.gate = Completer<void>();
      addTearDown(() {
        if (!delegate.gate!.isCompleted) delegate.gate!.complete();
      });
      await mountAgentUi(tester, view());
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('agent-model-choice-model-b'));
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-model-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-model-panel')), findsNothing);
      expect(delegate.state.value.selectionFor(id), low);
      expect(tester.widget<MenuItemButton>(choice).onPressed, isNull);
      delegate.fail = true;
      delegate.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-model-list')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-model-list-error')),
        findsOneWidget,
      );
      expect(delegate.state.value.selectionFor(id), low);
      delegate.fail = false;
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-model-panel')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-model-list-error')),
        findsNothing,
      );
      expect(repository.selected!.modelSelection, modelB.defaultSelection);
      expect(delegate.choices, [
        modelB.defaultSelection,
        modelB.defaultSelection,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a different model keeps the existing effort when supported', (
    tester,
  ) async {
    const compatible = AgentModelConfig(
      id: 'compatible',
      reasoningEfforts: [AgentReasoningEffort.low, AgentReasoningEffort.medium],
      defaultReasoningEffort: AgentReasoningEffort.medium,
    );
    await initialize(tester, models: const [modelA, compatible]);
    await mountAgentUi(tester, view());
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-model-choice-compatible')),
    );
    await tester.pumpAndSettle();
    const expected = AgentModelSelection(
      modelId: 'compatible',
      reasoningEffort: AgentReasoningEffort.low,
    );
    expect(repository.selected!.modelSelection, expected);
    expect(delegate.choices, [expected]);
    expect(find.byKey(const ValueKey('agent-model-panel')), findsOneWidget);
  });

  testWidgets(
    'outgoing card and list callbacks cannot act on the current page',
    (tester) async {
      await initialize(tester);
      await mountAgentUi(tester, view());
      await open(tester);
      final oldSlider = tester.widget<Slider>(find.byType(Slider));
      await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
      await tester.pump();
      expect(find.byType(Slider).hitTestable(), findsNothing);
      oldSlider.onChanged!(1);
      oldSlider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      final oldChoice = tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey('agent-model-choice-model-b')),
          )
          .onPressed!;
      await tester.tap(find.byKey(const ValueKey('agent-model-list-back')));
      // MenuItemButton delivers activation after the first frame. Build the
      // resulting page switch before checking its still-fading old controls.
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-model-choice-model-b')).hitTestable(),
        findsNothing,
      );
      oldChoice();
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    },
  );

  testWidgets(
    'Escape closes the menu after model selection and list back navigation',
    (tester) async {
      const alternate = AgentModelConfig(
        id: 'model-b',
        reasoningEfforts: [
          AgentReasoningEffort.low,
          AgentReasoningEffort.high,
          AgentReasoningEffort.max,
        ],
        defaultReasoningEffort: AgentReasoningEffort.low,
      );
      await initialize(tester, models: const [modelA, alternate]);
      var workspaceDismissals = 0;
      await mountAgentUi(
        tester,
        Shortcuts(
          // The workspace shell owns Escape outside its transient menus.
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape):
                WorkspaceTaskDismissIntent(),
          },
          child: Actions(
            actions: {
              WorkspaceTaskDismissIntent:
                  CallbackAction<WorkspaceTaskDismissIntent>(
                    onInvoke: (_) {
                      workspaceDismissals++;
                      return null;
                    },
                  ),
            },
            child: view(),
          ),
        ),
      );
      await open(tester);
      await chooseB(tester);
      await delegate.selectionWrite;
      expect(repository.selected!.modelSelection, alternate.defaultSelection);
      expect(find.byKey(const ValueKey('agent-model-panel')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-model-list-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('agent-model-list')), findsNothing);
      expect(find.byKey(const ValueKey('agent-model-panel')), findsOneWidget);
      expect(
        [
          FocusManager.instance.primaryFocus,
          ...?FocusManager.instance.primaryFocus?.ancestors,
        ].any((node) => node?.debugLabel == 'Sked menu'),
        isTrue,
        reason: 'Page changes must retain keyboard ownership in the menu.',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(workspaceDismissals, 0);
      expect(find.byKey(const ValueKey('agent-model-panel')), findsNothing);
      expect(delegate.choices, [alternate.defaultSelection]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing during page transition retires all old choices immediately',
    (tester) async {
      await initialize(tester);
      await mountAgentUi(tester, view());
      await open(tester);
      final oldSlider = tester.widget<Slider>(find.byType(Slider));
      await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final oldChoice = tester
          .widget<MenuItemButton>(
            find.byKey(const ValueKey('agent-model-choice-model-b')),
          )
          .onPressed!;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      oldChoice();
      oldSlider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(find.byKey(const ValueKey('agent-model-list')), findsNothing);
      expect(delegate.state.value.selectionFor(id), low);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'card and list keep their width and anchor edge during height interpolation',
    (tester) async {
      final models = [
        modelA,
        modelB,
        for (var index = 0; index < 12; index++)
          AgentModelConfig(
            id: 'extra-$index',
            reasoningEfforts: const [AgentReasoningEffort.low],
            defaultReasoningEffort: AgentReasoningEffort.low,
          ),
      ];
      await initialize(tester, models: models);
      await mountAgentUi(
        tester,
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(width: 180, child: view()),
          ),
        ),
        size: const Size(390, 844),
      );
      await open(tester);
      final start = expectMenuSurfaceVisible(
        tester,
        find.byKey(const ValueKey('agent-model-panel')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final middle = expectMenuSurfaceVisible(
        tester,
        find.byKey(const ValueKey('agent-model-list')),
      );
      await tester.pumpAndSettle();
      final end = expectMenuSurfaceVisible(
        tester,
        find.byKey(const ValueKey('agent-model-list')),
      );
      expect(middle.height, greaterThan(start.height));
      expect(middle.height, lessThan(end.height));
      expect(end.width, closeTo(start.width, .1));
      expect(end.width, closeTo(244, .1));
      expect(middle.bottom, closeTo(start.bottom, .5));
      expect(end.bottom, closeTo(start.bottom, .5));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final reduced in [true, false]) {
    testWidgets(
      'page height settles immediately with ${reduced ? 'reduced motion' : 'animations disabled'}',
      (tester) async {
        await initialize(tester);
        await mountAgentUi(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: !reduced),
              child: SkedMotionPolicyScope(
                disableAnimations: !reduced,
                reduceMotion: reduced,
                child: view(),
              ),
            ),
          ),
        );
        await open(tester);
        await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
        await tester.pump();
        final immediate = tester.getSize(
          find.byKey(const ValueKey('agent-model-content-transition')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(
            find.byKey(const ValueKey('agent-model-content-transition')),
          ),
          immediate,
        );
        expect(find.byType(Slider).hitTestable(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reset uses this model default and old reset callbacks expire', (
    tester,
  ) async {
    await initialize(
      tester,
      selection: const AgentModelSelection(
        modelId: 'model-a',
        reasoningEffort: AgentReasoningEffort.high,
      ),
    );
    await mountAgentUi(tester, view());
    await open(tester);
    final reset = find.byKey(const ValueKey('agent-effort-reset'));
    final previous = tester.widget<IconButton>(reset).onPressed!;
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(delegate.choices, [modelA.defaultSelection]);
    expect(repository.selected!.modelSelection, modelA.defaultSelection);
    expect(tester.widget<IconButton>(reset).onPressed, isNull);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1);
    await tester.pump();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(delegate.choices, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    previous();
    await tester.pumpAndSettle();
    expect(delegate.choices, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a previous model reset cannot change a newly selected model', (
    tester,
  ) async {
    await initialize(
      tester,
      selection: const AgentModelSelection(
        modelId: 'model-a',
        reasoningEffort: AgentReasoningEffort.high,
      ),
    );
    await mountAgentUi(tester, view());
    await open(tester);
    final previous = tester
        .widget<IconButton>(find.byKey(const ValueKey('agent-effort-reset')))
        .onPressed!;
    await chooseB(tester);
    previous();
    await tester.pumpAndSettle();
    expect(delegate.choices, [modelB.defaultSelection]);
    expect(repository.selected!.modelSelection, modelB.defaultSelection);
  });

  testWidgets(
    'compact trigger retains the full choice and opens the existing effort menu',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await initialize(tester, models: const [modelA]);
        await mountAgentUi(
          tester,
          Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: 120, child: view()),
          ),
          size: const Size(320, 740),
          scale: 2,
        );
        final trigger = find.byKey(const ValueKey('agent-model-picker'));
        expect(tester.getSize(trigger).width, lessThanOrEqualTo(120));
        expect(tester.getSize(trigger).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(trigger).height, greaterThanOrEqualTo(48));
        expect(trigger.hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-model-effort-label')),
          findsNothing,
        );
        final tooltip = tester.widget<Tooltip>(
          find.descendant(
            of: find.byType(AgentModelPicker),
            matching: find.byType(Tooltip),
          ),
        );
        expect(tooltip.message, 'model-a · Low');
        expect(find.bySemanticsLabel(RegExp('model-a.*Low')), findsWidgets);
        await open(tester);
        expect(find.text('Low'), findsWidgets);
        final slider = tester.widget<Slider>(find.byType(Slider));
        expect(slider.divisions, 1);
        slider.onChanged!(1);
        slider.onChangeEnd!(1);
        await tester.pumpAndSettle();
        await delegate.selectionWrite;
        expect(
          delegate.choices.single.reasoningEffort,
          AgentReasoningEffort.high,
        );
        expect(delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'one combined entry switches model for next run without sending',
    (tester) async {
      await initialize(tester, running: true);
      await mountAgentUi(tester, view());
      expect(find.byKey(const ValueKey('agent-effort-picker')), findsNothing);
      await open(tester);
      await chooseB(tester);
      await delegate.selectionWrite;
      expect(delegate.choices.single, modelB.defaultSelection);
      expect(repository.selected!.modelSelection, modelB.defaultSelection);
      expect(delegate.state.value.runFor(id).modelSelection, low);
      expect(delegate.calls, isEmpty);
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removed model requires an explicit enabled model choice on narrow 2x screen',
    (tester) async {
      await initialize(
        tester,
        models: const [modelA],
        selection: const AgentModelSelection(
          modelId: 'removed-model',
          reasoningEffort: AgentReasoningEffort.medium,
        ),
      );
      await mountAgentUi(tester, view(), size: const Size(320, 900), scale: 2);
      expect(delegate.choices, isEmpty);
      expect(agentConversationModelReady(delegate.state.value, id), isFalse);
      await open(tester);
      await tester.tap(
        find.byKey(const ValueKey('agent-model-choice-model-a')),
      );
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(delegate.choices.single, low);
      expect(agentConversationModelReady(delegate.state.value, id), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slider sorts configured stops and previews before one persisted release',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      await mountAgentUi(tester, view());
      await open(tester);
      var slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, 1);
      expect(slider.semanticFormatterCallback!(0), 'Low');
      expect(slider.semanticFormatterCallback!(1), 'High');
      slider.onChanged!(1);
      await tester.pump();
      expect(delegate.choices, isEmpty);
      expect(find.text('High'), findsWidgets);
      slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(
        delegate.choices.single.reasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(delegate.calls, isEmpty);
    },
  );

  testWidgets('slider keyboard step persists the same explicit choice', (
    tester,
  ) async {
    await initialize(tester, models: const [modelA]);
    await mountAgentUi(tester, view());
    await open(tester);
    tester.widget<Slider>(find.byType(Slider)).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(delegate.choices, isNotEmpty);
    expect(delegate.choices.last.reasoningEffort, AgentReasoningEffort.high);
    expect(delegate.calls, isEmpty);
  });

  testWidgets(
    'slider accessibility increment persists the named configured stop',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await initialize(tester, models: const [modelA]);
        await mountAgentUi(tester, view());
        await open(tester);
        final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
        final sliders = <SemanticsNode>[];
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          // The field label and slider export one merged accessible control.
          if (!node.isMergedIntoParent &&
              data.value == 'Low' &&
              data.hasAction(SemanticsAction.increase)) {
            sliders.add(node);
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(owner.rootSemanticsNode!);
        expect(sliders, hasLength(1));
        owner.performAction(sliders.single.id, SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(
          delegate.choices.single.reasoningEffort,
          AgentReasoningEffort.high,
        );
        expect(delegate.calls, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'menu focus can hide the IME across native frames without cancelling selection',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      try {
        await mountAgentUi(
          tester,
          Column(
            children: [
              const TextField(key: ValueKey('model-test-composer')),
              view(),
            ],
          ),
          size: const Size(390, 844),
        );
        await tester.showKeyboard(
          find.byKey(const ValueKey('model-test-composer')),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);
        await open(tester);
        expect(tester.testTextInput.isVisible, isFalse);
        for (final bottom in [240.0, 120.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: bottom);
          await tester.pumpAndSettle();
          expect(find.byType(Slider), findsOneWidget);
          expect(delegate.choices, isEmpty);
        }
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged!(1);
        slider.onChangeEnd!(1);
        await tester.pumpAndSettle();
        await delegate.selectionWrite;
        expect(
          delegate.choices.single.reasoningEffort,
          AgentReasoningEffort.high,
        );
        expect(
          repository.selected!.modelSelection?.reasoningEffort,
          AgentReasoningEffort.high,
        );
        expect(delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final nested in [false, true]) {
    for (final dismiss in ['back', 'escape', 'outside']) {
      for (final animations in [true, false]) {
        testWidgets(
          '$dismiss discards the model preview and releases its ${nested ? 'nested' : 'root'} route with animations=$animations',
          (tester) async {
            await initialize(tester, models: const [modelA]);
            try {
              await mountAgentUi(
                tester,
                nested
                    ? Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (_) => const Text('Nested workspace'),
                        ),
                      )
                    : const Text('Original workspace'),
              );
              final navigator = tester.state<NavigatorState>(
                find.byType(Navigator).last,
              );
              navigator.push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: !animations),
                      child: view(),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              await open(tester);
              final previousSlider = tester.widget<Slider>(find.byType(Slider));
              previousSlider.onChanged!(1);
              await tester.pump();
              expect(delegate.choices, isEmpty);
              switch (dismiss) {
                case 'back':
                  if (nested) {
                    await navigator.maybePop();
                  } else {
                    await tester.binding.handlePopRoute();
                  }
                case 'escape':
                  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                case 'outside':
                  await tester.tapAt(const Offset(12, 790));
              }
              // A gesture release queued after dismissal must already be invalid,
              // including while the menu's close animation still runs.
              previousSlider.onChangeEnd!(1);
              await tester.pumpAndSettle();
              expect(find.byType(AgentModelPicker), findsOneWidget);
              expect(find.byType(Slider), findsNothing);
              expect(delegate.choices, isEmpty);
              expect(delegate.state.value.selectionFor(id), low);
              expect(
                tester
                    .widget<Text>(
                      find.byKey(const ValueKey('agent-model-effort-label')),
                    )
                    .data,
                'Low',
              );
              await navigator.maybePop();
              await tester.pumpAndSettle();
              expect(find.byType(AgentModelPicker), findsNothing);
              expect(navigator.canPop(), isFalse);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }

  testWidgets(
    'ancestor scroll closes the menu before a late slider release can save',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      try {
        await mountAgentUi(
          tester,
          SingleChildScrollView(
            child: Column(children: [view(), const SizedBox(height: 1200)]),
          ),
        );
        await open(tester);
        final previousSlider = tester.widget<Slider>(find.byType(Slider));
        previousSlider.onChanged!(1);
        await tester.pump();
        final scroll = tester.state<ScrollableState>(
          find.ancestor(
            of: find.byType(AgentModelPicker),
            matching: find.byType(Scrollable),
          ),
        );
        final scrolling = scroll.position.animateTo(
          80,
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        );
        previousSlider.onChangeEnd!(1);
        await tester.pumpAndSettle();
        await scrolling;
        expect(find.byType(Slider), findsNothing);
        expect(delegate.choices, isEmpty);
        expect(delegate.state.value.selectionFor(id), low);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  for (final change in ['keyboard', 'window', 'density', 'padding']) {
    testWidgets(
      'new $change geometry cancels the menu and rejects a pending release',
      (tester) async {
        await initialize(tester, models: const [modelA]);
        try {
          await mountAgentUi(tester, view());
          await open(tester);
          final route = ModalRoute.of(
            tester.element(find.byType(AgentModelPicker)),
          )!;
          final previousSlider = tester.widget<Slider>(find.byType(Slider));
          previousSlider.onChanged!(1);
          await tester.pump();
          switch (change) {
            case 'keyboard':
              tester.view.viewInsets = const FakeViewPadding(bottom: 240);
            case 'window':
              tester.view.physicalSize = const Size(480, 820);
            case 'density':
              tester.view.devicePixelRatio = 2;
            case 'padding':
              tester.view.viewPadding = const FakeViewPadding(left: 24);
          }
          previousSlider.onChangeEnd!(1);
          await tester.pumpAndSettle();
          expect(find.byType(Slider), findsNothing);
          expect(delegate.choices, isEmpty);
          expect(delegate.state.value.selectionFor(id), low);
          expect(route.willHandlePopInternally, isFalse);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'covering the host cancels its menu without closing the newer route',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      try {
        await mountAgentUi(tester, view());
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        await open(tester);
        final previousSlider = tester.widget<Slider>(find.byType(Slider));
        previousSlider.onChanged!(1);
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covering task')),
          ),
        );
        await tester.pumpAndSettle();
        previousSlider.onChangeEnd!(1);
        await tester.pumpAndSettle();
        expect(find.text('Covering task'), findsOneWidget);
        expect(delegate.choices, isEmpty);
        await navigator.maybePop();
        await tester.pumpAndSettle();
        expect(find.byType(AgentModelPicker), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
        expect(navigator.canPop(), isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('removing an open picker releases its route history', (
    tester,
  ) async {
    await initialize(tester, models: const [modelA]);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    try {
      await mountAgentUi(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, show, _) => show ? view() : const Text('Picker removed'),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await open(tester);
      final previousSlider = tester.widget<Slider>(find.byType(Slider));
      expect(navigator.canPop(), isTrue);
      visible.value = false;
      await tester.pumpAndSettle();
      previousSlider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(find.text('Picker removed'), findsOneWidget);
      expect(navigator.canPop(), isFalse);
      expect(delegate.choices, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'late failed save cannot publish an error to the next conversation',
    (tester) async {
      await initialize(tester);
      delegate.gate = Completer<void>();
      delegate.fail = true;
      await mountAgentUi(tester, view());
      await open(tester);
      await chooseB(tester);
      id = (await repository.create(title: 'Next conversation')).id;
      await mountAgentUi(tester, view());
      delegate.gate!.complete();
      await tester.pumpAndSettle();
      expect(delegate.state.value.selectionFor(id), low);
      expect(find.textContaining('Could not save or complete'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending save keeps its preview and rejects a second release', (
    tester,
  ) async {
    await initialize(tester);
    delegate.gate = Completer<void>();
    addTearDown(() {
      if (!delegate.gate!.isCompleted) delegate.gate!.complete();
    });
    await mountAgentUi(tester, view());
    await open(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1);
    slider.onChangeEnd!(1);
    await tester.pumpAndSettle();
    final pending = tester.widget<Slider>(find.byType(Slider));
    expect(pending.value, 1);
    expect(pending.onChanged, isNull);
    expect(pending.onChangeEnd, isNull);
    slider.onChangeEnd!(0);
    expect(delegate.choices, hasLength(1));
    delegate.gate!.complete();
    await tester.pumpAndSettle();
    final saved = tester.widget<Slider>(find.byType(Slider));
    expect(saved.value, 1);
    expect(saved.onChanged, isNotNull);
    expect(
      repository.selected!.modelSelection!.reasoningEffort,
      AgentReasoningEffort.high,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save returns slider to saved value and reports failure', (
    tester,
  ) async {
    await initialize(tester, models: const [modelA]);
    delegate.fail = true;
    await mountAgentUi(tester, view());
    await open(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1);
    slider.onChangeEnd!(1);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(delegate.state.value.selectionFor(id), low);
    expect(find.textContaining('Could not save or complete'), findsWidgets);
    expect(find.textContaining('private error'), findsNothing);
  });

  testWidgets(
    'catalog change closes popup and rejects its stale slider callback',
    (tester) async {
      await initialize(tester);
      await mountAgentUi(tester, view());
      await open(tester);
      final slider = tester.widget<Slider>(find.byType(Slider));
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [modelB],
        defaultModelSelection: modelB.defaultSelection,
      );
      await tester.pumpAndSettle();
      slider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(find.byType(Slider), findsNothing);
    },
  );

  testWidgets(
    'a single remaining effort can explicitly repair an invalid selection',
    (tester) async {
      await initialize(
        tester,
        models: const [
          AgentModelConfig(
            id: 'model-a',
            reasoningEfforts: [AgentReasoningEffort.high],
            defaultReasoningEffort: AgentReasoningEffort.high,
          ),
        ],
      );
      await mountAgentUi(tester, view());
      await open(tester);
      expect(delegate.choices, isEmpty);
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-effort-choice-high')));
      await tester.pumpAndSettle();
      expect(
        delegate.choices.single.reasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(agentConversationModelReady(delegate.state.value, id), isTrue);
    },
  );

  testWidgets(
    'closing a drag preview restores the saved trigger without writing',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      await mountAgentUi(tester, view());
      await open(tester);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(find.byType(Slider), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('agent-model-effort-label')),
            )
            .data,
        'Low',
      );
    },
  );
  testWidgets(
    'reopening rejects the previous slider preview and release callbacks',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      await mountAgentUi(tester, view());
      await open(tester);
      final previousSlider = tester.widget<Slider>(find.byType(Slider));
      previousSlider.onChanged!(1);
      await tester.pump();
      expect(delegate.choices, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await open(tester);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      previousSlider.onChanged!(1);
      previousSlider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(delegate.state.value.selectionFor(id), low);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      expect(delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopening rejects the previous model choice callback', (
    tester,
  ) async {
    await initialize(tester);
    await mountAgentUi(tester, view());
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    final previousChoice = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('agent-model-choice-model-b')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    previousChoice.onPressed!();
    await tester.pumpAndSettle();
    expect(delegate.choices, isEmpty);
    expect(delegate.state.value.selectionFor(id), low);
    expect(
      find.byKey(const ValueKey('agent-model-choice-model-b')),
      findsOneWidget,
    );
    expect(delegate.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'choosing the same sole valid effort can repair an invalid queued selection',
    (tester) async {
      await initialize(
        tester,
        models: const [modelB],
        selection: modelB.defaultSelection,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [modelB],
        defaultModelSelection: modelB.defaultSelection,
        runs: {id: const AgentUiRunState(requiresModelSelection: true)},
      );
      await mountAgentUi(tester, view());
      await open(tester);
      await tester.tap(
        find.byKey(const ValueKey('agent-effort-choice-medium')),
      );
      await tester.pumpAndSettle();
      expect(delegate.choices.single, modelB.defaultSelection);
      expect(delegate.calls, isEmpty);
    },
  );
}
