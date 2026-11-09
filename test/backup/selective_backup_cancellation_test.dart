import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/backup/selective_backup_app_data.dart';
import 'package:sked/backup/selective_backup_models.dart';

void main() {
  test('cancellation ends a stalled selected export and a late read publishes no bundle', () async {
    const key = BackupObjectKey(BackupObjectKind.attachment, 'export-file');
    final bytes = Uint8List.fromList([1, 2, 3]);
    final inventory = SelectiveBackupBundle(
      records: [
        BackupRecord(
          key: key,
          label: 'small.bin',
          data: {
            'id': key.id,
            'name': 'small.bin',
            'mediaType': 'application/octet-stream',
            'byteLength': bytes.length,
            'sha256': backupDigest(bytes),
            'createdAt': 1794182400000,
          },
        ),
      ],
      roots: const [key],
    );
    final entered = Completer<void>();
    final reading = Completer<Uint8List>();
    final token = BackupCancellation();
    var published = false;
    final exporting =
        exportSelectiveBackup(
          inventory: inventory,
          selection: BackupSelection(
            objects: const [key],
            attachmentBytes: [key.id],
          ),
          cancellation: token,
          readAttachment: (_, _) {
            entered.complete();
            return reading.future;
          },
        ).then((bundle) {
          published = true;
          return bundle;
        });
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
    await entered.future;
    token.cancel();
    await rejected.timeout(const Duration(seconds: 5));
    expect(reading.isCompleted, isFalse);
    reading.complete(bytes);
    await Future<void>.delayed(Duration.zero);
    expect(published, isFalse);
  });
}
