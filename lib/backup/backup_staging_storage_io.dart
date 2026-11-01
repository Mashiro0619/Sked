import 'dart:io';

import 'package:path/path.dart' as path;

import '../agent/attachments/attachment_storage.dart';
import '../agent/attachments/attachment_storage_io.dart';
import '../services/app_storage_layout_io.dart';

AttachmentStorage createPlatformBackupStagingStorage() {
  final base = AppStorageLayout();
  return PlatformAttachmentStorage(
    layout: AppStorageLayout(
      directoryProvider: () async => Directory(
        path.join(
          (await base.directory()).path,
          'Sked_selective_restore_staging',
        ),
      ),
    ),
  );
}
