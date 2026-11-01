import 'package:flutter/foundation.dart' show visibleForTesting;

import '../agent/attachments/attachment_storage.dart';
import 'backup_staging_storage_stub.dart'
    if (dart.library.io) 'backup_staging_storage_io.dart'
    if (dart.library.js_interop) 'backup_staging_storage_web.dart';

AttachmentStorageFactory? _factory;
@visibleForTesting
void debugSetBackupStagingStorageFactory(AttachmentStorageFactory? factory) =>
    _factory = factory;
AttachmentStorage createBackupStagingStorage() =>
    _factory?.call() ?? createPlatformBackupStagingStorage();
