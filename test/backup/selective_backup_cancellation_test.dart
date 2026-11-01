import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_models.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/application/operation_contracts.dart';

import '../support/workspace_harness.dart';

class _StalledStorage extends MemoryAttachmentStorage {
  final entered = Completer<void>(), cancelled = Completer<void>();
  late final stream = StreamController<List<int>>(
    onListen: () => entered.complete(),
    onCancel: () => cancelled.complete(),
  );
  @override
  Stream<List<int>> read(String id) => stream.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup cancellation interrupts a stalled attachment read and releases export ownership', () async {
    final storage = _StalledStorage();
    final runtime = await workspaceProvider(agentAttachmentStorage: storage);
    addTearDown(runtime.dispose);
    addTearDown(storage.stream.close);
    await runtime.agent.initialize();
    final chat = await runtime.agent.conversations.create(
      title: 'Export cancellation',
      mode: AgentPermissionMode.plan,
    );
    final file = ConversationAttachment(
      id: 'export-file',
      name: 'small.bin',
      mediaType: 'application/octet-stream',
      byteLength: 3,
      digest: backupDigest([1, 2, 3]),
    );
    await runtime.agent.conversations.update(
      chat.id,
      (chat) => chat.copyWith(attachments: [file]),
    );
    final service = runtime.backups.selective;
    final inventory = await service.inventory();
    final token = BackupCancellation();
    final exporting = service.export(
      inventory,
      BackupSelection(
        objects: [BackupObjectKey(BackupObjectKind.conversation, chat.id)],
        attachmentBytes: [file.id],
      ),
      cancellation: token,
    );
    final rejected = expectLater(
      exporting,
      throwsA(
        isA<SelectiveBackupException>().having(
          (error) => error.code,
          'code',
          SelectiveBackupError.cancelled,
        ),
      ),
    );
    await storage.entered.future;
    expect(service.isBusy, isTrue);
    token.cancel();
    await rejected.timeout(const Duration(seconds: 5));
    await storage.cancelled.future;
    expect(service.isBusy, isFalse);
    expect(await service.journal.read(), isNull);
    expect(runtime.session.canWrite, isTrue);
  });
}
