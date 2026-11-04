import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/imports/school_web_handoff.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

import '../support/school_import_preparation.dart';
import '../support/workspace_harness.dart';

class _MemoryConversations extends ConversationStorage {
  _MemoryConversations() : super.base();
  String? source;
  bool fail = false;
  Future<void> Function()? beforeSave;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    await beforeSave?.call();
    if (fail) throw StateError('raw secret must not be shown');
    source = value;
  }
}

class _Fixture {
  _Fixture(this.provider, this.repository, this.storage);
  final AppRuntime provider;
  final ConversationRepository repository;
  final _MemoryConversations storage;
  AgentSettings settings = const AgentSettings(
    enabled: true,
    endpoint: 'https://model.example/v1',
    model: 'synthetic-model',
    models: [
      AgentModelConfig(
        id: 'synthetic-model',
        reasoningEfforts: [AgentReasoningEffort.medium],
        defaultReasoningEffort: AgentReasoningEffort.medium,
      ),
    ],
  );
  final starts = <String>[];
  final opened = <String>[];
  final results = <SchoolWebHandoffRouteResult?>[];
  final configurations = <SchoolWebHandoffReadiness>[];
}

Finder get _editor => find.byKey(const ValueKey('school-web-source-editor'));
Finder get _compress => find.byKey(const ValueKey('school-web-compress'));
Finder get _continue => find.byKey(const ValueKey('school-web-handoff'));
String _text(WidgetTester tester) =>
    tester.widget<TextField>(_editor).controller!.text;

Future<_Fixture> _mount(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double scale = 1,
  String content = '<script>discard()</script><table><tr><td>Algebra Monday 08:00</td></tr></table>',
  bool truncated = false,
  AgentSettings? settings,
  SchoolWebContentPreparer? prepare,
  bool inRoute = false,
  bool observeConversationOpen = true,
  Future<void> Function()? initializeHandoff,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final storage = _MemoryConversations();
  final repository = ConversationRepository(storage: storage);
  await repository.load();
  final provider = await workspaceProvider(
    agentConversationStorage: _MemoryConversations(),
  );
  final fixture = _Fixture(provider, repository, storage);
  if (settings != null) fixture.settings = settings;
  addTearDown(() {
    repository.dispose();
    provider.dispose();
  });
  final handoff = SchoolWebHandoffController(
    repository: repository,
    readSettings: () => fixture.settings,
    initialize: initializeHandoff ?? () async {},
    startHandoff: (id) async {
      fixture.starts.add(id);
    },
    readGeneration: () => 'review-generation',
  );
  final page = SchoolHtmlImportPage(
    initialContent: content,
    initialUrl:
        'https://student:secret@school.test/timetable?token=secret#login',
    initialTitle: 'School timetable',
    initialContentTruncated: truncated,
    initialDatasetGeneration: 'review-generation',
    initialCapturedAt: DateTime.utc(2026, 10, 30),
    showReturnToWebPageButton: inRoute,
    contentPreparer: prepare ?? prepareSchoolImportContentForTest,
    handoffController: handoff,
    openConversation: observeConversationOpen
        ? (context, id) async {
            fixture.opened.add(id);
          }
        : null,
    openConfiguration: (context, readiness) async {
      fixture.configurations.add(readiness);
      fixture.settings = const AgentSettings(
        enabled: true,
        endpoint: 'https://model.example/v1',
        model: 'synthetic-model',
        models: [
          AgentModelConfig(
            id: 'synthetic-model',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      );
    },
  );
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      textScale: scale,
      home: inRoute
          ? Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push<SchoolWebHandoffRouteResult>(
                        MaterialPageRoute<SchoolWebHandoffRouteResult>(
                          builder: (_) => page,
                        ),
                      )
                      .then(fixture.results.add),
                  child: const Text('Open source'),
                ),
              ),
            )
          : page,
    ),
  );
  await tester.pumpAndSettle();
  if (inRoute) {
    await tester.tap(find.text('Open source'));
    await tester.pumpAndSettle();
  }
  return fixture;
}

Future<void> _press(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'desktop handoff returns its durable conversation to the source caller',
    (tester) async {
      final fixture = await _mount(
        tester,
        inRoute: true,
        observeConversationOpen: false,
        size: const Size(1280, 900),
      );
      await _press(tester, _compress);
      final reviewed = _text(tester);
      await _press(tester, _continue);
      final result = fixture.results.single!;
      final saved = ConversationArchive.decode(fixture.storage.source!);
      expect(result.conversationId, saved.conversations.single.id);
      expect(saved.conversations.single.sources.single.text, reviewed);
      expect(fixture.starts, [result.conversationId]);
      expect(fixture.repository.conversations, hasLength(1));
      expect(fixture.opened, isEmpty);
      expect(find.byType(SchoolHtmlImportPage), findsNothing);
      expect(find.text('Open source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'failed route handoff keeps the source and returns success once on retry',
    (tester) async {
      final fixture = await _mount(
        tester,
        inRoute: true,
        observeConversationOpen: false,
      );
      await _press(tester, _compress);
      final reviewed = _text(tester);
      fixture.storage.fail = true;
      await _press(tester, _continue);
      expect(fixture.results, isEmpty);
      expect(fixture.starts, isEmpty);
      expect(_text(tester), reviewed);
      fixture.storage.fail = false;
      await fixture.repository.load();
      await tester.ensureVisible(_continue);
      await tester.tap(_continue);
      await tester.tap(_continue, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fixture.results, hasLength(1));
      expect(fixture.repository.conversations, hasLength(1));
      expect(fixture.starts, [fixture.results.single!.conversationId]);
      expect(find.text('Open source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'return during handoff initialization produces no success result',
    (tester) async {
      final initialized = Completer<void>();
      final fixture = await _mount(
        tester,
        inRoute: true,
        observeConversationOpen: false,
        initializeHandoff: () => initialized.future,
      );
      await _press(tester, _compress);
      await tester.ensureVisible(_continue);
      await tester.tap(_continue);
      await tester.pump();
      final l = AppLocalizations.of(tester.element(_editor));
      await tester.tap(find.text(l.schoolHtmlImportReturnToWebPage));
      await tester.pumpAndSettle();
      initialized.complete();
      await tester.pumpAndSettle();
      expect(fixture.results, [null]);
      expect(fixture.repository.conversations, isEmpty);
      expect(fixture.starts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accepted source handoff completes its own covered route and retains a newer editor',
    (tester) async {
      final fixture = await _mount(
        tester,
        inRoute: true,
        observeConversationOpen: false,
      );
      await _press(tester, _compress);
      final saving = Completer<void>();
      final saved = Completer<void>();
      fixture.storage.beforeSave = () async {
        saving.complete();
        await saved.future;
      };
      final editorController = TextEditingController();
      final editorFocus = FocusNode();
      addTearDown(editorController.dispose);
      addTearDown(editorFocus.dispose);
      final navigator = Navigator.of(tester.element(_editor));
      await tester.ensureVisible(_continue);
      await tester.tap(_continue);
      await saving.future;
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: TextField(
              key: const ValueKey('newer-school-editor'),
              controller: editorController,
              focusNode: editorFocus,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('newer-school-editor')),
        'Retain this draft',
      );
      saved.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('newer-school-editor')).hitTestable(),
        findsOneWidget,
      );
      expect(editorController.text, 'Retain this draft');
      expect(editorFocus.hasFocus, isTrue);
      expect(
        find.byType(SchoolHtmlImportPage, skipOffstage: false),
        findsNothing,
      );
      expect(
        fixture.results.single!.conversationId,
        fixture.repository.conversations.single.id,
      );
      expect(fixture.starts, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('review and handoff remain reachable at $scale×', (
        tester,
      ) async {
        final fixture = await _mount(
          tester,
          scale: scale,
          size: platform == TargetPlatform.android
              ? const Size(393, 852)
              : const Size(1280, 900),
        );
        expect(tester.widget<FilledButton>(_continue).onPressed, isNull);
        expect(find.text('https://school.test/timetable'), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
        await _press(tester, _compress);
        expect(_text(tester), contains('Algebra'));
        expect(_text(tester), contains('<table>'));
        expect(_text(tester), isNot(contains('<script>')));
        await _press(tester, _continue);
        expect(fixture.repository.conversations.length, 1);
        expect(fixture.starts.length, 1);
        expect(fixture.opened, fixture.starts);
        expect(
          fixture.repository.conversations.single.sources.single.text,
          _text(tester),
        );
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }

  testWidgets('disabled Agent retains the source through configuration', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      settings: const AgentSettings(enabled: false),
    );
    await _press(tester, _compress);
    final reviewed = _text(tester);
    await _press(tester, _continue);
    expect(fixture.configurations, [SchoolWebHandoffReadiness.disabled]);
    expect(fixture.repository.conversations, isEmpty);
    expect(_text(tester), reviewed);
    await _press(tester, _continue);
    expect(
      fixture.repository.conversations.single.sources.single.text,
      reviewed,
    );
  });

  testWidgets('plan mode parses a source without applying a timetable', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      settings: const AgentSettings(
        enabled: true,
        endpoint: 'https://model.example/v1',
        model: 'synthetic-model',
        permissionMode: AgentPermissionMode.plan,
        models: [
          AgentModelConfig(
            id: 'synthetic-model',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
    );
    final before = fixture.provider.session.data.toJson();
    await _press(tester, _compress);
    await _press(tester, _continue);
    expect(
      fixture.repository.conversations.single.mode,
      AgentPermissionMode.plan,
    );
    expect(fixture.provider.session.data.toJson(), before);
  });

  testWidgets(
    'failed handoff preserves the draft and retries without duplication',
    (tester) async {
      final fixture = await _mount(tester);
      await _press(tester, _compress);
      final reviewed = _text(tester);
      fixture.storage.fail = true;
      await _press(tester, _continue);
      expect(fixture.starts, isEmpty);
      expect(_text(tester), reviewed);
      expect(find.textContaining('raw secret'), findsNothing);
      fixture.storage.fail = false;
      await fixture.repository.load();
      await _press(tester, _continue);
      await _press(tester, _continue);
      expect(fixture.repository.conversations.length, 1);
      expect(fixture.repository.conversations.single.messages.length, 1);
    },
  );

  testWidgets('edits require compression again and keep capture truncation', (
    tester,
  ) async {
    final fixture = await _mount(tester, truncated: true);
    final l10n = AppLocalizations.of(tester.element(_editor));
    expect(find.text(l10n.schoolImportContentTruncated), findsOneWidget);
    await _press(tester, _compress);
    await tester.enterText(_editor, '${_text(tester)}\nA correction');
    await tester.pump();
    expect(tester.widget<FilledButton>(_continue).onPressed, isNull);
    await _press(tester, _compress);
    await _press(tester, _continue);
    expect(
      fixture.repository.conversations.single.sources.single.truncated,
      isTrue,
    );
  });

  testWidgets('bounded source input keeps surrogate pairs intact', (
    tester,
  ) async {
    await _mount(tester, content: '');
    await tester.enterText(
      _editor,
      '😀' * (SchoolImportContentSanitizer.maxInputLength ~/ 2 + 1),
    );
    await tester.pump();
    expect(
      _text(tester).length,
      lessThanOrEqualTo(SchoolImportContentSanitizer.maxInputLength),
    );
    expect(
      _text(tester).runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff),
      isFalse,
    );
  });

  testWidgets('return during preparation accepts no late handoff', (
    tester,
  ) async {
    final prepared = Completer<SchoolImportSanitizationResult>();
    final fixture = await _mount(
      tester,
      inRoute: true,
      prepare: (_) => prepared.future,
    );
    await tester.ensureVisible(_compress);
    await tester.tap(_compress);
    await tester.pump();
    final l10n = AppLocalizations.of(tester.element(_editor));
    final back = find.text(l10n.schoolHtmlImportReturnToWebPage);
    await tester.tap(back);
    await tester.tap(back, warnIfMissed: false);
    await tester.pump();
    prepared.complete(
      SchoolImportContentSanitizer.sanitizeWithResult('Algebra'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open source'), findsOneWidget);
    expect(fixture.starts, isEmpty);
    expect(fixture.repository.conversations, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
