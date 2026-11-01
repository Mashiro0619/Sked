import '../agent/attachments/attachment_storage.dart';
import '../agent/attachments/attachment_storage_web.dart';

AttachmentStorage createPlatformBackupStagingStorage() =>
    PlatformAttachmentStorage(databaseName: 'sked.backup.staging.v1');
