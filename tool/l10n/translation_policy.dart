/// Explicit untranslated messages use the current English template at build
/// time. Removing a locale entry prevents a copied English sentence going stale.
const commonEnglishFallbacks = <String>{
  'notificationCoverageBlocked',
  'notificationCoverageFailed',
  'notificationBatteryOptimizationWarning',
  'schoolWebImportSignOut',
  'schoolWebImportSignOutTitle',
  'schoolWebImportSignOutMessage',
  'schoolWebImportSignOutSuccess',
  'schoolWebImportSignOutFailed',
  'importWarningSkippedUnsupportedTimeZone',
  'expandTimelineEvents',
  'timelineEvents',
  'schoolImportEndpointChangeTitle',
  'schoolImportEndpointChangeMessage',
  'schoolImportEndpointChangeConfirm',
  'restoreBackupParserSettingsSummary',
  'backupParserEndpointUnset',
  'periodTimesDayFull',
  'icsImportReviewNotice',
  'icsImportContinueAction',
  'importWarningRecurrenceDateClamped',
  'importEntryLimitExceededMessage',
  'importWarningSkippedRecurrenceOverride',
  'importWarningSkippedCancelledEvent',
  'importWarningSkippedEmptyRecurrence',
  'importTextFileTooLarge',
  'confirmImportedStartDatesTitle',
  'confirmImportedStartDatesMessage',
  'importStartDateConfirmationRequiredMessage',
  'importWarningRecurrenceRuleDowngraded',
  'eventRecurrenceExceptionsChangeTitle',
  'eventRecurrenceExceptionsChangeMessage',
  'assistantPreviewDescription',
};

const localeEnglishFallbacks = <String, Set<String>>{
  'nl': {
    'exportTimetableText',
    'importTimetableText',
    'privacyPolicyEntryDesc',
    'schoolHtmlImportEmpty',
    'schoolHtmlImportEntry',
    'schoolHtmlImportEntryDesc',
    'schoolHtmlImportHtmlHint',
    'schoolHtmlImportHtmlLabel',
    'schoolHtmlImportNonHtmlHint',
    'schoolHtmlImportPageTitle',
  },
};

Set<String> allowedFallbacksForLocale(String locale) {
  final language = locale.replaceAll('-', '_').split('_').first;
  if (language == 'en' || language == 'zh') return const {};
  return {...commonEnglishFallbacks, ...?localeEnglishFallbacks[locale]};
}

/// Confirmed retired English copies, keyed by message to avoid guessing a
/// translation's language from its alphabet or from shared product names.
const retiredEnglishMessages = <String, Set<String>>{
  'assistantPreviewDescription': {
    'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.',
  },
  'exportTimetableText': {'Export timetable as text'},
  'importTimetableText': {'Import timetable from text'},
  'privacyPolicyEntryDesc': {
    'Learn how the app handles local storage, school-site configuration, file import/export, webpage parsing, and external links.',
  },
  'schoolHtmlImportEmpty': {'Paste the page HTML first.'},
  'schoolHtmlImportEntry': {'Import by pasting timetable page content'},
  'schoolHtmlImportEntryDesc': {
    'Paste source code or raw page content containing timetable information manually.',
  },
  'schoolHtmlImportHtmlHint': {
    'Paste source code or raw page content containing timetable information here.',
  },
  'schoolHtmlImportHtmlLabel': {'Page content'},
  'schoolHtmlImportNonHtmlHint': {
    'Any content containing timetable information can be parsed and imported, not just HTML.',
  },
  'schoolHtmlImportPageTitle': {'Parse timetable from page content'},
};
