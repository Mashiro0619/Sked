// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppLocalizationsSl extends AppLocalizations {
  AppLocalizationsSl([String locale = 'sl']) : super(locale);

  @override
  String get appTitle => 'Učitelj';

  @override
  String weekLabel(int week) {
    return 'Teden $week';
  }

  @override
  String get addCourse => 'Dodaj smer';

  @override
  String get settings => 'Nastavitve';

  @override
  String get multiTimetableSwitch => 'Zamenjaj vozni red';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Trenutni urnik · $weeks tednov';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Tapnite za preklop · $weeks tednov';
  }

  @override
  String get editTimetable => 'Uredi urnik';

  @override
  String get schoolImportResultEditorTitle => 'Edit parsed result';

  @override
  String get schoolImportParsePageTitle => 'Razčleni urnik';

  @override
  String get schoolImportParsePageParsing => 'Razčlenjevanje…';

  @override
  String get schoolImportParsePageFailed => 'Razčlenjevanje ni uspelo';

  @override
  String get schoolImportParsePageComplete => 'Razčlenjevanje končano';

  @override
  String get schoolImportParsePageContinue => 'Nadaljuj';

  @override
  String get schoolImportParsePageRawContent => 'Surov odgovor';

  @override
  String get schoolImportParsePageExpandRaw => 'Razširi surov odgovor';

  @override
  String get schoolImportParsePageCollapseRaw => 'Strni surov odgovor';

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
  String get createTimetable => 'Nov časovni razpored';

  @override
  String get jumpToWeek => 'Skoči na teden';

  @override
  String get timetable => 'Časovni razpored';

  @override
  String get themeWorkspaceSchedule => 'Schedule';

  @override
  String get timetableName => 'Ime urnika';

  @override
  String get timetableNameRequired => 'Timetable name is required';

  @override
  String get totalWeeks => 'Skupaj tedni';

  @override
  String get delete => 'Zbriši';

  @override
  String get cancel => 'Prekliči';

  @override
  String get save => 'Shrani';

  @override
  String get deleteTimetableTitle => 'Izbriši časovni razpored';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Izbriši \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Časovnega razporeda še ni';

  @override
  String get noTimetableMessage =>
      'Ustvarite urnik ali ga uvozite iz datoteke JSON.';

  @override
  String get importTimetable => 'Uvozni časovni razpored';

  @override
  String get courseName => 'Ime tečaja';

  @override
  String get location => 'Lokacija';

  @override
  String get dayOfWeek => 'Dan';

  @override
  String get semesterWeeks => 'Tedni';

  @override
  String get startTime => 'Začetni čas';

  @override
  String get endTime => 'Končni čas';

  @override
  String get linkedPeriods => 'Povezana obdobja';

  @override
  String get linkedPeriodsUnmatched =>
      'Obdobja se za trenutni čas ne ujemajo. Tapnite, da izberete ročno.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Obdobje $start-$end';
  }

  @override
  String get teacherName => 'Učitelj';

  @override
  String get credits => 'Krediti';

  @override
  String get remarks => 'Opombe';

  @override
  String get customFields => 'Polja po meri';

  @override
  String get customFieldsHint => 'Ena na vrstico, oblika: ključ: value';

  @override
  String get more => 'Več';

  @override
  String get selectDayOfWeek => 'Izberite dan';

  @override
  String get selectSemesterWeeks => 'Izberite tedne';

  @override
  String get selectAll => 'Izberi vse';

  @override
  String get clear => 'Počisti';

  @override
  String get confirm => 'Potrdi';

  @override
  String get selectLinkedPeriods => 'Izberite povezana obdobja';

  @override
  String get addCourseTitle => 'Dodaj smer';

  @override
  String get editCourseTitle => 'Uredi smer';

  @override
  String get editCourseTooltip => 'Uredi smer';

  @override
  String get place => 'Lokacija';

  @override
  String get time => 'Čas';

  @override
  String get notFilled => 'Ni napolnjeno';

  @override
  String get none => 'Brez';

  @override
  String get conflictCourses => 'Nasprotujoči tečaji';

  @override
  String get locationNotFilled => 'Lokacija ni zapolnjena';

  @override
  String get setAsDisplayed => 'Nastavi kot prikazano';

  @override
  String get editThisCourse => 'Uredi ta tečaj';

  @override
  String get settingsTitle => 'Nastavitve';

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
      'Trenutno ni na voljo nobenega urnika za nastavitve.';

  @override
  String get semesterStartDate => 'Datum začetka semestra';

  @override
  String get periodTimeSets => 'Določen čas obdobja';

  @override
  String get noPeriodTimeAvailable => 'Ni nastavljenega obdobja';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return '$name · $count obdobja';
  }

  @override
  String get coursePopupDismissSetting =>
      'Dovoli zunanji tap, da zaprete pojavno okno smeri';

  @override
  String get coursePopupDismissSettingHint =>
      'Če to izklopite, onemogočite tudi odpustitev podrska navzdol.';

  @override
  String get preserveTimetableGaps => 'Ohranitev vrzeli v časovnem razporedu';

  @override
  String get preserveTimetableGapsHint =>
      'Ko je izklopljeno, se vrzeli za kosilo in prelom zrušijo, tako da se kasnejši razredi premaknejo navzgor.';

  @override
  String get showPastEndedCourses => 'Prikaži pretekle tečaje';

  @override
  String get showPastEndedCoursesHint =>
      'Prikaži tečaje, ki so že končali do resničnega tekočega tedna s svetlejšim sivim slogom.';

  @override
  String get showFutureCourses => 'Prikaži prihodnje tečaje';

  @override
  String get showFutureCoursesHint =>
      'Prikaži tečaje, ki ta teden niso aktivni, vendar se bodo pojavili v poznejših tednih s sivim slogom.';

  @override
  String get timetableDisplaySettings => 'Prikaz urnika in interakcija';

  @override
  String get timetableDisplaySettingsDesc =>
      'Prikaz predmetov, postavitev, tedenske poteze in hitro dodajanje';

  @override
  String get showTimetableGridLines => 'Prikaži črte mreže urnika';

  @override
  String get showTimetableGridLinesHint =>
      'Nadzorujte, ali so vodoravne in navpične mrežne črte vidne v voznem redu.';

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
  String get liveCourseOutlineColor => 'Barva orisa tečaja';

  @override
  String get liveCourseOutlineColorHint =>
      'Izberite, ali so obrisi usmerjeni v trenutni/naslednji tečaj ali vse prikazane tečaje na trenutni strani.';

  @override
  String get liveCourseOutlineSettings => 'Opis tečaja';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Nastavite, ali je oris omogočen, kaj cilja, ali sledi barvi teme in učinkoviti barvi orisa.';

  @override
  String get liveCourseOutlineEnabled => 'Omogoči oris';

  @override
  String get liveCourseOutlineFollowTheme => 'Sledi barvi teme';

  @override
  String get liveCourseOutlineTarget => 'Osnovni cilj';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Trenutni/naslednji tečaj';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Vsi prikazani tečaji';

  @override
  String get liveCourseOutlineEffectiveColor => 'Učinkovita barva';

  @override
  String get liveCourseOutlineCustomColor => 'Barva orisa po meri';

  @override
  String get liveCourseOutlineWidth => 'Širina orisa';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Jezik';

  @override
  String get languagePageDescription =>
      'Izberite enega od jezikov, ki je resnično na voljo v aplikaciji.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'angleščina';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Odziv API';

  @override
  String get theme => 'Tema';

  @override
  String get themeFollowSystem => 'Sistem sledenja';

  @override
  String get themeLight => 'Svetloba';

  @override
  String get themeDark => 'Temna';

  @override
  String get themeColor => 'Barva teme';

  @override
  String get themeColorModeSingle => 'Barva ene teme';

  @override
  String get themeColorModeColorful => 'Barvno';

  @override
  String get themeColorUiColors => 'Barve uporabniškega vmesnika';

  @override
  String get themeColorCourseColors => 'Barve tečaja';

  @override
  String get themeColorPrimary => 'Primarni';

  @override
  String get themeColorSecondary => 'Sekundarni';

  @override
  String get themeColorTertiary => 'Terciarna';

  @override
  String get themeColorCourseText => 'Besedilo tečaja';

  @override
  String get themeColorCourseTextAuto => 'Samodejno';

  @override
  String get themeColorCourseTextCustom => 'Barva po meri';

  @override
  String get themeColorCourseColorsEmpty =>
      'Barve tečaja bodo ustvarjene po uvozu urnika.';

  @override
  String get themeCustomColor => 'Barva po meri';

  @override
  String get themeApplyCustomColor => 'Uporabi barvo';

  @override
  String get themeApplySettings => 'Uporabi nastavitve';

  @override
  String get dataImportExport => 'Podatki o uvozu in izvozu';

  @override
  String get dataImportExportDesc =>
      'Uvozite celotne podatke ali posamezne vozne redi ali izvozite trenutne/vse vozne redi.';

  @override
  String get appBackupTitle => 'Varnostna kopija in obnovitev aplikacije';

  @override
  String get appBackupSubtitle =>
      'Varnostno kopirajte ali obnovite urnike, razporede, nastavitve in šolska spletna mesta. Ključi API niso vključeni.';

  @override
  String get appBackupSheetSubtitle =>
      'Popolna obnovitev zamenja trenutne podatke aplikacije. Ključi AI API so v varni shrambi in se ne zapišejo v datoteke varnostne kopije.';

  @override
  String get restoreBackupFileTitle => 'Obnovi iz datoteke JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Izberite popolno datoteko varnostne kopije Sked. Pred obnovitvijo boste potrdili izbiro.';

  @override
  String get restoreBackupTextTitle => 'Prilepi JSON varnostne kopije';

  @override
  String get restoreBackupTextSubtitle =>
      'Prilepite popolno varnostno kopijo in obnovite trenutne podatke aplikacije.';

  @override
  String get shareBackupTitle => 'Deli datoteko varnostne kopije';

  @override
  String get shareBackupSubtitle =>
      'Izvozite vse podatke aplikacije kot JSON. Ključi API so izključeni.';

  @override
  String get saveBackupTitle => 'Shrani datoteko varnostne kopije';

  @override
  String get saveBackupSubtitle =>
      'Shranite popolno varnostno kopijo aplikacije v lokalno datoteko.';

  @override
  String get copyBackupTitle => 'Kopiraj besedilo varnostne kopije';

  @override
  String get copyBackupSubtitle =>
      'Prikaže celoten JSON varnostne kopije, da ga lahko kopirate ali začasno shranite.';

  @override
  String get restoreBackupConfirmTitle => 'Obnovim popolno varnostno kopijo?';

  @override
  String get restoreBackupConfirmMessage =>
      'To bo zamenjalo vse trenutne urnike, splošne razporede, nastavitve in šolska spletna mesta. Ključi API se ne uvozijo iz varnostnih kopij; pred ponovnim razčlenjevanjem urnikov znova vnesite ključ.';

  @override
  String get restoreBackupConfirmAction => 'Obnovi varnostno kopijo';

  @override
  String get restoreBackupSuccessMessage =>
      'Popolna varnostna kopija aplikacije je obnovljena. Ključe AI API je treba znova vnesti.';

  @override
  String get restoreBackupFailureMessage =>
      'Obnovitev ni uspela. Preverite vsebino varnostne kopije in poskusite znova.';

  @override
  String get openSourceLicenses => 'Odprtokodne licence';

  @override
  String get openSourceLicensesDesc =>
      'Oglejte si licence za odvisnosti Flutter in združena sredstva ikon aplikacij.';

  @override
  String get checkForUpdates => 'Preveri posodobitve';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Že na najnovejši različici ($version)';
  }

  @override
  String get currentVersionLabel => 'Trenutna različica';

  @override
  String get newVersionAvailable => 'Na voljo je posodobitev';

  @override
  String get latestVersionLabel => 'Najnovejša različica';

  @override
  String get updateContentLabel => 'Podrobnosti o posodobitvi';

  @override
  String get officialWebsite => 'Uradna spletna stran';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Pogon v oblaku';

  @override
  String get ignoreThisVersion => 'Prezri to različico';

  @override
  String get openUpdatesFailed => 'Ni moč odpreti povezave za posodobitev';

  @override
  String get updateCheckFailedTitle => 'Preverjanje posodobitve ni uspelo';

  @override
  String get updateCheckFailedMessage =>
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Skladišče GitHub';

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
      'Ni moč odpreti povezave za repozitorij GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Povezave do pravilnika o zasebnosti ni mogoče odpreti';

  @override
  String get selectPeriodTimeSet => 'Izberite nastavljeno obdobje';

  @override
  String get newItem => 'Novo';

  @override
  String get editPeriodTimeSet => 'Uredi nastavljeno obdobje';

  @override
  String get importTimetableFiles => 'Uvozni časovni razpored';

  @override
  String get importTimetableFilesDesc => 'Podpira eno ali več datotek urnika.';

  @override
  String get importTimetableText => 'Uvozni časovni razpored iz besedila';

  @override
  String get importTimetableTextDesc =>
      'Prilepite vsebino JSON urnika in jo uvozite.';

  @override
  String get shareTimetableFiles => 'Deli datoteke s časovnim razporedom';

  @override
  String get shareTimetableFilesDesc =>
      'Najprej izberite enega ali več voznih redov.';

  @override
  String get saveTimetableFiles => 'Shrani datoteke s časovnim razporedom';

  @override
  String get saveTimetableFilesDesc =>
      'Najprej izberite enega ali več voznih redov.';

  @override
  String get exportTimetableText => 'Časovni razpored izvoza kot besedilo';

  @override
  String get exportTimetableTextDesc =>
      'Izberite enega ali več voznih redov in kopirajte vsebino JSON.';

  @override
  String get jsonContent => 'Vsebina JSON';

  @override
  String get pasteJsonContentHint => 'Prilepi vsebino JSON za uvoz.';

  @override
  String get jsonContentEmpty => 'Najprej prilepi vsebino JSON.';

  @override
  String get copyText => 'Kopiraj';

  @override
  String get copiedToClipboard => 'Kopirano v odložišče';

  @override
  String get share => 'Delež';

  @override
  String get selectTimetablesToExport => 'Izberite časovne razporede za izvoz';

  @override
  String get selectTimetablesToImport => 'Izberite časovne razporede za uvoz';

  @override
  String timetableCourseCount(int count) {
    return '$count tečaji';
  }

  @override
  String get importAction => 'Uvozi';

  @override
  String get importTimetableDialogTitle => 'Uvozni časovni razpored';

  @override
  String get chooseImportMethod => 'Izberite, kako uvoziti.';

  @override
  String get importAsNewTimetable => 'Uvoz kot nov časovni razpored';

  @override
  String get replaceCurrentTimetable => 'Zamenjaj trenutni časovni razpored';

  @override
  String get importPeriodTimeSetDialogTitle => 'Časovni nizi obdobja uvoza';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Ta datoteka vsebuje združene nabore časovnih obdobj. Ali jih želite uvoziti in povezati?';

  @override
  String get importBundledPeriodTimeSets => 'Uvozi in povezuj';

  @override
  String get discardBundledPeriodTimeSets => 'Zavrzite pakete';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Obstoječih časovnih nastavitev obdobja ni na voljo, zato združenih časovnih nizov obdobja ni mogoče zavreči.';

  @override
  String savedToPath(Object path) {
    return 'Shranjeno v $path';
  }

  @override
  String get saveCancelled => 'Shranjevanje preklicano';

  @override
  String get fileSaveRestrictedTitle => 'Shranjevanje datotek omejeno';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Sistem ni mogel shraniti datoteke. Namesto tega lahko znova poskusite ali uporabite skupno rabo.';

  @override
  String get retrySave => 'Poskusi znova shraniti';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Omogočite dostop do datotek v sistemskih nastavitvah, nato pa se vrnite in poskusite znova izvoziti.';

  @override
  String get openSettings => 'Odpri nastavitve';

  @override
  String get browserDownloadRestrictedTitle => 'Prenos brskalnika omejen';

  @override
  String get browserDownloadRestrictedMessage =>
      'Ta brskalnik ne podpira neposrednega shranjevanja v lokalno datoteko. Preverite dovoljenja za prenos brskalnika ali namesto tega uporabite skupno rabo datotek.';

  @override
  String get switchToShare => 'Namesto tega uporabi skupno rabo';

  @override
  String get fileSaveFailedTitle => 'Shranjevanje datoteke ni uspelo';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Ni moč pisati na trenutno pot. Ciljna mapa je lahko zaščitena, datoteka je lahko v uporabi ali pot ni mogoče napisati.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Sistem ni mogel shraniti datoteke. Lahko znova poskusite, preverite sistemske nastavitve ali namesto tega uporabite skupno rabo datotek.';

  @override
  String get retryLater => 'Poskusi kasneje znova.';

  @override
  String get exportSwitchedToShare =>
      'Preklopil na skupno rabo datotek za izvoz';

  @override
  String get saveFailedRetry =>
      'Shranjevanje ni uspelo. Prosim, poskusite kasneje znova.';

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
  String get appInstanceBlockedTitle => 'Sked je že odprt';

  @override
  String get appInstanceBlockedMessage =>
      'Drugo okno aplikacije Sked ali zavihek brskalnika uporablja vaše lokalne podatke. Zaprite drugo okno oziroma zavihek in poskusite znova.';

  @override
  String get appInstanceLeaseFailedTitle => 'Lokalni podatki niso na voljo';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked ni mogel potrditi izključnega dostopa do lokalnih podatkov. Vaši podatki niso bili odprti ali spremenjeni. Preverite dostop do shrambe in poskusite znova.';

  @override
  String get savingChanges => 'Shranjevanje sprememb...';

  @override
  String get showApiKey => 'Prikaži ključ API';

  @override
  String get hideApiKey => 'Skrij ključ API';

  @override
  String get importFailedCheckContent =>
      'Uvoz ni uspel. Prosim preverite vsebino datoteke.';

  @override
  String get noImportableTimetables =>
      'V uvoženi datoteki niso našli uporabnih urnikov.';

  @override
  String importedTimetablesCount(int count) {
    return 'Uvoženi vozni redi $count';
  }

  @override
  String get periodTimesTitle => 'Obdobje';

  @override
  String get importExport => 'Uvoz in izvoz';

  @override
  String get importPeriodTemplate => 'Predloga za uvoz obdobja';

  @override
  String get importPeriodTemplateText => 'Uvozi predlogo obdobja iz besedila';

  @override
  String get sharePeriodTemplate => 'Predloga obdobja deljenja';

  @override
  String get saveTemplateToFile => 'Shrani predlogo v datoteko';

  @override
  String get exportPeriodTemplateText => 'Izvozi predlogo obdobja kot besedilo';

  @override
  String get deletePeriodTimeSet => 'Izbriši nastavljeno obdobje';

  @override
  String get periodTimeSetName => 'Ime nastavljenega časa obdobja';

  @override
  String get addOnePeriod => 'Dodaj obdobje';

  @override
  String periodNumberLabel(int index) {
    return 'Obdobje $index';
  }

  @override
  String get deleteThisPeriod => 'Črtaj to obdobje';

  @override
  String durationMinutes(int minutes) {
    return 'Trajanje $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Vrzel od prejšnjega $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'Končni čas mora biti poznejši od začetnega časa';

  @override
  String get periodOverlapPrevious => 'To obdobje se prekriva s prejšnjim';

  @override
  String get periodTimesSaved => 'Obdobje shranjeno';

  @override
  String get deletePeriodTimeSetTitle => 'Izbriši nastavljeno obdobje';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Izbriši \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'določen čas trenutnega obdobja';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Uvoženi $count časi obdobja';
  }

  @override
  String get periodFilePermissionTitle => 'Potrebno je dovoljenje za datoteko';

  @override
  String get androidFilePermissionMessage =>
      'Izvoz Android zahteva dovoljenje za dostop do datotek. Daj dovoljenje za nadaljnje shranjevanje.';

  @override
  String get reauthorize => 'Ponovno odobri';

  @override
  String get permissionPermanentlyDeniedTitle => 'Dovoljenje trajno zavrnjeno';

  @override
  String get permissionSettingsExportMessage =>
      'Omogočite dostop do datotek v sistemskih nastavitvah, nato pa se vrnite in poskusite znova izvoziti.';

  @override
  String get privacyPolicyTitle => 'Pravilnik o zasebnosti';

  @override
  String get privacyPolicyEntryDesc =>
      'Preberite, kako aplikacija obravnava lokalno shranjevanje, konfiguracijo šolskega mesta, uvoz/izvoz datotek, razčlenjevanje spletnih strani in zunanje povezave.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Sprejeta različica: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked je orodje za urnike, ki daje prednost lokalni hrambi. Urniki, nabori obdobij in konfiguracija šolskega mesta so shranjeni samo v vaši napravi ali brskalniku in se nikoli ne naložijo samodejno. Aplikacija obdeluje podatke samo, ko izrecno sprožite dejanja, kot so uvoz, razčlenjevanje spletnih strani, deljenje ali odpiranje zunanjih povezav. Celotna politika zasebnosti je na voljo na spletu.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokalno shranjevanje';

  @override
  String get privacyPolicyLocalStorageBody =>
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. AI API settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

  @override
  String get privacyPolicyImportExportTitle => 'Uvoz in izvoz';

  @override
  String get privacyPolicyImportExportBody =>
      'Aplikacija bere ali piše datoteke JSON urnika, datoteke JSON šolskega mesta in datoteke predloge obdobja samo, ko izrecno izberete datoteko ali začnete izvozno dejanje. Uvoz teh datotek je lokalna operacija, razen če izberete tudi razčlenitev spletne strani. Pridobivanje seznama modelov po meri je tudi izrecno omrežno dejanje in kontaktira le končno točko po meri, ki ste jo konfigurirali.';

  @override
  String get privacyPolicySharingTitle => 'Delitev';

  @override
  String get privacyPolicySharingBody =>
      'Ko izrecno uporabljate skupno rabo, program prenese izvoženo datoteko na list skupne rabe sistema ali ciljni program, ki ga izberete. Način uporabe te datoteke je odvisen od ciljne aplikacije ali storitve, ki ste jo izbrali.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Zunanje povezave';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Ko odprete zunanje povezave, kot je repozitorij GitHub, aplikacija prenese dejanje vašemu brskalniku ali drugi zunanji aplikaciji. Obdelavo podatkov po tej točki ureja tretja oseba, ki jo odprete.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Kaj aplikacija ne zbira';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Aplikacija ne zahteva računa Sked in ne omogoča analitike, oglaševalskih identifikatorjev ali varnostne kopije v oblaku. Prav tako ne zagotavlja namenskega polja za zbiranje gesel šolskih računov. Če se v aplikaciji vpišete na spletno mesto šole, se ta interakcija zgodi na strani šole, ki ste jo odprli.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Razčlenitev spletnih strani';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Ko uporabite uvoz šolske spletne strani ali analizirate prilepljeno besedilo urnika / HTML, aplikacija vsebino najprej pripravi in očisti lokalno, nato pa pošlje poslano besedilo urnika, besedilo strani ali vsebino HTML, izbirni naslov strani in URL, trenutni jezik aplikacije ter vsebino poziva parserja na končno točko, združljivo z OpenAI, ki ste jo nastavili. Pridobivanje seznama modelov prav tako zahteva isto končno točko. Sked ne ponuja vgrajene končne točke parserja in zahtev za analizo ne pošilja v zaledje parserja urnikov, ki bi ga nadzoroval razvijalec. Končna točka po meri in morebitne nadrejene storitve lahko podatke shranjujejo, posredujejo, omejujejo, brišejo ali drugače obdelujejo v skladu s pravili izbranega ponudnika storitev. Če uporabljate http:// Base URL, ga uporabljajte samo na zaupanja vrednih napravah, omrežjih in storitvah končne točke, ker vsebina in ključi API morda niso zaščiteni s transportnim šifriranjem.';

  @override
  String get privacyPolicyUpdatesTitle => 'Posodobitve pravilnika';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Trenutna različica politike zasebnosti je $version. Če poznejša različica spremeni način ravnanja s podatki, vas lahko aplikacija zahteva, da znova preberete posodobljeni pravilnik in se z njim strinjate.';
  }

  @override
  String get privacyGateTitle =>
      'Prosimo, strinjajte se s politiko zasebnosti pred uporabo aplikacije';

  @override
  String get privacyGateSummaryStorage =>
      'Časovni razporedi, nabori obdobja in konfiguracija šolskega mesta so shranjeni le lokalno in se ne naložijo samodejno v strežnik razvijalcev.';

  @override
  String get privacyGateSummaryImportExport =>
      'Uvoz, izvoz in skupna raba se zgodijo le, ko jih izrecno zaženete; Razčlenjevanje spletne strani pošlje samo stisnjeno vsebino, ki jo pošljete na konfigurirano končno točko razčlenjanja, preden shranite, pa lahko pregledate razčlenjen časovni razpored.';

  @override
  String get privacyGateSummaryUpdates =>
      'Če poznejša različica spremeni način ravnanja s podatki, vas lahko aplikacija zahteva, da znova pregledate posodobljeni pravilnik o zasebnosti.';

  @override
  String get schoolWebImportEntry => 'Uvozi s spletne strani šole';

  @override
  String get schoolWebImportEntryDesc =>
      'Uvozi trenutno stran voznega reda s spletnega mesta šole.';

  @override
  String get schoolSitesManageEntry => 'Upravljanje šolskih spletnih mest';

  @override
  String get schoolSitesManageEntryDesc =>
      'Dodajanje, urejanje in brisanje šolskih prijavnih URL-jev z uvozom in izvozom JSON.';

  @override
  String get schoolSitesPageTitle => 'Upravljanje šolskih lokacij';

  @override
  String get schoolSitesImportJson => 'Uvozna šola JSON';

  @override
  String get schoolSitesShareJson => 'Deli šolo JSON';

  @override
  String get schoolSitesSaveJson => 'Shrani šolo JSON';

  @override
  String get schoolSitesSaved => 'Shranjena šolska mesta';

  @override
  String get schoolSitesImported => 'Uvožena šolska mesta';

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
  String get schoolSitesEmpty => 'Šolska lokacija še ni konfiguracije.';

  @override
  String get schoolSitesNameLabel => 'Ime šole';

  @override
  String get schoolSitesLoginUrlLabel => 'URL za prijavo';

  @override
  String get schoolSitesAdd => 'Dodaj šolo';

  @override
  String get schoolSitesEdit => 'Uredi šolo';

  @override
  String get schoolSitesDeleteTitle => 'Izbriši šolo';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Izbriši \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Najprej vnesite ime šole in URL za prijavo.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Uvoz z lepljenjem vsebine strani s časovnim razporedom';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Ročno prilepite izvorno kodo ali neobdelano vsebino strani, ki vsebuje informacije o urniku.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Razčleni časovni razpored iz vsebine strani';

  @override
  String get schoolHtmlImportUrlLabel => 'Izvorni URL (neobvezno)';

  @override
  String get schoolHtmlImportTitleLabel => 'Naslov strani (neobvezno)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Vsebina strani';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Tukaj prilepite izvorno kodo ali neobdelano vsebino strani, ki vsebuje informacije o urniku.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Vsako vsebino, ki vsebuje informacije o voznem redu, je mogoče razčleniti in uvoziti, ne samo HTML.';

  @override
  String get schoolHtmlImportCompress => 'Pripravi vsebino';

  @override
  String get schoolHtmlImportCompressed => 'Vsebina pripravljena';

  @override
  String get schoolHtmlImportCompressFirst => 'Najprej pripravite vsebino.';

  @override
  String get schoolHtmlImportSubmit => 'Razčlenitev in uvoz';

  @override
  String get schoolImportContentTruncated =>
      'Ta stran je dosegla varno omejitev uvoza. V razčlenjevanje bo poslan samo zajeti del.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Razčlenitev bo trajala nekaj časa. Prosim, počakajte.';

  @override
  String get schoolHtmlImportEmpty => 'Najprej prilepi HTML strani.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Nazaj na spletno stran';

  @override
  String get schoolWebImportPageTitle => 'Uvoz spletne strani šole';

  @override
  String get schoolWebImportPreview => 'Uvozi predogled';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count tečaji';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count obdobja';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Naslov strani';

  @override
  String get schoolWebImportParserUsed => 'Razčlenjevalnik';

  @override
  String get schoolWebImportWarnings => 'Uvozi opombe';

  @override
  String get schoolWebImportParserDetails => 'Podrobnosti razčlenjevanja';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Razširi podrobnosti razčlenjevanja';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Strni podrobnosti razčlenjevanja';

  @override
  String get schoolWebImportOpenPageHint =>
      'Vpišite se v šolsko spletno mesto v aplikaciji in se ročno pomaknite na stran s časovnim razporedom.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Ta platforma še ne podpira vdelane spletne prijave. Prosimo, uporabite platformo s podporo WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Izberite šolo';

  @override
  String get schoolWebImportNoSchools =>
      'Šolska nastavitev ni na voljo. Najprej preveri school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Ni uspelo naložiti šolske nastavitve. Preverite obliko datoteke JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Uvozi trenutno stran';

  @override
  String get schoolWebImportLoadingPage => 'Nalaganje strani...';

  @override
  String get schoolWebImportParsing => 'Razčlenitev trenutne strani...';

  @override
  String get schoolWebImportLoadFailed =>
      'Nalaganje strani ni uspelo. Osvežite ali poskusite znova kasneje.';

  @override
  String get schoolWebImportUnknownOrigin => 'Neznano spletno mesto';

  @override
  String get schoolWebImportExitTitle => 'Ali želite zapustiti brskalnik?';

  @override
  String get schoolWebImportExitMessage =>
      'Stran se bo zaprla. Vse, česar še niste uvozili, bo izgubljeno.';

  @override
  String get schoolWebImportExitConfirm => 'Zapusti';

  @override
  String get schoolWebImportEmptyPage =>
      'Trenutna vsebina strani je prazna in je še ni mogoče uvoziti.';

  @override
  String get schoolWebImportSuccess => 'Uvožen spletni urnik';

  @override
  String get schoolImportParserSettingsTitle => 'AI API configuration';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure the OpenAI-compatible API used by timetable parsing and other AI features.';

  @override
  String get schoolImportParserSourceTitle => 'Vir razčlenjevanja';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Po meri združljiv z OpenAI';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Razčlenjevalnik po meri, združljiv z OpenAI';

  @override
  String get schoolImportParserCustomPromptTitle => 'Poziv po meri';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Uredi vgrajen poziv razčlenjevalnika tukaj. Spremembe vplivajo samo na razčlenjevalnik, združljiv z OpenAI po meri.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Vgrajeni poziv je privzeto naložen tukaj. Počistite ga, da se vrnete na vgrajeno različico.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Ponastavi privzeti poziv';

  @override
  String get schoolImportParserBaseUrl => 'Osnovni URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL mora biti naslov HTTP ali HTTPS z gostiteljem.';

  @override
  String get schoolImportParserApiKey => 'Ključ API';

  @override
  String get schoolImportParserModel => 'Vzorec';

  @override
  String get schoolImportParserFetchModels => 'Pridobi seznam modelov';

  @override
  String get schoolImportParserFetchingModels => 'Dobivam modele. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Do končne točke modelov niso vrnili.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Modelov ni bilo mogoče pridobiti. Preverite končno točko in poskusite znova.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Pridobljeni modeli $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Želite uporabiti nešifrirano končno točko HTTP?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Ključ API in vsebina urnika sta med prenosom lahko prebrana ali spremenjena. Nadaljujte le, če zaupate tej napravi, omrežju in končni točki. Odobritev velja, dokler ne zaprete aplikacije Sked.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Nastavitev razčlenjevalnika po meri je nepopolna. Najprej izpolnite osnovni URL, API ključ in model.';

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
    return 'Razčlenitev: po meri ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Oglejte si celoten pravilnik o zasebnosti';

  @override
  String get privacyAgreeAndContinue => 'Strinjam se in nadaljujem';

  @override
  String get privacyDecline => 'Zavrni';

  @override
  String get privacyDeclineWebHint =>
      'To okolje brskalnika ne dovoljuje aplikaciji, da zapre stran za vas. Če se ne strinjate, zaprite ta zavihek ali okno sami.';

  @override
  String get defaultPeriodTimeSetName => 'Privzeta obdobja';

  @override
  String get periodTimeSetFallbackName => 'Obdobje';

  @override
  String get untitledTimetableName => 'Brez naslova vozni red';

  @override
  String get newTimetableName => 'Nov časovni razpored';

  @override
  String get newPeriodTimeSetName => 'Novo določeno obdobje';

  @override
  String get emptyTimetableName => 'Prazen urnik';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name obdobja';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Vrsta uvoza datoteke se ne ujema.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Različica uvozne datoteke še ni podprta.';

  @override
  String get noPeriodTimesInImportMessage =>
      'V uvozni datoteki ni bilo časa obdobja.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Prosimo, izberite vsaj en urnik.';

  @override
  String get noExportableTimetableMessage => 'Za izvoz ni razporeda.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Zamenjava sedanjega voznega reda podpira samo izbiro enega voznega reda.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Trenutnega časovnega razporeda ni za nadomestitev.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'To določeno obdobje še vedno uporabljajo $count urniki. Prerazporedite jih preden izbrišete.';
  }

  @override
  String get weekdayMonday => 'Ponedeljek';

  @override
  String get weekdayTuesday => 'Torek';

  @override
  String get weekdayWednesday => 'Sreda';

  @override
  String get weekdayThursday => 'Četrtek';

  @override
  String get weekdayFriday => 'Petek';

  @override
  String get weekdaySaturday => 'Sobota';

  @override
  String get weekdaySunday => 'Nedelja';

  @override
  String get weekdayShortMonday => 'Naslednji mesec';

  @override
  String get weekdayShortTuesday => 'Tor';

  @override
  String get weekdayShortWednesday => 'sreda';

  @override
  String get weekdayShortThursday => 'četrt';

  @override
  String get weekdayShortFriday => 'pet';

  @override
  String get weekdayShortSaturday => 'Sat';

  @override
  String get weekdayShortSunday => 'Sonce';

  @override
  String get monthJanuary => 'Jan';

  @override
  String get monthFebruary => 'februar';

  @override
  String get monthMarch => 'Mar';

  @override
  String get monthApril => 'Apr';

  @override
  String get monthMay => 'Maj';

  @override
  String get monthJune => 'Jun';

  @override
  String get monthJuly => 'jul';

  @override
  String get monthAugust => 'avg';

  @override
  String get monthSeptember => 'sept.';

  @override
  String get monthOctober => 'okt.';

  @override
  String get monthNovember => 'Nov';

  @override
  String get monthDecember => 'Dec.';

  @override
  String get semesterWeeksWholeTerm => 'Cel semester';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Tedni $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Tedni $value';
  }

  @override
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

  @override
  String get firstLaunchTitle => 'Izberite začetni način';

  @override
  String get firstLaunchSubtitle =>
      'Izberite delovni prostor, ki ga najpogosteje uporabljate. Način lahko pozneje zamenjate.';

  @override
  String get firstLaunchStudentDesc =>
      'Upravljajte urnike, predmete, tedne, čase ur in uvoze.';

  @override
  String get firstLaunchGeneralDesc =>
      'Upravljajte kategorije, dogodke, opomnike in podatke JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Začni z urnikom';

  @override
  String get firstLaunchStartGeneral => 'Začni z razporedom';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Z izbiro začetnega delovnega prostora potrjujete, da ste prebrali in sprejeli ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Pravilnik o zasebnosti';

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
  String get today => 'Danes';

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
      'Pogledi, orodna vrstica, oblika datuma in hitro dodajanje';

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
  String get viewWeek => 'Teden';

  @override
  String get viewDay => 'Dan';

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
  String get developerModeTitle => 'Način za razvijalce';

  @override
  String get developerModeDescription =>
      'Orodja za dodajanje celovitih vzorčnih podatkov za preverjanje videza in uporabe.';

  @override
  String get developerSampleLanguage => 'Jezik vzorčnih podatkov';

  @override
  String get developerSampleChinese => 'Kitajščina';

  @override
  String get developerSampleEnglish => 'Angleščina';

  @override
  String get developerSampleDataDescription =>
      'Doda en urnik ter nabor kategorij in dogodkov, ne da bi zamenjal obstoječe podatke.';

  @override
  String get developerAddSampleData => 'Dodaj vzorčne podatke';

  @override
  String get developerSampleDataAdded => 'Vzorčni urnik in dogodki so dodani.';

  @override
  String get developerModeLongPressHint =>
      'Za odprtje načina za razvijalce pridržite 3 sekunde';

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
      'Strni krmarjenje po delovnem prostoru';

  @override
  String get expandWorkspaceNavigation =>
      'Razširi krmarjenje po delovnem prostoru';

  @override
  String get schoolWebImportExitBrowser => 'Zapri vgrajeni brskalnik';

  @override
  String get schoolWebImportEditAddress => 'Uredi naslov';

  @override
  String get schoolWebImportAddressLabel => 'Spletni naslov';

  @override
  String get schoolWebImportOpenAddress => 'Odpri';

  @override
  String get schoolWebImportAddressInvalid =>
      'Vnesite naslov HTTP ali HTTPS z gostiteljem.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Ta spletna stran je zahtevala novo okno, ki ga v tej napravi ni mogoče odpreti.';

  @override
  String get schoolWebImportSecureConnection => 'Varna povezava';

  @override
  String get schoolWebImportInsecureConnection => 'Nevarna povezava';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Želite odpreti prijavo v šolski sistem?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Prijava v šolski sistem lahko prek obrazcev ali preusmeritev strežnika pošlje poverilnice šoli in njenim ponudnikom prijave. Android ne more ustaviti vsakega takega prenosa za ločeno potrditev cilja. Nadaljujte le, če jim zaupate za to sejo uvoza:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Odprem nezaščiteno prijavo v šolski sistem?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Ta prijava v šolski sistem uporablja HTTP. Kdor lahko spremlja ali spreminja to povezavo, lahko prebere ali spremeni vaše poverilnice in vsebino strani. Nadaljujte le, če sprejemate to tveganje za:\n\n$origin';
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
