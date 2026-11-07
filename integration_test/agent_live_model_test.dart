import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/attachments/attachment_storage_io.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/data/app_data_codec.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/services/app_storage_layout_io.dart';

import '../test/support/workspace_harness.dart';

// Explicit native acceptance only. Read connection configuration and copy the
// secure credential slots into an isolated memory vault; all business and
// Agent writes target synthetic data and a test-owned SQLite file.
const _profileFile = String.fromEnvironment('SKED_AGENT_LIVE_PROFILE_FILE');
const _connectionFile = String.fromEnvironment(
  'SKED_AGENT_LIVE_CONNECTION_FILE',
);
const _reportFile = String.fromEnvironment('SKED_AGENT_LIVE_REPORT_FILE');
const _credentialsFile = String.fromEnvironment(
  'SKED_AGENT_LIVE_CREDENTIALS_FILE',
);
const _revision = String.fromEnvironment('SKED_SOURCE_SHA');

Future<MemoryAgentCredentialStore> _readCredentials() async {
  final vault = MemoryAgentCredentialStore();
  if (_credentialsFile.isEmpty) {
    final secure = SecureAgentCredentialStore();
    for (final slot in AgentCredentialSlot.values) {
      await vault.write(slot, await secure.read(slot));
    }
    return vault;
  }
  final privateTemp = await getTemporaryDirectory();
  final root = await privateTemp.resolveSymbolicLinks();
  final file = File(_credentialsFile);
  if (!path.isAbsolute(file.path) ||
      !path.isWithin(root, await file.resolveSymbolicLinks())) {
    throw ArgumentError(
      'The acceptance credential file must be inside this test app\'s temporary directory.',
    );
  }
  try {
    final Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      throw const FormatException('Invalid acceptance credential file.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.any(
          (key) => !AgentCredentialSlot.values.any((slot) => slot.name == key),
        ) ||
        decoded.values.any((value) => value != null && value is! String)) {
      throw const FormatException('Invalid acceptance credential file.');
    }
    for (final slot in AgentCredentialSlot.values) {
      await vault.write(slot, decoded[slot.name] as String?);
    }
    return vault;
  } finally {
    await file.delete();
  }
}

class _ObservedProvider extends ProviderClient {
  final requests = <Map<String, Object?>>[];
  final closed = Completer<void>();

  @override
  void close() {
    if (closed.isCompleted) return;
    super.close();
    closed.complete();
  }

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    final record = <String, Object?>{
      'model': request.model,
      'protocol': request.protocol.name,
      'tools': request.tools.map((tool) => tool.name).toList(),
      'messageCount': request.messages.length,
      'startedAt': DateTime.now().toUtc().toIso8601String(),
    };
    requests.add(record);
    try {
      await for (final event in super.stream(
        request,
        apiKey: apiKey,
        cancellation: cancellation,
      )) {
        if (event is ProviderUsageEvent) {
          record['usage'] = {
            'inputTokens': event.usage.inputTokens,
            'outputTokens': event.usage.outputTokens,
            'totalTokens': event.usage.totalTokens,
          };
        }
        if (event is ProviderCompleted) {
          record['finishReason'] = event.response.finishReason;
          record['toolCalls'] = [
            for (final call in event.response.toolCalls)
              {'id': call.id, 'name': call.name, 'arguments': call.arguments},
          ];
        }
        yield event;
      }
    } on ProviderException catch (error) {
      record['error'] = error.code.name;
      rethrow;
    } finally {
      record['finishedAt'] = DateTime.now().toUtc().toIso8601String();
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real model completes synthetic business tasks and compaction', (
    tester,
  ) async {
    expect(
      _profileFile.isNotEmpty != _connectionFile.isNotEmpty,
      isTrue,
      reason: 'Pass either the existing profile or its isolated AgentSettings JSON.',
    );
    expect(_reportFile, isNotEmpty);
    expect(_revision, matches(RegExp(r'^[a-f0-9]{40}$')));
    await tester.runAsync(() async {
      final sourceFile = File(
        _connectionFile.isEmpty ? _profileFile : _connectionFile,
      );
      final originalBytes = await sourceFile.readAsBytes();
      final connection = _connectionFile.isEmpty
          ? (await AppDataCodec.decodeStorage(originalBytes)).agentSettings
          : AgentSettings.fromJson(jsonDecode(utf8.decode(originalBytes)));
      expect(connection.defaultModelSelection, isNotNull);
      final vault = await _readCredentials();
      final root = await Directory.systemTemp.createTemp('sked-agent-live-');
      final databasePath = '${root.path}${Platform.pathSeparator}agent.sqlite';
      final store = AgentStore.open(filePath: databasePath);
      final provider = _ObservedProvider();
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Sked acceptance',
        packageName: 'com.mashiro.sked.agent_acceptance',
        version: '0',
        buildNumber: '0',
        buildSignature: '',
      );
      final initial =
          buildInitialAppData(
            buildDefaultPeriodTimes(),
            localeCode: 'zh',
          ).copyWith(
            agentSettings: connection.copyWith(
              enabled: true,
              permissionMode: AgentPermissionMode.full,
              systemInstructions: '',
              historyRetentionDays: 0,
              models: [
                for (final model in connection.models)
                  if (model.id == connection.model)
                    AgentModelConfig.fromJson({
                      ...model.toJson(),
                      'autoCompact': true,
                      'autoCompactAtTokens':
                          model.effectiveContextTokens != null &&
                              model.effectiveContextTokens! < 6000
                          ? (model.effectiveContextTokens! * .8).floor()
                          : 6000,
                    })
                  else
                    model,
              ],
            ),
          );
      final mainStorage = WorkspaceMemoryStorage(initial);
      final app = await workspaceProvider(
        locale: 'zh',
        storage: mainStorage,
        agentStore: store,
        agentCredentialStore: vault,
        agentProvider: provider,
        agentAttachmentStorage: PlatformAttachmentStorage(
          layout: AppStorageLayout(directoryProvider: () async => root),
        ),
      );
      final stages = <Map<String, Object?>>[];
      final report = <String, Object?>{
        'sourceSha': _revision,
        'platform': Platform.operatingSystem,
        'model': connection.model,
        'protocol': connection.protocol.name,
        'businessData': 'synthetic',
        'credentialSource': _credentialsFile.isEmpty
            ? 'native secure slots copied to an isolated memory vault'
            : 'test app private temporary transfer file, deleted after reading',
        'connectionSource': _connectionFile.isEmpty
            ? 'read-only existing AppData profile'
            : 'isolated copy of existing AgentSettings',
        'requests': provider.requests,
        'stages': stages,
      };
      var approvals = 0, questions = 0;
      final handling = <String>{};
      final pendingInteractions = <Future<void>>{};
      Object? interactionFailure;
      StackTrace? interactionStack;
      String? conversationId;
      ValueListenable<AgentUiRunState>? watch;
      void handleInteraction(String id, Future<void> action) {
        late final Future<void> tracked;
        tracked = action
            .catchError((Object error, StackTrace stack) async {
              interactionFailure ??= error;
              interactionStack ??= stack;
              await app.agent.runtime.stop(id);
            })
            .whenComplete(() => pendingInteractions.remove(tracked));
        pendingInteractions.add(tracked);
        tracked.ignore();
      }

      void answer() {
        final id = conversationId;
        if (id == null) return;
        final approval = app.agent.runtime.state.value
            .runFor(id)
            .pendingApproval;
        if (approval != null && handling.add('approval:${approval.id}')) {
          approvals++;
          handleInteraction(id, app.agent.runtime.approve(id, approval.id));
        }
        final question = app.agent.conversations.find(id)?.pendingQuestion;
        if (question != null &&
            !question.isResolved &&
            handling.add('question:${question.id}')) {
          questions++;
          handleInteraction(
            id,
            app.agent.runtime.answerQuestion(id, question.id, [
              for (final prompt in question.questions)
                AgentQuestionAnswer(questionId: prompt.id, text: '2026-09-14'),
            ]),
          );
        }
      }

      try {
        await app.agent.initialize();
        final chat = await app.agent.conversations.create(
          title: '合成模型验收',
          mode: AgentPermissionMode.full,
        );
        conversationId = chat.id;
        final syntheticHistory = [
          for (var index = 0; index < 40; index++)
            ConversationMessage(
              id: 'synthetic-context-$index',
              role: index.isEven
                  ? ConversationRole.user
                  : ConversationRole.assistant,
              text:
                  'Synthetic reference $index. '
                  '${List.filled(12, 'This is fictional background for a context test. It contains no real people or business records.').join(' ')}',
              createdAt: DateTime.utc(2026, 9, 1).add(Duration(minutes: index)),
            ),
        ];
        await app.agent.conversations.update(
          chat.id,
          (value) => value.copyWith(
            messages: syntheticHistory,
            executionHistoryStart: syntheticHistory.length,
          ),
        );
        watch = app.agent.runtime.watchConversation(chat.id);
        watch.addListener(answer);
        app.agent.conversations.addListener(answer);
        Future<void> run(String label, String prompt) async {
          final before = provider.requests.length;
          await app.agent.runtime.send(chat.id, prompt);
          await Future.wait(pendingInteractions.toList());
          if (interactionFailure != null) {
            Error.throwWithStackTrace(interactionFailure!, interactionStack!);
          }
          final state = app.agent.runtime.state.value.runFor(chat.id);
          stages.add({
            'name': label,
            'phase': state.phase.name,
            'error': state.errorMessage,
            'requests': provider.requests.length - before,
          });
          expect(state.phase, AgentUiPhase.idle, reason: label);
        }

        await run(
          'create',
          '这是合成数据验收。创建名为“Agent合成验收”的课表，'
              '开学日期2026年9月7日，共18周，使用现有节次时间集。'
              '再添加两门每周上课的课程：数学，周一第1节；英语，周二第2节。'
              '完成后核对实际保存结果。',
        );
        final table = app.session.committedData.studentMode.timetables
            .singleWhere((table) => table.config.name == 'Agent合成验收');
        expect(table.courses.map((course) => course.name).toSet(), {
          '数学',
          '英语',
        });
        final automatic = await store.listRecords('context', chat.id);
        expect(
          automatic,
          isNotEmpty,
          reason: 'The first real task must automatically summarize its synthetic history.',
        );
        report['automaticCompactions'] = automatic;
        await app.agent.configure(
          app.agent.settings.copyWith(
            models: [
              for (final model in app.agent.settings.models)
                AgentModelConfig.fromJson({
                  ...model.toJson(),
                  'autoCompact': false,
                }),
            ],
          ),
        );
        await app.agent.runtime.setMode(chat.id, AgentPermissionMode.plan);
        await run(
          'preview',
          '请规划创建另一张名为“仅预览验收”的课表，'
              '2026年9月7日开学，共18周，使用同一节次时间集。',
        );
        expect(
          app.session.committedData.studentMode.timetables.any(
            (table) => table.config.name == '仅预览验收',
          ),
          isFalse,
        );
        await app.agent.runtime.setMode(chat.id, AgentPermissionMode.ask);
        await run(
          'question-and-approval',
          '先通过问答向我询问新的开学日期。'
              '收到答案后，将“Agent合成验收”课表的开学日期改为我给出的日期。',
        );
        expect(questions, greaterThan(0));
        expect(approvals, greaterThan(0));
        final changed = app.session.committedData.studentMode.timetables
            .singleWhere((value) => value.id == table.id);
        expect(changed.config.startDate, DateTime(2026, 9, 14));
        await app.agent.runtime.send(chat.id, '/compact');
        expect(
          (await store.listRecords('context', chat.id)).length,
          greaterThan(automatic.length),
          reason: 'Manual compaction must save a new checkpoint.',
        );
        final checkpoint = await store.latestContextCheckpoint(chat.id);
        expect(checkpoint, isNotNull);
        report['compaction'] = checkpoint;
        report['approvals'] = approvals;
        report['questions'] = questions;
        report['businessEndState'] = {
          'timetableName': changed.config.name,
          'startDate': changed.config.startDate.toIso8601String(),
          'courses': changed.courses.map((course) => course.name).toList(),
          'receiptCount':
              app.session.committedData.applicationLedger?.receipts.length,
        };
        report['outcome'] = 'passed';
      } catch (error) {
        report['outcome'] = 'failed';
        report['failureType'] = error.runtimeType.toString();
        rethrow;
      } finally {
        watch?.removeListener(answer);
        app.agent.conversations.removeListener(answer);
        await app.agent.quiesce();
        await Future.wait(pendingInteractions.toList());
        report['conversations'] = [
          for (final chat in await app.agent.conversations.readAll())
            chat.toJson(),
        ];
        final artifact = File(_reportFile);
        await artifact.parent.create(recursive: true);
        await artifact.writeAsString(
          const JsonEncoder.withIndent('  ').convert(report),
        );
        binding.reportData = {'agentLiveModel': report};
        expect(await sourceFile.readAsBytes(), originalBytes);
        app.dispose();
        await app.session.close();
        await provider.closed.future;
        await store.close();
        await root.delete(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
