import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/generated/api/models.dart' as view;
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/application/data_restore_receipt.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/backup/selective_backup_agent_data.dart';
import 'package:sked/backup/selective_backup_agent_store.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_codec.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';

import 'agent_rust_offline_workspace.dart';

/// Continues the same offline journey through the real backup and host owners.
Future<void> runRustAgentBackupJourney({
  required Directory root,
  required AppData seed,
  required Map<String, Object?> historyParts,
  required List<String> checkpoints,
}) async {
  final workspace = OfflineAgentWorkspace(
    Directory(path.join(root.path, 'backup')),
  );
  final journal = _InterruptedRestoreJournal(workspace.createRestoreJournal());
  final credentials = _UnavailableUntilOpenedCredentials();
  await workspace.open(
    seed: seed.copyWith(
      agentSettings: seed.agentSettings.copyWith(enabled: false),
    ),
    journal: journal,
    credentials: credentials,
    initializeAgent: false,
  );
  final app = workspace.app;
  final nativeStore = NativeAgentBackupStore(workspace.client);
  final repository = app.agent.conversations;
  final service = app.backups.selective;
  late String draftId;
  late String operationId;
  late String generation;
  late String keptId;
  late String binaryId;
  late String missingId;
  late Uint8List selectedBytes;
  try {
    final template = (historyParts['conversations']! as List).first as Map;
    final kept = _copy(template);
    keptId = 'backup-untouched';
    (kept['conversation'] as Map)['id'] = keptId;
    (kept['conversation'] as Map)['title'] = '保留的历史';
    await nativeStore.restore({
      'conversations': [kept],
      'knowledge': <Object?>[],
      'attachments': kept['attachments'],
    }, 'offline-backup-seed');
    await repository.load();
    await repository.read(keptId);
    await repository.updateDraftText(keptId, '保留已存会话中的下一条输入');
    final draft = await repository.createDraft(title: '尚未发送的输入');
    draftId = draft.id;
    await repository.updateDraftText(draftId, '恢复结束前保留此输入');
    await repository.addSource(
      draftId,
      const ConversationSource(
        id: 'volatile-source',
        kind: 'structured_file',
        text: '尚未发送的来源',
      ),
    );
    final draftBytes = Uint8List.fromList([4, 5, 6]);
    final draftSource = await File(path.join(root.path, 'draft.bin'))
        .writeAsBytes(draftBytes);
    await app.agent.binaryAttachments.attach(
      draftId,
      XFile(draftSource.path, mimeType: 'application/octet-stream'),
      canModify: () => repository.canWrite,
    );
    final draftAttachment = repository.find(draftId)!.attachments.single;

    Future<void> assertDraftRetained() async {
      final actual = (await workspace.client.query(
        native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: draftId,
        ),
      )).snapshot!;
      expect(actual.conversation.draftOnly, isTrue);
      expect(actual.conversation.draft, '恢复结束前保留此输入');
      expect(actual.sources.single.text, '尚未发送的来源');
      expect(actual.attachments.single.id, draftAttachment.id);
      expect(repository.selectedId, draftId);
      expect(await nativeStore.readAttachment(draftAttachment), draftBytes);
    }

    final inventory = await service.inventory();
    expect(
      inventory.byKey.containsKey(
        BackupObjectKey(BackupObjectKind.conversation, draftId),
      ),
      isFalse,
    );
    final calendar = app.session.committedData.generalMode.schedules.single;
    final calendarKey = BackupObjectKey(BackupObjectKind.calendar, calendar.id);
    final calendarSelection = BackupSelection(objects: [calendarKey]);
    final exported = service.decode(
      await service.export(inventory, calendarSelection),
    );
    expect(exported.records.map((record) => record.key), [calendarKey]);
    await assertDraftRetained();

    final cancelled = BackupCancellation()..cancel();
    final cancelledPlan = await service.prepareRestore(
      inventory,
      calendarSelection,
    );
    await expectLater(
      service.restore(cancelledPlan, cancellation: cancelled),
      throwsA(
        isA<SelectiveBackupException>().having(
          (error) => error.code,
          'code',
          SelectiveBackupError.cancelled,
        ),
      ),
    );
    final empty = await service.prepareRestore(
      inventory,
      BackupSelection(objects: const []),
    );
    await service.restore(empty);
    expect(await journal.read(), isNull);
    await assertDraftRetained();
    expect(credentials.reads, 0);
    expect(credentials.writes, 0);
    checkpoints.add('真实应用备份读取不激活密钥；导出、取消和空恢复保留草稿与附件');

    selectedBytes = Uint8List.fromList([0, 1, 2, 255, 128]);
    final included = _metadata(
      'selected-binary',
      'selected.bin',
      selectedBytes,
    );
    final metadataOnly = _metadata(
      'metadata-only',
      'missing.bin',
      Uint8List.fromList([8, 9]),
    );
    final incoming = _copy(template);
    (incoming['conversation'] as Map)['id'] = draftId;
    (incoming['conversation'] as Map)['title'] = '恢复的可读历史';
    incoming['attachments'] = [included, metadataOnly];
    final user = (incoming['messages'] as List).cast<Map>().firstWhere(
      (message) => message['role'] == 'user',
    );
    user['attachmentIds'] = [included['id'], metadataOnly['id']];
    final incomingData = app.session.committedData.copyWith(
      generalMode: app.session.committedData.generalMode.withSchedule(
        calendar.copyWith(name: '恢复后的日历'),
      ),
    );
    final source = buildSelectiveBackupInventory(
      appData: incomingData,
      schoolSites: const [
        SchoolSite(
          id: 'offline-restored-site',
          name: '恢复的学校网站',
          loginUrl: 'https://school.example.test',
        ),
      ],
      agentRecords: nativeAgentBackupRecords({
        'conversations': [incoming],
        'knowledge': [
          {
            'kind': 'memory',
            'id': 'offline-restored-memory',
            'title': '学习偏好',
            'body': '下午安排复习。',
            'enabled': true,
          },
        ],
        'attachments': [included, metadataOnly],
      }),
    );
    final selection = BackupSelection(
      objects: [
        calendarKey,
        const BackupObjectKey(
          BackupObjectKind.schoolSite,
          'offline-restored-site',
        ),
        const BackupObjectKey(
          BackupObjectKind.memory,
          'offline-restored-memory',
        ),
        BackupObjectKey(BackupObjectKind.conversation, draftId),
      ],
      attachmentBytes: [included['id']! as String],
    );
    final portable = await exportSelectiveBackup(
      inventory: source,
      selection: selection,
      readAttachment: (_, _) async => selectedBytes,
    );
    final bytes = const SelectiveBackupCodec().encode(portable);
    credentials.available = true;
    await app.agent.setEnabled(true);
    final backupSource = await File(path.join(root.path, 'selected.sked.zip'))
        .writeAsBytes(bytes);
    await app.agent.binaryAttachments.attach(
      keptId,
      XFile(backupSource.path, mimeType: 'application/zip'),
      canModify: () => repository.canWrite,
    );
    final sourceAttachment = repository.find(keptId)!.attachments.single;
    final arguments = <String, Object?>{
      'sourceId': sourceAttachment.id,
      'objects': selection.objects.map((key) => key.toJson()).toList(),
      'attachmentIds': selection.attachmentBytes.toList(),
    };
    await app.agent.runtime.setMode(keptId, AgentPermissionMode.plan);
    final preview = await app.agent.runtime.runHostTool(
      keptId,
      toolName: 'backups.restore',
      arguments: arguments,
    );
    expect(preview['status'], 'preview');
    expect(await journal.read(), isNull);
    expect(
      app.session.committedData.generalMode.schedules.single.name,
      calendar.name,
    );
    await assertDraftRetained();

    await app.agent.runtime.setMode(keptId, AgentPermissionMode.ask);
    journal.failAfterConversations = true;
    journal.failClear = true;
    final approvalReady = workspace.client.events.firstWhere(
      (event) =>
          event.snapshot?.operations.any(
            (operation) =>
                operation.phase == view.ViewOperationPhase.waitingApproval,
          ) ==
          true,
    );
    final restoring = app.agent.runtime.runHostTool(
      keptId,
      toolName: 'backups.restore',
      arguments: arguments,
    );
    await approvalReady.timeout(const Duration(seconds: 20));
    await app.agent.runtime.loadConversation(keptId);
    final approval = app.agent.runtime.state.value
        .runFor(keptId)
        .pendingApproval!;
    expect(await journal.read(), isNull);
    await app.agent.runtime.approve(keptId, approval.id);
    final result = await restoring.timeout(const Duration(seconds: 20));
    expect(result['effectStatus'], 'unknown');
    expect(result['dataStatus'], 'unknown');
    expect(result['recoveryRequired'], isTrue);
    operationId = result['operationId']! as String;
    final unresolvedRestore =
        (await workspace.client.query(
          native.AgentQuery(
            kind: native.QueryKind.readConversation,
            conversationId: keptId,
          ),
        )).snapshot!.operations.singleWhere(
          (operation) => operation.binding?.operationId == operationId,
        );
    expect(unresolvedRestore.binding!.store, view.ViewOperationStore.external_);
    expect(unresolvedRestore.phase, view.ViewOperationPhase.unresolved);
    final pending = (await journal.read())!;
    generation = app.session.committedData.applicationLedger!.generation;
    expect(service.recoveryPending, isTrue);
    expect(app.session.canWrite, isFalse);
    expect(
      app.session.committedData.generalMode.schedules.single.name,
      '恢复后的日历',
    );
    await assertDraftRetained();
    final durable =
        (await nativeStore.exportParts(
              conversationIds: [draftId],
              knowledgeKeys: const [],
            ))['conversations']!
            as List;
    expect(
      (durable.single as Map)['conversation'],
      containsPair('title', '恢复的可读历史'),
    );
    final nativeRecords = await _nativeJournalRecords(workspace, draftId);
    final fixedTargets = pending.targets
        .map((target) => target.fingerprint)
        .toList();
    checkpoints.add('备份工具经计划与审批进入跨库恢复；原生历史已保存后丢失阶段回执仍保留草稿');

    await expectLater(app.lifecycle.retryStorageLoad(), throwsStateError);
    expect((await journal.read())!.isComplete, isTrue);
    await assertDraftRetained();
    journal.failClear = false;
    await app.lifecycle.retryStorageLoad();
    expect(await journal.read(), isNull);
    expect(service.recoveryPending, isFalse);
    expect(app.session.canWrite, isTrue);
    expect(repository.draftConversation, isNull);
    final restored = await repository.read(draftId);
    expect(restored.title, '恢复的可读历史');
    expect(restored.executionMessages, isEmpty);
    expect(restored.pendingRedo, isNull);
    expect((await repository.read(keptId)).draft, '保留已存会话中的下一条输入');
    expect(app.session.committedData.applicationLedger!.generation, generation);
    final receipt = completedDataRestoreReceipt(
      app.session.committedData.applicationLedger,
      operationId,
    );
    expect(receipt, isNotNull);
    expect(receipt!.result['effectStatus'], 'applied');
    expect(
      receipt.result['restoreCompletion'],
      containsPair('restoreId', pending.restoreId),
    );
    expect(app.session.committedData.applicationLedger!.receipts, hasLength(1));
    final recoveredRestore =
        (await workspace.client.query(
          native.AgentQuery(
            kind: native.QueryKind.readConversation,
            conversationId: keptId,
          ),
        )).snapshot!.operations.singleWhere(
          (operation) => operation.binding?.operationId == operationId,
        );
    expect(recoveredRestore.binding!.store, view.ViewOperationStore.external_);
    expect(recoveredRestore.phase, view.ViewOperationPhase.committed);
    expect(
      journal.attempts.every(
        (state) =>
            state.restoreId == pending.restoreId &&
            _sameStrings(
              state.targets.map((target) => target.fingerprint).toList(),
              fixedTargets,
            ),
      ),
      isTrue,
    );
    final includedFile = restored.attachments.singleWhere(
      (file) => file.name == 'selected.bin',
    );
    final missingFile = restored.attachments.singleWhere(
      (file) => file.name == 'missing.bin',
    );
    binaryId = includedFile.id;
    missingId = missingFile.id;
    expect(await nativeStore.readAttachment(includedFile), selectedBytes);
    await expectLater(
      nativeStore.readAttachment(missingFile),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(await _nativeJournalRecords(workspace, draftId), nativeRecords);
    final after = await service.inventory();
    expect(
      after
          .byKey[const BackupObjectKey(
            BackupObjectKind.memory,
            'offline-restored-memory',
          )]!
          .data['body'],
      '下午安排复习。',
    );
    expect(
      after
          .byKey[const BackupObjectKey(
            BackupObjectKind.schoolSite,
            'offline-restored-site',
          )]!
          .label,
      '恢复的学校网站',
    );
    checkpoints.add('固定目标恢复、清理失败重试与唯一跨世代完成回执；元数据附件保持缺失');

    final nextDraft = await repository.createDraft(title: '下一次恢复前的输入');
    await repository.updateDraftText(nextDraft.id, '成功后结束草稿边界');
    final nextSource = buildSelectiveBackupInventory(
      appData: app.session.committedData,
      schoolSites: const [
        SchoolSite(
          id: 'offline-second-site',
          name: '第二个学校网站',
          loginUrl: 'https://second.example.test',
        ),
      ],
    );
    final nextPlan = await service.prepareRestore(
      nextSource,
      BackupSelection(
        objects: const [
          BackupObjectKey(BackupObjectKind.schoolSite, 'offline-second-site'),
        ],
      ),
    );
    await service.restore(nextPlan);
    expect(repository.draftConversation, isNull);
    expect(repository.find(nextDraft.id), isNull);
    checkpoints.add('仅恢复业务对象也在完整成功后结束未发送草稿边界');

    await repository.load();
    await app.agent.runtime.setMode(keptId, AgentPermissionMode.full);
    Future<Map<String, Object?>> manage(
      String tool,
      Map<String, Object?> arguments,
    ) async {
      final result = await app.agent.runtime.runHostTool(
        keptId,
        toolName: tool,
        arguments: arguments,
      );
      await app.agent.conversationTools.waitForPendingOperations();
      await (await workspace.client.core).recoverOperations(
        conversationId: keptId,
      );
      final receipt = app.agent.external.status(
        result['operationId']! as String,
      )!;
      expect(receipt.result['effectStatus'], 'applied');
      final caller = (await workspace.client.query(
        native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: keptId,
        ),
      )).snapshot!;
      expect(caller.operations.last.binding!.operationId, receipt.operationId);
      expect(
        caller.operations.last.binding!.store,
        view.ViewOperationStore.external_,
      );
      expect(caller.operations.last.phase, view.ViewOperationPhase.committed);
      return receipt.result;
    }

    final created = await manage('conversations.create', {'title': '受管理的会话'});
    final managedId = (created['arguments'] as Map)['conversationId'] as String;
    expect(
      (created['effectResult'] as Map)['conversation'],
      containsPair('id', managedId),
    );
    final renamed = await manage('conversations.rename', {
      'id': managedId,
      'title': '重命名后的会话',
    });
    expect(
      (renamed['effectResult'] as Map)['conversation'],
      containsPair('title', '重命名后的会话'),
    );
    for (final archived in [true, false]) {
      final changed = await manage('conversations.archive', {
        'id': managedId,
        'archived': archived,
      });
      final actual = (await workspace.client.query(
        native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: managedId,
        ),
      )).snapshot!;
      expect(actual.conversation.archived, archived);
      expect(
        (changed['effectResult'] as Map)['conversation'],
        containsPair('id', managedId),
      );
      expect(
        (changed['effectResult'] as Map)['conversation'],
        containsPair('archived', archived),
      );
    }
    final deleted = await manage('conversations.delete', {'id': managedId});
    expect(deleted['effectResult'], containsPair('conversationId', managedId));
    expect(deleted['effectResult'], containsPair('deleted', true));
    expect(
      (await workspace.client.query(
        native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: managedId,
        ),
      )).snapshot,
      isNull,
    );
    checkpoints.add('会话创建、重命名、归档、恢复与删除的回执绑定同一实际对象');
  } finally {
    await workspace.close();
  }

  final reopened = OfflineAgentWorkspace(workspace.root);
  try {
    await reopened.open(initializeAgent: false);
    await reopened.app.agent.conversations.load();
    final restored = await reopened.app.agent.conversations.read(draftId);
    final reopenedStore = NativeAgentBackupStore(reopened.client);
    expect(restored.executionMessages, isEmpty);
    expect(
      await reopenedStore.readAttachment(
        restored.attachments.singleWhere((file) => file.id == binaryId),
      ),
      selectedBytes,
    );
    await expectLater(
      reopenedStore.readAttachment(
        restored.attachments.singleWhere((file) => file.id == missingId),
      ),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(
      (await reopened.app.agent.conversations.read(keptId)).draft,
      '保留已存会话中的下一条输入',
    );
    expect(await reopened.createRestoreJournal().read(), isNull);
    expect(reopened.app.session.canWrite, isTrue);
    checkpoints.add('重新打开真实应用后所选业务、历史和附件状态一致');
  } finally {
    await reopened.close();
  }
}

Map<String, Object?> _copy(Map source) =>
    (jsonDecode(jsonEncode(source)) as Map).cast<String, Object?>();

Map<String, Object?> _metadata(String id, String name, Uint8List bytes) => {
  'id': id,
  'name': name,
  'mediaType': 'application/octet-stream',
  'byteLength': bytes.length,
  'sha256': backupDigest(bytes),
  'createdAt': 1794182400000,
};

bool _sameStrings(List<String> a, List<String> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((same) => same);

Future<int> _nativeJournalRecords(
  OfflineAgentWorkspace workspace,
  String id,
) async {
  var count = 0;
  await for (final entry in Directory(
    path.join(workspace.agentDirectory.path, 'conversations'),
  ).list()) {
    if (entry is! File || !entry.path.endsWith('.jsonl')) continue;
    for (final line in await entry.readAsLines()) {
      if ((jsonDecode(line) as Map)['conversationId'] == id) count++;
    }
  }
  return count;
}

class _UnavailableUntilOpenedCredentials extends MemoryAgentCredentialStore {
  int reads = 0, writes = 0;
  bool available = false;
  @override
  Future<String?> read(AgentCredentialSlot slot) {
    reads++;
    if (!available) {
      throw StateError('Keyring is unavailable during ordinary backup.');
    }
    return super.read(slot);
  }

  @override
  Future<void> write(AgentCredentialSlot slot, String? value) {
    writes++;
    if (!available) {
      throw StateError('Keyring is unavailable during ordinary backup.');
    }
    return super.write(slot, value);
  }
}

class _InterruptedRestoreJournal implements SelectiveRestoreJournal {
  _InterruptedRestoreJournal(this.inner);
  final SelectiveRestoreJournal inner;
  final attempts = <SelectiveRestoreState>[];
  bool failAfterConversations = false;
  bool failClear = false;
  @override
  Future<SelectiveRestoreState?> read() => inner.read();
  @override
  Future<void> write(SelectiveRestoreState state) async {
    attempts.add(state);
    if (failAfterConversations &&
        state.completed > 0 &&
        state.targets[state.completed - 1].owner == BackupOwner.conversations) {
      failAfterConversations = false;
      throw StateError('Lost the native conversation stage acknowledgement.');
    }
    await inner.write(state);
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      throw StateError('Restore completed; journal cleanup is pending.');
    }
    await inner.clear();
  }
}
