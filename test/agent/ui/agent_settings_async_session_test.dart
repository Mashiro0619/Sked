import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_connection_diagnostics.dart';
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/agent_connection_settings_page.dart';
import 'package:sked/screens/agent_model_settings_page.dart';
import 'package:sked/widgets/settings_list.dart';

import '../../support/workspace_harness.dart';

const _model = AgentModelConfig(
  id: 'async-model',
  reasoningEfforts: [AgentReasoningEffort.medium],
  defaultReasoningEffort: AgentReasoningEffort.medium,
);
const _settings = AgentSettings(
  endpoint: 'https://async.example.invalid/v1',
  model: 'async-model',
  models: [_model],
);

void main() {
  Finder key(String value) => find.byKey(ValueKey(value));

  Future<_Fixture> mount(WidgetTester tester, {bool? pageEditor}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1100);
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(_Fixture.create))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.knowledge.releaseAll();
      fixture.diagnostics.releaseAll();
      await _pumpAsyncFrame(tester);
      await tester.runAsync(fixture.app.agent.quiesce);
      fixture.knowledge.dispose();
      fixture.diagnostics.dispose();
      fixture.app.dispose();
    });
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: fixture.app,
        agentApplication: fixture.diagnostics,
        home: pageEditor == null
            ? const AgentConnectionSettingsPage()
            : Scaffold(
                body: AgentKnowledgeView(
                  service: fixture.knowledge,
                  kind: KnowledgeKind.memory,
                  pageEditor: pageEditor,
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<void> coverAndReturn(WidgetTester tester, Finder source) async {
    final navigator = Navigator.of(tester.element(source));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Independent route')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Independent route').hitTestable(), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(source.hitTestable(), findsOneWidget);
  }

  for (final pageEditor in [true, false]) {
    for (final oldFails in [false, true]) {
      testWidgets(
        'a ${oldFails ? 'failed' : 'completed'} knowledge read cannot revive after returning to a ${pageEditor ? 'page' : 'dialog'} source',
        (tester) async {
          final fixture = await mount(tester, pageEditor: pageEditor);
          final item = key('knowledge-item-${fixture.record.key}');
          await _tap(tester, item, settle: false);
          await _pumpUntil(tester, () => fixture.knowledge.reads.length == 1);
          await coverAndReturn(tester, find.byType(AgentKnowledgeView));
          await _tap(tester, item, settle: false);
          await _pumpUntil(tester, () => fixture.knowledge.reads.length == 2);
          final first = fixture.knowledge.reads.first;
          if (oldFails) {
            first.result.completeError(
              StateError('private obsolete read failure'),
            );
          } else {
            first.succeed();
          }
          await _pumpAsyncFrame(tester);
          final l = AppLocalizations.of(tester.element(item));
          expect(find.byType(AgentKnowledgeEditor), findsNothing);
          expect(find.text(l.agentKnowledgeStorageFailed), findsNothing);
          expect(
            tester.widget<FilledButton>(key('knowledge-add-memory')).onPressed,
            isNull,
            reason: 'the newer read still owns opening',
          );
          fixture.knowledge.reads.last.succeed();
          await _pumpUntil(
            tester,
            () => find.byType(AgentKnowledgeEditor).evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextFormField>(key('knowledge-body'))
                .controller!
                .text,
            fixture.record.body,
          );
          await tester.enterText(
            key('knowledge-body'),
            'Accepted current memory body',
          );
          await _tap(tester, key('knowledge-save'), settle: false);
          await _pumpUntil(
            tester,
            () => find.byType(AgentKnowledgeEditor).evaluate().isEmpty,
          );
          await tester.pumpAndSettle();
          expect(
            fixture.app.agent.knowledgeRepository.records.single.body,
            'Accepted current memory body',
          );
          expect(find.text(l.agentKnowledgeSaved), findsOneWidget);
          expect(
            tester.widget<FilledButton>(key('knowledge-add-memory')).onPressed,
            isNotNull,
            reason: 'its own editor return finishes normally',
          );
          expect(find.textContaining('private obsolete'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a saved memory Undo callback expires after a covered source returns',
    (tester) async {
      final fixture = await mount(tester, pageEditor: true);
      await _tap(tester, key('knowledge-add-memory'));
      await tester.enterText(key('knowledge-title'), 'Saved extra memory');
      await tester.enterText(key('knowledge-body'), 'Accepted body');
      await _tap(tester, key('knowledge-save'), settle: false);
      await _pumpUntil(
        tester,
        () => find.byType(AgentKnowledgeEditor).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      final oldUndo = tester
          .widget<SnackBar>(find.byType(SnackBar))
          .action!
          .onPressed;
      await coverAndReturn(tester, find.byType(AgentKnowledgeView));
      oldUndo();
      await _pumpAsyncFrame(tester);
      expect(fixture.knowledge.undoCalls, isEmpty);
      expect(fixture.app.agent.knowledgeRepository.records, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an accepted memory undo keeps its persistence when the source is covered',
    (tester) async {
      final fixture = await mount(tester, pageEditor: true);
      await _tap(tester, key('knowledge-add-memory'));
      await tester.enterText(key('knowledge-title'), 'Undo accepted memory');
      await tester.enterText(key('knowledge-body'), 'Accepted body');
      await _tap(tester, key('knowledge-save'), settle: false);
      await _pumpUntil(
        tester,
        () => find.byType(AgentKnowledgeEditor).evaluate().isEmpty,
      );
      await tester.pumpAndSettle();
      fixture.knowledge.pauseUndo = true;
      await _tap(tester, find.byType(SnackBarAction), settle: false);
      await _pumpUntil(tester, () => fixture.knowledge.undoCalls.length == 1);
      await coverAndReturn(tester, find.byType(AgentKnowledgeView));
      fixture.knowledge.resumeUndo.complete();
      await _pumpUntil(
        tester,
        () => fixture.app.agent.knowledgeRepository.records.length == 1,
      );
      await tester.pumpAndSettle();
      expect(
        fixture.app.agent.knowledgeRepository.records.single.id,
        fixture.record.id,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final newModel in [false, true]) {
    for (final settingsChange in [false, true]) {
      testWidgets(
        'an old ${newModel ? 'new-model' : 'configured-model'} opener expires after ${settingsChange ? 'a committed settings change' : 'source reentry'}',
        (tester) async {
          final fixture = await mount(tester);
          const draftEndpoint = 'https://unsaved.example.invalid/v1';
          await tester.enterText(key('agent-endpoint'), draftEndpoint);
          final entry = newModel
              ? key('agent-add-model')
              : key('agent-configured-model-${_model.id}');
          await tester.ensureVisible(entry);
          await tester.pumpAndSettle();
          final oldAction = tester.widget<SettingsConnectedTile>(entry).onTap!;
          if (settingsChange) {
            await tester.runAsync(
              () => fixture.app.agent.configure(
                fixture.app.agent.settings.copyWith(
                  models: [
                    AgentModelConfig(
                      id: _model.id,
                      reasoningEfforts: const [AgentReasoningEffort.high],
                      defaultReasoningEffort: AgentReasoningEffort.high,
                    ),
                  ],
                ),
              ),
            );
            await _pumpAsyncFrame(tester);
          } else {
            await coverAndReturn(
              tester,
              find.byType(AgentConnectionSettingsPage),
            );
          }
          oldAction();
          await _pumpAsyncFrame(tester);
          expect(find.byType(AgentModelSettingsPage), findsNothing);
          await _tap(tester, entry);
          expect(find.byType(AgentModelSettingsPage), findsOneWidget);
          expect(
            tester.widget<TextFormField>(key('agent-model')).controller!.text,
            newModel ? isEmpty : _model.id,
          );
          if (!newModel) {
            final effort = settingsChange
                ? AgentReasoningEffort.high
                : AgentReasoningEffort.medium;
            expect(
              tester
                  .widget<CheckboxListTile>(
                    key('agent-model-effort-${effort.name}'),
                  )
                  .value,
              isTrue,
            );
          }
          Navigator.of(tester.element(find.byType(AgentModelSettingsPage)))
              .pop();
          await _pumpAsyncFrame(tester);
          expect(
            tester
                .widget<TextFormField>(key('agent-endpoint'))
                .controller!
                .text,
            draftEndpoint,
          );
          expect(tester.widget<SettingsConnectedTile>(entry).onTap, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final models in [false, true]) {
    final buttonKey = models ? 'agent-load-models' : 'agent-probe-connection';
    for (final oldFails in [false, true]) {
      testWidgets(
        'a ${oldFails ? 'failed' : 'completed'} ${models ? 'catalog' : 'probe'} cannot clear a newer diagnosis after source reentry',
        (tester) async {
          final fixture = await mount(tester);
          await _tap(tester, key(buttonKey), settle: false);
          await _pumpUntil(
            tester,
            () => fixture.diagnostics.requestCount(models) == 1,
          );
          final oldCancellation = fixture.diagnostics.cancellation(models, 0);
          await coverAndReturn(
            tester,
            find.byType(AgentConnectionSettingsPage),
          );
          expect(oldCancellation.isCancelled, isTrue);
          await _tap(tester, key(buttonKey), settle: false);
          await _pumpUntil(
            tester,
            () => fixture.diagnostics.requestCount(models) == 2,
          );
          fixture.diagnostics.finish(
            models,
            0,
            fail: oldFails,
            model: 'obsolete-model',
          );
          await _pumpAsyncFrame(tester);
          final l = AppLocalizations.of(tester.element(key(buttonKey)));
          expect(
            find.byKey(const ValueKey('agent-model-search')),
            findsNothing,
          );
          expect(find.text(l.agentConnectionOk), findsNothing);
          expect(find.text(l.agentRequestFailed), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
          expect(
            tester.widget<OutlinedButton>(key(buttonKey)).onPressed,
            isNull,
          );
          expect(
            fixture.diagnostics.cancellation(models, 1).isCancelled,
            isFalse,
          );
          fixture.diagnostics.finish(models, 1, model: 'current-model');
          await _pumpUntil(
            tester,
            () => models
                ? key('agent-catalog-model-current-model').evaluate().isNotEmpty
                : find.text(l.agentConnectionOk).evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('private obsolete'), findsNothing);
          expect(find.text('obsolete-model'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'current ${models ? 'catalog' : 'probe'} failures still report safely',
      (tester) async {
        final fixture = await mount(tester);
        await _tap(tester, key(buttonKey), settle: false);
        await _pumpUntil(
          tester,
          () => fixture.diagnostics.requestCount(models) == 1,
        );
        fixture.diagnostics.finish(models, 0, fail: true);
        final l = AppLocalizations.of(tester.element(key(buttonKey)));
        await _pumpUntil(
          tester,
          () => find.text(l.agentRequestFailed).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(key('agent-settings-error'), findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(key(buttonKey)).onPressed,
          isNotNull,
        );
        expect(find.textContaining('private obsolete'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'an old ${models ? 'catalog' : 'probe'} button cannot start after source reentry',
      (tester) async {
        final fixture = await mount(tester);
        await tester.ensureVisible(key(buttonKey));
        final oldAction = tester
            .widget<OutlinedButton>(key(buttonKey))
            .onPressed!;
        await coverAndReturn(tester, find.byType(AgentConnectionSettingsPage));
        oldAction();
        await _pumpAsyncFrame(tester);
        expect(fixture.diagnostics.requestCount(models), 0);
        await _tap(tester, key(buttonKey), settle: false);
        await _pumpUntil(
          tester,
          () => fixture.diagnostics.requestCount(models) == 1,
        );
        fixture.diagnostics.finish(models, 0, model: 'current-model');
        final l = AppLocalizations.of(tester.element(key(buttonKey)));
        await _pumpUntil(
          tester,
          () => models
              ? key('agent-catalog-model-current-model').evaluate().isNotEmpty
              : find.text(l.agentConnectionOk).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'starting a new ${models ? 'catalog' : 'probe'} retires the previous successful probe',
      (tester) async {
        final fixture = await mount(tester);
        final probeButton = key('agent-probe-connection');
        await _tap(tester, probeButton, settle: false);
        await _pumpUntil(tester, () => fixture.diagnostics.probes.length == 1);
        fixture.diagnostics.finish(false, 0);
        final l = AppLocalizations.of(tester.element(probeButton));
        await _pumpUntil(
          tester,
          () => find.text(l.agentConnectionOk).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await _tap(tester, key(buttonKey), settle: false);
        final index = models ? 0 : 1;
        await _pumpUntil(
          tester,
          () => fixture.diagnostics.requestCount(models) == index + 1,
        );
        expect(find.text(l.agentConnectionOk), findsNothing);
        expect(find.text(l.agentToolsObserved), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        fixture.diagnostics.finish(models, index, fail: true);
        await _pumpUntil(
          tester,
          () => find.text(l.agentRequestFailed).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(find.text(l.agentConnectionOk), findsNothing);
        expect(find.text(l.agentToolsObserved), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final coalesced in [false, true]) {
    testWidgets(
      'a successful probe expires when its settings change${coalesced ? ' and return before the next frame' : ' after a source visit'}',
      (tester) async {
        final fixture = await mount(tester);
        final button = key('agent-probe-connection');
        await _tap(tester, button, settle: false);
        await _pumpUntil(tester, () => fixture.diagnostics.probes.length == 1);
        fixture.diagnostics.finish(false, 0);
        final l = AppLocalizations.of(tester.element(button));
        await _pumpUntil(
          tester,
          () => find.text(l.agentConnectionOk).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        final original = fixture.app.agent.settings;
        final changed = original.copyWith(
          models: [
            AgentModelConfig(
              id: _model.id,
              reasoningEfforts: const [AgentReasoningEffort.high],
              defaultReasoningEffort: AgentReasoningEffort.high,
            ),
          ],
        );
        if (!coalesced) {
          await coverAndReturn(
            tester,
            find.byType(AgentConnectionSettingsPage),
          );
          expect(find.text(l.agentConnectionOk), findsOneWidget);
        }
        await tester.runAsync(() async {
          await fixture.app.agent.configure(changed);
          if (coalesced) await fixture.app.agent.configure(original);
        });
        await _pumpAsyncFrame(tester);
        expect(find.text(l.agentConnectionOk), findsNothing);
        expect(find.text(l.agentToolsObserved), findsNothing);
        if (!coalesced) {
          await tester.runAsync(() => fixture.app.agent.configure(original));
          await _pumpAsyncFrame(tester);
          expect(find.text(l.agentConnectionOk), findsNothing);
        }
        await _tap(tester, button, settle: false);
        await _pumpUntil(tester, () => fixture.diagnostics.probes.length == 2);
        fixture.diagnostics.finish(false, 1);
        await _pumpUntil(
          tester,
          () => find.text(l.agentConnectionOk).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'changed committed settings cancel a diagnosis before its late result',
    (tester) async {
      final fixture = await mount(tester);
      final button = key('agent-probe-connection');
      await _tap(tester, button, settle: false);
      await _pumpUntil(tester, () => fixture.diagnostics.probes.length == 1);
      await tester.runAsync(
        () => fixture.app.agent.configure(
          fixture.app.agent.settings.copyWith(
            models: [
              AgentModelConfig(
                id: _model.id,
                reasoningEfforts: const [AgentReasoningEffort.high],
                defaultReasoningEffort: AgentReasoningEffort.high,
              ),
            ],
          ),
        ),
      );
      await _pumpAsyncFrame(tester);
      expect(fixture.diagnostics.probes.first.cancellation.isCancelled, isTrue);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      await _tap(tester, button, settle: false);
      await _pumpUntil(tester, () => fixture.diagnostics.probes.length == 2);
      fixture.diagnostics.finish(false, 0);
      await _pumpAsyncFrame(tester);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      fixture.diagnostics.finish(false, 1);
      final l = AppLocalizations.of(tester.element(button));
      await _pumpUntil(
        tester,
        () => find.text(l.agentConnectionOk).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await _pumpAsyncFrame(tester);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await _pumpAsyncFrame(tester);
  expect(target.hitTestable(), findsOneWidget);
  await tester.runAsync(() => tester.tap(target.hitTestable()));
  if (settle) {
    await tester.pumpAndSettle();
    await _pumpAsyncFrame(tester);
    await tester.pumpAndSettle();
  } else {
    await _pumpAsyncFrame(tester);
  }
}

Future<void> _pumpAsyncFrame(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 10)) {
    await _pumpAsyncFrame(tester);
  }
  expect(ready(), isTrue, reason: 'the observed asynchronous state completes');
  // The frame satisfying the predicate can pop a route whose Future belongs
  // to the real async zone. Let its request-owned cleanup publish a fresh UI.
  await _pumpAsyncFrame(tester);
}

class _Fixture {
  _Fixture(this.app, this.knowledge, this.diagnostics, this.record);
  final AppRuntime app;
  final _HeldKnowledgeService knowledge;
  final _DiagnosticApplication diagnostics;
  final KnowledgeRecord record;

  static Future<_Fixture> create() async {
    final app = await workspaceProvider();
    await app.agent.initialize();
    await app.agent.configure(_settings);
    await app.agent.knowledge.initialize();
    final record = app.agent.knowledge.newRecord(
      KnowledgeKind.memory,
      title: 'Deferred memory',
      body: 'Original stored memory body',
    );
    await app.agent.knowledge.saveFromUi(
      app.agent.knowledge.prepareSave(record),
    );
    final knowledge = _HeldKnowledgeService(
      repository: app.agent.knowledgeRepository,
    );
    await knowledge.initialize();
    return _Fixture(app, knowledge, _DiagnosticApplication(app.agent), record);
  }
}

class _HeldRead {
  _HeldRead(this.record);
  final KnowledgeRecord record;
  final result = Completer<KnowledgeRecord>();
  void succeed() {
    if (!result.isCompleted) result.complete(record);
  }
}

class _HeldKnowledgeService extends AgentKnowledgeService {
  _HeldKnowledgeService({required super.repository});
  final reads = <_HeldRead>[];
  final undoCalls = <String>[];
  bool pauseUndo = false;
  final resumeUndo = Completer<void>();

  @override
  Future<KnowledgeRecord> read(KnowledgeKind kind, String id) async {
    final request = _HeldRead(await super.read(kind, id));
    reads.add(request);
    return request.result.future;
  }

  @override
  Future<KnowledgeReceipt> undoFromUi(String operationId) async {
    undoCalls.add(operationId);
    if (pauseUndo) await resumeUndo.future;
    return super.undoFromUi(operationId);
  }

  void releaseAll() {
    for (final request in reads) {
      request.succeed();
    }
    if (!resumeUndo.isCompleted) resumeUndo.complete();
  }
}

class _HeldDiagnostic<T> {
  _HeldDiagnostic(this.cancellation);
  final ProviderCancellationToken cancellation;
  final result = Completer<T>();
}

/// The real application still owns configuration and stores. These explicit
/// diagnostic gates deliberately finish after cancellation to verify UI
/// ownership independently of how quickly a network client can abort.
class _DiagnosticApplication extends ChangeNotifier
    implements AgentApplication {
  _DiagnosticApplication(this.application) {
    application.addListener(notifyListeners);
  }
  final AgentApplication application;
  final probes = <_HeldDiagnostic<AgentConnectionProbeResult>>[];
  final catalogs = <_HeldDiagnostic<AgentModelCatalog>>[];
  @override
  AgentSettings get settings => application.settings;
  @override
  AgentConnectionManager get connections => application.connections;
  @override
  String get suggestedModelId => application.suggestedModelId;
  @override
  Future<void> initialize() => application.initialize();
  @override
  Future<void> configure(
    AgentSettings value, {
    AgentCredentialAction credentialAction = AgentCredentialAction.keep,
    String? rawKey,
    AgentSettings? expectedSettings,
  }) => application.configure(
    value,
    credentialAction: credentialAction,
    rawKey: rawKey,
    expectedSettings: expectedSettings,
  );

  @override
  Future<AgentConnectionProbeResult> probeConnection({
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) {
    final request = _HeldDiagnostic<AgentConnectionProbeResult>(
      cancellation ?? ProviderCancellationToken(),
    );
    probes.add(request);
    return request.result.future;
  }

  @override
  Future<AgentModelCatalog> listConnectionModels({
    bool allowInsecureHttp = false,
    ProviderCancellationToken? cancellation,
  }) {
    final request = _HeldDiagnostic<AgentModelCatalog>(
      cancellation ?? ProviderCancellationToken(),
    );
    catalogs.add(request);
    return request.result.future;
  }

  int requestCount(bool models) => models ? catalogs.length : probes.length;
  ProviderCancellationToken cancellation(bool models, int index) =>
      models ? catalogs[index].cancellation : probes[index].cancellation;

  void finish(
    bool models,
    int index, {
    bool fail = false,
    String model = 'fixture-model',
  }) {
    if (models) {
      final result = catalogs[index].result;
      if (result.isCompleted) return;
      if (fail) {
        result.completeError(StateError('private obsolete diagnostic failure'));
      } else {
        result.complete(AgentModelCatalog(models: [model], complete: true));
      }
    } else {
      final result = probes[index].result;
      if (result.isCompleted) return;
      if (fail) {
        result.completeError(StateError('private obsolete diagnostic failure'));
      } else {
        result.complete(
          const AgentConnectionProbeResult(toolCallingObserved: true),
        );
      }
    }
  }

  void releaseAll() {
    for (var index = 0; index < probes.length; index++) {
      finish(false, index);
    }
    for (var index = 0; index < catalogs.length; index++) {
      finish(true, index);
    }
  }

  @override
  void dispose() {
    application.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected diagnostic fixture call ${invocation.memberName}',
  );
}
