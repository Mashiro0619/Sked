// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppLocalizationsEt extends AppLocalizations {
  AppLocalizationsEt([String locale = 'et']) : super(locale);

  @override
  String get appTitle => 'Klassikaaslane';

  @override
  String weekLabel(int week) {
    return 'Nädal $week';
  }

  @override
  String get addCourse => 'Lisa kursus';

  @override
  String get settings => 'Seaded';

  @override
  String get multiTimetableSwitch => 'Ajavahemite vahetamine';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Praegune ajakava · $weeks nädalad';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Puudutage vahetamiseks · $weeks nädalad';
  }

  @override
  String get editTimetable => 'Ajaplani muutmine';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get schoolImportParsePageTitle => 'Analüüsi tunniplaani';

  @override
  String get schoolImportParsePageParsing => 'Analüüsimine…';

  @override
  String get schoolImportParsePageFailed => 'Analüüs nurjus';

  @override
  String get schoolImportParsePageComplete => 'Analüüs lõpetatud';

  @override
  String get schoolImportParsePageContinue => 'Jätka';

  @override
  String get schoolImportParsePageRawContent => 'Töötlemata vastus';

  @override
  String get schoolImportParsePageExpandRaw => 'Laienda töötlemata vastust';

  @override
  String get schoolImportParsePageCollapseRaw => 'Ahenda töötlemata vastus';

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
  String get createTimetable => 'Uus ajakava';

  @override
  String get jumpToWeek => 'Hüppa nädalale';

  @override
  String get timetable => 'Ajaaeg';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Ajarava nimi';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Nädalad kokku';

  @override
  String get delete => 'Kustuta';

  @override
  String get cancel => 'Tühista';

  @override
  String get save => 'Salvesta';

  @override
  String get deleteTimetableTitle => 'Kustuta ajakava';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Kustutada \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Veel ajakava pole';

  @override
  String get noTimetableMessage =>
      'Looge ajakava või importige üks JSON-failist.';

  @override
  String get importTimetable => 'Importimise ajakava';

  @override
  String get courseName => 'Kursuse nimi';

  @override
  String get location => 'Asukoht';

  @override
  String get dayOfWeek => 'Päev';

  @override
  String get semesterWeeks => 'Nädalad';

  @override
  String get startTime => 'Algusaeg';

  @override
  String get endTime => 'Lõpuaeg';

  @override
  String get linkedPeriods => 'Seotud perioodid';

  @override
  String get linkedPeriodsUnmatched =>
      'Praegune aeg ei vasta perioodidele. Valimiseks puudutage käsitsi.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Periood $start-$end';
  }

  @override
  String get teacherName => 'Õpetaja';

  @override
  String get credits => 'Krediidid';

  @override
  String get remarks => 'Märkused';

  @override
  String get customFields => 'Kohandatud väljad';

  @override
  String get customFieldsHint => 'Üks rida kohta, vorming: key:value';

  @override
  String get more => 'Rohkem';

  @override
  String get selectDayOfWeek => 'Vali päev';

  @override
  String get selectSemesterWeeks => 'Vali nädalad';

  @override
  String get selectAll => 'Vali kõik';

  @override
  String get clear => 'Puhasta';

  @override
  String get confirm => 'Kinnita';

  @override
  String get selectLinkedPeriods => 'Valige seotud perioodid';

  @override
  String get addCourseTitle => 'Lisa kursus';

  @override
  String get editCourseTitle => 'Muuda kursust';

  @override
  String get editCourseTooltip => 'Muuda kursust';

  @override
  String get place => 'Asukoht';

  @override
  String get time => 'Aeg';

  @override
  String get notFilled => 'Mitte täidetud';

  @override
  String get none => 'Ükski';

  @override
  String get conflictCourses => 'Konfliktlikud kursused';

  @override
  String get locationNotFilled => 'Asukoht ei ole täidetud';

  @override
  String get setAsDisplayed => 'Määrake näidatuna';

  @override
  String get editThisCourse => 'Redigeeri seda kursust';

  @override
  String get settingsTitle => 'Seaded';

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
      'Praegu ei ole seadete jaoks ajakava saadaval.';

  @override
  String get semesterStartDate => 'Semestri alguskuupäev';

  @override
  String get periodTimeSets => 'Perioodi määratud aeg';

  @override
  String get noPeriodTimeAvailable => 'Vabamat perioodi aega ei ole määratud';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count perioodid';
  }

  @override
  String get coursePopupDismissSetting =>
      'Luba väljaspool puudutada kursuse hüpikakna sulgemiseks';

  @override
  String get coursePopupDismissSettingHint =>
      'Selle välja lülitamine keelab ka nihkumise vallandamise.';

  @override
  String get preserveTimetableGaps => 'Ajaplaani puudujääkide säilitamine';

  @override
  String get preserveTimetableGapsHint =>
      'Kui välja, lõuna ja paus lüngad kokku nii hilisemad klassid liikuda üles.';

  @override
  String get showPastEndedCourses => 'Näita möödunud kursusi';

  @override
  String get showPastEndedCoursesHint =>
      'Näita kursusi, mis on juba lõppenud tõelise praeguse nädala heledama halli stiilis.';

  @override
  String get showFutureCourses => 'Näita tulevasi kursusi';

  @override
  String get showFutureCoursesHint =>
      'Näita kursusi, mis ei ole aktiivsed sel nädalal, kuid ilmuvad hilisematel nädalatel halli stiilis.';

  @override
  String get timetableDisplaySettings => 'Ajarava kuvamine ja suhtlemine';

  @override
  String get timetableDisplaySettingsDesc =>
      'Kursuste kuvamine, paigutus, nädalaliigutused ja kiirlisamine';

  @override
  String get showTimetableGridLines => 'Näita ajakava võrgu joone';

  @override
  String get showTimetableGridLinesHint =>
      'Kontrollige, kas ajakavas on nähtavad horisontaalsed ja vertikaalsed võrgujooned.';

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
  String get liveCourseOutlineColor => 'Kursuse kontuuri värv';

  @override
  String get liveCourseOutlineColorHint =>
      'Valige, kas kontuurid on suunatud praegusele/järgmisele kursusele või kõigile praegusel lehel kuvatud kursustele.';

  @override
  String get liveCourseOutlineSettings => 'Kursuse ülevaade';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Konfigureerige, kas kontuur on lubatud, mida see suunab, kas see järgib teemavärvi ja efektiivset kontuurivärvi.';

  @override
  String get liveCourseOutlineEnabled => 'Luba kontur';

  @override
  String get liveCourseOutlineFollowTheme => 'Järgi teema värvi';

  @override
  String get liveCourseOutlineTarget => 'Eesmärk';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Praegune/järgmine kursus';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Kõik näidatud kursused';

  @override
  String get liveCourseOutlineEffectiveColor => 'Tõhus värv';

  @override
  String get liveCourseOutlineCustomColor => 'Kohandatud kontuurivärv';

  @override
  String get liveCourseOutlineWidth => 'Kontuuri laius';

  @override
  String get outlineWidthUnit => 'Px';

  @override
  String get language => 'keel';

  @override
  String get languagePageDescription =>
      'Valige üks rakenduses tõeliselt saadaval olevatest keeltest.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'Inglise keel';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API vastus';

  @override
  String get theme => 'Teema';

  @override
  String get themeFollowSystem => 'Jälgi süsteemi';

  @override
  String get themeLight => 'Valgus';

  @override
  String get themeDark => 'Tume';

  @override
  String get themeColor => 'Teemavärv';

  @override
  String get themeColorModeSingle => 'Ühe teema värv';

  @override
  String get themeColorModeColorful => 'Värviline';

  @override
  String get themeColorUiColors => 'UI värvid';

  @override
  String get themeColorCourseColors => 'Kursuse värvid';

  @override
  String get themeColorPrimary => 'esmane';

  @override
  String get themeColorSecondary => 'Sekundaarne';

  @override
  String get themeColorTertiary => 'Tertiaarne';

  @override
  String get themeColorCourseText => 'Kursuse tekst';

  @override
  String get themeColorCourseTextAuto => 'Automaatne';

  @override
  String get themeColorCourseTextCustom => 'Kohandatud värv';

  @override
  String get themeColorCourseColorsEmpty =>
      'Kursuse värvid genereeritakse pärast ajakava importimist.';

  @override
  String get themeCustomColor => 'Kohandatud värv';

  @override
  String get themeApplyCustomColor => 'Värvi rakendamine';

  @override
  String get themeApplySettings => 'Seadete rakendamine';

  @override
  String get dataImportExport => 'Import- ja ekspordiandmed';

  @override
  String get dataImportExportDesc =>
      'Importige täielikud andmed või üksikud ajakavad või eksportige praegused/kõik ajakavad.';

  @override
  String get appBackupTitle => 'Rakenduse varundamine ja taastamine';

  @override
  String get appBackupSubtitle =>
      'Varunda või taasta tunniplaanid, ajakavad, seaded ja koolide saidid. API-võtmeid ei kaasata.';

  @override
  String get appBackupSheetSubtitle =>
      'Täielik taastamine asendab praegused rakenduse andmed. AI API-võtmed on turvalises salvestusruumis ja neid ei kirjutata varukoopiafailidesse.';

  @override
  String get restoreBackupFileTitle => 'Taasta JSON-failist';

  @override
  String get restoreBackupFileSubtitle =>
      'Vali täielik Skedi varukoopiafail. Enne taastamist küsitakse kinnitust.';

  @override
  String get restoreBackupTextTitle => 'Kleebi varukoopia JSON';

  @override
  String get restoreBackupTextSubtitle =>
      'Kleebi täielik varukoopia ja taasta praegused rakenduse andmed.';

  @override
  String get shareBackupTitle => 'Jaga varukoopiafaili';

  @override
  String get shareBackupSubtitle =>
      'Ekspordi kõik rakenduse andmed JSON-ina. API-võtmed jäetakse välja.';

  @override
  String get saveBackupTitle => 'Salvesta varukoopiafail';

  @override
  String get saveBackupSubtitle =>
      'Salvesta rakenduse täielik varukoopia kohalikku faili.';

  @override
  String get copyBackupTitle => 'Kopeeri varukoopia tekst';

  @override
  String get copyBackupSubtitle =>
      'Kuva täielik varukoopia JSON, et saaksid selle kopeerida või ajutiselt salvestada.';

  @override
  String get restoreBackupConfirmTitle => 'Taastada täielik varukoopia?';

  @override
  String get restoreBackupConfirmMessage =>
      'See asendab kõik praegused tunniplaanid, üldised ajakavad, seaded ja koolide saidid. API-võtmeid varukoopiatest ei impordita; sisesta võti enne tunniplaanide uuesti parsimist uuesti.';

  @override
  String get restoreBackupConfirmAction => 'Taasta varukoopia';

  @override
  String get restoreBackupSuccessMessage =>
      'Rakenduse täielik varukoopia taastati. AI API-võtmed tuleb uuesti sisestada.';

  @override
  String get restoreBackupFailureMessage =>
      'Taastamine ebaõnnestus. Kontrolli varukoopia sisu ja proovi uuesti.';

  @override
  String get openSourceLicenses => 'Avatud lähtekoodiga litsentsid';

  @override
  String get openSourceLicensesDesc =>
      'Vaata Flutteri sõltuvuste ja rakenduse ikoonide varude litsentse.';

  @override
  String get checkForUpdates => 'Uuenduste kontrollimine';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Juba viimase versiooniga ($version)';
  }

  @override
  String get currentVersionLabel => 'Praegune versioon';

  @override
  String get newVersionAvailable => 'Uuendus saadaval';

  @override
  String get latestVersionLabel => 'Viimane versioon';

  @override
  String get updateContentLabel => 'Uuendamise üksikasjad';

  @override
  String get officialWebsite => 'Ametlik veebileht';

  @override
  String get googlePlay => 'Google Play\'i';

  @override
  String get cloudDrive => 'Pilvekäik';

  @override
  String get ignoreThisVersion => 'Ignoreeri seda versiooni';

  @override
  String get openUpdatesFailed => 'Uuenduslingi avamine nurjus';

  @override
  String get updateCheckFailedTitle => 'Uuenduse kontroll nurjus';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHubi hoidlus';

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
  String get openGithubFailed => 'GitHubi salvestuse lingi avamine nurjus';

  @override
  String get openPrivacyPolicyFailed =>
      'Privaatsuspoliitika lingi avamine nurjus';

  @override
  String get selectPeriodTimeSet => 'Vali perioodi aeg';

  @override
  String get newItem => 'Uus';

  @override
  String get editPeriodTimeSet => 'Perioodi aja seadistuse muutmine';

  @override
  String get importTimetableFiles => 'Importimise ajakava';

  @override
  String get importTimetableFilesDesc => 'Toetab ühte või mitut ajakavafaili.';

  @override
  String get importTimetableText => 'Ajakaava importimine tekstist';

  @override
  String get importTimetableTextDesc =>
      'Kleebige ajakava JSON sisu ja importige see.';

  @override
  String get shareTimetableFiles => 'Jaga ajakavafaile';

  @override
  String get shareTimetableFilesDesc =>
      'Valige kõigepealt üks või mitu ajakava.';

  @override
  String get saveTimetableFiles => 'Ajakava failide salvestamine';

  @override
  String get saveTimetableFilesDesc =>
      'Valige kõigepealt üks või mitu ajakava.';

  @override
  String get exportTimetableText => 'Ekspordi ajakava tekstina';

  @override
  String get exportTimetableTextDesc =>
      'Valige üks või mitu ajakava ja seejärel kopeerige JSON-sisu.';

  @override
  String get jsonContent => 'JSON sisu';

  @override
  String get pasteJsonContentHint => 'Kleepige impordimiseks JSON-sisu.';

  @override
  String get jsonContentEmpty => 'Esiteks kleebige JSON sisu.';

  @override
  String get copyText => 'Kopeerimine';

  @override
  String get copiedToClipboard => 'Kopeeritud lõikepuhvrisse';

  @override
  String get share => 'Jaga';

  @override
  String get selectTimetablesToExport => 'Valige ekspordimiseks ajakavad';

  @override
  String get selectTimetablesToImport => 'Importimiseks ajakavade valimine';

  @override
  String timetableCourseCount(int count) {
    return '$count kursused';
  }

  @override
  String get importAction => 'Import';

  @override
  String get importTimetableDialogTitle => 'Importimise ajakava';

  @override
  String get chooseImportMethod => 'Valige, kuidas importida.';

  @override
  String get importAsNewTimetable => 'Import uue ajakavana';

  @override
  String get replaceCurrentTimetable => 'Asendada praegune ajakava';

  @override
  String get importPeriodTimeSetDialogTitle => 'Impordiperioodi ajakohad';

  @override
  String get importPeriodTimeSetDialogBody =>
      'See fail sisaldab komplekteeritud perioodi ajaseadmeid. Kas soovite neid importida ja ühendada?';

  @override
  String get importBundledPeriodTimeSets => 'Import ja assotsieerimine';

  @override
  String get discardBundledPeriodTimeSets => 'Visata komplektid ära';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Olemasolevat perioodi aegset ei ole saadaval, seega ei saa paketitud perioodi aegset kõrvaldada.';

  @override
  String savedToPath(Object path) {
    return 'Salvestatud $path';
  }

  @override
  String get saveCancelled => 'Salvestamine tühistatud';

  @override
  String get fileSaveRestrictedTitle => 'Faili salvestamine piiratud';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Süsteem ei suutnud faili salvestada. Selle asemel saate proovida uuesti või kasutada jagamist.';

  @override
  String get retrySave => 'Püüa salvestada uuesti';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Lubage süsteemi seadetes juurdepääs failidele, seejärel tagastage ja proovige uuesti eksportida.';

  @override
  String get openSettings => 'Ava seaded';

  @override
  String get browserDownloadRestrictedTitle =>
      'Brauseri allalaadimine piiratud';

  @override
  String get browserDownloadRestrictedMessage =>
      'See brauser ei toeta otse salvestamist kohalikku faili. Kontrollige brauseri allalaadimise õigusi või kasutage selle asemel failide jagamist.';

  @override
  String get switchToShare => 'Kasutage selle asemel jagamist';

  @override
  String get fileSaveFailedTitle => 'Faili salvestamine nurjus';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Praegusele teele kirjutamine nurjus. Sihtkaust võib olla kaitstud, fail võib olla kasutuses või tee võib olla kirjutamata.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Süsteem ei suutnud faili salvestada. Võite proovida uuesti, kontrollida süsteemi seadeid või selle asemel kasutada failide jagamist.';

  @override
  String get retryLater => 'Proovi hiljem uuesti';

  @override
  String get exportSwitchedToShare =>
      'Eksportimiseks failide jagamisele üles lülitatud';

  @override
  String get saveFailedRetry =>
      'Salvestamine nurjus. Palun proovige hiljem uuesti.';

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
  String get appInstanceBlockedTitle => 'Sked on juba avatud';

  @override
  String get appInstanceBlockedMessage =>
      'Teine Skedi aken või brauseri vahekaart kasutab sinu kohalikke andmeid. Sulge see ja proovi uuesti.';

  @override
  String get appInstanceLeaseFailedTitle => 'Kohalikud andmed pole saadaval';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked ei saanud kinnitada ainupääsu kohalikele andmetele. Sinu andmeid ei avatud ega muudetud. Kontrolli juurdepääsu salvestusruumile ja proovi uuesti.';

  @override
  String get savingChanges => 'Muudatuste salvestamine...';

  @override
  String get showApiKey => 'Kuva API-võti';

  @override
  String get hideApiKey => 'Peida API-võti';

  @override
  String get importFailedCheckContent =>
      'Importimine nurjus. Palun kontrollige faili sisu.';

  @override
  String get noImportableTimetables =>
      'Imporditud failist ei leitud kasutatavaid ajakavasid.';

  @override
  String importedTimetablesCount(int count) {
    return 'Imporditud $count ajakavad';
  }

  @override
  String get periodTimesTitle => 'Perioodi ajad';

  @override
  String get importExport => 'Import ja eksport';

  @override
  String get importPeriodTemplate => 'Impordiperioodi mall';

  @override
  String get importPeriodTemplateText => 'Perioodi malli importimine tekstist';

  @override
  String get sharePeriodTemplate => 'Osalemisperioodi mall';

  @override
  String get saveTemplateToFile => 'Malli salvestamine faili';

  @override
  String get exportPeriodTemplateText => 'Perioodi malli eksportimine tekstina';

  @override
  String get deletePeriodTimeSet => 'Kustuta perioodi aeg';

  @override
  String get periodTimeSetName => 'Perioodi aja määramise nimi';

  @override
  String get addOnePeriod => 'Lisa periood';

  @override
  String periodNumberLabel(int index) {
    return 'Periood $index';
  }

  @override
  String get deleteThisPeriod => 'Kustuta see periood';

  @override
  String durationMinutes(int minutes) {
    return 'Kestus $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Vahe eelmisest $minutes min';
  }

  @override
  String get endTimeMustBeLater => 'Lõppeaeg peab olema hiljem kui algusaeg';

  @override
  String get periodOverlapPrevious => 'See periood ületab eelmise';

  @override
  String get periodTimesSaved => 'Säästatud perioodiaeg';

  @override
  String get deletePeriodTimeSetTitle => 'Kustuta perioodi aeg';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Kustutada \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'kehtestatud praegune periood';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Imporditud $count perioodi aeg';
  }

  @override
  String get periodFilePermissionTitle => 'Vajalik faililoa';

  @override
  String get androidFilePermissionMessage =>
      'Android eksport nõuab failide juurdepääsu luba. Andke luba jätkata säästmist.';

  @override
  String get reauthorize => 'Autoriseerida uuesti';

  @override
  String get permissionPermanentlyDeniedTitle => 'Luba jäädavalt keelatud';

  @override
  String get permissionSettingsExportMessage =>
      'Lubage süsteemi seadetes juurdepääs failidele, seejärel tagastage ja proovige uuesti eksportida.';

  @override
  String get privacyPolicyTitle => 'Privaatsuspoliitika';

  @override
  String get privacyPolicyEntryDesc =>
      'Uuri, kuidas rakendus käsitleb kohalikku salvestust, kooli saidi konfiguratsiooni, failide importi/eksporti, veebilehtede analüüsi ja välislinke.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Aksepteeritud versioon: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked on lokaalselt töötav tunniplaani tööriist. Tunniplaanid, perioodide komplektid ja kooli saidi konfiguratsioon salvestatakse ainult teie seadmes või brauseris ning neid ei laadita kunagi automaatselt üles. Rakendus töötleb andmeid ainult siis, kui käivitate selgesõnaliselt selliseid toiminguid nagu importimine, veebilehe analüüs, jagamine või väliste linkide avamine. Täielik privaatsuspoliitika on saadaval veebis.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Kohalik ladustamine';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Import ja eksport';

  @override
  String get privacyPolicyImportExportBody =>
      'Rakendus loeb või kirjutab ajakava JSON-faile, kooli saidi JSON-faile ja perioodimallifaile ainult siis, kui olete sõnaselgelt valinud faili või alustanud eksporditegevust. Nende failide importimine on kohalik toiming, kui te ei valiks ka veebilehe analüüsimist. Kohandatud mudeliloendi hankimine on ka selgesõnaline võrgutegevus ja võtab ühendust ainult teie konfigureeritud kohandatud lõpppunktiga.';

  @override
  String get privacyPolicySharingTitle => 'Jagamine';

  @override
  String get privacyPolicySharingBody =>
      'Kui kasutate selgesõnaliselt jagamist, edastab rakendus eksportitud faili süsteemi jagamise lehele või valitud sihrrakendusele. Kuidas seda faili hiljem käsitletakse, sõltub valitud sihrrakendusest või teenusest.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Välislingid';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Kui avate välislinge, näiteks GitHubi hoiu, annab rakendus tegevuse teie brauserile või muule välisele rakendusele. Andmete töötlemist pärast seda punkti reguleerib teie avatud kolmas isik.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Mida rakendus ei kogugi';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Rakendus ei vaja Sked\'i kontot ja ei võimalda analüüsi, reklaamide identifitseerijaid ega pilvevarukoopiat. Samuti ei paku see spetsiaalset väljad koolikonto paroolide kogumiseks. Kui sisse logite rakenduse sees kooli veebisaidile, toimub see suhtlemine kooli lehel, mille avasite.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Veebilehe analüüs';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Kui kasutad kooli veebilehe importi või analüüsid kleebitud tunniplaani teksti / HTML-i, valmistab rakendus sisu esmalt kohapeal ette ja puhastab selle ning saadab seejärel esitatud tunniplaani teksti, leheteksti või HTML-sisu, valikulise lehe pealkirja ja URL-i, rakenduse praeguse keele ning parseri viiba sisu sinu seadistatud OpenAI-ga ühilduvasse lõpp-punkti. Mudelite loendi hankimine teeb päringu samasse lõpp-punkti. Sked ei paku sisseehitatud parseri lõpp-punkti ega saada analüüsipäringuid arendaja hallatavasse tunniplaaniparseri taustsüsteemi. Kohandatud lõpp-punkt ja võimalikud ülesvooluteenused võivad andmeid salvestada, edastada, piirata, kustutada või muul viisil töödelda vastavalt sinu valitud teenusepakkuja reeglitele. Kui kasutad http:// Base URL-i, kasuta seda ainult usaldusväärsetes seadmetes, võrkudes ja lõpp-punktiteenustes, sest sisu ja API-võtmed ei pruugi olla transpordikrüptimisega kaitstud.';

  @override
  String get privacyPolicyUpdatesTitle => 'Poliitika uuendused';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Praegune privaatsuspoliitika versioon on $version. Kui uuem versioon muudab andmete töötlemise viisi, võib rakendus paluda teil uuendatud eeskirja uuesti lugeda ja sellega nõustuda.';
  }

  @override
  String get privacyGateTitle =>
      'Palun nõustu privaatsuspoliitikaga enne rakenduse kasutamist';

  @override
  String get privacyGateSummaryStorage =>
      'Ajaplaanid, ajavahemikud ja kooli saidi konfiguratsioon salvestatakse ainult kohalikult ning neid ei laadita automaatselt üles arendaja serverisse.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, eksport ja jagamine toimuvad ainult siis, kui neid selgesõnaliselt käivitate; Veebilehe analüüsimine saadab ainult teie konfigureeritud analüüsimise lõpppunktile esitatud surutud sisu ja enne salvestamist saate analüüsitud ajakava vaadata.';

  @override
  String get privacyGateSummaryUpdates =>
      'Kui hilisem versioon muudab andmete töötlemise viisi, võib rakendus paluda teil uuendatud privaatsuspoliitikat uuesti vaadata.';

  @override
  String get schoolWebImportEntry => 'Import kooli veebilehelt';

  @override
  String get schoolWebImportEntryDesc =>
      'Importige praegune ajakava lehekülg kooli saidilt.';

  @override
  String get schoolSitesManageEntry => 'Kooli saitide haldamine';

  @override
  String get schoolSitesManageEntryDesc =>
      'Lisage, muuta ja kustutage kooli sisselogimise URL-id, kasutades JSON-impordi ja -eksporti.';

  @override
  String get schoolSitesPageTitle => 'Kooli koha juhtimine';

  @override
  String get schoolSitesImportJson => 'Kooli JSON importimine';

  @override
  String get schoolSitesShareJson => 'Jaga kooli JSON';

  @override
  String get schoolSitesSaveJson => 'Salvesta kooli JSON';

  @override
  String get schoolSitesSaved => 'Kooli saitid salvestatud';

  @override
  String get schoolSitesImported => 'Imporditud koolikohad';

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
  String get schoolSitesEmpty => 'Kooli veebilehe konfiguratsioon veel puudub.';

  @override
  String get schoolSitesNameLabel => 'Kooli nimi';

  @override
  String get schoolSitesLoginUrlLabel => 'Logi sisse URL';

  @override
  String get schoolSitesAdd => 'Lisa kool';

  @override
  String get schoolSitesEdit => 'Kooli muutmine';

  @override
  String get schoolSitesDeleteTitle => 'Kooli kustutamine';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Kustutada \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Täitke esimesena kooli nimi ja sisselogimise URL.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry => 'Import ajakava lehekülje sisu kleepides';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Kleebige lähtekood või ajakava teavet sisaldav lehekülje sisu käsitsi.';

  @override
  String get schoolHtmlImportPageTitle => 'Ajakava analüüs lehekülje sisust';

  @override
  String get schoolHtmlImportUrlLabel => 'Allika URL (vabatahtlik)';

  @override
  String get schoolHtmlImportTitleLabel => 'Lehekülje pealkiri (vabatahtlik)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Lehekülje sisu';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Kleebige lähtekood või ajakava teavet sisaldav lehekülje sisu siia.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Iga sisu, mis sisaldab ajakava teavet, saab analüüsida ja impordida, mitte ainult HTML-i.';

  @override
  String get schoolHtmlImportCompress => 'Valmista sisu';

  @override
  String get schoolHtmlImportCompressed => 'Sisu on valmis';

  @override
  String get schoolHtmlImportCompressFirst => 'Valmista sisu kõigepealt.';

  @override
  String get schoolHtmlImportSubmit => 'Analüüs ja import';

  @override
  String get schoolImportContentTruncated =>
      'See leht saavutas turvalise impordi piirangu. Analüüsimiseks saadetakse ainult jäädvustatud osa.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsimine võib võtta mõnda aega. Palun oota.';

  @override
  String get schoolHtmlImportEmpty => 'Esiteks kleebige lehekülg HTML.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Tagasi veebilehele';

  @override
  String get schoolWebImportPageTitle => 'Kooli veebilehe importimine';

  @override
  String get schoolWebImportPreview => 'Import eelvaate';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count kursused';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count perioodid';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Lehekülje pealkiri';

  @override
  String get schoolWebImportParserUsed => 'Parseri';

  @override
  String get schoolWebImportWarnings => 'Märkide importimine';

  @override
  String get schoolWebImportParserDetails => 'Parsimise üksikasjad';

  @override
  String get schoolWebImportExpandParserDetails => 'Kuva parsimise üksikasjad';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Ahenda parsimise üksikasjad';

  @override
  String get schoolWebImportOpenPageHint =>
      'Logige sisse kooli saidile rakenduses, seejärel liikuge ajakava lehele käsitsi.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'See platvorm ei toeta veel sisseehitatud veebi sisselogimist. Palun kasutage platvormi WebView toetusega.';

  @override
  String get schoolWebImportSelectSchool => 'Vali kool';

  @override
  String get schoolWebImportNoSchools =>
      'Kooli konfiguratsioon ei ole saadaval. Kontrollige kõigepealt school_sites.jsoni.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Kooli konfiguratsiooni laadimine nurjus. Kontrollige JSON failivormingut.';

  @override
  String get schoolWebImportImportCurrentPage =>
      'Praeguse lehekülje importimine';

  @override
  String get schoolWebImportLoadingPage => 'Lehekülje laadimine…';

  @override
  String get schoolWebImportParsing => 'Aktiivse lehekülje analüüsimine...';

  @override
  String get schoolWebImportLoadFailed =>
      'Lehekülje laadimine nurjus. Palun värskendage või proovige hiljem uuesti.';

  @override
  String get schoolWebImportUnknownOrigin => 'Tundmatu sait';

  @override
  String get schoolWebImportExitTitle => 'Kas väljuda brauserist?';

  @override
  String get schoolWebImportExitMessage =>
      'Leht suletakse. Kõik, mida te pole veel importinud, läheb kaotsi.';

  @override
  String get schoolWebImportExitConfirm => 'Välju';

  @override
  String get schoolWebImportEmptyPage =>
      'Praeguse lehekülje sisu on tühi ja seda ei saa veel importida.';

  @override
  String get schoolWebImportSuccess => 'Veebi ajakava imporditud';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Parseri allikas';

  @override
  String get schoolImportParserSourceCustomOpenAi => 'Custom OpenAI-ga ühilduv';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'OpenAI-ga ühilduv kohandatud parser';

  @override
  String get schoolImportParserCustomPromptTitle => 'Kohandatud kutse';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Siin muuda sisseehitatud parseri kutset. Muutused mõjutavad ainult kohandatud OpenAI-ga ühilduvat parserit.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Sisseehitatud käsk laaditakse siin vaikimisi. Puhastage see, et tagasi sisseehitatud versiooni.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Vaikimisi kutse taastamine';

  @override
  String get schoolImportParserBaseUrl => 'Baas URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL peab olema hostiga HTTP- või HTTPS-aadress.';

  @override
  String get schoolImportParserApiKey => 'API võti';

  @override
  String get schoolImportParserModel => 'mudel';

  @override
  String get schoolImportParserFetchModels => 'Mudelite nimekirja hankimine';

  @override
  String get schoolImportParserFetchingModels => 'Kutsu mudeleid. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Ükski mudel ei tagastatud lõpppunktiks.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Mudeleid ei õnnestunud laadida. Kontrollige lõpp-punkti ja proovige uuesti.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Toodud $count mudelid';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Kas kasutada krüptimata HTTP-lõpp-punkti?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API-võtit ja tunniplaani sisu võidakse edastamise ajal lugeda või muuta. Jätkake ainult siis, kui usaldate seda seadet, võrku ja lõpp-punkti. Nõusolek kehtib kuni Skedi sulgemiseni.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Kohandatud parseri konfiguratsioon ei ole täielik. Täida esmalt baas URL, API võti ja mudel.';

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
    return 'Parser: kohandatud ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Vaata täielikku privaatsuspoliitikat';

  @override
  String get privacyAgreeAndContinue => 'Nõustu ja jätka';

  @override
  String get privacyDecline => 'Välja lükata';

  @override
  String get privacyDeclineWebHint =>
      'See brauseri keskkond ei võimalda rakendusel teie eest lehekülge sulgeda. Kui te ei nõustu, sulgege see vahekaardi või akna ise.';

  @override
  String get defaultPeriodTimeSetName => 'Vaikimisperioodid';

  @override
  String get periodTimeSetFallbackName => 'Perioodi ajad';

  @override
  String get untitledTimetableName => 'Pealkirjata ajakava';

  @override
  String get newTimetableName => 'Uus ajakava';

  @override
  String get newPeriodTimeSetName => 'Uus perioodi aeg';

  @override
  String get emptyTimetableName => 'Tühi ajakava';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name perioodid';
  }

  @override
  String get importFileTypeMismatchMessage => 'Faili tüüp ei vasta.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Seda impordifaili versiooni ei toetata veel.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Impordifailis ei leitud perioodi aega.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Palun valige vähemalt üks ajakava.';

  @override
  String get noExportableTimetableMessage => 'Ekspordi ajakava puudub.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Praeguse ajakava asendamine toetab ainult ühe ajakava valikut.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Praegust ajakava asendamiseks ei ole.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Seda perioodi ajaseadet kasutab endiselt $count ajakava(d). Andke need enne kustutamist uuesti.';
  }

  @override
  String get weekdayMonday => 'Esmaspäev';

  @override
  String get weekdayTuesday => 'Teisipäev';

  @override
  String get weekdayWednesday => 'Kolmapäev';

  @override
  String get weekdayThursday => 'Neljapäev';

  @override
  String get weekdayFriday => 'Reede';

  @override
  String get weekdaySaturday => 'Laupäev';

  @override
  String get weekdaySunday => 'Pühapäev';

  @override
  String get weekdayShortMonday => 'esmaspäev';

  @override
  String get weekdayShortTuesday => 'Teisipäev';

  @override
  String get weekdayShortWednesday => 'Kolmapäev';

  @override
  String get weekdayShortThursday => 'neljapäev';

  @override
  String get weekdayShortFriday => 'reede';

  @override
  String get weekdayShortSaturday => 'laupäev';

  @override
  String get weekdayShortSunday => 'Päike';

  @override
  String get monthJanuary => 'jaanuar';

  @override
  String get monthFebruary => 'veebruar';

  @override
  String get monthMarch => 'märts';

  @override
  String get monthApril => 'aprill';

  @override
  String get monthMay => 'mai';

  @override
  String get monthJune => 'juuni';

  @override
  String get monthJuly => 'juuli';

  @override
  String get monthAugust => 'august';

  @override
  String get monthSeptember => 'Sept';

  @override
  String get monthOctober => 'oktoober';

  @override
  String get monthNovember => 'veebruar';

  @override
  String get monthDecember => 'detsember';

  @override
  String get semesterWeeksWholeTerm => 'Kõik semestrid';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Nädalad $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Nädalad $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Vali algrežiim';

  @override
  String get firstLaunchSubtitle =>
      'Vali tööruum, mida kasutad kõige rohkem. Režiimi saab hiljem muuta.';

  @override
  String get firstLaunchStudentDesc =>
      'Halda tunniplaane, kursusi, nädalaid, tundide aegu ja importimist.';

  @override
  String get firstLaunchGeneralDesc =>
      'Halda kategooriaid, sündmusi, meeldetuletusi ning JSON / ICS andmeid.';

  @override
  String get firstLaunchStartStudent => 'Alusta tunniplaaniga';

  @override
  String get firstLaunchStartGeneral => 'Alusta ajakavaga';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Alustava tööruumi valimisega kinnitad, et oled lugenud ';

  @override
  String get firstLaunchPrivacyConsentLink => 'privaatsuspoliitikat';

  @override
  String get firstLaunchPrivacyConsentAfter => ' ja nõustud sellega.';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'Täna';

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
      'Vaated, tööriistariba, kuupäevavorming ja kiirlisamine';

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
  String get viewWeek => 'Nädal';

  @override
  String get viewDay => 'Päev';

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
  String get developerModeTitle => 'Arendajarežiim';

  @override
  String get developerModeDescription =>
      'Tööriistad täielike näidisandmete lisamiseks kujunduse ja kasutuse kontrollimiseks.';

  @override
  String get developerSampleLanguage => 'Näidisandmete keel';

  @override
  String get developerSampleChinese => 'Hiina';

  @override
  String get developerSampleEnglish => 'Inglise';

  @override
  String get developerSampleDataDescription =>
      'Lisab ühe tunniplaani ning kategooriad ja sündmused olemasolevaid andmeid asendamata.';

  @override
  String get developerAddSampleData => 'Lisa näidisandmed';

  @override
  String get developerSampleDataAdded =>
      'Näidistunniplaan ja sündmused on lisatud.';

  @override
  String get developerModeLongPressHint =>
      'Arendajarežiimi avamiseks hoidke 3 sekundit all';

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
  String get collapseWorkspaceNavigation => 'Ahenda tööruumi navigeerimine';

  @override
  String get expandWorkspaceNavigation => 'Laienda tööruumi navigeerimist';

  @override
  String get schoolWebImportExitBrowser => 'Sule sisseehitatud brauser';

  @override
  String get schoolWebImportEditAddress => 'Muuda aadressi';

  @override
  String get schoolWebImportAddressLabel => 'Veebiaadress';

  @override
  String get schoolWebImportOpenAddress => 'Ava';

  @override
  String get schoolWebImportAddressInvalid =>
      'Sisestage hostiga HTTP- või HTTPS-aadress.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'See veebileht taotles uut akent, mida ei saa selles seadmes avada.';

  @override
  String get schoolWebImportSecureConnection => 'Turvaline ühendus';

  @override
  String get schoolWebImportInsecureConnection => 'Ebaturvaline ühendus';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Kas avada kooli sisselogimine?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Kooli sisselogimine võib saata kasutajatunnused vormide või serveri ümbersuunamiste kaudu koolile ja selle sisselogimisteenuse pakkujatele. Android ei saa iga sellist edastust eraldi sihtkoha kinnitamiseks peatada. Jätkake ainult siis, kui usaldate neid selle impordiseansi jaoks:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Kas avada ebaturvaline kooli sisselogimine?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'See kooli sisselogimine kasutab HTTP-d. Igaüks, kes saab seda ühendust jälgida või muuta, võib lugeda või muuta teie sisselogimisandmeid ja lehe sisu. Jätkake ainult siis, kui nõustute selle riskiga saidi puhul:\n\n$origin';
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
