import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/services/export_service.dart';
import 'package:sked/widgets/assistant_pane.dart';

import '../../support/workspace_harness.dart';
import '../../support/agent_native_fixture.dart';
import '../../support/agent_workspace_navigation.dart';

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      fail('Timed out waiting for $reason');
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  await tester.pump();
}

Future<void> _complete(
  WidgetTester tester,
  Future<void> future,
  String reason,
) async {
  var done = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    future.then(
      (_) => done = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        done = true;
      },
    ),
  );
  await _until(tester, () => done, reason);
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}

class _Exports extends ExportService {
  final payloads = <ExportPayload>[];
  ExportSaveStatus status = ExportSaveStatus.saved;

  @override
  Future<ExportSaveResult> saveFile(ExportPayload payload) async {
    payloads.add(payload);
    return ExportSaveResult(
      status: status,
      path: status == ExportSaveStatus.saved ? 'memory://export.json' : null,
    );
  }
}

void main() {
  late AppRuntime app;
  late MemoryAgentCore native;
  late _Exports exports;
  late WidgetTester activeTester;
  var call = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    native = MemoryAgentCore();
    app = await workspaceProvider(
      mode: AppMode.general,
      agentNativeClient: native.client,
    );
    // These UI binding cases own their Dart business scopes directly.
    // Native preparation acknowledgements are checked by the offline journey.
    app.agent.tools.onOperationPrepared = null;
    app.agent.tools.onOperationUpdate = null;
    await app.lifecycle.completeFirstLaunch(
      AppMode.general,
      hideWorkspaceNavigation: false,
    );
    exports = _Exports();
    call = 0;
  });
  tearDown(() {
    app.dispose();
  });

  Future<Map<String, Object?>> tool(
    String name,
    Map<String, Object?> args,
  ) async {
    Map<String, Object?>? result;
    Object? failure;
    StackTrace? failureStack;
    await activeTester.runAsync(() async {
      await app.agent.initialize();
      final scope = OperationScope(
        id: 'ui-host-${++call}',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      );
      try {
        result = await app.agent.tools.execute(
          ProviderToolCall(
            id: 'host-call-$call',
            name: name,
            arguments: jsonEncode(args),
          ),
          scope,
          (_) => throw StateError('Full mode must not request approval.'),
        );
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
      } finally {
        app.agent.tools.finishScope(scope);
        app.agent.external.discardScope(scope);
        scope.cancel();
      }
    });
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    return result!;
  }

  Future<void> mount(WidgetTester tester) async {
    activeTester = tester;
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: app,
        home: AppHomeScreen(agentExportService: exports),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<String> openRunningFullWorkspace(WidgetTester tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.25;
    tester.view.physicalSize = const Size(1582, 853);
    await tester.runAsync(() async {
      await app.agent.configure(
        app.agent.settings.copyWith(
          enabled: true,
          endpoint: 'https://workspace-return.invalid/v1',
          model: 'return-fixture',
          models: const [
            AgentModelConfig(
              id: 'return-fixture',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
      );
      final initial = nativeConversationFixture(
        id: 'ui-running-history',
        title: 'Return to the full workspace',
        messages: [
          for (var index = 0; index < 16; index++)
            ViewMessage(
              id: 'host-history-$index',
              role: index.isEven
                  ? ViewMessageRole.user
                  : ViewMessageRole.assistant,
              text:
                  'Synthetic history $index. ${List.filled(4, 'This is a local reading-position fixture. It contains no personal schedule or credentials.').join(' ')}',
              createdAt: DateTime.utc(
                2026,
                1,
                1,
                12,
                index,
              ).millisecondsSinceEpoch,
              toolCalls: const [],
              responseItems: const [],
              attachmentIds: const [],
              contextReferences: const [],
              attachmentDelivery: ViewAttachmentDelivery.local,
            ),
        ],
      );
      final value = initial.conversation;
      native.snapshots[value.id] = copyNativeSnapshot(
        initial,
        conversation: ViewConversation(
          id: value.id,
          title: value.title,
          titleWasEdited: false,
          pinned: false,
          archived: false,
          draftOnly: false,
          createdAt: value.createdAt,
          updatedAt: value.updatedAt,
          mode: ViewPermissionMode.ask,
          status: ViewConversationStatus.running,
          draft: '',
          draftAttachmentIds: const [],
          draftReferences: const [],
          executionHistoryStart: 0,
          runId: 'ui-running',
        ),
      );
      native.selectedId = value.id;
      native.presentations[value.id] = const RunPresentation(
        active: true,
        canContinue: false,
        compacting: false,
      );
      app.agent.runtime.ingestState(
        nativeStateFixture(native.snapshots[value.id]!),
        presentation: native.presentations[value.id],
      );
      await app.agent.conversations.load();
      // The bundle caches Futures across tests. Load the real catalog outside
      // FakeAsync so later host tools can await the same cached asset.
      await app.agent.knowledge.initialize();
    });
    await mount(tester);
    await tester.tap(key('workspace-agent-entry'));
    await _until(
      tester,
      () => key('agent-composer').hitTestable().evaluate().isNotEmpty,
      'the running composer to become interactive',
    );
    final id = app.agent.conversations.selectedId!;
    expect(app.agent.runtime.state.value.runFor(id).isActive, isTrue);
    await tester.enterText(
      key('agent-composer'),
      'Keep the full workspace draft.',
    );
    await _until(
      tester,
      () =>
          app.agent.conversations.find(id)?.draft ==
          'Keep the full workspace draft.',
      'the native draft projection',
    );
    expect(find.byType(AgentPage), findsOneWidget);
    expect(
      tester.widget<TextField>(key('agent-composer')).controller!.text,
      'Keep the full workspace draft.',
    );
    await tester.enterText(
      key('agent-composer'),
      'Edited in the full workspace.',
    );
    await _until(
      tester,
      () =>
          app.agent.conversations.find(id)?.draft ==
          'Edited in the full workspace.',
      'the edited native draft projection',
    );
    return id;
  }

  Future<void> backFromFullWorkspace(WidgetTester tester) async {
    await selectAgentShellDestination(
      tester,
      app.workspaceView.activeMode.value,
    );
    await _until(
      tester,
      () => find.byType(AgentPage).evaluate().isEmpty,
      'the business workspace to replace the Agent page',
    );
    expect(find.byType(AgentPage), findsNothing);
  }

  Future<void> finishAndUnmount(WidgetTester tester) async {
    await _complete(
      tester,
      app.agent.quiesce(),
      'the actual runtime to quiesce',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sidebar reopens the running Agent view with its draft and reading position',
    (tester) async {
      try {
        final id = await openRunningFullWorkspace(tester);
        await tester.drag(key('agent-transcript-$id'), const Offset(0, 620));
        await _until(
          tester,
          () => !tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: key('agent-transcript-$id'),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position
              .isScrollingNotifier
              .value,
          'transcript scrolling to finish',
        );
        final reading = tester
            .widget<AgentTranscript>(find.byType(AgentTranscript))
            .position;
        expect(reading.followLatest, isFalse);
        final anchor = reading.anchor;
        expect(anchor, isNotNull);
        await backFromFullWorkspace(tester);
        expect(find.byType(AgentAssistantPane), findsNothing);
        expect(key('agent-composer'), findsNothing);
        tester.view.physicalSize = const Size(1062, 853);
        await tester.pump();
        await _until(
          tester,
          () =>
              key('workspace-agent-entry').hitTestable().evaluate().isNotEmpty,
          'the resized sidebar entry',
        );
        await tester.tap(key('workspace-agent-entry'));
        await _until(
          tester,
          () => key('agent-composer').hitTestable().evaluate().isNotEmpty,
          'the reopened composer',
        );
        expect(key('agent-composer').hitTestable(), findsOneWidget);
        final reopenedReading = tester
            .widget<AgentTranscript>(find.byType(AgentTranscript))
            .position;
        expect(reopenedReading, same(reading));
        expect(reopenedReading.followLatest, isFalse);
        expect(reopenedReading.anchor, anchor);
        expect(app.agent.conversations.selectedId, id);
        expect(
          tester.widget<TextField>(key('agent-composer')).controller!.text,
          'Edited in the full workspace.',
        );
        expect(
          app.agent.conversations.find(id)!.draft,
          'Edited in the full workspace.',
        );
        expect(app.agent.runtime.state.value.runFor(id).isActive, isTrue);
        expect(
          native.commands.where((command) => command.kind == CommandKind.send),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await finishAndUnmount(tester);
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'navigation host selects the requested course and opens its actual stored detail',
    (tester) async {
      await mount(tester);
      final timetable = app.session.committedData.studentMode.timetables
          .firstWhere((t) => t.courses.isNotEmpty);
      final course = timetable.courses.first;
      final result = await tool('navigation.open', {
        'workspace': 'student',
        'ref': {'kind': 'course', 'id': course.id, 'parentId': timetable.id},
        'week': 2,
      });
      await tester.pumpAndSettle();
      expect(result['effectStatus'], 'applied');
      expect(app.session.committedData.activeMode, AppMode.student);
      expect(
        app.session.committedData.studentMode.activeTimetableId,
        timetable.id,
      );
      expect(app.studentView.selectedWeek, 2);
      expect(find.byType(AgentResourceView), findsOneWidget);
      expect(find.text(course.name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'out-of-range navigation fails without changing workspace or selected week',
    (tester) async {
      await mount(tester);
      final before = app.session.committedData;
      final timetable = before.studentMode.timetables.first;
      final selectedWeek = app.studentView.selectedWeek;
      final result = await tool('navigation.open', {
        'workspace': 'student',
        'ref': {'kind': 'timetable', 'id': timetable.id},
        'week': timetable.config.totalWeeks + 1,
      });
      expect(result['effectStatus'], isNot('applied'));
      expect(app.session.committedData.activeMode, before.activeMode);
      expect(app.studentView.selectedWeek, selectedWeek);
      expect(find.byType(AgentResourceView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final studentEnabled in [false, true]) {
    testWidgets(
      'developer sample uses the real home binding and preserves ${studentEnabled ? 'existing objects in both workspaces' : 'the disabled student workspace'}',
      (tester) async {
        await mount(tester);
        await tester.runAsync(
          () => app.workspaces.setEnabled(AppMode.student, studentEnabled),
        );
        await tester.pumpAndSettle();
        final before = app.session.committedData;
        final language = studentEnabled ? 'english' : 'simplifiedChinese';
        if (studentEnabled) {
          await expectLater(
            tool('developer.sample.apply', {
              'language': 'unregistered-language',
            }),
            throwsA(
              isA<OperationProblem>().having(
                (error) => error.code,
                'code',
                OperationErrorCode.invalidArgument,
              ),
            ),
          );
          expect(app.session.committedData.encode(), before.encode());
        }
        final result = await tool('developer.sample.apply', {
          'language': language,
        });
        expect(result['effectStatus'], 'applied');
        expect(result['dataStatus'], 'committed');
        final after = app.session.committedData;
        final oldTables = before.studentMode.timetables
            .map((table) => table.toJson())
            .toList();
        final oldCalendars = before.generalMode.schedules
            .map((calendar) => calendar.toJson())
            .toList();
        expect(after.enabledWorkspaces, before.enabledWorkspaces);
        expect(after.activeMode, before.activeMode);
        expect(after.generalMode.schedules, hasLength(oldCalendars.length + 3));
        expect(
          after.generalMode.schedules
              .take(oldCalendars.length)
              .map((calendar) => calendar.toJson())
              .toList(),
          oldCalendars,
        );
        final newCalendars = after.generalMode.schedules
            .skip(oldCalendars.length)
            .toList();
        expect(
          newCalendars.every((calendar) => calendar.events.isNotEmpty),
          isTrue,
        );
        expect(after.generalMode.activeScheduleId, newCalendars.first.id);
        expect(
          result['effectResult'],
          containsPair('calendarId', newCalendars.first.id),
        );
        if (studentEnabled) {
          expect(after.studentMode.timetables, hasLength(oldTables.length + 1));
          expect(
            after.studentMode.timetables
                .take(oldTables.length)
                .map((table) => table.toJson())
                .toList(),
            oldTables,
          );
          final added = after.studentMode.timetables.last;
          expect(added.config.name, 'Sample timetable');
          expect(added.courses, isNotEmpty);
          expect(after.studentMode.activeTimetableId, added.id);
          expect(result['effectResult'], containsPair('timetableId', added.id));
        } else {
          expect(after.studentMode.toJson(), before.studentMode.toJson());
        }
        final recorded = await tool('operations.status', {
          'operationId': result['operationId'],
        });
        expect(recorded['operationId'], result['operationId']);
        expect(recorded['effectStatus'], 'applied');
        expect(app.session.committedData.encode(), after.encode());
        await tester.pumpWidget(const SizedBox());
        final loaded = await tester.runAsync(
          () => app.session.repository.load(),
        );
        expect(loaded!.encode(), after.encode());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'file destination cancellation stays explicit and an unmounted host rejects new saves',
    (tester) async {
      await mount(tester);
      final id = app.session.committedData.studentMode.timetables.first.id;
      Future<Map<String, Object?>> write({bool unmount = false}) async {
        late Completer<void> generated;
        late Completer<void> proceed;
        late Future<Map<String, Object?>> running;
        Object? failure;
        StackTrace? failureStack;
        await tester.runAsync(() async {
          generated = Completer<void>();
          proceed = Completer<void>();
          await app.agent.initialize();
          final scope = OperationScope(
            id: 'ui-export-${++call}',
            policy: OperationPolicy(
              enabled: true,
              mode: AgentPermissionMode.full,
            ),
          );
          Future<MutationApproval?> ask(Object _) async =>
              throw StateError('Full mode must not request approval.');
          running = (() async {
            try {
              final artifact = await app.agent.tools.execute(
                ProviderToolCall(
                  id: 'generate-${++call}',
                  name: 'exports.generate',
                  arguments: jsonEncode({
                    'format': 'timetables_json',
                    'ids': [id],
                  }),
                ),
                scope,
                ask,
              );
              generated.complete();
              await proceed.future;
              return await app.agent.tools.execute(
                ProviderToolCall(
                  id: 'write-${++call}',
                  name: 'exports.write',
                  arguments: jsonEncode({'artifactId': artifact['artifactId']}),
                ),
                scope,
                ask,
              );
            } catch (error, stack) {
              failure = error;
              failureStack = stack;
              if (!generated.isCompleted) generated.complete();
              return <String, Object?>{'status': 'failed'};
            } finally {
              app.agent.tools.finishScope(scope);
              app.agent.external.discardScope(scope);
              scope.cancel();
            }
          })();
          await generated.future;
        });
        if (unmount) await tester.pumpWidget(const SizedBox.shrink());
        final result = await tester.runAsync(() {
          proceed.complete();
          return running;
        });
        if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
        return result!;
      }

      exports.status = ExportSaveStatus.cancelled;
      final result = await write();
      expect(result['effectStatus'], 'failed');
      expect(exports.payloads, hasLength(1));
      await expectLater(write(unmount: true), throwsA(isA<OperationProblem>()));
      expect(exports.payloads, hasLength(1));
    },
  );
}
