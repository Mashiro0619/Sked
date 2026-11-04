import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_connection_settings_page.dart';
import 'package:sked/screens/agent_model_settings_page.dart';
import 'package:sked/screens/agent_preferences_settings_page.dart';
import 'package:sked/screens/agent_settings_page.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/settings_page_header.dart';

import '../../support/workspace_harness.dart';

class _SettingsStorage extends WorkspaceMemoryStorage {
  _SettingsStorage()
    : super(buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'));
  bool fail = false;
  bool pause = false;
  int writes = 0;
  final entered = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> save(AppData value) async {
    writes++;
    if (pause) {
      if (!entered.isCompleted) entered.complete();
      await resume.future;
      pause = false;
    }
    if (fail) throw StateError('Synthetic settings write failed');
    await super.save(value);
  }
}

class _DelayedKnowledgeService extends AgentKnowledgeService {
  _DelayedKnowledgeService({required super.repository});
  final readStarted = Completer<void>();
  final resumeRead = Completer<void>();

  @override
  Future<KnowledgeRecord> read(KnowledgeKind kind, String id) async {
    if (!readStarted.isCompleted) readStarted.complete();
    await resumeRead.future;
    return super.read(kind, id);
  }
}

class _FailedKnowledgeService extends AgentKnowledgeService {
  _FailedKnowledgeService({required super.repository});

  @override
  Future<void> initialize({bool reload = false}) => Future.error(
    const KnowledgeException(
      KnowledgeError.unavailable,
      'Synthetic initialization failure',
    ),
  );
}

void main() {
  late AppRuntime app;
  const model = AgentModelConfig(
    id: 'model-a',
    reasoningEfforts: [AgentReasoningEffort.low, AgentReasoningEffort.high],
    defaultReasoningEffort: AgentReasoningEffort.low,
  );
  const settings = AgentSettings(
    endpoint: 'https://settings.example.invalid/v1',
    model: 'model-a',
    models: [model],
  );
  Finder key(String value) => find.byKey(ValueKey(value));

  // Real storage saves must not wait on gates created in FakeAsync's queue.
  Future<_SettingsStorage> createStorage(WidgetTester tester) async =>
      (await tester.runAsync(() async => _SettingsStorage()))!;

  Future<void> mount(
    WidgetTester tester, {
    double width = 1200,
    double height = 900,
    double scale = 1,
    _SettingsStorage? storage,
    bool configured = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      app = await workspaceProvider(storage: storage);
      await app.agent.initialize();
      await app.agent.knowledge.initialize();
      if (configured) await app.agent.configure(settings);
    });
    addTearDown(() async {
      if (storage != null && !storage.resume.isCompleted)
        storage.resume.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(app.agent.quiesce);
      app.dispose();
    });
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: app,
        home: const AgentSettingsPage(),
        textScale: scale,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleUi(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    // Drain the focused editor's pending caret reveal before moving to a
    // button. Real route futures can also retire an old opening latch here.
    await settleUi(tester);
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await settleUi(tester);
    if (target.hitTestable().evaluate().isEmpty) {
      final scroll = find
          .ancestor(of: target, matching: find.byType(Scrollable))
          .first;
      final direction = tester.getCenter(target).dy < tester.getRect(scroll).top
          ? 180.0
          : -180.0;
      // A user scroll dismisses the focused editor's keyboard/caret tracking;
      // programmatic visibility alone does not send this drag notification.
      await tester.dragUntilVisible(
        target.hitTestable(),
        scroll,
        Offset(0, direction),
        maxIteration: 24,
      );
      await settleUi(tester);
    }
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    expect(target.hitTestable(), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(target.hitTestable());
      await app.agent.quiesce().timeout(const Duration(seconds: 10));
    });
    await settleUi(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.runAsync(tester.binding.handlePopRoute);
    await settleUi(tester);
  }

  testWidgets(
    'Agent settings use named page destinations instead of tabs',
    (tester) async {
      await mount(tester, height: 560);
      final semantics = tester.ensureSemantics();
      try {
        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(TabBarView), findsNothing);
        for (final destination in [
          ('agent-settings-connection', AgentConnectionSettingsPage),
          ('agent-settings-preferences', AgentPreferencesSettingsPage),
          ('agent-settings-skills', AgentKnowledgeView),
          ('agent-settings-memories', AgentKnowledgeView),
        ]) {
          final target = key(destination.$1);
          expect(target.hitTestable(), findsOneWidget);
          final data = tester.getSemantics(target).getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
          expect(data.label, isNotEmpty);
          await tap(tester, target);
          expect(find.byType(destination.$2).hitTestable(), findsOneWidget);
          expect(key('agent-settings-connection').hitTestable(), findsNothing);
          await back(tester);
          expect(
            key('agent-settings-connection').hitTestable(),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );

  testWidgets(
    'model save preserves the parent connection draft and returns one level',
    (tester) async {
      await mount(tester);
      await tap(tester, key('agent-settings-connection'));
      final parent = tester.state(find.byType(AgentConnectionSettingsPage));
      await tester.enterText(
        key('agent-endpoint'),
        'https://draft.example.invalid/v1',
      );
      await tester.enterText(key('agent-api-key'), 'synthetic-new-key');
      await tap(tester, key('agent-configured-model-model-a'));
      expect(find.byType(AgentModelSettingsPage), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
      final dropdown = tester.widget<SkedDropdownMenu<AgentReasoningEffort>>(
        find.byType(SkedDropdownMenu<AgentReasoningEffort>),
      );
      dropdown.onSelected!(AgentReasoningEffort.high);
      await tester.pumpAndSettle();
      await tap(tester, key('agent-save-model'));
      expect(find.byType(AgentModelSettingsPage), findsNothing);
      expect(
        tester.state(find.byType(AgentConnectionSettingsPage)),
        same(parent),
      );
      expect(
        app.agent.settings.modelConfig('model-a')!.defaultReasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(app.agent.settings.endpoint, settings.endpoint);
      expect(
        tester.widget<TextFormField>(key('agent-endpoint')).controller!.text,
        'https://draft.example.invalid/v1',
      );
      expect(
        tester.widget<TextFormField>(key('agent-api-key')).controller!.text,
        'synthetic-new-key',
      );
      await tap(tester, key('agent-save-connection'));
      expect(find.byType(AgentConnectionSettingsPage), findsNothing);
      expect(key('agent-settings-connection').hitTestable(), findsOneWidget);
      expect(app.agent.settings.endpoint, 'https://draft.example.invalid/v1');
      expect(
        app.agent.settings.modelConfig('model-a')!.defaultReasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(
        await tester.runAsync(
          () => app.agent.connections.readKeyFor(app.agent.settings),
        ),
        'synthetic-new-key',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'immediate Back after a connection edit cancels or discards without saving',
    (tester) async {
      final storage = await createStorage(tester);
      await mount(tester, storage: storage);
      final writes = storage.writes;
      await tap(tester, key('agent-settings-connection'));
      await tester.enterText(
        key('agent-endpoint'),
        'https://draft.example.invalid/v1',
      );
      await back(tester);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
      expect(find.text(l.unsavedChangesMessage), findsOneWidget);
      await tap(tester, find.widgetWithText(TextButton, l.cancel));
      expect(find.byType(AgentConnectionSettingsPage), findsOneWidget);
      expect(storage.writes, writes);
      await back(tester);
      await tap(
        tester,
        find.widgetWithText(FilledButton, l.discardChangesAndExit),
      );
      expect(find.byType(AgentConnectionSettingsPage), findsNothing);
      expect(app.agent.settings.endpoint, settings.endpoint);
      expect(storage.writes, writes);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving preferences blocks Back until the accepted save completes',
    (tester) async {
      final storage = await createStorage(tester);
      await mount(tester, storage: storage);
      await tap(tester, key('agent-settings-preferences'));
      await tester.enterText(
        key('agent-system-instructions'),
        'Synthetic preference',
      );
      await reveal(tester, key('agent-save-preferences'));
      storage.pause = true;
      await tester.runAsync(() async {
        await tester.tap(key('agent-save-preferences'));
        await storage.entered.future.timeout(const Duration(seconds: 10));
      });
      await tester.pump();
      await back(tester);
      expect(find.byType(AgentPreferencesSettingsPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.widget<FilledButton>(key('agent-save-preferences')).onPressed,
        isNull,
      );
      await tester.runAsync(() async {
        storage.resume.complete();
        await app.agent.quiesce();
      });
      await tester.pumpAndSettle();
      expect(find.byType(AgentPreferencesSettingsPage), findsNothing);
      expect(app.agent.settings.systemInstructions, 'Synthetic preference');
      expect(app.agent.settings.models, settings.models);
      expect(key('agent-settings-connection').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed settings save retains the page and secret draft', (
    tester,
  ) async {
    final storage = await createStorage(tester);
    await mount(tester, storage: storage);
    await tap(tester, key('agent-settings-connection'));
    await tester.enterText(key('agent-api-key'), 'synthetic-unsaved-key');
    storage.fail = true;
    await tap(tester, key('agent-save-connection'));
    expect(find.byType(AgentConnectionSettingsPage), findsOneWidget);
    expect(key('agent-settings-error'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(key('agent-api-key')).controller!.text,
      'synthetic-unsaved-key',
    );
    expect(app.agent.settings.credentialRef, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final section in ['preferences', 'connection', 'model', 'new-model']) {
    testWidgets(
      'a late accepted $section save completes its source and preserves the newer route',
      (tester) async {
        final storage = await createStorage(tester);
        await mount(tester, storage: storage);
        late final Type sourceType;
        late final String saveKey;
        switch (section) {
          case 'preferences':
            await tap(tester, key('agent-settings-preferences'));
            await tester.enterText(
              key('agent-system-instructions'),
              'Accepted preference',
            );
            sourceType = AgentPreferencesSettingsPage;
            saveKey = 'agent-save-preferences';
          case 'connection':
            await tap(tester, key('agent-settings-connection'));
            await tester.enterText(
              key('agent-endpoint'),
              'https://accepted.example.invalid/v1',
            );
            sourceType = AgentConnectionSettingsPage;
            saveKey = 'agent-save-connection';
          case 'model':
          case 'new-model':
            await tap(tester, key('agent-settings-connection'));
            await tester.enterText(
              key('agent-endpoint'),
              'https://parent-draft.example.invalid/v1',
            );
            if (section == 'model') {
              await tap(tester, key('agent-configured-model-model-a'));
            } else {
              await tap(tester, key('agent-add-model'));
              await tester.enterText(key('agent-model'), 'new-accepted-model');
              await tap(tester, key('agent-model-effort-high'));
            }
            final dropdown = tester
                .widget<SkedDropdownMenu<AgentReasoningEffort>>(
                  find.byType(SkedDropdownMenu<AgentReasoningEffort>),
                );
            dropdown.onSelected!(AgentReasoningEffort.high);
            sourceType = AgentModelSettingsPage;
            saveKey = 'agent-save-model';
        }
        await reveal(tester, key(saveKey));
        storage.pause = true;
        await tester.runAsync(() async {
          await tester.tap(key(saveKey));
          await storage.entered.future.timeout(const Duration(seconds: 10));
        });
        await tester.pump();
        final context = tester.element(find.byType(sourceType));
        final sourceRoute = ModalRoute.of(context)!;
        final newer = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Newer settings route')),
        );
        var newerCompleted = false;
        unawaited(
          Navigator.of(context).push<void>(newer).then((_) {
            newerCompleted = true;
          }),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          storage.resume.complete();
          await app.agent.quiesce();
        });
        await tester.pumpAndSettle();
        expect(newerCompleted, isFalse);
        expect(newer.isCurrent, isTrue);
        expect(find.text('Newer settings route').hitTestable(), findsOneWidget);
        expect(sourceRoute.isActive, isFalse);
        expect(find.byType(sourceType, skipOffstage: false), findsNothing);
        switch (section) {
          case 'preferences':
            expect(
              app.agent.settings.systemInstructions,
              'Accepted preference',
            );
          case 'connection':
            expect(
              app.agent.settings.endpoint,
              'https://accepted.example.invalid/v1',
            );
          case 'model':
          case 'new-model':
            expect(
              app.agent.settings
                  .modelConfig(
                    section == 'model' ? 'model-a' : 'new-accepted-model',
                  )!
                  .defaultReasoningEffort,
              AgentReasoningEffort.high,
            );
        }
        await back(tester);
        expect(newerCompleted, isTrue);
        expect(find.byType(sourceType, skipOffstage: false), findsNothing);
        if (section == 'preferences' || section == 'connection') {
          expect(
            key('agent-settings-connection').hitTestable(),
            findsOneWidget,
          );
        } else {
          expect(
            find.byType(AgentConnectionSettingsPage).hitTestable(),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextFormField>(key('agent-endpoint'))
                .controller!
                .text,
            'https://parent-draft.example.invalid/v1',
          );
        }
        // Opening a fresh editor after returning must use the newly committed
        // baseline; a second edit must not report an external-settings conflict.
        if (section == 'preferences') {
          await tap(tester, key('agent-settings-preferences'));
          await tester.enterText(
            key('agent-system-instructions'),
            'Second preference',
          );
          await tap(tester, key('agent-save-preferences'));
          expect(app.agent.settings.systemInstructions, 'Second preference');
        } else if (section == 'connection') {
          await tap(tester, key('agent-settings-connection'));
          await tester.enterText(
            key('agent-endpoint'),
            'https://second.example.invalid/v1',
          );
          await tap(tester, key('agent-save-connection'));
          expect(
            app.agent.settings.endpoint,
            'https://second.example.invalid/v1',
          );
        } else {
          final id = section == 'model' ? 'model-a' : 'new-accepted-model';
          await tap(tester, key('agent-configured-model-$id'));
          if (section == 'new-model') {
            await tap(tester, key('agent-model-effort-low'));
          }
          final dropdown = tester
              .widget<SkedDropdownMenu<AgentReasoningEffort>>(
                find.byType(SkedDropdownMenu<AgentReasoningEffort>),
              );
          dropdown.onSelected!(AgentReasoningEffort.low);
          await tester.pumpAndSettle();
          await tap(tester, key('agent-save-model'));
          expect(
            app.agent.settings.modelConfig(id)!.defaultReasoningEffort,
            AgentReasoningEffort.low,
          );
        }
        expect(find.byType(sourceType, skipOffstage: false), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a delayed knowledge read cannot open from a covered settings source',
    (tester) async {
      await mount(tester);
      final original = app.agent.knowledge.newRecord(
        KnowledgeKind.memory,
        title: 'Delayed memory',
        body: 'Synthetic source',
      );
      await tester.runAsync(
        () => app.agent.knowledge.saveFromUi(
          app.agent.knowledge.prepareSave(original),
        ),
      );
      final delayed = (await tester.runAsync(
        () async =>
            _DelayedKnowledgeService(repository: app.agent.knowledgeRepository),
      ))!;
      addTearDown(() {
        if (!delayed.resumeRead.isCompleted) delayed.resumeRead.complete();
        delayed.dispose();
      });
      await tester.runAsync(delayed.initialize);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          home: Scaffold(
            body: AgentKnowledgeView(
              service: delayed,
              kind: KnowledgeKind.memory,
              pageEditor: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, key('knowledge-item-${original.key}'));
      expect(delayed.readStarted.isCompleted, isTrue);
      final context = tester.element(find.byType(AgentKnowledgeView));
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Newer knowledge route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      delayed.resumeRead.complete();
      await tester.pumpAndSettle();
      expect(find.text('Newer knowledge route').hitTestable(), findsOneWidget);
      expect(find.byType(AgentKnowledgeEditor), findsNothing);
      expect(
        app.agent.knowledgeRepository.records.single.body,
        'Synthetic source',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed knowledge child page retains the mobile Back action', (
    tester,
  ) async {
    await mount(tester, width: 390, height: 740);
    final failed = _FailedKnowledgeService(
      repository: app.agent.knowledgeRepository,
    );
    addTearDown(failed.dispose);
    final context = tester.element(find.byType(AgentSettingsPage));
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SettingsPageScaffold(
            title: 'Knowledge failure',
            bodyBuilder: (_, header) => AgentKnowledgeView(
              service: failed,
              kind: KnowledgeKind.memory,
              pageEditor: true,
              headerSliver: header,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'the failed child status lays out before settling',
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentKnowledgeView)),
    );
    expect(find.text(l.agentKnowledgeUnavailable), findsOneWidget);
    await tap(tester, find.byType(BackButton).hitTestable());
    expect(find.byType(AgentKnowledgeView), findsNothing);
    expect(key('agent-settings-memories').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'external model changes invalidate the old editor instead of overwriting',
    (tester) async {
      await mount(tester);
      await tap(tester, key('agent-settings-connection'));
      await tap(tester, key('agent-configured-model-model-a'));
      final latestModel = AgentModelConfig(
        id: model.id,
        reasoningEfforts: const [AgentReasoningEffort.high],
        defaultReasoningEffort: AgentReasoningEffort.high,
      );
      await tester.runAsync(
        () => app.agent.configure(
          app.agent.settings.copyWith(models: [latestModel]),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, key('agent-save-model'));
      final l = AppLocalizations.of(
        tester.element(key('agent-settings-error')),
      );
      expect(find.text(l.agentSettingsChanged), findsOneWidget);
      expect(app.agent.settings.modelConfig(model.id), latestModel);
      expect(find.byType(AgentModelSettingsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 740), const Size(1000, 800)]) {
    testWidgets('single-model effort fields remain reachable at 2x in $size', (
      tester,
    ) async {
      await mount(
        tester,
        width: size.width,
        height: size.height,
        scale: 2,
        configured: false,
      );
      await tap(tester, key('agent-settings-connection'));
      await tap(tester, key('agent-add-model'));
      await tester.enterText(key('agent-model'), 'long-synthetic-model-name');
      await tap(tester, key('agent-save-model'));
      expect(key('agent-model-efforts-required'), findsOneWidget);
      expect(app.agent.settings.models, isEmpty);
      for (final effort in AgentReasoningEffort.values) {
        final target = key('agent-model-effort-${effort.name}');
        await reveal(tester, target);
        expect(target.hitTestable(), findsOneWidget);
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      await tap(tester, key('agent-model-effort-high'));
      final dropdown = tester.widget<SkedDropdownMenu<AgentReasoningEffort>>(
        find.byType(SkedDropdownMenu<AgentReasoningEffort>),
      );
      expect(dropdown.dropdownMenuEntries.map((entry) => entry.value), [
        AgentReasoningEffort.high,
      ]);
      dropdown.onSelected!(AgentReasoningEffort.high);
      await tester.pumpAndSettle();
      await tap(tester, key('agent-save-model'));
      expect(app.agent.settings.models.single.id, 'long-synthetic-model-name');
      expect(
        app.agent.settings.models.single.defaultReasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(find.byType(AgentModelSettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets(
    'knowledge edits are child pages and retain the list after saving',
    (tester) async {
      await mount(tester);
      await tap(tester, key('agent-settings-memories'));
      final list = find.byWidgetPredicate(
        (widget) =>
            widget is AgentKnowledgeView && widget.kind == KnowledgeKind.memory,
      );
      expect(tester.widget<AgentKnowledgeView>(list).pageEditor, isTrue);
      await tap(tester, key('knowledge-add-memory'));
      final editor = tester.widget<AgentKnowledgeEditor>(
        find.byType(AgentKnowledgeEditor),
      );
      expect(editor.pagePresentation, isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(key('knowledge-title'), 'Synthetic memory');
      await tester.enterText(key('knowledge-body'), 'Synthetic shared note');
      await tap(tester, key('knowledge-save'));
      expect(find.byType(AgentKnowledgeEditor), findsNothing);
      expect(list.hitTestable(), findsOneWidget);
      expect(find.text('Synthetic memory'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('knowledge-add-memory')).onPressed,
        isNotNull,
        reason: 'the saved editor return retired its opening latch',
      );
      final record = app.agent.knowledge.list(KnowledgeKind.memory).single;
      await tap(tester, key('knowledge-item-${record.key}'));
      expect(find.byType(AgentKnowledgeEditor).hitTestable(), findsOneWidget);
      await tester.enterText(key('knowledge-body'), 'Unsaved memory change');
      await back(tester);
      final l = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
      await tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, l.cancel),
        ),
      );
      expect(
        tester.widget<TextFormField>(key('knowledge-body')).controller!.text,
        'Unsaved memory change',
      );
      expect(
        (await tester.runAsync(
          () => app.agent.knowledge.read(record.kind, record.id),
        ))!.body,
        'Synthetic shared note',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
