import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_reference_picker.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import 'agent_ui_test_support.dart';

void main() {
  final composer = find.byKey(const ValueKey('agent-composer'));
  final picker = find.byType(AgentReferencePicker);
  final chips = find.byType(AgentReferenceChips);

  Future<_ReferenceFixture> fixture({int customSkills = 0}) async {
    final result = _ReferenceFixture(customSkills: customSkills);
    await result.initialize();
    addTearDown(result.delegate.state.dispose);
    addTearDown(result.repository.dispose);
    return result;
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.ensureVisible(composer);
    await tester.enterText(composer, text);
    await tester.pumpAndSettle();
  }

  AgentReferenceChoice calendar(WidgetTester tester) => tester
      .widget<AgentReferencePicker>(picker)
      .result
      .choices
      .firstWhere(
        (choice) => choice.value.resourceRef?.kind == ResourceKind.calendar,
      );

  testWidgets(
    'typing at opens search and selecting persists a stable reference without replacing the editor',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      final editor = tester.widget<TextField>(composer);
      await type(tester, '@');
      expect(picker, findsOneWidget);
      expect(app.searches, 1);
      final choice = calendar(tester);
      final row = find.byKey(ValueKey('agent-reference-choice-${choice.key}'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await app.repository.waitForPendingWrites();
      final saved = app.repository.selected!;
      expect(saved.draftReferences.single.toJson(), choice.value.toJson());
      expect(saved.draft, choice.label);
      expect(app.validations, 1);
      expect(app.updates, 1);
      expect(
        tester.widget<TextField>(composer).controller,
        same(editor.controller),
      );
      expect(
        tester.widget<TextField>(composer).focusNode,
        same(editor.focusNode),
      );
      expect(editor.focusNode!.hasFocus, true);
      expect(chips, findsOneWidget);
      expect(picker, findsNothing);
      expect(
        ConversationArchive.decode(app.storage.source!)
            .conversations
            .single
            .draftReferences
            .single
            .stableKey,
        choice.key,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'a draft with only a reference can send its original empty text',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await app.repository.updateDraftReferences('conversation', [
        app.calendarReference,
      ]);
      await mountAgentUi(tester, app.view());
      expect(tester.widget<TextField>(composer).controller!.text, isEmpty);
      final send = find.byKey(const ValueKey('agent-send'));
      expect(tester.widget<IconButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(app.delegate.calls, ['send:conversation:']);
    },
  );

  testWidgets(
    'composing input stays untouched and starts searching only after composition commits',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      await tester.tap(composer);
      const composing = TextEditingValue(
        text: '@中',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pumpAndSettle();
      expect(app.searches, 0);
      expect(picker, findsNothing);
      expect(tester.widget<TextField>(composer).controller!.value, composing);
      tester.testTextInput.updateEditingValue(
        composing.copyWith(composing: TextRange.empty),
      );
      await tester.pumpAndSettle();
      expect(app.searches, 1);
      expect(picker, findsOneWidget);
    },
  );

  for (final boundary in ['query', 'selection', 'hidden']) {
    testWidgets('old reference selection expires after $boundary changes', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      await type(tester, '@');
      final oldPicker = tester.widget<AgentReferencePicker>(picker);
      final choice = calendar(tester);
      switch (boundary) {
        case 'query':
          await type(tester, '@a different query');
        case 'selection':
          tester.widget<TextField>(composer).controller!.selection =
              const TextSelection.collapsed(offset: 0);
          await tester.pumpAndSettle();
        case 'hidden':
          await mountAgentUi(tester, app.view(active: false));
          await mountAgentUi(tester, app.view());
      }
      await oldPicker.onSelect(choice);
      await tester.pumpAndSettle();
      expect(app.repository.selected!.draftReferences, isEmpty);
      expect(app.validations, 0);
    });
  }

  testWidgets(
    'a query changed during fresh validation cannot save or replace current text',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      final release = Completer<void>();
      app.beforeValidation = () => release.future;
      await mountAgentUi(tester, app.view());
      await type(tester, '@');
      final old = tester.widget<AgentReferencePicker>(picker);
      final pending = old.onSelect(calendar(tester));
      await tester.pump();
      await type(tester, '@new query');
      release.complete();
      await pending;
      await tester.pumpAndSettle();
      expect(app.repository.selected!.draftReferences, isEmpty);
      expect(tester.widget<TextField>(composer).controller!.text, '@new query');
      expect(app.updates, 0);
    },
  );

  testWidgets(
    'load more keeps one frozen search and accumulates unique results',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture(customSkills: 30);
      await mountAgentUi(tester, app.view());
      await type(tester, '@custom');
      expect(
        tester.widget<AgentReferencePicker>(picker).result.choices,
        hasLength(8),
      );
      for (final length in [16, 24, 30]) {
        await tester.widget<AgentReferencePicker>(picker).onLoadMore!();
        await tester.pumpAndSettle();
        final result = tester.widget<AgentReferencePicker>(picker).result;
        expect(result.choices, hasLength(length));
        expect(
          result.choices.map((choice) => choice.key).toSet(),
          hasLength(length),
        );
      }
      expect(tester.widget<AgentReferencePicker>(picker).result.hasMore, false);
      expect(app.searches, 1);
    },
  );

  testWidgets(
    'selecting an earlier attached file atomically attaches it to the draft',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      final attachment = ConversationAttachment(
        id: 'notes',
        name: 'notes.txt',
        mediaType: 'text/plain',
        byteLength: 4,
        digest: 'a' * 64,
      );
      await app.repository.update(
        'conversation',
        (current) => current.copyWith(
          attachments: [attachment],
          messages: [
            ConversationMessage(
              id: 'old-user',
              role: ConversationRole.user,
              text: 'Earlier file',
              createdAt: DateTime.utc(2026, 11, 7),
              attachmentIds: ['notes'],
            ),
          ],
        ),
      );
      await mountAgentUi(tester, app.view());
      await type(tester, '@notes');
      final view = tester.widget<AgentReferencePicker>(picker);
      await view.onSelect(
        view.result.choices.singleWhere(
          (choice) =>
              choice.value.kind == AgentComposerReferenceKind.attachment,
        ),
      );
      await tester.pumpAndSettle();
      expect(app.repository.selected!.draftAttachmentIds, ['notes']);
      expect(
        app.repository.selected!.draftReferences.single.attachmentId,
        'notes',
      );
      final saved = ConversationArchive.decode(app.storage.source!)
          .conversations
          .single;
      expect(saved.draftAttachmentIds, ['notes']);
      expect(saved.draftReferences.single.attachmentId, 'notes');
    },
  );

  testWidgets(
    'removing a chip persists references without changing editable text',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await app.repository.updateDraftReferences('conversation', [
        app.calendarReference,
      ]);
      await mountAgentUi(tester, app.view());
      await type(tester, 'Keep this sentence');
      final widget = tester.widget<AgentReferenceChips>(chips);
      await widget.onRemove!(widget.choices.single);
      await tester.pumpAndSettle();
      expect(app.repository.selected!.draftReferences, isEmpty);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Keep this sentence',
      );
      expect(chips, findsNothing);
    },
  );

  testWidgets('reference search and selection fit the 320px 2x composer', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final app = await fixture();
    await mountAgentUi(
      tester,
      app.view(),
      size: const Size(320, 480),
      scale: 2,
    );
    await type(tester, '@');
    expect(tester.takeException(), isNull);
    final choice = calendar(tester);
    await tester.widget<AgentReferencePicker>(picker).onSelect(choice);
    await tester.pumpAndSettle();
    expect(chips, findsOneWidget);
    expect(
      app.repository.selected!.draftReferences.single.stableKey,
      choice.key,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'accepted reference-only messages retain readonly snapshot chips after the draft clears',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      final reference = AgentComposerReference.resource(
        ref: app.calendarReference.resourceRef!,
        datasetGeneration: 'fixture-data',
        label: 'Saved category name',
      );
      await app.repository.updateDraftReferences('conversation', [reference]);
      await mountAgentUi(tester, app.view());
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await tester.pumpAndSettle();
      expect(app.repository.selected!.draftReferences, isEmpty);
      expect(app.repository.selected!.messages.single.text, isEmpty);
      expect(
        app.repository.selected!.messages.single.contextReferences.single
            .toJson(),
        reference.toJson(),
      );
      final readonly = tester.widget<AgentReferenceChips>(chips);
      expect(readonly.onRemove, isNull);
      expect(readonly.choices.single.value.toJson(), reference.toJson());
      expect(find.text('Saved category name'), findsOneWidget);
      expect(
        tester.widget<InputChip>(find.byType(InputChip)).onDeleted,
        isNull,
      );
      expect(app.validations, 0);

      await app.repository.create(id: 'other', title: 'Other conversation');
      final otherReference = AgentComposerReference.resource(
        ref: reference.resourceRef!,
        datasetGeneration: 'fixture-data',
        label: 'Other saved name',
      );
      await app.repository.update(
        'other',
        (current) => current.copyWith(
          messages: [
            ConversationMessage(
              id: 'sent-0',
              role: ConversationRole.user,
              text: '',
              createdAt: DateTime.utc(2026, 11, 7),
              contextReferences: [otherReference],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved category name'), findsNothing);
      expect(find.text('Other saved name'), findsOneWidget);
      expect(
        tester.widget<AgentReferenceChips>(chips).choices.single.value.toJson(),
        otherReference.toJson(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final text in ['', 'An earlier request']) {
    testWidgets(
      'history keeps readonly reference snapshots with text "$text"',
      (tester) async {
        addTearDown(tester.view.reset);
        final app = await fixture();
        final reference = AgentComposerReference.resource(
          ref: app.calendarReference.resourceRef!,
          datasetGeneration: 'older-data',
          label: 'Historical category name',
        );
        final now = DateTime.utc(2026, 11, 7);
        await app.repository.update(
          'conversation',
          (current) => current.copyWith(
            messages: [
              ConversationMessage(
                id: 'current',
                role: ConversationRole.user,
                text: 'Current request',
                createdAt: now,
              ),
            ],
            historyVersions: [
              ConversationHistoryVersion(
                id: 'history',
                batchId: 'batch',
                createdAt: now,
                messages: [
                  ConversationMessage(
                    id: 'old',
                    role: ConversationRole.user,
                    text: text,
                    createdAt: now,
                    contextReferences: [reference],
                  ),
                ],
                runs: [],
                turns: [],
              ),
            ],
          ),
        );
        await mountAgentUi(tester, app.view());
        expect(find.text(reference.label), findsNothing);
        tester
            .widget<SkedPopupMenuButton<String>>(
              find.byKey(const ValueKey('agent-conversation-menu')),
            )
            .onSelected!
            .call('message-history');
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        await tester.tap(
          find.descendant(of: dialog, matching: find.byType(ExpansionTile)),
        );
        await tester.pumpAndSettle();
        final readonly = tester.widget<AgentReferenceChips>(
          find.descendant(of: dialog, matching: chips),
        );
        expect(readonly.onRemove, isNull);
        expect(readonly.choices.single.value.toJson(), reference.toJson());
        expect(find.text(reference.label), findsOneWidget);
        expect(
          tester
              .widget<InputChip>(
                find.descendant(of: dialog, matching: find.byType(InputChip)),
              )
              .onDeleted,
          isNull,
        );
        expect(app.repository.selected!.draftReferences, isEmpty);
        expect(app.validations, 0);
        await app.repository.create(id: 'other', title: 'Another conversation');
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(find.text(reference.label), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'empty search is explicit and a plain email does not open the picker',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      await type(tester, 'person@example.com');
      expect(picker, findsNothing);
      expect(app.searches, 0);
      await type(tester, '@zzzz-no-matches');
      final l = AppLocalizations.of(tester.element(picker));
      expect(find.text(l.agentReferenceEmpty), findsOneWidget);
    },
  );
}

class _ReferenceFixture {
  _ReferenceFixture({required this.customSkills});
  final int customSkills;
  final storage = UiMemoryStorage();
  late final repository = ConversationRepository(storage: storage);
  late final delegate = _ReferenceDelegate(repository);
  final data = buildInitialAppData(buildDefaultPeriodTimes());
  int searches = 0;
  int validations = 0;
  int updates = 0;
  Future<void> Function()? beforeValidation;

  Future<void> initialize() async {
    await repository.load();
    await repository.create(id: 'conversation', title: 'References');
  }

  AgentComposerReference get calendarReference =>
      AgentComposerReference.resource(
        ref: ResourceRef(
          kind: ResourceKind.calendar,
          id: data.generalMode.schedules.single.id,
        ),
        datasetGeneration: 'fixture-data',
        label: data.generalMode.schedules.single.name,
      );

  AgentComposerReferenceSearch search(String id) =>
      AgentComposerReferenceSearch(
        snapshot: data,
        datasetGeneration: 'fixture-data',
        snapshotRevision: 1,
        conversation: repository.find(id)!,
        skills: SharedSkillLoader(
          loadString: (path) async => File(path).readAsStringSync(),
          registeredTools: {},
          overlays: SkillOverlaySnapshot([
            for (var index = 0; index < customSkills; index++)
              SkillOverlay(
                skill: SkillDescriptor.editable(
                  id: 'custom-$index',
                  title: 'Custom $index',
                  summary: 'Custom fixture',
                  body: 'Instructions',
                  revision: 1,
                ),
                enabled: true,
                builtIn: false,
                body: 'Instructions',
              ),
          ]),
        ),
      );

  Widget view({bool active = true}) => AgentConversationView(
    repository: repository,
    delegate: delegate,
    active: active,
    createReferenceSearch: (id) async {
      searches++;
      return search(id);
    },
    validateReference: (id, reference) async {
      validations++;
      await beforeValidation?.call();
      final validation = await search(id).validate(reference);
      if (!validation.isCurrent) {
        throw const OperationProblem(
          OperationErrorCode.expired,
          'Reference unavailable',
        );
      }
      return validation.currentReference!;
    },
    updateComposerReferences: (id, references, {validate}) async {
      updates++;
      await repository.updateDraftReferences(
        id,
        references,
        validate: validate,
      );
    },
    readDatasetGeneration: () => 'fixture-data',
  );
}

class _ReferenceDelegate extends UiDelegate {
  _ReferenceDelegate(super.repository);

  @override
  Future<void> send(String conversationId, String text) async {
    calls.add('send:$conversationId:$text');
    await repository.update(
      conversationId,
      (current) => current.copyWith(
        messages: [
          ...current.messages,
          ConversationMessage(
            id: 'sent-${current.messages.length}',
            role: ConversationRole.user,
            text: text,
            createdAt: DateTime.utc(2026, 11, 7),
            contextReferences: current.draftReferences,
            attachmentIds: current.draftAttachmentIds,
          ),
        ],
        draft: '',
        draftReferences: [],
        draftAttachmentIds: [],
      ),
    );
  }
}
