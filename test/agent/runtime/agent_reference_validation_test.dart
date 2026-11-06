import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/developer_sample_data_service.dart';

import '../../support/workspace_harness.dart';

class _SaveGate {
  final entered = Completer<void>();
  final released = Completer<void>();

  void release() {
    if (!released.isCompleted) released.complete();
  }
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  _SaveGate? nextSave;

  @override
  Future<void> save(AppData value) async {
    final gate = nextSave;
    nextSave = null;
    if (gate != null) {
      gate.entered.complete();
      await gate.released.future;
    }
    await super.save(value);
  }
}

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(
      ProviderResponse(
        text: 'Unexpected model request',
        toolCalls: const [],
        finishReason: 'stop',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final action in [
    ResourceMutationAction.patch,
    ResourceMutationAction.delete,
  ]) {
    test(
      'reference validation rereads a same-generation $action after its namespace queue wait',
      () async {
        final initial = DeveloperSampleDataService.append(
          current: buildInitialAppData(buildDefaultPeriodTimes()),
          language: DeveloperSampleLanguage.english,
          now: DateTime(2026, 9, 8, 9),
        ).data;
        final storage = _Storage(initial);
        final provider = _Provider();
        final gate = _SaveGate();
        final app = await workspaceProvider(
          storage: storage,
          agentProvider: provider,
        );
        addTearDown(() async {
          gate.release();
          await app.agent.quiesce();
          app.dispose();
        });
        await app.agent.configure(
          const AgentSettings(
            endpoint: 'https://fixture.example/v1',
            model: 'fixture',
            models: [
              AgentModelConfig(
                id: 'fixture',
                reasoningEfforts: [AgentReasoningEffort.medium],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              ),
            ],
          ),
        );
        await app.agent.setEnabled(true);
        final conversation = await app.agent.conversations.create(
          title: 'Reference validation',
        );
        final search = await app.agent.createReferenceSearch(conversation.id);
        final reference = (await search.search(''))
            .group(AgentComposerReferenceGroup.timetable)
            .candidates
            .first
            .reference;
        expect(app.session.committedData.applicationLedger, isNull);
        final originalLabel = reference.label;
        const changedLabel = 'Renamed while reference validation was queued';
        final scope = OperationScope(
          id: 'synthetic-$action',
          policy: OperationPolicy(
            enabled: true,
            mode: AgentPermissionMode.full,
          ),
        );
        final plan = app.agent.mutations.prepare(
          scope: scope,
          resources: [
            ResourceMutation(
              kind: ResourceKind.timetable,
              action: action,
              target: reference.resourceRef,
              values: action == ResourceMutationAction.patch
                  ? const {'name': changedLabel}
                  : const {},
            ),
          ],
        );
        storage.nextSave = gate;
        final commit = app.agent.mutations.commit(
          planId: plan.id,
          scope: scope,
        );
        await gate.entered.future;
        expect(
          app.session.committedData.studentMode.timetables
              .singleWhere((table) => table.id == reference.resourceRef!.id)
              .config
              .name,
          originalLabel,
        );
        final blockedTail = app.agent.mutations.waitForPendingWrites();
        var validationSettled = false;
        final validation = app.agent
            .validateComposerReferences(conversation.id, [reference])
            .then<Object>((value) => value, onError: (Object error) => error)
            .whenComplete(() => validationSettled = true);
        try {
          // The public queue Future changes exactly when validation enqueues its
          // namespace check behind the blocked commit. Pump microtasks until that
          // observable boundary, with a bounded failure if the check is omitted.
          for (
            var turn = 0;
            turn < 1000 &&
                identical(
                  app.agent.mutations.waitForPendingWrites(),
                  blockedTail,
                );
            turn++
          ) {
            await Future<void>.microtask(() {});
          }
          expect(
            identical(app.agent.mutations.waitForPendingWrites(), blockedTail),
            false,
            reason: 'Validation must have captured its initial search and queued the namespace check.',
          );
          expect(validationSettled, false);
          expect(gate.released.isCompleted, false);
          gate.release();
          final committed = await commit;
          expect(committed.replayed, false);
          expect(app.agent.mutations.generation, reference.datasetGeneration);
          final outcome = await validation;
          if (action == ResourceMutationAction.patch) {
            expect(outcome, isA<List<AgentComposerReference>>());
            final current = (outcome as List<AgentComposerReference>).single;
            expect(current.stableKey, reference.stableKey);
            expect(current.label, changedLabel);
          } else {
            expect(
              outcome,
              isA<OperationProblem>()
                  .having(
                    (error) => error.code,
                    'code',
                    OperationErrorCode.expired,
                  )
                  .having((error) => error.field, 'field', 'references'),
            );
          }
          expect(provider.requests, isEmpty);
          expect(
            app.agent.conversations.find(conversation.id)!.messages,
            isEmpty,
          );
          expect(
            app.session.committedData.applicationLedger!.receipts,
            hasLength(1),
          );
        } finally {
          gate.release();
          await commit;
          await validation;
          scope.cancel();
        }
      },
    );
  }
}
