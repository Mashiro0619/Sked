// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'Klasskamrat';

  @override
  String weekLabel(int week) {
    return 'Vecka $week';
  }

  @override
  String get addCourse => 'Lägg till kurs';

  @override
  String get settings => 'Inställningar';

  @override
  String get multiTimetableSwitch => 'Byt tidtabeller';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Aktuell tidtabell · $weeks veckor';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tryck för att växla · $weeks veckor';
  }

  @override
  String get editTimetable => 'Redigera tidtabell';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get schoolImportParsePageTitle => 'Analysera schema';

  @override
  String get schoolImportParsePageParsing => 'Analyserar…';

  @override
  String get schoolImportParsePageFailed => 'Analysen misslyckades';

  @override
  String get schoolImportParsePageComplete => 'Analysen är klar';

  @override
  String get schoolImportParsePageContinue => 'Fortsätt';

  @override
  String get schoolImportParsePageRawContent => 'Rått svar';

  @override
  String get schoolImportParsePageExpandRaw => 'Expandera rått svar';

  @override
  String get schoolImportParsePageCollapseRaw => 'Fäll ihop rått svar';

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
  String get createTimetable => 'Ny tidtabell';

  @override
  String get jumpToWeek => 'Hoppa till veckan';

  @override
  String get timetable => 'Tidsplan';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Tidsplan namn';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Totalt veckor';

  @override
  String get delete => 'Ta bort';

  @override
  String get cancel => 'Avbryt';

  @override
  String get save => 'Spara';

  @override
  String get deleteTimetableTitle => 'Ta bort tidsplan';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Ta bort \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Ingen tidtabell ännu';

  @override
  String get noTimetableMessage =>
      'Skapa en tidsplan eller importera en från en JSON-fil.';

  @override
  String get importTimetable => 'Importera tidtabell';

  @override
  String get courseName => 'Kursnamn';

  @override
  String get location => 'Läge';

  @override
  String get dayOfWeek => 'dag';

  @override
  String get semesterWeeks => 'veckor';

  @override
  String get startTime => 'Starttid';

  @override
  String get endTime => 'Sluttid';

  @override
  String get linkedPeriods => 'Länkade perioder';

  @override
  String get linkedPeriodsUnmatched =>
      'Inga perioder matchade för aktuell tid. Tryck för att välja manuellt.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Period $start-$end';
  }

  @override
  String get teacherName => 'Lärare';

  @override
  String get credits => 'Krediter';

  @override
  String get remarks => 'Anmärkningar';

  @override
  String get customFields => 'Anpassade fält';

  @override
  String get customFieldsHint => 'En per rad, format: nyckel:värde';

  @override
  String get more => 'Mer';

  @override
  String get selectDayOfWeek => 'Välj dag';

  @override
  String get selectSemesterWeeks => 'Välj veckor';

  @override
  String get selectAll => 'Välj alla';

  @override
  String get clear => 'Rensa';

  @override
  String get confirm => 'Bekräfta';

  @override
  String get selectLinkedPeriods => 'Välj länkade perioder';

  @override
  String get addCourseTitle => 'Lägg till kurs';

  @override
  String get editCourseTitle => 'Redigera kurs';

  @override
  String get editCourseTooltip => 'Redigera kurs';

  @override
  String get place => 'Läge';

  @override
  String get time => 'Tid';

  @override
  String get notFilled => 'Inte fyllt';

  @override
  String get none => 'Ingen';

  @override
  String get conflictCourses => 'Konflikterande kurser';

  @override
  String get locationNotFilled => 'Plats inte fyllt';

  @override
  String get setAsDisplayed => 'Ange som visas';

  @override
  String get editThisCourse => 'Redigera denna kurs';

  @override
  String get settingsTitle => 'Inställningar';

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
      'Ingen tidsplan finns för närvarande tillgänglig för inställningar.';

  @override
  String get semesterStartDate => 'Startdatum för terminen';

  @override
  String get periodTimeSets => 'Periodisk tidsinställning';

  @override
  String get noPeriodTimeAvailable => 'Ingen tillgänglig tidsperiod';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count perioder';
  }

  @override
  String get coursePopupDismissSetting =>
      'Tillåt att trycka utanför för att stänga kurs popup';

  @override
  String get coursePopupDismissSettingHint =>
      'Om du stänger av detta inaktiverar du också svepningsnedladdning.';

  @override
  String get preserveTimetableGaps => 'Behålla tidstabellsluckor';

  @override
  String get preserveTimetableGapsHint =>
      'När du är av kollapsar lunch- och pausluckor så att senare klasser flyttar uppåt.';

  @override
  String get showPastEndedCourses => 'Visa tidigare avslutade kurser';

  @override
  String get showPastEndedCoursesHint =>
      'Visa kurser som redan har avslutats av den verkliga aktuella veckan med en ljusgrå stil.';

  @override
  String get showFutureCourses => 'Visa framtida kurser';

  @override
  String get showFutureCoursesHint =>
      'Visa kurser som inte är aktiva denna vecka men kommer att visas senare veckor med en grå stil.';

  @override
  String get timetableDisplaySettings => 'Tidsplan visning och interaktion';

  @override
  String get timetableDisplaySettingsDesc =>
      'Kursvisning, layout, veckogester och snabbtillägg';

  @override
  String get showTimetableGridLines => 'Visa rutnätlinjer i tidtabellen';

  @override
  String get showTimetableGridLinesHint =>
      'Kontrollera om horisontella och vertikala nätlinjer är synliga i schemat.';

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
  String get liveCourseOutlineColor => 'Färg på kursen';

  @override
  String get liveCourseOutlineColorHint =>
      'Välj om konturerna riktar sig till nuvarande/nästa kurs eller alla kurser som visas på den aktuella sidan.';

  @override
  String get liveCourseOutlineSettings => 'Kursbeskrivning';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Konfigurera om konturen är aktiverad, vad den riktar sig till, om den följer temafärgen och den effektiva konturfärgen.';

  @override
  String get liveCourseOutlineEnabled => 'Aktivera kontur';

  @override
  String get liveCourseOutlineFollowTheme => 'Följ temafärg';

  @override
  String get liveCourseOutlineTarget => 'Omfattande mål';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Aktuell/nästa kurs';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Alla kurser som visas';

  @override
  String get liveCourseOutlineEffectiveColor => 'Effektiv färg';

  @override
  String get liveCourseOutlineCustomColor => 'Anpassad konturfärg';

  @override
  String get liveCourseOutlineWidth => 'Omrisbredd';

  @override
  String get outlineWidthUnit => 'Px';

  @override
  String get language => 'Språk';

  @override
  String get languagePageDescription =>
      'Välj ett av de språk som verkligen är tillgängliga i appen.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'Svenska';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API-svar';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Följ systemet';

  @override
  String get themeLight => 'Ljus';

  @override
  String get themeDark => 'mörk';

  @override
  String get themeColor => 'Temafärg';

  @override
  String get themeColorModeSingle => 'Färg för ett tema';

  @override
  String get themeColorModeColorful => 'Färgrika';

  @override
  String get themeColorUiColors => 'UI färger';

  @override
  String get themeColorCourseColors => 'Kursfärger';

  @override
  String get themeColorPrimary => 'Primära';

  @override
  String get themeColorSecondary => 'Sekundär';

  @override
  String get themeColorTertiary => 'Tertiär';

  @override
  String get themeColorCourseText => 'Kurstext';

  @override
  String get themeColorCourseTextAuto => 'automatiskt';

  @override
  String get themeColorCourseTextCustom => 'Anpassad färg';

  @override
  String get themeColorCourseColorsEmpty =>
      'Kursfärger genereras efter import av en tidsplan.';

  @override
  String get themeCustomColor => 'Anpassad färg';

  @override
  String get themeApplyCustomColor => 'Använd färg';

  @override
  String get themeApplySettings => 'Använd inställningar';

  @override
  String get dataImportExport => 'Import och export av data';

  @override
  String get dataImportExportDesc =>
      'Importera hela data eller enskilda tidtabeller eller exportera aktuella/alla tidtabeller.';

  @override
  String get appBackupTitle => 'Appsäkerhetskopia och återställning';

  @override
  String get appBackupSubtitle =>
      'Säkerhetskopiera eller återställ scheman, kalendrar, inställningar och skolsidor. API-nycklar ingår inte.';

  @override
  String get appBackupSheetSubtitle =>
      'En fullständig återställning ersätter aktuella appdata. AI API-nycklar ligger i säker lagring och skrivs inte till säkerhetskopior.';

  @override
  String get restoreBackupFileTitle => 'Återställ från JSON-fil';

  @override
  String get restoreBackupFileSubtitle =>
      'Välj en fullständig Sked-säkerhetskopia. Du bekräftar innan återställning.';

  @override
  String get restoreBackupTextTitle => 'Klistra in säkerhetskopia som JSON';

  @override
  String get restoreBackupTextSubtitle =>
      'Klistra in en fullständig säkerhetskopia och återställ aktuella appdata.';

  @override
  String get shareBackupTitle => 'Dela säkerhetskopifil';

  @override
  String get shareBackupSubtitle =>
      'Exportera alla appdata som JSON. API-nycklar utesluts.';

  @override
  String get saveBackupTitle => 'Spara säkerhetskopifil';

  @override
  String get saveBackupSubtitle =>
      'Spara en fullständig appsäkerhetskopia i en lokal fil.';

  @override
  String get copyBackupTitle => 'Kopiera säkerhetskopitext';

  @override
  String get copyBackupSubtitle =>
      'Visa hela säkerhetskopian som JSON så att du kan kopiera eller lagra den tillfälligt.';

  @override
  String get restoreBackupConfirmTitle =>
      'Återställa fullständig säkerhetskopia?';

  @override
  String get restoreBackupConfirmMessage =>
      'Detta ersätter alla aktuella scheman, allmänna kalendrar, inställningar och skolsidor. API-nycklar importeras inte från säkerhetskopior; ange nyckeln igen innan du parser scheman igen.';

  @override
  String get restoreBackupConfirmAction => 'Återställ säkerhetskopia';

  @override
  String get restoreBackupSuccessMessage =>
      'Fullständig appsäkerhetskopia återställd. AI API-nycklar måste anges igen.';

  @override
  String get restoreBackupFailureMessage =>
      'Återställningen misslyckades. Kontrollera säkerhetskopians innehåll och försök igen.';

  @override
  String get openSourceLicenses => 'Licenser med öppen källkod';

  @override
  String get openSourceLicensesDesc =>
      'Visa licenser för Flutter-beroenden och paketerade app-ikontillgångar.';

  @override
  String get checkForUpdates => 'Kontrollera uppdateringar';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Redan på den senaste versionen ($version)';
  }

  @override
  String get currentVersionLabel => 'Aktuell version';

  @override
  String get newVersionAvailable => 'Uppdatering tillgänglig';

  @override
  String get latestVersionLabel => 'Senaste versionen';

  @override
  String get updateContentLabel => 'Uppdatera detaljer';

  @override
  String get officialWebsite => 'Officiell hemsida';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud Drive';

  @override
  String get ignoreThisVersion => 'Ignorera denna version';

  @override
  String get openUpdatesFailed => 'Kan inte öppna uppdateringslänken';

  @override
  String get updateCheckFailedTitle => 'Uppdateringskontroll misslyckades';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub-arkiv';

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
  String get openGithubFailed =>
      'Kan inte öppna länken till GitHub-repositoriet';

  @override
  String get openPrivacyPolicyFailed =>
      'Kan inte öppna länken till integritetspolicyn';

  @override
  String get selectPeriodTimeSet => 'Välj tidsinställd period';

  @override
  String get newItem => 'Nya';

  @override
  String get editPeriodTimeSet => 'Redigera tidsinställd period';

  @override
  String get importTimetableFiles => 'Importera tidtabell';

  @override
  String get importTimetableFilesDesc =>
      'Stödjer en eller flera tidstabellfiler.';

  @override
  String get importTimetableText => 'Importera tidsplan från text';

  @override
  String get importTimetableTextDesc =>
      'Klistra in tidstabellen JSON innehåll och importera det.';

  @override
  String get shareTimetableFiles => 'Dela tidstabellfiler';

  @override
  String get shareTimetableFilesDesc =>
      'Välj en eller flera tidtabeller först.';

  @override
  String get saveTimetableFiles => 'Spara tidstabellfiler';

  @override
  String get saveTimetableFilesDesc => 'Välj en eller flera tidtabeller först.';

  @override
  String get exportTimetableText => 'Exportera tidtabell som text';

  @override
  String get exportTimetableTextDesc =>
      'Välj en eller flera tidtabeller och kopiera sedan JSON-innehållet.';

  @override
  String get jsonContent => 'JSON-innehåll';

  @override
  String get pasteJsonContentHint =>
      'Klistra in JSON-innehållet för att importera.';

  @override
  String get jsonContentEmpty => 'Klistra in JSON-innehållet först.';

  @override
  String get copyText => 'Kopiera';

  @override
  String get copiedToClipboard => 'Kopierad till klippstavla';

  @override
  String get share => 'Dela';

  @override
  String get selectTimetablesToExport => 'Välj tidtabeller att exportera';

  @override
  String get selectTimetablesToImport => 'Välj tidtabeller att importera';

  @override
  String timetableCourseCount(int count) {
    return '$count kurser';
  }

  @override
  String get importAction => 'Importera';

  @override
  String get importTimetableDialogTitle => 'Importera tidtabell';

  @override
  String get chooseImportMethod => 'Välj hur du importerar.';

  @override
  String get importAsNewTimetable => 'Importera som ny tidtabell';

  @override
  String get replaceCurrentTimetable => 'Ersätta aktuell tidsplan';

  @override
  String get importPeriodTimeSetDialogTitle =>
      'Importera tidsuppsättningar för perioden';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Den här filen innehåller bundlade periodtidsuppsättningar. Vill du importera och associera dem?';

  @override
  String get importBundledPeriodTimeSets => 'Importera och associera';

  @override
  String get discardBundledPeriodTimeSets => 'Kastera bundlade uppsättningar';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Ingen befintlig periodtidsuppsättning är tillgänglig, så bundlade periodtidsuppsättningar kan inte kasseras.';

  @override
  String savedToPath(Object path) {
    return 'Sparad till $path';
  }

  @override
  String get saveCancelled => 'Spara inställd';

  @override
  String get fileSaveRestrictedTitle => 'Filsparning begränsad';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Systemet kunde inte spara filen. Du kan försöka igen eller använda delning istället.';

  @override
  String get retrySave => 'Försök spara igen';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Aktivera filåtkomst i systeminställningarna, gå sedan tillbaka och försök exportera igen.';

  @override
  String get openSettings => 'Öppna inställningar';

  @override
  String get browserDownloadRestrictedTitle =>
      'Nedladdning av webbläsare begränsad';

  @override
  String get browserDownloadRestrictedMessage =>
      'Denna webbläsare stöder inte direkt sparning till en lokal fil. Kontrollera nedladdningsbehörigheter i webbläsaren eller använd fildelning istället.';

  @override
  String get switchToShare => 'Använd delning istället';

  @override
  String get fileSaveFailedTitle => 'Filsparning misslyckades';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Kan inte skriva till aktuell sökväg. Målmappen kan vara skyddad, filen kan vara i användning eller vägen kan inte skrivas.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Systemet kunde inte spara filen. Du kan försöka igen, kontrollera systeminställningarna eller använda fildelning istället.';

  @override
  String get retryLater => 'Försök igen senare';

  @override
  String get exportSwitchedToShare => 'Bytt till fildelning för export';

  @override
  String get saveFailedRetry => 'Sparandet misslyckades. Försök igen senare.';

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
  String get appInstanceBlockedTitle => 'Appen Sked är redan öppen';

  @override
  String get appInstanceBlockedMessage =>
      'Dina lokala data används i ett annat Sked-fönster eller en annan webbläsarflik. Stäng det andra fönstret eller fliken och försök igen.';

  @override
  String get appInstanceLeaseFailedTitle => 'Lokala data är inte tillgängliga';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked kunde inte verifiera exklusiv åtkomst till lokala data. Dina data har inte öppnats eller ändrats. Kontrollera åtkomsten till lagringen och försök igen.';

  @override
  String get savingChanges => 'Sparar ändringar...';

  @override
  String get showApiKey => 'Visa API-nyckel';

  @override
  String get hideApiKey => 'Dölj API-nyckel';

  @override
  String get importFailedCheckContent =>
      'Importen misslyckades. Kontrollera filens innehåll.';

  @override
  String get noImportableTimetables =>
      'Inga användbara tidtabeller hittades i den importerade filen.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importerade $count tidtabeller';
  }

  @override
  String get periodTimesTitle => 'Periodtider';

  @override
  String get importExport => 'Import och export';

  @override
  String get importPeriodTemplate => 'Importera periodmall';

  @override
  String get importPeriodTemplateText => 'Importera periodmall från text';

  @override
  String get sharePeriodTemplate => 'Mall för aktieperiod';

  @override
  String get saveTemplateToFile => 'Spara mall till fil';

  @override
  String get exportPeriodTemplateText => 'Exportera periodmall som text';

  @override
  String get deletePeriodTimeSet => 'Ta bort tidsinställd period';

  @override
  String get periodTimeSetName => 'Namn på tidsinställning för perioden';

  @override
  String get addOnePeriod => 'Lägg till period';

  @override
  String periodNumberLabel(int index) {
    return 'Period $index';
  }

  @override
  String get deleteThisPeriod => 'Ta bort denna period';

  @override
  String durationMinutes(int minutes) {
    return 'Längd $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Gap från tidigare $minutes min';
  }

  @override
  String get endTimeMustBeLater => 'Sluttid måste vara senare än starttid';

  @override
  String get periodOverlapPrevious => 'Denna period överlappar den föregående';

  @override
  String get periodTimesSaved => 'Sparade periodtider';

  @override
  String get deletePeriodTimeSetTitle => 'Ta bort tidsinställd period';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Ta bort \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'tidsinställning för aktuell period';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importerade $count periodtider';
  }

  @override
  String get periodFilePermissionTitle => 'Filbehörighet behövs';

  @override
  String get androidFilePermissionMessage =>
      'Android-export kräver filåtkomsttillstånd. Ge tillstånd att fortsätta spara.';

  @override
  String get reauthorize => 'Autorisera igen';

  @override
  String get permissionPermanentlyDeniedTitle => 'Tillstånd förnekat permanent';

  @override
  String get permissionSettingsExportMessage =>
      'Aktivera filåtkomst i systeminställningarna, gå sedan tillbaka och försök exportera igen.';

  @override
  String get privacyPolicyTitle => 'Integritetspolicy';

  @override
  String get privacyPolicyEntryDesc =>
      'Lär dig hur appen hanterar lokal lagring, konfiguration av skolans webbplats, import/export av filer, analys av webbsidor och externa länkar.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Godkänd version: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked är ett lokalt-först schemaverktyg. Scheman, periodtidsuppsättningar och skolwebbplatskonfiguration lagras endast på din enhet eller i din webbläsare och laddas aldrig upp automatiskt. Appen behandlar endast data när du uttryckligen startar åtgärder som import, webbsidoparsning, delning eller öppnande av externa länkar. Den fullständiga integritetspolicyn finns tillgänglig online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokal förvaring';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Import och export';

  @override
  String get privacyPolicyImportExportBody =>
      'Appen läser eller skriver JSON-filer för tidstabeller, JSON-filer för skolor och periodmallar endast när du uttryckligen väljer en fil eller startar en exportåtgärd. Importera dessa filer är en lokal åtgärd om du inte också väljer webbsidoparsing. Att hämta en anpassad modelllista är också en explicit nätverksåtgärd och kontaktar bara den anpassade slutpunkten du konfigurerat.';

  @override
  String get privacyPolicySharingTitle => 'Delning';

  @override
  String get privacyPolicySharingBody =>
      'När du uttryckligen använder delning skickar appen den exporterade filen till systemdelningsbladet eller till den målapp du väljer. Hur filen hanteras senare beror på vilken målapp eller tjänst du väljer.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Externa länkar';

  @override
  String get privacyPolicyExternalLinksBody =>
      'När du öppnar externa länkar som GitHub-repositoriet överlämnar appen åtgärden till din webbläsare eller ett annat externt program. Datahantering efter denna punkt regleras av den tredje part du öppnar.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Vad appen inte samlar in';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Appen kräver inte ett Sked-konto och aktiverar inte analys, annonseringsidentifierare eller molnsäkerhetskopiering. Det tillhandahåller inte heller ett dedikerat fält för att samla in lösenord för skolkonton. Om du loggar in på en skolas webbplats i appen sker den interaktionen på skolans sida du öppnade.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Analysering av webbsidor';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'När du använder import från en skolas webbsida eller analyserar inklistrad schematext / HTML förbereder och rensar appen först innehållet lokalt och skickar sedan den inskickade schematexten, sidtexten eller HTML-innehållet, valfri sidtitel och URL, appens aktuella språk samt parserns promptinnehåll till den OpenAI-kompatibla endpoint som du har konfigurerat. Hämtning av modellistan använder också samma endpoint. Sked tillhandahåller ingen inbyggd parser-endpoint och skickar inte parserförfrågningar till en utvecklarkontrollerad backend för schemaanalys. Den anpassade endpointen och eventuella upstream-tjänster kan lagra, vidarebefordra, begränsa, ta bort eller på annat sätt behandla data enligt reglerna hos den tjänsteleverantör du väljer. Om du använder en http:// Base URL ska du bara använda den på betrodda enheter, nätverk och endpoint-tjänster, eftersom innehåll och API-nycklar kanske inte skyddas av transportkryptering.';

  @override
  String get privacyPolicyUpdatesTitle => 'Uppdateringar av policyn';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Den nuvarande versionen av sekretesspolicyn är $version. Om en senare version ändrar hur data hanteras kan appen be dig att läsa och godkänna den uppdaterade policyn igen.';
  }

  @override
  String get privacyGateTitle =>
      'Vänligen godkänn sekretesspolicyn innan du använder appen';

  @override
  String get privacyGateSummaryStorage =>
      'Tidstabeller, tidsuppsättningar och konfiguration av skolan lagras endast lokalt och laddas inte upp automatiskt till en utvecklarserver.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, export och delning sker endast när du uttryckligen startar dem. Webbsidoparsning skickar endast det komprimerade innehållet du skickar till din konfigurerade parseringsändpunkt, och du kan granska den parserade tidsplanen innan du sparar.';

  @override
  String get privacyGateSummaryUpdates =>
      'Om en senare version ändrar hur data hanteras kan appen be dig att granska den uppdaterade sekretesspolicyn igen.';

  @override
  String get schoolWebImportEntry => 'Importera från skolans webbsida';

  @override
  String get schoolWebImportEntryDesc =>
      'Importera den aktuella tidtabellsidan från skolans webbplats.';

  @override
  String get schoolSitesManageEntry => 'Hantera skolans webbplatser';

  @override
  String get schoolSitesManageEntryDesc =>
      'Lägg till, redigera och ta bort skolans inloggningsadresser med JSON-import och -export.';

  @override
  String get schoolSitesPageTitle => 'Förvaltning av skolan';

  @override
  String get schoolSitesImportJson => 'Importera skolans JSON';

  @override
  String get schoolSitesShareJson => 'Dela skolan JSON';

  @override
  String get schoolSitesSaveJson => 'Spara skolans JSON';

  @override
  String get schoolSitesSaved => 'Skolansidor sparade';

  @override
  String get schoolSitesImported => 'Importerade skolplatser';

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
  String get schoolSitesEmpty => 'Ingen skolkonfiguration ännu.';

  @override
  String get schoolSitesNameLabel => 'Skolans namn';

  @override
  String get schoolSitesLoginUrlLabel => 'Inloggningsadress';

  @override
  String get schoolSitesAdd => 'Lägg till skola';

  @override
  String get schoolSitesEdit => 'Redigera skolan';

  @override
  String get schoolSitesDeleteTitle => 'Ta bort skolan';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Ta bort \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Fyll i skolans namn och inloggningsadress först.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importera genom att klistra in tidstabellsidans innehåll';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Klistra in källkod eller rå sidinnehåll som innehåller tidtabellinformation manuellt.';

  @override
  String get schoolHtmlImportPageTitle => 'Analysera tidsplan från sidinnehåll';

  @override
  String get schoolHtmlImportUrlLabel => 'Källa URL (valfritt)';

  @override
  String get schoolHtmlImportTitleLabel => 'Sidtitel (valfri)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Sidans innehåll';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Klistra in källkod eller rå sidinnehåll som innehåller tidtabellinformation här.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Allt innehåll som innehåller tidtabellinformation kan analyseras och importeras, inte bara HTML.';

  @override
  String get schoolHtmlImportCompress => 'Förbered innehåll';

  @override
  String get schoolHtmlImportCompressed => 'Innehåll förberett';

  @override
  String get schoolHtmlImportCompressFirst => 'Förbered innehållet först.';

  @override
  String get schoolHtmlImportSubmit => 'Analysera och importera';

  @override
  String get schoolImportContentTruncated =>
      'Den här sidan har nått den säkra importgränsen. Endast den insamlade delen skickas för analys.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsing kan ta ett tag. Vänta lite.';

  @override
  String get schoolHtmlImportEmpty => 'Klistra in HTML-sidan först.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Tillbaka till webbsidan';

  @override
  String get schoolWebImportPageTitle => 'Import av skolans webbsida';

  @override
  String get schoolWebImportPreview => 'Importera förhandsgranskning';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count kurser';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count perioder';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Sidtitel';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importera anteckningar';

  @override
  String get schoolWebImportParserDetails => 'Analysdetaljer';

  @override
  String get schoolWebImportExpandParserDetails => 'Visa analysdetaljer';

  @override
  String get schoolWebImportCollapseParserDetails => 'Dölj analysdetaljer';

  @override
  String get schoolWebImportOpenPageHint =>
      'Logga in på skolans webbplats i appen och navigera sedan till tidtabellsidan manuellt.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Denna plattform stöder inte inbäddad webbloggning ännu. Använd en plattform med WebView-stöd.';

  @override
  String get schoolWebImportSelectSchool => 'Välj skola';

  @override
  String get schoolWebImportNoSchools =>
      'Ingen skolkonfiguration är tillgänglig. Kontrollera school_sites.json först.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Misslyckades ladda skolkonfigurationen. Kontrollera filformatet JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importera aktuell sida';

  @override
  String get schoolWebImportLoadingPage => 'Laddar sidan…';

  @override
  String get schoolWebImportParsing => 'Tolkar nuvarande sida...';

  @override
  String get schoolWebImportLoadFailed =>
      'Sidladdning misslyckades. Uppdatera eller försök igen senare.';

  @override
  String get schoolWebImportUnknownOrigin => 'Okänd webbplats';

  @override
  String get schoolWebImportExitTitle => 'Lämna webbläsaren?';

  @override
  String get schoolWebImportExitMessage =>
      'Sidan stängs. Allt du inte har importerat ännu går förlorat.';

  @override
  String get schoolWebImportExitConfirm => 'Lämna';

  @override
  String get schoolWebImportEmptyPage =>
      'Aktuellt innehåll på sidan är tomt och kan inte importeras ännu.';

  @override
  String get schoolWebImportSuccess => 'Webbtidsplan importerad';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Parserkälla';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Anpassad OpenAI-kompatibel';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Anpassad OpenAI-kompatibel parser';

  @override
  String get schoolImportParserCustomPromptTitle => 'Anpassad prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Redigera den inbyggda parser prompt här. Ändringar påverkar bara den anpassade OpenAI-kompatibla parsern.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Den inbyggda prompten laddas här som standard. Rensa den för att falla tillbaka till den inbyggda versionen.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Återställ standardprompt';

  @override
  String get schoolImportParserBaseUrl => 'Basadress';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL måste vara en HTTP- eller HTTPS-URL med värd.';

  @override
  String get schoolImportParserApiKey => 'API-nyckel';

  @override
  String get schoolImportParserModel => 'Modell';

  @override
  String get schoolImportParserFetchModels => 'Hämta modelllista';

  @override
  String get schoolImportParserFetchingModels => 'Hämta modeller. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Inga modeller returnerades vid slutpunkten.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Det gick inte att hämta modeller. Kontrollera slutpunkten och försök igen.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Hämtade $count modeller';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Vill du använda en okrypterad HTTP-slutpunkt?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API-nyckeln och schemainnehållet kan läsas eller ändras under överföringen. Fortsätt bara om du litar på den här enheten, nätverket och slutpunkten. Godkännandet gäller tills du stänger Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Anpassad parser konfiguration är ofullständig. Fyll i grundadressen, API-nyckeln och modellen först.';

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
    return 'Parser: Anpassad ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Visa hela sekretesspolicyn';

  @override
  String get privacyAgreeAndContinue => 'Håll med och fortsätt';

  @override
  String get privacyDecline => 'Avfärda';

  @override
  String get privacyDeclineWebHint =>
      'Denna webbläsarmiljö tillåter inte att appen stänger sidan åt dig. Om du inte håller med, stäng den här fliken eller fönstret själv.';

  @override
  String get defaultPeriodTimeSetName => 'Standardperioder';

  @override
  String get periodTimeSetFallbackName => 'Periodtider';

  @override
  String get untitledTimetableName => 'Tidsplan utan titel';

  @override
  String get newTimetableName => 'Ny tidtabell';

  @override
  String get newPeriodTimeSetName => 'Ny tidsinställning';

  @override
  String get emptyTimetableName => 'Tomma tidtabeller';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name perioder';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Importeringsfiltypen matchar inte.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Denna importfilversion stöds ännu inte.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Inga periodtider hittades i importfilen.';

  @override
  String get selectAtLeastOneTimetableMessage => 'Välj minst en tidsplan.';

  @override
  String get noExportableTimetableMessage =>
      'Det finns ingen tidsplan för export.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Att byta ut den aktuella tidtabellen stöder bara att välja en tidtabell.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Det finns ingen tidsplan att ersätta.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Denna tidsinställning används fortfarande av $count tidtabell(er). Omdela dem innan du raderar dem.';
  }

  @override
  String get weekdayMonday => 'måndag';

  @override
  String get weekdayTuesday => 'tisdag';

  @override
  String get weekdayWednesday => 'Onsdag';

  @override
  String get weekdayThursday => 'Torsdag';

  @override
  String get weekdayFriday => 'Fredag';

  @override
  String get weekdaySaturday => 'Lördag';

  @override
  String get weekdaySunday => 'söndag';

  @override
  String get weekdayShortMonday => 'måndag';

  @override
  String get weekdayShortTuesday => 'tisdag';

  @override
  String get weekdayShortWednesday => 'Onsdag';

  @override
  String get weekdayShortThursday => 'torsdag';

  @override
  String get weekdayShortFriday => 'Fr';

  @override
  String get weekdayShortSaturday => 'lördag';

  @override
  String get weekdayShortSunday => 'Solen';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'februari';

  @override
  String get monthMarch => 'mars';

  @override
  String get monthApril => 'apr';

  @override
  String get monthMay => 'maj';

  @override
  String get monthJune => 'juni';

  @override
  String get monthJuly => 'jul';

  @override
  String get monthAugust => 'aug';

  @override
  String get monthSeptember => 'sep';

  @override
  String get monthOctober => 'Okt';

  @override
  String get monthNovember => 'nov';

  @override
  String get monthDecember => 'maj';

  @override
  String get semesterWeeksWholeTerm => 'Hela terminen';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Veckor $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Veckor $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Välj startläge';

  @override
  String get firstLaunchSubtitle =>
      'Välj den arbetsyta du använder mest. Du kan byta läge senare.';

  @override
  String get firstLaunchStudentDesc =>
      'Hantera scheman, kurser, veckor, lektionstider och importer.';

  @override
  String get firstLaunchGeneralDesc =>
      'Hantera kategorier, händelser, påminnelser och JSON / ICS-data.';

  @override
  String get firstLaunchStartStudent => 'Börja med schema';

  @override
  String get firstLaunchStartGeneral => 'Börja med kalender';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Genom att välja en startarbetsyta bekräftar du att du har läst och godkänner ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Integritetspolicyn';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'I dag';

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
      'Vyer, verktygsfält, datumformat och snabbtillägg';

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
  String get viewWeek => 'Vecka';

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
  String get developerModeTitle => 'Utvecklarläge';

  @override
  String get developerModeDescription =>
      'Verktyg för att lägga till fullständiga exempeldata och kontrollera utseende och interaktion.';

  @override
  String get developerSampleLanguage => 'Språk för exempeldata';

  @override
  String get developerSampleChinese => 'Kinesiska';

  @override
  String get developerSampleEnglish => 'Engelska';

  @override
  String get developerSampleDataDescription =>
      'Lägger till ett schema och en uppsättning kategorier och händelser utan att ersätta befintliga data.';

  @override
  String get developerAddSampleData => 'Lägg till exempeldata';

  @override
  String get developerSampleDataAdded =>
      'Exempelschema och händelser har lagts till.';

  @override
  String get developerModeLongPressHint =>
      'Håll ned i 3 sekunder för att öppna utvecklarläget';

  @override
  String get collapseWorkspaceNavigation => 'Fäll ihop arbetsytenavigering';

  @override
  String get expandWorkspaceNavigation => 'Expandera arbetsytenavigering';

  @override
  String get schoolWebImportExitBrowser => 'Stäng den inbyggda webbläsaren';

  @override
  String get schoolWebImportEditAddress => 'Redigera adress';

  @override
  String get schoolWebImportAddressLabel => 'Webbadress';

  @override
  String get schoolWebImportOpenAddress => 'Öppna';

  @override
  String get schoolWebImportAddressInvalid =>
      'Ange en HTTP- eller HTTPS-adress med en värd.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Den här webbsidan begärde ett nytt fönster som inte kan öppnas på den här enheten.';

  @override
  String get schoolWebImportSecureConnection => 'Säker anslutning';

  @override
  String get schoolWebImportInsecureConnection => 'Osäker anslutning';

  @override
  String get schoolWebImportSignInConsentTitle => 'Öppna skolans inloggning?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Skolans inloggning kan skicka inloggningsuppgifter via formulär eller serveromdirigeringar till skolan och dess inloggningsleverantörer. Android kan inte pausa varje sådan överföring för en separat bekräftelse av destinationen. Fortsätt bara om du litar på dem under den här importsessionen:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Öppna en osäker skolinloggning?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Den här skolinloggningen använder HTTP. Den som kan övervaka eller ändra anslutningen kan läsa eller ändra dina inloggningsuppgifter och sidans innehåll. Fortsätt bara om du accepterar den här risken för:\n\n$origin';
  }
}
