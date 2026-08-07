import 'app_backup_restore_journal.dart';
import 'app_backup_restore_journal_io.dart';

AppBackupRestoreJournal createPlatformAppBackupRestoreJournal() =>
    FileAppBackupRestoreJournal();
