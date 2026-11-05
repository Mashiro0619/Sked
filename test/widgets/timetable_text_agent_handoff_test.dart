import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/settings_commands.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/controllers/workspace_commands.dart';
import 'package:sked/controllers/workspace_view_state.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/school_html_import_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

import '../support/memory_conversation_storage.dart';
import '../support/notification_test_scope.dart';
import '../support/workspace_harness.dart';

const _source =
    '  Monday periods 3, 4: Algebra, weeks 1-16.\n'
    'Semester starts 2026-09-07.  ';
Finder _key(String name) => find.byKey(ValueKey(name));
Finder get _textEditor => find.descendant(
  of: find.byType(TextImportPage),
  matching: find.byType(TextField),
);
Finder get _reviewEditor => _key('school-web-source-editor');

class _Conversations extends MemoryConversationStorage {
  bool fail = false;
  Future<void> Function()? beforeSave;

  @override
  Future<void> save(String value, {required int revision}) async {
    await beforeSave?.call();
    if (fail) throw StateError('Synthetic handoff storage failure');
    await super.save(value, revision: revision);
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
    // The real runtime accepts the reviewed source, but this fixture never
    // requests a mutation or accesses an external endpoint.
    yield ProviderCompleted(
      ProviderResponse(
        text: 'Please confirm the period times before importing.',
        toolCalls: const [],
        finishReason: 'stop',
      ),
    );
  }
}

class _Fixture {
  _Fixture(this.app, this.provider, this.storage);
  final AppRuntime app;
  final _Provider provider;
  final _Conversations storage;
  late NavigatorState navigator;
  late ModalRoute<dynamic> rootRoute;

  Widget build(BuildContext context) {
    navigator = Navigator.of(context);
    rootRoute = ModalRoute.of(context)!;
    return Consumer2<WorkspaceViewState, SettingsViewState>(
      builder: (_, workspace, settings, _) => AdaptiveSkedShell(
        workspace: workspace,
        workspaces: context.read<WorkspaceCommands>(),
        settings: settings,
        settingsCommands: context.read<SettingsCommands>(),
        activeMode: workspace.activeMode,
        onOpenSettings: () => navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SettingsPage(
              packageInfoLoader: () async => PackageInfo(
                appName: 'Sked',
                packageName: 'com.mashiro.sked.text-handoff-test',
                version: '3.0.0',
                buildNumber: '1',
              ),
              updateDistribution: const UpdateDistribution(
                UpdateChannel.github,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool enabled = true,
}) async {
  final storage = _Conversations();
  final provider = _Provider();
  final app = await workspaceProvider(
    storage: WorkspaceMemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
    ),
    agentConversationStorage: storage,
    agentProvider: provider,
  );
  await app.agent.configure(
    const AgentSettings(
      endpoint: 'https://synthetic.invalid/v1',
      model: 'synthetic',
      models: [
        AgentModelConfig(
          id: 'synthetic',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
    ),
  );
  await app.agent.setEnabled(enabled);
  final fixture = _Fixture(app, provider, storage);
  addTearDown(() async {
    storage.fail = false;
    storage.beforeSave = null;
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: app,
      home: Builder(builder: fixture.build),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openText(WidgetTester tester, {bool settings = false}) async {
  if (settings) {
    Finder settingsButton() {
      for (final name in [
        'workspace-resource-settings',
        'adaptive-shell-settings-action',
        'student-settings-button',
      ]) {
        final entry = _key(name).hitTestable();
        if (entry.evaluate().isNotEmpty) return entry.first;
      }
      return _key('missing-settings-entry');
    }

    if (settingsButton().evaluate().isEmpty) {
      await _tap(tester, _key('workspace-main-navigation'));
    }
    await _tap(tester, settingsButton());
    final studentTransfer = _key('settings-student-transfer');
    await tester.scrollUntilVisible(
      studentTransfer,
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('settings-overview-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _tap(tester, studentTransfer);
    await _tap(
      tester,
      _key('transfer-action-SettingsStudentDataAction.importTimetablesText'),
    );
  } else {
    await _tap(tester, _key('empty-timetable-import-button'));
    await _tap(tester, _key('empty-timetable-import-text'));
  }
  expect(find.byType(TextImportPage), findsOneWidget);
  await tester.enterText(_textEditor, _source);
}

Future<void> _review(WidgetTester tester) async {
  await _tap(tester, _key('text-import-secondary-action'));
  expect(find.byType(SchoolHtmlImportPage), findsOneWidget);
  expect(tester.widget<TextField>(_reviewEditor).controller!.text, _source);
}

Future<void> _prepare(WidgetTester tester) async {
  final compress = _key('school-web-compress');
  await tester.ensureVisible(compress);
  await tester.pumpAndSettle();
  // Exercise the production isolate, waiting for the actual prepared state.
  await tester.runAsync(() async {
    await tester.tap(compress);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
      if (tester.widget<FilledButton>(_key('school-web-handoff')).onPressed !=
          null) {
        return;
      }
    }
    fail('The production content preparation did not complete.');
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpNotificationTestPlatform();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

  for (final settings in [false, true]) {
    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      testWidgets(
        '${settings ? 'settings' : 'home'} text handoff returns to root chat at ${size.width}',
        (tester) async {
          final fixture = await _mount(tester, size: size);
          final data = fixture.app.session.committedData.studentMode.toJson();
          await _openText(tester, settings: settings);
          await _review(tester);
          expect(fixture.provider.requests, isEmpty);
          expect(fixture.app.agent.conversations.conversations, isEmpty);
          await _prepare(tester);
          expect(fixture.provider.requests, isEmpty);
          expect(fixture.app.session.committedData.studentMode.toJson(), data);
          final reviewed = tester
              .widget<TextField>(_reviewEditor)
              .controller!
              .text
              .trim();
          await _tap(tester, _key('school-web-handoff'));
          await fixture.app.agent.runtime.waitForIdle();
          await tester.pumpAndSettle();

          final conversation =
              fixture.app.agent.conversations.conversations.single;
          final l = AppLocalizations.of(tester.element(_key('agent-composer')));
          expect(conversation.sources.single.text, reviewed);
          expect(
            conversation.sources.single.provenance!.title,
            l.importTimetableText,
          );
          expect(conversation.messages.first.text, l.schoolWebAgentImportTask);
          expect(fixture.provider.requests, hasLength(1));
          expect(fixture.app.session.committedData.studentMode.toJson(), data);
          expect(fixture.rootRoute.isCurrent, isTrue);
          expect(fixture.navigator.canPop(), isFalse);
          expect(_key('agent-composer').hitTestable(), findsOneWidget);
          expect(
            find.byType(TextImportPage, skipOffstage: false),
            findsNothing,
          );
          expect(
            find.byType(SchoolHtmlImportPage, skipOffstage: false),
            findsNothing,
          );
          expect(find.byType(SettingsPage, skipOffstage: false), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('cancelled review retains exact original text and JSON import', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    final data = fixture.app.session.committedData.studentMode.toJson();
    await _openText(tester, settings: true);
    await _review(tester);
    await tester.enterText(_reviewEditor, 'Edited only in review');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_textEditor).controller!.text, _source);
    final l = AppLocalizations.of(tester.element(_textEditor));
    await _tap(
      tester,
      find.widgetWithText(FilledButton, l.timetableImportJsonAction),
    );
    expect(find.text(l.importFailedCheckContent), findsOneWidget);
    expect(tester.widget<TextField>(_textEditor).controller!.text, _source);
    expect(fixture.provider.requests, isEmpty);
    expect(fixture.app.agent.conversations.conversations, isEmpty);
    expect(fixture.app.session.committedData.studentMode.toJson(), data);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed handoff retains both drafts until storage recovery', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _openText(tester);
    await _review(tester);
    await _prepare(tester);
    final reviewed = tester.widget<TextField>(_reviewEditor).controller!.text;
    fixture.storage.fail = true;
    await _tap(tester, _key('school-web-handoff'));
    expect(find.byType(SchoolHtmlImportPage), findsOneWidget);
    expect(tester.widget<TextField>(_reviewEditor).controller!.text, reviewed);
    final original = find.descendant(
      of: find.byType(TextImportPage, skipOffstage: false),
      matching: find.byType(TextField, skipOffstage: false),
      skipOffstage: false,
    );
    expect(tester.widget<TextField>(original).controller!.text, _source);
    expect(fixture.provider.requests, isEmpty);
    expect(fixture.app.agent.conversations.conversations, isEmpty);
    fixture.storage.fail = false;
    // A failed durable write deliberately closes the repository gate. The
    // continuation must not bypass recovery or invent a successful handoff.
    await fixture.app.agent.conversations.load();
    await _tap(tester, _key('school-web-handoff'));
    await fixture.app.agent.runtime.waitForIdle();
    await tester.pumpAndSettle();
    expect(fixture.app.agent.conversations.conversations, hasLength(1));
    expect(fixture.provider.requests, hasLength(1));
    expect(_key('agent-composer').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled Agent still permits local review without enabling it', (
    tester,
  ) async {
    final fixture = await _mount(tester, enabled: false);
    await _openText(tester);
    await _review(tester);
    await _prepare(tester);
    expect(fixture.app.agent.settings.enabled, isFalse);
    expect(fixture.provider.requests, isEmpty);
    expect(fixture.app.agent.conversations.conversations, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_textEditor).controller!.text, _source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('original JSON action imports without creating an Agent task', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _openText(tester, settings: true);
    final l = AppLocalizations.of(tester.element(_textEditor));
    final timeSet = fixture.app.studentView.periodTimeSets.first;
    final source = encodeTimetableDataEnvelope(
      TimetableExportData(
        timetables: [
          TimetableData(
            id: 'synthetic-incoming',
            config: TimetableConfig(
              name: 'JSON imported timetable',
              startDate: DateTime(2026, 9, 7),
              totalWeeks: 18,
              periodTimeSetId: timeSet.id,
            ),
            courses: const [],
          ),
        ],
        periodTimeSets: [timeSet],
      ),
    );
    await tester.enterText(_textEditor, source);
    final submit = find.widgetWithText(
      FilledButton,
      l.timetableImportJsonAction,
    );
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.widgetWithText(FilledButton, l.importBundledPeriodTimeSets),
    );
    await tester.pumpAndSettle();
    expect(
      fixture.app.studentView.timetables.single.config.name,
      'JSON imported timetable',
    );
    expect(find.byType(TextImportPage, skipOffstage: false), findsNothing);
    expect(
      find.byType(SchoolHtmlImportPage, skipOffstage: false),
      findsNothing,
    );
    expect(fixture.provider.requests, isEmpty);
    expect(fixture.app.agent.conversations.conversations, isEmpty);
    expect(find.byType(AgentPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted handoff does not replace a newer destination', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _openText(tester);
    await _review(tester);
    await _prepare(tester);
    final started = Completer<void>();
    final release = Completer<void>();
    fixture.storage.beforeSave = () async {
      if (!started.isCompleted) started.complete();
      await release.future;
    };
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    await tester.ensureVisible(_key('school-web-handoff'));
    await tester.pumpAndSettle();
    await tester.tap(_key('school-web-handoff'));
    await tester.pump();
    await started.future;
    unawaited(
      fixture.navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            key: ValueKey('text-handoff-newer-destination'),
            body: Text('Newer destination retains navigation'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final newer = tester.element(_key('text-handoff-newer-destination'));
    release.complete();
    await tester.pumpAndSettle();
    await fixture.app.agent.runtime.waitForIdle();
    await tester.pumpAndSettle();
    expect(tester.element(_key('text-handoff-newer-destination')), same(newer));
    expect(fixture.app.agent.conversations.conversations, hasLength(1));
    expect(fixture.provider.requests, hasLength(1));
    expect(find.byType(TextImportPage, skipOffstage: false), findsNothing);
    expect(
      find.byType(SchoolHtmlImportPage, skipOffstage: false),
      findsNothing,
    );
    expect(find.byType(AgentPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new data session retires text and review without a handoff', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _openText(tester);
    await _review(tester);
    final reservation = fixture.app.maintenance.reserve();
    fixture.app.maintenance.release(reservation);
    await tester.pumpAndSettle();
    expect(find.byType(TextImportPage, skipOffstage: false), findsNothing);
    expect(
      find.byType(SchoolHtmlImportPage, skipOffstage: false),
      findsNothing,
    );
    expect(fixture.rootRoute.isCurrent, isTrue);
    expect(fixture.provider.requests, isEmpty);
    expect(fixture.app.agent.conversations.conversations, isEmpty);
    expect(find.byType(AgentPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
