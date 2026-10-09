// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppLocalizationsEt extends AppLocalizations {
  AppLocalizationsEt([String locale = 'et']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Nädal $week';
  }

  @override
  String get addCourse => 'Lisa kursus';

  @override
  String get settings => 'Seaded';

  @override
  String get multiTimetableSwitch => 'Vaheta tunniplaani';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Praegune tunniplaan · $weeks nädalat';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Vahetamiseks puuduta · $weeks nädalat';
  }

  @override
  String get editTimetable => 'Muuda tunniplaani';

  @override
  String get schoolImportResultEditorTitle => 'Muuda analüüsi tulemust';

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
  String get schoolImportExpandWarnings => 'Laienda impordi hoiatusi';

  @override
  String get schoolImportCollapseWarnings => 'Ahenda impordi hoiatusi';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Mõned kursused kestavad $week. nädalani.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Asendada praegune tunniplaan?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Imporditud tunniplaan asendab praeguse tunniplaani.';

  @override
  String get createTimetable => 'Uus tunniplaan';

  @override
  String get jumpToWeek => 'Hüppa nädalale';

  @override
  String get timetable => 'Tunniplaan';

  @override
  String get themeWorkspaceSchedule => 'Ajakava';

  @override
  String get timetableName => 'Tunniplaani nimi';

  @override
  String get timetableNameRequired => 'Sisesta tunniplaani nimi';

  @override
  String get totalWeeks => 'Nädalad kokku';

  @override
  String get delete => 'Kustuta';

  @override
  String get cancel => 'Tühista';

  @override
  String get save => 'Salvesta';

  @override
  String get deleteTimetableTitle => 'Kustuta tunniplaan';

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
  String get customFieldsInvalidJson =>
      'Sisesta kehtiv JSON-objekt või tühjenda väli.';

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
  String get settingsSectionTimetable => 'Tunniplaan';

  @override
  String get settingsSectionGeneralSchedule => 'Üldine ajakava';

  @override
  String get settingsSectionAppearance => 'Välimus';

  @override
  String get settingsSectionApp => 'Rakendus';

  @override
  String get settingsSectionWorkspace => 'Tööruum';

  @override
  String get settingsSectionAppearanceLanguage => 'Välimus ja keel';

  @override
  String get settingsSectionDataSecurity => 'Andmed ja turvalisus';

  @override
  String get settingsSectionAbout => 'Teave Skedi kohta';

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
      'Horisontaalne paigutus ja viiped';

  @override
  String get fitDaySelectorToWidth => 'Mahuta päevavalik ekraanile';

  @override
  String get fitDaySelectorToWidthHint =>
      'Võimaluse korral kuvatakse ekraanil kõik seitse päeva. Väljalülitamisel kasutatakse fikseeritud laiust ja kerimist.';

  @override
  String get fitWeekColumnsToWidth => 'Mahuta nädala veerud ekraanile';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Võimaluse korral kuvatakse ekraanil kõik seitse tunniplaani veergu. Väljalülitamisel kasutatakse fikseeritud laiust ja kerimist.';

  @override
  String get enableWeekSwipeNavigation => 'Vaheta nädalat pühkides';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Teisele nädalale liikumiseks pühi vasakule või paremale. Fikseeritud laiuse korral keri esmalt servani ja lohista sellest edasi.';

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
  String get outlineWidthUnit => 'px';

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
  String get microsoftStoreUpdates => 'Värskendusi haldab Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Eelväljalasete värskendused';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Kaasa Alpha-, Beta- ja RC-versioonid, mis võivad olla ebastabiilsed. Väljalülitatuna pakutakse ainult stabiilseid versioone.';

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
  String get googlePlay => 'Google Play';

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
      'GitHubist ei õnnestunud uusimat versiooni hankida. Saad siiski allpool avada GitHubi väljalasete lehe.';

  @override
  String get githubRepository => 'GitHubi hoidlus';

  @override
  String get googlePlayStoreDesc => 'Vaata Skedi Google Plays';

  @override
  String get openGooglePlayFailed => 'Google Play avamine nurjus';

  @override
  String get starSkedOnGithub => 'Lisa Skedile GitHubis täht!';

  @override
  String get starSkedOnGithubDesc => 'Ava projekti hoidla ja lisa Skedile täht';

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
  String get importAction => 'Impordi';

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
  String get periodTimesUnsavedExitTitle => 'Muudatused on salvestamata';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Tundide kellaaegade viimaseid muudatusi ei õnnestunud salvestada. Võid proovida uuesti, jätkata muutmist või muudatused hüljata.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Mõned tundide kellaajad on vigased. Paranda need enne salvestamist või hülga muudatused ja välju.';

  @override
  String get discardChangesAndExit => 'Hülga muudatused ja välju';

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
      'Skedi seadmerakendus salvestab tunniplaanid, üldised ajakavad, seotud seaded ja muudetavad kooliveebisaitide seaded operatsioonisüsteemi rakenduse tugikataloogi. Brauseriversioon kasutab brauseri salvestusruumi. Varasemate versioonide kasutaja dokumentide kausta salvestatud failid jäävad alles, kuid neid ei loeta ega migreerita automaatselt. Nende andmete säilitamiseks ekspordi enne uuendamist vanast versioonist rakenduse täielik varukoopia ja taasta see pärast uuendamist. AI API seaded salvestatakse kohalikult. Kohandatud API-võti salvestatakse võimaluse korral platvormi turvalisse salvestusruumi. Rakenduse täielikud varukoopiad ei sisalda kohandatud API-võtit. Rakendus ei laadi neid kohalikke andmeid automaatselt üles arendaja hallatavasse serverisse.';

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
  String get schoolSitesImportPreviewTitle =>
      'Vaata kooliveebisaitide import üle';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount kehtivat veebisaiti, $invalidCount vigast kirjet.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Failis on tühi kooliveebisaitide loend.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Kirje $position on vigane ja jäetakse vahele.';
  }

  @override
  String get schoolSitesImportMerge => 'Ühenda';

  @override
  String get schoolSitesImportReplace => 'Asenda';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Asendada praegused kooliveebisaidid?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'See eemaldab $currentCount praegust veebisaiti ja salvestab $importedCount imporditud veebisaiti. Seda ei saa tagasi võtta.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Kooliveebisaitide andmed vajavad taastamist';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked ei saanud lugeda kooliveebisaitide faili ega selle varukoopiat. Enne kirjutamise blokeerimist loodi kaitstud koopiad.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Kooliveebisaitide salvestusruum pole saadaval';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked ei pääse praegu kooliveebisaitide salvestusruumile ligi. Kontrolli salvestusruumi juurdepääsu või seadme kättesaadavust ja proovi uuesti. Olemasolevaid veebisaitide andmeid ei kirjutata üle.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Taastefailid või mõjutatud salvestuskohad on loetletud allpool. Ära muuda faile enne veebisaitide loendi taastamist.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Alusta ilma kooliveebisaitideta';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Alustada tühja kooliveebisaitide loendiga?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Kaitstud koopiad säilitatakse, kuid Sked loob uue tühja kooliveebisaitide faili. Jätka ainult siis, kui sa ei soovi esmalt taastamist uuesti proovida.';

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
      'Kohandatud parseri seadistus on puudulik. Sisesta esmalt baas-URL, API-võti ja mudel.';

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
  String get schoolImportParserSettingsTitle => 'Tunniplaani parsimise API';

  @override
  String get schoolImportParserSettingsDesc =>
      'Seadista OpenAI-ühilduv API tunniplaanide importimiseks, mitte vestlusabilise jaoks.';

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
      'Kohandatud API-võti salvestatakse võimaluse korral platvormi turvalisse salvestusruumi. Kasuta kohandatud parseri juurdepääsuandmeid ja HTTP-otspunkte ainult usaldusväärsetes seadmetes, brauserites ja võrkudes.';

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
  String get clearAppData => 'Kustuta andmed';

  @override
  String get clearAppDataDesc =>
      'Kustuta kõik kohalikud Skedi andmed jäädavalt ja sulge rakendus';

  @override
  String get clearAppDataConfirmTitle => 'Kustutada kõik Skedi andmed?';

  @override
  String get clearAppDataConfirmMessage =>
      'See kustutab jäädavalt tunniplaanid, ajakavad, seaded, kooliveebisaidid, kohalikud varukoopiad, taastekoopiad ja AI API-võtme ning sulgeb Skedi. Mujale eksporditud faile ei kustutata. Seda ei saa tagasi võtta.';

  @override
  String get clearAppDataAction => 'Kustuta andmed ja välju';

  @override
  String get clearAppDataFailed =>
      'Kõiki kohalikke andmeid ei õnnestunud kustutada. Sked jääb avatuks, et saaksid uuesti proovida.';

  @override
  String get clearAppDataExitFailed =>
      'Kohalikud andmed kustutati, kuid Skedi sulgemine nurjus. Sulge rakendus käsitsi enne selle uuesti kasutamist.';

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
  String get monthSeptember => 'september';

  @override
  String get monthOctober => 'oktoober';

  @override
  String get monthNovember => 'november';

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
  String get generalSchedule => 'Üldine ajakava';

  @override
  String get studentTimetable => 'Tunniplaan';

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
  String get switchMode => 'Vaheta režiimi';

  @override
  String get generalScheduleComingSoon => 'Üldine ajakava on peagi saadaval';

  @override
  String get switchToStudentTimetable => 'Lülitu tunniplaanile';

  @override
  String get mySchedule => 'Minu ajakava';

  @override
  String get today => 'Täna';

  @override
  String get addEvent => 'Lisa sündmus';

  @override
  String get editEvent => 'Muuda sündmust';

  @override
  String get eventTitle => 'Pealkiri';

  @override
  String get eventTitleRequired => 'Sisesta pealkiri';

  @override
  String get eventStartTime => 'Algusaeg';

  @override
  String get eventEndTime => 'Lõppaeg';

  @override
  String get eventDate => 'Kuupäev';

  @override
  String get eventTime => 'Kellaaeg';

  @override
  String get eventNotes => 'Märkmed';

  @override
  String get eventColor => 'Värv';

  @override
  String get eventRecurrence => 'Kordumine';

  @override
  String get recurrenceNone => 'Ei kordu';

  @override
  String get recurrenceWeekly => 'Iga nädal';

  @override
  String get recurrenceEndDate => 'Lõppkuupäev';

  @override
  String get recurrenceNoEndDate => 'Lõppkuupäev puudub';

  @override
  String get recurrenceSetEndDate => 'Määra';

  @override
  String get recurrenceChangeEndDate => 'Muuda';

  @override
  String get repeatsWeekly => 'Kordub iga nädal';

  @override
  String recurrenceUntil(Object date) {
    return 'Kuni $date';
  }

  @override
  String get switchToGeneralSchedule => 'Lülitu üldisele ajakavale';

  @override
  String get generalDisplaySettings => 'Ajakava kuvaseaded';

  @override
  String get generalDisplaySettingsDesc =>
      'Vaated, tööriistariba, kuupäevavorming ja kiirlisamine';

  @override
  String get closePopupOnOutsideTap =>
      'Sulge hüpikaken sellest väljaspool puudutamisel';

  @override
  String get showGridLines => 'Kuva ruudustiku jooned';

  @override
  String get generalScheduleImportExport => 'Kategooriate import ja eksport';

  @override
  String get generalScheduleImportExportDesc =>
      'Impordi või jaga ajakava kategooriaid';

  @override
  String get importGeneralSchedules => 'Impordi kategooriad';

  @override
  String get importGeneralSchedulesDesc => 'Loe kategooriad JSON-failist';

  @override
  String get shareGeneralSchedules => 'Jaga kategooriaid';

  @override
  String get shareGeneralSchedulesDesc => 'Jaga kategooriaid JSON-failina';

  @override
  String get saveGeneralSchedules => 'Salvesta kategooriad';

  @override
  String get saveGeneralSchedulesDesc => 'Salvesta kategooriad JSON-failina';

  @override
  String get selectSchedulesToExport => 'Vali eksporditavad kategooriad';

  @override
  String get selectSchedulesToImport => 'Vali imporditavad kategooriad';

  @override
  String generalScheduleEventCount(int count) {
    return 'Sündmusi: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Imporditi $count kategooriat';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Kas lisada import uue kategooriana või asendada olemasolev kategooria?';

  @override
  String get addAsNewSchedule => 'Lisa uue kategooriana';

  @override
  String get selectAtLeastOneScheduleMessage => 'Vali vähemalt üks kategooria.';

  @override
  String get noExportableScheduleMessage => 'Eksporditavaid kategooriaid pole.';

  @override
  String get noSchedulesInImportMessage =>
      'Impordifail ei sisalda kategooriaid.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Asendamiseks vali täpselt üks imporditud kategooria.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Asendamiseks valitud kategooria pole saadaval.';

  @override
  String get calendars => 'Kategooriad';

  @override
  String get calendar => 'Kategooria';

  @override
  String get viewWeek => 'Nädal';

  @override
  String get viewDay => 'Päev';

  @override
  String get viewList => 'Loend';

  @override
  String get viewMonth => 'Kuu';

  @override
  String visibleCategoryCount(int count) {
    return '$count kategooriat';
  }

  @override
  String get noVisibleCategories => 'Nähtavaid kategooriaid pole';

  @override
  String get selectCategoryToReplace => 'Vali asendatav kategooria';

  @override
  String get replaceCategory => 'Asenda kategooria';

  @override
  String get deleteEventTitle => 'Kustuta sündmus';

  @override
  String get deleteEventConfirmation => 'See sündmus kustutatakse jäädavalt.';

  @override
  String get deleteRecurringEventTitle => 'Kustuta korduv sündmus';

  @override
  String get eventDuplicated => 'Sündmus dubleeriti';

  @override
  String get searchEvents => 'Otsi sündmusi';

  @override
  String get clearSearch => 'Tühjenda otsing';

  @override
  String get filterByColor => 'Filtreeri värvi järgi';

  @override
  String get allColors => 'Kõik värvid';

  @override
  String upcomingEventsCount(int count) {
    return 'Tulemas: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Tähtaja ületanud: $count';
  }

  @override
  String get allDay => 'Kogu päev';

  @override
  String get collapseAllDayTimeline => 'Ahenda kogu päeva sündmused';

  @override
  String get expandAllDayTimeline => 'Laienda kogu päeva sündmused';

  @override
  String allDayEventsCount(int count) {
    return '$count kogu päeva sündmust';
  }

  @override
  String moreEvents(int count) {
    return '+$count veel';
  }

  @override
  String get noMatchingEvents => 'Vastavaid sündmusi pole';

  @override
  String get noUpcomingEvents => 'Tulevasi sündmusi pole';

  @override
  String get addCalendar => 'Lisa kategooria';

  @override
  String get newCalendar => 'Uus kategooria';

  @override
  String get hideCalendar => 'Peida kategooria';

  @override
  String get showCalendar => 'Kuva kategooria';

  @override
  String get rename => 'Nimeta ümber';

  @override
  String get renameCalendar => 'Nimeta kategooria ümber';

  @override
  String get name => 'Nimi';

  @override
  String get deleteCalendar => 'Kustuta kategooria';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Kustutada „$name“?';
  }

  @override
  String get deleteThisOccurrence => 'Kustuta see kord';

  @override
  String get deleteFutureOccurrences => 'Kustuta see ja järgnevad korrad';

  @override
  String get deleteAllOccurrences => 'Kustuta kogu sari';

  @override
  String get duplicateEvent => 'Dubleeri';

  @override
  String get repeatsDaily => 'Kordub iga päev';

  @override
  String get repeatsMonthly => 'Kordub iga kuu';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Kordub iga $interval $unit järel';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count korda';
  }

  @override
  String get recurrenceDaily => 'Iga päev';

  @override
  String get recurrenceMonthly => 'Iga kuu';

  @override
  String get recurrenceCustom => 'Kohandatud';

  @override
  String get recurrenceEvery => 'Iga';

  @override
  String get recurrenceUnit => 'Ühik';

  @override
  String get recurrenceDays => 'päeva';

  @override
  String get recurrenceWeeks => 'nädala';

  @override
  String get recurrenceMonths => 'kuu';

  @override
  String get recurrenceRepeatCount => 'Korduste arv';

  @override
  String get recurrenceNoLimit => 'Piiranguta';

  @override
  String get recurrencePositiveNumber => 'Sisesta positiivne arv';

  @override
  String get clearEndDate => 'Eemalda lõppkuupäev';

  @override
  String get pickDate => 'Vali kuupäev';

  @override
  String get pickTime => 'Vali kellaaeg';

  @override
  String get reminder => 'Rakendusesisene meeldetuletus';

  @override
  String get reminderAtStart => 'Algusajal';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes minutit varem';
  }

  @override
  String get reminderHourBefore => '1 tund varem';

  @override
  String get reminderDayBefore => '1 päev varem';

  @override
  String get markReminderHandled => 'Märgi käsitletuks';

  @override
  String get restoreReminder => 'Taasta rakendusesisene meeldetuletus';

  @override
  String get reminderHandled =>
      'Rakendusesisene meeldetuletus märgiti käsitletuks';

  @override
  String get reminderRestored => 'Rakendusesisene meeldetuletus taastati';

  @override
  String get reminderUpcoming => 'Tulemas';

  @override
  String get reminderOverdue => 'Tähtaeg möödunud';

  @override
  String get generalFitWeekColumnsToWidth => 'Mahuta nädal ekraanile';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Kuva kogu nädal kompaktses paigutuses. Lülita välja horisontaalseks kerimiseks. Üle 7 päeva pikkused kohandatud vahemikud jäävad keritavaks.';

  @override
  String get showWeekends => 'Kuva nädalavahetused';

  @override
  String get startHour => 'Algustund';

  @override
  String get endHour => 'Lõpptund';

  @override
  String get timeGridDensity => 'Ajaruudustiku tihedus';

  @override
  String get timeGridHourHeight => 'Tunnirea kõrgus';

  @override
  String get timeGridHourHeightHint =>
      'Muudab päeva- ja nädalavaate vertikaalset skaalat, muutmata ruudustiku 15-, 30- või 60-minutilist intervalli.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Impordi JSON-fail';

  @override
  String get pasteJson => 'Kleebi JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Impordi kategooriad kopeeritud JSON-ist';

  @override
  String get importIcsFile => 'Impordi ICS-fail';

  @override
  String get importIcsFileDesc => 'Loe sündmused .ics-kalendrifailist';

  @override
  String get pasteIcs => 'Kleebi ICS';

  @override
  String get pasteIcsDesc => 'Impordi sündmused kopeeritud kalendritekstist';

  @override
  String get copyJson => 'Kopeeri JSON';

  @override
  String get copyJsonDesc => 'Kopeeri valitud kategooriad JSON-tekstina';

  @override
  String get shareIcs => 'Jaga ICS-i';

  @override
  String get shareIcsDesc => 'Jaga valitud kalendreid .ics-failina';

  @override
  String get saveIcs => 'Salvesta ICS';

  @override
  String get saveIcsDesc => 'Salvesta valitud kalendrid .ics-failina';

  @override
  String get copyIcs => 'Kopeeri ICS';

  @override
  String get copyIcsDesc => 'Kopeeri valitud kalendrid ICS-tekstina';

  @override
  String get importIcs => 'Impordi ICS';

  @override
  String get icsContent => 'ICS-i sisu';

  @override
  String get pasteIcsContentHint => 'Kleebi siia BEGIN:VCALENDAR sisu';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Leiti $count sündmust. Kas lisada need uue kategooriana või asendada olemasolev kategooria?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Imporditi $count kategooriat, hoiatusi: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Algusajata sündmus jäeti vahele.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Toetamata algusajaga sündmus jäeti vahele.';

  @override
  String get importWarningAdjustedEnd =>
      'Kohandati sündmust, mille lõppaeg ei olnud algusajast hilisem.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Toetamata ICS-väljad lisati märkmetesse: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Toetamata kordussagedust eirati: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs => 'Vali ICS-ina kopeeritavad kalendrid';

  @override
  String get selectCalendarsToExportIcs =>
      'Vali ICS-ina eksporditavad kalendrid';

  @override
  String get exportIcsText => 'Ekspordi ICS-tekst';

  @override
  String get exportJsonText => 'Ekspordi JSON-tekst';

  @override
  String get dataRestoredFromBackupNotice =>
      'Rakenduse andmed taastati eelmisest varukoopiast, sest põhifaili ei õnnestunud laadida.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Nii põhiandmefail kui ka selle varukoopia on kahjustatud. Rakendus kasutab nüüd uusi andmeid.';

  @override
  String get dataRecoveryCorruptTitle => 'Sinu andmed vajavad taastamist';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked ei saanud lugeda põhiandmefaili ega selle varukoopiat. Enne kirjutamise blokeerimist loodi kaitstud koopiad.';

  @override
  String get dataRecoveryIoFailureTitle => 'Salvestusruum pole saadaval';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked ei pääse praegu kohalikule salvestusruumile ligi. Kontrolli salvestusruumi juurdepääsu või seadme kättesaadavust ja proovi uuesti. Olemasolevaid andmeid ei kirjutata üle.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Nende andmete avamiseks uuenda Skedi';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Need andmed loodi Skedi uuema versiooniga. Enne uuesti proovimist uuenda rakendust. Andmete kaitsmiseks on uute andmetega alustamine keelatud.';

  @override
  String get dataRecoveryRetryAction => 'Proovi uuesti';

  @override
  String get dataRecoveryArtifactsHint =>
      'Taastefailid või mõjutatud salvestuskohad on loetletud allpool. Ära muuda faile enne andmete taastamist.';

  @override
  String get dataRecoveryArtifactsAction => 'Kuva taastefailid ja asukohad';

  @override
  String get dataRecoveryStartFreshAction => 'Alusta uute andmetega';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Alustada uute andmetega?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Kaitstud koopiad säilitatakse, kuid Sked loob uue kohaliku andmefaili. Jätka ainult siis, kui sa ei soovi esmalt taastamist uuesti proovida.';

  @override
  String get previousMonth => 'Eelmine kuu';

  @override
  String get nextMonth => 'Järgmine kuu';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Pooleli';

  @override
  String get deleteCourseTitle => 'Kustuta kursus';

  @override
  String get deleteCourseMessage => 'Kustutada see kursus?';

  @override
  String get showLunarCalendar => 'Kuva kuukalender';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count sündmust';
  }

  @override
  String get defaultView => 'Vaikevaade';

  @override
  String get generalDefaultViewSection => 'Käivitamisel';

  @override
  String get generalViewSwitchBehavior => 'Vaate vahetamise nupp';

  @override
  String get settingsWorkspaceMode => 'Aktiivne tööruum';

  @override
  String get hideHomeWorkspaceNavigation => 'Peida tööruumide navigeerimine';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Peida tööruumide navigeerimine. Tööruumi saab endiselt vahetada põhikuva menüüst.';

  @override
  String get generalDateLabelFormat => 'Kuupäevasildi vorming';

  @override
  String get generalDateLabelFormatLocalized => 'Kohalik (juuli 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Kaldkriipsuga (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Tööriistariba paigutus';

  @override
  String get toolbarNavigationSection => 'Tööriistariba navigeerimine';

  @override
  String get toolbarNavigationHiddenBehavior => 'Peidetud üksused';

  @override
  String get toolbarNavigationRemove => 'Peida täielikult';

  @override
  String get toolbarNavigationMore => 'Teisalda menüüsse Rohkem';

  @override
  String get toolbarNavigationReorder =>
      'Muuda tööriistariba üksuste järjekorda';

  @override
  String get toolbarNavigationVisibility => 'Kuva tööriistariba üksus';

  @override
  String get toolbarNavigationTimetable => 'Tunniplaani valik';

  @override
  String get toolbarNavigationWeek => 'Nädala valik';

  @override
  String get toolbarNavigationView => 'Vaate vahetus';

  @override
  String get toolbarNavigationCategory => 'Kategooria valik';

  @override
  String get toolbarNavigationDate => 'Kuupäeva valik';

  @override
  String get generalToolbarWidthPolicy => 'Tööriistariba ruumi jaotus';

  @override
  String get generalToolbarWidthContent => 'Automaatne jaotus';

  @override
  String get generalToolbarWidthBalanced => 'Võrdne jaotus';

  @override
  String get generalToolbarWidthCalendarPriority => 'Kategooria eelistus';

  @override
  String get generalToolbarWidthDatePriority => 'Kuupäeva eelistus';

  @override
  String get generalViewSwitchCycle => 'Vaheta vaateid järjest';

  @override
  String get generalViewSwitchMenu => 'Ava vaadete menüü';

  @override
  String get generalViewSwitchTooltip => 'Vaheta vaadet';

  @override
  String get generalViewSwitchMenuTooltip => 'Vali vaade';

  @override
  String get generalViewLongPressTodayHint =>
      'Tänasele liikumiseks vajuta pikalt';

  @override
  String get generalScheduleDisplaySection => 'Ajakava kuvamine';

  @override
  String get generalTimeGridSection => 'Ajaruudustik';

  @override
  String get generalPopupSection => 'Hüpikakna käitumine';

  @override
  String get quickActionsSection => 'Kiirtoimingud';

  @override
  String get showAddCourseFab => 'Kuva kursuse lisamise ujuvnupp';

  @override
  String get showAddCourseFabHint =>
      'Kuva või peida kursuse lisamise ujuvnupp tunniplaani paremas alanurgas.';

  @override
  String get showAddEventFab => 'Kuva sündmuse lisamise ujuvnupp';

  @override
  String get showAddEventFabHint =>
      'Kuva või peida sündmuse lisamise ujuvnupp ajakava paremas alanurgas.';

  @override
  String get enableLongPressAddCourse =>
      'Lisa kursus tühja ruudustikku pikalt vajutades';

  @override
  String get enableLongPressAddCourseHint =>
      'Kursuse lisamiseks vajuta pikalt tunniplaani ruudustiku tühja ala.';

  @override
  String get enableLongPressAddEvent =>
      'Lisa sündmus tühja ruudustikku pikalt vajutades';

  @override
  String get enableLongPressAddEventHint =>
      'Sündmuse lisamiseks vajuta päeva- või nädalavaates pikalt ajaruudustiku tühja ala.';

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
  String get developerNotificationDiagnostics => 'Teavituste diagnostika';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Kontrolli Androidi teavituste edastuse olekut, loo olemasolev meeldetuletuste plaan uuesti ja saada ohutuid testteavitusi Skedi tavapärase teavitusteenuse kaudu.';

  @override
  String get developerNotificationUnsupported =>
      'Teavituste diagnostika on saadaval ainult Androidis.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Teavituste diagnostika muutub kättesaadavaks pärast ajakava koordinaatori käivitumist.';

  @override
  String get developerNotificationRefresh => 'Värskenda diagnostikat';

  @override
  String get developerNotificationSystemStatus => 'Süsteemi teavitusluba';

  @override
  String get developerNotificationPermissionAllowed => 'Lubatud';

  @override
  String get developerNotificationPermissionBlocked => 'Blokeeritud';

  @override
  String get developerNotificationExactAlarm => 'Täpsed alarmid';

  @override
  String get developerNotificationExactAlarmAllowed => 'Lubatud';

  @override
  String get developerNotificationExactAlarmBlocked => 'Pole lubatud';

  @override
  String get developerNotificationPlan => 'Ajakava teavituste plaan';

  @override
  String get developerNotificationCoverage => 'Meeldetuletuste kaetus';

  @override
  String get developerNotificationCoverageReady =>
      'Kõik teadaolevad lõpliku korduste arvuga meeldetuletused on otse ajastatud';

  @override
  String get developerNotificationCoverageRenewable =>
      'Korduvate meeldetuletuste pikaajalist ajastust uuendatakse võimaluste piires';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Otseajastuse piir on täis. Hilisemaid meeldetuletusi püütakse uuendada võimaluste piires';

  @override
  String get developerNotificationCoverageBlocked =>
      'Täpse edastuse nõuded pole täidetud';

  @override
  String get developerNotificationCoverageFailed =>
      'Viimane meeldetuletuste sünkroonimine nurjus';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled otse ajastatud alarmi / piir $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled ajastatud, $planned kavandatud';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Viimane viga: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Loo teavituste plaan uuesti';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Teavituste plaan loodi uuesti.';

  @override
  String get developerNotificationTestChannel => 'Testkanal';

  @override
  String get developerNotificationTestCourse => 'Kursuste meeldetuletused';

  @override
  String get developerNotificationTestSchedule => 'Ajakava meeldetuletused';

  @override
  String get developerNotificationImmediateTest => 'Saada testteavitus kohe';

  @override
  String get developerNotificationThirtySecondTest =>
      'Ajasta taustatest 30 sekundi pärast';

  @override
  String get developerNotificationImmediateQueued =>
      'Testteavitus saadeti kohe.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Taustatest ajastati 30 sekundi pärast.';

  @override
  String get developerNotificationAppSwitch =>
      'Rakenduse meeldetuletuste lüliti';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Tavalised meeldetuletused on lubatud';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Tavalised meeldetuletused on keelatud; arendajateste saab endiselt käivitada';

  @override
  String get developerNotificationTimeZone => 'Kohalik ajavöönd';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Pole veel loodud. Arendajatest loob selle.';

  @override
  String get developerNotificationChannelEnabledState => 'Lubatud';

  @override
  String get developerNotificationChannelBlockedState => 'Blokeeritud';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Tähtsus: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Tähtsus pole saadaval';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending ootel / $active aktiivset';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Süsteem kuvas viimati: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Ümberarvutust pole veel salvestatud.';

  @override
  String get developerNotificationNextReminder =>
      'Järgmine tavaline meeldetuletus';

  @override
  String get developerNotificationNoPendingReminder =>
      'Praeguses plaanis pole tulevasi meeldetuletusi';

  @override
  String get developerNotificationNextMaintenance => 'Järgmine hooldus';

  @override
  String get developerNotificationNextRenewal =>
      'Järgmine ajastuse uuendamise katse';

  @override
  String get developerNotificationNoMaintenance => 'Pole ajastatud';

  @override
  String get developerNotificationTruncation => 'Plaani kärpimine';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Plaani piirangu tõttu jäeti välja $count';
  }

  @override
  String get developerNotificationLastReconciliation => 'Viimane ümberarvutus';

  @override
  String get developerNotificationLastSynchronization =>
      'Viimane meeldetuletuste sünkroonimine';

  @override
  String get developerNotificationLateRecovery =>
      'Hilinenud meeldetuletuste taastamine';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Pärast algset kellaaega taastati ja edastati $count meeldetuletust';
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
  String get developerNotificationReconcileOriginForeground => 'Esiplaan';

  @override
  String get developerNotificationReconcileOriginBackground => 'Taust';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Täielik ümberarvutus';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Hooldus';

  @override
  String get developerNotificationReconcileModeRecovery => 'Taastamine';

  @override
  String get developerNotificationRunRecovery =>
      'Käivita meeldetuletuste taastamine';

  @override
  String get developerNotificationRecoveryComplete =>
      'Meeldetuletuste taastamine on lõpetatud';

  @override
  String get developerNotificationReconcileResultSuccess => 'Õnnestus';

  @override
  String get developerNotificationReconcileResultSkipped => 'Vahele jäetud';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Ajastamine on blokeeritud, kuni kõik täpse edastuse tingimused on täidetud';

  @override
  String get developerNotificationReconcileResultFailed => 'Nurjus';

  @override
  String get developerNotificationBackgroundLimits => 'Tootja taustapiirangud';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Tootja taustapiirangud võivad edastust mõjutada.';

  @override
  String get developerNotificationAutostart => 'Tootja taustakäivitus';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Tootja: $vendor. Tootja seadete otsetee on saadaval. Android ei saa selle loa olekut näidata.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Tootja: $vendor. Kasutatakse rakenduse teabe lehte. Android ei saa selle loa olekut näidata.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Tootja taustaseadete otsetee pole saadaval.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Viimati avatud leht: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor => 'tootja seaded';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'rakenduse teave';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'puudub';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Taaskäivitamisjärgse taastamise piirangud';

  @override
  String get developerNotificationRebootBoundary =>
      'Taastamine algab pärast esimest avamist lukustusest. Sunniviisiliselt peatatud rakendus ei saa ise käivituda.';

  @override
  String get developerNotificationTestChecking =>
      'Testid pole saadaval, kuni teavituste olekut kontrollitakse.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Testid pole saadaval, sest süsteemi teavitused on blokeeritud.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Testid pole saadaval, sest valitud teavituskanal on blokeeritud.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Hallatakse Windowsi teavitusseadetes';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Ei kehti Windowsis';

  @override
  String get developerNotificationWindowsIdentity =>
      'Windowsi paketi identiteet';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX-i identiteet on saadaval; kuvatud teavitusi saab eemaldada';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Kuvatud teavituste usaldusväärseks eemaldamiseks installi MSIX-i versioon';

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
  String get notificationSettingsSection => 'Meeldetuletused ja teavitused';

  @override
  String get notificationCoverage => 'Meeldetuletuste kaetus';

  @override
  String get notificationCoverageRenewable =>
      'Lõppkuupäevata korduvate sündmuste meeldetuletuste ajastust uuendatakse taustal, et säilitada pikaajaline kaetus.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android saab otse ajastada kuni $capacity meeldetuletust. Hilisemaid meeldetuletusi püütakse ajastada eelneva uuendamisega.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Luba meeldetuletused ja teavitused';

  @override
  String get notificationSettingsEnabledHint =>
      'Teavitused ajastatakse ainult meeldetuletusega üksustele. Määra allpool vaikemeeldetuletus kursustele, mis seda kasutavad.';

  @override
  String get notificationPrecisionLimitations =>
      'Meeldetuletused sõltuvad süsteemi õigustest ja taustal töötamisest. Väljalülitamine, kellaaja muutmine või süsteemi piirangud võivad neid edasi lükata.';

  @override
  String get notificationSettingsEnabledSummary => 'Lubatud';

  @override
  String get notificationSettingsDisabledSummary => 'Keelatud';

  @override
  String get notificationDefaultsSection => 'Vaikemeeldetuletused';

  @override
  String get notificationCourseDefaultReminder => 'Kursuste vaikemeeldetuletus';

  @override
  String get notificationGeneralDefaultReminder => 'Ajakava vaikemeeldetuletus';

  @override
  String get notificationReminderOff => 'Meeldetuletuseta';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minutit varem';
  }

  @override
  String get notificationPermission => 'Teavitusluba';

  @override
  String get notificationPermissionGranted => 'Süsteem on lubanud';

  @override
  String get notificationPermissionDenied => 'Süsteem on blokeerinud';

  @override
  String get notificationPermissionChecking => 'Loa kontrollimine…';

  @override
  String get notificationPermissionRequest => 'Taotle luba';

  @override
  String get notificationPermissionOpenSettings => 'Ava süsteemi seaded';

  @override
  String get notificationPermissionRequestFailed =>
      'Teavitusloa lugemine nurjus. Proovi uuesti.';

  @override
  String get notificationExactAlarm => 'Täpsete alarmide luba';

  @override
  String get notificationExactAlarmAllowed => 'Süsteem on lubanud';

  @override
  String get notificationExactAlarmRequired =>
      'Vajalik meeldetuletuste täpseks ajastamiseks';

  @override
  String get notificationExactAlarmRequest => 'Luba täpsed alarmid';

  @override
  String get notificationBatteryOptimization => 'Aku optimeerimine';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Androidi aku optimeerimise erand on lubatud';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Täpsed meeldetuletused vajavad Androidi aku optimeerimise erandit';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Ava aku optimeerimise seaded';

  @override
  String get notificationAutostart => 'Tootja taustakäivitus';

  @override
  String get notificationAutostartVendorHint =>
      'Luba automaatne käivitamine või taustal töötamine, et meeldetuletused saaks pärast taaskäivitamist taastada.';

  @override
  String get notificationAutostartFallbackHint =>
      'Ava Skedi rakenduse teave ja luba taustal töötamine. Android ei saa seda tootja seadet kontrollida.';

  @override
  String get notificationAutostartUnavailable =>
      'Tootja seadete lehte ei leitud. Kontrolli Skedi rakenduse teavet käsitsi.';

  @override
  String get notificationAutostartRequest => 'Ava tootja taustaseaded';

  @override
  String get notificationAutostartOpenFailed =>
      'Tootja taustaseadete avamine nurjus. Kontrolli Skedi rakenduse teavet käsitsi.';

  @override
  String get notificationLockScreenTitles => 'Kuva pealkirjad lukustuskuval';

  @override
  String get notificationLockScreenTitlesHint =>
      'Väljalülitamisel peidetakse lukustuskuval teavituste üksikasjad.';

  @override
  String get notificationWidgets => 'Avakuva vidinad';

  @override
  String get notificationWidgetsDesc =>
      'Värskenda Skedi vidinaid ja vaata, kuidas neid avakuvale lisada.';

  @override
  String get notificationWidgetsDialogTitle => 'Lisa Skedi vidin';

  @override
  String get notificationWidgetsDialogMessage =>
      'Vajuta seadme avakuval pikalt tühjale alale, vali Vidinad ja lisa Skedi vidin. Vidin kuvab järgmisi kursusi või sündmusi.';

  @override
  String get notificationWidgetsRefresh => 'Värskenda vidinaid';

  @override
  String get notificationWidgetsRefreshed => 'Vidinad värskendati';

  @override
  String get notificationPlatformUnsupported =>
      'See platvorm ei toeta süsteemi teavitusi.';

  @override
  String get workspaceFeatures => 'Funktsioonide haldus';

  @override
  String get workspaceBoth => 'Tunniplaan ja kalender';

  @override
  String get workspaceOnlyStudent => 'Ainult tunniplaan';

  @override
  String get workspaceOnlyGeneral => 'Ainult kalender';

  @override
  String get workspaceDisableTitle => 'Kas lülitada see tööruum välja?';

  @override
  String get workspaceDisableMessage =>
      'Andmed ja eelistused säilivad. Funktsioonid ja meeldetuletused peatatakse, kuni lülitad tööruumi siin uuesti sisse.';

  @override
  String get workspaceEnableHint =>
      'Vali kasutatavad funktsioonid. Vähemalt üks peab jääma sisse.';

  @override
  String get workspaceLastRequired => 'Vähemalt üks tööruum peab jääma sisse.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Tööruum on välja lülitatud, kuid meeldetuletusi ei saanud eemaldada. Proovi teavituste taastamist uuesti.';

  @override
  String get settingsSearch => 'Otsi seadeid';

  @override
  String get settingsNoResults => 'Vastavaid seadeid ei leitud';

  @override
  String get settingsDataPrivacy => 'Andmed ja privaatsus';

  @override
  String get workspacePreferences => 'Kuva ja juhtimine';

  @override
  String get workspaceManage => 'Halda';

  @override
  String get selectedDayAgenda => 'Valitud päev';

  @override
  String get notificationTroubleshooting => 'Õigused ja tõrkeotsing';

  @override
  String get settingsConnection => 'Ühendus';

  @override
  String get settingsAdvanced => 'Täpsemad seaded';

  @override
  String get unsavedChangesMessage =>
      'Sul on salvestamata muudatusi. Kas loobuda neist ja lahkuda?';

  @override
  String get backupWorkspaceSelection =>
      'Täielik varukoopia sisaldab andmeid ja sisselülitatud tööruumide valikut.';

  @override
  String get assistantLayoutPreview => 'AI · Paigutuse eelvaade';

  @override
  String get assistantSelectionContext =>
      'Kasutab praegust valikut kontekstina';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Sõnumi mustand';

  @override
  String get assistantPreviewNoSend =>
      'Ainult paigutuse eelvaade. Midagi ei saadeta ega muudeta.';

  @override
  String get resizePanel => 'Muuda paneeli suurust';

  @override
  String get minimizeWindow => 'Minimeeri';

  @override
  String get maximizeWindow => 'Maksimeeri';

  @override
  String get restoreWindow => 'Taasta aken';

  @override
  String get closeWindow => 'Sulge aken';

  @override
  String get courseSystemReminder => 'Süsteemi meeldetuletus';

  @override
  String courseReminderInherit(String reminder) {
    return 'Kasuta vaikeseadet ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Süsteemi meeldetuletused on teavitusseadetes välja lülitatud. Selle kursuse eelistuse saab siiski salvestada.';

  @override
  String get courseReminderDefaultOff =>
      'Kursuste vaikemeeldetuletust pole määratud. Vali siin kohandatud meeldetuletus või määra vaikemeeldetuletus teavitusseadetes.';

  @override
  String get courseReminderDeliveryHint =>
      'See eelistus salvestatakse koos kursusega. Edastus sõltub süsteemi teavituslubadest ja taustapiirangutest.';

  @override
  String get courseReminderPermissionUnknown =>
      'Süsteemi teavituste olekut pole kontrollitud. Enne meeldetuletustele lootmist vaata teavitusseaded üle.';

  @override
  String get courseReminderMinutesLabel => 'Minutit enne tundi';

  @override
  String get exportAction => 'Ekspordi';

  @override
  String get datePickerSelectWeek => 'Vali nädal';

  @override
  String get datePickerSelectMonth => 'Vali kuu';

  @override
  String get generalDateLabelFormatDescription =>
      'Kehtib kuupäevade navigeerimisele arvutis ja väiksematel ekraanidel.';

  @override
  String get dateRangeTitle => 'Vali kuupäevavahemik';

  @override
  String get dateRangeCustom => 'Kohandatud';

  @override
  String get dateRangeChooseStart => 'Vali alguskuupäev';

  @override
  String get dateRangeChooseEnd => 'Vali lõppkuupäev';

  @override
  String get dateRangeLimit =>
      'Vali 1–14 päeva, mõlemad lõppkuupäevad kaasa arvatud.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days päeva',
      one: '1 päev',
    );
    return 'Kohandatud · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Vali kerimisratastega';

  @override
  String get courseReminderUseDefault => 'Kasuta vaikeseadet';

  @override
  String get courseReminderInvalidMinutes =>
      'Sisesta täisarv minuteid, null või suurem.';

  @override
  String get generalCustomColumnWidth => 'Kohandatud vaate veerulaius';

  @override
  String get generalCustomColumnWidthAuto => 'Automaatne';

  @override
  String get generalCustomColumnWidthManual => 'Vähim laius';

  @override
  String get generalCustomColumnWidthMinimum => 'Vähim laius päeva kohta';

  @override
  String get generalCustomColumnWidthHint =>
      'Kõik kuupäevad kasutavad sama vähimat laiust. Veerud täidavad vaba ruumi või neid saab horisontaalselt kerida. Mõjutab ainult kohandatud vaadet.';

  @override
  String get settingsAppearanceLanguage => 'Välimus ja keel';

  @override
  String get settingsAppearanceDetails => 'Värvid ja piirjooned';

  @override
  String get monthNoEvents => 'Sel päeval pole sündmusi';

  @override
  String get settingsOverview => 'Ülevaade';

  @override
  String get settingsThemeTarget => 'Teema siht';

  @override
  String get settingsColorMode => 'Värvirežiim';

  @override
  String get settingsNotificationPreferences => 'Meeldetuletuste eelistused';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Vaikemeeldetuletused, load ja töökindlus';

  @override
  String get settingsFeaturesSummary => 'Tööruumid ja navigeerimine';

  @override
  String get settingsPrivacySummary =>
      'Privaatsuspoliitika ja kohalike andmete kustutamine';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tundi',
      one: '1 tund',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Tund';

  @override
  String get periodTimesDurationColumn => 'Kestus';

  @override
  String get periodTimesGapColumn => 'Vahetund';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Salvestamise ootel…';

  @override
  String get periodTimesSaveFailed => 'Salvestamata · Salvestamine nurjus';

  @override
  String get periodTimesInvalidStatus =>
      'Salvestamata · Paranda esile tõstetud kellaajad';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked ei saanud kinnitada, kas viimane salvestamine võeti tagasi. Kirjutamine on peatatud ja taastekoopiad säilitatud. Kontrollige salvestusruumi ja proovige uuesti laadida.';

  @override
  String get settingsPanelDisplayMode => 'Paneelide kuvamine';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Ühine tunniplaanidele ja kalendritele';

  @override
  String get settingsPanelDisplayOverlay => 'Ülekate';

  @override
  String get settingsPanelDisplaySideBySide => 'Kõrvuti';

  @override
  String get settingsPanelDisplayAutomatic => 'Automaatne';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Katab parema külje kalendri laiust muutmata.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Eelistab kõrvuti kuvamist; katab kalendri ainult siis, kui see jääks liiga kitsaks.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Kuvab kõrvuti, kui kalender jääb loetavaks, muidu ülekattena.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Tööriistaribal Seadete või Tööruumi väljalülitamine viib selle menüüsse Rohkem ega eemalda seda. Menüüd Rohkem ei saa peita, kui see sisaldab olulisi toiminguid. Tööruumide vahetamine kuvatakse ainult siis, kui alumine navigeerimisriba on peidetud ja mitu tööruumi on lubatud.';

  @override
  String get reminderEnded => 'Lõppenud';

  @override
  String get reminderAutoCloseHint =>
      'Sulgub 10 sekundi pärast. Avatuks jätmiseks kasuta paneeli.';

  @override
  String get showReminderIndependently => 'Ava eraldi';

  @override
  String get categoryManagerTitle => 'Halda kategooriaid';

  @override
  String get categoryHidden => 'Peidetud';

  @override
  String get categoryShowOnCalendar => 'Kuva kalendris';

  @override
  String get categoryHideOnCalendar => 'Peida kalendrist';

  @override
  String get categoryEditColor => 'Muuda kategooria värvi';

  @override
  String get categoryThemePalette => 'Teema värvipalett';

  @override
  String get categoryCustomColor => 'Kohandatud';

  @override
  String get colorHexInvalid =>
      'Sisesta kuuekohaline kuueteistkümnendsüsteemis värvikood.';

  @override
  String categoryColorSlot(int number) {
    return 'Teema värv $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Poe uuendused võivad hilineda. Saadavust näitab poe leht.';

  @override
  String get storePrereleaseNotice =>
      'Eelväljalasete uuenduste teavituste saamine ei liida sind poe testprogrammiga.';

  @override
  String get updateFoundTitle => 'Uus versioon on saadaval';

  @override
  String get updateNoNotes => 'Väljalaskemärkmeid pole lisatud.';

  @override
  String get updateLater => 'Hiljem';

  @override
  String get updateRetry => 'Proovi uuesti';

  @override
  String get updatePrerelease => 'Eelväljalase';

  @override
  String get updateNetworkFailure =>
      'Uuenduste kontrollimine nurjus. Kontrolli ühendust ja proovi uuesti.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Uuemat versiooni ei leitud (praegune: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Varukoopia taastamine…';

  @override
  String get backupRestoreInProgressMessage =>
      'Andmeid ja seadeid saab muuta pärast taastamise lõppu. Neid saab endiselt vaadata.';
}
