// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get appTitle => 'Klassekammerat';

  @override
  String weekLabel(int week) {
    return 'Uge $week';
  }

  @override
  String get addCourse => 'Tilføj kursus';

  @override
  String get settings => 'Indstillinger';

  @override
  String get multiTimetableSwitch => 'Skift tidsplaner';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Nuværende tidsplan · $weeks uger';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tryk for at skifte · $weeks uger';
  }

  @override
  String get editTimetable => 'Rediger tidsplan';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get schoolImportParsePageTitle => 'Analyser skema';

  @override
  String get schoolImportParsePageParsing => 'Analyserer…';

  @override
  String get schoolImportParsePageFailed => 'Analysen mislykkedes';

  @override
  String get schoolImportParsePageComplete => 'Analyse fuldført';

  @override
  String get schoolImportParsePageContinue => 'Fortsæt';

  @override
  String get schoolImportParsePageRawContent => 'Rå svar';

  @override
  String get schoolImportParsePageExpandRaw => 'Udvid råt svar';

  @override
  String get schoolImportParsePageCollapseRaw => 'Fold råt svar sammen';

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
  String get createTimetable => 'Ny tidsplan';

  @override
  String get jumpToWeek => 'Hop til ugen';

  @override
  String get timetable => 'Tidsplan';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Navn på tidsplan';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Totalt uger';

  @override
  String get delete => 'Slet';

  @override
  String get cancel => 'Afbryd';

  @override
  String get save => 'Gem';

  @override
  String get deleteTimetableTitle => 'Slet tidsplan';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Slet \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Ingen tidsplan endnu';

  @override
  String get noTimetableMessage =>
      'Opret en tidsplan eller importer en fra en JSON-fil.';

  @override
  String get importTimetable => 'Import tidsplan';

  @override
  String get courseName => 'Kursets navn';

  @override
  String get location => 'Beliggenhed';

  @override
  String get dayOfWeek => 'Dag';

  @override
  String get semesterWeeks => 'uger';

  @override
  String get startTime => 'Starttid';

  @override
  String get endTime => 'Sluttid';

  @override
  String get linkedPeriods => 'Forbundne perioder';

  @override
  String get linkedPeriodsUnmatched =>
      'Ingen perioder matchede for den aktuelle tid. Tryk for at vælge manuelt.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Periode $start-$end';
  }

  @override
  String get teacherName => 'Lærer';

  @override
  String get credits => 'Kreditter';

  @override
  String get remarks => 'Bemærkninger';

  @override
  String get customFields => 'Brugerdefinerede felter';

  @override
  String get customFieldsHint => 'En pr. linje, format: nøgle:værdi';

  @override
  String get more => 'Mere';

  @override
  String get selectDayOfWeek => 'Vælg dag';

  @override
  String get selectSemesterWeeks => 'Vælg uger';

  @override
  String get selectAll => 'Vælg alle';

  @override
  String get clear => 'Ryd';

  @override
  String get confirm => 'Bekræft';

  @override
  String get selectLinkedPeriods => 'Vælg tilknyttede perioder';

  @override
  String get addCourseTitle => 'Tilføj kursus';

  @override
  String get editCourseTitle => 'Rediger kursus';

  @override
  String get editCourseTooltip => 'Rediger kursus';

  @override
  String get place => 'Beliggenhed';

  @override
  String get time => 'Tid';

  @override
  String get notFilled => 'Ikke udfyldt';

  @override
  String get none => 'Ingen';

  @override
  String get conflictCourses => 'Konflikterende kurser';

  @override
  String get locationNotFilled => 'Beliggenhed ikke udfyldt';

  @override
  String get setAsDisplayed => 'Sæt som vist';

  @override
  String get editThisCourse => 'Rediger dette kursus';

  @override
  String get settingsTitle => 'Indstillinger';

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
      'Der er i øjeblikket ingen tidsplan tilgængelig for indstillinger.';

  @override
  String get semesterStartDate => 'Startdato for semestret';

  @override
  String get periodTimeSets => 'Periodetid indstillet';

  @override
  String get noPeriodTimeAvailable => 'Ingen tilgængelig periode tid angivet';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count perioder';
  }

  @override
  String get coursePopupDismissSetting =>
      'Tillad udenfor tryk for at lukke kursus popup';

  @override
  String get coursePopupDismissSettingHint =>
      'Hvis du slår dette fra, deaktiveres også skyde ned afskedigelse.';

  @override
  String get preserveTimetableGaps => 'Bevar tidsplanens huller';

  @override
  String get preserveTimetableGapsHint =>
      'Når du er ude, kollapser frokost og pause huller, så senere klasser bevæger sig opad.';

  @override
  String get showPastEndedCourses => 'Vis tidligere afsluttede kurser';

  @override
  String get showPastEndedCoursesHint =>
      'Vis kurser, der allerede er afsluttet ved den virkelige nuværende uge med en lysegrå stil.';

  @override
  String get showFutureCourses => 'Vis fremtidige kurser';

  @override
  String get showFutureCoursesHint =>
      'Vis kurser, der ikke er aktive i denne uge, men vises i senere uger med en grå stil.';

  @override
  String get timetableDisplaySettings => 'Tidsplan visning og interaktion';

  @override
  String get timetableDisplaySettingsDesc =>
      'Visning af fag, layout, ugebevægelser og hurtig tilføjelse';

  @override
  String get showTimetableGridLines => 'Vis tidsplan gitterlinjer';

  @override
  String get showTimetableGridLinesHint =>
      'Kontroller, om vandrette og lodrette gitterlinjer er synlige i tidsplanen.';

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
  String get liveCourseOutlineColor => 'Farve på kursus';

  @override
  String get liveCourseOutlineColorHint =>
      'Vælg, om konturerne er rettet mod det aktuelle/næste kursus eller alle de kurser, der vises på den aktuelle side.';

  @override
  String get liveCourseOutlineSettings => 'Kursus oversigt';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Konfigurer, om konturen er aktiveret, hvad den målretter sig mod, om den følger temafarven og den effektive konturfarve.';

  @override
  String get liveCourseOutlineEnabled => 'Aktiver kontur';

  @override
  String get liveCourseOutlineFollowTheme => 'Følg temafarve';

  @override
  String get liveCourseOutlineTarget => 'Skitseret mål';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Aktuelt/næste kursus';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Alle vist kurser';

  @override
  String get liveCourseOutlineEffectiveColor => 'Effektiv farve';

  @override
  String get liveCourseOutlineCustomColor => 'Brugerdefineret konturfarve';

  @override
  String get liveCourseOutlineWidth => 'Omkringsbredde';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Sprog';

  @override
  String get languagePageDescription =>
      'Vælg et af de sprog, der virkelig er tilgængelige i appen.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'engelsk';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API-svar';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Følg systemet';

  @override
  String get themeLight => 'Lys';

  @override
  String get themeDark => 'Mørk';

  @override
  String get themeColor => 'Temafarve';

  @override
  String get themeColorModeSingle => 'Enkelt temafarve';

  @override
  String get themeColorModeColorful => 'Farverige';

  @override
  String get themeColorUiColors => 'UI farver';

  @override
  String get themeColorCourseColors => 'Kursfarver';

  @override
  String get themeColorPrimary => 'Primært';

  @override
  String get themeColorSecondary => 'Sekundær';

  @override
  String get themeColorTertiary => 'Tertiær';

  @override
  String get themeColorCourseText => 'Kursustekst';

  @override
  String get themeColorCourseTextAuto => 'automatisk';

  @override
  String get themeColorCourseTextCustom => 'Brugerdefineret farve';

  @override
  String get themeColorCourseColorsEmpty =>
      'Kursets farver vil blive genereret efter import af en tidsplan.';

  @override
  String get themeCustomColor => 'Brugerdefineret farve';

  @override
  String get themeApplyCustomColor => 'Anvend farve';

  @override
  String get themeApplySettings => 'Anvend indstillinger';

  @override
  String get dataImportExport => 'Import og eksport af data';

  @override
  String get dataImportExportDesc =>
      'Importer fulde data eller enkelte tidsplaner, eller eksporter aktuelle/alle tidsplaner.';

  @override
  String get appBackupTitle => 'App-sikkerhedskopi og gendannelse';

  @override
  String get appBackupSubtitle =>
      'Sikkerhedskopiér eller gendan skemaer, planer, indstillinger og skolesider. API-nøgler er ikke inkluderet.';

  @override
  String get appBackupSheetSubtitle =>
      'En fuld gendannelse erstatter de aktuelle appdata. AI-API-nøgler ligger i sikker lagring og skrives ikke til sikkerhedskopier.';

  @override
  String get restoreBackupFileTitle => 'Gendan fra JSON-fil';

  @override
  String get restoreBackupFileSubtitle =>
      'Vælg en fuld Sked-sikkerhedskopi. Du skal bekræfte før gendannelse.';

  @override
  String get restoreBackupTextTitle => 'Indsæt sikkerhedskopi-JSON';

  @override
  String get restoreBackupTextSubtitle =>
      'Indsæt en fuld sikkerhedskopi og gendan de aktuelle appdata.';

  @override
  String get shareBackupTitle => 'Del sikkerhedskopifil';

  @override
  String get shareBackupSubtitle =>
      'Eksportér alle appdata som JSON. API-nøgler udelades.';

  @override
  String get saveBackupTitle => 'Gem sikkerhedskopifil';

  @override
  String get saveBackupSubtitle =>
      'Gem en fuld app-sikkerhedskopi i en lokal fil.';

  @override
  String get copyBackupTitle => 'Kopiér sikkerhedskopitekst';

  @override
  String get copyBackupSubtitle =>
      'Vis den fulde sikkerhedskopi-JSON, så du kan kopiere eller gemme den midlertidigt.';

  @override
  String get restoreBackupConfirmTitle => 'Gendan fuld sikkerhedskopi?';

  @override
  String get restoreBackupConfirmMessage =>
      'Dette erstatter alle aktuelle skemaer, generelle planer, indstillinger og skolesider. API-nøgler importeres ikke fra sikkerhedskopier; indtast nøglen igen, før du parser skemaer igen.';

  @override
  String get restoreBackupConfirmAction => 'Gendan sikkerhedskopi';

  @override
  String get restoreBackupSuccessMessage =>
      'Fuld app-sikkerhedskopi gendannet. AI-API-nøgler skal indtastes igen.';

  @override
  String get restoreBackupFailureMessage =>
      'Gendannelse mislykkedes. Kontrollér sikkerhedskopiens indhold, og prøv igen.';

  @override
  String get openSourceLicenses => 'Open source-licenser';

  @override
  String get openSourceLicensesDesc =>
      'Se licenser for Flutter-afhængigheder og bundtede app-ikonaktiver.';

  @override
  String get checkForUpdates => 'Tjek efter opdateringer';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Allerede på den seneste version ($version)';
  }

  @override
  String get currentVersionLabel => 'Aktuel version';

  @override
  String get newVersionAvailable => 'Opdatering tilgængelig';

  @override
  String get latestVersionLabel => 'Seneste version';

  @override
  String get updateContentLabel => 'Opdater detaljer';

  @override
  String get officialWebsite => 'Officiel hjemmeside';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud-drev';

  @override
  String get ignoreThisVersion => 'Ignorer denne version';

  @override
  String get openUpdatesFailed => 'Kunne ikke åbne opdateringslinket';

  @override
  String get updateCheckFailedTitle => 'Opdateringskontrol mislykkedes';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub-lager';

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
  String get openGithubFailed => 'Kan ikke åbne linket til GitHub-repositoriet';

  @override
  String get openPrivacyPolicyFailed =>
      'Kan ikke åbne linket til privatlivspolitikken';

  @override
  String get selectPeriodTimeSet => 'Vælg periode tidsindstilling';

  @override
  String get newItem => 'Nyt';

  @override
  String get editPeriodTimeSet => 'Rediger tidsindstilling for perioden';

  @override
  String get importTimetableFiles => 'Import tidsplan';

  @override
  String get importTimetableFilesDesc =>
      'Understøtter en eller flere tidsplan filer.';

  @override
  String get importTimetableText => 'Importer tidsplan fra tekst';

  @override
  String get importTimetableTextDesc =>
      'Indsæt tidsplan JSON indhold og importere det.';

  @override
  String get shareTimetableFiles => 'Del tidsplan filer';

  @override
  String get shareTimetableFilesDesc => 'Vælg en eller flere tidsplaner først.';

  @override
  String get saveTimetableFiles => 'Gem tidsplan filer';

  @override
  String get saveTimetableFilesDesc => 'Vælg en eller flere tidsplaner først.';

  @override
  String get exportTimetableText => 'Eksporter tidsplan som tekst';

  @override
  String get exportTimetableTextDesc =>
      'Vælg en eller flere tidsplaner, og kopier derefter JSON-indholdet.';

  @override
  String get jsonContent => 'JSON indhold';

  @override
  String get pasteJsonContentHint => 'Indsæt JSON-indholdet for at importere.';

  @override
  String get jsonContentEmpty => 'Indsæt JSON indhold først.';

  @override
  String get copyText => 'Kopier';

  @override
  String get copiedToClipboard => 'Kopieret til udklipstavle';

  @override
  String get share => 'Del';

  @override
  String get selectTimetablesToExport => 'Vælg tidsplaner til eksport';

  @override
  String get selectTimetablesToImport => 'Vælg tidsplaner at importere';

  @override
  String timetableCourseCount(int count) {
    return '$count kurser';
  }

  @override
  String get importAction => 'Import';

  @override
  String get importTimetableDialogTitle => 'Import tidsplan';

  @override
  String get chooseImportMethod => 'Vælg hvordan du importerer.';

  @override
  String get importAsNewTimetable => 'Importer som ny tidsplan';

  @override
  String get replaceCurrentTimetable => 'Erstat nuværende tidsplan';

  @override
  String get importPeriodTimeSetDialogTitle => 'Import periode tidssæt';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Denne fil indeholder bundtede periodetidssæt. Vil du importere og tilknytte dem?';

  @override
  String get importBundledPeriodTimeSets => 'Import og tilknytning';

  @override
  String get discardBundledPeriodTimeSets => 'Kast bundtede sæt';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Der er ingen eksisterende periodetidssæt tilgængelige, så bundtede periodetidssæt kan ikke kasseres.';

  @override
  String savedToPath(Object path) {
    return 'Gemt til $path';
  }

  @override
  String get saveCancelled => 'Gem annulleret';

  @override
  String get fileSaveRestrictedTitle => 'Fillagring begrænset';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Systemet kunne ikke gemme filen. Du kan prøve igen eller bruge deling i stedet.';

  @override
  String get retrySave => 'Prøv at gemme igen';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Aktiver filadgang i systemindstillingerne, vend derefter tilbage og prøv at eksportere igen.';

  @override
  String get openSettings => 'Åbn indstillinger';

  @override
  String get browserDownloadRestrictedTitle => 'Browser download begrænset';

  @override
  String get browserDownloadRestrictedMessage =>
      'Denne browser understøtter ikke direkte gemning til en lokal fil. Kontroller browserens downloadtilladelser eller brug fildeling i stedet.';

  @override
  String get switchToShare => 'Brug deling i stedet';

  @override
  String get fileSaveFailedTitle => 'Fillagring mislykkedes';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Kunne ikke skrive til den aktuelle sti. Målmappen kan være beskyttet, filen kan være i brug, eller stien kan ikke skrives.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Systemet kunne ikke gemme filen. Du kan prøve igen, kontrollere systemindstillingerne eller bruge fildeling i stedet.';

  @override
  String get retryLater => 'Prøv igen senere';

  @override
  String get exportSwitchedToShare => 'Skiftet til fildeling til eksport';

  @override
  String get saveFailedRetry => 'Gemning mislykkedes. Prøv igen senere.';

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
  String get appInstanceBlockedTitle => 'Sked er allerede åben';

  @override
  String get appInstanceBlockedMessage =>
      'Et andet Sked-vindue eller en anden browserfane bruger dine lokale data. Luk vinduet eller fanen, og prøv igen.';

  @override
  String get appInstanceLeaseFailedTitle => 'Lokale data er ikke tilgængelige';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked kunne ikke bekræfte eksklusiv adgang til lokale data. Dine data blev ikke åbnet eller ændret. Kontrollér adgangen til lageret, og prøv igen.';

  @override
  String get savingChanges => 'Gemmer ændringer...';

  @override
  String get showApiKey => 'Vis API-nøgle';

  @override
  String get hideApiKey => 'Skjul API-nøgle';

  @override
  String get importFailedCheckContent =>
      'Import mislykkedes. Kontroller venligst filens indhold.';

  @override
  String get noImportableTimetables =>
      'Der blev ikke fundet nogen brugbare tidsplaner i den importerede fil.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importerede $count tidsplaner';
  }

  @override
  String get periodTimesTitle => 'Periodetider';

  @override
  String get importExport => 'Import og eksport';

  @override
  String get importPeriodTemplate => 'Skabelon til importperiode';

  @override
  String get importPeriodTemplateText => 'Importer periodeskabelon fra tekst';

  @override
  String get sharePeriodTemplate => 'Skabelon til andelsperiode';

  @override
  String get saveTemplateToFile => 'Gem skabelon til fil';

  @override
  String get exportPeriodTemplateText => 'Eksporter periode skabelon som tekst';

  @override
  String get deletePeriodTimeSet => 'Slet tidsindstillingen for perioden';

  @override
  String get periodTimeSetName => 'Periodens tidssæt navn';

  @override
  String get addOnePeriod => 'Tilføj periode';

  @override
  String periodNumberLabel(int index) {
    return 'Periode $index';
  }

  @override
  String get deleteThisPeriod => 'Slet denne periode';

  @override
  String durationMinutes(int minutes) {
    return 'Varighed $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Gap fra tidligere $minutes min';
  }

  @override
  String get endTimeMustBeLater => 'Sluttid skal være senere end starttid';

  @override
  String get periodOverlapPrevious => 'Denne periode overlapper den foregående';

  @override
  String get periodTimesSaved => 'Periodetider gemt';

  @override
  String get deletePeriodTimeSetTitle => 'Slet tidsindstillingen for perioden';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Slet \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'tidsindstilling for den aktuelle periode';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importeret $count periodetid';
  }

  @override
  String get periodFilePermissionTitle => 'Filtilladelse nødvendig';

  @override
  String get androidFilePermissionMessage =>
      'Android eksport kræver tilladelse til filadgang. Giv tilladelse til at fortsætte med at gemme.';

  @override
  String get reauthorize => 'Godkend igen';

  @override
  String get permissionPermanentlyDeniedTitle => 'Tilladelse nægtet permanent';

  @override
  String get permissionSettingsExportMessage =>
      'Aktiver filadgang i systemindstillingerne, vend derefter tilbage og prøv at eksportere igen.';

  @override
  String get privacyPolicyTitle => 'Privatlivspolitik';

  @override
  String get privacyPolicyEntryDesc =>
      'Lær, hvordan appen håndterer lokal lagring, konfiguration af skolens websted, import/eksport af filer, analysering af websider og eksterne links.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Accepteret version: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked er et lokalt-først skemaværktøj. Skemaer, tidssæt og skolewebstedskonfiguration gemmes kun på din enhed eller i din browser og uploades aldrig automatisk. Appen behandler kun data, når du udtrykkeligt starter handlinger som import, websideanalyse, deling eller åbning af eksterne links. Den fulde fortrolighedspolitik er tilgængelig online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokal opbevaring';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Import og eksport';

  @override
  String get privacyPolicyImportExportBody =>
      'Appen læser eller skriver kun tidsplan JSON-filer, skole-site JSON-filer og periode-skabelon-filer, når du udtrykkeligt vælger en fil eller starter en eksporthandling. Importering af disse filer er en lokal operation, medmindre du også vælger websideanalyse. Hent en brugerdefineret modelliste er også en eksplicit netværkshandling og kontakter kun det brugerdefinerede slutpunkt, du har konfigureret.';

  @override
  String get privacyPolicySharingTitle => 'Deling';

  @override
  String get privacyPolicySharingBody =>
      'Når du udtrykkeligt bruger deling, sender appen den eksporterede fil til systemdelingsarket eller til den målapp, du vælger. Hvordan filen håndteres bagefter afhænger af den målapp eller -tjeneste, du har valgt.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Eksterne links';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Når du åbner eksterne links som f.eks. GitHub-repositoriet, overfører appen handlingen til din browser eller et andet eksternt program. Databehandling efter dette punkt reguleres af den tredjepart, du åbner.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Hvad appen ikke indsamler';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Appen kræver ikke en Sked-konto og aktiverer ikke analyse, reklame-identifikatorer eller sikkerhedskopiering i skyen. Det giver heller ikke et dedikeret felt til indsamling af skolekonto adgangskoder. Hvis du logger på en skole hjemmeside i appen, sker denne interaktion på den skole side, du åbnede.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Analysering af websider';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Når du bruger import fra en skoles webside eller analyserer indsat skematext / HTML, forbereder og renser appen først indholdet lokalt og sender derefter den indsendte skematext, sidetekst eller HTML-indhold, valgfri sidetitel og URL, appens aktuelle sprog og parserens promptindhold til det OpenAI-kompatible endpoint, du har konfigureret. Hentning af modellisten bruger også det samme endpoint. Sked leverer ikke et indbygget parser-endpoint og sender ikke parserforespørgsler til en udviklerstyret skemaparser-backend. Det brugerdefinerede endpoint og eventuelle upstream-tjenester kan gemme, videresende, begrænse, slette eller på anden måde behandle data efter reglerne hos den tjenesteudbyder, du vælger. Hvis du bruger en http:// Base URL, bør den kun bruges på betroede enheder, netværk og endpoint-tjenester, fordi indhold og API-nøgler muligvis ikke er beskyttet af transportkryptering.';

  @override
  String get privacyPolicyUpdatesTitle => 'Opdateringer af politikken';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Den nuværende version af fortrolighedspolitikken er $version. Hvis en senere version ændrer, hvordan data håndteres, kan appen bede dig om at læse og acceptere den opdaterede politik igen.';
  }

  @override
  String get privacyGateTitle =>
      'Godkend venligst fortrolighedspolitikken før du bruger appen';

  @override
  String get privacyGateSummaryStorage =>
      'Tidsplaner, tidssæt og konfiguration af skolens websted gemmes kun lokalt og uploades ikke automatisk til en udviklerserver.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, eksport og deling sker kun, når du udtrykkeligt starter dem. Websideanalysering sender kun det komprimerede indhold, du sender til dit konfigurerede analyseringsendepunkt, og du kan gennemgå den analyserede tidsplan, før du gemmer den.';

  @override
  String get privacyGateSummaryUpdates =>
      'Hvis en senere version ændrer, hvordan data håndteres, kan appen bede dig om at gennemgå den opdaterede fortrolighedspolitik igen.';

  @override
  String get schoolWebImportEntry => 'Import fra skolens hjemmeside';

  @override
  String get schoolWebImportEntryDesc =>
      'Importer den aktuelle tidsplan side fra skolens websted.';

  @override
  String get schoolSitesManageEntry => 'Administrer skolens websteder';

  @override
  String get schoolSitesManageEntryDesc =>
      'Tilføj, rediger og slet skolens login-URL\'er med JSON-import og -eksport.';

  @override
  String get schoolSitesPageTitle => 'Skolen site management';

  @override
  String get schoolSitesImportJson => 'Importer skole JSON';

  @override
  String get schoolSitesShareJson => 'Del skolen JSON';

  @override
  String get schoolSitesSaveJson => 'Gem skolens JSON';

  @override
  String get schoolSitesSaved => 'Skolens hjemmesider gemt';

  @override
  String get schoolSitesImported => 'Skolepladser importeret';

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
  String get schoolSitesEmpty => 'Ingen skole websted konfiguration endnu.';

  @override
  String get schoolSitesNameLabel => 'Skolens navn';

  @override
  String get schoolSitesLoginUrlLabel => 'Indloggingsadresse';

  @override
  String get schoolSitesAdd => 'Tilføj skole';

  @override
  String get schoolSitesEdit => 'Rediger skole';

  @override
  String get schoolSitesDeleteTitle => 'Slet skole';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Slet \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Udfyld skolens navn og login URL først.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importer ved at indsætte tidsplan side indhold';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Indsæt kildekode eller rå sideindhold, der indeholder tidsplaneoplysninger manuelt.';

  @override
  String get schoolHtmlImportPageTitle => 'Analyser tidsplan fra sideindhold';

  @override
  String get schoolHtmlImportUrlLabel => 'Kilde URL (valgfrit)';

  @override
  String get schoolHtmlImportTitleLabel => 'Sidetitel (valgfrit)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Sideindhold';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Indsæt kildekode eller rå sideindhold, der indeholder tidsplan oplysninger her.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Alt indhold, der indeholder tidsplaneoplysninger, kan analyseres og importeres, ikke kun HTML.';

  @override
  String get schoolHtmlImportCompress => 'Forbered indhold';

  @override
  String get schoolHtmlImportCompressed => 'Indhold forberedt';

  @override
  String get schoolHtmlImportCompressFirst => 'Forbered indholdet først.';

  @override
  String get schoolHtmlImportSubmit => 'Analyser og importer';

  @override
  String get schoolImportContentTruncated =>
      'Denne side har nået den sikre importgrænse. Kun den registrerede del sendes til analyse.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsing kan tage et stykke tid. Vent venligst.';

  @override
  String get schoolHtmlImportEmpty => 'Indsæt HTML-siden først.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Tilbage til hjemmesiden';

  @override
  String get schoolWebImportPageTitle => 'Import af skolens webside';

  @override
  String get schoolWebImportPreview => 'Importer forhåndsvisning';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count kurser';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count perioder';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Sidetitel';

  @override
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importér noter';

  @override
  String get schoolWebImportParserDetails => 'Analyseringsdetaljer';

  @override
  String get schoolWebImportExpandParserDetails => 'Udvid analyseringsdetaljer';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Skjul analyseringsdetaljer';

  @override
  String get schoolWebImportOpenPageHint =>
      'Log på skolens websted i appen, og naviger derefter manuelt til tidsplanen.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Denne platform understøtter endnu ikke indlejret weblogin. Brug en platform med WebView-støtte.';

  @override
  String get schoolWebImportSelectSchool => 'Vælg skole';

  @override
  String get schoolWebImportNoSchools =>
      'Der er ingen skolekonfiguration tilgængelig. Tjek school_sites.json først.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Kunne ikke indlæse skolekonfiguration. Tjek JSON-filformatet.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importer nuværende side';

  @override
  String get schoolWebImportLoadingPage => 'Indlæser side…';

  @override
  String get schoolWebImportParsing => 'Parser den aktuelle side...';

  @override
  String get schoolWebImportLoadFailed =>
      'Indlæsning af siden mislykkedes. Opdater eller prøv igen senere.';

  @override
  String get schoolWebImportUnknownOrigin => 'Ukendt websted';

  @override
  String get schoolWebImportExitTitle => 'Forlad browseren?';

  @override
  String get schoolWebImportExitMessage =>
      'Siden lukkes. Alt, du endnu ikke har importeret, går tabt.';

  @override
  String get schoolWebImportExitConfirm => 'Forlad';

  @override
  String get schoolWebImportEmptyPage =>
      'Det aktuelle indhold er tomt og kan endnu ikke importeres.';

  @override
  String get schoolWebImportSuccess => 'Web tidsplan importeret';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Parser kilde';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Tilpasset OpenAI-kompatibel';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Tilpasset OpenAI-kompatibel parser';

  @override
  String get schoolImportParserCustomPromptTitle => 'Brugerdefineret prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Rediger den indbyggede parser prompt her. Ændringer påvirker kun den brugerdefinerede OpenAI-kompatible parser.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Den indbyggede prompt indlæses her som standard. Tøm den for at falde tilbage til den indbyggede version.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Nulstil standardprompt';

  @override
  String get schoolImportParserBaseUrl => 'Baseadresse';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL skal være en HTTP- eller HTTPS-adresse med en vært.';

  @override
  String get schoolImportParserApiKey => 'API-nøgle';

  @override
  String get schoolImportParserModel => 'Modell';

  @override
  String get schoolImportParserFetchModels => 'Hent modelliste';

  @override
  String get schoolImportParserFetchingModels => 'Henter modeller. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Ingen modeller blev returneret ved slutpunktet.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Modellerne kunne ikke hentes. Kontrollér slutpunktet, og prøv igen.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Hentet $count modeller';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Vil du bruge et ukrypteret HTTP-slutpunkt?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API-nøglen og skemaindholdet kan blive læst eller ændret under overførslen. Fortsæt kun, hvis du har tillid til denne enhed, dette netværk og slutpunktet. Godkendelsen gælder, indtil du lukker Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Tilpasset parser konfiguration er ufuldstændig. Udfyld grundlæggende URL, API-nøgle og model først.';

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
    return 'Parser: Brugerdefineret ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Se fuld fortrolighedspolitik';

  @override
  String get privacyAgreeAndContinue => 'Enig og fortsæt';

  @override
  String get privacyDecline => 'Afsæt';

  @override
  String get privacyDeclineWebHint =>
      'Dette browsermiljø tillader ikke, at appen lukker siden for dig. Hvis du ikke er enig, luk venligst denne fane eller vinduet selv.';

  @override
  String get defaultPeriodTimeSetName => 'Standardperioder';

  @override
  String get periodTimeSetFallbackName => 'Periodetider';

  @override
  String get untitledTimetableName => 'Tidsplan uden titel';

  @override
  String get newTimetableName => 'Ny tidsplan';

  @override
  String get newPeriodTimeSetName => 'Ny periode tidsindstilling';

  @override
  String get emptyTimetableName => 'Tomme tidsplaner';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name perioder';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Import filtype stemmer ikke overens.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Denne importfilversion understøttes endnu ikke.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Ingen periodetider fundet i importfilen.';

  @override
  String get selectAtLeastOneTimetableMessage => 'Vælg mindst én tidsplan.';

  @override
  String get noExportableTimetableMessage =>
      'Der er ingen tidsplan til eksport.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Erstatning af den aktuelle tidsplan understøtter kun at vælge en tidsplan.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Der er ingen tidsplan til udskiftning.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Dette tidssæt anvendes stadig af $count tidsplan(er). Tildele dem igen, før de slettes.';
  }

  @override
  String get weekdayMonday => 'Mandag';

  @override
  String get weekdayTuesday => 'Tirsdag';

  @override
  String get weekdayWednesday => 'Onsdag';

  @override
  String get weekdayThursday => 'Torsdag';

  @override
  String get weekdayFriday => 'Fredag';

  @override
  String get weekdaySaturday => 'Lørdag';

  @override
  String get weekdaySunday => 'Søndag';

  @override
  String get weekdayShortMonday => 'mandag';

  @override
  String get weekdayShortTuesday => 'tirsdag';

  @override
  String get weekdayShortWednesday => 'Onsdag';

  @override
  String get weekdayShortThursday => 'torsdag';

  @override
  String get weekdayShortFriday => 'fredag';

  @override
  String get weekdayShortSaturday => 'Lørdag';

  @override
  String get weekdayShortSunday => 'Solen';

  @override
  String get monthJanuary => 'januar';

  @override
  String get monthFebruary => 'februar';

  @override
  String get monthMarch => 'marts';

  @override
  String get monthApril => 'Apr';

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
  String get semesterWeeksWholeTerm => 'Hele semestret';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Uger $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Uger $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Vælg starttilstand';

  @override
  String get firstLaunchSubtitle =>
      'Vælg det arbejdsområde, du bruger mest. Du kan skifte tilstand senere.';

  @override
  String get firstLaunchStudentDesc =>
      'Administrer skemaer, kurser, uger, lektionstider og importer.';

  @override
  String get firstLaunchGeneralDesc =>
      'Administrer kategorier, begivenheder, påmindelser og JSON / ICS-data.';

  @override
  String get firstLaunchStartStudent => 'Start med skema';

  @override
  String get firstLaunchStartGeneral => 'Start med plan';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Ved at vælge et startarbejdsområde bekræfter du, at du har læst og accepterer ';

  @override
  String get firstLaunchPrivacyConsentLink => 'privatlivspolitikken';

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
      'Visninger, værktøjslinje, datoformat og hurtig tilføjelse';

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
  String get viewWeek => 'Uge';

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
  String get developerModeTitle => 'Udviklertilstand';

  @override
  String get developerModeDescription =>
      'Værktøjer til at tilføje komplette eksempeldata til kontrol af udseende og interaktion.';

  @override
  String get developerSampleLanguage => 'Sprog for eksempeldata';

  @override
  String get developerSampleChinese => 'Kinesisk';

  @override
  String get developerSampleEnglish => 'Engelsk';

  @override
  String get developerSampleDataDescription =>
      'Tilføjer et skema og et sæt kategorier og begivenheder uden at erstatte eksisterende data.';

  @override
  String get developerAddSampleData => 'Tilføj eksempeldata';

  @override
  String get developerSampleDataAdded =>
      'Eksempelskema og kalenderdata er tilføjet.';

  @override
  String get developerModeLongPressHint =>
      'Hold nede i 3 sekunder for at åbne udviklertilstand';

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
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending pending / $active active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'native last posted $time';
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
  String get developerNotificationWindowsPermissionManaged =>
      'Managed by Windows notification settings';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Not applicable on Windows';

  @override
  String get developerNotificationWindowsIdentity => 'Windows package identity';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX identity available; active cards can be cancelled';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Install the MSIX build to cancel active cards reliably';

  @override
  String get collapseWorkspaceNavigation =>
      'Fold arbejdsområdenavigation sammen';

  @override
  String get expandWorkspaceNavigation => 'Udvid arbejdsområdenavigation';

  @override
  String get schoolWebImportExitBrowser => 'Afslut indbygget browser';

  @override
  String get schoolWebImportEditAddress => 'Rediger adresse';

  @override
  String get schoolWebImportAddressLabel => 'Webadresse';

  @override
  String get schoolWebImportOpenAddress => 'Åbn';

  @override
  String get schoolWebImportAddressInvalid =>
      'Indtast en HTTP- eller HTTPS-adresse med en vært.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Denne webside anmodede om et nyt vindue, som ikke kan åbnes på denne enhed.';

  @override
  String get schoolWebImportSecureConnection => 'Sikker forbindelse';

  @override
  String get schoolWebImportInsecureConnection => 'Usikker forbindelse';

  @override
  String get schoolWebImportSignInConsentTitle => 'Åbn skolens login?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Skolens login kan sende legitimationsoplysninger via formularer eller serveromdirigeringer til skolen og dens loginudbydere. Android kan ikke sætte hver sådan overførsel på pause for at vise en særskilt destinationsbekræftelse. Fortsæt kun, hvis du har tillid til dem i denne importsession:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Åbn et usikkert skolelogin?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Dette skolelogin bruger HTTP. Enhver, der kan overvåge eller ændre forbindelsen, kan læse eller ændre dine loginoplysninger og sidens indhold. Fortsæt kun, hvis du accepterer denne risiko for:\n\n$origin';
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
