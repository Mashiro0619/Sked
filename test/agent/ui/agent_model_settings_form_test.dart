import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_model_settings_form.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/agent/connection/agent_connection_diagnostics.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  const configured = AgentSettings(
    enabled: true,
    endpoint: 'https://example.test/v1',
    model: 'test-model',
    models: [
      AgentModelConfig(
        id: 'test-model',
        reasoningEfforts: [AgentReasoningEffort.medium],
        defaultReasoningEffort: AgentReasoningEffort.medium,
      ),
    ],
    credentialRef: 'opaque-local-reference',
  );

  testWidgets(
    'new model requires selected efforts and an explicit default before saving',
    (tester) async {
      addTearDown(tester.view.reset);
      var saves = 0;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: const AgentSettings(endpoint: 'https://example.test/v1'),
          suggestedModelId: 'legacy-model-candidate',
          onSave: (_) async => saves++,
        ),
      );
      final manual = find.byKey(const ValueKey('agent-model'));
      expect(tester.widget<TextFormField>(manual).controller!.text, isEmpty);
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-suggested-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-suggested-model')));
      await tester.pumpAndSettle();
      Future<void> save() async {
        await tester.ensureVisible(
          find.byKey(const ValueKey('agent-save-model')),
        );
        await tester.tap(find.byKey(const ValueKey('agent-save-model')));
        await tester.pumpAndSettle();
      }

      await save();
      expect(saves, 0);
      final options = find.byKey(
        const ValueKey('agent-model-options-legacy-model-candidate'),
      );
      await tester.ensureVisible(options);
      await tester.tap(options);
      await tester.pumpAndSettle();
      final high = find.byKey(
        const ValueKey('agent-model-effort-legacy-model-candidate-high'),
      );
      await tester.ensureVisible(high);
      await tester.tap(high);
      await tester.pumpAndSettle();
      await save();
      expect(saves, 0);
      final effort = find.byKey(
        const ValueKey('agent-default-effort-legacy-model-candidate'),
      );
      await tester.ensureVisible(effort);
      await tester.tap(effort);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'High'));
      await tester.pumpAndSettle();
      await save();
      expect(saves, 1);
      expect(find.text('Automatic'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy model candidate does not silently join a connection-only save',
    (tester) async {
      addTearDown(tester.view.reset);
      AgentModelSettingsChange? saved;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: const AgentSettings(endpoint: 'https://example.test/v1'),
          suggestedModelId: 'legacy-candidate',
          onSave: (change) async => saved = change,
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-save-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saved!.settings.models, isEmpty);
      expect(saved!.settings.model, isEmpty);
    },
  );

  testWidgets(
    'manual diagnostics show the saved HTTP plaintext disclosure before sending',
    (tester) async {
      addTearDown(tester.view.reset);
      var requests = 0;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: configured.copyWith(endpoint: 'http://trusted.example/v1'),
          onSave: (_) async {},
          onProbe: (_) async {
            requests++;
            return const AgentConnectionProbeResult(toolCallingObserved: true);
          },
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentModelSettingsForm)),
      );
      expect(find.text(l.agentHttpTransportWarning), findsOneWidget);
      expect(find.text(l.agentApiDataNotice), findsOneWidget);
      expect(requests, 0);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-endpoint')));
      await tester.enterText(
        find.byKey(const ValueKey('agent-endpoint')),
        'https://unsaved.example/v1',
      );
      expect(find.text(l.agentHttpTransportWarning), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-probe-connection')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-probe-connection')));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text(l.agentToolsObserved), findsOneWidget);
    },
  );

  testWidgets(
    'saved diagnostics provide independently selected model choices without replacing the default',
    (tester) async {
      addTearDown(tester.view.reset);
      var probes = 0;
      AgentModelSettingsChange? saved;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: configured,
          onSave: (change) async => saved = change,
          onProbe: (_) async {
            probes++;
            return const AgentConnectionProbeResult(toolCallingObserved: false);
          },
          onListModels: (_) async => AgentModelCatalog(
            models: ['model-one', 'model-two'],
            complete: false,
          ),
        ),
        size: const Size(390, 844),
        scale: 2,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('agent-endpoint')));
      await tester.enterText(
        find.byKey(const ValueKey('agent-endpoint')),
        'https://unsaved.example/v1',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-probe-connection')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-probe-connection')));
      await tester.pumpAndSettle();
      expect(probes, 1);
      expect(
        find.textContaining(
          'Diagnostics use the saved connection: https://example.test/v1',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Connected, but tool calling was not verified'),
        findsOneWidget,
      );
      expect(find.text('Valid tool call received'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-load-models')));
      await tester.pumpAndSettle();
      expect(
        find.text('The service returned a partial model list.'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-model-catalog')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-catalog-model-model-two')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-catalog-model-model-two')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-catalog-model-model-one')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-catalog-model-model-one')),
      );
      await tester.pumpAndSettle();
      for (final model in ['model-two', 'model-one']) {
        final options = find.byKey(ValueKey('agent-model-options-$model'));
        await tester.ensureVisible(options);
        await tester.tap(options);
        await tester.pumpAndSettle();
        final high = find.byKey(ValueKey('agent-model-effort-$model-high'));
        await tester.ensureVisible(high);
        await tester.tap(high);
        await tester.pumpAndSettle();
        final effort = find.byKey(ValueKey('agent-default-effort-$model'));
        await tester.ensureVisible(effort);
        await tester.tap(effort);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MenuItemButton, 'High'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-save-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saved!.settings.model, 'test-model');
      expect(saved!.settings.availableModels.map((model) => model.id), [
        'test-model',
        'model-two',
        'model-one',
      ]);
      expect(saved!.settings.endpoint, 'https://unsaved.example/v1');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configuration changes and page removal cancel diagnostic requests and discard old results',
    (tester) async {
      addTearDown(tester.view.reset);
      final settings = ValueNotifier(configured);
      addTearDown(settings.dispose);
      var completion = Completer<AgentConnectionProbeResult>();
      ProviderCancellationToken? cancellation;
      await mountAgentUi(
        tester,
        ValueListenableBuilder<AgentSettings>(
          valueListenable: settings,
          builder: (context, value, _) => AgentModelSettingsForm(
            settings: value,
            onSave: (_) async {},
            onProbe: (token) {
              cancellation = token;
              return completion.future;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('agent-probe-connection')));
      await tester.pump();
      expect(cancellation!.isCancelled, isFalse);
      settings.value = configured.copyWith(
        endpoint: 'https://changed.example/v1',
      );
      await tester.pump();
      expect(cancellation!.isCancelled, isTrue);
      completion.complete(
        const AgentConnectionProbeResult(toolCallingObserved: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Valid tool call received'), findsNothing);
      completion = Completer<AgentConnectionProbeResult>();
      await tester.tap(find.byKey(const ValueKey('agent-probe-connection')));
      await tester.pumpWidget(const SizedBox());
      expect(cancellation!.isCancelled, isTrue);
      completion.complete(
        const AgentConnectionProbeResult(toolCallingObserved: true),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'manual models save independently chosen thinking levels and defaults',
    (tester) async {
      addTearDown(tester.view.reset);
      AgentModelSettingsChange? saved;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: configured,
          onSave: (change) async => saved = change,
        ),
      );
      final manual = find.byKey(const ValueKey('agent-model'));
      await tester.ensureVisible(manual);
      await tester.enterText(manual, 'manual-model');
      await tester.ensureVisible(find.byKey(const ValueKey('agent-add-model')));
      await tester.tap(find.byKey(const ValueKey('agent-add-model')));
      await tester.pumpAndSettle();
      final defaultModel = find.byKey(
        const ValueKey('agent-default-model-test-model'),
      );
      await tester.ensureVisible(defaultModel);
      await tester.tap(defaultModel);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'manual-model'));
      await tester.pumpAndSettle();
      final options = find.byKey(
        const ValueKey('agent-model-options-manual-model'),
      );
      await tester.ensureVisible(options);
      await tester.tap(options);
      await tester.pumpAndSettle();
      final high = find.byKey(
        const ValueKey('agent-model-effort-manual-model-high'),
      );
      await tester.ensureVisible(high);
      await tester.tap(high);
      await tester.pumpAndSettle();
      final defaultEffort = find.byKey(
        const ValueKey('agent-default-effort-manual-model'),
      );
      await tester.ensureVisible(defaultEffort);
      await tester.tap(defaultEffort);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'High'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-save-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saved!.settings.model, 'manual-model');
      expect(
        saved!.settings.defaultModelSelection,
        const AgentModelSelection(
          modelId: 'manual-model',
          reasoningEffort: AgentReasoningEffort.high,
        ),
      );
      expect(saved!.settings.modelConfig('test-model')!.reasoningEfforts, [
        AgentReasoningEffort.medium,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'key replacement is transient, settings retain only their opaque reference',
    (tester) async {
      addTearDown(tester.view.reset);
      AgentModelSettingsChange? saved;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: configured,
          onSave: (change) async => saved = change,
        ),
      );
      final keyFinder = find.byKey(const ValueKey('agent-api-key'));
      await tester.ensureVisible(keyFinder);
      await tester.enterText(keyFinder, 'test-only-secret');
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: keyFinder, matching: find.byType(TextField)),
            )
            .obscureText,
        isTrue,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-save-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saved!.credentialAction, AgentCredentialAction.replace);
      expect(saved!.apiKey, 'test-only-secret');
      expect(saved!.settings.credentialRef, configured.credentialRef);
      expect(
        saved!.settings.toJson().toString(),
        isNot(contains('test-only-secret')),
      );
      expect(tester.widget<TextFormField>(keyFinder).controller!.text, isEmpty);
    },
  );

  testWidgets(
    'blank keeps credentials and removal is an explicit host action',
    (tester) async {
      addTearDown(tester.view.reset);
      final saves = <AgentModelSettingsChange>[];
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: configured,
          onSave: (change) async => saves.add(change),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-save-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saves.single.credentialAction, AgentCredentialAction.keep);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-clear-key')));
      await tester.tap(find.byKey(const ValueKey('agent-clear-key')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saves.last.credentialAction, AgentCredentialAction.clear);
      expect(saves.last.apiKey, isNull);
    },
  );

  testWidgets('failure never echoes secrets and key is cleared on disposal', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mountAgentUi(
      tester,
      AgentModelSettingsForm(
        settings: configured,
        onSave: (_) async {
          throw StateError('test-only-secret');
        },
      ),
    );
    final keyFinder = find.byKey(const ValueKey('agent-api-key'));
    await tester.enterText(keyFinder, 'test-only-secret');
    final controller = tester.widget<TextFormField>(keyFinder).controller!;
    await tester.ensureVisible(find.byKey(const ValueKey('agent-save-model')));
    await tester.tap(find.byKey(const ValueKey('agent-save-model')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not save the connection'),
      findsOneWidget,
    );
    expect(controller.text, 'test-only-secret');
    expect(find.textContaining('StateError'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(controller.text, isEmpty);
  });

  testWidgets(
    'invalid configuration is not submitted at 2x text on a narrow phone',
    (tester) async {
      addTearDown(tester.view.reset);
      var saves = 0;
      await mountAgentUi(
        tester,
        AgentModelSettingsForm(
          settings: const AgentSettings(),
          onSave: (_) async => saves++,
        ),
        size: const Size(320, 700),
        scale: 2,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-save-model')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-save-model')));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.textContaining('valid HTTP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
