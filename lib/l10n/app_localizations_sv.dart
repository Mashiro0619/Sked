// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle => 'Redigera tolkningsresultat';

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
  String get schoolImportExpandWarnings => 'Visa importvarningar';

  @override
  String get schoolImportCollapseWarnings => 'Dölj importvarningar';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Vissa kurser pågår till och med vecka $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Ersätta det aktuella schemat?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Det importerade schemat ersätter det aktuella schemat.';

  @override
  String get createTimetable => 'Ny tidtabell';

  @override
  String get jumpToWeek => 'Hoppa till veckan';

  @override
  String get timetable => 'Tidsplan';

  @override
  String get themeWorkspaceSchedule => 'Schema';

  @override
  String get timetableName => 'Tidsplan namn';

  @override
  String get timetableNameRequired => 'Ange ett namn på schemat';

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
    return 'Lektionspass $start–$end';
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
  String get settingsSectionTimetable => 'Kursschema';

  @override
  String get settingsSectionGeneralSchedule => 'Allmänt schema';

  @override
  String get settingsSectionAppearance => 'Utseende';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionWorkspace => 'Arbetsyta';

  @override
  String get settingsSectionAppearanceLanguage => 'Utseende och språk';

  @override
  String get settingsSectionDataSecurity => 'Data och säkerhet';

  @override
  String get settingsSectionAbout => 'Om Sked';

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
  String get timetableHorizontalLayoutSection => 'Vågrät layout och gester';

  @override
  String get fitDaySelectorToWidth => 'Anpassa dagväljaren till skärmen';

  @override
  String get fitDaySelectorToWidthHint =>
      'Visa alla sju dagar på skärmen om möjligt. Stäng av för att använda fast bredd och rulla i sidled.';

  @override
  String get fitWeekColumnsToWidth => 'Anpassa veckokolumnerna till skärmen';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Visa alla sju schemakolumner på skärmen om möjligt. Stäng av för att använda fast bredd och rulla i sidled.';

  @override
  String get enableWeekSwipeNavigation => 'Svep för att byta vecka';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Svep åt vänster eller höger för att byta vecka. Vid fast bredd behöver du först rulla till kanten och sedan dra vidare.';

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
  String get outlineWidthUnit => 'px';

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
  String get microsoftStoreUpdates =>
      'Uppdateringar hanteras av Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Ta emot förhandsversioner';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Inkludera Alpha-, Beta- och RC-versioner, som kan vara instabila. När avstängt erbjuds endast stabila versioner.';

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
      'Det gick inte att hämta den senaste versionen från GitHub. Du kan fortfarande öppna GitHub Releases nedan.';

  @override
  String get githubRepository => 'GitHub-arkiv';

  @override
  String get googlePlayStoreDesc => 'Visa Sked på Google Play';

  @override
  String get openGooglePlayFailed => 'Det gick inte att öppna Google Play';

  @override
  String get starSkedOnGithub => 'Ge Sked en stjärna på GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Öppna projektets kodarkiv och ge Sked en stjärna';

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
  String get periodTimesUnsavedExitTitle => 'Ändringarna har inte sparats';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'De senaste ändringarna av lektionstiderna kunde inte sparas. Du kan försöka igen, fortsätta redigera eller kasta ändringarna.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Vissa lektionstider är ogiltiga. Rätta dem innan du sparar, eller kasta ändringarna och avsluta.';

  @override
  String get discardChangesAndExit => 'Kasta ändringar och avsluta';

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
    return 'Lektionspass $index';
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
      'På inbyggda plattformar lagrar Sked kursscheman, allmänna scheman, tillhörande inställningar och redigerbara skolwebbplatser i operativsystemets katalog för appdata. Webbläsarversionen använder webbläsarens lagring. Filer som tidigare versioner sparat i användarens Dokument-mapp finns kvar, men läses eller flyttas inte automatiskt. Om du vill behålla dessa data behöver du exportera en fullständig appsäkerhetskopia från den gamla versionen före uppgraderingen och sedan återställa den. Inställningar för AI-API lagras lokalt. Den egna API-nyckeln sparas via plattformens säkra lagring när sådan finns. Fullständiga appsäkerhetskopior innehåller inte den egna API-nyckeln. Appen laddar inte automatiskt upp dessa lokala data till en server som kontrolleras av utvecklaren.';

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
  String get schoolSitesImportPreviewTitle =>
      'Granska importen av skolwebbplatser';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount giltiga webbplatser, $invalidCount ogiltiga poster.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Filen innehåller en tom lista över skolwebbplatser.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Post $position är ogiltig och hoppas över.';
  }

  @override
  String get schoolSitesImportMerge => 'Slå samman';

  @override
  String get schoolSitesImportReplace => 'Ersätt';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Ersätta de aktuella skolwebbplatserna?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Detta tar bort $currentCount befintliga webbplatser och sparar $importedCount importerade webbplatser. Åtgärden kan inte ångras.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Skolwebbplatsernas data behöver återställas';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked kunde inte läsa filen med skolwebbplatser eller dess säkerhetskopia. Skyddade kopior skapades innan skrivningar blockerades.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Lagringen för skolwebbplatser är inte tillgänglig';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked kan inte komma åt lagringen för skolwebbplatser just nu. Kontrollera lagringsåtkomst eller enhetens tillgänglighet och försök igen. Befintliga webbplatsdata skrivs inte över.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Återställningsfiler eller berörda lagringsplatser visas nedan. Låt filerna vara oförändrade tills webbplatslistan har återställts.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Börja utan skolwebbplatser';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Börja med en tom lista över skolwebbplatser?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Skyddade kopior behålls, men Sked skapar en ny, tom fil för skolwebbplatser. Fortsätt bara om du inte vill försöka återställa listan först.';

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
      'Inställningarna för den egna parsern är ofullständiga. Fyll först i bas-URL, API-nyckel och modell.';

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
  String get schoolImportParserSettingsTitle => 'API för schemaimport';

  @override
  String get schoolImportParserSettingsDesc =>
      'Konfigurera det OpenAI-kompatibla API:et för schemaimport, inte för en chattassistent.';

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
      'Den egna API-nyckeln sparas via plattformens säkra lagring när sådan finns. Använd bara egna inloggningsuppgifter för parsern och HTTP-adresser på enheter, i webbläsare och i nätverk som du litar på.';

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
  String get clearAppData => 'Rensa data';

  @override
  String get clearAppDataDesc =>
      'Ta bort alla lokala Sked-data permanent och avsluta appen';

  @override
  String get clearAppDataConfirmTitle => 'Rensa alla Sked-data?';

  @override
  String get clearAppDataConfirmMessage =>
      'Detta tar permanent bort kursscheman, händelser, inställningar, skolwebbplatser, lokala säkerhetskopior, återställningskopior och AI-API-nyckeln och avslutar sedan Sked. Filer som du har exporterat till andra platser tas inte bort. Åtgärden kan inte ångras.';

  @override
  String get clearAppDataAction => 'Rensa data och avsluta';

  @override
  String get clearAppDataFailed =>
      'Det gick inte att rensa alla lokala data. Sked förblir öppet så att du kan försöka igen.';

  @override
  String get clearAppDataExitFailed =>
      'Dina lokala data har rensats, men Sked kunde inte avslutas. Stäng appen manuellt innan du använder den igen.';

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
  String get monthJanuary => 'jan';

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
  String get generalSchedule => 'Allmänt schema';

  @override
  String get studentTimetable => 'Kursschema';

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
  String get switchMode => 'Byt läge';

  @override
  String get generalScheduleComingSoon => 'Allmänt schema kommer snart';

  @override
  String get switchToStudentTimetable => 'Byt till kursschema';

  @override
  String get mySchedule => 'Mitt schema';

  @override
  String get today => 'I dag';

  @override
  String get addEvent => 'Lägg till händelse';

  @override
  String get editEvent => 'Redigera händelse';

  @override
  String get eventTitle => 'Titel';

  @override
  String get eventTitleRequired => 'Ange en titel';

  @override
  String get eventStartTime => 'Starttid';

  @override
  String get eventEndTime => 'Sluttid';

  @override
  String get eventDate => 'Datum';

  @override
  String get eventTime => 'Tid';

  @override
  String get eventNotes => 'Anteckningar';

  @override
  String get eventColor => 'Färg';

  @override
  String get eventRecurrence => 'Upprepa';

  @override
  String get recurrenceNone => 'Upprepas inte';

  @override
  String get recurrenceWeekly => 'Varje vecka';

  @override
  String get recurrenceEndDate => 'Slutdatum';

  @override
  String get recurrenceNoEndDate => 'Inget slutdatum';

  @override
  String get recurrenceSetEndDate => 'Ange';

  @override
  String get recurrenceChangeEndDate => 'Ändra';

  @override
  String get repeatsWeekly => 'Upprepas varje vecka';

  @override
  String recurrenceUntil(Object date) {
    return 'Till och med $date';
  }

  @override
  String get switchToGeneralSchedule => 'Byt till allmänt schema';

  @override
  String get generalDisplaySettings => 'Allmänna visningsinställningar';

  @override
  String get generalDisplaySettingsDesc =>
      'Vyer, verktygsfält, datumformat och snabbtillägg';

  @override
  String get closePopupOnOutsideTap => 'Stäng popupfönster vid tryck utanför';

  @override
  String get showGridLines => 'Visa rutnätslinjer';

  @override
  String get generalScheduleImportExport => 'Import och export av kategorier';

  @override
  String get generalScheduleImportExportDesc =>
      'Importera eller dela schemakategorier';

  @override
  String get importGeneralSchedules => 'Importera kategorier';

  @override
  String get importGeneralSchedulesDesc => 'Läs kategorier från en JSON-fil';

  @override
  String get shareGeneralSchedules => 'Dela kategorier';

  @override
  String get shareGeneralSchedulesDesc => 'Dela kategorier som en JSON-fil';

  @override
  String get saveGeneralSchedules => 'Spara kategorier';

  @override
  String get saveGeneralSchedulesDesc => 'Spara kategorier som en JSON-fil';

  @override
  String get selectSchedulesToExport => 'Välj kategorier att exportera';

  @override
  String get selectSchedulesToImport => 'Välj kategorier att importera';

  @override
  String generalScheduleEventCount(int count) {
    return 'Händelser: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Importerade $count kategorier';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Lägga till importen som en ny kategori eller ersätta en befintlig kategori?';

  @override
  String get addAsNewSchedule => 'Lägg till som ny kategori';

  @override
  String get selectAtLeastOneScheduleMessage => 'Välj minst en kategori.';

  @override
  String get noExportableScheduleMessage =>
      'Det finns ingen kategori att exportera.';

  @override
  String get noSchedulesInImportMessage =>
      'Importfilen innehåller inga kategorier.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Välj exakt en importerad kategori för ersättning.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Den valda kategorin som ska ersättas är inte tillgänglig.';

  @override
  String get calendars => 'Kategorier';

  @override
  String get calendar => 'Kategori';

  @override
  String get viewWeek => 'Vecka';

  @override
  String get viewDay => 'Dag';

  @override
  String get viewList => 'Lista';

  @override
  String get viewMonth => 'Månad';

  @override
  String visibleCategoryCount(int count) {
    return '$count kategorier';
  }

  @override
  String get noVisibleCategories => 'Inga synliga kategorier';

  @override
  String get selectCategoryToReplace => 'Välj kategori att ersätta';

  @override
  String get replaceCategory => 'Ersätt kategori';

  @override
  String get deleteEventTitle => 'Ta bort händelse';

  @override
  String get deleteEventConfirmation => 'Händelsen tas bort permanent.';

  @override
  String get deleteRecurringEventTitle => 'Ta bort återkommande händelse';

  @override
  String get eventDuplicated => 'Händelsen har duplicerats';

  @override
  String get searchEvents => 'Sök händelser';

  @override
  String get clearSearch => 'Rensa sökning';

  @override
  String get filterByColor => 'Filtrera efter färg';

  @override
  String get allColors => 'Alla färger';

  @override
  String upcomingEventsCount(int count) {
    return 'Kommande: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Förfallna: $count';
  }

  @override
  String get allDay => 'Hela dagen';

  @override
  String get collapseAllDayTimeline => 'Dölj heldagshändelser';

  @override
  String get expandAllDayTimeline => 'Visa heldagshändelser';

  @override
  String allDayEventsCount(int count) {
    return '$count heldagshändelser';
  }

  @override
  String moreEvents(int count) {
    return '+$count till';
  }

  @override
  String get noMatchingEvents => 'Inga matchande händelser';

  @override
  String get noUpcomingEvents => 'Inga kommande händelser';

  @override
  String get addCalendar => 'Lägg till kategori';

  @override
  String get newCalendar => 'Ny kategori';

  @override
  String get hideCalendar => 'Dölj kategori';

  @override
  String get showCalendar => 'Visa kategori';

  @override
  String get rename => 'Byt namn';

  @override
  String get renameCalendar => 'Byt namn på kategori';

  @override
  String get name => 'Namn';

  @override
  String get deleteCalendar => 'Ta bort kategori';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Ta bort ”$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Ta bort denna förekomst';

  @override
  String get deleteFutureOccurrences => 'Ta bort denna och följande';

  @override
  String get deleteAllOccurrences => 'Ta bort hela serien';

  @override
  String get duplicateEvent => 'Duplicera';

  @override
  String get repeatsDaily => 'Upprepas varje dag';

  @override
  String get repeatsMonthly => 'Upprepas varje månad';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Upprepas med intervallet $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count gånger';
  }

  @override
  String get recurrenceDaily => 'Varje dag';

  @override
  String get recurrenceMonthly => 'Varje månad';

  @override
  String get recurrenceCustom => 'Anpassat';

  @override
  String get recurrenceEvery => 'Intervall';

  @override
  String get recurrenceUnit => 'Enhet';

  @override
  String get recurrenceDays => 'Dagar';

  @override
  String get recurrenceWeeks => 'Veckor';

  @override
  String get recurrenceMonths => 'Månader';

  @override
  String get recurrenceRepeatCount => 'Antal upprepningar';

  @override
  String get recurrenceNoLimit => 'Ingen gräns';

  @override
  String get recurrencePositiveNumber => 'Ange ett positivt tal';

  @override
  String get clearEndDate => 'Rensa slutdatum';

  @override
  String get pickDate => 'Välj datum';

  @override
  String get pickTime => 'Välj tid';

  @override
  String get reminder => 'Påminnelse i appen';

  @override
  String get reminderAtStart => 'Vid start';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min före';
  }

  @override
  String get reminderHourBefore => '1 timme före';

  @override
  String get reminderDayBefore => '1 dag före';

  @override
  String get markReminderHandled => 'Markera som hanterad';

  @override
  String get restoreReminder => 'Återställ påminnelse i appen';

  @override
  String get reminderHandled =>
      'Påminnelsen i appen har markerats som hanterad';

  @override
  String get reminderRestored => 'Påminnelsen i appen har återställts';

  @override
  String get reminderUpcoming => 'Kommande';

  @override
  String get reminderOverdue => 'Förfallen';

  @override
  String get generalFitWeekColumnsToWidth => 'Anpassa veckovyn till skärmen';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Visa hela veckan i kompakta layouter. Stäng av för horisontell rullning. Anpassade intervall över 7 dagar går fortfarande att rulla.';

  @override
  String get showWeekends => 'Visa helger';

  @override
  String get startHour => 'Starttimme';

  @override
  String get endHour => 'Sluttimme';

  @override
  String get timeGridDensity => 'Tidsrutnätets täthet';

  @override
  String get timeGridHourHeight => 'Timradens höjd';

  @override
  String get timeGridHourHeightHint =>
      'Ändrar höjdskalan för dag- och veckovyer utan att ändra rutnätets intervall på 15, 30 eller 60 minuter.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importera JSON-fil';

  @override
  String get pasteJson => 'Klistra in JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importera kategorier från kopierad JSON';

  @override
  String get importIcsFile => 'Importera ICS-fil';

  @override
  String get importIcsFileDesc => 'Läs händelser från en .ics-kalenderfil';

  @override
  String get pasteIcs => 'Klistra in ICS';

  @override
  String get pasteIcsDesc => 'Importera händelser från kopierad kalendertext';

  @override
  String get copyJson => 'Kopiera JSON';

  @override
  String get copyJsonDesc => 'Kopiera valda kategorier som JSON-text';

  @override
  String get shareIcs => 'Dela ICS';

  @override
  String get shareIcsDesc => 'Dela valda kategorier som .ics';

  @override
  String get saveIcs => 'Spara ICS';

  @override
  String get saveIcsDesc => 'Spara valda kategorier som .ics';

  @override
  String get copyIcs => 'Kopiera ICS';

  @override
  String get copyIcsDesc => 'Kopiera valda kategorier som ICS-text';

  @override
  String get importIcs => 'Importera ICS';

  @override
  String get icsContent => 'ICS-innehåll';

  @override
  String get pasteIcsContentHint =>
      'Klistra in innehåll som börjar med BEGIN:VCALENDAR här';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Hittade $count händelser. Lägga till dem som en ny kategori eller ersätta en befintlig kategori?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Importerade $count kategorier med $warningCount varningar';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Hoppade över en händelse utan starttid.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Hoppade över en händelse vars starttidsformat inte stöds.';

  @override
  String get importWarningAdjustedEnd =>
      'Justerade en händelse vars sluttid inte låg efter starttiden.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'ICS-fält som inte stöds lades till i anteckningarna: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Ignorerade en upprepningsfrekvens som inte stöds: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'Välj kategorier att kopiera som ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Välj kategorier att exportera som ICS';

  @override
  String get exportIcsText => 'Exportera ICS-text';

  @override
  String get exportJsonText => 'Exportera JSON-text';

  @override
  String get dataRestoredFromBackupNotice =>
      'Appdata återställdes från den föregående säkerhetskopian eftersom huvudfilen inte kunde läsas in.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Både huvuddatafilen och dess säkerhetskopia är skadade. Appen har nu startats med nya data.';

  @override
  String get dataRecoveryCorruptTitle => 'Dina data behöver återställas';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked kunde inte läsa huvuddatafilen eller dess säkerhetskopia. Skyddade kopior skapades innan skrivningar blockerades.';

  @override
  String get dataRecoveryIoFailureTitle => 'Lagringen är inte tillgänglig';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked kan inte komma åt den lokala lagringen just nu. Kontrollera lagringsåtkomst eller enhetens tillgänglighet och försök igen. Befintliga data skrivs inte över.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Uppdatera Sked för att öppna dessa data';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Dessa data skapades av en nyare version av Sked. Uppdatera appen innan du försöker igen. För att skydda dina data är det inte möjligt att börja om med nya data.';

  @override
  String get dataRecoveryRetryAction => 'Försök igen';

  @override
  String get dataRecoveryArtifactsHint =>
      'Återställningsfiler eller berörda lagringsplatser visas nedan. Låt filerna vara oförändrade tills dina data har återställts.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Visa återställningsfiler och lagringsplatser';

  @override
  String get dataRecoveryStartFreshAction => 'Börja med nya data';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Börja med nya data?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Skyddade kopior behålls, men Sked skapar en ny lokal datafil. Fortsätt bara om du inte vill försöka återställa dina data först.';

  @override
  String get previousMonth => 'Föregående månad';

  @override
  String get nextMonth => 'Nästa månad';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Pågår';

  @override
  String get deleteCourseTitle => 'Ta bort kurs';

  @override
  String get deleteCourseMessage => 'Ta bort den här kursen?';

  @override
  String get showLunarCalendar => 'Visa månkalender';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count händelser';
  }

  @override
  String get defaultView => 'Standardvy';

  @override
  String get generalDefaultViewSection => 'Vid start';

  @override
  String get generalViewSwitchBehavior => 'Knapp för vybyte';

  @override
  String get settingsWorkspaceMode => 'Aktiv arbetsyta';

  @override
  String get hideHomeWorkspaceNavigation => 'Dölj arbetsytenavigering';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Dölj navigeringen mellan arbetsytor. Du kan fortfarande byta via arbetsytemenyn på huvudskärmen.';

  @override
  String get generalDateLabelFormat => 'Format för datumetikett';

  @override
  String get generalDateLabelFormatLocalized => 'Lokalt format (juli 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Snedstreck (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Verktygsfältets layout';

  @override
  String get toolbarNavigationSection => 'Navigering i verktygsfältet';

  @override
  String get toolbarNavigationHiddenBehavior => 'Dolda objekt';

  @override
  String get toolbarNavigationRemove => 'Dölj helt';

  @override
  String get toolbarNavigationMore => 'Flytta till Mer';

  @override
  String get toolbarNavigationReorder => 'Ändra ordningen i verktygsfältet';

  @override
  String get toolbarNavigationVisibility => 'Visa objekt i verktygsfältet';

  @override
  String get toolbarNavigationTimetable => 'Schemaväljare';

  @override
  String get toolbarNavigationWeek => 'Veckoväljare';

  @override
  String get toolbarNavigationView => 'Vyväljare';

  @override
  String get toolbarNavigationCategory => 'Kategoriväljare';

  @override
  String get toolbarNavigationDate => 'Datumväljare';

  @override
  String get generalToolbarWidthPolicy => 'Utrymmesfördelning i verktygsfältet';

  @override
  String get generalToolbarWidthContent => 'Automatisk fördelning';

  @override
  String get generalToolbarWidthBalanced => 'Jämn fördelning';

  @override
  String get generalToolbarWidthCalendarPriority => 'Prioritera kategori';

  @override
  String get generalToolbarWidthDatePriority => 'Prioritera datum';

  @override
  String get generalViewSwitchCycle => 'Växla mellan vyer i ordning';

  @override
  String get generalViewSwitchMenu => 'Öppna vymenyn';

  @override
  String get generalViewSwitchTooltip => 'Byt vy';

  @override
  String get generalViewSwitchMenuTooltip => 'Välj vy';

  @override
  String get generalViewLongPressTodayHint =>
      'Tryck länge för att gå till idag';

  @override
  String get generalScheduleDisplaySection => 'Schemavisning';

  @override
  String get generalTimeGridSection => 'Tidsrutnät';

  @override
  String get generalPopupSection => 'Popupfönster';

  @override
  String get quickActionsSection => 'Snabbåtgärder';

  @override
  String get showAddCourseFab =>
      'Visa flytande knapp för att lägga till kurser';

  @override
  String get showAddCourseFabHint =>
      'Visa eller dölj den flytande knappen för att lägga till kurser längst ned till höger i kursschemat.';

  @override
  String get showAddEventFab =>
      'Visa flytande knapp för att lägga till händelser';

  @override
  String get showAddEventFabHint =>
      'Visa eller dölj den flytande knappen för att lägga till händelser längst ned till höger i schemat.';

  @override
  String get enableLongPressAddCourse =>
      'Tryck länge på en tom ruta för att lägga till kurser';

  @override
  String get enableLongPressAddCourseHint =>
      'Tryck länge på ett tomt område i kursschemats rutnät för att lägga till en kurs.';

  @override
  String get enableLongPressAddEvent =>
      'Tryck länge på en tom ruta för att lägga till händelser';

  @override
  String get enableLongPressAddEventHint =>
      'Tryck länge på ett tomt område i tidsrutnätet i dag- eller veckovyn för att lägga till en händelse.';

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
  String get developerNotificationDiagnostics => 'Aviseringsdiagnostik';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Granska leveransstatus på Android, bygg om den befintliga påminnelseplanen och skicka säkra testaviseringar via Skeds vanliga aviseringstjänst.';

  @override
  String get developerNotificationUnsupported =>
      'Aviseringsdiagnostik är endast tillgänglig på Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Aviseringsdiagnostiken blir tillgänglig när schemakoordinatorn har startat.';

  @override
  String get developerNotificationRefresh => 'Uppdatera diagnostik';

  @override
  String get developerNotificationSystemStatus =>
      'Systembehörighet för aviseringar';

  @override
  String get developerNotificationPermissionAllowed => 'Tillåten';

  @override
  String get developerNotificationPermissionBlocked => 'Blockerad';

  @override
  String get developerNotificationExactAlarm => 'Exakta alarm';

  @override
  String get developerNotificationExactAlarmAllowed => 'Tillåtna';

  @override
  String get developerNotificationExactAlarmBlocked => 'Inte tillåtna';

  @override
  String get developerNotificationPlan => 'Schema för aviseringar';

  @override
  String get developerNotificationCoverage => 'Påminnelsernas täckning';

  @override
  String get developerNotificationCoverageReady =>
      'Alla kända påminnelser med ett slut är direkt schemalagda';

  @override
  String get developerNotificationCoverageRenewable =>
      'Återkommande påminnelser förnyas långsiktigt i mån av möjlighet';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Kapaciteten för direkt schemalagda alarm är full. Senare påminnelser förnyas i mån av möjlighet';

  @override
  String get developerNotificationCoverageBlocked =>
      'Kraven för leverans vid exakt tid är inte uppfyllda';

  @override
  String get developerNotificationCoverageFailed =>
      'Den senaste synkroniseringen av påminnelser misslyckades';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled direkt schemalagda alarm / kapacitet $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled schemalagda, $planned planerade';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Senaste fel: $message';
  }

  @override
  String get developerNotificationRunMaintenance => 'Bygg om aviseringsplanen';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Aviseringsplanen har byggts om.';

  @override
  String get developerNotificationTestChannel => 'Testkanal';

  @override
  String get developerNotificationTestCourse => 'Kurspåminnelser';

  @override
  String get developerNotificationTestSchedule => 'Schemapåminnelser';

  @override
  String get developerNotificationImmediateTest => 'Skicka test direkt';

  @override
  String get developerNotificationThirtySecondTest =>
      'Schemalägg bakgrundstest om 30 sekunder';

  @override
  String get developerNotificationImmediateQueued =>
      'Testaviseringen skickades direkt.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Bakgrundstestet är schemalagt om 30 sekunder.';

  @override
  String get developerNotificationAppSwitch => 'Appens påminnelsereglage';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Aktiverat för vanliga påminnelser';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Inaktiverat för vanliga påminnelser. Utvecklartester kan fortfarande köras';

  @override
  String get developerNotificationTimeZone => 'Lokal tidszon';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Har inte skapats ännu. Ett utvecklartest skapar den.';

  @override
  String get developerNotificationChannelEnabledState => 'Aktiverad';

  @override
  String get developerNotificationChannelBlockedState => 'Blockerad';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Viktighet: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Viktighet inte tillgänglig';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending väntande / $active aktiva';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Senast visad av systemet: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Ingen omberäkning har registrerats ännu.';

  @override
  String get developerNotificationNextReminder => 'Nästa ordinarie påminnelse';

  @override
  String get developerNotificationNoPendingReminder =>
      'Det finns inga framtida påminnelser i den aktuella planen';

  @override
  String get developerNotificationNextMaintenance => 'Nästa underhåll';

  @override
  String get developerNotificationNextRenewal =>
      'Nästa förnyelse i mån av möjlighet';

  @override
  String get developerNotificationNoMaintenance => 'Inte schemalagt';

  @override
  String get developerNotificationTruncation => 'Begränsning av planen';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count utelämnade på grund av planens gräns';
  }

  @override
  String get developerNotificationLastReconciliation => 'Senaste omberäkning';

  @override
  String get developerNotificationLastSynchronization =>
      'Senaste påminnelsesynkronisering';

  @override
  String get developerNotificationLateRecovery =>
      'Återställning av försenade påminnelser';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count påminnelser återställdes efter sin ursprungliga tid';
  }

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
  String get developerNotificationReconcileOriginForeground => 'Förgrund';

  @override
  String get developerNotificationReconcileOriginBackground => 'Bakgrund';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Fullständig omberäkning';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Underhåll';

  @override
  String get developerNotificationReconcileModeRecovery => 'Återställning';

  @override
  String get developerNotificationRunRecovery => 'Återställ påminnelser';

  @override
  String get developerNotificationRecoveryComplete =>
      'Påminnelserna har återställts';

  @override
  String get developerNotificationReconcileResultSuccess => 'Lyckades';

  @override
  String get developerNotificationReconcileResultSkipped => 'Hoppades över';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Blockerat tills alla krav för leverans vid exakt tid är uppfyllda';

  @override
  String get developerNotificationReconcileResultFailed => 'Misslyckades';

  @override
  String get developerNotificationBackgroundLimits =>
      'Tillverkarens bakgrundsbegränsningar';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Tillverkarens bakgrundsbegränsningar kan påverka leveransen.';

  @override
  String get developerNotificationAutostart =>
      'Bakgrundsstart enligt tillverkaren';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Tillverkare: $vendor. En sida med tillverkarinställningar finns. Android kan inte visa om behörighet har beviljats.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Tillverkare: $vendor. Appinfosidan används som alternativ. Android kan inte visa om behörighet har beviljats.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Det finns ingen tillgänglig sida med tillverkarens bakgrundsinställningar.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Senast öppnade mål: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'tillverkarinställningar';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'appinformation';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'inget';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Villkor för återställning efter omstart';

  @override
  String get developerNotificationRebootBoundary =>
      'Återställningen börjar efter den första upplåsningen. En tvångsstoppad app kan inte starta sig själv.';

  @override
  String get developerNotificationTestChecking =>
      'Testerna är inte tillgängliga medan aviseringsstatusen kontrolleras.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Testerna är inte tillgängliga eftersom systemaviseringar är blockerade.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Testerna är inte tillgängliga eftersom den valda aviseringskanalen är blockerad.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Hanteras i Windows aviseringsinställningar';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Gäller inte för Windows';

  @override
  String get developerNotificationWindowsIdentity => 'Windows-paketidentitet';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX-identitet finns. Visade aviseringar kan tas bort';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Installera MSIX-versionen för att kunna ta bort visade aviseringar på ett tillförlitligt sätt';

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

  @override
  String get notificationSettingsSection => 'Påminnelser och aviseringar';

  @override
  String get notificationCoverage => 'Påminnelsernas täckning';

  @override
  String get notificationCoverageRenewable =>
      'Återkommande händelser utan slutdatum förnyas i bakgrunden för att täcka en längre tid.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android kan direkt schemalägga upp till $capacity påminnelser. Senare påminnelser förnyas i förväg i mån av möjlighet.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Aktivera påminnelser och aviseringar';

  @override
  String get notificationSettingsEnabledHint =>
      'Schemalägger bara objekt som har en påminnelse. Ange en standardpåminnelse nedan för kurser som använder standardinställningen.';

  @override
  String get notificationPrecisionLimitations =>
      'Påminnelser beror på systembehörigheter och bakgrundskörning. Avstängning, tidsändringar eller systembegränsningar kan fördröja dem.';

  @override
  String get notificationSettingsEnabledSummary => 'Aktiverat';

  @override
  String get notificationSettingsDisabledSummary => 'Inaktiverat';

  @override
  String get notificationDefaultsSection => 'Standardpåminnelser';

  @override
  String get notificationCourseDefaultReminder =>
      'Standardpåminnelse för kurser';

  @override
  String get notificationGeneralDefaultReminder =>
      'Standardpåminnelse för händelser';

  @override
  String get notificationReminderOff => 'Ingen påminnelse';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minuter före';
  }

  @override
  String get notificationPermission => 'Behörighet för aviseringar';

  @override
  String get notificationPermissionGranted => 'Tillåten av systemet';

  @override
  String get notificationPermissionDenied => 'Blockerad av systemet';

  @override
  String get notificationPermissionChecking => 'Kontrollerar behörighet…';

  @override
  String get notificationPermissionRequest => 'Begär behörighet';

  @override
  String get notificationPermissionOpenSettings =>
      'Öppna systeminställningarna';

  @override
  String get notificationPermissionRequestFailed =>
      'Det gick inte att läsa aviseringsbehörigheten. Försök igen.';

  @override
  String get notificationExactAlarm => 'Behörighet för exakta alarm';

  @override
  String get notificationExactAlarmAllowed => 'Tillåten av systemet';

  @override
  String get notificationExactAlarmRequired =>
      'Krävs för påminnelser vid exakt tid';

  @override
  String get notificationExactAlarmRequest => 'Tillåt exakta alarm';

  @override
  String get notificationBatteryOptimization => 'Batterioptimering';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Undantagen från Androids batterioptimering';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Påminnelser vid exakt tid kräver undantag från Androids batterioptimering';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Öppna inställningar för batterioptimering';

  @override
  String get notificationAutostart => 'Bakgrundsstart enligt tillverkaren';

  @override
  String get notificationAutostartVendorHint =>
      'Tillåt automatisk start eller körning i bakgrunden så att påminnelser kan återställas efter omstart.';

  @override
  String get notificationAutostartFallbackHint =>
      'Öppna Skeds appinformation och tillåt körning i bakgrunden. Android kan inte verifiera denna tillverkarinställning.';

  @override
  String get notificationAutostartUnavailable =>
      'Ingen sida med tillverkarinställningar hittades. Kontrollera Skeds appinformation manuellt.';

  @override
  String get notificationAutostartRequest =>
      'Öppna tillverkarens bakgrundsinställningar';

  @override
  String get notificationAutostartOpenFailed =>
      'Det gick inte att öppna tillverkarens bakgrundsinställningar. Kontrollera Skeds appinformation manuellt.';

  @override
  String get notificationLockScreenTitles => 'Visa titlar på låsskärmen';

  @override
  String get notificationLockScreenTitlesHint =>
      'När detta är avstängt döljs aviseringsdetaljer på låsskärmen.';

  @override
  String get notificationWidgets => 'Widgetar på startskärmen';

  @override
  String get notificationWidgetsDesc =>
      'Uppdatera Skeds widgetar och se hur du lägger till en på startskärmen.';

  @override
  String get notificationWidgetsDialogTitle => 'Lägg till en Sked-widget';

  @override
  String get notificationWidgetsDialogMessage =>
      'Tryck länge på ett tomt område på enhetens startskärm, välj Widgetar och lägg till en Sked-widget. Widgeten visar dina kommande kurser eller händelser.';

  @override
  String get notificationWidgetsRefresh => 'Uppdatera widgetar';

  @override
  String get notificationWidgetsRefreshed => 'Widgetarna har uppdaterats';

  @override
  String get notificationPlatformUnsupported =>
      'Denna plattform har inget stöd för systemaviseringar.';

  @override
  String get workspaceFeatures => 'Funktionshantering';

  @override
  String get workspaceBoth => 'Schema och kalender';

  @override
  String get workspaceOnlyStudent => 'Endast schema';

  @override
  String get workspaceOnlyGeneral => 'Endast kalender';

  @override
  String get workspaceDisableTitle => 'Stänga av den här arbetsytan?';

  @override
  String get workspaceDisableMessage =>
      'Data och inställningar sparas. Funktioner och påminnelser stoppas tills du aktiverar arbetsytan här igen.';

  @override
  String get workspaceEnableHint =>
      'Välj de funktioner du använder. Minst en måste vara aktiv.';

  @override
  String get workspaceLastRequired => 'Minst en arbetsyta måste vara aktiv.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Arbetsytan är avstängd, men påminnelserna kunde inte tas bort. Försök återställa aviseringarna igen.';

  @override
  String get settingsSearch => 'Sök i inställningar';

  @override
  String get settingsNoResults => 'Inga matchande inställningar';

  @override
  String get settingsDataPrivacy => 'Data och integritet';

  @override
  String get workspacePreferences => 'Visning och interaktion';

  @override
  String get workspaceManage => 'Hantera';

  @override
  String get selectedDayAgenda => 'Vald dag';

  @override
  String get notificationTroubleshooting => 'Behörigheter och felsökning';

  @override
  String get settingsConnection => 'Anslutning';

  @override
  String get settingsAdvanced => 'Avancerat';

  @override
  String get unsavedChangesMessage =>
      'Du har osparade ändringar. Kasta dem och lämna?';

  @override
  String get backupWorkspaceSelection =>
      'Den fullständiga säkerhetskopian innehåller data och valet av aktiva arbetsytor.';

  @override
  String get assistantLayoutPreview => 'AI · Layoutförhandsvisning';

  @override
  String get assistantSelectionContext =>
      'Använder det aktuella valet som sammanhang';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Meddelandeutkast';

  @override
  String get assistantPreviewNoSend =>
      'Endast förhandsvisning av layouten. Inget skickas eller ändras.';

  @override
  String get resizePanel => 'Ändra panelens storlek';

  @override
  String get minimizeWindow => 'Minimera';

  @override
  String get maximizeWindow => 'Maximera';

  @override
  String get restoreWindow => 'Återställ fönster';

  @override
  String get closeWindow => 'Stäng fönster';

  @override
  String get courseSystemReminder => 'Systempåminnelse';

  @override
  String courseReminderInherit(String reminder) {
    return 'Använd standard ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Systempåminnelser är avstängda i aviseringsinställningarna. Du kan fortfarande spara påminnelseinställningen för den här kursen.';

  @override
  String get courseReminderDefaultOff =>
      'Ingen standardpåminnelse för kurser har angetts. Välj en egen påminnelse här eller ange en standard i aviseringsinställningarna.';

  @override
  String get courseReminderDeliveryHint =>
      'Inställningen sparas med kursen. Leveransen beror på systemets aviseringsbehörigheter och bakgrundsbegränsningar.';

  @override
  String get courseReminderPermissionUnknown =>
      'Statusen för systemaviseringar har inte kontrollerats. Granska aviseringsinställningarna innan du förlitar dig på påminnelser.';

  @override
  String get courseReminderMinutesLabel => 'Minuter före kursstart';

  @override
  String get exportAction => 'Exportera';

  @override
  String get datePickerSelectWeek => 'Välj vecka';

  @override
  String get datePickerSelectMonth => 'Välj månad';

  @override
  String get generalDateLabelFormatDescription =>
      'Gäller datumnavigering på datorer och mindre skärmar.';

  @override
  String get dateRangeTitle => 'Välj datumintervall';

  @override
  String get dateRangeCustom => 'Anpassat';

  @override
  String get dateRangeChooseStart => 'Välj startdatum';

  @override
  String get dateRangeChooseEnd => 'Välj slutdatum';

  @override
  String get dateRangeLimit =>
      'Välj 1–14 dagar, inklusive start- och slutdatum.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return 'Anpassat · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Välj med rullhjul';

  @override
  String get courseReminderUseDefault => 'Använd standard';

  @override
  String get courseReminderInvalidMinutes =>
      'Ange ett helt antal minuter, noll eller mer.';

  @override
  String get generalCustomColumnWidth => 'Kolumnbredd i anpassad vy';

  @override
  String get generalCustomColumnWidthAuto => 'Automatisk';

  @override
  String get generalCustomColumnWidthManual => 'Minsta bredd';

  @override
  String get generalCustomColumnWidthMinimum => 'Minsta bredd per dag';

  @override
  String get generalCustomColumnWidthHint =>
      'Alla datum har samma minsta bredd. Kolumnerna fyller det tillgängliga utrymmet eller rullas i sidled. Påverkar bara den anpassade vyn.';

  @override
  String get settingsAppearanceLanguage => 'Utseende och språk';

  @override
  String get settingsAppearanceDetails => 'Färger och konturer';

  @override
  String get monthNoEvents => 'Inga händelser denna dag';

  @override
  String get settingsOverview => 'Översikt';

  @override
  String get settingsThemeTarget => 'Tema för';

  @override
  String get settingsColorMode => 'Färgläge';

  @override
  String get settingsNotificationPreferences => 'Påminnelseinställningar';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Standardpåminnelser, behörigheter och tillförlitlighet';

  @override
  String get settingsFeaturesSummary => 'Arbetsytor och navigering';

  @override
  String get settingsPrivacySummary =>
      'Integritetspolicy och rensning av lokala data';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lektionspass',
      one: '1 lektionspass',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Lektionspass';

  @override
  String get periodTimesDurationColumn => 'Längd';

  @override
  String get periodTimesGapColumn => 'Rast';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Väntar på att spara…';

  @override
  String get periodTimesSaveFailed => 'Inte sparat · Det gick inte att spara';

  @override
  String get periodTimesInvalidStatus =>
      'Inte sparat · Rätta de markerade tiderna';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked kunde inte bekräfta om den senaste sparningen återställdes. Skrivning är pausad och återställningskopior har bevarats. Kontrollera lagringen och försök läsa in igen.';

  @override
  String get settingsPanelDisplayMode => 'Panelvisning';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Gemensam för scheman och kalendrar';

  @override
  String get settingsPanelDisplayOverlay => 'Överlagring';

  @override
  String get settingsPanelDisplaySideBySide => 'Sida vid sida';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatisk';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Lägger panelen över höger sida utan att ändra kalenderns bredd.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Föredrar sida vid sida; överlagrar bara om kalendern blir för smal.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Visar sida vid sida när kalendern har läsbar bredd, annars som överlagring.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Om du döljer Inställningar eller Arbetsyta i verktygsfältet flyttas de till Mer. Åtkomsten finns kvar. Mer kan inte döljas när menyn innehåller nödvändiga åtgärder. Arbetsyteväxlaren visas bara när den nedre navigeringen är dold och flera arbetsytor är aktiverade.';

  @override
  String get reminderEnded => 'Avslutad';

  @override
  String get reminderAutoCloseHint =>
      'Stängs efter 10 sekunder. Använd panelen för att hålla den öppen.';

  @override
  String get showReminderIndependently => 'Öppna separat';

  @override
  String get categoryManagerTitle => 'Hantera kategorier';

  @override
  String get categoryHidden => 'Dold';

  @override
  String get categoryShowOnCalendar => 'Visa i kalendern';

  @override
  String get categoryHideOnCalendar => 'Dölj i kalendern';

  @override
  String get categoryEditColor => 'Ändra kategorifärg';

  @override
  String get categoryThemePalette => 'Temafärger';

  @override
  String get categoryCustomColor => 'Anpassad';

  @override
  String get colorHexInvalid => 'Ange en sexsiffrig hexadecimal färgkod.';

  @override
  String categoryColorSlot(int number) {
    return 'Temafärg $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Butiksuppdateringar kan komma senare. Se butikssidan för tillgänglighet.';

  @override
  String get storePrereleaseNotice =>
      'Aviseringar om förhandsversioner innebär inte att du automatiskt ansluts till butikens testprogram.';

  @override
  String get updateFoundTitle => 'Ny version tillgänglig';

  @override
  String get updateNoNotes => 'Det finns inga versionsanteckningar.';

  @override
  String get updateLater => 'Senare';

  @override
  String get updateRetry => 'Försök igen';

  @override
  String get updatePrerelease => 'Förhandsversion';

  @override
  String get updateNetworkFailure =>
      'Det gick inte att söka efter uppdateringar. Kontrollera anslutningen och försök igen.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Ingen nyare version hittades (aktuell: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Återställer säkerhetskopian…';

  @override
  String get backupRestoreInProgressMessage =>
      'Data och inställningar kan ändras när återställningen är klar. Du kan fortfarande visa dem.';
}
