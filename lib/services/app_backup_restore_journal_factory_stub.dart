import 'app_backup_restore_journal.dart';

AppBackupRestoreJournal createPlatformAppBackupRestoreJournal() =>
    SharedPreferencesAppBackupRestoreJournal();
