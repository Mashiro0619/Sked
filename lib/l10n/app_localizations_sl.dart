// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppLocalizationsSl extends AppLocalizations {
  AppLocalizationsSl([String locale = 'sl']) : super(locale);

  @override
  String get appTitle => 'Sked';

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
  String get schoolImportResultEditorTitle => 'Uredi rezultat razčlenjevanja';

  @override
  String get schoolImportParsePageTitle => 'Razčleni urnik';

  @override
  String get schoolImportParsePageParsing => 'Razčlenjevanje…';

  @override
  String get schoolImportParsePageFailed => 'Razčlenjevanje ni uspelo';

  @override
  String get schoolImportParseErrorMessage =>
      'Urnika ni bilo mogoče razčleniti. Preverite vsebino, nastavitve razčlenjevalnika in omrežno povezavo ter poskusite znova.';

  @override
  String get schoolImportParsePageContinue => 'Nadaljuj';

  @override
  String get schoolImportExpandWarnings => 'Razširi opozorila o uvozu';

  @override
  String get schoolImportCollapseWarnings => 'Skrči opozorila o uvozu';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Nekateri predmeti potekajo do vključno $week. tedna.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle => 'Zamenjam trenutni urnik?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Uvoženi urnik bo zamenjal trenutnega.';

  @override
  String get createTimetable => 'Nov časovni razpored';

  @override
  String get jumpToWeek => 'Skoči na teden';

  @override
  String get timetable => 'Časovni razpored';

  @override
  String get themeWorkspaceSchedule => 'Urnik';

  @override
  String get timetableName => 'Ime urnika';

  @override
  String get timetableNameRequired => 'Vnesite ime urnika';

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
  String get customFieldsInvalidJson =>
      'Vnesite veljaven objekt JSON ali počistite polje.';

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
  String get settingsSectionAppearance => 'Videz';

  @override
  String get settingsSectionWorkspace => 'Delovni prostor';

  @override
  String get settingsSectionAbout => 'O aplikaciji Sked';

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
  String get timetableHorizontalLayoutSection =>
      'Vodoravna postavitev in poteze';

  @override
  String get fitDaySelectorToWidth => 'Prilagodi izbirnik dni zaslonu';

  @override
  String get fitDaySelectorToWidthHint =>
      'Če je mogoče, prikaže vseh sedem dni na zaslonu. Izklopite za nespremenljivo širino in vodoravno pomikanje.';

  @override
  String get fitWeekColumnsToWidth => 'Prilagodi tedenske stolpce zaslonu';

  @override
  String get enableWeekSwipeNavigation => 'Podrsnite za menjavo tedna';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Podrsnite levo ali desno za menjavo tedna. Pri nespremenljivi širini se najprej pomaknite do roba in nato povlecite naprej.';

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
  String get includePrereleaseUpdates => 'Prejemaj predizdaje';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Vključi različice Alpha, Beta in RC, ki so lahko nestabilne. Če je izklopljeno, so na voljo le stabilne različice.';

  @override
  String get currentVersionLabel => 'Trenutna različica';

  @override
  String get newVersionAvailable => 'Na voljo je posodobitev';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get ignoreThisVersion => 'Prezri to različico';

  @override
  String get openUpdatesFailed => 'Ni moč odpreti povezave za posodobitev';

  @override
  String get updateCheckFailedTitle => 'Preverjanje posodobitve ni uspelo';

  @override
  String get githubRepository => 'Skladišče GitHub';

  @override
  String get googlePlayStoreDesc =>
      'Ogled aplikacije Sked v trgovini Google Play';

  @override
  String get openGooglePlayFailed => 'Trgovine Google Play ni mogoče odpreti';

  @override
  String get microsoftStoreDesc =>
      'Ogled aplikacije Sked v trgovini Microsoft Store';

  @override
  String get openMicrosoftStoreFailed =>
      'Trgovine Microsoft Store ni mogoče odpreti';

  @override
  String get starSkedOnGithub => 'Podelite Skedu zvezdico na GitHubu!';

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
  String get studentDayEmpty => 'Ta dan ni pouka';

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
  String get periodTimesUnsavedExitTitle => 'Spremembe niso shranjene';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Zadnjih sprememb časov šolskih ur ni bilo mogoče shraniti. Lahko poskusite znova, nadaljujete urejanje ali zavržete spremembe.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Nekateri časi šolskih ur niso veljavni. Pred shranjevanjem jih popravite ali zavrzite spremembe in zapustite stran.';

  @override
  String get discardChangesAndExit => 'Zavrzi in zapusti';

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
      'Sked je orodje za urnike, ki daje prednost lokalnemu shranjevanju. Urniki, splošni načrti, nabori časov učnih ur in nastavitve šolskih spletnih mest so shranjeni samo v vaši napravi ali brskalniku in se nikoli ne nalagajo samodejno. Aplikacija obdeluje podatke samo, ko izrecno sprožite dejanja, kot so uvoz, razčlenjevanje besedila / HTML urnika, uvoz šolske spletne strani, deljenje ali odpiranje zunanjih povezav. Celotna politika zasebnosti je na voljo na spletu.';

  @override
  String get privacyGateTitle =>
      'Prosimo, strinjajte se s politiko zasebnosti pred uporabo aplikacije';

  @override
  String get privacyGateSummaryStorage =>
      'Urniki, splošni načrti, nabori časov učnih ur in nastavitve šolskih spletnih mest se shranjujejo samo lokalno in se ne nalagajo samodejno na strežnik razvijalca.';

  @override
  String get privacyGateSummaryImportExport =>
      'Uvoz, izvoz, popolne varnostne kopije in deljenje se izvedejo le, ko jih izrecno zaženete. Popolne varnostne kopije aplikacije ne vključujejo prilagojenih ključev API, razčlenjevanje besedila / HTML urnika pa pošlje samo oddano vsebino na nastavljeno končno točko za razčlenjevanje.';

  @override
  String get privacyGateSummaryUpdates =>
      'Če poznejša različica spremeni način ravnanja s podatki, vas lahko aplikacija zahteva, da znova pregledate posodobljeni pravilnik o zasebnosti.';

  @override
  String get schoolWebImportEntry => 'Uvozi s spletne strani šole';

  @override
  String get schoolWebImportEntryDesc =>
      'Uvozi trenutno stran voznega reda s spletnega mesta šole.';

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
  String get schoolSitesImportPreviewTitle => 'Pregled uvoza šolskih spletišč';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Veljavna spletišča: $validCount; neveljavni vnosi: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Datoteka vsebuje prazen seznam šolskih spletišč.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Vnos $position ni veljaven in bo preskočen.';
  }

  @override
  String get schoolSitesImportMerge => 'Združi';

  @override
  String get schoolSitesImportReplace => 'Zamenjaj';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Zamenjam trenutna šolska spletišča?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'S tem odstranite vsa trenutna spletišča ($currentCount) in shranite uvožena spletišča ($importedCount). Tega dejanja ni mogoče razveljaviti.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Podatke šolskih spletišč je treba obnoviti';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked ni mogel prebrati datoteke šolskih spletišč ali njene varnostne kopije. Pred blokiranjem zapisovanja so bile ustvarjene zaščitene kopije.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Shramba šolskih spletišč ni na voljo';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked trenutno ne more dostopati do shrambe šolskih spletišč. Preverite dostop do shrambe ali razpoložljivost naprave in poskusite znova. Trenutni podatki spletišč ne bodo prepisani.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Spodaj so navedene datoteke za obnovitev ali prizadeta mesta shranjevanja. Datotek ne spreminjajte, dokler seznam spletišč ni obnovljen.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Začni brez šolskih spletišč';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Začnem s praznim seznamom šolskih spletišč?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Zaščitene kopije bodo ohranjene, Sked pa bo ustvaril novo prazno datoteko šolskih spletišč. Nadaljujte le, če najprej ne želite znova poskusiti obnovitve.';

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
  String get schoolWebImportUnsupportedPlatform =>
      'Ta platforma še ne podpira vdelane spletne prijave. Prosimo, uporabite platformo s podporo WebView.';

  @override
  String get schoolWebImportNoSchools =>
      'Šolska nastavitev ni na voljo. Najprej preveri school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Konfiguracije šole ni bilo mogoče naložiti. Poskusite znova.';

  @override
  String get schoolWebImportImportCurrentPage => 'Uvozi trenutno stran';

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
  String get schoolImportParserSettingsTitle => 'API za uvoz urnika';

  @override
  String get schoolImportParserSettingsDesc =>
      'Nastavite API, združljiv z OpenAI, za uvoz urnikov, ne za klepetalnega pomočnika.';

  @override
  String get schoolImportParserSourceTitle => 'Vir razčlenjevanja';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Po meri združljiv z OpenAI';

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
      'Lastni ključ API se shrani prek varne shrambe platforme, kadar je ta na voljo. Lastne poverilnice razčlenjevalnika in končne točke HTTP uporabljajte le v napravah, brskalnikih in omrežjih, ki jim zaupate.';

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
  String get clearAppData => 'Počisti podatke';

  @override
  String get clearAppDataDesc =>
      'Trajno izbriši vse lokalne podatke Skeda in zapri aplikacijo';

  @override
  String get clearAppDataConfirmTitle => 'Počistim vse podatke Skeda?';

  @override
  String get clearAppDataConfirmMessage =>
      'S tem trajno izbrišete urnike pouka, dogodke, nastavitve, šolska spletišča, lokalne varnostne kopije, obnovitvene kopije in ključ API umetne inteligence, nato pa se Sked zapre. Datoteke, ki ste jih izvozili drugam, ne bodo izbrisane. Tega dejanja ni mogoče razveljaviti.';

  @override
  String get clearAppDataAction => 'Počisti podatke in zapri';

  @override
  String get clearAppDataFailed =>
      'Vseh lokalnih podatkov ni bilo mogoče počistiti. Sked bo ostal odprt, da lahko poskusite znova.';

  @override
  String get clearAppDataExitFailed =>
      'Lokalni podatki so bili počiščeni, vendar se Sked ni mogel zapreti. Pred ponovno uporabo aplikacijo zaprite ročno.';

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
      'Urnik, izbran za zamenjavo, ni na voljo. Izberi ga znova.';

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
  String get weekdayShortMonday => 'pon.';

  @override
  String get weekdayShortTuesday => 'tor.';

  @override
  String get weekdayShortWednesday => 'sre.';

  @override
  String get weekdayShortThursday => 'čet.';

  @override
  String get weekdayShortFriday => 'pet.';

  @override
  String get weekdayShortSaturday => 'sob.';

  @override
  String get weekdayShortSunday => 'ned.';

  @override
  String get monthJanuary => 'jan';

  @override
  String get monthFebruary => 'februar';

  @override
  String get monthMarch => 'mar';

  @override
  String get monthApril => 'apr';

  @override
  String get monthMay => 'Maj';

  @override
  String get monthJune => 'jun';

  @override
  String get monthJuly => 'jul';

  @override
  String get monthAugust => 'avg';

  @override
  String get monthSeptember => 'sept.';

  @override
  String get monthOctober => 'okt.';

  @override
  String get monthNovember => 'nov';

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
  String get generalSchedule => 'Splošni urnik';

  @override
  String get studentTimetable => 'Urnik pouka';

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
  String get firstLaunchPrivacyConsentBefore =>
      'Z izbiro začetnega delovnega prostora potrjujete, da ste prebrali in sprejeli ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Pravilnik o zasebnosti';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Preklopi način';

  @override
  String get switchToStudentTimetable => 'Preklopi na urnik pouka';

  @override
  String get today => 'Danes';

  @override
  String get addEvent => 'Dodaj dogodek';

  @override
  String get editEvent => 'Uredi dogodek';

  @override
  String get eventTitle => 'Naslov';

  @override
  String get eventTitleRequired => 'Vnesite naslov';

  @override
  String get eventStartTime => 'Čas začetka';

  @override
  String get eventEndTime => 'Čas konca';

  @override
  String get eventDate => 'Datum';

  @override
  String get eventTime => 'Čas';

  @override
  String get eventNotes => 'Opombe';

  @override
  String get eventColor => 'Barva';

  @override
  String get eventRecurrence => 'Ponavljanje';

  @override
  String get recurrenceNone => 'Se ne ponavlja';

  @override
  String get recurrenceWeekly => 'Tedensko';

  @override
  String get recurrenceEndDate => 'Končni datum';

  @override
  String get repeatsWeekly => 'Se ponavlja tedensko';

  @override
  String recurrenceUntil(Object date) {
    return 'Do $date';
  }

  @override
  String get switchToGeneralSchedule => 'Preklopi na splošni urnik';

  @override
  String get generalDisplaySettings => 'Splošne nastavitve prikaza';

  @override
  String get generalDisplaySettingsDesc =>
      'Pogledi, orodna vrstica, oblika datuma in hitro dodajanje';

  @override
  String get closePopupOnOutsideTap =>
      'Zapri pojavno okno ob dotiku zunaj njega';

  @override
  String get showGridLines => 'Prikaži mrežne črte';

  @override
  String get generalScheduleImportExport => 'Uvoz in izvoz kategorij';

  @override
  String get generalScheduleImportExportDesc =>
      'Uvozite ali delite kategorije urnika';

  @override
  String get importGeneralSchedules => 'Uvozi kategorije';

  @override
  String get importGeneralSchedulesDesc =>
      'Preberi kategorije iz datoteke JSON';

  @override
  String get shareGeneralSchedules => 'Deli kategorije';

  @override
  String get shareGeneralSchedulesDesc => 'Deli kategorije kot datoteko JSON';

  @override
  String get saveGeneralSchedules => 'Shrani kategorije';

  @override
  String get saveGeneralSchedulesDesc => 'Shrani kategorije kot datoteko JSON';

  @override
  String get selectSchedulesToExport => 'Izberite kategorije za izvoz';

  @override
  String get selectSchedulesToImport => 'Izberite kategorije za uvoz';

  @override
  String generalScheduleEventCount(int count) {
    return 'Dogodki: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Uvožene kategorije: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Želite uvoz dodati kot novo kategorijo ali zamenjati obstoječo kategorijo?';

  @override
  String get addAsNewSchedule => 'Dodaj kot novo kategorijo';

  @override
  String get selectAtLeastOneScheduleMessage => 'Izberite vsaj eno kategorijo.';

  @override
  String get noExportableScheduleMessage =>
      'Na voljo ni nobene kategorije za izvoz.';

  @override
  String get noSchedulesInImportMessage =>
      'Uvozna datoteka ne vsebuje kategorij.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Za zamenjavo izberite natanko eno uvoženo kategorijo.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Izbrana ciljna kategorija ni na voljo.';

  @override
  String get calendars => 'Kategorije';

  @override
  String get calendar => 'Kategorija';

  @override
  String get viewWeek => 'Teden';

  @override
  String get viewDay => 'Dan';

  @override
  String get viewList => 'Seznam';

  @override
  String get viewMonth => 'Mesec';

  @override
  String visibleCategoryCount(int count) {
    return 'Kategorije: $count';
  }

  @override
  String get noVisibleCategories => 'Ni vidnih kategorij';

  @override
  String get selectCategoryToReplace => 'Izberite kategorijo za zamenjavo';

  @override
  String get replaceCategory => 'Zamenjaj kategorijo';

  @override
  String get deleteEventTitle => 'Izbriši dogodek';

  @override
  String get deleteEventConfirmation => 'Ta dogodek bo trajno izbrisan.';

  @override
  String get deleteRecurringEventTitle => 'Izbriši ponavljajoči se dogodek';

  @override
  String get eventDuplicated => 'Dogodek je podvojen';

  @override
  String get allDay => 'Ves dan';

  @override
  String get collapseAllDayTimeline => 'Skrči celodnevne dogodke';

  @override
  String get expandAllDayTimeline => 'Razširi celodnevne dogodke';

  @override
  String allDayEventsCount(int count) {
    return 'Celodnevni dogodki: $count';
  }

  @override
  String moreEvents(int count) {
    return '+ še $count';
  }

  @override
  String get noMatchingEvents => 'Ni ustreznih dogodkov';

  @override
  String get noUpcomingEvents => 'Ni prihajajočih dogodkov';

  @override
  String get addCalendar => 'Dodaj kategorijo';

  @override
  String get newCalendar => 'Nova kategorija';

  @override
  String get hideCalendar => 'Skrij kategorijo';

  @override
  String get showCalendar => 'Prikaži kategorijo';

  @override
  String get rename => 'Preimenuj';

  @override
  String get renameCalendar => 'Preimenuj kategorijo';

  @override
  String get name => 'Ime';

  @override
  String get deleteCalendar => 'Izbriši kategorijo';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Izbrišem »$name«?';
  }

  @override
  String get deleteThisOccurrence => 'Izbriši to ponovitev';

  @override
  String get deleteFutureOccurrences => 'Izbriši to in prihodnje ponovitve';

  @override
  String get deleteAllOccurrences => 'Izbriši celotno zaporedje';

  @override
  String get duplicateEvent => 'Podvoji';

  @override
  String get repeatsDaily => 'Se ponavlja dnevno';

  @override
  String get repeatsMonthly => 'Se ponavlja mesečno';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Se ponavlja v razmiku $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return 'Število ponovitev: $count';
  }

  @override
  String get recurrenceDaily => 'Dnevno';

  @override
  String get recurrenceMonthly => 'Mesečno';

  @override
  String get recurrenceCustom => 'Po meri';

  @override
  String get recurrenceEvery => 'Razmik';

  @override
  String get recurrenceUnit => 'Enota';

  @override
  String get recurrenceDays => 'Dni';

  @override
  String get recurrenceWeeks => 'Tednov';

  @override
  String get recurrenceMonths => 'Mesecev';

  @override
  String get recurrenceRepeatCount => 'Število ponovitev';

  @override
  String get recurrenceNoLimit => 'Brez omejitve';

  @override
  String get recurrencePositiveNumber => 'Vnesite pozitivno število';

  @override
  String get clearEndDate => 'Odstrani končni datum';

  @override
  String get pickDate => 'Izberite datum';

  @override
  String get pickTime => 'Izberite čas';

  @override
  String get reminder => 'Opomnik';

  @override
  String get reminderAtStart => 'Ob začetku';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min prej';
  }

  @override
  String get reminderHourBefore => '1 uro prej';

  @override
  String get reminderDayBefore => '1 dan prej';

  @override
  String get markReminderHandled => 'Označi kot obravnavano';

  @override
  String get restoreReminder => 'Obnovi opomnik v aplikaciji';

  @override
  String get reminderHandled =>
      'Opomnik v aplikaciji je označen kot obravnavan';

  @override
  String get reminderRestored => 'Opomnik v aplikaciji je obnovljen';

  @override
  String get reminderUpcoming => 'Prihajajoče';

  @override
  String get generalFitWeekColumnsToWidth => 'Prilagodi teden zaslonu';

  @override
  String get showWeekends => 'Prikaži konce tedna';

  @override
  String get startHour => 'Začetna ura';

  @override
  String get endHour => 'Končna ura';

  @override
  String get timeGridDensity => 'Gostota časovne mreže';

  @override
  String get timeGridHourHeight => 'Višina urne vrstice';

  @override
  String get timeGridHourHeightHint =>
      'Prilagodi navpično merilo dnevnega in tedenskega pogleda, ne da bi spremenila 15-, 30- ali 60-minutni razmik mreže.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Uvozi datoteko JSON';

  @override
  String get pasteJson => 'Prilepi JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Uvozi kategorije iz kopiranega besedila JSON';

  @override
  String get importIcsFile => 'Uvozi datoteko ICS';

  @override
  String get importIcsFileDesc => 'Preberi dogodke iz koledarske datoteke .ics';

  @override
  String get pasteIcs => 'Prilepi ICS';

  @override
  String get pasteIcsDesc =>
      'Uvozi dogodke iz kopiranega koledarskega besedila';

  @override
  String get copyJson => 'Kopiraj JSON';

  @override
  String get copyJsonDesc => 'Kopiraj izbrane kategorije kot besedilo JSON';

  @override
  String get shareIcs => 'Deli ICS';

  @override
  String get shareIcsDesc => 'Deli izbrane kategorije kot .ics';

  @override
  String get saveIcs => 'Shrani ICS';

  @override
  String get saveIcsDesc => 'Shrani izbrane kategorije kot .ics';

  @override
  String get copyIcs => 'Kopiraj ICS';

  @override
  String get copyIcsDesc => 'Kopiraj izbrane kategorije kot besedilo ICS';

  @override
  String get importIcs => 'Uvozi ICS';

  @override
  String get icsContent => 'Vsebina ICS';

  @override
  String get pasteIcsContentHint => 'Sem prilepite vsebino BEGIN:VCALENDAR';

  @override
  String get icsReminderExportTitle => 'Izvoz ICS ne vključuje opomnikov';

  @override
  String get icsReminderExportMessage =>
      'Opomniki niso vključeni v izvoženi ICS. Izberite JSON, da ohranite nastavitve opomnikov.';

  @override
  String get icsReminderExportJsonAction => 'Izvozi JSON';

  @override
  String get icsReminderExportContinueAction => 'Nadaljuj z ICS';

  @override
  String get icsReminderImportNotice =>
      'Dogodki, uvoženi iz ICS, bodo imeli izklopljene opomnike. Za obnovitev nastavitev opomnikov uporabite JSON.';

  @override
  String get icsReminderReplaceTitle => 'Zamenjaj dogodke in opomnike?';

  @override
  String icsReminderReplaceMessage(String calendar) {
    return 'Če kategorijo »$calendar« zamenjate z dogodki iz ICS, bodo njeni dogodki prepisani, njihovi opomniki pa izklopljeni. Prekličite, da najprej izvozite varnostno kopijo JSON, ali se vrnite in dodajte novo kategorijo.';
  }

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Najdeni dogodki: $count. Jih želite dodati kot novo kategorijo ali zamenjati obstoječo kategorijo?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Uvožene kategorije: $count; opozorila: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Dogodek brez časa začetka je bil preskočen.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Dogodek z nepodprto obliko časa začetka je bil preskočen.';

  @override
  String get importWarningAdjustedEnd =>
      'Čas dogodka je bil popravljen, ker konec ni bil poznejši od začetka.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Nepodprta polja ICS so bila prezrta: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Nepodprta pogostost ponavljanja je bila prezrta: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Izberite kategorije za kopiranje v ICS';

  @override
  String get selectCalendarsToExportIcs => 'Izberite kategorije za izvoz v ICS';

  @override
  String get exportIcsText => 'Izvozi besedilo ICS';

  @override
  String get exportJsonText => 'Izvozi besedilo JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Podatki aplikacije so bili obnovljeni iz prejšnje varnostne kopije, ker glavne datoteke ni bilo mogoče naložiti.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Glavna podatkovna datoteka in njena varnostna kopija sta poškodovani. Aplikacija je zdaj zagnana z novimi podatki.';

  @override
  String get dataRecoveryCorruptTitle => 'Vaše podatke je treba obnoviti';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked ni mogel prebrati glavne podatkovne datoteke ali njene varnostne kopije. Pred blokiranjem zapisovanja so bile ustvarjene zaščitene kopije.';

  @override
  String get dataRecoveryIoFailureTitle => 'Shramba ni na voljo';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked trenutno ne more dostopati do lokalne shrambe. Preverite dostop do shrambe ali razpoložljivost naprave in poskusite znova. Obstoječi podatki ne bodo prepisani.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Za odpiranje teh podatkov posodobite Sked';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Ti podatki so bili ustvarjeni z novejšo različico Skeda. Pred ponovnim poskusom posodobite aplikacijo. Za zaščito podatkov je začetek z novimi podatki onemogočen.';

  @override
  String get dataRecoveryRetryAction => 'Poskusi znova';

  @override
  String get dataRecoveryArtifactsHint =>
      'Spodaj so navedene datoteke za obnovitev ali prizadeta mesta shranjevanja. Datotek ne spreminjajte, dokler vaši podatki niso obnovljeni.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Prikaži datoteke in mesta za obnovitev';

  @override
  String get dataRecoveryStartFreshAction => 'Začni z novimi podatki';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Začnem z novimi podatki?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Zaščitene kopije bodo ohranjene, Sked pa bo ustvaril novo lokalno podatkovno datoteko. Nadaljujte le, če najprej ne želite znova poskusiti obnovitve.';

  @override
  String get previousMonth => 'Prejšnji mesec';

  @override
  String get nextMonth => 'Naslednji mesec';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'V teku';

  @override
  String get deleteCourseTitle => 'Izbriši predmet';

  @override
  String get deleteCourseMessage => 'Izbrišem ta predmet?';

  @override
  String get showLunarCalendar => 'Prikaži lunin koledar';

  @override
  String monthDayEvents(int day, int count) {
    return '$day., dogodki: $count';
  }

  @override
  String get defaultView => 'Privzeti pogled';

  @override
  String get generalDefaultViewSection => 'Ob zagonu';

  @override
  String get generalViewSwitchBehavior => 'Gumb za menjavo pogleda';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Skrij navigacijo delovnih prostorov';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Skrijte navigacijo delovnih prostorov. Še vedno jih lahko zamenjate v meniju na glavnem zaslonu.';

  @override
  String get generalDateLabelFormat => 'Oblika datumskih oznak';

  @override
  String get generalDateLabelFormatLocalized => 'Krajevna oblika (julij 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Poševnica (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Postavitev orodne vrstice';

  @override
  String get toolbarNavigationSection => 'Navigacija orodne vrstice';

  @override
  String get toolbarNavigationHiddenBehavior => 'Skriti elementi';

  @override
  String get toolbarNavigationRemove => 'Povsem skrij';

  @override
  String get toolbarNavigationMore => 'Premakni v Več';

  @override
  String get toolbarNavigationReorder =>
      'Spremeni vrstni red elementov orodne vrstice';

  @override
  String get toolbarNavigationVisibility => 'Prikaži element orodne vrstice';

  @override
  String get toolbarNavigationTimetable => 'Izbirnik urnika';

  @override
  String get toolbarNavigationWeek => 'Izbirnik tedna';

  @override
  String get toolbarNavigationView => 'Izbirnik pogleda';

  @override
  String get toolbarNavigationCategory => 'Izbirnik kategorije';

  @override
  String get toolbarNavigationDate => 'Izbirnik datuma';

  @override
  String get generalToolbarWidthPolicy =>
      'Razporeditev prostora v orodni vrstici';

  @override
  String get generalToolbarWidthContent => 'Samodejna razporeditev';

  @override
  String get generalToolbarWidthBalanced => 'Uravnoteženo';

  @override
  String get generalToolbarWidthCalendarPriority => 'Prednost kategorije';

  @override
  String get generalToolbarWidthDatePriority => 'Prednost datuma';

  @override
  String get generalViewSwitchCycle => 'Kroži med pogledi';

  @override
  String get generalViewSwitchMenu => 'Odpri meni pogledov';

  @override
  String get generalViewSwitchTooltip => 'Preklopi pogled';

  @override
  String get generalViewSwitchMenuTooltip => 'Izberite pogled';

  @override
  String get generalViewLongPressTodayHint => 'Pridržite za vrnitev na danes';

  @override
  String get generalScheduleDisplaySection => 'Prikaz urnika';

  @override
  String get generalTimeGridSection => 'Časovna mreža';

  @override
  String get generalPopupSection => 'Vedenje pojavnih oken';

  @override
  String get quickActionsSection => 'Hitra dejanja';

  @override
  String get showAddCourseFab =>
      'Prikaži plavajoči gumb za dodajanje predmetov';

  @override
  String get showAddCourseFabHint =>
      'Prikaže ali skrije plavajoči gumb za dodajanje predmetov v spodnjem desnem kotu urnika pouka.';

  @override
  String get showAddEventFab => 'Prikaži plavajoči gumb za dodajanje dogodkov';

  @override
  String get showAddEventFabHint =>
      'Prikaže ali skrije plavajoči gumb za dodajanje dogodkov v spodnjem desnem kotu urnika.';

  @override
  String get enableLongPressAddCourse =>
      'Pridržite prazno mrežo za dodajanje predmetov';

  @override
  String get enableLongPressAddCourseHint =>
      'Pridržite prazno območje mreže urnika pouka, da dodate predmet.';

  @override
  String get enableLongPressAddEvent =>
      'Pridržite prazno mrežo za dodajanje dogodkov';

  @override
  String get enableLongPressAddEventHint =>
      'V dnevnem ali tedenskem pogledu pridržite prazno območje časovne mreže, da dodate dogodek.';

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
  String get developerNotificationDiagnostics => 'Diagnostika obvestil';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Preverite stanje dostave v Androidu, znova sestavite obstoječi načrt opomnikov in pošljite varna preizkusna obvestila prek običajne storitve obvestil Skeda.';

  @override
  String get developerNotificationUnsupported =>
      'Diagnostika obvestil je na voljo samo v Androidu.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Diagnostika obvestil bo na voljo, ko se zažene koordinator urnika.';

  @override
  String get developerNotificationRefresh => 'Osveži diagnostiko';

  @override
  String get developerNotificationSystemStatus =>
      'Sistemsko dovoljenje za obvestila';

  @override
  String get developerNotificationPermissionAllowed => 'Dovoljeno';

  @override
  String get developerNotificationPermissionBlocked => 'Blokirano';

  @override
  String get developerNotificationExactAlarm => 'Natančni alarmi';

  @override
  String get developerNotificationExactAlarmAllowed => 'Dovoljeno';

  @override
  String get developerNotificationExactAlarmBlocked => 'Ni dovoljeno';

  @override
  String get developerNotificationPlan => 'Načrt obvestil urnika';

  @override
  String get developerNotificationCoverage => 'Pokritost z opomniki';

  @override
  String get developerNotificationCoverageReady =>
      'Vsi znani opomniki z določenim koncem so neposredno razporejeni';

  @override
  String get developerNotificationCoverageRenewable =>
      'Ponavljajoči se opomniki se dolgoročno obnavljajo po najboljših zmožnostih';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Zmogljivost neposrednih alarmov je zapolnjena; poznejši opomniki se obnavljajo po najboljših zmožnostih';

  @override
  String get developerNotificationCoverageBlocked =>
      'Pogoji za natančno dostavo niso izpolnjeni';

  @override
  String get developerNotificationCoverageFailed =>
      'Zadnja sinhronizacija opomnikov ni uspela';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return 'Neposredni alarmi: $scheduled / zmogljivost: $capacity';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Zadnja napaka: $message';
  }

  @override
  String get developerNotificationTestChannel => 'Preizkusni kanal';

  @override
  String get developerNotificationTestCourse => 'Opomniki za predmete';

  @override
  String get developerNotificationTestSchedule => 'Opomniki za dogodke';

  @override
  String get developerNotificationImmediateTest =>
      'Takoj pošlji preizkusno obvestilo';

  @override
  String get developerNotificationThirtySecondTest =>
      'Načrtuj preizkus v ozadju čez 30 sekund';

  @override
  String get developerNotificationImmediateQueued =>
      'Takojšnje preizkusno obvestilo je poslano.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Preizkus v ozadju je načrtovan čez 30 sekund.';

  @override
  String get developerNotificationAppSwitch => 'Stikalo opomnikov aplikacije';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Omogočeno za običajne opomnike';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Onemogočeno za običajne opomnike; razvijalske preizkuse je še vedno mogoče zagnati';

  @override
  String get developerNotificationTimeZone => 'Krajevni časovni pas';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Še ni ustvarjen. Ustvarjen bo ob razvijalskem preizkusu.';

  @override
  String get developerNotificationChannelEnabledState => 'Omogočeno';

  @override
  String get developerNotificationChannelBlockedState => 'Blokirano';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Pomembnost: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Pomembnost ni na voljo';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return 'Čakajoča: $pending / aktivna: $active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Zadnji sistemski prikaz: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Ponovni izračun še ni zabeležen.';

  @override
  String get developerNotificationNextReminder => 'Naslednji pravi opomnik';

  @override
  String get developerNotificationNoPendingReminder =>
      'V trenutnem načrtu ni prihodnjih opomnikov';

  @override
  String get developerNotificationNextRenewal =>
      'Naslednja obnova po najboljših zmožnostih';

  @override
  String get developerNotificationLastSynchronization =>
      'Zadnja sinhronizacija opomnikov';

  @override
  String get developerNotificationLateRecovery =>
      'Obnovitev zakasnelih opomnikov';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Opomniki, obnovljeni po prvotnem času: $count';
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
  String get developerNotificationReconcileOriginForeground => 'Ospredje';

  @override
  String get developerNotificationReconcileOriginBackground => 'Ozadje';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Celoten ponovni izračun';

  @override
  String get developerNotificationReconcileModeRecovery => 'Obnovitev';

  @override
  String get developerNotificationRunRecovery => 'Zaženi obnovitev opomnikov';

  @override
  String get developerNotificationRecoveryComplete =>
      'Obnovitev opomnikov je končana';

  @override
  String get developerNotificationReconcileResultSuccess => 'Uspelo';

  @override
  String get developerNotificationReconcileResultSkipped => 'Preskočeno';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Blokirano, dokler niso izpolnjeni vsi pogoji za natančno dostavo';

  @override
  String get developerNotificationReconcileResultFailed => 'Ni uspelo';

  @override
  String get developerNotificationBackgroundLimits =>
      'Omejitve ozadja proizvajalca';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Omejitve delovanja v ozadju, ki jih določi proizvajalec, lahko vplivajo na dostavo.';

  @override
  String get developerNotificationAutostart =>
      'Zagon v ozadju pri proizvajalcu';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Proizvajalec: $vendor; na voljo je stran z nastavitvami proizvajalca. Android ne more prikazati stanja tega dovoljenja.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Proizvajalec: $vendor; uporabljena bo nadomestna stran s podatki o aplikaciji. Android ne more prikazati stanja tega dovoljenja.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Stran z nastavitvami ozadja proizvajalca ni na voljo.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Nazadnje odprto mesto: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'nastavitve proizvajalca';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'podatki o aplikaciji';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'nič';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Pogoji obnovitve po ponovnem zagonu';

  @override
  String get developerNotificationRebootBoundary =>
      'Obnovitev se začne po prvem odklepanju. Prisilno ustavljena aplikacija se ne more sama zagnati.';

  @override
  String get developerNotificationTestChecking =>
      'Med preverjanjem stanja obvestil preizkusi niso na voljo.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Preizkusi niso na voljo, ker so sistemska obvestila blokirana.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Preizkusi niso na voljo, ker je izbrani kanal obvestil blokiran.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Upravljajo nastavitve obvestil sistema Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Ne velja za Windows';

  @override
  String get developerNotificationWindowsIdentity =>
      'Identiteta paketa Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identiteta MSIX je na voljo; prikazana obvestila je mogoče odstraniti';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Za zanesljivo odstranjevanje prikazanih obvestil namestite različico MSIX';

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
  String get notificationSettingsSection => 'Opomniki in obvestila';

  @override
  String get notificationCoverage => 'Pokritost z opomniki';

  @override
  String get notificationCoverageBlocked =>
      'Reminders are blocked and will not fire. Review the system requirements below.';

  @override
  String get notificationCoverageFailed =>
      'Reminders could not be synced. Open notification settings and try again.';

  @override
  String get notificationCoverageRenewable =>
      'Ponavljajoči se dogodki brez končnega datuma uporabljajo obnavljanje v ozadju za dolgoročno pokritost.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android lahko neposredno razporedi do $capacity opomnikov; poznejši opomniki se poskušajo obnoviti vnaprej.';
  }

  @override
  String get notificationSettingsEnabled => 'Omogoči opomnike in obvestila';

  @override
  String get notificationSettingsEnabledHint =>
      'Razporedi samo elemente z nastavljenim opomnikom. Spodaj nastavite privzeti opomnik za predmete, ki ga podedujejo.';

  @override
  String get notificationPrecisionLimitations =>
      'Opomniki so odvisni od sistemskih dovoljenj in delovanja v ozadju. Izklop, spremembe časa ali sistemske omejitve jih lahko zakasnijo.';

  @override
  String get notificationSettingsEnabledSummary => 'Omogočeno';

  @override
  String get notificationSettingsDisabledSummary => 'Onemogočeno';

  @override
  String get notificationDefaultsSection => 'Privzeti opomniki';

  @override
  String get notificationCourseDefaultReminder =>
      'Privzeti opomnik za predmete';

  @override
  String get notificationGeneralDefaultReminder =>
      'Privzeti opomnik za dogodke';

  @override
  String get notificationReminderOff => 'Brez opomnika';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes min prej';
  }

  @override
  String get notificationPermission => 'Dovoljenje za obvestila';

  @override
  String get notificationPermissionGranted => 'Sistem dovoljuje';

  @override
  String get notificationPermissionDenied => 'Sistem blokira';

  @override
  String get notificationPermissionChecking => 'Preverjanje dovoljenja …';

  @override
  String get notificationPermissionRequest => 'Zahtevaj dovoljenje';

  @override
  String get notificationPermissionOpenSettings => 'Odpri sistemske nastavitve';

  @override
  String get notificationPermissionRequestFailed =>
      'Dovoljenja za obvestila ni bilo mogoče prebrati. Poskusite znova.';

  @override
  String get notificationExactAlarm => 'Dovoljenje za natančne alarme';

  @override
  String get notificationExactAlarmAllowed => 'Sistem dovoljuje';

  @override
  String get notificationExactAlarmRequired =>
      'Potrebno za natančen čas opomnikov';

  @override
  String get notificationExactAlarmRequest => 'Dovoli natančne alarme';

  @override
  String get notificationBatteryOptimization => 'Optimizacija baterije';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Dodano med izjeme optimizacije baterije v Androidu';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Natančni opomniki zahtevajo izjemo pri optimizaciji baterije v Androidu';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Odpri nastavitve optimizacije baterije';

  @override
  String get notificationAutostart => 'Zagon v ozadju pri proizvajalcu';

  @override
  String get notificationAutostartVendorHint =>
      'Dovolite samodejni zagon ali delovanje v ozadju, da se lahko opomniki obnovijo po ponovnem zagonu.';

  @override
  String get notificationAutostartFallbackHint =>
      'Odprite podatke o aplikaciji Sked in dovolite delovanje v ozadju. Android te nastavitve proizvajalca ne more preveriti.';

  @override
  String get notificationAutostartUnavailable =>
      'Stran z nastavitvami proizvajalca ni bila najdena. Ročno preverite podatke o aplikaciji Sked.';

  @override
  String get notificationAutostartRequest =>
      'Odpri nastavitve ozadja proizvajalca';

  @override
  String get notificationAutostartOpenFailed =>
      'Nastavitev ozadja proizvajalca ni bilo mogoče odpreti. Ročno preverite podatke o aplikaciji Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Prikaži naslove na zaklenjenem zaslonu';

  @override
  String get notificationLockScreenTitlesHint =>
      'Ko je možnost izklopljena, so podrobnosti obvestil na zaklenjenem zaslonu skrite.';

  @override
  String get notificationPlatformUnsupported =>
      'Ta platforma ne podpira izvornih obvestil.';

  @override
  String get workspaceFeatures => 'Upravljanje funkcij';

  @override
  String get workspaceBoth => 'Urnik in koledar';

  @override
  String get workspaceOnlyStudent => 'Samo urnik';

  @override
  String get workspaceOnlyGeneral => 'Samo koledar';

  @override
  String get workspaceDisableTitle => 'Izklopim ta delovni prostor?';

  @override
  String get workspaceDisableMessage =>
      'Podatki in nastavitve se ohranijo. Funkcije in opomniki se ustavijo, dokler prostora tukaj znova ne vklopite.';

  @override
  String get workspaceEnableHint =>
      'Izberite funkcije, ki jih uporabljate. Vsaj ena mora ostati vklopljena.';

  @override
  String get workspaceLastRequired =>
      'Vsaj en delovni prostor mora ostati vklopljen.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Delovni prostor je izklopljen, vendar opomnikov ni bilo mogoče odstraniti. Poskusite znova obnoviti obvestila.';

  @override
  String get settingsDataPrivacy => 'Podatki in zasebnost';

  @override
  String get selectedDayAgenda => 'Izbrani dan';

  @override
  String get notificationTroubleshooting => 'Dovoljenja in odpravljanje težav';

  @override
  String get settingsConnection => 'Povezava';

  @override
  String get settingsAdvanced => 'Napredno';

  @override
  String get unsavedChangesMessage =>
      'Imate neshranjene spremembe. Jih zavržem in zaprem?';

  @override
  String get backupWorkspaceSelection =>
      'Celotna varnostna kopija vključuje podatke in izbor vklopljenih delovnih prostorov.';

  @override
  String get assistantLayoutPreview => 'UI · Predogled postavitve';

  @override
  String get assistantSelectionContext => 'Trenutni izbor uporabi kot kontekst';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Osnutek sporočila';

  @override
  String get assistantPreviewNoSend =>
      'Samo predogled postavitve. Nič ne bo poslano ali spremenjeno.';

  @override
  String get resizePanel => 'Spremeni velikost podokna';

  @override
  String get minimizeWindow => 'Pomanjšaj';

  @override
  String get maximizeWindow => 'Povečaj';

  @override
  String get restoreWindow => 'Obnovi okno';

  @override
  String get closeWindow => 'Zapri okno';

  @override
  String get courseSystemReminder => 'Sistemski opomnik';

  @override
  String courseReminderInherit(String reminder) {
    return 'Uporabi privzeto ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Sistemski opomniki so izklopljeni v nastavitvah obvestil. Nastavitev opomnika za ta predmet lahko vseeno shranite.';

  @override
  String get courseReminderDefaultOff =>
      'Privzeti opomnik za predmete ni nastavljen. Tukaj izberite opomnik po meri ali nastavite privzetega v nastavitvah obvestil.';

  @override
  String get courseReminderDeliveryHint =>
      'Ta nastavitev se shrani s predmetom. Dostava je odvisna od sistemskih dovoljenj za obvestila in omejitev ozadja.';

  @override
  String get courseReminderPermissionUnknown =>
      'Stanje sistemskih obvestil še ni bilo preverjeno. Preden se zanesete na opomnike, preverite nastavitve obvestil.';

  @override
  String get courseReminderMinutesLabel => 'Minute pred začetkom pouka';

  @override
  String get exportAction => 'Izvozi';

  @override
  String get datePickerSelectWeek => 'Izberi teden';

  @override
  String get datePickerSelectMonth => 'Izberi mesec';

  @override
  String get generalDateLabelFormatDescription =>
      'Velja za datumsko navigacijo na namizju in manjših zaslonih.';

  @override
  String get dateRangeTitle => 'Izberi datumski obseg';

  @override
  String get dateRangeCustom => 'Po meri';

  @override
  String get dateRangeChooseStart => 'Izberi začetni datum';

  @override
  String get dateRangeChooseEnd => 'Izberi končni datum';

  @override
  String get dateRangeLimit =>
      'Izberi od 1 do 14 dni, vključno z obema datumoma.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dni',
      two: '$days dneva',
      one: '1 dan',
    );
    return 'Po meri · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Izberi z drsnimi kolesci';

  @override
  String get courseReminderUseDefault => 'Uporabi privzeto';

  @override
  String get courseReminderInvalidMinutes =>
      'Vnesite celo število minut, ki je večje ali enako nič.';

  @override
  String get generalCustomColumnWidth => 'Širina stolpcev v pogledu po meri';

  @override
  String get generalCustomColumnWidthAuto => 'Samodejno';

  @override
  String get generalCustomColumnWidthManual => 'Najmanjša širina';

  @override
  String get generalCustomColumnWidthMinimum =>
      'Najmanjša širina posameznega dne';

  @override
  String get generalCustomColumnWidthHint =>
      'Vsi datumi imajo enako najmanjšo širino. Stolpci zapolnijo razpoložljivi prostor ali omogočijo vodoravno pomikanje. Vpliva samo na pogled po meri.';

  @override
  String get settingsAppearanceLanguage => 'Videz in jezik';

  @override
  String get settingsAppearanceDetails => 'Barve in obrisi';

  @override
  String get monthNoEvents => 'Ta dan ni dogodkov';

  @override
  String get settingsOverview => 'Pregled';

  @override
  String get settingsThemeTarget => 'Tema za';

  @override
  String get settingsColorMode => 'Barvni način';

  @override
  String get settingsNotificationPreferences => 'Nastavitve opomnikov';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Privzeti opomniki, dovoljenja in zanesljivost';

  @override
  String get settingsFeaturesSummary => 'Delovni prostori in navigacija';

  @override
  String get settingsPrivacySummary =>
      'Pravilnik o zasebnosti in čiščenje lokalnih podatkov';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Število šolskih ur: $count',
      one: '1 šolska ura',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Šolska ura';

  @override
  String get periodTimesDurationColumn => 'Trajanje';

  @override
  String get periodTimesGapColumn => 'Odmor';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Čakanje na shranjevanje …';

  @override
  String get periodTimesSaveFailed => 'Ni shranjeno · Shranjevanje ni uspelo';

  @override
  String get periodTimesInvalidStatus =>
      'Ni shranjeno · Popravite označene čase';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked ni mogel potrditi, ali je bilo zadnje shranjevanje razveljavljeno. Pisanje je ustavljeno, obnovitvene kopije pa so ohranjene. Preverite shrambo in poskusite znova naložiti podatke.';

  @override
  String get settingsPanelDisplayMode => 'Prikaz plošč';

  @override
  String get settingsPanelDisplayModeGlobal => 'Skupno urnikom in koledarjem';

  @override
  String get settingsPanelDisplayOverlay => 'Prekrivanje';

  @override
  String get settingsPanelDisplaySideBySide => 'Druga ob drugi';

  @override
  String get settingsPanelDisplayAutomatic => 'Samodejno';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Prekrije desno stran, ne da bi spremenil širino koledarja.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Daje prednost prikazu druga ob drugi; prekrije le, če bi koledar postal preozek.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Prikaže drugo ob drugi, če koledar ostane berljiv, sicer s prekrivanjem.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Ko izklopite prikaz Nastavitev ali Delovnega prostora v orodni vrstici, se premakneta v meni Več in ostaneta dostopna. Menija Več ni mogoče skriti, dokler vsebuje nujna dejanja. Preklop delovnega prostora se prikaže samo, ko je spodnja navigacija skrita in je omogočenih več delovnih prostorov.';

  @override
  String get reminderEnded => 'Končano';

  @override
  String get reminderAutoCloseHint =>
      'Zapre se po 10 sekundah. Z uporabo podokna ga obdržite odprtega.';

  @override
  String get showReminderIndependently => 'Odpri ločeno';

  @override
  String get categoryManagerTitle => 'Upravljanje kategorij';

  @override
  String get categoryHidden => 'Skrito';

  @override
  String get categoryShowOnCalendar => 'Prikaži na koledarju';

  @override
  String get categoryHideOnCalendar => 'Skrij s koledarja';

  @override
  String get categoryEditColor => 'Spremeni barvo kategorije';

  @override
  String get categoryThemePalette => 'Paleta teme';

  @override
  String get categoryCustomColor => 'Po meri';

  @override
  String get colorHexInvalid => 'Vnesite šestmestno šestnajstiško barvno kodo.';

  @override
  String get colorPickerHue => 'Odtenek';

  @override
  String get colorPickerSaturation => 'Nasičenost';

  @override
  String get colorPickerValue => 'Svetlost';

  @override
  String get colorPickerHex => 'Šestnajstiška barva';

  @override
  String get colorPickerSpectrum => 'Barvni spekter';

  @override
  String get colorPickerSpectrumKeyboardHint =>
      'S puščicama levo in desno prilagodite nasičenost, s puščicama gor in dol pa svetlost.';

  @override
  String categoryColorSlot(int number) {
    return 'Barva teme $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Posodobitve v trgovini so lahko na voljo pozneje. Razpoložljivost preverite na strani trgovine.';

  @override
  String get storePrereleaseNotice =>
      'Prejemanje obvestil o predizdajah vas ne vključi samodejno v preizkusni program trgovine.';

  @override
  String get updateFoundTitle => 'Na voljo je nova različica';

  @override
  String get updateNoNotes => 'Opombe ob izdaji niso na voljo.';

  @override
  String get updateLater => 'Pozneje';

  @override
  String get updateRetry => 'Poskusi znova';

  @override
  String get updatePrerelease => 'Predizdaja';

  @override
  String get updateNetworkFailure =>
      'Posodobitev ni mogoče preveriti. Preverite povezavo in poskusite znova.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Novejša različica ni bila najdena (trenutna: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Obnavljanje varnostne kopije…';

  @override
  String get backupRestoreInProgressMessage =>
      'Podatke in nastavitve lahko spremenite po končani obnovitvi. Še vedno si jih lahko ogledate.';

  @override
  String get managePeriodTimeSets => 'Upravljaj nabore časov učnih ur';

  @override
  String periodTimeSetUsageSummary(int periodCount, int timetableCount) {
    return 'Število učnih ur: $periodCount · Povezani urniki: $timetableCount';
  }

  @override
  String chooseTimetableImportMethod(String name) {
    return 'Uvozi kot nov urnik ali zamenjaj vse podatke in predavanja v urniku »$name«.';
  }

  @override
  String get selectAtLeastOneWeek => 'Izberi vsaj en teden.';

  @override
  String get notificationRemindHiddenGeneralCalendars =>
      'Ohrani opomnike za skrite kategorije';

  @override
  String get notificationRemindHiddenGeneralCalendarsHint =>
      'Velja za opomnike v aplikaciji in sistemska obvestila. Sistemska obvestila morajo biti omogočena tudi v nastavitvah.';

  @override
  String get generalReminderFollowDefault => 'Uporabi privzeto';

  @override
  String get generalReminderCustom => 'Opomniki po meri';

  @override
  String get eventEditScopeTitle => 'Uredi ponavljajoči se dogodek';

  @override
  String get eventEditThisOccurrence => 'Samo ta ponovitev';

  @override
  String get eventEditThisAndFollowing => 'Ta in naslednje ponovitve';

  @override
  String get eventEditEntireSeries => 'Celoten niz';

  @override
  String get eventEditEntireSeriesHint =>
      'Spremembe veljajo za celoten niz, vključno s preteklimi ponovitvami.';

  @override
  String get eventEditConflict =>
      'Ta dogodek se je spremenil. Osnutek je ohranjen; znova odpri dogodek in preveri najnovejšo različico.';

  @override
  String eventSavedToHiddenCalendar(String name) {
    return 'Shranjeno v skriti kategoriji »$name«.';
  }

  @override
  String get viewEvent => 'Prikaži dogodek';

  @override
  String get schoolSitesNameRequired => 'Vnesite ime šole.';

  @override
  String get schoolSitesLoginUrlRequired => 'Vnesite URL za prijavo.';

  @override
  String get languageNoResults => 'Ni ujemajočih se jezikov';

  @override
  String get themeGeneralMonthTextColors => 'Besedilo mesečnega pogleda';

  @override
  String get themeGeneralFestivalTextColor => 'Prazniki in prosti dnevi';

  @override
  String get themeGeneralSolarTermTextColor => 'Sončna obdobja';

  @override
  String get themeGeneralLunarTextColor => 'Lunini datumi';

  @override
  String get courseTextLowContrastHint =>
      'To barvo besedila je na nekaterih karticah predmetov morda težko brati (kontrast pod 4.5:1). Lahko jo ohranite ali izberete drugo.';

  @override
  String get shortenSemesterTitle => 'Skrajšam semester?';

  @override
  String shortenSemesterMessage(int weeks, int count) {
    return 'Semester se bo končal v tednu $weeks. Predmeti s poznejšimi urami: $count. Predmeti in izbrani tedni bodo ohranjeni. Obnovite število tednov za ponovni prikaz.';
  }

  @override
  String get defaultGeneralCalendarName => 'Moj koledar';

  @override
  String get icsImportReportTitle => 'Poročilo o uvozu';

  @override
  String get icsImportReportAction => 'Prikaži poročilo';

  @override
  String get icsExportFailureTitle => 'Izvoz v ICS ni mogoč';

  @override
  String get icsCopyDiagnosticsAction => 'Kopiraj podrobnosti';

  @override
  String get icsUnsupportedTimeZoneMessage =>
      'Ta ICS vsebuje poimenovane časovne pasove, ki jih Sked ne more varno razbrati. Nič ni bilo uvoženo. Iz izvornega koledarja izvozite UTC ali krajevne čase brez časovnega pasu in poskusite znova.';

  @override
  String get icsExportMonthlyAnchorMismatchMessage =>
      'Tega mesečnega dogodka ni mogoče natančno predstaviti v ICS. Izvozite JSON, da ohranite datume.';

  @override
  String get icsExportEmptyRecurrenceMessage =>
      'Ta ponavljajoči se dogodek nima veljavnih pojavitev za izvoz v ICS. Izvozite JSON, da ohranite zapis.';

  @override
  String get icsImportedCalendarName => 'Uvožen koledar';

  @override
  String get icsUntitledEventName => 'Dogodek brez naslova';

  @override
  String notificationWindowsCoverageLimit(int days, int capacity) {
    return 'Windows načrtuje opomnike le za naslednjih $days dni, največ $capacity hkrati. Aplikacijo redno znova odprite, da osvežite načrt.';
  }

  @override
  String notificationWindowsCoverageSummary(int count, String date) {
    return 'Načrtovani opomniki: $count. Zadnje preverjanje zajema obdobje do $date.';
  }

  @override
  String get notificationWindowsCoverageCapacityLimited =>
      'Dosežena je omejitev števila opomnikov. Nekateri še niso načrtovani. Ko se sprožijo bližnji opomniki, znova odprite aplikacijo in osvežite načrt.';

  @override
  String get courseInactiveThisWeek => 'Ta teden ni na urniku';

  @override
  String get schoolWebImportSignOut => 'Sign out';

  @override
  String get schoolWebImportSignOutTitle => 'Sign out of school websites?';

  @override
  String get schoolWebImportSignOutMessage =>
      'This clears sign-in cookies and saved website data for school pages in Sked. Imported timetables and app settings are kept.';

  @override
  String get schoolWebImportSignOutSuccess =>
      'School website sign-in data cleared.';

  @override
  String get schoolWebImportSignOutFailed =>
      'Could not clear school sign-in data. Please try again.';

  @override
  String importWarningSkippedUnsupportedTimeZone(Object fields) {
    return 'Skipped an event whose time zone cannot be interpreted safely: $fields.';
  }

  @override
  String get icsSkippedTimeZonesReview =>
      'The following events will be skipped because their time zones cannot be interpreted safely. Review the details before importing the remaining events.';

  @override
  String get icsImportRemainingAction => 'Continue with remaining events';

  @override
  String get expandTimelineEvents => 'Expand events';

  @override
  String get timelineEvents => 'Events in this timeline';

  @override
  String get schoolImportEndpointChangeTitle => 'Change the parsing endpoint?';

  @override
  String schoolImportEndpointChangeMessage(String previous, String next) {
    return 'The saved API key will be sent to the new endpoint when you parse a timetable or fetch models.\n\nCurrent: $previous\nNew: $next\n\nOnly continue if you trust the new endpoint.';
  }

  @override
  String get schoolImportEndpointChangeConfirm => 'Change endpoint';

  @override
  String restoreBackupParserSettingsSummary(String current, String backup) {
    return 'The parsing endpoint, model and prompt on this device are kept. The API key on this device will be cleared.\n\nKept endpoint: $current\nBackup endpoint (ignored): $backup';
  }

  @override
  String get backupParserEndpointUnset => 'Not configured';

  @override
  String get periodTimesDayFull =>
      'No room remains for another period today. Adjust the existing times before adding more.';
}
