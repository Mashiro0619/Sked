// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Week $week';
  }

  @override
  String get addCourse => 'Add course';

  @override
  String get settings => 'Settings';

  @override
  String get multiTimetableSwitch => 'Switch timetables';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Current timetable · $weeks weeks';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tap to switch · $weeks weeks';
  }

  @override
  String get editTimetable => 'Edit timetable';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get schoolImportParsePageTitle => 'Rooster analyseren';

  @override
  String get schoolImportParsePageParsing => 'Analyseren…';

  @override
  String get schoolImportParsePageFailed => 'Analyse mislukt';

  @override
  String get schoolImportParsePageComplete => 'Analyse voltooid';

  @override
  String get schoolImportParsePageContinue => 'Doorgaan';

  @override
  String get schoolImportParsePageRawContent => 'Onbewerkt antwoord';

  @override
  String get schoolImportParsePageExpandRaw => 'Onbewerkt antwoord uitvouwen';

  @override
  String get schoolImportParsePageCollapseRaw =>
      'Onbewerkt antwoord samenvouwen';

  @override
  String get schoolImportExpandWarnings => 'Expand import warnings';

  @override
  String get schoolImportCollapseWarnings => 'Collapse import warnings';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Some courses continue through week $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Replace current timetable?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'The imported timetable will replace the current timetable.';

  @override
  String get createTimetable => 'New timetable';

  @override
  String get jumpToWeek => 'Jump to week';

  @override
  String get timetable => 'Timetable';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Timetable name';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Total weeks';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get deleteTimetableTitle => 'Delete timetable';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'No timetable yet';

  @override
  String get noTimetableMessage =>
      'Create a timetable or import one from a JSON file.';

  @override
  String get importTimetable => 'Import timetable';

  @override
  String get courseName => 'Course name';

  @override
  String get location => 'Location';

  @override
  String get dayOfWeek => 'Day';

  @override
  String get semesterWeeks => 'Weeks';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get linkedPeriods => 'Linked periods';

  @override
  String get linkedPeriodsUnmatched =>
      'No periods matched for the current time. Tap to choose manually.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Period $start-$end';
  }

  @override
  String get teacherName => 'Teacher';

  @override
  String get credits => 'Credits';

  @override
  String get remarks => 'Remarks';

  @override
  String get customFields => 'Custom fields';

  @override
  String get customFieldsHint => 'One per line, format: key:value';

  @override
  String get more => 'Meer';

  @override
  String get selectDayOfWeek => 'Choose day';

  @override
  String get selectSemesterWeeks => 'Choose weeks';

  @override
  String get selectAll => 'Select all';

  @override
  String get clear => 'Clear';

  @override
  String get confirm => 'Confirm';

  @override
  String get selectLinkedPeriods => 'Choose linked periods';

  @override
  String get addCourseTitle => 'Add course';

  @override
  String get editCourseTitle => 'Edit course';

  @override
  String get editCourseTooltip => 'Edit course';

  @override
  String get place => 'Location';

  @override
  String get time => 'Time';

  @override
  String get notFilled => 'Not filled';

  @override
  String get none => 'None';

  @override
  String get conflictCourses => 'Conflicting courses';

  @override
  String get locationNotFilled => 'Location not filled';

  @override
  String get setAsDisplayed => 'Set as displayed';

  @override
  String get editThisCourse => 'Edit this course';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionTimetable => 'Timetable';

  @override
  String get settingsSectionGeneralSchedule => 'General schedule';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionWorkspace => 'Workspace';

  @override
  String get settingsSectionAppearanceLanguage => 'Appearance & language';

  @override
  String get settingsSectionDataSecurity => 'Data & security';

  @override
  String get settingsSectionAbout => 'About Sked';

  @override
  String get noTimetableSettings =>
      'No timetable is currently available for settings.';

  @override
  String get semesterStartDate => 'Semester start date';

  @override
  String get periodTimeSets => 'Period time set';

  @override
  String get noPeriodTimeAvailable => 'No available period time set';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count periods';
  }

  @override
  String get coursePopupDismissSetting =>
      'Allow outside tap to close course popup';

  @override
  String get coursePopupDismissSettingHint =>
      'Turning this off also disables swipe-down dismissal.';

  @override
  String get preserveTimetableGaps => 'Preserve timetable gaps';

  @override
  String get preserveTimetableGapsHint =>
      'When off, lunch and break gaps are collapsed so later classes move upward.';

  @override
  String get showPastEndedCourses => 'Show past-ended courses';

  @override
  String get showPastEndedCoursesHint =>
      'Show courses that have already finished by the real current week with a lighter gray style.';

  @override
  String get showFutureCourses => 'Show future courses';

  @override
  String get showFutureCoursesHint =>
      'Show courses that are not active this week but will appear in later weeks with a gray style.';

  @override
  String get timetableDisplaySettings => 'Timetable display and interaction';

  @override
  String get timetableDisplaySettingsDesc =>
      'Vakweergave, indeling, weekgebaren en snel toevoegen';

  @override
  String get showTimetableGridLines => 'Show timetable grid lines';

  @override
  String get showTimetableGridLinesHint =>
      'Control whether horizontal and vertical grid lines are visible in the timetable.';

  @override
  String get timetableHorizontalLayoutSection =>
      'Horizontal layout and gestures';

  @override
  String get fitDaySelectorToWidth => 'Fit day selector to screen';

  @override
  String get fitDaySelectorToWidthHint =>
      'Show all seven days within the screen when possible; turn off to use a fixed width and scroll.';

  @override
  String get fitWeekColumnsToWidth => 'Fit week columns to screen';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Show all seven timetable columns within the screen when possible; turn off to use a fixed width and scroll.';

  @override
  String get enableWeekSwipeNavigation => 'Swipe to change weeks';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Swipe left or right to move to another week. With fixed widths, drag past the edge first.';

  @override
  String get liveCourseOutlineColor => 'Course outline color';

  @override
  String get liveCourseOutlineColorHint =>
      'Choose whether outlines target the current/next course or all displayed courses on the current page.';

  @override
  String get liveCourseOutlineSettings => 'Course outline';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Configure whether the outline is enabled, what it targets, whether it follows the theme color, and the effective outline color.';

  @override
  String get liveCourseOutlineEnabled => 'Enable outline';

  @override
  String get liveCourseOutlineFollowTheme => 'Follow theme color';

  @override
  String get liveCourseOutlineTarget => 'Outline target';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Current/next course';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'All displayed courses';

  @override
  String get liveCourseOutlineEffectiveColor => 'Effective color';

  @override
  String get liveCourseOutlineCustomColor => 'Custom outline color';

  @override
  String get liveCourseOutlineWidth => 'Outline width';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Language';

  @override
  String get languagePageDescription =>
      'Choose one of the languages that is truly available in the app.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API response';

  @override
  String get theme => 'Theme';

  @override
  String get themeFollowSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeColor => 'Theme color';

  @override
  String get themeColorModeSingle => 'Single theme color';

  @override
  String get themeColorModeColorful => 'Colorful';

  @override
  String get themeColorUiColors => 'UI colors';

  @override
  String get themeColorCourseColors => 'Course colors';

  @override
  String get themeColorPrimary => 'Primary';

  @override
  String get themeColorSecondary => 'Secondary';

  @override
  String get themeColorTertiary => 'Tertiary';

  @override
  String get themeColorCourseText => 'Course text';

  @override
  String get themeColorCourseTextAuto => 'Auto';

  @override
  String get themeColorCourseTextCustom => 'Custom color';

  @override
  String get themeColorCourseColorsEmpty =>
      'Course colors will be generated after importing a timetable.';

  @override
  String get themeCustomColor => 'Custom color';

  @override
  String get themeApplyCustomColor => 'Apply color';

  @override
  String get themeApplySettings => 'Apply settings';

  @override
  String get dataImportExport => 'Import and export data';

  @override
  String get dataImportExportDesc =>
      'Import full data or single timetables, or export current/all timetables.';

  @override
  String get appBackupTitle => 'App-back-up en herstel';

  @override
  String get appBackupSubtitle =>
      'Maak een back-up van roosters, agenda\'s, instellingen en schoolsites of herstel ze. API-sleutels worden niet meegenomen.';

  @override
  String get appBackupSheetSubtitle =>
      'Een volledig herstel vervangt de huidige appgegevens. AI-API-sleutels staan in beveiligde opslag en worden niet naar back-upbestanden geschreven.';

  @override
  String get restoreBackupFileTitle => 'Herstellen vanuit JSON-bestand';

  @override
  String get restoreBackupFileSubtitle =>
      'Kies een volledig Sked-back-upbestand. Je bevestigt voordat er wordt hersteld.';

  @override
  String get restoreBackupTextTitle => 'Back-up-JSON plakken';

  @override
  String get restoreBackupTextSubtitle =>
      'Plak een volledige back-up en herstel de huidige appgegevens.';

  @override
  String get shareBackupTitle => 'Back-upbestand delen';

  @override
  String get shareBackupSubtitle =>
      'Exporteer alle appgegevens als JSON. API-sleutels worden uitgesloten.';

  @override
  String get saveBackupTitle => 'Back-upbestand opslaan';

  @override
  String get saveBackupSubtitle =>
      'Sla een volledige app-back-up op in een lokaal bestand.';

  @override
  String get copyBackupTitle => 'Back-uptekst kopiëren';

  @override
  String get copyBackupSubtitle =>
      'Toon de volledige back-up-JSON zodat je deze kunt kopiëren of tijdelijk bewaren.';

  @override
  String get restoreBackupConfirmTitle => 'Volledige back-up herstellen?';

  @override
  String get restoreBackupConfirmMessage =>
      'Dit vervangt alle huidige roosters, algemene agenda\'s, instellingen en schoolsites. API-sleutels worden niet uit back-ups geïmporteerd; voer de sleutel opnieuw in voordat je opnieuw roosters parseert.';

  @override
  String get restoreBackupConfirmAction => 'Back-up herstellen';

  @override
  String get restoreBackupSuccessMessage =>
      'Volledige app-back-up hersteld. AI-API-sleutels moeten opnieuw worden ingevoerd.';

  @override
  String get restoreBackupFailureMessage =>
      'Herstellen mislukt. Controleer de inhoud van de back-up en probeer het opnieuw.';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get openSourceLicensesDesc =>
      'View licenses for Flutter dependencies and bundled app icon assets.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Already on the latest version ($version)';
  }

  @override
  String get currentVersionLabel => 'Current version';

  @override
  String get newVersionAvailable => 'Update available';

  @override
  String get latestVersionLabel => 'Latest version';

  @override
  String get updateContentLabel => 'Update details';

  @override
  String get officialWebsite => 'Official website';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud drive';

  @override
  String get ignoreThisVersion => 'Ignore this version';

  @override
  String get openUpdatesFailed => 'Unable to open the update link';

  @override
  String get updateCheckFailedTitle => 'Update check failed';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub repository';

  @override
  String get googlePlayStoreDesc => 'View Sked on Google Play';

  @override
  String get openGooglePlayFailed => 'Unable to open Google Play';

  @override
  String get starSkedOnGithub => 'Star Sked on GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Open the project repository and give Sked a Star';

  @override
  String get openGithubFailed => 'Unable to open the GitHub repository link';

  @override
  String get openPrivacyPolicyFailed =>
      'Kan de link naar het privacybeleid niet openen';

  @override
  String get selectPeriodTimeSet => 'Choose period time set';

  @override
  String get newItem => 'New';

  @override
  String get editPeriodTimeSet => 'Edit period time set';

  @override
  String get importTimetableFiles => 'Import timetable';

  @override
  String get importTimetableFilesDesc =>
      'Supports one or multiple timetable files.';

  @override
  String get importTimetableText => 'Import timetable from text';

  @override
  String get importTimetableTextDesc =>
      'Paste timetable JSON content and import it.';

  @override
  String get shareTimetableFiles => 'Share timetable files';

  @override
  String get shareTimetableFilesDesc => 'Choose one or more timetables first.';

  @override
  String get saveTimetableFiles => 'Save timetable files';

  @override
  String get saveTimetableFilesDesc => 'Choose one or more timetables first.';

  @override
  String get exportTimetableText => 'Export timetable as text';

  @override
  String get exportTimetableTextDesc =>
      'Choose one or more timetables, then copy the JSON content.';

  @override
  String get jsonContent => 'JSON content';

  @override
  String get pasteJsonContentHint => 'Paste the JSON content to import.';

  @override
  String get jsonContentEmpty => 'Paste JSON content first.';

  @override
  String get copyText => 'Copy';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get share => 'Share';

  @override
  String get selectTimetablesToExport => 'Choose timetables to export';

  @override
  String get selectTimetablesToImport => 'Choose timetables to import';

  @override
  String timetableCourseCount(int count) {
    return '$count courses';
  }

  @override
  String get importAction => 'Import';

  @override
  String get importTimetableDialogTitle => 'Import timetable';

  @override
  String get chooseImportMethod => 'Choose how to import.';

  @override
  String get importAsNewTimetable => 'Import as new timetable';

  @override
  String get replaceCurrentTimetable => 'Replace current timetable';

  @override
  String get importPeriodTimeSetDialogTitle => 'Import period time sets';

  @override
  String get importPeriodTimeSetDialogBody =>
      'This file contains bundled period time sets. Do you want to import and associate them?';

  @override
  String get importBundledPeriodTimeSets => 'Import and associate';

  @override
  String get discardBundledPeriodTimeSets => 'Discard bundled sets';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'No existing period time set is available, so bundled period time sets cannot be discarded.';

  @override
  String savedToPath(Object path) {
    return 'Saved to $path';
  }

  @override
  String get saveCancelled => 'Save cancelled';

  @override
  String get fileSaveRestrictedTitle => 'File saving restricted';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'The system could not save the file. You can retry or use sharing instead.';

  @override
  String get retrySave => 'Retry save';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Enable file access in system settings, then return and try exporting again.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get browserDownloadRestrictedTitle => 'Browser download restricted';

  @override
  String get browserDownloadRestrictedMessage =>
      'This browser does not support directly saving to a local file. Check browser download permissions or use file sharing instead.';

  @override
  String get switchToShare => 'Use sharing instead';

  @override
  String get fileSaveFailedTitle => 'File save failed';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Unable to write to the current path. The target folder may be protected, the file may be in use, or the path may be unwritable.';

  @override
  String get fileSaveFailedGenericMessage =>
      'The system could not save the file. You can retry, check system settings, or use file sharing instead.';

  @override
  String get retryLater => 'Try again later';

  @override
  String get exportSwitchedToShare => 'Switched to file sharing for export';

  @override
  String get saveFailedRetry => 'Save failed. Please try again later.';

  @override
  String get periodTimesUnsavedExitTitle => 'Changes not saved';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'The latest period-time changes could not be saved. You can retry, continue editing, or discard them.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Some period times are invalid. Fix them before saving, or discard these changes and leave.';

  @override
  String get discardChangesAndExit => 'Discard and exit';

  @override
  String get appInstanceBlockedTitle => 'Sked is al geopend';

  @override
  String get appInstanceBlockedMessage =>
      'Een ander Sked-venster of een ander browsertabblad gebruikt je lokale gegevens. Sluit het andere venster of tabblad en probeer het opnieuw.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Lokale gegevens zijn niet beschikbaar';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked kon de exclusieve toegang tot lokale gegevens niet controleren. Je gegevens zijn niet geopend of gewijzigd. Controleer de toegang tot de opslag en probeer het opnieuw.';

  @override
  String get savingChanges => 'Wijzigingen worden opgeslagen...';

  @override
  String get showApiKey => 'API-sleutel tonen';

  @override
  String get hideApiKey => 'API-sleutel verbergen';

  @override
  String get importFailedCheckContent =>
      'Import failed. Please check the file content.';

  @override
  String get noImportableTimetables =>
      'No usable timetables were found in the imported file.';

  @override
  String importedTimetablesCount(int count) {
    return 'Imported $count timetables';
  }

  @override
  String get periodTimesTitle => 'Period times';

  @override
  String get importExport => 'Import and export';

  @override
  String get importPeriodTemplate => 'Import period template';

  @override
  String get importPeriodTemplateText => 'Import period template from text';

  @override
  String get sharePeriodTemplate => 'Share period template';

  @override
  String get saveTemplateToFile => 'Save template to file';

  @override
  String get exportPeriodTemplateText => 'Export period template as text';

  @override
  String get deletePeriodTimeSet => 'Delete period time set';

  @override
  String get periodTimeSetName => 'Period time set name';

  @override
  String get addOnePeriod => 'Add period';

  @override
  String periodNumberLabel(int index) {
    return 'Period $index';
  }

  @override
  String get deleteThisPeriod => 'Delete this period';

  @override
  String durationMinutes(int minutes) {
    return 'Duration $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Gap from previous $minutes min';
  }

  @override
  String get endTimeMustBeLater => 'End time must be later than start time';

  @override
  String get periodOverlapPrevious => 'This period overlaps the previous one';

  @override
  String get periodTimesSaved => 'Period times saved';

  @override
  String get deletePeriodTimeSetTitle => 'Delete period time set';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'current period time set';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Imported $count period times';
  }

  @override
  String get periodFilePermissionTitle => 'File permission needed';

  @override
  String get androidFilePermissionMessage =>
      'Android export requires file access permission. Grant permission to continue saving.';

  @override
  String get reauthorize => 'Authorize again';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Permission permanently denied';

  @override
  String get permissionSettingsExportMessage =>
      'Enable file access in system settings, then return and try exporting again.';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get privacyPolicyEntryDesc =>
      'Learn how the app handles local storage, school-site configuration, file import/export, webpage parsing, and external links.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Accepted version: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked is een lokaal-eerst roosterhulpmiddel. Roosters, periodetijdsets en schoolwebsiteconfiguratie worden alleen op je apparaat of in je browser opgeslagen en worden nooit automatisch geüpload. De app verwerkt alleen gegevens wanneer je expliciet acties start zoals importeren, webpagina-analyse, delen of het openen van externe links. Het volledige privacybeleid is online beschikbaar.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Local storage';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Import and export';

  @override
  String get privacyPolicyImportExportBody =>
      'The app reads or writes timetable JSON files, school-site JSON files, and period-template files only when you explicitly choose a file or start an export action. Importing these files is a local operation unless you also choose webpage parsing. Fetching a custom model list is also an explicit network action and only contacts the custom endpoint you configured.';

  @override
  String get privacyPolicySharingTitle => 'Sharing';

  @override
  String get privacyPolicySharingBody =>
      'When you explicitly use sharing, the app passes the exported file to the system share sheet or to the target app you choose. How that file is handled afterward depends on the target app or service you selected.';

  @override
  String get privacyPolicyExternalLinksTitle => 'External links';

  @override
  String get privacyPolicyExternalLinksBody =>
      'When you open external links such as the GitHub repository, the app hands the action off to your browser or another external application. Data handling after that point is governed by the third party you open.';

  @override
  String get privacyPolicyNoCollectionTitle => 'What the app does not collect';

  @override
  String get privacyPolicyNoCollectionBody =>
      'The app does not require a Sked account and does not enable analytics, advertising identifiers, or cloud backup. It also does not provide a dedicated field for collecting school account passwords. If you sign in to a school website inside the app, that interaction happens on the school page you opened.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Webpage parsing';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Wanneer je schoolwebpagina-import gebruikt of geplakte roostertekst / HTML analyseert, bereidt en schoont de app de inhoud eerst lokaal op en verzendt daarna de ingediende roostertekst, paginatekst of HTML-inhoud, de optionele paginatitel en URL, de huidige app-taal en de parserprompt naar het OpenAI-compatibele endpoint dat je hebt geconfigureerd. Het ophalen van de modellenlijst vraagt ook datzelfde endpoint aan. Sked biedt geen ingebouwd parser-endpoint en verzendt geen parseraanvragen naar een door de ontwikkelaar beheerde roosterparser-backend. Het aangepaste endpoint en eventuele upstreamdiensten kunnen gegevens opslaan, doorsturen, beperken, verwijderen of anderszins verwerken volgens de regels van de door jou gekozen serviceprovider. Als je een http:// Base URL gebruikt, gebruik die dan alleen op vertrouwde apparaten, vertrouwde netwerken en vertrouwde endpointdiensten, omdat inhoud en API-sleutels mogelijk niet door transportversleuteling worden beschermd.';

  @override
  String get privacyPolicyUpdatesTitle => 'Policy updates';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'The current privacy policy version is $version. If a later version changes how data is handled, the app may ask you to read and agree to the updated policy again.';
  }

  @override
  String get privacyGateTitle =>
      'Please agree to the privacy policy before using the app';

  @override
  String get privacyGateSummaryStorage =>
      'Timetables, period-time sets, and school-site configuration are only stored locally and are not automatically uploaded to a developer server.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, export, and sharing only happen when you explicitly start them; webpage parsing sends only the submitted content to your configured parsing endpoint, and you can review the parsed timetable before saving.';

  @override
  String get privacyGateSummaryUpdates =>
      'If a later version changes how data is handled, the app may ask you to review the updated privacy policy again.';

  @override
  String get schoolWebImportEntry => 'Import from school webpage';

  @override
  String get schoolWebImportEntryDesc =>
      'Import the current timetable page from the school site.';

  @override
  String get schoolSitesManageEntry => 'Manage school sites';

  @override
  String get schoolSitesManageEntryDesc =>
      'Add, edit, and delete school login URLs, with JSON import and export.';

  @override
  String get schoolSitesPageTitle => 'School site management';

  @override
  String get schoolSitesImportJson => 'Import school JSON';

  @override
  String get schoolSitesShareJson => 'Share school JSON';

  @override
  String get schoolSitesSaveJson => 'Save school JSON';

  @override
  String get schoolSitesSaved => 'School sites saved';

  @override
  String get schoolSitesImported => 'School sites imported';

  @override
  String get schoolSitesImportPreviewTitle => 'Review school-site import';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount valid sites, $invalidCount invalid entries.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'The file contains an empty school-site list.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Entry $position is invalid and will be skipped.';
  }

  @override
  String get schoolSitesImportMerge => 'Merge';

  @override
  String get schoolSitesImportReplace => 'Replace';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Replace current school sites?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'This removes $currentCount current sites and saves $importedCount imported sites. This cannot be undone.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'School-site data needs recovery';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked could not read the school-site file or its backup. Protected copies were created before writes were blocked.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'School-site storage is unavailable';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked cannot access school-site storage right now. Retry after checking storage access or device availability. Current site data will not be overwritten.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Recovery files or affected storage locations are listed below. Keep any files unchanged until the site list is recovered.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Start with no school sites';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Start with an empty school-site list?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Protected copies will be kept, but Sked will create a new empty school-site file. Continue only if you do not want to retry recovery first.';

  @override
  String get schoolSitesEmpty => 'No school site configuration yet.';

  @override
  String get schoolSitesNameLabel => 'School name';

  @override
  String get schoolSitesLoginUrlLabel => 'Login URL';

  @override
  String get schoolSitesAdd => 'Add school';

  @override
  String get schoolSitesEdit => 'Edit school';

  @override
  String get schoolSitesDeleteTitle => 'Delete school';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Fill in the school name and login URL first.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Import by pasting timetable page content';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Paste source code or raw page content containing timetable information manually.';

  @override
  String get schoolHtmlImportPageTitle => 'Parse timetable from page content';

  @override
  String get schoolHtmlImportUrlLabel => 'Source URL (optional)';

  @override
  String get schoolHtmlImportTitleLabel => 'Page title (optional)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Page content';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Paste source code or raw page content containing timetable information here.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Any content containing timetable information can be parsed and imported, not just HTML.';

  @override
  String get schoolHtmlImportCompress => 'Inhoud voorbereiden';

  @override
  String get schoolHtmlImportCompressed => 'Inhoud voorbereid';

  @override
  String get schoolHtmlImportCompressFirst => 'Bereid eerst de inhoud voor.';

  @override
  String get schoolHtmlImportSubmit => 'Parse and import';

  @override
  String get schoolImportContentTruncated =>
      'Deze pagina heeft de veilige importlimiet bereikt. Alleen het vastgelegde gedeelte wordt verzonden voor analyse.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsing may take a while. Please wait.';

  @override
  String get schoolHtmlImportEmpty => 'Paste the page HTML first.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Back to webpage';

  @override
  String get schoolWebImportPageTitle => 'School webpage import';

  @override
  String get schoolWebImportPreview => 'Import preview';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count courses';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count periods';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Page title';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Import notes';

  @override
  String get schoolWebImportParserDetails => 'Analysedetails';

  @override
  String get schoolWebImportExpandParserDetails => 'Analysedetails uitvouwen';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Analysedetails samenvouwen';

  @override
  String get schoolWebImportOpenPageHint =>
      'Sign in to the school site in-app, then navigate to the timetable page manually.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'This platform does not support embedded web login yet. Please use a platform with WebView support.';

  @override
  String get schoolWebImportSelectSchool => 'Choose school';

  @override
  String get schoolWebImportNoSchools =>
      'No school configuration is available. Check school_sites.json first.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Failed to load school configuration. Check the JSON file format.';

  @override
  String get schoolWebImportImportCurrentPage => 'Import current page';

  @override
  String get schoolWebImportLoadingPage => 'Loading page…';

  @override
  String get schoolWebImportParsing => 'Parsing current page…';

  @override
  String get schoolWebImportLoadFailed =>
      'Page load failed. Please refresh or try again later.';

  @override
  String get schoolWebImportUnknownOrigin => 'Onbekende website';

  @override
  String get schoolWebImportExitTitle => 'Browser verlaten?';

  @override
  String get schoolWebImportExitMessage =>
      'De pagina wordt gesloten. Alles wat u nog niet hebt geïmporteerd, gaat verloren.';

  @override
  String get schoolWebImportExitConfirm => 'Verlaten';

  @override
  String get schoolWebImportEmptyPage =>
      'The current page content is empty and cannot be imported yet.';

  @override
  String get schoolWebImportSuccess => 'Web timetable imported';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Parser source';

  @override
  String get schoolImportParserSourceCustomOpenAi => 'Custom OpenAI-compatible';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Custom OpenAI-compatible parser';

  @override
  String get schoolImportParserCustomPromptTitle => 'Custom prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Edit the built-in parser prompt here. Changes only affect the custom OpenAI-compatible parser.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'The built-in prompt is loaded here by default. Clear it to fall back to the built-in version.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Reset default prompt';

  @override
  String get schoolImportParserBaseUrl => 'Base URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'De Base URL moet een HTTP- of HTTPS-URL met host zijn.';

  @override
  String get schoolImportParserApiKey => 'API key';

  @override
  String get schoolImportParserModel => 'Model';

  @override
  String get schoolImportParserFetchModels => 'Fetch model list';

  @override
  String get schoolImportParserFetchingModels => 'Fetching models...';

  @override
  String get schoolImportParserNoModelsFound =>
      'No models were returned by the endpoint.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Kan modellen niet ophalen. Controleer het eindpunt en probeer het opnieuw.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Fetched $count models';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Een niet-versleuteld HTTP-eindpunt gebruiken?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'De API-sleutel en de inhoud van het rooster kunnen tijdens de overdracht worden gelezen of gewijzigd. Ga alleen door als u dit apparaat, netwerk en eindpunt vertrouwt. Deze toestemming blijft geldig totdat u Sked sluit.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get clearAppData => 'Clear data';

  @override
  String get clearAppDataDesc =>
      'Permanently delete all local Sked data and exit the app';

  @override
  String get clearAppDataConfirmTitle => 'Clear all Sked data?';

  @override
  String get clearAppDataConfirmMessage =>
      'This permanently deletes timetables, schedules, settings, school sites, local backups, recovery copies, and the AI API key, then exits Sked. Files you exported elsewhere are not deleted. This cannot be undone.';

  @override
  String get clearAppDataAction => 'Clear data and exit';

  @override
  String get clearAppDataFailed =>
      'Unable to clear all local data. Sked will remain open so you can retry.';

  @override
  String get clearAppDataExitFailed =>
      'Your local data was cleared, but Sked could not exit. Close the app manually before using it again.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Parser: Custom ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'View full privacy policy';

  @override
  String get privacyAgreeAndContinue => 'Agree and continue';

  @override
  String get privacyDecline => 'Decline';

  @override
  String get privacyDeclineWebHint =>
      'This browser environment does not allow the app to close the page for you. If you do not agree, please close this tab or window yourself.';

  @override
  String get defaultPeriodTimeSetName => 'Default periods';

  @override
  String get periodTimeSetFallbackName => 'Period times';

  @override
  String get untitledTimetableName => 'Untitled timetable';

  @override
  String get newTimetableName => 'New timetable';

  @override
  String get newPeriodTimeSetName => 'New period time set';

  @override
  String get emptyTimetableName => 'Empty timetable';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name periods';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Import file type does not match.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'This import file version is not supported yet.';

  @override
  String get noPeriodTimesInImportMessage =>
      'No period times found in the import file.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Please select at least one timetable.';

  @override
  String get noExportableTimetableMessage =>
      'There is no timetable available to export.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Replacing the current timetable only supports selecting one timetable.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'There is no current timetable to replace.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'This period time set is still used by $count timetable(s). Reassign them before deleting.';
  }

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdayTuesday => 'Tuesday';

  @override
  String get weekdayWednesday => 'Wednesday';

  @override
  String get weekdayThursday => 'Thursday';

  @override
  String get weekdayFriday => 'Friday';

  @override
  String get weekdaySaturday => 'Saturday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get weekdayShortMonday => 'Mon';

  @override
  String get weekdayShortTuesday => 'Tue';

  @override
  String get weekdayShortWednesday => 'Wed';

  @override
  String get weekdayShortThursday => 'Thu';

  @override
  String get weekdayShortFriday => 'Fri';

  @override
  String get weekdayShortSaturday => 'Sat';

  @override
  String get weekdayShortSunday => 'Sun';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'Feb';

  @override
  String get monthMarch => 'Mar';

  @override
  String get monthApril => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'Jun';

  @override
  String get monthJuly => 'Jul';

  @override
  String get monthAugust => 'Aug';

  @override
  String get monthSeptember => 'Sep';

  @override
  String get monthOctober => 'Oct';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Dec';

  @override
  String get semesterWeeksWholeTerm => 'All semester';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Weeks $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Weeks $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Kies je startmodus';

  @override
  String get firstLaunchSubtitle =>
      'Kies de werkruimte die je het meest gebruikt. Je kunt later van modus wisselen.';

  @override
  String get firstLaunchStudentDesc =>
      'Beheer roosters, vakken, weken, lestijden en import.';

  @override
  String get firstLaunchGeneralDesc =>
      'Beheer categorieën, evenementen, herinneringen en JSON / ICS-gegevens.';

  @override
  String get firstLaunchStartStudent => 'Starten met rooster';

  @override
  String get firstLaunchStartGeneral => 'Starten met agenda';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Door een startwerkruimte te kiezen, bevestig je dat je het ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Privacybeleid';

  @override
  String get firstLaunchPrivacyConsentAfter =>
      ' hebt gelezen en ermee akkoord gaat.';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'Vandaag';

  @override
  String get addEvent => 'Add event';

  @override
  String get editEvent => 'Edit event';

  @override
  String get eventTitle => 'Title';

  @override
  String get eventTitleRequired => 'Title is required';

  @override
  String get eventStartTime => 'Start time';

  @override
  String get eventEndTime => 'End time';

  @override
  String get eventDate => 'Date';

  @override
  String get eventTime => 'Time';

  @override
  String get eventNotes => 'Notes';

  @override
  String get eventColor => 'Color';

  @override
  String get eventRecurrence => 'Repeat';

  @override
  String get recurrenceNone => 'Does not repeat';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceEndDate => 'End date';

  @override
  String get recurrenceNoEndDate => 'No end date';

  @override
  String get recurrenceSetEndDate => 'Set';

  @override
  String get recurrenceChangeEndDate => 'Change';

  @override
  String get repeatsWeekly => 'Repeats weekly';

  @override
  String recurrenceUntil(Object date) {
    return 'Until $date';
  }

  @override
  String get switchToGeneralSchedule => 'Switch to General schedule';

  @override
  String get generalDisplaySettings => 'General display settings';

  @override
  String get generalDisplaySettingsDesc =>
      'Weergaven, werkbalk, datumnotatie en snel toevoegen';

  @override
  String get closePopupOnOutsideTap => 'Close popup on tap outside';

  @override
  String get showGridLines => 'Show grid lines';

  @override
  String get generalScheduleImportExport => 'Category import & export';

  @override
  String get generalScheduleImportExportDesc =>
      'Import or share schedule categories';

  @override
  String get importGeneralSchedules => 'Import categories';

  @override
  String get importGeneralSchedulesDesc => 'Read categories from a JSON file';

  @override
  String get shareGeneralSchedules => 'Share categories';

  @override
  String get shareGeneralSchedulesDesc => 'Share categories as a JSON file';

  @override
  String get saveGeneralSchedules => 'Save categories';

  @override
  String get saveGeneralSchedulesDesc => 'Save categories as a JSON file';

  @override
  String get selectSchedulesToExport => 'Select categories to export';

  @override
  String get selectSchedulesToImport => 'Select categories to import';

  @override
  String generalScheduleEventCount(int count) {
    return 'Events: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Imported $count categories';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Add the import as a new category or replace an existing category?';

  @override
  String get addAsNewSchedule => 'Add as new category';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Please select at least one category.';

  @override
  String get noExportableScheduleMessage => 'No category available to export.';

  @override
  String get noSchedulesInImportMessage =>
      'Import file contains no categories.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Choose exactly one imported category for replacement.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'The selected replacement category is unavailable.';

  @override
  String get calendars => 'Categories';

  @override
  String get calendar => 'Category';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewDay => 'Dag';

  @override
  String get viewList => 'List';

  @override
  String get viewMonth => 'Month';

  @override
  String visibleCategoryCount(int count) {
    return '$count categories';
  }

  @override
  String get noVisibleCategories => 'No visible categories';

  @override
  String get selectCategoryToReplace => 'Choose category to replace';

  @override
  String get replaceCategory => 'Replace category';

  @override
  String get deleteEventTitle => 'Delete event';

  @override
  String get deleteEventConfirmation =>
      'This event will be permanently deleted.';

  @override
  String get deleteRecurringEventTitle => 'Delete recurring event';

  @override
  String get eventDuplicated => 'Event duplicated';

  @override
  String get searchEvents => 'Search events';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filterByColor => 'Filter by color';

  @override
  String get allColors => 'All colors';

  @override
  String upcomingEventsCount(int count) {
    return 'Upcoming $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Overdue $count';
  }

  @override
  String get allDay => 'All-day';

  @override
  String get collapseAllDayTimeline => 'Collapse all-day events';

  @override
  String get expandAllDayTimeline => 'Expand all-day events';

  @override
  String allDayEventsCount(int count) {
    return '$count all-day events';
  }

  @override
  String moreEvents(int count) {
    return '+$count more';
  }

  @override
  String get noMatchingEvents => 'No matching events';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get addCalendar => 'Add category';

  @override
  String get newCalendar => 'New category';

  @override
  String get hideCalendar => 'Hide category';

  @override
  String get showCalendar => 'Show category';

  @override
  String get rename => 'Rename';

  @override
  String get renameCalendar => 'Rename category';

  @override
  String get name => 'Name';

  @override
  String get deleteCalendar => 'Delete category';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteThisOccurrence => 'Delete this occurrence';

  @override
  String get deleteFutureOccurrences => 'Delete this and following';

  @override
  String get deleteAllOccurrences => 'Delete entire series';

  @override
  String get duplicateEvent => 'Duplicate';

  @override
  String get repeatsDaily => 'Repeats daily';

  @override
  String get repeatsMonthly => 'Repeats monthly';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Repeats every $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count times';
  }

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceCustom => 'Custom';

  @override
  String get recurrenceEvery => 'Every';

  @override
  String get recurrenceUnit => 'Unit';

  @override
  String get recurrenceDays => 'Days';

  @override
  String get recurrenceWeeks => 'Weeks';

  @override
  String get recurrenceMonths => 'Months';

  @override
  String get recurrenceRepeatCount => 'Repeat count';

  @override
  String get recurrenceNoLimit => 'No limit';

  @override
  String get recurrencePositiveNumber => 'Enter a positive number';

  @override
  String get clearEndDate => 'Clear end date';

  @override
  String get pickDate => 'Pick date';

  @override
  String get pickTime => 'Pick time';

  @override
  String get reminder => 'In-app reminder';

  @override
  String get reminderAtStart => 'At start';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get reminderHourBefore => '1 hour before';

  @override
  String get reminderDayBefore => '1 day before';

  @override
  String get markReminderHandled => 'Mark handled';

  @override
  String get restoreReminder => 'Restore in-app reminder';

  @override
  String get reminderHandled => 'In-app reminder marked handled';

  @override
  String get reminderRestored => 'In-app reminder restored';

  @override
  String get reminderUpcoming => 'Upcoming';

  @override
  String get reminderOverdue => 'Overdue';

  @override
  String get showWeekends => 'Show weekends';

  @override
  String get startHour => 'Start hour';

  @override
  String get endHour => 'End hour';

  @override
  String get timeGridDensity => 'Time grid density';

  @override
  String get timeGridHourHeight => 'Hour row height';

  @override
  String get timeGridHourHeightHint =>
      'Adjusts the vertical scale of day and week views without changing the 15, 30, or 60 minute grid interval.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Import JSON file';

  @override
  String get pasteJson => 'Paste JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Import categories from copied JSON';

  @override
  String get importIcsFile => 'Import ICS file';

  @override
  String get importIcsFileDesc => 'Read events from an .ics calendar file';

  @override
  String get pasteIcs => 'Paste ICS';

  @override
  String get pasteIcsDesc => 'Import events from copied calendar text';

  @override
  String get copyJson => 'Copy JSON';

  @override
  String get copyJsonDesc => 'Copy selected categories as JSON text';

  @override
  String get shareIcs => 'Share ICS';

  @override
  String get shareIcsDesc => 'Share selected calendars as .ics';

  @override
  String get saveIcs => 'Save ICS';

  @override
  String get saveIcsDesc => 'Save selected calendars as .ics';

  @override
  String get copyIcs => 'Copy ICS';

  @override
  String get copyIcsDesc => 'Copy selected calendars as ICS text';

  @override
  String get importIcs => 'Import ICS';

  @override
  String get icsContent => 'ICS content';

  @override
  String get pasteIcsContentHint => 'Paste BEGIN:VCALENDAR content here';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Found $count events. Add them as a new category or replace an existing category?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Imported $count categories with $warningCount warnings';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Skipped an event without a start time.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Skipped an event with an unsupported start time.';

  @override
  String get importWarningAdjustedEnd =>
      'Adjusted an event whose end time was not after its start.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Unsupported ICS fields were added to notes: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Ignored unsupported repeat frequency: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'Select calendars to copy as ICS';

  @override
  String get selectCalendarsToExportIcs => 'Select calendars to export as ICS';

  @override
  String get exportIcsText => 'Export ICS text';

  @override
  String get exportJsonText => 'Export JSON text';

  @override
  String get dataRestoredFromBackupNotice =>
      'App data was restored from the previous backup because the main file failed to load.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Both the main data file and its backup are damaged. The app is now using a fresh state.';

  @override
  String get dataRecoveryCorruptTitle => 'Your data needs recovery';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked could not read the main data file or its backup. Protected copies were created before writes were blocked.';

  @override
  String get dataRecoveryIoFailureTitle => 'Storage is unavailable';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked cannot access local storage right now. Retry after checking storage access or device availability. Existing data will not be overwritten.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Update Sked to open this data';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'This data was created by a newer version of Sked. Update the app before trying again. Starting fresh is disabled to protect it.';

  @override
  String get dataRecoveryRetryAction => 'Retry';

  @override
  String get dataRecoveryArtifactsHint =>
      'Recovery files or affected storage locations are listed below. Keep any files unchanged until your data is recovered.';

  @override
  String get dataRecoveryArtifactsAction => 'Show recovery files and locations';

  @override
  String get dataRecoveryStartFreshAction => 'Start with new data';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Start with new data?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Protected copies will be kept, but Sked will create a new local data file. Continue only if you do not want to retry recovery first.';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'In progress';

  @override
  String get deleteCourseTitle => 'Delete course';

  @override
  String get deleteCourseMessage => 'Delete this course?';

  @override
  String get showLunarCalendar => 'Show lunar calendar';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count events';
  }

  @override
  String get defaultView => 'Default view';

  @override
  String get generalDefaultViewSection => 'Startup';

  @override
  String get generalViewSwitchBehavior => 'View switch button';

  @override
  String get settingsWorkspaceMode => 'Active workspace';

  @override
  String get hideHomeWorkspaceNavigation => 'Hide workspace navigation';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Hides the bottom bar, navigation rail, or sidebar. Switch workspaces from Settings.';

  @override
  String get generalDateLabelFormat => 'Date label format';

  @override
  String get generalDateLabelFormatLocalized => 'Localized (2026 Jul)';

  @override
  String get generalDateLabelFormatSlash => 'Slash (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Toolbar layout';

  @override
  String get toolbarNavigationSection => 'Toolbar navigation';

  @override
  String get toolbarNavigationHiddenBehavior => 'Hidden items';

  @override
  String get toolbarNavigationRemove => 'Hide completely';

  @override
  String get toolbarNavigationMore => 'Move into More';

  @override
  String get toolbarNavigationReorder => 'Reorder toolbar items';

  @override
  String get toolbarNavigationVisibility => 'Show toolbar item';

  @override
  String get toolbarNavigationTimetable => 'Timetable selector';

  @override
  String get toolbarNavigationWeek => 'Week selector';

  @override
  String get toolbarNavigationView => 'View switcher';

  @override
  String get toolbarNavigationCategory => 'Category selector';

  @override
  String get toolbarNavigationDate => 'Date selector';

  @override
  String get generalToolbarWidthPolicy => 'Toolbar space allocation';

  @override
  String get generalToolbarWidthContent => 'Automatic allocation';

  @override
  String get generalToolbarWidthBalanced => 'Balanced';

  @override
  String get generalToolbarWidthCalendarPriority => 'Category priority';

  @override
  String get generalToolbarWidthDatePriority => 'Date priority';

  @override
  String get generalViewSwitchCycle => 'Cycle through views';

  @override
  String get generalViewSwitchMenu => 'Open view menu';

  @override
  String get generalViewSwitchTooltip => 'Switch view';

  @override
  String get generalViewSwitchMenuTooltip => 'Choose view';

  @override
  String get generalViewLongPressTodayHint => 'Long-press to go to today';

  @override
  String get generalScheduleDisplaySection => 'Schedule display';

  @override
  String get generalTimeGridSection => 'Time grid';

  @override
  String get generalPopupSection => 'Popup behavior';

  @override
  String get quickActionsSection => 'Quick actions';

  @override
  String get showAddCourseFab => 'Show floating add course button';

  @override
  String get showAddCourseFabHint =>
      'Show or hide the floating add course button in the bottom-right corner of the timetable.';

  @override
  String get showAddEventFab => 'Show floating add event button';

  @override
  String get showAddEventFabHint =>
      'Show or hide the floating add event button in the bottom-right corner of the schedule.';

  @override
  String get enableLongPressAddCourse => 'Long-press blank grid to add courses';

  @override
  String get enableLongPressAddCourseHint =>
      'Long-press an empty area of the timetable grid to add a course.';

  @override
  String get enableLongPressAddEvent => 'Long-press blank grid to add events';

  @override
  String get enableLongPressAddEventHint =>
      'In day or week view, long-press an empty area of the time grid to add an event.';

  @override
  String get developerModeTitle => 'Ontwikkelaarsmodus';

  @override
  String get developerModeDescription =>
      'Hulpmiddelen om volledige voorbeeldgegevens toe te voegen voor controle van weergave en interactie.';

  @override
  String get developerSampleLanguage => 'Taal van voorbeeldgegevens';

  @override
  String get developerSampleChinese => 'Chinees';

  @override
  String get developerSampleEnglish => 'Engels';

  @override
  String get developerSampleDataDescription =>
      'Voegt één rooster en een set categorieën en afspraken toe zonder bestaande gegevens te vervangen.';

  @override
  String get developerAddSampleData => 'Voorbeeldgegevens toevoegen';

  @override
  String get developerSampleDataAdded =>
      'Voorbeeldrooster en -afspraken toegevoegd.';

  @override
  String get developerModeLongPressHint =>
      'Houd 3 seconden ingedrukt om de ontwikkelaarsmodus te openen';

  @override
  String get developerNotificationDiagnostics => 'Notification diagnostics';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Inspect Android delivery state, rebuild the existing reminder plan, and send safe test notifications through Sked\'s normal notification service.';

  @override
  String get developerNotificationUnsupported =>
      'Notification diagnostics are available on Android only.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Notification diagnostics are unavailable until the agenda coordinator starts.';

  @override
  String get developerNotificationRefresh => 'Refresh diagnostics';

  @override
  String get developerNotificationSystemStatus =>
      'System notification permission';

  @override
  String get developerNotificationPermissionAllowed => 'Allowed';

  @override
  String get developerNotificationPermissionBlocked => 'Blocked';

  @override
  String get developerNotificationExactAlarm => 'Exact alarms';

  @override
  String get developerNotificationExactAlarmAllowed => 'Allowed';

  @override
  String get developerNotificationExactAlarmInexact => 'Inexact fallback';

  @override
  String get developerNotificationPlan => 'Agenda notification plan';

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled scheduled, $planned planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Last error: $message';
  }

  @override
  String get developerNotificationRunMaintenance => 'Rebuild notification plan';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Notification plan rebuilt.';

  @override
  String get developerNotificationTestChannel => 'Test channel';

  @override
  String get developerNotificationTestCourse => 'Course reminders';

  @override
  String get developerNotificationTestSchedule => 'Schedule reminders';

  @override
  String get developerNotificationImmediateTest => 'Send immediate test';

  @override
  String get developerNotificationThirtySecondTest =>
      'Schedule 30-second background test';

  @override
  String get developerNotificationImmediateQueued =>
      'Immediate test notification sent.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Background test scheduled for 30 seconds.';

  @override
  String get developerNotificationAppSwitch => 'App reminder switch';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Enabled for normal reminders';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Disabled for normal reminders; developer tests can still run';

  @override
  String get developerNotificationTimeZone => 'Local time zone';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Not created yet. A developer test will create it.';

  @override
  String get developerNotificationChannelEnabledState => 'Enabled';

  @override
  String get developerNotificationChannelBlockedState => 'Blocked';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Importance: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Importance unavailable';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'No reconciliation recorded yet.';

  @override
  String get developerNotificationNextReminder => 'Next real reminder';

  @override
  String get developerNotificationNoPendingReminder =>
      'No future reminder in the current plan';

  @override
  String get developerNotificationNextMaintenance => 'Next maintenance';

  @override
  String get developerNotificationNoMaintenance => 'Not scheduled';

  @override
  String get developerNotificationTruncation => 'Plan truncation';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count omitted by the plan limit';
  }

  @override
  String get developerNotificationLastReconciliation => 'Latest reconciliation';

  @override
  String developerNotificationReconciliationSummary(
    Object origin,
    Object mode,
    Object result,
    Object time,
  ) {
    return '$origin · $mode · $result · $time';
  }

  @override
  String get developerNotificationReconcileOriginForeground => 'Foreground';

  @override
  String get developerNotificationReconcileOriginBackground => 'Background';

  @override
  String get developerNotificationReconcileModeAuthoritative => 'Authoritative';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Maintenance';

  @override
  String get developerNotificationReconcileResultSuccess => 'Succeeded';

  @override
  String get developerNotificationReconcileResultSkipped => 'Skipped';

  @override
  String get developerNotificationReconcileResultFailed => 'Failed';

  @override
  String get developerNotificationTestChecking =>
      'Tests are unavailable while notification status is being checked.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Tests are unavailable because system notifications are blocked.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Tests are unavailable because the selected notification channel is blocked.';

  @override
  String get collapseWorkspaceNavigation => 'Werkruimtenavigatie inklappen';

  @override
  String get expandWorkspaceNavigation => 'Werkruimtenavigatie uitklappen';

  @override
  String get schoolWebImportExitBrowser => 'Ingebouwde browser sluiten';

  @override
  String get schoolWebImportEditAddress => 'Adres bewerken';

  @override
  String get schoolWebImportAddressLabel => 'Webadres';

  @override
  String get schoolWebImportOpenAddress => 'Openen';

  @override
  String get schoolWebImportAddressInvalid =>
      'Voer een HTTP- of HTTPS-adres met een host in.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Deze webpagina heeft een nieuw venster aangevraagd dat niet op dit apparaat kan worden geopend.';

  @override
  String get schoolWebImportSecureConnection => 'Beveiligde verbinding';

  @override
  String get schoolWebImportInsecureConnection => 'Onveilige verbinding';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Aanmelden bij de school openen?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Bij aanmelden bij de school kunnen aanmeldgegevens via formulieren of serveromleidingen naar de school en haar aanmeldproviders worden verzonden. Android kan niet elke dergelijke overdracht onderbreken voor een afzonderlijke bevestiging van de bestemming. Ga alleen door als u hen voor deze importsessie vertrouwt:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Onveilige schoolaanmelding openen?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Deze schoolaanmelding gebruikt HTTP. Iedereen die deze verbinding kan volgen of wijzigen, kan uw aanmeldgegevens en de pagina-inhoud lezen of veranderen. Ga alleen door als u dit risico accepteert voor:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Reminders & notifications';

  @override
  String get notificationSettingsEnabled =>
      'Enable reminders and notifications';

  @override
  String get notificationSettingsEnabledHint =>
      'Schedules only items with a reminder. Set a course default below for courses that inherit it.';

  @override
  String get notificationSettingsEnabledSummary => 'Enabled';

  @override
  String get notificationSettingsDisabledSummary => 'Disabled';

  @override
  String get notificationDefaultsSection => 'Default reminders';

  @override
  String get notificationCourseDefaultReminder => 'Course default reminder';

  @override
  String get notificationGeneralDefaultReminder => 'Schedule default reminder';

  @override
  String get notificationReminderOff => 'No reminder';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get notificationPermission => 'Notification permission';

  @override
  String get notificationPermissionGranted => 'Allowed by the system';

  @override
  String get notificationPermissionDenied => 'Blocked by the system';

  @override
  String get notificationPermissionChecking => 'Checking permission…';

  @override
  String get notificationPermissionRequest => 'Request permission';

  @override
  String get notificationPermissionOpenSettings => 'Open system settings';

  @override
  String get notificationPermissionRequestFailed =>
      'Could not read notification permission. Try again.';

  @override
  String get notificationExactAlarm => 'Exact alarm permission';

  @override
  String get notificationExactAlarmAllowed => 'Allowed by the system';

  @override
  String get notificationExactAlarmRequired =>
      'Required for precise reminder times';

  @override
  String get notificationExactAlarmRequest => 'Allow exact alarms';

  @override
  String get notificationLockScreenTitles => 'Show titles on the lock screen';

  @override
  String get notificationLockScreenTitlesHint =>
      'When off, notification details stay private on the lock screen.';

  @override
  String get notificationWidgets => 'Home screen widgets';

  @override
  String get notificationWidgetsDesc =>
      'Refresh Sked widgets and learn how to add one from the launcher.';

  @override
  String get notificationWidgetsDialogTitle => 'Add a Sked widget';

  @override
  String get notificationWidgetsDialogMessage =>
      'From your device launcher, touch and hold an empty area, choose Widgets, and add a Sked widget. The widget shows your next courses or events.';

  @override
  String get notificationWidgetsRefresh => 'Refresh widgets';

  @override
  String get notificationWidgetsRefreshed => 'Widgets refreshed';

  @override
  String get notificationPlatformUnsupported =>
      'This platform does not provide native notifications.';
}
