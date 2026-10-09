// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class AppLocalizationsDa extends AppLocalizations {
  AppLocalizationsDa([String locale = 'da']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle => 'Rediger analyseresultat';

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
  String get schoolImportExpandWarnings => 'Vis importadvarsler';

  @override
  String get schoolImportCollapseWarnings => 'Skjul importadvarsler';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Nogle kurser fortsætter til uge $week.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Erstat det aktuelle skema?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Det importerede skema erstatter det aktuelle skema.';

  @override
  String get createTimetable => 'Ny tidsplan';

  @override
  String get jumpToWeek => 'Hop til ugen';

  @override
  String get timetable => 'Tidsplan';

  @override
  String get themeWorkspaceSchedule => 'Tidsplan';

  @override
  String get timetableName => 'Navn på tidsplan';

  @override
  String get timetableNameRequired => 'Angiv et navn til skemaet';

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
  String get customFieldsInvalidJson =>
      'Angiv et gyldigt JSON-objekt, eller ryd feltet.';

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
  String get settingsSectionTimetable => 'Skema';

  @override
  String get settingsSectionGeneralSchedule => 'Generel tidsplan';

  @override
  String get settingsSectionAppearance => 'Udseende';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionWorkspace => 'Arbejdsområde';

  @override
  String get settingsSectionAppearanceLanguage => 'Udseende og sprog';

  @override
  String get settingsSectionDataSecurity => 'Data og sikkerhed';

  @override
  String get settingsSectionAbout => 'Om Sked';

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
  String get timetableHorizontalLayoutSection => 'Vandret layout og bevægelser';

  @override
  String get fitDaySelectorToWidth => 'Tilpas dagvælgeren til skærmen';

  @override
  String get fitDaySelectorToWidthHint =>
      'Vis alle syv dage på skærmen, når det er muligt. Slå fra for at bruge fast bredde og rulning.';

  @override
  String get fitWeekColumnsToWidth => 'Tilpas ugekolonnerne til skærmen';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Vis alle syv skemakolonner på skærmen, når det er muligt. Slå fra for at bruge fast bredde og rulning.';

  @override
  String get enableWeekSwipeNavigation => 'Skift uge ved at stryge';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Stryg til venstre eller højre for at gå til en anden uge. Ved fast bredde skal du først rulle ud til kanten.';

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
  String get microsoftStoreUpdates =>
      'Opdateringer administreres af Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Modtag foreløbige opdateringer';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Medtag Alpha-, Beta- og RC-versioner, som kan være ustabile. Når slået fra, tilbydes kun stabile versioner.';

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
      'Den nyeste version kunne ikke hentes fra GitHub. Du kan stadig åbne GitHub Releases nedenfor.';

  @override
  String get githubRepository => 'GitHub-lager';

  @override
  String get googlePlayStoreDesc => 'Se Sked på Google Play';

  @override
  String get openGooglePlayFailed => 'Kunne ikke åbne Google Play';

  @override
  String get starSkedOnGithub => 'Giv Sked en stjerne på GitHub!';

  @override
  String get starSkedOnGithubDesc =>
      'Åbn projektets repository, og giv Sked en stjerne';

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
  String get importAction => 'Importér';

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
  String get periodTimesUnsavedExitTitle => 'Ændringerne er ikke gemt';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'De seneste ændringer af lektionstiderne kunne ikke gemmes. Du kan prøve igen, fortsætte med at redigere eller kassere ændringerne.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Nogle lektionstider er ugyldige. Ret dem før du gemmer, eller kassér ændringerne og forlad siden.';

  @override
  String get discardChangesAndExit => 'Kassér og afslut';

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
      'På native platforme gemmer Sked skemaer, generelle tidsplaner, tilhørende indstillinger og redigerbar konfiguration af skolesider i operativsystemets mappe til appdata. Browserversioner bruger browserens lager. Filer, som ældre versioner har skrevet til brugerens Dokumenter-mappe, bliver liggende, men læses eller overføres ikke automatisk. Hvis du vil beholde disse data, skal du eksportere en fuld sikkerhedskopi fra den gamle version før opdateringen og gendanne den bagefter. AI API-indstillinger gemmes lokalt. Den brugerdefinerede API-nøgle gemmes via platformens sikre lager, når det er tilgængeligt. Fuldstændige sikkerhedskopier indeholder ikke den brugerdefinerede API-nøgle. Appen uploader ikke automatisk disse lokale data til en server, som udvikleren styrer.';

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
  String get schoolSitesImportPreviewTitle => 'Gennemgå import af skolesider';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount gyldige sider, $invalidCount ugyldige poster.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Filen indeholder en tom liste over skolesider.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Post $position er ugyldig og springes over.';
  }

  @override
  String get schoolSitesImportMerge => 'Flet';

  @override
  String get schoolSitesImportReplace => 'Erstat';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Erstat de aktuelle skolesider?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Dette fjerner de $currentCount aktuelle sider og gemmer $importedCount importerede sider. Det kan ikke fortrydes.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Data for skolesider skal gendannes';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked kunne hverken læse filen med skolesider eller dens sikkerhedskopi. Beskyttede kopier blev oprettet, før skrivning blev blokeret.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Lageret for skolesider er utilgængeligt';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked kan ikke få adgang til lageret for skolesider lige nu. Kontrollér adgang til lageret eller enhedens tilgængelighed, og prøv igen. De nuværende data overskrives ikke.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Gendannelsesfiler eller berørte lagerplaceringer vises nedenfor. Lad filerne være uændrede, indtil listen over sider er gendannet.';

  @override
  String get schoolSitesRecoveryStartFreshAction => 'Start uden skolesider';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Start med en tom liste over skolesider?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'De beskyttede kopier bevares, men Sked opretter en ny tom fil med skolesider. Fortsæt kun, hvis du ikke vil forsøge at gendanne først.';

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
      'Konfigurationen af den brugerdefinerede parser er ufuldstændig. Udfyld først basis-URL, API-nøgle og model.';

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
  String get schoolImportParserSettingsTitle => 'API til skemaimport';

  @override
  String get schoolImportParserSettingsDesc =>
      'Konfigurer den OpenAI-kompatible API til import af skemaer, ikke en chatassistent.';

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
      'Den brugerdefinerede API-nøgle gemmes via platformens sikre lager, når det er tilgængeligt. Brug kun parserens adgangsoplysninger og HTTP-adresser på enheder, i browsere og på netværk, du har tillid til.';

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
  String get clearAppData => 'Ryd data';

  @override
  String get clearAppDataDesc =>
      'Slet alle lokale Sked-data permanent, og afslut appen';

  @override
  String get clearAppDataConfirmTitle => 'Ryd alle Sked-data?';

  @override
  String get clearAppDataConfirmMessage =>
      'Dette sletter skemaer, tidsplaner, indstillinger, skolesider, lokale sikkerhedskopier, gendannelseskopier og AI API-nøglen permanent og afslutter derefter Sked. Filer, du har eksporteret andre steder, slettes ikke. Det kan ikke fortrydes.';

  @override
  String get clearAppDataAction => 'Ryd data og afslut';

  @override
  String get clearAppDataFailed =>
      'Kunne ikke rydde alle lokale data. Sked forbliver åben, så du kan prøve igen.';

  @override
  String get clearAppDataExitFailed =>
      'Dine lokale data blev ryddet, men Sked kunne ikke afsluttes. Luk appen manuelt, før du bruger den igen.';

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
  String get monthDecember => 'december';

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
  String get generalSchedule => 'Generel tidsplan';

  @override
  String get studentTimetable => 'Studieskema';

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
  String get switchMode => 'Skift tilstand';

  @override
  String get generalScheduleComingSoon => 'Generel tidsplan kommer snart';

  @override
  String get switchToStudentTimetable => 'Skift til studieskema';

  @override
  String get mySchedule => 'Min tidsplan';

  @override
  String get today => 'I dag';

  @override
  String get addEvent => 'Tilføj begivenhed';

  @override
  String get editEvent => 'Rediger begivenhed';

  @override
  String get eventTitle => 'Titel';

  @override
  String get eventTitleRequired => 'Angiv en titel';

  @override
  String get eventStartTime => 'Starttid';

  @override
  String get eventEndTime => 'Sluttid';

  @override
  String get eventDate => 'Dato';

  @override
  String get eventTime => 'Tid';

  @override
  String get eventNotes => 'Noter';

  @override
  String get eventColor => 'Farve';

  @override
  String get eventRecurrence => 'Gentagelse';

  @override
  String get recurrenceNone => 'Gentages ikke';

  @override
  String get recurrenceWeekly => 'Ugentligt';

  @override
  String get recurrenceEndDate => 'Slutdato';

  @override
  String get recurrenceNoEndDate => 'Ingen slutdato';

  @override
  String get recurrenceSetEndDate => 'Indstil';

  @override
  String get recurrenceChangeEndDate => 'Skift';

  @override
  String get repeatsWeekly => 'Gentages ugentligt';

  @override
  String recurrenceUntil(Object date) {
    return 'Indtil $date';
  }

  @override
  String get switchToGeneralSchedule => 'Skift til generel tidsplan';

  @override
  String get generalDisplaySettings => 'Indstillinger for visning af tidsplan';

  @override
  String get generalDisplaySettingsDesc =>
      'Visninger, værktøjslinje, datoformat og hurtig tilføjelse';

  @override
  String get closePopupOnOutsideTap => 'Luk pop op-vinduet ved tryk udenfor';

  @override
  String get showGridLines => 'Vis gitterlinjer';

  @override
  String get generalScheduleImportExport => 'Import og eksport af kategorier';

  @override
  String get generalScheduleImportExportDesc =>
      'Importér eller del kategorier fra tidsplanen';

  @override
  String get importGeneralSchedules => 'Importér kategorier';

  @override
  String get importGeneralSchedulesDesc => 'Læs kategorier fra en JSON-fil';

  @override
  String get shareGeneralSchedules => 'Del kategorier';

  @override
  String get shareGeneralSchedulesDesc => 'Del kategorier som en JSON-fil';

  @override
  String get saveGeneralSchedules => 'Gem kategorier';

  @override
  String get saveGeneralSchedulesDesc => 'Gem kategorier som en JSON-fil';

  @override
  String get selectSchedulesToExport => 'Vælg kategorier til eksport';

  @override
  String get selectSchedulesToImport => 'Vælg kategorier til import';

  @override
  String generalScheduleEventCount(int count) {
    return 'Begivenheder: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Importerede $count kategorier';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Tilføj som en ny kategori, eller erstat en eksisterende kategori?';

  @override
  String get addAsNewSchedule => 'Tilføj som ny kategori';

  @override
  String get selectAtLeastOneScheduleMessage => 'Vælg mindst én kategori.';

  @override
  String get noExportableScheduleMessage =>
      'Der er ingen kategori at eksportere.';

  @override
  String get noSchedulesInImportMessage =>
      'Importfilen indeholder ingen kategorier.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Vælg præcis én importeret kategori til erstatning.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Den valgte kategori, der skal erstattes, er utilgængelig.';

  @override
  String get calendars => 'Kategorier';

  @override
  String get calendar => 'Kategori';

  @override
  String get viewWeek => 'Uge';

  @override
  String get viewDay => 'Dag';

  @override
  String get viewList => 'Liste';

  @override
  String get viewMonth => 'Måned';

  @override
  String visibleCategoryCount(int count) {
    return '$count kategorier';
  }

  @override
  String get noVisibleCategories => 'Ingen synlige kategorier';

  @override
  String get selectCategoryToReplace => 'Vælg kategori, der skal erstattes';

  @override
  String get replaceCategory => 'Erstat kategori';

  @override
  String get deleteEventTitle => 'Slet begivenhed';

  @override
  String get deleteEventConfirmation => 'Denne begivenhed slettes permanent.';

  @override
  String get deleteRecurringEventTitle => 'Slet gentagen begivenhed';

  @override
  String get eventDuplicated => 'Begivenheden er duplikeret';

  @override
  String get searchEvents => 'Søg efter begivenheder';

  @override
  String get clearSearch => 'Ryd søgning';

  @override
  String get filterByColor => 'Filtrér efter farve';

  @override
  String get allColors => 'Alle farver';

  @override
  String upcomingEventsCount(int count) {
    return 'Kommende: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Forbi sluttid: $count';
  }

  @override
  String get allDay => 'Hele dagen';

  @override
  String get collapseAllDayTimeline => 'Skjul heldagsbegivenheder';

  @override
  String get expandAllDayTimeline => 'Vis heldagsbegivenheder';

  @override
  String allDayEventsCount(int count) {
    return '$count heldagsbegivenheder';
  }

  @override
  String moreEvents(int count) {
    return '+$count flere';
  }

  @override
  String get noMatchingEvents => 'Ingen matchende begivenheder';

  @override
  String get noUpcomingEvents => 'Ingen kommende begivenheder';

  @override
  String get addCalendar => 'Tilføj kategori';

  @override
  String get newCalendar => 'Ny kategori';

  @override
  String get hideCalendar => 'Skjul kategori';

  @override
  String get showCalendar => 'Vis kategori';

  @override
  String get rename => 'Omdøb';

  @override
  String get renameCalendar => 'Omdøb kategori';

  @override
  String get name => 'Navn';

  @override
  String get deleteCalendar => 'Slet kategori';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Slet \"$name\"?';
  }

  @override
  String get deleteThisOccurrence => 'Slet kun denne forekomst';

  @override
  String get deleteFutureOccurrences => 'Slet denne og fremtidige forekomster';

  @override
  String get deleteAllOccurrences => 'Slet hele serien';

  @override
  String get duplicateEvent => 'Duplikér';

  @override
  String get repeatsDaily => 'Gentages dagligt';

  @override
  String get repeatsMonthly => 'Gentages månedligt';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Gentages med intervallet $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count gange';
  }

  @override
  String get recurrenceDaily => 'Dagligt';

  @override
  String get recurrenceMonthly => 'Månedligt';

  @override
  String get recurrenceCustom => 'Brugerdefineret';

  @override
  String get recurrenceEvery => 'Interval';

  @override
  String get recurrenceUnit => 'Enhed';

  @override
  String get recurrenceDays => 'dage';

  @override
  String get recurrenceWeeks => 'uger';

  @override
  String get recurrenceMonths => 'måneder';

  @override
  String get recurrenceRepeatCount => 'Antal gentagelser';

  @override
  String get recurrenceNoLimit => 'Ingen grænse';

  @override
  String get recurrencePositiveNumber => 'Angiv et positivt tal';

  @override
  String get clearEndDate => 'Ryd slutdato';

  @override
  String get pickDate => 'Vælg dato';

  @override
  String get pickTime => 'Vælg tidspunkt';

  @override
  String get reminder => 'Påmindelse i appen';

  @override
  String get reminderAtStart => 'Ved start';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min før';
  }

  @override
  String get reminderHourBefore => '1 time før';

  @override
  String get reminderDayBefore => '1 dag før';

  @override
  String get markReminderHandled => 'Markér som håndteret';

  @override
  String get restoreReminder => 'Gendan påmindelse i appen';

  @override
  String get reminderHandled => 'Påmindelsen i appen er markeret som håndteret';

  @override
  String get reminderRestored => 'Påmindelsen i appen er gendannet';

  @override
  String get reminderUpcoming => 'Kommende';

  @override
  String get reminderOverdue => 'Forbi sluttid';

  @override
  String get generalFitWeekColumnsToWidth => 'Tilpas ugevisning til skærmen';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Vis hele ugen i kompakte layouts. Slå fra for vandret rulning. Selvvalgte intervaller over 7 dage ruller stadig.';

  @override
  String get showWeekends => 'Vis weekender';

  @override
  String get startHour => 'Vis fra klokken';

  @override
  String get endHour => 'Vis til klokken';

  @override
  String get timeGridDensity => 'Tidsgitterets interval';

  @override
  String get timeGridHourHeight => 'Højde pr. time';

  @override
  String get timeGridHourHeightHint =>
      'Justerer den lodrette skala i dags- og ugevisning uden at ændre gitterintervallet på 15, 30 eller 60 minutter.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importér JSON-fil';

  @override
  String get pasteJson => 'Indsæt JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importér kategorier fra kopieret JSON';

  @override
  String get importIcsFile => 'Importér ICS-fil';

  @override
  String get importIcsFileDesc => 'Læs begivenheder fra en .ics-kalenderfil';

  @override
  String get pasteIcs => 'Indsæt ICS';

  @override
  String get pasteIcsDesc => 'Importér begivenheder fra kopieret kalendertekst';

  @override
  String get copyJson => 'Kopiér JSON';

  @override
  String get copyJsonDesc => 'Kopiér valgte kategorier som JSON-tekst';

  @override
  String get shareIcs => 'Del ICS';

  @override
  String get shareIcsDesc => 'Del valgte kalendere som .ics';

  @override
  String get saveIcs => 'Gem ICS';

  @override
  String get saveIcsDesc => 'Gem valgte kalendere som .ics';

  @override
  String get copyIcs => 'Kopiér ICS';

  @override
  String get copyIcsDesc => 'Kopiér valgte kalendere som ICS-tekst';

  @override
  String get importIcs => 'Importér ICS';

  @override
  String get icsContent => 'ICS-indhold';

  @override
  String get pasteIcsContentHint =>
      'Indsæt indhold, der begynder med BEGIN:VCALENDAR, her';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Fandt $count begivenheder. Tilføj dem som en ny kategori, eller erstat en eksisterende?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Importerede $count kategorier med $warningCount advarsler';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Sprang en begivenhed uden starttid over.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Sprang en begivenhed med en ikke-understøttet starttid over.';

  @override
  String get importWarningAdjustedEnd =>
      'Justerede en sluttid, der ikke lå efter starttiden.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Ikke-understøttede ICS-felter blev føjet til noter: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Ignorerede en ikke-understøttet gentagelsesfrekvens: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Vælg kalendere, der skal kopieres som ICS';

  @override
  String get selectCalendarsToExportIcs => 'Vælg kalendere til eksport som ICS';

  @override
  String get exportIcsText => 'Eksportér ICS-tekst';

  @override
  String get exportJsonText => 'Eksportér JSON-tekst';

  @override
  String get dataRestoredFromBackupNotice =>
      'Appdata blev gendannet fra den tidligere sikkerhedskopi, fordi hovedfilen ikke kunne indlæses.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Både hovedfilen og dens sikkerhedskopi er beskadiget. Appen bruger nu en ny starttilstand.';

  @override
  String get dataRecoveryCorruptTitle => 'Dine data skal gendannes';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked kunne hverken læse hovedfilen eller dens sikkerhedskopi. Beskyttede kopier blev oprettet, før skrivning blev blokeret.';

  @override
  String get dataRecoveryIoFailureTitle => 'Lageret er utilgængeligt';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked kan ikke få adgang til det lokale lager lige nu. Kontrollér adgang til lageret eller enhedens tilgængelighed, og prøv igen. Eksisterende data overskrives ikke.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Opdatér Sked for at åbne disse data';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Disse data blev oprettet med en nyere version af Sked. Opdatér appen, før du prøver igen. Det er ikke muligt at starte forfra, da dataene skal beskyttes.';

  @override
  String get dataRecoveryRetryAction => 'Prøv igen';

  @override
  String get dataRecoveryArtifactsHint =>
      'Gendannelsesfiler eller berørte lagerplaceringer vises nedenfor. Lad filerne være uændrede, indtil dine data er gendannet.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Vis gendannelsesfiler og placeringer';

  @override
  String get dataRecoveryStartFreshAction => 'Start med nye data';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Start med nye data?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'De beskyttede kopier bevares, men Sked opretter en ny lokal datafil. Fortsæt kun, hvis du ikke vil forsøge at gendanne først.';

  @override
  String get previousMonth => 'Forrige måned';

  @override
  String get nextMonth => 'Næste måned';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'I gang';

  @override
  String get deleteCourseTitle => 'Slet kursus';

  @override
  String get deleteCourseMessage => 'Slet dette kursus?';

  @override
  String get showLunarCalendar => 'Vis månekalender';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count begivenheder';
  }

  @override
  String get defaultView => 'Standardvisning';

  @override
  String get generalDefaultViewSection => 'Ved opstart';

  @override
  String get generalViewSwitchBehavior => 'Knap til at skifte visning';

  @override
  String get settingsWorkspaceMode => 'Aktivt arbejdsområde';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Skjul navigation mellem arbejdsområder';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Skjul navigationen mellem arbejdsområder. Du kan stadig skifte i arbejdsområdemenuen på hovedskærmen.';

  @override
  String get generalDateLabelFormat => 'Format for datomærkat';

  @override
  String get generalDateLabelFormatLocalized => 'Lokalt format (jul. 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Med skråstreg (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Værktøjslinjens layout';

  @override
  String get toolbarNavigationSection => 'Navigation på værktøjslinjen';

  @override
  String get toolbarNavigationHiddenBehavior => 'Skjulte elementer';

  @override
  String get toolbarNavigationRemove => 'Skjul helt';

  @override
  String get toolbarNavigationMore => 'Flyt til Mere';

  @override
  String get toolbarNavigationReorder => 'Omarrangér værktøjslinjens elementer';

  @override
  String get toolbarNavigationVisibility => 'Vis element på værktøjslinjen';

  @override
  String get toolbarNavigationTimetable => 'Skemavælger';

  @override
  String get toolbarNavigationWeek => 'Ugevælger';

  @override
  String get toolbarNavigationView => 'Visningsvælger';

  @override
  String get toolbarNavigationCategory => 'Kategorivælger';

  @override
  String get toolbarNavigationDate => 'Datovælger';

  @override
  String get generalToolbarWidthPolicy => 'Pladsfordeling på værktøjslinjen';

  @override
  String get generalToolbarWidthContent => 'Automatisk fordeling';

  @override
  String get generalToolbarWidthBalanced => 'Balanceret';

  @override
  String get generalToolbarWidthCalendarPriority => 'Kategori prioriteres';

  @override
  String get generalToolbarWidthDatePriority => 'Dato prioriteres';

  @override
  String get generalViewSwitchCycle => 'Skift gennem visningerne';

  @override
  String get generalViewSwitchMenu => 'Åbn visningsmenu';

  @override
  String get generalViewSwitchTooltip => 'Skift visning';

  @override
  String get generalViewSwitchMenuTooltip => 'Vælg visning';

  @override
  String get generalViewLongPressTodayHint => 'Hold nede for at gå til i dag';

  @override
  String get generalScheduleDisplaySection => 'Visning af tidsplan';

  @override
  String get generalTimeGridSection => 'Tidsgitter';

  @override
  String get generalPopupSection => 'Pop op-vinduers adfærd';

  @override
  String get quickActionsSection => 'Hurtige handlinger';

  @override
  String get showAddCourseFab => 'Vis flydende knap til at tilføje kursus';

  @override
  String get showAddCourseFabHint =>
      'Vis eller skjul den flydende knap til at tilføje kurser nederst til højre i skemaet.';

  @override
  String get showAddEventFab => 'Vis flydende knap til at tilføje begivenhed';

  @override
  String get showAddEventFabHint =>
      'Vis eller skjul den flydende knap til at tilføje begivenheder nederst til højre i tidsplanen.';

  @override
  String get enableLongPressAddCourse =>
      'Hold på tomt gitter for at tilføje kurser';

  @override
  String get enableLongPressAddCourseHint =>
      'Tryk og hold på et tomt område i skemagitteret for at tilføje et kursus.';

  @override
  String get enableLongPressAddEvent =>
      'Hold på tomt gitter for at tilføje begivenheder';

  @override
  String get enableLongPressAddEventHint =>
      'Tryk og hold på et tomt område af tidsgitteret i dags- eller ugevisning for at tilføje en begivenhed.';

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
  String get developerNotificationDiagnostics => 'Notifikationsdiagnostik';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Undersøg leveringstilstanden i Android, genopbyg den eksisterende påmindelsesplan, og send sikre testnotifikationer gennem Skeds normale notifikationstjeneste.';

  @override
  String get developerNotificationUnsupported =>
      'Notifikationsdiagnostik er kun tilgængelig på Android.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Notifikationsdiagnostik er utilgængelig, indtil notifikationskoordinatoren starter.';

  @override
  String get developerNotificationRefresh => 'Opdatér diagnostik';

  @override
  String get developerNotificationSystemStatus =>
      'Systemtilladelse til notifikationer';

  @override
  String get developerNotificationPermissionAllowed => 'Tilladt';

  @override
  String get developerNotificationPermissionBlocked => 'Blokeret';

  @override
  String get developerNotificationExactAlarm => 'Præcise alarmer';

  @override
  String get developerNotificationExactAlarmAllowed => 'Tilladt';

  @override
  String get developerNotificationExactAlarmBlocked => 'Ikke tilladt';

  @override
  String get developerNotificationPlan => 'Plan for kalendernotifikationer';

  @override
  String get developerNotificationCoverage => 'Dækning';

  @override
  String get developerNotificationCoverageReady =>
      'Alle kendte påmindelser med et endeligt antal gentagelser er planlagt direkte';

  @override
  String get developerNotificationCoverageRenewable =>
      'Gentagne påmindelser fornyes langsigtet, så vidt systemet tillader det';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Kapaciteten for direkte alarmer er fuld; senere påmindelser fornyes, så vidt systemet tillader det';

  @override
  String get developerNotificationCoverageBlocked =>
      'Kravene til præcis levering er ikke opfyldt';

  @override
  String get developerNotificationCoverageFailed =>
      'Den seneste synkronisering af påmindelser mislykkedes';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled direkte alarmer / kapacitet $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled lagt i kø, $planned planlagt';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Seneste fejl: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Genopbyg notifikationsplan';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Notifikationsplanen er genopbygget.';

  @override
  String get developerNotificationTestChannel => 'Testkanal';

  @override
  String get developerNotificationTestCourse => 'Kursuspåmindelser';

  @override
  String get developerNotificationTestSchedule => 'Påmindelser om begivenheder';

  @override
  String get developerNotificationImmediateTest => 'Send test med det samme';

  @override
  String get developerNotificationThirtySecondTest =>
      'Planlæg baggrundstest om 30 sekunder';

  @override
  String get developerNotificationImmediateQueued =>
      'Testnotifikation sendt med det samme.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Baggrundstesten er planlagt om 30 sekunder.';

  @override
  String get developerNotificationAppSwitch => 'Appens påmindelseskontakt';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Almindelige påmindelser er slået til';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Almindelige påmindelser er slået fra; udviklertests kan stadig køres';

  @override
  String get developerNotificationTimeZone => 'Lokal tidszone';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Ikke oprettet endnu. En udviklertest opretter den.';

  @override
  String get developerNotificationChannelEnabledState => 'Aktiveret';

  @override
  String get developerNotificationChannelBlockedState => 'Blokeret';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Vigtighed: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Vigtighed er utilgængelig';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending afventer / $active aktive';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Senest vist af systemet: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Ingen genberegning er registreret endnu.';

  @override
  String get developerNotificationNextReminder => 'Næste rigtige påmindelse';

  @override
  String get developerNotificationNoPendingReminder =>
      'Ingen fremtidig påmindelse i den aktuelle plan';

  @override
  String get developerNotificationNextMaintenance => 'Næste vedligeholdelse';

  @override
  String get developerNotificationNextRenewal => 'Næste forsøg på fornyelse';

  @override
  String get developerNotificationNoMaintenance => 'Ikke planlagt';

  @override
  String get developerNotificationTruncation => 'Afkortning af planen';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count udeladt på grund af planens grænse';
  }

  @override
  String get developerNotificationLastReconciliation => 'Seneste genberegning';

  @override
  String get developerNotificationLastSynchronization =>
      'Seneste synkronisering af påmindelser';

  @override
  String get developerNotificationLateRecovery =>
      'Gendannelse af forsinkede påmindelser';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count påmindelser blev gendannet efter deres oprindelige tidspunkt';
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
  String get developerNotificationReconcileOriginForeground => 'Forgrund';

  @override
  String get developerNotificationReconcileOriginBackground => 'Baggrund';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Fuld genberegning';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Vedligeholdelse';

  @override
  String get developerNotificationReconcileModeRecovery => 'Gendannelse';

  @override
  String get developerNotificationRunRecovery =>
      'Kør gendannelse af påmindelser';

  @override
  String get developerNotificationRecoveryComplete =>
      'Gendannelsen af påmindelser er fuldført';

  @override
  String get developerNotificationReconcileResultSuccess => 'Lykkedes';

  @override
  String get developerNotificationReconcileResultSkipped => 'Sprunget over';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Blokeret, indtil alle krav til præcis levering er opfyldt';

  @override
  String get developerNotificationReconcileResultFailed => 'Mislykkedes';

  @override
  String get developerNotificationBackgroundLimits =>
      'Producentens baggrundsbegrænsninger';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Producentens baggrundsbegrænsninger kan påvirke leveringen.';

  @override
  String get developerNotificationAutostart => 'Producentens baggrundsstart';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Producent: $vendor. Der findes en genvej til producentens indstillinger. Android kan ikke vise, om tilladelsen er givet.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Producent: $vendor. Appoplysninger bruges som alternativ. Android kan ikke vise, om tilladelsen er givet.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Der er ingen tilgængelig genvej til producentens baggrundsindstillinger.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Senest åbnede mål: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'producentindstillinger';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'appoplysninger';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'ingen';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Grænser for gendannelse efter genstart';

  @override
  String get developerNotificationRebootBoundary =>
      'Gendannelse begynder efter den første oplåsning. En app, der er tvangsstandset, kan ikke starte sig selv.';

  @override
  String get developerNotificationTestChecking =>
      'Tests er utilgængelige, mens notifikationsstatus kontrolleres.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Tests er utilgængelige, fordi systemnotifikationer er blokeret.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Tests er utilgængelige, fordi den valgte notifikationskanal er blokeret.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Styres af Windows\' notifikationsindstillinger';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Ikke relevant på Windows';

  @override
  String get developerNotificationWindowsIdentity => 'Windows-pakkeidentitet';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX-identitet er tilgængelig; aktive notifikationer kan annulleres';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Installér MSIX-versionen for pålideligt at kunne annullere aktive notifikationer';

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
  String get notificationSettingsSection => 'Påmindelser og notifikationer';

  @override
  String get notificationCoverage => 'Påmindelsesdækning';

  @override
  String get notificationCoverageRenewable =>
      'Gentagne tidsplaner uden slutdato bruger fornyelse i baggrunden til langsigtet dækning.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android kan rumme op til $capacity direkte påmindelser. Senere påmindelser forsøges fornyet på forhånd.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Aktivér påmindelser og notifikationer';

  @override
  String get notificationSettingsEnabledHint =>
      'Planlægger kun elementer med en påmindelse. Indstil en standard nedenfor til kurser, der bruger standardindstillingen.';

  @override
  String get notificationPrecisionLimitations =>
      'Påmindelser afhænger af systemtilladelser og baggrundskørsel. Slukning, tidsændringer eller systembegrænsninger kan forsinke dem.';

  @override
  String get notificationSettingsEnabledSummary => 'Aktiveret';

  @override
  String get notificationSettingsDisabledSummary => 'Deaktiveret';

  @override
  String get notificationDefaultsSection => 'Standardpåmindelser';

  @override
  String get notificationCourseDefaultReminder =>
      'Standardpåmindelse for kurser';

  @override
  String get notificationGeneralDefaultReminder =>
      'Standardpåmindelse for begivenheder';

  @override
  String get notificationReminderOff => 'Ingen påmindelse';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutter før';
  }

  @override
  String get notificationPermission => 'Tilladelse til notifikationer';

  @override
  String get notificationPermissionGranted => 'Tilladt af systemet';

  @override
  String get notificationPermissionDenied => 'Blokeret af systemet';

  @override
  String get notificationPermissionChecking => 'Kontrollerer tilladelse…';

  @override
  String get notificationPermissionRequest => 'Anmod om tilladelse';

  @override
  String get notificationPermissionOpenSettings => 'Åbn systemindstillinger';

  @override
  String get notificationPermissionRequestFailed =>
      'Kunne ikke læse notifikationstilladelsen. Prøv igen.';

  @override
  String get notificationExactAlarm => 'Tilladelse til præcise alarmer';

  @override
  String get notificationExactAlarmAllowed => 'Tilladt af systemet';

  @override
  String get notificationExactAlarmRequired =>
      'Kræves til præcise påmindelsestider';

  @override
  String get notificationExactAlarmRequest => 'Tillad præcise alarmer';

  @override
  String get notificationBatteryOptimization => 'Batterioptimering';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Undtaget fra Androids batterioptimering';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Præcise påmindelser kræver en undtagelse fra Androids batterioptimering';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Åbn indstillinger for batterioptimering';

  @override
  String get notificationAutostart => 'Producentens baggrundsstart';

  @override
  String get notificationAutostartVendorHint =>
      'Tillad automatisk start eller baggrundskørsel, så påmindelser kan gendannes efter en genstart.';

  @override
  String get notificationAutostartFallbackHint =>
      'Åbn Skeds appoplysninger, og tillad baggrundskørsel. Android kan ikke kontrollere denne producentindstilling.';

  @override
  String get notificationAutostartUnavailable =>
      'Der blev ikke fundet en side med producentindstillinger. Kontrollér Skeds appoplysninger manuelt.';

  @override
  String get notificationAutostartRequest =>
      'Åbn producentens baggrundsindstillinger';

  @override
  String get notificationAutostartOpenFailed =>
      'Kunne ikke åbne producentens baggrundsindstillinger. Kontrollér Skeds appoplysninger manuelt.';

  @override
  String get notificationLockScreenTitles => 'Vis titler på låseskærmen';

  @override
  String get notificationLockScreenTitlesHint =>
      'Når indstillingen er slået fra, vises notifikationernes detaljer ikke på låseskærmen.';

  @override
  String get notificationWidgets => 'Widgets på startskærmen';

  @override
  String get notificationWidgetsDesc =>
      'Opdatér Sked-widgets, og se, hvordan du tilføjer en fra startskærmen.';

  @override
  String get notificationWidgetsDialogTitle => 'Tilføj en Sked-widget';

  @override
  String get notificationWidgetsDialogMessage =>
      'Hold nede på et tomt område på enhedens startskærm, vælg Widgets, og tilføj en Sked-widget. Den viser dine næste kurser eller begivenheder.';

  @override
  String get notificationWidgetsRefresh => 'Opdatér widgets';

  @override
  String get notificationWidgetsRefreshed => 'Widgets er opdateret';

  @override
  String get notificationPlatformUnsupported =>
      'Denne platform tilbyder ikke native notifikationer.';

  @override
  String get workspaceFeatures => 'Funktionsstyring';

  @override
  String get workspaceBoth => 'Skoleskema og kalender';

  @override
  String get workspaceOnlyStudent => 'Kun skoleskema';

  @override
  String get workspaceOnlyGeneral => 'Kun kalender';

  @override
  String get workspaceDisableTitle => 'Slå dette arbejdsområde fra?';

  @override
  String get workspaceDisableMessage =>
      'Data og indstillinger bevares. Funktioner og påmindelser stoppes, indtil du slår arbejdsområdet til igen her.';

  @override
  String get workspaceEnableHint =>
      'Vælg de funktioner, du bruger. Mindst én skal forblive aktiv.';

  @override
  String get workspaceLastRequired =>
      'Mindst ét arbejdsområde skal forblive aktivt.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Arbejdsområdet er slået fra, men påmindelserne kunne ikke fjernes. Prøv at gendanne notifikationerne igen.';

  @override
  String get settingsSearch => 'Søg i indstillinger';

  @override
  String get settingsNoResults => 'Ingen matchende indstillinger';

  @override
  String get settingsDataPrivacy => 'Data og privatliv';

  @override
  String get workspacePreferences => 'Visning og betjening';

  @override
  String get workspaceManage => 'Administrer';

  @override
  String get selectedDayAgenda => 'Valgt dag';

  @override
  String get notificationTroubleshooting => 'Tilladelser og fejlfinding';

  @override
  String get settingsConnection => 'Forbindelse';

  @override
  String get settingsAdvanced => 'Avanceret';

  @override
  String get unsavedChangesMessage =>
      'Du har ændringer, der ikke er gemt. Kassér dem og forlad siden?';

  @override
  String get backupWorkspaceSelection =>
      'Den komplette sikkerhedskopi indeholder data og valget af aktive arbejdsområder.';

  @override
  String get assistantLayoutPreview => 'AI · Layoutforhåndsvisning';

  @override
  String get assistantSelectionContext =>
      'Bruger det aktuelle valg som kontekst';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Beskedkladde';

  @override
  String get assistantPreviewNoSend =>
      'Kun layoutforhåndsvisning. Intet sendes eller ændres.';

  @override
  String get resizePanel => 'Ændr panelets størrelse';

  @override
  String get minimizeWindow => 'Minimér';

  @override
  String get maximizeWindow => 'Maksimér';

  @override
  String get restoreWindow => 'Gendan vindue';

  @override
  String get closeWindow => 'Luk vindue';

  @override
  String get courseSystemReminder => 'Systempåmindelse';

  @override
  String courseReminderInherit(String reminder) {
    return 'Brug standard ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Systempåmindelser er slået fra i notifikationsindstillingerne. Dette kursus\' indstilling kan stadig gemmes.';

  @override
  String get courseReminderDefaultOff =>
      'Der er ikke indstillet en standardpåmindelse for kurser. Vælg en brugerdefineret her, eller angiv en standard i notifikationsindstillingerne.';

  @override
  String get courseReminderDeliveryHint =>
      'Denne indstilling gemmes sammen med kurset. Levering afhænger af systemets notifikationstilladelser og baggrundsbegrænsninger.';

  @override
  String get courseReminderPermissionUnknown =>
      'Systemets notifikationsstatus er ikke kontrolleret. Gennemgå notifikationsindstillingerne, før du stoler på påmindelserne.';

  @override
  String get courseReminderMinutesLabel => 'Minutter før kurset';

  @override
  String get exportAction => 'Eksportér';

  @override
  String get datePickerSelectWeek => 'Vælg uge';

  @override
  String get datePickerSelectMonth => 'Vælg måned';

  @override
  String get generalDateLabelFormatDescription =>
      'Gælder datonavigation på computere og mindre skærme.';

  @override
  String get dateRangeTitle => 'Vælg datointerval';

  @override
  String get dateRangeCustom => 'Tilpasset';

  @override
  String get dateRangeChooseStart => 'Vælg startdato';

  @override
  String get dateRangeChooseEnd => 'Vælg slutdato';

  @override
  String get dateRangeLimit => 'Vælg 1–14 dage, inklusive start- og slutdato.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dage',
      one: '1 dag',
    );
    return 'Brugerdefineret · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Vælg med rullehjul';

  @override
  String get courseReminderUseDefault => 'Brug standard';

  @override
  String get courseReminderInvalidMinutes =>
      'Angiv et helt antal minutter på nul eller derover.';

  @override
  String get generalCustomColumnWidth =>
      'Kolonnebredde i brugerdefineret visning';

  @override
  String get generalCustomColumnWidthAuto => 'Automatisk';

  @override
  String get generalCustomColumnWidthManual => 'Mindste bredde';

  @override
  String get generalCustomColumnWidthMinimum => 'Mindste bredde pr. dag';

  @override
  String get generalCustomColumnWidthHint =>
      'Alle datoer deler denne minimumsbredde. Kolonnerne fylder den tilgængelige plads eller ruller vandret. Gælder kun brugerdefineret visning.';

  @override
  String get settingsAppearanceLanguage => 'Udseende og sprog';

  @override
  String get settingsAppearanceDetails => 'Farver og konturer';

  @override
  String get monthNoEvents => 'Ingen begivenheder denne dag';

  @override
  String get settingsOverview => 'Oversigt';

  @override
  String get settingsThemeTarget => 'Tema for';

  @override
  String get settingsColorMode => 'Farvetilstand';

  @override
  String get settingsNotificationPreferences => 'Indstillinger for påmindelser';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Standardpåmindelser, tilladelser og pålidelighed';

  @override
  String get settingsFeaturesSummary => 'Arbejdsområder og navigation';

  @override
  String get settingsPrivacySummary =>
      'Privatlivspolitik og rydning af lokale data';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lektioner',
      one: '1 lektion',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Lektion';

  @override
  String get periodTimesDurationColumn => 'Varighed';

  @override
  String get periodTimesGapColumn => 'Pause';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Venter på at gemme…';

  @override
  String get periodTimesSaveFailed => 'Ikke gemt · Kunne ikke gemme';

  @override
  String get periodTimesInvalidStatus => 'Ikke gemt · Ret de markerede tider';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked kunne ikke bekræfte, om den seneste lagring blev rullet tilbage. Skrivning er sat på pause, og gendannelseskopier er bevaret. Kontrollér lageret, og prøv at indlæse igen.';

  @override
  String get settingsPanelDisplayMode => 'Panelvisning';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Fælles for skemaer og kalendere';

  @override
  String get settingsPanelDisplayOverlay => 'Overlejring';

  @override
  String get settingsPanelDisplaySideBySide => 'Side om side';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatisk';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Lægger panelet over højre side uden at ændre kalenderens bredde.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Foretrækker side om side; overlejrer kun, hvis kalenderen bliver for smal.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Viser side om side, når kalenderen har en læsbar bredde, ellers som overlejring.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Hvis du slår Indstillinger eller Arbejdsområde fra på værktøjslinjen, flyttes elementet til Mere i stedet for at blive fjernet. Mere kan ikke skjules, mens menuen indeholder nødvendige handlinger. Skift mellem arbejdsområder vises kun, når navigationen nederst er skjult, og flere arbejdsområder er aktiveret.';

  @override
  String get reminderEnded => 'Afsluttet';

  @override
  String get reminderAutoCloseHint =>
      'Lukker efter 10 sekunder. Brug panelet for at holde det åbent.';

  @override
  String get showReminderIndependently => 'Åbn separat';

  @override
  String get categoryManagerTitle => 'Administrér kategorier';

  @override
  String get categoryHidden => 'Skjult';

  @override
  String get categoryShowOnCalendar => 'Vis i kalender';

  @override
  String get categoryHideOnCalendar => 'Skjul i kalender';

  @override
  String get categoryEditColor => 'Skift kategorifarve';

  @override
  String get categoryThemePalette => 'Temapaletten';

  @override
  String get categoryCustomColor => 'Brugerdefineret';

  @override
  String get colorHexInvalid => 'Angiv en sekscifret hexadecimal farvekode.';

  @override
  String categoryColorSlot(int number) {
    return 'Temafarve $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Opdateringer i butikken kan komme senere. Tilgængeligheden afgøres af butikssiden.';

  @override
  String get storePrereleaseNotice =>
      'Notifikationer om forhåndsversioner tilmelder dig ikke et testprogram i butikken.';

  @override
  String get updateFoundTitle => 'Ny version tilgængelig';

  @override
  String get updateNoNotes => 'Der er ingen udgivelsesnoter.';

  @override
  String get updateLater => 'Senere';

  @override
  String get updateRetry => 'Prøv igen';

  @override
  String get updatePrerelease => 'Forhåndsversion';

  @override
  String get updateNetworkFailure =>
      'Kunne ikke søge efter opdateringer. Kontrollér forbindelsen, og prøv igen.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Ingen nyere version fundet (aktuel: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Gendanner sikkerhedskopi…';

  @override
  String get backupRestoreInProgressMessage =>
      'Data og indstillinger kan ændres, når gendannelsen er færdig. Du kan stadig se dem.';
}
