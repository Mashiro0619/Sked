/// Shared names for Sked's browser-local persistence.
///
/// Native platforms use files in the application-support directory instead;
/// these keys are only used by the browser implementations and the browser
/// journal backend.
const appDataWebStorageKey = 'sked.app_data';
const appDataWebRecoveryKeyPrefix = 'sked.app_data.recovery.';

const schoolSitesWebStorageKey = 'sked.school_sites';
const schoolSitesWebRecoveryKeyPrefix = 'sked.school_sites.recovery.';

const appBackupRestoreJournalWebStorageKey = 'sked.backup_restore_journal';
const appBackupRestoreJournalWebRecoveryKeyPrefix =
    'sked.backup_restore_journal.recovery.';

const browserLocalStorageUriPrefix = 'browser://local-storage/';

String browserLocalStorageUri(String key) =>
    '$browserLocalStorageUriPrefix$key';
