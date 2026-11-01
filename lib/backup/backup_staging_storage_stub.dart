import '../agent/attachments/attachment_storage.dart';

AttachmentStorage createPlatformBackupStagingStorage() =>
    throw UnsupportedError('Backup staging is unavailable on this platform.');
