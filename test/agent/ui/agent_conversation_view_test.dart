import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_service.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/agent/ui/agent_model_picker.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import 'agent_ui_test_support.dart';

class _AcceptedSendDelegate extends UiDelegate {
  _AcceptedSendDelegate(super.repository);

  final sendStarted = Completer<void>();
  final allowSend = Completer<void>();

  @override
  Future<void> send(String conversationId, String text) async {
    await super.send(conversationId, text);
    sendStarted.complete();
    await allowSend.future;
  }

  void release() {
    if (!allowSend.isCompleted) allowSend.complete();
  }
}

class _RecordingHistoryService implements ConversationHistoryService {
  final calls = <(String, String, String)>[];

  @override
  Future<void> editAndRedo(
    String conversationId,
    String messageId,
    String text,
  ) async {
    calls.add((conversationId, messageId, text));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UiMemoryStorage storage;
  late ConversationRepository repository;
  late UiDelegate delegate;
  var sequence = 0;
  Future<void> initialize() async {
    sequence = 0;
    storage = UiMemoryStorage();
    repository = ConversationRepository(
      storage: storage,
      idGenerator: () => 'conversation-${++sequence}',
      clock: () => DateTime.utc(2026, 10, 29),
    );
    await repository.load();
    delegate = UiDelegate(repository);
  }

  tearDown(() {
    repository.dispose();
    delegate.state.dispose();
  });
  Widget view({bool active = true, bool interactive = true}) =>
      AgentConversationView(
        repository: repository,
        delegate: delegate,
        active: active,
        interactive: interactive,
      );
  Widget composerView({TextDirection direction = TextDirection.ltr}) =>
      Directionality(
        textDirection: direction,
        child: AgentConversationView(
          repository: repository,
          delegate: delegate,
          readDatasetGeneration: () => 'synthetic-layout-data',
          modelPickerBuilder: (conversation, _, layout) => AgentModelPicker(
            conversationId: conversation.id,
            delegate: delegate,
            layoutBuilder: layout,
          ),
        ),
      );
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await repository.waitForPendingWrites();
    await tester.pumpAndSettle();
  }

  Future<void> newConversation(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('agent-history')));
    await tester.pumpAndSettle();
    final trigger = find.byKey(const ValueKey('agent-history-new'));
    await tester.ensureVisible(trigger);
    await tester.tap(trigger.hitTestable());
    await tester.pumpAndSettle();
  }

  for (final changesActivity in [true, false]) {
    testWidgets(
      'rename confirmation expires after ${changesActivity ? 'activity' : 'interaction'} is hidden and restored',
      (tester) async {
        addTearDown(tester.view.reset);
        await initialize();
        final conversation = await repository.create(title: 'Original title');
        await mountAgentUi(tester, view());
        final retainedState = tester.state(find.byType(AgentConversationView));
        await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('agent-rename-input')),
          'Expired title',
        );
        await mountAgentUi(
          tester,
          view(active: !changesActivity, interactive: changesActivity),
        );
        await mountAgentUi(tester, view());
        expect(
          tester.state(find.byType(AgentConversationView)),
          same(retainedState),
        );
        await tester.tap(find.text('Save'));
        await settle(tester);
        expect(repository.find(conversation.id)!.title, 'Original title');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final changesActivity in [true, false]) {
    for (final action in ['new', 'select', 'send', 'queue', 'steer']) {
      testWidgets(
        '$action waiting for draft storage expires after ${changesActivity ? 'activity' : 'interaction'} is hidden and restored',
        (tester) async {
          addTearDown(tester.view.reset);
          await initialize();
          final first = await repository.create(title: 'First conversation');
          final second = await repository.create(title: 'Second conversation');
          await repository.select(first.id);
          if (action == 'queue' || action == 'steer') {
            delegate.state.value = AgentUiState(
              enabled: true,
              configured: true,
              runs: {
                first.id: const AgentUiRunState(phase: AgentUiPhase.running),
              },
            );
          }
          var active = true;
          var interactive = true;
          late StateSetter changeHost;
          await mountAgentUi(
            tester,
            StatefulBuilder(
              builder: (_, setState) {
                changeHost = setState;
                return view(active: active, interactive: interactive);
              },
            ),
          );
          final retainedState = tester.state(
            find.byType(AgentConversationView),
          );
          final gate = Completer<void>();
          final saveStarted = Completer<void>();
          storage.beforeSave = () {
            if (!saveStarted.isCompleted) saveStarted.complete();
            return gate.future;
          };
          addTearDown(() {
            if (!gate.isCompleted) gate.complete();
          });
          await tester.enterText(
            find.byKey(const ValueKey('agent-composer')),
            'Keep this accepted draft',
          );
          await tester.pump();
          expect(saveStarted.isCompleted, isTrue);
          if (action == 'select') {
            await tester.tap(find.byKey(const ValueKey('agent-history')));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(ValueKey('agent-history-${second.id}')),
            );
          } else if (action == 'new') {
            await newConversation(tester);
          } else {
            final trigger = find.byKey(ValueKey('agent-$action'));
            await tester.ensureVisible(trigger);
            await tester.tap(trigger);
          }
          await tester.pump();
          changeHost(() {
            if (changesActivity) {
              active = false;
            } else {
              interactive = false;
            }
          });
          await tester.pump();
          changeHost(() {
            active = true;
            interactive = true;
          });
          await tester.pump();
          expect(
            tester.state(find.byType(AgentConversationView)),
            same(retainedState),
          );
          expect(gate.isCompleted, isFalse);
          gate.complete();
          await settle(tester);
          expect(repository.conversations, hasLength(2));
          expect(repository.selectedId, first.id);
          expect(repository.find(first.id)!.draft, 'Keep this accepted draft');
          expect(delegate.calls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final invalidation in [
    'activity hidden',
    'interaction hidden',
    'host reentry',
  ]) {
    testWidgets(
      'edit and redo waiting for draft storage expires after $invalidation',
      (tester) async {
        addTearDown(tester.view.reset);
        await initialize();
        final conversation = await repository.create(title: 'History draft');
        const requestId = 'history-request';
        const originalRequest = 'Original request';
        const revisedRequest = 'Revise the original request';
        final createdAt = DateTime.utc(2026, 10, 29);
        await repository.update(
          conversation.id,
          (current) => current.copyWith(
            messages: [
              ConversationMessage(
                id: requestId,
                role: ConversationRole.user,
                text: originalRequest,
                createdAt: createdAt,
              ),
              ConversationMessage(
                id: 'history-reply',
                role: ConversationRole.assistant,
                text: 'Original reply',
                createdAt: createdAt,
              ),
            ],
            runs: [
              ConversationRunUsage(
                id: 'history-run',
                startedAt: createdAt,
                settledAt: createdAt,
                kind: ConversationRunKind.model,
                protocol: 'openai_chat_completions',
                model: 'fixture-model',
                reasoningEffort: AgentReasoningEffort.medium,
                status: ConversationRunStatus.completed,
              ),
            ],
            turns: [
              ConversationTurn(
                id: 'history-turn',
                requestMessageId: requestId,
                ownershipComplete: true,
                messageIds: const [requestId, 'history-reply'],
                runIds: const ['history-run'],
              ),
            ],
          ),
        );
        final history = _RecordingHistoryService();
        var active = true;
        var interactive = true;
        late StateSetter changeHost;
        await mountAgentUi(
          tester,
          StatefulBuilder(
            builder: (_, setState) {
              changeHost = setState;
              return AgentConversationView(
                repository: repository,
                delegate: delegate,
                history: history,
                active: active,
                interactive: interactive,
              );
            },
          ),
        );
        final retainedState = tester.state(find.byType(AgentConversationView));
        final gate = Completer<void>();
        final saveStarted = Completer<void>();
        storage.beforeSave = () {
          if (!saveStarted.isCompleted) saveStarted.complete();
          return gate.future;
        };
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        await tester.enterText(
          find.byKey(const ValueKey('agent-composer')),
          'Keep this accepted draft',
        );
        await tester.pump();
        expect(saveStarted.isCompleted, isTrue);
        final edit = find.byKey(const ValueKey('agent-edit-redo-$requestId'));
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('agent-redo-input')),
          revisedRequest,
        );
        await tester.tap(find.byKey(const ValueKey('agent-confirm-redo')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('agent-redo-input')), findsNothing);
        expect(tester.widget<IconButton>(edit).onPressed, isNull);
        expect(history.calls, isEmpty);
        changeHost(() {
          if (invalidation == 'interaction hidden') {
            interactive = false;
          } else {
            active = false;
          }
        });
        await tester.pump();
        if (invalidation == 'host reentry') {
          changeHost(() => active = true);
          await tester.pump();
        }
        expect(
          tester.state(find.byType(AgentConversationView)),
          same(retainedState),
        );
        expect(gate.isCompleted, isFalse);
        gate.complete();
        await settle(tester);
        expect(history.calls, isEmpty);
        expect(repository.selectedId, conversation.id);
        expect(repository.selected!.draft, 'Keep this accepted draft');
        expect(repository.selected!.messages.first.text, originalRequest);
        expect(repository.selected!.pendingRedo, isNull);
        changeHost(() {
          active = true;
          interactive = true;
        });
        await settle(tester);
        expect(history.calls, isEmpty);
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('agent-redo-input')))
              .controller!
              .text,
          revisedRequest,
        );
        await tester.tap(find.byKey(const ValueKey('agent-confirm-redo')));
        await settle(tester);
        expect(history.calls, [(conversation.id, requestId, revisedRequest)]);
        expect(delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final menu in ['permission', 'conversation']) {
    for (final invalidation in ['conversation switch', 'host reentry']) {
      testWidgets('$menu menu rejects queued results after $invalidation', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        await initialize();
        final first = await repository.create(title: 'First conversation');
        final second = await repository.create(title: 'Second conversation');
        await repository.select(first.id);
        var active = true;
        late StateSetter changeHost;
        await mountAgentUi(
          tester,
          StatefulBuilder(
            builder: (_, setState) {
              changeHost = setState;
              return view(active: active);
            },
          ),
        );
        final key = menu == 'permission'
            ? 'agent-mode-picker'
            : 'agent-conversation-menu';
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        final void Function() deliverLateResult;
        if (menu == 'permission') {
          final popup = tester.widget<SkedPopupMenuButton<AgentPermissionMode>>(
            find.byKey(ValueKey(key)),
          );
          final onSelected = popup.onSelected!;
          deliverLateResult = () => onSelected(AgentPermissionMode.full);
        } else {
          final popup = tester.widget<SkedPopupMenuButton<String>>(
            find.byKey(ValueKey(key)),
          );
          final onSelected = popup.onSelected!;
          deliverLateResult = () => onSelected('archive');
        }
        if (invalidation == 'conversation switch') {
          await repository.select(second.id);
        } else {
          changeHost(() => active = false);
          await tester.pump();
          changeHost(() => active = true);
        }
        await tester.pumpAndSettle();
        deliverLateResult();
        await settle(tester);
        expect(delegate.calls, isEmpty);
        expect(repository.find(first.id)!.mode, AgentPermissionMode.ask);
        expect(repository.find(second.id)!.mode, AgentPermissionMode.ask);
        expect(repository.find(first.id)!.archived, isFalse);
        expect(repository.find(second.id)!.archived, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'a send already accepted by the delegate completes after the retained host is hidden',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      delegate.state.dispose();
      final accepted = _AcceptedSendDelegate(repository);
      delegate = accepted;
      addTearDown(accepted.release);
      final conversation = await repository.create(title: 'Accepted send');
      var active = true;
      late StateSetter changeHost;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            changeHost = setState;
            return view(active: active);
          },
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Finish the accepted request',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      for (
        var attempt = 0;
        attempt < 120 && !accepted.sendStarted.isCompleted;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(accepted.sendStarted.isCompleted, isTrue);
      changeHost(() => active = false);
      await tester.pump();
      expect(accepted.allowSend.isCompleted, isFalse);
      accepted.release();
      await settle(tester);
      expect(delegate.calls, [
        'send:${conversation.id}:Finish the accepted request',
      ]);
      changeHost(() => active = true);
      await settle(tester);
      expect(delegate.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    for (final brightness in Brightness.values) {
      for (final width in [320.0, 390.0, 1000.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'composer actions share one row at $width and ${scale}x on $platform $brightness',
            (tester) async {
              addTearDown(tester.view.reset);
              await initialize();
              const model = AgentModelConfig(
                id: 'a-very-long-model-name-with-extra-context',
                reasoningEfforts: [
                  AgentReasoningEffort.medium,
                  AgentReasoningEffort.high,
                ],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              );
              delegate.state.value = AgentUiState(
                enabled: true,
                configured: true,
                availableModels: const [model],
                defaultModelSelection: model.defaultSelection,
              );
              await repository.create(title: 'Composer layout');
              await mountAgentUi(
                tester,
                composerView(),
                size: Size(width, 1000),
                scale: scale,
                brightness: brightness,
              );
              final keys = [
                'agent-attach-file',
                'agent-mode-picker',
                'agent-model-picker',
                'agent-send',
              ];
              final rects = keys
                  .map((key) => tester.getRect(find.byKey(ValueKey(key))))
                  .toList();
              final row = tester.getRect(
                find.byKey(const ValueKey('agent-composer-actions')),
              );
              for (final rect in rects) {
                expect(rect.center.dy, closeTo(rects.first.center.dy, 1));
                expect(rect.left, greaterThanOrEqualTo(row.left));
                expect(rect.right, lessThanOrEqualTo(row.right));
                expect(
                  rect.height,
                  greaterThanOrEqualTo(
                    platform == TargetPlatform.windows ? 24 : 48,
                  ),
                );
                expect(
                  rect.width,
                  greaterThanOrEqualTo(
                    platform == TargetPlatform.windows ? 24 : 48,
                  ),
                );
              }
              for (var i = 1; i < rects.length; i++) {
                expect(rects[i - 1].right, lessThanOrEqualTo(rects[i].left));
              }
              expect(rects[2].width, lessThanOrEqualTo(320));
              expect(rects.last.right, closeTo(row.right, 1));
              for (final key in keys) {
                expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
              }
              expect(tester.takeException(), isNull);
            },
            variant: TargetPlatformVariant.only(platform),
          );
        }
      }
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final selected in [false, true]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'short model control keeps its width from 600 to 1000 on $platform $direction selected=$selected',
          (tester) async {
            addTearDown(tester.view.reset);
            await initialize();
            const model = AgentModelConfig(
              id: 'model-a',
              reasoningEfforts: [AgentReasoningEffort.low],
              defaultReasoningEffort: AgentReasoningEffort.low,
            );
            delegate.state.value = AgentUiState(
              enabled: true,
              configured: true,
              availableModels: const [model],
              defaultModelSelection: selected ? model.defaultSelection : null,
            );
            await repository.create(title: 'Compact composer');
            final widths = <double>[];
            for (final width in [600.0, 1000.0]) {
              await mountAgentUi(
                tester,
                composerView(direction: direction),
                size: Size(width, 900),
              );
              final picker = find.byKey(const ValueKey('agent-model-picker'));
              widths.add(tester.getSize(picker).width);
              final row = tester.getRect(
                find.byKey(const ValueKey('agent-composer-actions')),
              );
              final send = tester.getRect(
                find.byKey(const ValueKey('agent-send')),
              );
              final permission = tester.getRect(
                find.byKey(const ValueKey('agent-mode-picker')),
              );
              final attachment = tester.getRect(
                find.byKey(const ValueKey('agent-attach-file')),
              );
              if (direction == TextDirection.ltr) {
                expect(attachment.left, closeTo(row.left, 1));
                expect(permission.left - attachment.right, closeTo(4, 1));
                expect(send.right, closeTo(row.right, 1));
                expect(tester.getRect(picker).right + 4, closeTo(send.left, 1));
              } else {
                expect(attachment.right, closeTo(row.right, 1));
                expect(attachment.left - permission.right, closeTo(4, 1));
                expect(send.left, closeTo(row.left, 1));
                expect(tester.getRect(picker).left - 4, closeTo(send.right, 1));
              }
              if (!selected) {
                final l = AppLocalizations.of(tester.element(picker));
                expect(find.text(l.agentChooseModel), findsOneWidget);
                expect(find.text(l.agentThinkingEffort), findsNothing);
                expect(
                  find.byKey(const ValueKey('agent-model-effort-label')),
                  findsNothing,
                );
              }
              expect(tester.takeException(), isNull);
            }
            expect(widths.first, lessThan(320));
            expect(widths.last, closeTo(widths.first, 1));
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 390.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'compact model group stays reachable with 2x text and IME at $width on $platform $direction',
          (tester) async {
            addTearDown(tester.view.reset);
            await initialize();
            const model = AgentModelConfig(
              id: 'a-very-long-model-name-with-extra-context',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            );
            delegate.state.value = AgentUiState(
              enabled: true,
              configured: true,
              availableModels: const [model],
              defaultModelSelection: model.defaultSelection,
            );
            await repository.create(title: 'IME layout');
            await mountAgentUi(
              tester,
              composerView(direction: direction),
              size: Size(width, 740),
              scale: 2,
              keyboard: 280,
            );
            await tester.enterText(
              find.byKey(const ValueKey('agent-composer')),
              'Check active touch targets',
            );
            await settle(tester);
            final composer = find.byKey(const ValueKey('agent-composer'));
            final input = tester.widget<TextField>(composer);
            final insets = MediaQuery.viewInsetsOf(tester.element(composer));
            // Selection handles intentionally own their overlay's input. Probe
            // the underlying controls while preserving the focused draft/IME.
            tester
                .state<EditableTextState>(
                  find.descendant(
                    of: composer,
                    matching: find.byType(EditableText),
                  ),
                )
                .hideToolbar();
            await tester.pump();
            expect(input.focusNode!.hasFocus, isTrue);
            expect(input.controller!.text, 'Check active touch targets');
            expect(MediaQuery.viewInsetsOf(tester.element(composer)), insets);
            final keys = [
              'agent-attach-file',
              'agent-mode-picker',
              'agent-model-picker',
              'agent-send',
            ];
            await tester.ensureVisible(
              find.byKey(const ValueKey('agent-composer-actions')),
            );
            final rects = keys
                .map((key) => tester.getRect(find.byKey(ValueKey(key))))
                .toList();
            for (var i = 0; i < rects.length; i++) {
              expect(rects[i].width, greaterThanOrEqualTo(48));
              expect(rects[i].height, greaterThanOrEqualTo(48));
              expect(rects[i].center.dy, closeTo(rects.first.center.dy, 1));
              expect(
                find.byKey(ValueKey(keys[i])).hitTestable(),
                findsOneWidget,
              );
              final target = tester.renderObject(find.byKey(ValueKey(keys[i])));
              for (final x in [
                rects[i].left + 2,
                rects[i].center.dx,
                rects[i].right - 2,
              ]) {
                for (final y in [
                  rects[i].top + 2,
                  rects[i].center.dy,
                  rects[i].bottom - 2,
                ]) {
                  final point = Offset(x, y);
                  final path = tester.hitTestOnBinding(point).path;
                  expect(
                    path.any((entry) => identical(entry.target, target)),
                    isTrue,
                    reason:
                        '${keys[i]} must receive input at $point within ${rects[i]}; '
                        'target=${target.runtimeType}, '
                        'hit=${path.map((entry) => entry.target.runtimeType).join(', ')}, '
                        'painters=${path.where((entry) => entry.target is RenderCustomPaint).map((entry) => (entry.target as RenderCustomPaint).painter?.runtimeType).join(', ')}',
                  );
                }
              }
              if (i > 0) {
                if (direction == TextDirection.ltr) {
                  expect(rects[i - 1].right, lessThanOrEqualTo(rects[i].left));
                } else {
                  expect(rects[i].right, lessThanOrEqualTo(rects[i - 1].left));
                }
              }
            }
            await tester.tap(find.byKey(const ValueKey('agent-model-picker')));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('agent-effort-value')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
  testWidgets('permission label collapses before inline effort is hidden', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    const model = AgentModelConfig(
      id: 'a-very-long-model-name-with-extra-context',
      reasoningEfforts: [AgentReasoningEffort.medium],
      defaultReasoningEffort: AgentReasoningEffort.medium,
    );
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      availableModels: const [model],
      defaultModelSelection: model.defaultSelection,
    );
    await repository.create(title: 'Compression order');
    for (final layout in [
      (width: 1000.0, scale: 1.0),
      (width: 390.0, scale: 1.0),
      (width: 320.0, scale: 2.0),
    ]) {
      await mountAgentUi(
        tester,
        composerView(),
        size: Size(layout.width, 900),
        scale: layout.scale,
      );
      final permission = find.byKey(const ValueKey('agent-mode-picker'));
      expect(
        find.descendant(of: permission, matching: find.byType(Text)),
        layout.width == 1000 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('agent-model-effort-label')),
        layout.scale == 1 ? findsOneWidget : findsNothing,
      );
      expect(delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets(
    'composer wraps action groups only when four minimum targets cannot fit',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      const model = AgentModelConfig(
        id: 'model-a',
        reasoningEfforts: [AgentReasoningEffort.low],
        defaultReasoningEffort: AgentReasoningEffort.low,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [model],
        defaultModelSelection: model.defaultSelection,
      );
      await repository.create(title: 'Wrap');
      for (final width in [320.0, 230.0]) {
        await mountAgentUi(tester, composerView(), size: Size(width, 900));
        final attachment = tester.getRect(
          find.byKey(const ValueKey('agent-attach-file')),
        );
        final permission = tester.getRect(
          find.byKey(const ValueKey('agent-mode-picker')),
        );
        final picker = tester.getRect(
          find.byKey(const ValueKey('agent-model-picker')),
        );
        final send = tester.getRect(find.byKey(const ValueKey('agent-send')));
        expect(attachment.center.dy, closeTo(permission.center.dy, 1));
        expect(picker.center.dy, closeTo(send.center.dy, 1));
        if (width == 320) {
          expect(permission.center.dy, closeTo(picker.center.dy, 1));
        } else {
          expect(picker.top, greaterThanOrEqualTo(permission.bottom + 4));
        }
        for (final rect in [attachment, permission, picker, send]) {
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets('opening and typing in New chat never persists empty history', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    await mountAgentUi(tester, view());
    await settle(tester);
    final draftId = repository.selectedId!;
    expect(repository.isDraft(draftId), isTrue);
    expect(repository.conversations, isEmpty);
    expect(storage.source, isNull);
    expect(find.byKey(const ValueKey('agent-composer')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Keep this unsent draft',
    );
    await settle(tester);
    await newConversation(tester);
    await settle(tester);
    expect(repository.selectedId, draftId);
    expect(repository.selected!.draft, 'Keep this unsent draft');
    expect(repository.conversations, isEmpty);
    expect(storage.source, isNull);
    expect(delegate.calls, isEmpty);
  });

  testWidgets(
    'new drafts retain their initial model until the first message is saved',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      const firstSelection = AgentModelSelection(
        modelId: 'model-a',
        reasoningEffort: AgentReasoningEffort.high,
      );
      const secondSelection = AgentModelSelection(
        modelId: 'model-b',
        reasoningEffort: AgentReasoningEffort.medium,
      );
      const models = [
        AgentModelConfig(
          id: 'model-a',
          reasoningEfforts: [
            AgentReasoningEffort.medium,
            AgentReasoningEffort.high,
          ],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
        AgentModelConfig(
          id: 'model-b',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ];
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: models,
        defaultModelSelection: firstSelection,
      );
      await mountAgentUi(tester, view());
      await newConversation(tester);
      await settle(tester);
      final firstId = repository.selectedId!;
      expect(repository.find(firstId)!.modelSelection, firstSelection);
      expect(repository.isDraft(firstId), isTrue);
      expect(storage.source, isNull);
      await repository.update(
        firstId,
        (current) => current.copyWith(
          messages: [
            ConversationMessage(
              id: 'first-user-message',
              role: ConversationRole.user,
              text: 'Start this conversation',
              createdAt: DateTime.utc(2026, 10, 29),
            ),
          ],
        ),
      );
      expect(repository.isDraft(firstId), isFalse);

      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: models,
        defaultModelSelection: secondSelection,
        modelSelections: {firstId: firstSelection},
      );
      await tester.pumpAndSettle();
      await newConversation(tester);
      await settle(tester);
      expect(repository.selected!.modelSelection, secondSelection);
      expect(repository.find(firstId)!.modelSelection, firstSelection);
      expect(repository.conversations, hasLength(1));
      expect(repository.isDraft(repository.selectedId), isTrue);
      expect(delegate.calls, isEmpty);
    },
  );

  testWidgets(
    'HTTP transport approval describes transmission and does not present a business mutation',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(
        title: 'HTTP request',
        mode: AgentPermissionMode.plan,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: AgentUiRunState(
            phase: AgentUiPhase.waitingApproval,
            pendingApproval: AgentUiApproval(
              id: 'http-request',
              summary: 'Transport permission',
              details: {
                'kind': 'httpTransport',
                'endpoint': 'http://model.example/v1',
              },
            ),
          ),
        },
      );
      await mountAgentUi(tester, view());
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.text(l.agentHttpTransportApproval), findsOneWidget);
      expect(find.text(l.agentHttpTransportWarning), findsOneWidget);
      expect(find.text(l.agentHttpTransportScope), findsOneWidget);
      expect(find.text('http://model.example/v1'), findsOneWidget);
      expect(find.text(l.agentChangeCount(0)), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-approve')));
      await tester.tap(find.byKey(const ValueKey('agent-approve')));
      await settle(tester);
      expect(delegate.calls, ['approve:${conversation.id}:http-request']);
      expect(repository.selected!.mode, AgentPermissionMode.plan);
    },
  );

  testWidgets(
    'unresolved previous writes keep a distinct read-only recovery notice',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(
        title: 'Needs recovery',
        mode: AgentPermissionMode.full,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {conversation.id: const AgentUiRunState(recoveryRequired: true)},
      );
      await mountAgentUi(tester, view());
      expect(
        find.text(
          'Check the previous operation result first. Only reading is currently allowed.',
        ),
        findsOneWidget,
      );
      expect(repository.selected!.mode, AgentPermissionMode.full);
      expect(find.byKey(const ValueKey('agent-composer')), findsOneWidget);
    },
  );

  testWidgets(
    'archive retains its selected history and draft and restore re-enables input',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final first = await repository.create(title: 'Keep archived context');
      await repository.update(
        first.id,
        (value) => value.copyWith(draft: 'Still needed'),
      );
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive conversation'));
      await settle(tester);
      expect(repository.selectedId, first.id);
      expect(repository.selected!.archived, isTrue);
      expect(repository.selected!.draft, 'Still needed');
      expect(find.byKey(const ValueKey('agent-composer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-history')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('agent-history-${first.id}')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-history-more')));
      await tester.pumpAndSettle();
      final archived = find.byKey(const ValueKey('agent-history-archived'));
      await tester.ensureVisible(archived);
      await tester.tap(archived.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('agent-history-${first.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('agent-restore-${first.id}')));
      await settle(tester);
      expect(repository.find(first.id)!.archived, isFalse);
      await tester.tap(find.byKey(const ValueKey('agent-history-close')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Still needed',
      );
      expect(delegate.calls, [
        'archive:${first.id}:true',
        'archive:${first.id}:false',
      ]);
    },
  );

  testWidgets(
    'conversation export uses the selected id and reports success only when saved',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Export this');
      final exported = <String>[];
      var saved = false;
      await mountAgentUi(
        tester,
        AgentConversationView(
          repository: repository,
          delegate: delegate,
          onExportConversation: (id) async {
            exported.add(id);
            return saved;
          },
        ),
      );
      Future<void> export() async {
        await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export conversation'));
        await settle(tester);
      }

      await export();
      expect(exported, [conversation.id]);
      expect(find.text('Action completed'), findsNothing);
      saved = true;
      await export();
      expect(find.text('Action completed'), findsOneWidget);
    },
  );

  testWidgets(
    'running composer offers distinct queue and steering actions and stopped work can continue',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Ongoing request');
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: const AgentUiRunState(phase: AgentUiPhase.running),
        },
      );
      await mountAgentUi(tester, view(), size: const Size(390, 844), scale: 2);
      final composer = find.byKey(const ValueKey('agent-composer'));
      await tester.enterText(composer, 'Afterwards create a second class');
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-queue')));
      await tester.tap(find.byKey(const ValueKey('agent-queue')));
      await settle(tester);
      expect(delegate.calls, [
        'queue:${conversation.id}:Afterwards create a second class',
      ]);
      expect(repository.selected!.draft, isEmpty);
      await tester.ensureVisible(composer);
      await tester.enterText(composer, 'Use the afternoon instead');
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-steer')));
      await tester.tap(find.byKey(const ValueKey('agent-steer')));
      await settle(tester);
      expect(
        delegate.calls.last,
        'steer:${conversation.id}:Use the afternoon instead',
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: const AgentUiRunState(phase: AgentUiPhase.stopped),
        },
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('agent-continue')));
      await tester.tap(find.byKey(const ValueKey('agent-continue')));
      await settle(tester);
      expect(delegate.calls.last, 'continue:${conversation.id}');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'queued input displays its message without exposing queue storage JSON',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Queued request');
      await repository.update(
        conversation.id,
        (value) => value.copyWith(
          messages: [
            ConversationMessage(
              id: 'queued',
              role: ConversationRole.notice,
              text: jsonEncode({
                'kind': 'agent_pending_input',
                'version': 1,
                'mode': 'followUp',
                'text': 'Use the blue category',
              }),
              createdAt: DateTime.utc(2026),
            ),
            ConversationMessage(
              id: 'host-operation',
              role: ConversationRole.notice,
              text: jsonEncode({
                'kind': 'agent_host_operation',
                'operationId': 'durable-operation',
              }),
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      await mountAgentUi(tester, view());
      expect(find.text('Use the blue category'), findsOneWidget);
      expect(find.textContaining('agent_pending_input'), findsNothing);
      expect(find.textContaining('agent_host_operation'), findsNothing);
    },
  );

  testWidgets(
    'new conversation and drafts persist across panel removal and resize',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        defaultMode: AgentPermissionMode.full,
      );
      await mountAgentUi(tester, view());
      await newConversation(tester);
      await settle(tester);
      expect(repository.selected!.mode, AgentPermissionMode.full);
      expect(delegate.calls, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Keep this\nexact draft',
      );
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      await mountAgentUi(tester, view(), size: const Size(320, 700), scale: 2);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Keep this\nexact draft',
      );
      expect(repository.selected!.draft, 'Keep this\nexact draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history selection and rename operate on actual repository targets',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final first = await repository.create(title: 'First');
      await repository.create(title: 'Second');
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('agent-history-${first.id}')));
      await settle(tester);
      expect(repository.selectedId, first.id);
      await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-rename-input')),
        'Renamed first',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(repository.find(first.id)!.title, 'Renamed first');
      expect(repository.conversations.last.title, 'Second');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deletion confirms and stops its own run before removing the conversation',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final first = await repository.create(title: 'First');
      final second = await repository.create(title: 'Second');
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repository.find(second.id), isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(delegate.calls, ['stop:${second.id}']);
      expect(repository.find(second.id), isNull);
      expect(repository.selectedId, first.id);
    },
  );

  testWidgets(
    'send delegates exact text without inventing a message or clearing unaccepted drafts',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Send');
      await mountAgentUi(tester, view());
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        '  Exact request\n',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await settle(tester);
      expect(delegate.calls, ['send:${conversation.id}:  Exact request\n']);
      expect(repository.selected!.messages, isEmpty);
      expect(repository.selected!.draft, '  Exact request\n');
      await repository.update(
        conversation.id,
        (current) => current.copyWith(draft: ''),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'policy can tighten while running and stop remains a real runtime action',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(
        title: 'Running',
        mode: AgentPermissionMode.full,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: const AgentUiRunState(
            phase: AgentUiPhase.running,
            streamingText: 'Real streamed text',
          ),
        },
      );
      await mountAgentUi(tester, view());
      expect(find.text('Real streamed text'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-mode-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-mode-plan')));
      await settle(tester);
      expect(repository.selected!.mode, AgentPermissionMode.plan);
      expect(delegate.calls, ['mode:${conversation.id}:plan']);
      await tester.tap(find.byKey(const ValueKey('agent-stop')));
      await tester.pumpAndSettle();
      expect(delegate.calls.last, 'stop:${conversation.id}');
      expect(repository.selected!.messages, isEmpty);
    },
  );

  testWidgets(
    'approval dispatches only the concrete plan id and tool details remain inspectable',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Review');
      await repository.update(
        conversation.id,
        (current) => current.copyWith(
          messages: [
            ConversationMessage(
              id: 'call-message',
              role: ConversationRole.assistant,
              text: '',
              createdAt: DateTime.utc(2026),
              toolCalls: const [
                ConversationToolCall(
                  id: 'call-1',
                  name: 'settings.query',
                  arguments: '{"key":"theme"}',
                ),
              ],
            ),
            ConversationMessage(
              id: 'result-message',
              role: ConversationRole.tool,
              toolCallId: 'call-1',
              text: '{"status":"read","value":"dark"}',
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: AgentUiRunState(
            phase: AgentUiPhase.waitingApproval,
            pendingApproval: AgentUiApproval(
              id: 'plan-17',
              summary: 'Change one setting',
              details: {'before': 'dark', 'after': 'light'},
            ),
          ),
        },
      );
      await mountAgentUi(tester, view());
      await tester.ensureVisible(find.byKey(const ValueKey('agent-approve')));
      await tester.tap(find.byKey(const ValueKey('agent-approve')));
      await tester.pumpAndSettle();
      expect(delegate.calls, ['approve:${conversation.id}:plan-17']);
      await tester.tap(find.byKey(const ValueKey('agent-reject')));
      await tester.pumpAndSettle();
      expect(delegate.calls.last, 'reject:${conversation.id}:plan-17');
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-activity-toggle-legacy-call-message')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-activity-toggle-legacy-call-message')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-activity-tool-call-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-activity-tool-call-1')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('"status": "read"'), findsOneWidget);
      expect(repository.selected!.messages.length, 2);
    },
  );

  testWidgets('failed draft save retains text and explicit retry persists it', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    await repository.create(title: 'Failure');
    await mountAgentUi(tester, view());
    storage.fail = true;
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Unsaved draft',
    );
    await settle(tester);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.textContaining('raw-secret'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
          .controller!
          .text,
      'Unsaved draft',
    );
    await tester.pumpWidget(const SizedBox());
    await mountAgentUi(tester, view());
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
          .controller!
          .text,
      'Unsaved draft',
    );
    storage.fail = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(repository.selected!.draft, 'Unsaved draft');
    expect(repository.canWrite, isTrue);
  });

  testWidgets('keyboard shortcut delegates the exact draft', (tester) async {
    addTearDown(tester.view.reset);
    await initialize();
    final conversation = await repository.create(title: 'Keyboard');
    await mountAgentUi(tester, view());
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Keyboard request',
    );
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(delegate.calls, ['send:${conversation.id}:Keyboard request']);
  });

  testWidgets('shortcut waits until the input method finishes composing', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    final conversation = await repository.create(title: 'Input method');
    await mountAgentUi(tester, view());
    await tester.showKeyboard(find.byKey(const ValueKey('agent-composer')));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '下周课表',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 0, end: 4),
      ),
    );
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(delegate.calls, isEmpty);
    expect(repository.selected!.draft, '下周课表');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '下周课表',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(delegate.calls, ['send:${conversation.id}:下周课表']);
  });

  testWidgets(
    'opening the keyboard preserves the focused composer and its draft',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.create(title: 'Focus');
      await mountAgentUi(tester, view(), size: const Size(360, 820));
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Pending text',
      );
      await settle(tester);
      final focus = tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
          .focusNode!;
      expect(focus.hasFocus, isTrue);
      await mountAgentUi(
        tester,
        view(),
        size: const Size(360, 820),
        keyboard: 340,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Pending text',
      );
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a panel preserves the accepted draft write but does not start its pending send',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.create(title: 'Queued send');
      await mountAgentUi(tester, view());
      final gate = Completer<void>();
      storage.beforeSave = () => gate.future;
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Keep working',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pumpAndSettle();
      await repository.waitForPendingWrites();
      expect(delegate.calls, isEmpty);
      expect(repository.selected!.draft, 'Keep working');
    },
  );

  testWidgets(
    'narrow phone with 2x text and keyboard retains reachable controls',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.create(
        title: 'A long conversation title that must wrap completely',
      );
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 740),
        scale: 2,
        keyboard: 280,
        locale: const Locale('zh'),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('agent-composer')));
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        '查看下周课表',
      );
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-send')));
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await settle(tester);
      expect(delegate.calls.single, contains('查看下周课表'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RTL compact 2x approval and input remain reachable', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    final conversation = await repository.create(
      title: 'A long right-to-left conversation',
    );
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {
        conversation.id: AgentUiRunState(
          phase: AgentUiPhase.waitingApproval,
          pendingApproval: AgentUiApproval(
            id: 'rtl-plan',
            summary: 'Change title',
            details: {
              'planId': 'rtl-plan',
              'changeCount': 1,
              'changes': [
                {'key': 'title', 'before': 'Previous', 'after': 'Next'},
              ],
            },
          ),
        ),
      },
    );
    await mountAgentUi(
      tester,
      Directionality(textDirection: TextDirection.rtl, child: view()),
      size: const Size(320, 740),
      scale: 2,
      keyboard: 280,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('agent-approve')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('agent-approve')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('agent-approve')));
    await settle(tester);
    expect(delegate.calls, ['approve:${conversation.id}:rtl-plan']);
    await tester.ensureVisible(find.byKey(const ValueKey('agent-composer')));
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Follow up text',
    );
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('agent-queue')));
    await tester.tap(find.byKey(const ValueKey('agent-queue')));
    await settle(tester);
    expect(delegate.calls.last, 'queue:${conversation.id}:Follow up text');
    expect(tester.takeException(), isNull);
  });
}
