// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Het $week';
  }

  @override
  String get addCourse => 'Tanfolyam hozzáadása';

  @override
  String get settings => 'Beállítások';

  @override
  String get multiTimetableSwitch => 'Váltás menetrend';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Aktuális menetrend · $weeks hetek';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Koppintson a váltáshoz · $weeks hetek';
  }

  @override
  String get editTimetable => 'A menetrend szerkesztése';

  @override
  String get schoolImportResultEditorTitle =>
      'Feldolgozott eredmény szerkesztése';

  @override
  String get schoolImportParsePageTitle => 'Órarend elemzése';

  @override
  String get schoolImportParsePageParsing => 'Elemzés…';

  @override
  String get schoolImportParsePageFailed => 'Az elemzés sikertelen';

  @override
  String get schoolImportParsePageComplete => 'Az elemzés kész';

  @override
  String get schoolImportParsePageContinue => 'Folytatás';

  @override
  String get schoolImportParsePageRawContent => 'Nyers válasz';

  @override
  String get schoolImportParsePageExpandRaw => 'Nyers válasz kibontása';

  @override
  String get schoolImportParsePageCollapseRaw => 'Nyers válasz összecsukása';

  @override
  String get schoolImportExpandWarnings =>
      'Importálási figyelmeztetések kibontása';

  @override
  String get schoolImportCollapseWarnings =>
      'Importálási figyelmeztetések összecsukása';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Egyes tantárgyak a(z) $week. hétig tartanak.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Lecseréli a jelenlegi órarendet?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Az importált órarend lecseréli a jelenlegi órarendet.';

  @override
  String get createTimetable => 'Új menetrend';

  @override
  String get jumpToWeek => 'Ugrás a hétre';

  @override
  String get timetable => 'Naptár';

  @override
  String get themeWorkspaceSchedule => 'Naptár';

  @override
  String get timetableName => 'Időrend neve';

  @override
  String get timetableNameRequired => 'Az órarend neve kötelező';

  @override
  String get totalWeeks => 'Összes hét';

  @override
  String get delete => 'Törlés';

  @override
  String get cancel => 'törlés';

  @override
  String get save => 'Mentés';

  @override
  String get deleteTimetableTitle => 'Időterv törlése';

  @override
  String deleteTimetableMessage(Object name) {
    return ' \"$name\" törlése?';
  }

  @override
  String get noTimetableTitle => 'Még nincs menetrend';

  @override
  String get noTimetableMessage =>
      'Hozzon létre egy ütemtervet, vagy importáljon egyet egy JSON fájlból.';

  @override
  String get importTimetable => 'Importálási menetrend';

  @override
  String get courseName => 'Tanfolyam neve';

  @override
  String get location => 'Helyszín';

  @override
  String get dayOfWeek => 'nap';

  @override
  String get semesterWeeks => 'Hetek';

  @override
  String get startTime => 'Kezdési idő';

  @override
  String get endTime => 'Végedő idő';

  @override
  String get linkedPeriods => 'Kapcsolódó időszakok';

  @override
  String get linkedPeriodsUnmatched =>
      'Nincsenek időszakok a jelenlegi időre. Koppintson a kézi kiválasztáshoz.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Periódus $start-$end';
  }

  @override
  String get teacherName => 'Tanár';

  @override
  String get credits => 'Hitelek';

  @override
  String get remarks => 'Megjegyzések';

  @override
  String get customFields => 'Egyéni mezők';

  @override
  String get customFieldsHint => 'Egy soronként, formátum: kulcs:érték';

  @override
  String get customFieldsInvalidJson =>
      'Adjon meg egy érvényes JSON-objektumot, vagy törölje a mező tartalmát.';

  @override
  String get more => 'Továbbiak';

  @override
  String get selectDayOfWeek => 'Válasszon napot';

  @override
  String get selectSemesterWeeks => 'Válasszon héteket';

  @override
  String get selectAll => 'Minden kiválasztás';

  @override
  String get clear => 'Tisztítás';

  @override
  String get confirm => 'Megerősítés';

  @override
  String get selectLinkedPeriods => 'Válasszon összekapcsolt időszakokat';

  @override
  String get addCourseTitle => 'Tanfolyam hozzáadása';

  @override
  String get editCourseTitle => 'A tanfolyam szerkesztése';

  @override
  String get editCourseTooltip => 'A tanfolyam szerkesztése';

  @override
  String get place => 'Helyszín';

  @override
  String get time => 'Idő';

  @override
  String get notFilled => 'Nem töltött ki';

  @override
  String get none => 'Nincs';

  @override
  String get conflictCourses => 'Konfliktusos tanfolyamok';

  @override
  String get locationNotFilled => 'Helyszín nem töltött ki';

  @override
  String get setAsDisplayed => 'Beállítás a megjelenítéshez';

  @override
  String get editThisCourse => 'Szerkesztse ezt a kurzust';

  @override
  String get settingsTitle => 'Beállítások';

  @override
  String get settingsSectionTimetable => 'Órarend';

  @override
  String get settingsSectionGeneralSchedule => 'Általános naptár';

  @override
  String get settingsSectionAppearance => 'Megjelenés';

  @override
  String get settingsSectionApp => 'Alkalmazás';

  @override
  String get settingsSectionWorkspace => 'Munkaterület';

  @override
  String get settingsSectionAppearanceLanguage => 'Megjelenés és nyelv';

  @override
  String get settingsSectionDataSecurity => 'Adatok és biztonság';

  @override
  String get settingsSectionAbout => 'A Sked névjegye';

  @override
  String get noTimetableSettings =>
      'Jelenleg nincs rendelkezésre álló menetrend a beállításokhoz.';

  @override
  String get semesterStartDate => 'A szemeszter kezdési dátuma';

  @override
  String get periodTimeSets => 'Időtartam beállítása';

  @override
  String get noPeriodTimeAvailable => 'Nincs rendelkezésre álló időszak';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count időszakok';
  }

  @override
  String get coursePopupDismissSetting =>
      'Engedélyezze a külső érintést a kurzus lezárásához';

  @override
  String get coursePopupDismissSettingHint =>
      'Ha kikapcsolja ezt, letiltja a lefelé húzó elbocsátást is.';

  @override
  String get preserveTimetableGaps => 'A menetrend hiányosságainak megőrzése';

  @override
  String get preserveTimetableGapsHint =>
      'Mikor le, ebéd és szünet szakadékok összeomlik, így későbbi osztályok felfelé mozog.';

  @override
  String get showPastEndedCourses =>
      'A múltban befejezett tanfolyamok megjelenítése';

  @override
  String get showPastEndedCoursesHint =>
      'Mutassa meg a tanfolyamokat, amelyek már befejezték a valódi jelenlegi héten világosabb szürke stílusban.';

  @override
  String get showFutureCourses => 'Jövőbeli tanfolyamok megjelenítése';

  @override
  String get showFutureCoursesHint =>
      'Mutassa meg azokat a tanfolyamokat, amelyek nem aktívak ezen a héten, de későbbi hetekben szürke stílusban jelennek meg.';

  @override
  String get timetableDisplaySettings =>
      'Az ütemterv megjelenítése és interakció';

  @override
  String get timetableDisplaySettingsDesc =>
      'Kurzusmegjelenítés, elrendezés, heti gesztusok és gyors hozzáadás';

  @override
  String get showTimetableGridLines => 'A menetrend rácsvonalak megjelenítése';

  @override
  String get showTimetableGridLinesHint =>
      'Ellenőrizze, hogy a vízszintes és függőleges rácsvonalak láthatók-e a menetrendben.';

  @override
  String get timetableHorizontalLayoutSection =>
      'Vízszintes elrendezés és gesztusok';

  @override
  String get fitDaySelectorToWidth => 'Napválasztó igazítása a képernyőhöz';

  @override
  String get fitDaySelectorToWidthHint =>
      'Ha lehet, mind a hét nap elfér a képernyőn; kikapcsolva rögzített szélességgel görgethető.';

  @override
  String get fitWeekColumnsToWidth => 'Heti oszlopok igazítása a képernyőhöz';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Ha lehet, az órarend mind a hét oszlopa elfér a képernyőn; kikapcsolva rögzített szélességgel görgethető.';

  @override
  String get enableWeekSwipeNavigation => 'Hétváltás lapozással';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Balra vagy jobbra húzva válthat hetet. Rögzített szélesség esetén előbb húzza túl a tartalmat a szélén.';

  @override
  String get liveCourseOutlineColor => 'A tanfolyam vázlata színe';

  @override
  String get liveCourseOutlineColorHint =>
      'Válassza ki, hogy a vázlatok az aktuális/következő tanfolyamot célozzák-e, vagy az aktuális oldalon megjelenő összes tanfolyamot.';

  @override
  String get liveCourseOutlineSettings => 'A tanfolyam vázlata';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Beállítja, hogy a vázlat engedélyezve van-e, mit célozza, követi-e a téma színét és a hatékony vázlat színét.';

  @override
  String get liveCourseOutlineEnabled => 'Vázlat engedélyezése';

  @override
  String get liveCourseOutlineFollowTheme => 'Kövesse a téma színét';

  @override
  String get liveCourseOutlineTarget => 'Vázlati cél';

  @override
  String get liveCourseOutlineTargetCurrentOrNext =>
      'Jelenlegi/következő tanfolyam';

  @override
  String get liveCourseOutlineTargetAllDisplayed =>
      'Minden megjelenített tanfolyam';

  @override
  String get liveCourseOutlineEffectiveColor => 'Hatékony szín';

  @override
  String get liveCourseOutlineCustomColor => 'Egyéni vázlat színe';

  @override
  String get liveCourseOutlineWidth => 'Vázlat szélessége';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Nyelv';

  @override
  String get languagePageDescription =>
      'Válasszon egy olyan nyelvet, amely valóban elérhető az alkalmazásban.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'Magyar';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API válasz';

  @override
  String get theme => 'Téma';

  @override
  String get themeFollowSystem => 'Kövesse a rendszert';

  @override
  String get themeLight => 'Fény';

  @override
  String get themeDark => 'Sötét';

  @override
  String get themeColor => 'Téma színe';

  @override
  String get themeColorModeSingle => 'Egyetlen téma szín';

  @override
  String get themeColorModeColorful => 'Színes';

  @override
  String get themeColorUiColors => 'Felhasználói felület színei';

  @override
  String get themeColorCourseColors => 'A tanfolyam színei';

  @override
  String get themeColorPrimary => 'Elsődleges';

  @override
  String get themeColorSecondary => 'Másodlagos';

  @override
  String get themeColorTertiary => 'Terciáris';

  @override
  String get themeColorCourseText => 'A tanfolyam szövege';

  @override
  String get themeColorCourseTextAuto => 'Automatikus';

  @override
  String get themeColorCourseTextCustom => 'Egyéni szín';

  @override
  String get themeColorCourseColorsEmpty =>
      'A tanfolyam színei a menetrend importálása után jönnek létre.';

  @override
  String get themeCustomColor => 'Egyéni szín';

  @override
  String get themeApplyCustomColor => 'Szín alkalmazása';

  @override
  String get themeApplySettings => 'Beállítások alkalmazása';

  @override
  String get dataImportExport => 'Adatok importálása és exportálása';

  @override
  String get dataImportExportDesc =>
      'Teljes adatok vagy egyetlen menetrend importálása, vagy az aktuális/összes menetrend exportálása.';

  @override
  String get appBackupTitle =>
      'Alkalmazás biztonsági mentése és visszaállítása';

  @override
  String get appBackupSubtitle =>
      'Mentse vagy állítsa vissza az órarendeket, naptárakat, beállításokat és iskolai webhelyeket. Az API-kulcsok nem szerepelnek benne.';

  @override
  String get appBackupSheetSubtitle =>
      'A teljes visszaállítás lecseréli az aktuális alkalmazásadatokat. Az AI API-kulcsok biztonságos tárhelyen vannak, és nem kerülnek a mentési fájlokba.';

  @override
  String get restoreBackupFileTitle => 'Visszaállítás JSON-fájlból';

  @override
  String get restoreBackupFileSubtitle =>
      'Válasszon egy teljes Sked biztonsági mentési fájlt. Visszaállítás előtt megerősítést kérünk.';

  @override
  String get restoreBackupTextTitle => 'Mentési JSON beillesztése';

  @override
  String get restoreBackupTextSubtitle =>
      'Illesszen be egy teljes mentést, és állítsa vissza az aktuális alkalmazásadatokat.';

  @override
  String get shareBackupTitle => 'Mentési fájl megosztása';

  @override
  String get shareBackupSubtitle =>
      'Exportálja a teljes alkalmazásadatot JSON-ként. Az API-kulcsok kimaradnak.';

  @override
  String get saveBackupTitle => 'Mentési fájl mentése';

  @override
  String get saveBackupSubtitle =>
      'Teljes alkalmazásmentés mentése helyi fájlba.';

  @override
  String get copyBackupTitle => 'Mentési szöveg másolása';

  @override
  String get copyBackupSubtitle =>
      'Megjeleníti a teljes mentési JSON-t, hogy kimásolhassa vagy ideiglenesen eltárolhassa.';

  @override
  String get restoreBackupConfirmTitle => 'Teljes mentés visszaállítása?';

  @override
  String get restoreBackupConfirmMessage =>
      'Ez lecseréli az összes jelenlegi órarendet, általános naptárat, beállítást és iskolai webhelyet. Az API-kulcsok nem importálódnak a mentésekből; az órarendek újraelemzése előtt adja meg újra a kulcsot.';

  @override
  String get restoreBackupConfirmAction => 'Mentés visszaállítása';

  @override
  String get restoreBackupSuccessMessage =>
      'Teljes alkalmazásmentés visszaállítva. Az AI API-kulcsokat újra meg kell adni.';

  @override
  String get restoreBackupFailureMessage =>
      'A visszaállítás sikertelen. Ellenőrizze a mentés tartalmát, és próbálja újra.';

  @override
  String get openSourceLicenses => 'Nyílt forráskódú licencek';

  @override
  String get openSourceLicensesDesc =>
      'Licencek megtekintése a Flutter függőségekhez és a csomagolt alkalmazás ikon eszközökhöz.';

  @override
  String get checkForUpdates => 'Ellenőrizze a frissítéseket';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates =>
      'A frissítéseket a Microsoft Store kezeli';

  @override
  String get includePrereleaseUpdates => 'Előzetes frissítések fogadása';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Az esetleg instabil Alpha, Beta és RC verziók is megjelennek. Kikapcsolva csak stabil verziókat kínál fel.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Már a legújabb verzió ($version)';
  }

  @override
  String get currentVersionLabel => 'Jelenlegi verzió';

  @override
  String get newVersionAvailable => 'Frissítés elérhető';

  @override
  String get latestVersionLabel => 'Legújabb verzió';

  @override
  String get updateContentLabel => 'Frissítési részletek';

  @override
  String get officialWebsite => 'Hivatalos honlap';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Felhő meghajtó';

  @override
  String get ignoreThisVersion => 'Figyelmen kívül hagyja ezt a verziót';

  @override
  String get openUpdatesFailed => 'Nem sikerült megnyitni a frissítési linket';

  @override
  String get updateCheckFailedTitle => 'A frissítés ellenőrzése nem sikerült';

  @override
  String get updateCheckFailedMessage =>
      'Nem sikerült lekérni a legújabb verziót a GitHubról. Alább továbbra is megnyithatja a GitHub Releases oldalt.';

  @override
  String get githubRepository => 'GitHub tároló';

  @override
  String get googlePlayStoreDesc => 'Sked megtekintése a Google Playen';

  @override
  String get openGooglePlayFailed => 'Nem sikerült megnyitni a Google Playt';

  @override
  String get starSkedOnGithub => 'Csillagozza meg a Skedet a GitHubon!';

  @override
  String get starSkedOnGithubDesc =>
      'Nyissa meg a projekt tárolóját, és adjon csillagot a Skednek';

  @override
  String get openGithubFailed =>
      'Nem sikerült megnyitni a GitHub tároló linket';

  @override
  String get openPrivacyPolicyFailed =>
      'Nem sikerült megnyitni az adatvédelmi szabályzat hivatkozását';

  @override
  String get selectPeriodTimeSet => 'Válassza ki az időszak meghatározását';

  @override
  String get newItem => 'Új';

  @override
  String get editPeriodTimeSet => 'Periódus időbeállítás szerkesztése';

  @override
  String get importTimetableFiles => 'Importálási menetrend';

  @override
  String get importTimetableFilesDesc =>
      'Támogatja egy vagy több menetrend fájlt.';

  @override
  String get importTimetableText => 'Időterv importálása szövegből';

  @override
  String get importTimetableTextDesc =>
      'Beilleszteni a JSON tartalmat és importálni.';

  @override
  String get shareTimetableFiles => 'Időrend fájlok megosztása';

  @override
  String get shareTimetableFilesDesc =>
      'Válasszon először egy vagy több menetrendet.';

  @override
  String get saveTimetableFiles => 'Időtervfájlok mentése';

  @override
  String get saveTimetableFilesDesc =>
      'Válasszon először egy vagy több menetrendet.';

  @override
  String get exportTimetableText => 'Az ütemterv exportálása szövegként';

  @override
  String get exportTimetableTextDesc =>
      'Válasszon egy vagy több ütemtervet, majd másolja a JSON tartalmat.';

  @override
  String get jsonContent => 'JSON tartalom';

  @override
  String get pasteJsonContentHint => 'A JSON tartalom importálásához.';

  @override
  String get jsonContentEmpty => 'A JSON tartalom beillesztése először.';

  @override
  String get copyText => 'Másolás';

  @override
  String get copiedToClipboard => 'Másolás a vágólapra';

  @override
  String get share => 'Megosztás';

  @override
  String get selectTimetablesToExport => 'Válassza ki az export menetrendjét';

  @override
  String get selectTimetablesToImport =>
      'Válassza ki az importáló menetrendeket';

  @override
  String timetableCourseCount(int count) {
    return '$count tanfolyamok';
  }

  @override
  String get importAction => 'Importálás';

  @override
  String get importTimetableDialogTitle => 'Importálási menetrend';

  @override
  String get chooseImportMethod => 'Válassza ki, hogyan importálja.';

  @override
  String get importAsNewTimetable => 'Importálás új menetrendként';

  @override
  String get replaceCurrentTimetable => 'A jelenlegi menetrend cseréje';

  @override
  String get importPeriodTimeSetDialogTitle => 'Importálási időtartam';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Ez a fájl tartalmazza a csomagolt időszak időkészleteket. Szeretné importálni és társítani őket?';

  @override
  String get importBundledPeriodTimeSets => 'Importálás és társulás';

  @override
  String get discardBundledPeriodTimeSets => 'Eldobja a csomagolt készleteket';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Nem áll rendelkezésre meglévő időszak-időállomány, így a csomagolt időszak-időállományok nem dobhatók el.';

  @override
  String savedToPath(Object path) {
    return 'Mentés $path';
  }

  @override
  String get saveCancelled => 'Mentés törölt';

  @override
  String get fileSaveRestrictedTitle => 'Fájlmentés korlátozott';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'A rendszer nem tudta menteni a fájlt. Ehelyett megpróbálhatja újra, vagy megosztást használhat.';

  @override
  String get retrySave => 'Megpróbálja újra menteni';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Engedélyezze a fájlhozzáférést a rendszerbeállításokban, majd térjen vissza, és próbálja meg újra exportálni.';

  @override
  String get openSettings => 'Beállítások megnyitása';

  @override
  String get browserDownloadRestrictedTitle => 'Böngésző letöltés korlátozott';

  @override
  String get browserDownloadRestrictedMessage =>
      'Ez a böngésző nem támogatja a közvetlen mentést egy helyi fájlba. Ellenőrizze a böngésző letöltési engedélyeit, vagy használja a fájlmegosztást helyette.';

  @override
  String get switchToShare => 'Használja a megosztást helyette';

  @override
  String get fileSaveFailedTitle => 'Nem sikerült mentni a fájlt';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Nem sikerült írni az aktuális útvonalra. Előfordulhat, hogy a célmappa védett, a fájl használatban van, vagy az út nem írható.';

  @override
  String get fileSaveFailedGenericMessage =>
      'A rendszer nem tudta menteni a fájlt. Megpróbálhatja újra, ellenőrizheti a rendszerbeállításokat, vagy ehelyett fájlmegosztást használhat.';

  @override
  String get retryLater => 'Próbálja meg újra később';

  @override
  String get exportSwitchedToShare => 'Váltott fájlmegosztásra az exporthoz';

  @override
  String get saveFailedRetry =>
      'Mentés nem sikerült. Kérjük, próbálja meg újra később.';

  @override
  String get periodTimesUnsavedExitTitle => 'A módosítások nincsenek mentve';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'A tanórák időpontjainak legutóbbi módosításait nem sikerült menteni. Próbálja újra, folytassa a szerkesztést, vagy vesse el őket.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Néhány tanóra időpontja érvénytelen. Mentés előtt javítsa ki őket, vagy vesse el a módosításokat és lépjen ki.';

  @override
  String get discardChangesAndExit => 'Elvetés és kilépés';

  @override
  String get appInstanceBlockedTitle => 'A Sked már meg van nyitva';

  @override
  String get appInstanceBlockedMessage =>
      'Egy másik Sked-ablak vagy böngészőlap használja a helyi adatait. Zárja be, majd próbálja újra.';

  @override
  String get appInstanceLeaseFailedTitle => 'A helyi adatok nem érhetők el';

  @override
  String get appInstanceLeaseFailedMessage =>
      'A Sked nem tudta ellenőrizni a helyi adatokhoz való kizárólagos hozzáférést. Az adatait nem nyitotta meg és nem módosította. Ellenőrizze a tárhely-hozzáférést, majd próbálja újra.';

  @override
  String get savingChanges => 'Változtatások mentése...';

  @override
  String get showApiKey => 'API-kulcs megjelenítése';

  @override
  String get hideApiKey => 'API-kulcs elrejtése';

  @override
  String get importFailedCheckContent =>
      'Nem sikerült importálni. Kérjük, ellenőrizze a fájl tartalmát.';

  @override
  String get noImportableTimetables =>
      'Az importált fájlban nem találtak használható ütemterveket.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importált $count menetrend';
  }

  @override
  String get periodTimesTitle => 'Időszakák';

  @override
  String get importExport => 'Import és export';

  @override
  String get importPeriodTemplate => 'Importálási időszak sablon';

  @override
  String get importPeriodTemplateText => 'Időszablon importálása szövegből';

  @override
  String get sharePeriodTemplate => 'Megosztási időszak sablon';

  @override
  String get saveTemplateToFile => 'Sáblon mentése fájlba';

  @override
  String get exportPeriodTemplateText =>
      'Exportálja az időszak sablont szövegként';

  @override
  String get deletePeriodTimeSet => 'Periódus időbeállítás törlése';

  @override
  String get periodTimeSetName => 'Periódus időbeállítás neve';

  @override
  String get addOnePeriod => 'Periódus hozzáadása';

  @override
  String periodNumberLabel(int index) {
    return 'Periódus $index';
  }

  @override
  String get deleteThisPeriod => 'Törölje ezt az időszakot';

  @override
  String durationMinutes(int minutes) {
    return 'Időtartam $minutes perc';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Előző $minutes perc távolsága';
  }

  @override
  String get endTimeMustBeLater =>
      'A befejezési időnek később kell lennie, mint a kezdési időnek';

  @override
  String get periodOverlapPrevious => 'Ez az időszak átfedi az előzőt';

  @override
  String get periodTimesSaved => 'Mentett időszakok';

  @override
  String get deletePeriodTimeSetTitle => 'Periódus időbeállítás törlése';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return ' \"$name\" törlése?';
  }

  @override
  String get currentPeriodTimeSet => 'jelenlegi időszak időbeállítása';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importált $count időszakok';
  }

  @override
  String get periodFilePermissionTitle => 'Szükség van fájlengedélyre';

  @override
  String get androidFilePermissionMessage =>
      'Az Android export fájlhozzáférési engedélyt igényel. Engedélyt ad a mentés folytatásához.';

  @override
  String get reauthorize => 'Újra engedélyezni';

  @override
  String get permissionPermanentlyDeniedTitle =>
      'Az engedélyt véglegesen megtagadták';

  @override
  String get permissionSettingsExportMessage =>
      'Engedélyezze a fájlhozzáférést a rendszerbeállításokban, majd térjen vissza, és próbálja meg újra exportálni.';

  @override
  String get privacyPolicyTitle => 'Adatvédelmi nyilatkozat';

  @override
  String get privacyPolicyEntryDesc =>
      'Ismerje meg, hogyan kezeli az alkalmazás a helyi tárolást, az iskola-webhely konfigurációját, a fájl importját/exportját, a weboldal elemzését és a külső hivatkozásokat.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Elfogadott verzió: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'A Sked egy helyi alapú órarend eszköz. Az órarendek, az időtartam-készletek és az iskolahely konfigurációja csak az Ön eszközén vagy böngészőjében tárolódik, és soha nem kerül automatikusan feltöltésre. Az alkalmazás csak akkor dolgoz fel adatokat, amikor kifejezetten olyan műveleteket indít, mint az importálás, a weboldal-elemzés, a megosztás vagy a külső hivatkozások megnyitása. A teljes adatvédelmi szabályzat online érhető el.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Helyi tárolás';

  @override
  String get privacyPolicyLocalStorageBody =>
      'Natív platformokon a Sked az órarend adatait, az általános naptárakat, a kapcsolódó beállításokat és a szerkeszthető iskolai webhelykonfigurációt az operációs rendszer alkalmazástámogatási könyvtárában tárolja; a böngészős változat a böngésző tárhelyét használja. A korábbi verziók által a felhasználó Dokumentumok mappájába írt fájlok a helyükön maradnak, de az alkalmazás nem olvassa be és nem költözteti át őket automatikusan. Az adatok megőrzéséhez frissítés előtt exportáljon teljes alkalmazásmentést a régi verzióból, majd állítsa vissza az újban. Az AI API beállításai helyben tárolódnak; az egyéni API-kulcs a platform biztonságos tárolójába kerül, ha az elérhető. A teljes alkalmazásmentés nem tartalmazza az egyéni API-kulcsot. Az alkalmazás nem tölti fel automatikusan ezeket a helyi adatokat a fejlesztő által kezelt szerverre.';

  @override
  String get privacyPolicyImportExportTitle => 'Import és export';

  @override
  String get privacyPolicyImportExportBody =>
      'Az alkalmazás csak akkor olvas vagy írja el az ütemterv JSON fájljait, az iskolai helyszín JSON fájljait és az időszak-sablon fájljait, ha kifejezetten kiválaszt egy fájlt vagy elkezd egy exportálási műveletet. Ezek a fájlok importálása helyi művelet, kivéve, ha a weboldal elemzését is választja. Az egyéni modelllista beszerzése is egy kifejezett hálózati művelet, és csak az Ön által konfigurált egyéni végponttal lép kapcsolatba.';

  @override
  String get privacyPolicySharingTitle => 'Megosztás';

  @override
  String get privacyPolicySharingBody =>
      'Ha kifejezetten megosztást használ, az alkalmazás továbbítja az exportált fájlt a rendszermegosztási lapra vagy az Ön által kiválasztott célalkalmazásra. A fájl későbbi kezelése az Ön által kiválasztott célalkalmazástól vagy szolgáltatástól függ.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Külső linkek';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Ha külső hivatkozásokat nyit, például a GitHub tárolót, az alkalmazás átadja a műveletet a böngészőjének vagy egy másik külső alkalmazásnak. Az e pont után történő adatkezelést az Ön által megnyitott harmadik fél szabályozza.';

  @override
  String get privacyPolicyNoCollectionTitle =>
      'Amit az alkalmazás nem gyűjt össze';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Az alkalmazáshoz nincs szükség Sked fiókra, és nem engedélyezi az elemzést, a hirdetési azonosítókat vagy a felhő biztonsági mentését. Nem biztosít külön mezőt az iskola fiókjának jelszavai gyűjtésére. Ha bejelentkezik egy iskolai weboldalra az alkalmazáson belül, az interakció az Ön által megnyitott iskolai oldalon történik.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Weboldal elemzése';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Amikor iskolai weboldal importálását használod, vagy beillesztett órarendszöveget / HTML-t elemeztetsz, az alkalmazás először helyben előkészíti és megtisztítja a tartalmat, majd elküldi a beküldött órarendszöveget, oldalszöveget vagy HTML-tartalmat, az opcionális oldal címet és URL-t, az alkalmazás aktuális nyelvét és az elemző prompt tartalmát az általad beállított OpenAI-kompatibilis végpontra. A modelllista lekérése is ugyanezt a végpontot hívja meg. A Sked nem biztosít beépített elemző végpontot, és nem küld elemzési kéréseket fejlesztő által vezérelt órarendelemző háttérrendszernek. Az egyéni végpont és az esetleges upstream szolgáltatások az általad választott szolgáltató szabályai szerint tárolhatják, továbbíthatják, korlátozhatják, törölhetik vagy más módon kezelhetik az adatokat. Ha http:// Base URL-t használsz, csak megbízható eszközökön, hálózatokon és végpontszolgáltatásokkal használd, mert a tartalom és az API-kulcsok nem feltétlenül védettek szállítási titkosítással.';

  @override
  String get privacyPolicyUpdatesTitle => 'Politikai frissítések';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'A jelenlegi adatvédelmi szabályzat verziója $version. Ha egy későbbi verzió megváltoztatja az adatok kezelésének módját, az alkalmazás megkérheti Önt, hogy újra olvassa el és elfogadja a frissített szabályzatot.';
  }

  @override
  String get privacyGateTitle =>
      'Kérjük, elfogadja az adatvédelmi szabályzatot az alkalmazás használata előtt';

  @override
  String get privacyGateSummaryStorage =>
      'Az ütemtervek, az időtartam-készletek és az iskola-helyszín konfigurációja csak helyileg tárolódik, és nem tölthetők fel automatikusan a fejlesztői kiszolgálóra.';

  @override
  String get privacyGateSummaryImportExport =>
      'Az import, az export és a megosztás csak akkor történik, ha kifejezetten elindítja őket; A weboldal elemzése csak az Ön által beküldött tömörített tartalmat küld a konfigurált elemzési végponthoz, és a mentés előtt felülvizsgálhatja a elemzett ütemtervet.';

  @override
  String get privacyGateSummaryUpdates =>
      'Ha egy későbbi verzió megváltoztatja az adatok kezelésének módját, az alkalmazás megkérheti Önt, hogy újra ellenőrizze a frissített adatvédelmi szabályzatot.';

  @override
  String get schoolWebImportEntry => 'Importálás az iskola weboldaláról';

  @override
  String get schoolWebImportEntryDesc =>
      'Importálja az aktuális menetrend oldalát az iskola webhelyéről.';

  @override
  String get schoolSitesManageEntry => 'Iskolai webhelyek kezelése';

  @override
  String get schoolSitesManageEntryDesc =>
      'Hozzáadás, szerkesztés és törlés iskolai bejelentkezési URL-ek, JSON import és export.';

  @override
  String get schoolSitesPageTitle => 'Iskolai helyszín menedzsment';

  @override
  String get schoolSitesImportJson => 'Iskola JSON importálása';

  @override
  String get schoolSitesShareJson => 'Iskola JSON megosztása';

  @override
  String get schoolSitesSaveJson => 'Iskola JSON mentése';

  @override
  String get schoolSitesSaved => 'Iskolai oldalak mentése';

  @override
  String get schoolSitesImported => 'Importált iskolai helyszínek';

  @override
  String get schoolSitesImportPreviewTitle =>
      'Iskolai webhelyek importálásának áttekintése';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Érvényes webhelyek: $validCount, érvénytelen bejegyzések: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'A fájl üres iskolai webhelylistát tartalmaz.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'A(z) $position. bejegyzés érvénytelen, ezért kimarad.';
  }

  @override
  String get schoolSitesImportMerge => 'Egyesítés';

  @override
  String get schoolSitesImportReplace => 'Csere';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Lecseréli a jelenlegi iskolai webhelyeket?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Ez eltávolít $currentCount jelenlegi webhelyet, és ment $importedCount importált webhelyet. A művelet nem vonható vissza.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Az iskolai webhelyadatok helyreállítást igényelnek';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'A Sked nem tudta beolvasni az iskolai webhelyek fájlját vagy annak biztonsági mentését. Az írás letiltása előtt védett másolatok készültek.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Az iskolai webhelyek tárhelye nem érhető el';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'A Sked jelenleg nem fér hozzá az iskolai webhelyek tárhelyéhez. Ellenőrizze a tárhely elérhetőségét és az eszközt, majd próbálja újra. A jelenlegi webhelyadatok nem lesznek felülírva.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'A helyreállítási fájlok és az érintett tárhelyek alább láthatók. A webhelylista helyreállításáig ne módosítsa a fájlokat.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Kezdés iskolai webhelyek nélkül';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Üres iskolai webhelylistával kezd?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'A védett másolatok megmaradnak, de a Sked új, üres iskolai webhelyfájlt hoz létre. Csak akkor folytassa, ha előbb nem szeretné újrapróbálni a helyreállítást.';

  @override
  String get schoolSitesEmpty => 'Még nincs iskolai helyszín konfigurációja.';

  @override
  String get schoolSitesNameLabel => 'Iskola neve';

  @override
  String get schoolSitesLoginUrlLabel => 'Bejelentkezési URL';

  @override
  String get schoolSitesAdd => 'Iskola hozzáadása';

  @override
  String get schoolSitesEdit => 'Iskola szerkesztése';

  @override
  String get schoolSitesDeleteTitle => 'Iskola törlése';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return ' \"$name\" törlése?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Töltse ki először az iskola nevét és a bejelentkezési URL-t.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importálás ütemterv oldal tartalma beillesztésével';

  @override
  String get schoolHtmlImportEntryDesc =>
      'A forráskódot vagy a menetrend információit tartalmazó nyers oldal tartalmát manuálisan kell beilleszteni.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Időterv elemzése az oldal tartalmából';

  @override
  String get schoolHtmlImportUrlLabel => 'Forrás URL (opcionális)';

  @override
  String get schoolHtmlImportTitleLabel => 'Oldal címe (opcionális)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Oldal tartalma';

  @override
  String get schoolHtmlImportHtmlHint =>
      'A forráskódot vagy az ütemterv információit tartalmazó nyers oldaltartalmat illessze ide.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Minden tartalom, amely időrend információkat tartalmaz, elemezhető és importálható, nem csak HTML.';

  @override
  String get schoolHtmlImportCompress => 'Tartalom előkészítése';

  @override
  String get schoolHtmlImportCompressed => 'Tartalom előkészítve';

  @override
  String get schoolHtmlImportCompressFirst =>
      'Először készítse elő a tartalmat.';

  @override
  String get schoolHtmlImportSubmit => 'Elemzés és importálás';

  @override
  String get schoolImportContentTruncated =>
      'Ez az oldal elérte a biztonságos importálási korlátot. Csak a rögzített rész lesz elküldve elemzésre.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Az elemzés eltarthat egy ideig. Kérem, várjon!';

  @override
  String get schoolHtmlImportEmpty => 'Helyezze be először a HTML oldalt.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Vissza a weboldalra';

  @override
  String get schoolWebImportPageTitle => 'Iskolai weboldal importálása';

  @override
  String get schoolWebImportPreview => 'Előnézet importálása';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count tanfolyamok';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count időszakok';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Oldal címe';

  @override
  String get schoolWebImportParserUsed => 'Feldolgozó';

  @override
  String get schoolWebImportWarnings => 'Importáljon jegyzeteket';

  @override
  String get schoolWebImportParserDetails => 'Az elemzés részletei';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Az elemzés részleteinek kibontása';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Az elemzés részleteinek összecsukása';

  @override
  String get schoolWebImportOpenPageHint =>
      'Jelentkezzen be az iskola webhelyére az alkalmazásban, majd navigáljon a menetrend oldalára manuálisan.';

  @override
  String get schoolWebImportConfigMissing =>
      'Az egyéni feldolgozó beállítása hiányos. Előbb adja meg az alap URL-t, az API-kulcsot és a modellt.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Ez a platform még nem támogatja a beágyazott webes bejelentkezést. Kérjük, használjon WebView támogatással rendelkező platformot.';

  @override
  String get schoolWebImportSelectSchool => 'Válasszon iskolát';

  @override
  String get schoolWebImportNoSchools =>
      'Nincs iskolai konfiguráció elérhető. Ellenőrizze először a school_sites.json-t.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Nem sikerült betölteni az iskola konfigurációját. Ellenőrizze a JSON fájlformátumot.';

  @override
  String get schoolWebImportImportCurrentPage => 'Aktuális oldal importálása';

  @override
  String get schoolWebImportLoadingPage => 'Oldal betöltése…';

  @override
  String get schoolWebImportParsing => 'Az aktuális oldal elemzése...';

  @override
  String get schoolWebImportLoadFailed =>
      'Az oldal betöltése nem sikerült. Kérjük, frissítse meg vagy próbálja meg újra később.';

  @override
  String get schoolWebImportUnknownOrigin => 'Ismeretlen webhely';

  @override
  String get schoolWebImportExitTitle => 'Kilép a böngészőből?';

  @override
  String get schoolWebImportExitMessage =>
      'Az oldal bezárul. Minden, amit még nem importált, elveszik.';

  @override
  String get schoolWebImportExitConfirm => 'Kilépés';

  @override
  String get schoolWebImportEmptyPage =>
      'Az aktuális oldal tartalma üres, és még nem lehet importálni.';

  @override
  String get schoolWebImportSuccess => 'Web menetrend importált';

  @override
  String get schoolImportParserSettingsTitle => 'Órarend-feldolgozó API';

  @override
  String get schoolImportParserSettingsDesc =>
      'Az órarendek importálásához használt OpenAI-kompatibilis API beállítása. Ez nem a csevegőasszisztens beállítása.';

  @override
  String get schoolImportParserSourceTitle => 'Parser forrás';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Egyéni OpenAI-kompatibilis';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Egyéni OpenAI-kompatibilis elemző';

  @override
  String get schoolImportParserCustomPromptTitle => 'Egyéni prompt';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Szerkesztse a beépített elemző hívást itt. A változások csak az egyedi OpenAI-kompatibilis elemzőt érintik.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'A beépített hívó alapértelmezés szerint itt van betöltve. Törölje, hogy visszatérjen a beépített verzióhoz.';

  @override
  String get schoolImportParserResetDefaultPrompt =>
      'Az alapértelmezett hívó visszaállítása';

  @override
  String get schoolImportParserBaseUrl => 'Bázis URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'A Base URL mezőnek gazdagépet tartalmazó HTTP- vagy HTTPS-címnek kell lennie.';

  @override
  String get schoolImportParserApiKey => 'API kulcs';

  @override
  String get schoolImportParserModel => 'modell';

  @override
  String get schoolImportParserFetchModels => 'Modelllista beszerzése';

  @override
  String get schoolImportParserFetchingModels => 'Modelleket hozni. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'A végpont nem adott vissza modellt.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Nem sikerült lekérni a modelleket. Ellenőrizze a végpontot, és próbálja újra.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Megszerzett $count modellek';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'Az egyéni API-kulcs a platform biztonságos tárolójába kerül, ha az elérhető. Egyéni feldolgozói hitelesítő adatokat és HTTP-végpontokat csak megbízható eszközökön, böngészőkben és hálózatokon használjon.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Titkosítatlan HTTP-végpontot használ?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Az API-kulcs és az órarend tartalma átvitel közben elolvasható vagy módosítható. Csak akkor folytassa, ha megbízik ebben az eszközben, hálózatban és végpontban. A jóváhagyás a Sked bezárásáig érvényes.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Az egyéni elemző konfigurációja nem teljes. Töltse ki először az alap URL-t, az API kulcsot és a modellt.';

  @override
  String get clearAppData => 'Adatok törlése';

  @override
  String get clearAppDataDesc =>
      'A Sked összes helyi adatának végleges törlése és kilépés az alkalmazásból';

  @override
  String get clearAppDataConfirmTitle => 'Törli a Sked összes adatát?';

  @override
  String get clearAppDataConfirmMessage =>
      'Ez végleg törli az órarendeket, naptárakat, beállításokat, iskolai webhelyeket, helyi biztonsági mentéseket, helyreállítási másolatokat és az AI API-kulcsot, majd bezárja a Skedet. A máshová exportált fájlok nem törlődnek. A művelet nem vonható vissza.';

  @override
  String get clearAppDataAction => 'Adatok törlése és kilépés';

  @override
  String get clearAppDataFailed =>
      'Nem sikerült minden helyi adatot törölni. A Sked nyitva marad, hogy újra próbálkozhasson.';

  @override
  String get clearAppDataExitFailed =>
      'A helyi adatok törlődtek, de a Sked nem tudott kilépni. Újbóli használat előtt zárja be kézzel az alkalmazást.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Parser: Egyéni ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Teljes adatvédelmi szabályzat megtekintése';

  @override
  String get privacyAgreeAndContinue => 'Egyetértek és folytatjuk';

  @override
  String get privacyDecline => 'Elutalás';

  @override
  String get privacyDeclineWebHint =>
      'Ez a böngészőkörnyezet nem engedélyezi, hogy az alkalmazás bezárja az oldalt az Ön számára. Ha nem ért egyet, kérjük, zárja be ezt a lapot vagy ablakot.';

  @override
  String get defaultPeriodTimeSetName => 'Alapértelmezett időszakok';

  @override
  String get periodTimeSetFallbackName => 'Időszakák';

  @override
  String get untitledTimetableName => 'Cím nélküli menetrend';

  @override
  String get newTimetableName => 'Új menetrend';

  @override
  String get newPeriodTimeSetName => 'Új időszak beállítása';

  @override
  String get emptyTimetableName => 'Üres menetrend';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name időszakok';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Az importált fájltípus nem felel meg.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Ez a fájl importálási verziója még nem támogatott.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Az import fájlban nem találtak időszakot.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Kérjük, válasszon legalább egy menetrendet.';

  @override
  String get noExportableTimetableMessage =>
      'Az exportra nincs rendelkezésre álló menetrend.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'A jelenlegi menetrend cseréje csak egy menetrend kiválasztását támogatja.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Nincs jelenlegi menetrend a cserélésre.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Ezt az időszakot a $count menetrend(ek) még mindig használja. A törlés előtt újratörölje őket.';
  }

  @override
  String get weekdayMonday => 'Hétfő';

  @override
  String get weekdayTuesday => 'kedd';

  @override
  String get weekdayWednesday => 'szerda';

  @override
  String get weekdayThursday => 'csütörtök';

  @override
  String get weekdayFriday => 'péntek';

  @override
  String get weekdaySaturday => 'szombat';

  @override
  String get weekdaySunday => 'Vasárnap';

  @override
  String get weekdayShortMonday => 'hétfő';

  @override
  String get weekdayShortTuesday => 'kedd';

  @override
  String get weekdayShortWednesday => 'szerda';

  @override
  String get weekdayShortThursday => 'csütörtök';

  @override
  String get weekdayShortFriday => 'péntek';

  @override
  String get weekdayShortSaturday => 'szombat';

  @override
  String get weekdayShortSunday => 'Nap';

  @override
  String get monthJanuary => 'január';

  @override
  String get monthFebruary => 'február';

  @override
  String get monthMarch => 'március';

  @override
  String get monthApril => 'április';

  @override
  String get monthMay => 'május';

  @override
  String get monthJune => 'Június';

  @override
  String get monthJuly => 'július';

  @override
  String get monthAugust => 'Augusztus';

  @override
  String get monthSeptember => 'szeptember';

  @override
  String get monthOctober => 'október';

  @override
  String get monthNovember => 'nov';

  @override
  String get monthDecember => 'decemberben';

  @override
  String get semesterWeeksWholeTerm => 'Minden félévben';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Hetek $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Hetek $value';
  }

  @override
  String get generalSchedule => 'Általános naptár';

  @override
  String get studentTimetable => 'Tanulói órarend';

  @override
  String get firstLaunchTitle => 'Válassza ki a kezdő módot';

  @override
  String get firstLaunchSubtitle =>
      'Válassza ki a leggyakrabban használt munkaterületet. Később módot válthat.';

  @override
  String get firstLaunchStudentDesc =>
      'Órarendek, kurzusok, hetek, órakezdések és importok kezelése.';

  @override
  String get firstLaunchGeneralDesc =>
      'Kategóriák, események, emlékeztetők és JSON / ICS adatok kezelése.';

  @override
  String get firstLaunchStartStudent => 'Kezdés órarenddel';

  @override
  String get firstLaunchStartGeneral => 'Kezdés naptárral';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'A kezdő munkaterület kiválasztásával megerősíti, hogy elolvasta és elfogadja az ';

  @override
  String get firstLaunchPrivacyConsentLink => 'Adatvédelmi szabályzatot';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Módváltás';

  @override
  String get generalScheduleComingSoon =>
      'Az általános naptár hamarosan elérhető';

  @override
  String get switchToStudentTimetable => 'Váltás a tanulói órarendre';

  @override
  String get mySchedule => 'Saját naptár';

  @override
  String get today => 'Ma';

  @override
  String get addEvent => 'Esemény hozzáadása';

  @override
  String get editEvent => 'Esemény szerkesztése';

  @override
  String get eventTitle => 'Cím';

  @override
  String get eventTitleRequired => 'A cím kötelező';

  @override
  String get eventStartTime => 'Kezdési idő';

  @override
  String get eventEndTime => 'Befejezési idő';

  @override
  String get eventDate => 'Dátum';

  @override
  String get eventTime => 'Idő';

  @override
  String get eventNotes => 'Jegyzetek';

  @override
  String get eventColor => 'Szín';

  @override
  String get eventRecurrence => 'Ismétlés';

  @override
  String get recurrenceNone => 'Nincs ismétlés';

  @override
  String get recurrenceWeekly => 'Hetente';

  @override
  String get recurrenceEndDate => 'Záró dátum';

  @override
  String get recurrenceNoEndDate => 'Nincs záró dátum';

  @override
  String get recurrenceSetEndDate => 'Beállítás';

  @override
  String get recurrenceChangeEndDate => 'Módosítás';

  @override
  String get repeatsWeekly => 'Hetente ismétlődik';

  @override
  String recurrenceUntil(Object date) {
    return 'Eddig: $date';
  }

  @override
  String get switchToGeneralSchedule => 'Váltás az általános naptárra';

  @override
  String get generalDisplaySettings => 'Általános megjelenítési beállítások';

  @override
  String get generalDisplaySettingsDesc =>
      'Nézetek, eszköztár, dátumformátum és gyors hozzáadás';

  @override
  String get closePopupOnOutsideTap =>
      'Felugró ablak bezárása külső koppintásra';

  @override
  String get showGridLines => 'Rácsvonalak megjelenítése';

  @override
  String get generalScheduleImportExport =>
      'Kategóriák importálása és exportálása';

  @override
  String get generalScheduleImportExportDesc =>
      'Naptárkategóriák importálása vagy megosztása';

  @override
  String get importGeneralSchedules => 'Kategóriák importálása';

  @override
  String get importGeneralSchedulesDesc => 'Kategóriák beolvasása JSON-fájlból';

  @override
  String get shareGeneralSchedules => 'Kategóriák megosztása';

  @override
  String get shareGeneralSchedulesDesc => 'Kategóriák megosztása JSON-fájlként';

  @override
  String get saveGeneralSchedules => 'Kategóriák mentése';

  @override
  String get saveGeneralSchedulesDesc => 'Kategóriák mentése JSON-fájlként';

  @override
  String get selectSchedulesToExport => 'Exportálandó kategóriák kiválasztása';

  @override
  String get selectSchedulesToImport => 'Importálandó kategóriák kiválasztása';

  @override
  String generalScheduleEventCount(int count) {
    return 'Események: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Importált kategóriák: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Új kategóriaként adja hozzá az importált adatokat, vagy lecserél egy meglévő kategóriát?';

  @override
  String get addAsNewSchedule => 'Hozzáadás új kategóriaként';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Válasszon legalább egy kategóriát.';

  @override
  String get noExportableScheduleMessage => 'Nincs exportálható kategória.';

  @override
  String get noSchedulesInImportMessage =>
      'Az importfájl nem tartalmaz kategóriákat.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'A cseréhez pontosan egy importált kategóriát válasszon.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'A cserére kiválasztott kategória nem érhető el.';

  @override
  String get calendars => 'Kategóriák';

  @override
  String get calendar => 'Kategória';

  @override
  String get viewWeek => 'Hét';

  @override
  String get viewDay => 'Nap';

  @override
  String get viewList => 'Lista';

  @override
  String get viewMonth => 'Hónap';

  @override
  String visibleCategoryCount(int count) {
    return '$count kategória';
  }

  @override
  String get noVisibleCategories => 'Nincsenek látható kategóriák';

  @override
  String get selectCategoryToReplace => 'Lecserélendő kategória kiválasztása';

  @override
  String get replaceCategory => 'Kategória cseréje';

  @override
  String get deleteEventTitle => 'Esemény törlése';

  @override
  String get deleteEventConfirmation => 'Ez az esemény véglegesen törlődik.';

  @override
  String get deleteRecurringEventTitle => 'Ismétlődő esemény törlése';

  @override
  String get eventDuplicated => 'Esemény megkettőzve';

  @override
  String get searchEvents => 'Események keresése';

  @override
  String get clearSearch => 'Keresés törlése';

  @override
  String get filterByColor => 'Szűrés szín szerint';

  @override
  String get allColors => 'Minden szín';

  @override
  String upcomingEventsCount(int count) {
    return 'Közelgő: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Lejárt: $count';
  }

  @override
  String get allDay => 'Egész napos';

  @override
  String get collapseAllDayTimeline => 'Egész napos események összecsukása';

  @override
  String get expandAllDayTimeline => 'Egész napos események kibontása';

  @override
  String allDayEventsCount(int count) {
    return '$count egész napos esemény';
  }

  @override
  String moreEvents(int count) {
    return '+$count további';
  }

  @override
  String get noMatchingEvents => 'Nincs megfelelő esemény';

  @override
  String get noUpcomingEvents => 'Nincsenek közelgő események';

  @override
  String get addCalendar => 'Kategória hozzáadása';

  @override
  String get newCalendar => 'Új kategória';

  @override
  String get hideCalendar => 'Kategória elrejtése';

  @override
  String get showCalendar => 'Kategória megjelenítése';

  @override
  String get rename => 'Átnevezés';

  @override
  String get renameCalendar => 'Kategória átnevezése';

  @override
  String get name => 'Név';

  @override
  String get deleteCalendar => 'Kategória törlése';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Törli ezt: „$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Csak ennek az előfordulásnak a törlése';

  @override
  String get deleteFutureOccurrences => 'Ennek és a következőknek a törlése';

  @override
  String get deleteAllOccurrences => 'Teljes sorozat törlése';

  @override
  String get duplicateEvent => 'Megkettőzés';

  @override
  String get repeatsDaily => 'Naponta ismétlődik';

  @override
  String get repeatsMonthly => 'Havonta ismétlődik';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Ismétlés: $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count alkalom';
  }

  @override
  String get recurrenceDaily => 'Naponta';

  @override
  String get recurrenceMonthly => 'Havonta';

  @override
  String get recurrenceCustom => 'Egyéni';

  @override
  String get recurrenceEvery => 'Gyakoriság';

  @override
  String get recurrenceUnit => 'Egység';

  @override
  String get recurrenceDays => 'nap';

  @override
  String get recurrenceWeeks => 'hét';

  @override
  String get recurrenceMonths => 'hónap';

  @override
  String get recurrenceRepeatCount => 'Ismétlések száma';

  @override
  String get recurrenceNoLimit => 'Korlátlan';

  @override
  String get recurrencePositiveNumber => 'Adjon meg pozitív számot';

  @override
  String get clearEndDate => 'Záró dátum törlése';

  @override
  String get pickDate => 'Dátum választása';

  @override
  String get pickTime => 'Idő választása';

  @override
  String get reminder => 'Alkalmazáson belüli emlékeztető';

  @override
  String get reminderAtStart => 'Kezdéskor';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes perccel előtte';
  }

  @override
  String get reminderHourBefore => '1 órával előtte';

  @override
  String get reminderDayBefore => '1 nappal előtte';

  @override
  String get markReminderHandled => 'Megjelölés kezeltként';

  @override
  String get restoreReminder =>
      'Alkalmazáson belüli emlékeztető visszaállítása';

  @override
  String get reminderHandled =>
      'Alkalmazáson belüli emlékeztető kezeltként megjelölve';

  @override
  String get reminderRestored =>
      'Alkalmazáson belüli emlékeztető visszaállítva';

  @override
  String get reminderUpcoming => 'Közelgő';

  @override
  String get reminderOverdue => 'Lejárt';

  @override
  String get generalFitWeekColumnsToWidth => 'Heti nézet képernyőhöz igazítása';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'A teljes hét megjelenítése kompakt elrendezésben. Kikapcsolva vízszintesen görgethető. A 7 napnál hosszabb egyéni tartományok továbbra is görgethetők.';

  @override
  String get showWeekends => 'Hétvégék megjelenítése';

  @override
  String get startHour => 'Kezdő óra';

  @override
  String get endHour => 'Záró óra';

  @override
  String get timeGridDensity => 'Időrács sűrűsége';

  @override
  String get timeGridHourHeight => 'Órasor magassága';

  @override
  String get timeGridHourHeightHint =>
      'A napi és heti nézet függőleges léptékét módosítja a 15, 30 vagy 60 perces rácsköz megváltoztatása nélkül.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'JSON-fájl importálása';

  @override
  String get pasteJson => 'JSON beillesztése';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Kategóriák importálása másolt JSON-ból';

  @override
  String get importIcsFile => 'ICS-fájl importálása';

  @override
  String get importIcsFileDesc => 'Események beolvasása .ics naptárfájlból';

  @override
  String get pasteIcs => 'ICS beillesztése';

  @override
  String get pasteIcsDesc => 'Események importálása másolt naptárszövegből';

  @override
  String get copyJson => 'JSON másolása';

  @override
  String get copyJsonDesc => 'Kijelölt kategóriák másolása JSON-szövegként';

  @override
  String get shareIcs => 'ICS megosztása';

  @override
  String get shareIcsDesc => 'Kijelölt naptárak megosztása .ics formátumban';

  @override
  String get saveIcs => 'ICS mentése';

  @override
  String get saveIcsDesc => 'Kijelölt naptárak mentése .ics formátumban';

  @override
  String get copyIcs => 'ICS másolása';

  @override
  String get copyIcsDesc => 'Kijelölt naptárak másolása ICS-szövegként';

  @override
  String get importIcs => 'ICS importálása';

  @override
  String get icsContent => 'ICS-tartalom';

  @override
  String get pasteIcsContentHint => 'Illessze ide a BEGIN:VCALENDAR tartalmat';

  @override
  String importIcsPreviewPrompt(int count) {
    return '$count esemény található. Új kategóriaként adja hozzá őket, vagy lecserél egy meglévőt?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Importált kategóriák: $count; figyelmeztetések: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Egy kezdési idő nélküli esemény kimaradt.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Egy nem támogatott kezdési idejű esemény kimaradt.';

  @override
  String get importWarningAdjustedEnd =>
      'Egy esemény befejezési ideje módosult, mert nem volt későbbi a kezdésnél.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'A nem támogatott ICS-mezők a jegyzetekbe kerültek: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Nem támogatott ismétlési gyakoriság figyelmen kívül hagyva: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'ICS-ként másolandó naptárak kiválasztása';

  @override
  String get selectCalendarsToExportIcs =>
      'ICS-ként exportálandó naptárak kiválasztása';

  @override
  String get exportIcsText => 'ICS-szöveg exportálása';

  @override
  String get exportJsonText => 'JSON-szöveg exportálása';

  @override
  String get dataRestoredFromBackupNotice =>
      'Az alkalmazás adatai a korábbi biztonsági mentésből álltak helyre, mert a fő fájlt nem sikerült betölteni.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'A fő adatfájl és a biztonsági mentése is sérült. Az alkalmazás most új, kezdeti állapotot használ.';

  @override
  String get dataRecoveryCorruptTitle => 'Az adatok helyreállítást igényelnek';

  @override
  String get dataRecoveryCorruptMessage =>
      'A Sked nem tudta beolvasni a fő adatfájlt vagy annak biztonsági mentését. Az írás letiltása előtt védett másolatok készültek.';

  @override
  String get dataRecoveryIoFailureTitle => 'A tárhely nem érhető el';

  @override
  String get dataRecoveryIoFailureMessage =>
      'A Sked jelenleg nem fér hozzá a helyi tárhelyhez. Ellenőrizze a tárhely elérhetőségét és az eszközt, majd próbálja újra. A meglévő adatok nem lesznek felülírva.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Az adatok megnyitásához frissítse a Skedet';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Ezeket az adatokat a Sked újabb verziója hozta létre. Újrapróbálkozás előtt frissítse az alkalmazást. Az adatok védelmében az újrakezdés le van tiltva.';

  @override
  String get dataRecoveryRetryAction => 'Újrapróbálás';

  @override
  String get dataRecoveryArtifactsHint =>
      'A helyreállítási fájlok és az érintett tárhelyek alább láthatók. Az adatok helyreállításáig ne módosítsa a fájlokat.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Helyreállítási fájlok és helyek megjelenítése';

  @override
  String get dataRecoveryStartFreshAction => 'Kezdés új adatokkal';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Új adatokkal kezd?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'A védett másolatok megmaradnak, de a Sked új helyi adatfájlt hoz létre. Csak akkor folytassa, ha előbb nem szeretné újrapróbálni a helyreállítást.';

  @override
  String get previousMonth => 'Előző hónap';

  @override
  String get nextMonth => 'Következő hónap';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes perc';
  }

  @override
  String get reminderInProgress => 'Folyamatban';

  @override
  String get deleteCourseTitle => 'Tantárgy törlése';

  @override
  String get deleteCourseMessage => 'Törli ezt a tantárgyat?';

  @override
  String get showLunarCalendar => 'Holdnaptár megjelenítése';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count esemény';
  }

  @override
  String get defaultView => 'Alapértelmezett nézet';

  @override
  String get generalDefaultViewSection => 'Indítás';

  @override
  String get generalViewSwitchBehavior => 'Nézetváltó gomb';

  @override
  String get settingsWorkspaceMode => 'Aktív munkaterület';

  @override
  String get hideHomeWorkspaceNavigation => 'Munkaterület-navigáció elrejtése';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'A munkaterületek navigációjának elrejtése. A főképernyő munkaterület-menüjében továbbra is válthat.';

  @override
  String get generalDateLabelFormat => 'Dátumfelirat formátuma';

  @override
  String get generalDateLabelFormatLocalized => 'Helyi (2026. júl.)';

  @override
  String get generalDateLabelFormatSlash => 'Perjeles (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Eszköztár elrendezése';

  @override
  String get toolbarNavigationSection => 'Eszköztár navigációja';

  @override
  String get toolbarNavigationHiddenBehavior => 'Rejtett elemek';

  @override
  String get toolbarNavigationRemove => 'Teljes elrejtés';

  @override
  String get toolbarNavigationMore => 'Áthelyezés a Továbbiak menübe';

  @override
  String get toolbarNavigationReorder => 'Eszköztárelemek átrendezése';

  @override
  String get toolbarNavigationVisibility => 'Eszköztárelem megjelenítése';

  @override
  String get toolbarNavigationTimetable => 'Órarendválasztó';

  @override
  String get toolbarNavigationWeek => 'Hétválasztó';

  @override
  String get toolbarNavigationView => 'Nézetváltó';

  @override
  String get toolbarNavigationCategory => 'Kategóriaválasztó';

  @override
  String get toolbarNavigationDate => 'Dátumválasztó';

  @override
  String get generalToolbarWidthPolicy => 'Eszköztár helyelosztása';

  @override
  String get generalToolbarWidthContent => 'Automatikus elosztás';

  @override
  String get generalToolbarWidthBalanced => 'Kiegyensúlyozott';

  @override
  String get generalToolbarWidthCalendarPriority => 'Kategória elsőbbsége';

  @override
  String get generalToolbarWidthDatePriority => 'Dátum elsőbbsége';

  @override
  String get generalViewSwitchCycle => 'Nézetek váltása sorban';

  @override
  String get generalViewSwitchMenu => 'Nézetmenü megnyitása';

  @override
  String get generalViewSwitchTooltip => 'Nézetváltás';

  @override
  String get generalViewSwitchMenuTooltip => 'Nézet választása';

  @override
  String get generalViewLongPressTodayHint =>
      'Hosszan nyomva a mai napra ugrik';

  @override
  String get generalScheduleDisplaySection => 'Naptár megjelenítése';

  @override
  String get generalTimeGridSection => 'Időrács';

  @override
  String get generalPopupSection => 'Felugró ablak viselkedése';

  @override
  String get quickActionsSection => 'Gyorsműveletek';

  @override
  String get showAddCourseFab => 'Lebegő tantárgy-hozzáadás gomb megjelenítése';

  @override
  String get showAddCourseFabHint =>
      'Az órarend jobb alsó sarkában lévő lebegő tantárgy-hozzáadás gomb megjelenítése vagy elrejtése.';

  @override
  String get showAddEventFab => 'Lebegő esemény-hozzáadás gomb megjelenítése';

  @override
  String get showAddEventFabHint =>
      'A naptár jobb alsó sarkában lévő lebegő esemény-hozzáadás gomb megjelenítése vagy elrejtése.';

  @override
  String get enableLongPressAddCourse =>
      'Tantárgy hozzáadása a rács hosszú megnyomásával';

  @override
  String get enableLongPressAddCourseHint =>
      'Tantárgy hozzáadásához nyomja meg hosszan az órarend rácsának üres területét.';

  @override
  String get enableLongPressAddEvent =>
      'Esemény hozzáadása a rács hosszú megnyomásával';

  @override
  String get enableLongPressAddEventHint =>
      'Napi vagy heti nézetben nyomja meg hosszan az időrács üres területét egy esemény hozzáadásához.';

  @override
  String get developerModeTitle => 'Fejlesztői mód';

  @override
  String get developerModeDescription =>
      'Eszközök teljes mintaadatok hozzáadásához a megjelenés és a működés ellenőrzésére.';

  @override
  String get developerSampleLanguage => 'Mintaadatok nyelve';

  @override
  String get developerSampleChinese => 'Kínai';

  @override
  String get developerSampleEnglish => 'Angol';

  @override
  String get developerSampleDataDescription =>
      'Egy órarendet, valamint kategóriákat és eseményeket ad hozzá a meglévő adatok felülírása nélkül.';

  @override
  String get developerAddSampleData => 'Mintaadatok hozzáadása';

  @override
  String get developerSampleDataAdded =>
      'A mintaórarend és az események hozzáadva.';

  @override
  String get developerModeLongPressHint =>
      'Tartsa lenyomva 3 másodpercig a fejlesztői mód megnyitásához';

  @override
  String get developerNotificationDiagnostics => 'Értesítési diagnosztika';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Ellenőrizze az Android kézbesítési állapotát, építse újra a meglévő emlékeztetőtervet, és küldjön biztonságos tesztértesítéseket a Sked szokásos értesítési szolgáltatásán keresztül.';

  @override
  String get developerNotificationUnsupported =>
      'Az értesítési diagnosztika csak Androidon érhető el.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Az értesítési diagnosztika a naptárkoordinátor elindulása után érhető el.';

  @override
  String get developerNotificationRefresh => 'Diagnosztika frissítése';

  @override
  String get developerNotificationSystemStatus =>
      'Rendszerszintű értesítési engedély';

  @override
  String get developerNotificationPermissionAllowed => 'Engedélyezve';

  @override
  String get developerNotificationPermissionBlocked => 'Letiltva';

  @override
  String get developerNotificationExactAlarm => 'Pontos riasztások';

  @override
  String get developerNotificationExactAlarmAllowed => 'Engedélyezve';

  @override
  String get developerNotificationExactAlarmBlocked => 'Nincs engedélyezve';

  @override
  String get developerNotificationPlan => 'Naptárértesítési terv';

  @override
  String get developerNotificationCoverage => 'Lefedettség';

  @override
  String get developerNotificationCoverageReady =>
      'Minden ismert, véges ismétlésű emlékeztető közvetlenül ütemezve';

  @override
  String get developerNotificationCoverageRenewable =>
      'Az ismétlődő emlékeztetők hosszú távú lefedettségét lehetőség szerinti megújítás biztosítja';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'A közvetlen riasztási kapacitás megtelt; a későbbi emlékeztetők lehetőség szerint újra lesznek ütemezve';

  @override
  String get developerNotificationCoverageBlocked =>
      'A pontos kézbesítés feltételei nem teljesülnek';

  @override
  String get developerNotificationCoverageFailed =>
      'Az emlékeztetők legutóbbi szinkronizálása sikertelen';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled közvetlen riasztás / $capacity kapacitás';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled ütemezve, $planned tervezve';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Legutóbbi hiba: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Értesítési terv újraépítése';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Az értesítési terv újraépült.';

  @override
  String get developerNotificationTestChannel => 'Tesztcsatorna';

  @override
  String get developerNotificationTestCourse => 'Tantárgyi emlékeztetők';

  @override
  String get developerNotificationTestSchedule => 'Naptáremlékeztetők';

  @override
  String get developerNotificationImmediateTest => 'Azonnali teszt küldése';

  @override
  String get developerNotificationThirtySecondTest =>
      'Háttérteszt ütemezése 30 másodperc múlva';

  @override
  String get developerNotificationImmediateQueued =>
      'Az azonnali tesztértesítés elküldve.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'A háttérteszt 30 másodperc múlvára ütemezve.';

  @override
  String get developerNotificationAppSwitch =>
      'Alkalmazás emlékeztetőkapcsolója';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Normál emlékeztetők engedélyezve';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Normál emlékeztetők letiltva; a fejlesztői tesztek továbbra is futtathatók';

  @override
  String get developerNotificationTimeZone => 'Helyi időzóna';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Még nincs létrehozva. Egy fejlesztői teszt létrehozza.';

  @override
  String get developerNotificationChannelEnabledState => 'Engedélyezve';

  @override
  String get developerNotificationChannelBlockedState => 'Letiltva';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Fontosság: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'A fontosság nem érhető el';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending függőben / $active aktív';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Legutóbbi natív megjelenítés: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Még nincs rögzített újraszámítás.';

  @override
  String get developerNotificationNextReminder =>
      'Következő valódi emlékeztető';

  @override
  String get developerNotificationNoPendingReminder =>
      'Nincs jövőbeli emlékeztető a jelenlegi tervben';

  @override
  String get developerNotificationNextMaintenance => 'Következő karbantartás';

  @override
  String get developerNotificationNextRenewal =>
      'Következő lehetőség szerinti megújítás';

  @override
  String get developerNotificationNoMaintenance => 'Nincs ütemezve';

  @override
  String get developerNotificationTruncation => 'Terv csonkolása';

  @override
  String developerNotificationTruncationCount(int count) {
    return '$count kihagyva a tervkorlát miatt';
  }

  @override
  String get developerNotificationLastReconciliation =>
      'Legutóbbi újraszámítás';

  @override
  String get developerNotificationLastSynchronization =>
      'Emlékeztetők legutóbbi szinkronizálása';

  @override
  String get developerNotificationLateRecovery =>
      'Késő emlékeztetők helyreállítása';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count emlékeztető az eredeti időpontja után lett helyreállítva és kézbesítve';
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
  String get developerNotificationReconcileOriginForeground => 'Előtér';

  @override
  String get developerNotificationReconcileOriginBackground => 'Háttér';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Teljes újraszámítás';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Karbantartás';

  @override
  String get developerNotificationReconcileModeRecovery => 'Helyreállítás';

  @override
  String get developerNotificationRunRecovery => 'Emlékeztetők helyreállítása';

  @override
  String get developerNotificationRecoveryComplete =>
      'Emlékeztetők helyreállítása befejezve';

  @override
  String get developerNotificationReconcileResultSuccess => 'Sikeres';

  @override
  String get developerNotificationReconcileResultSkipped => 'Kihagyva';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'A pontos kézbesítés összes feltételének teljesüléséig letiltva';

  @override
  String get developerNotificationReconcileResultFailed => 'Sikertelen';

  @override
  String get developerNotificationBackgroundLimits =>
      'Gyártói háttérkorlátozások';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'A gyártó háttérkorlátozásai befolyásolhatják a kézbesítést.';

  @override
  String get developerNotificationAutostart => 'Gyártói háttérindítás';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Gyártó: $vendor; elérhető egy gyártói beállítási oldal. Az Android nem tudja lekérdezni az engedély állapotát.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Gyártó: $vendor; tartalék megoldásként az alkalmazásadatok nyílnak meg. Az Android nem tudja lekérdezni az engedély állapotát.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Nem érhető el gyártói háttérbeállítási oldal.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Legutóbb megnyitott cél: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'gyártói beállítások';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'alkalmazásadatok';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'nincs';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Újraindítás utáni helyreállítás korlátai';

  @override
  String get developerNotificationRebootBoundary =>
      'A helyreállítás az első feloldás után indul; a kényszerítetten leállított alkalmazás nem tud magától elindulni.';

  @override
  String get developerNotificationTestChecking =>
      'Az értesítési állapot ellenőrzése közben a tesztek nem érhetők el.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'A tesztek nem érhetők el, mert a rendszerértesítések le vannak tiltva.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'A tesztek nem érhetők el, mert a kiválasztott értesítési csatorna le van tiltva.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'A Windows értesítési beállításai kezelik';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Windows alatt nem alkalmazható';

  @override
  String get developerNotificationWindowsIdentity => 'Windows-csomagazonosság';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Az MSIX-csomagazonosság elérhető; az aktív értesítési kártyák törölhetők';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Az aktív értesítési kártyák megbízható törléséhez telepítse az MSIX-verziót';

  @override
  String get collapseWorkspaceNavigation =>
      'Munkaterület-navigáció összecsukása';

  @override
  String get expandWorkspaceNavigation => 'Munkaterület-navigáció kibontása';

  @override
  String get schoolWebImportExitBrowser => 'Beépített böngésző bezárása';

  @override
  String get schoolWebImportEditAddress => 'Cím szerkesztése';

  @override
  String get schoolWebImportAddressLabel => 'Webcím';

  @override
  String get schoolWebImportOpenAddress => 'Megnyitás';

  @override
  String get schoolWebImportAddressInvalid =>
      'Adjon meg egy gazdagéppel rendelkező HTTP- vagy HTTPS-címet.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Ez a weboldal új ablakot kért, amely nem nyitható meg ezen az eszközön.';

  @override
  String get schoolWebImportSecureConnection => 'Biztonságos kapcsolat';

  @override
  String get schoolWebImportInsecureConnection => 'Nem biztonságos kapcsolat';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Megnyitja az iskolai bejelentkezést?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Az iskolai bejelentkezés űrlapokon vagy szerverátirányításokon keresztül hitelesítő adatokat küldhet az iskolának és bejelentkezési szolgáltatóinak. Az Android nem tud minden ilyen átvitelt külön célmegerősítéshez megállítani. Csak akkor folytassa, ha megbízik bennük ebben az importálási munkamenetben:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Megnyitja a nem biztonságos iskolai bejelentkezést?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Ez az iskolai bejelentkezés HTTP-t használ. Bárki, aki megfigyelheti vagy módosíthatja ezt a kapcsolatot, elolvashatja vagy megváltoztathatja a hitelesítő adatait és az oldal tartalmát. Csak akkor folytassa, ha elfogadja ezt a kockázatot ennél a helynél:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Emlékeztetők és értesítések';

  @override
  String get notificationCoverage => 'Emlékeztetők lefedettsége';

  @override
  String get notificationCoverageRenewable =>
      'A záró dátum nélküli ismétlődő események hosszú távú lefedettségét háttérbeli megújítás tartja fenn.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Az Android közvetlenül legfeljebb $capacity emlékeztetőt tárolhat; a későbbiek megújítását a rendszer előre megkísérli.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Emlékeztetők és értesítések engedélyezése';

  @override
  String get notificationSettingsEnabledHint =>
      'Csak emlékeztetővel rendelkező elemekhez ütemez értesítést. Az alapértéket használó tantárgyakhoz állítsa be alább az alapértelmezett emlékeztetőt.';

  @override
  String get notificationPrecisionLimitations =>
      'Az emlékeztetők a rendszerengedélyektől és a háttérben futástól függenek. A kikapcsolás, az idő módosítása vagy a rendszer korlátozásai késést okozhatnak.';

  @override
  String get notificationSettingsEnabledSummary => 'Engedélyezve';

  @override
  String get notificationSettingsDisabledSummary => 'Letiltva';

  @override
  String get notificationDefaultsSection => 'Alapértelmezett emlékeztetők';

  @override
  String get notificationCourseDefaultReminder =>
      'Tantárgyak alapértelmezett emlékeztetője';

  @override
  String get notificationGeneralDefaultReminder =>
      'Naptár alapértelmezett emlékeztetője';

  @override
  String get notificationReminderOff => 'Nincs emlékeztető';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes perccel előtte';
  }

  @override
  String get notificationPermission => 'Értesítési engedély';

  @override
  String get notificationPermissionGranted => 'A rendszer engedélyezte';

  @override
  String get notificationPermissionDenied => 'A rendszer letiltotta';

  @override
  String get notificationPermissionChecking => 'Engedély ellenőrzése…';

  @override
  String get notificationPermissionRequest => 'Engedély kérése';

  @override
  String get notificationPermissionOpenSettings =>
      'Rendszerbeállítások megnyitása';

  @override
  String get notificationPermissionRequestFailed =>
      'Nem sikerült lekérdezni az értesítési engedélyt. Próbálja újra.';

  @override
  String get notificationExactAlarm => 'Pontos riasztások engedélye';

  @override
  String get notificationExactAlarmAllowed => 'A rendszer engedélyezte';

  @override
  String get notificationExactAlarmRequired =>
      'A pontos emlékeztetőkhöz szükséges';

  @override
  String get notificationExactAlarmRequest => 'Pontos riasztások engedélyezése';

  @override
  String get notificationBatteryOptimization => 'Akkumulátoroptimalizálás';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Kivétel az Android akkumulátoroptimalizálása alól';

  @override
  String get notificationBatteryOptimizationRequired =>
      'A pontos emlékeztetőkhöz kivétel szükséges az Android akkumulátoroptimalizálása alól';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Akkumulátoroptimalizálási beállítások megnyitása';

  @override
  String get notificationAutostart => 'Gyártói háttérindítás';

  @override
  String get notificationAutostartVendorHint =>
      'Engedélyezze az automatikus indítást vagy a háttérben futást, hogy újraindítás után helyreállhassanak az emlékeztetők.';

  @override
  String get notificationAutostartFallbackHint =>
      'Nyissa meg a Sked alkalmazásadatait, és engedélyezze a háttérben futást. Az Android ezt a gyártói beállítást nem tudja ellenőrizni.';

  @override
  String get notificationAutostartUnavailable =>
      'Nem található gyártói beállítási oldal. Ellenőrizze kézzel a Sked alkalmazásadatait.';

  @override
  String get notificationAutostartRequest =>
      'Gyártói háttérbeállítások megnyitása';

  @override
  String get notificationAutostartOpenFailed =>
      'Nem sikerült megnyitni a gyártói háttérbeállításokat. Ellenőrizze kézzel a Sked alkalmazásadatait.';

  @override
  String get notificationLockScreenTitles =>
      'Címek megjelenítése a zárolási képernyőn';

  @override
  String get notificationLockScreenTitlesHint =>
      'Kikapcsolva az értesítések részletei rejtve maradnak a zárolási képernyőn.';

  @override
  String get notificationWidgets => 'Kezdőképernyős modulok';

  @override
  String get notificationWidgetsDesc =>
      'Frissítse a Sked moduljait, és tudja meg, hogyan adhat hozzá egyet a kezdőképernyőről.';

  @override
  String get notificationWidgetsDialogTitle => 'Sked-modul hozzáadása';

  @override
  String get notificationWidgetsDialogMessage =>
      'A készülék kezdőképernyőjén nyomjon meg hosszan egy üres területet, válassza a Modulok lehetőséget, majd adjon hozzá egy Sked-modult. A modul a következő tanórákat vagy eseményeket mutatja.';

  @override
  String get notificationWidgetsRefresh => 'Modulok frissítése';

  @override
  String get notificationWidgetsRefreshed => 'Modulok frissítve';

  @override
  String get notificationPlatformUnsupported =>
      'Ez a platform nem támogat natív értesítéseket.';

  @override
  String get workspaceFeatures => 'Funkciók kezelése';

  @override
  String get workspaceBoth => 'Órarend és naptár';

  @override
  String get workspaceOnlyStudent => 'Csak órarend';

  @override
  String get workspaceOnlyGeneral => 'Csak naptár';

  @override
  String get workspaceDisableTitle => 'Kikapcsolja ezt a munkaterületet?';

  @override
  String get workspaceDisableMessage =>
      'Az adatok és beállítások megmaradnak. A funkciók és emlékeztetők leállnak, amíg itt újra be nem kapcsolja.';

  @override
  String get workspaceEnableHint =>
      'Válassza ki a használt funkciókat. Legalább egynek bekapcsolva kell maradnia.';

  @override
  String get workspaceLastRequired =>
      'Legalább egy munkaterületnek bekapcsolva kell maradnia.';

  @override
  String get workspaceReminderCleanupFailed =>
      'A munkaterület ki van kapcsolva, de az emlékeztetőket nem sikerült eltávolítani. Próbálja újra az értesítések helyreállítását.';

  @override
  String get settingsSearch => 'Beállítások keresése';

  @override
  String get settingsNoResults => 'Nincs megfelelő beállítás';

  @override
  String get settingsDataPrivacy => 'Adatok és adatvédelem';

  @override
  String get workspacePreferences => 'Megjelenítés és kezelés';

  @override
  String get workspaceManage => 'Kezelés';

  @override
  String get selectedDayAgenda => 'Kiválasztott nap';

  @override
  String get notificationTroubleshooting => 'Engedélyek és hibaelhárítás';

  @override
  String get settingsConnection => 'Kapcsolat';

  @override
  String get settingsAdvanced => 'Speciális';

  @override
  String get unsavedChangesMessage =>
      'Nem mentett módosításai vannak. Elveti őket és kilép?';

  @override
  String get backupWorkspaceSelection =>
      'A teljes biztonsági másolat az adatokat és a bekapcsolt munkaterületek kiválasztását is tartalmazza.';

  @override
  String get assistantLayoutPreview => 'AI · Elrendezési előnézet';

  @override
  String get assistantSelectionContext =>
      'Az aktuális kijelölést használja kontextusként';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Üzenetpiszkozat';

  @override
  String get assistantPreviewNoSend =>
      'Csak elrendezési előnézet. Semmi sem lesz elküldve vagy módosítva.';

  @override
  String get resizePanel => 'Panel átméretezése';

  @override
  String get minimizeWindow => 'Kis méret';

  @override
  String get maximizeWindow => 'Teljes méret';

  @override
  String get restoreWindow => 'Ablak visszaállítása';

  @override
  String get closeWindow => 'Ablak bezárása';

  @override
  String get courseSystemReminder => 'Rendszeremlékeztető';

  @override
  String courseReminderInherit(String reminder) {
    return 'Alapértelmezés használata ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'A rendszeremlékeztetők ki vannak kapcsolva az értesítési beállításokban. A tantárgy beállítása ettől még menthető.';

  @override
  String get courseReminderDefaultOff =>
      'Nincs alapértelmezett tantárgyi emlékeztető. Válasszon itt egyéni emlékeztetőt, vagy állítson be alapértéket az értesítési beállításokban.';

  @override
  String get courseReminderDeliveryHint =>
      'Ez a beállítás a tantárggyal együtt mentődik. A kézbesítés a rendszer értesítési engedélyeitől és háttérkorlátozásaitól függ.';

  @override
  String get courseReminderPermissionUnknown =>
      'A rendszer értesítési állapota még nincs ellenőrizve. Mielőtt az emlékeztetőkre hagyatkozna, ellenőrizze az értesítési beállításokat.';

  @override
  String get courseReminderMinutesLabel => 'Percekkel az óra előtt';

  @override
  String get exportAction => 'Exportálás';

  @override
  String get datePickerSelectWeek => 'Hét kiválasztása';

  @override
  String get datePickerSelectMonth => 'Hónap kiválasztása';

  @override
  String get generalDateLabelFormatDescription =>
      'Az asztali és kisebb képernyők dátumnavigációjára is vonatkozik.';

  @override
  String get dateRangeTitle => 'Dátumtartomány kiválasztása';

  @override
  String get dateRangeCustom => 'Egyéni';

  @override
  String get dateRangeChooseStart => 'Válassza ki a kezdőnapot';

  @override
  String get dateRangeChooseEnd => 'Válassza ki a zárónapot';

  @override
  String get dateRangeLimit =>
      'Válasszon 1–14 napot, a kezdő- és zárónapot is beleértve.';

  @override
  String dateRangeCustomDays(int days) {
    return 'Egyéni · $days nap';
  }

  @override
  String get timePickerWheelMode => 'Kiválasztás görgetőkerekekkel';

  @override
  String get courseReminderUseDefault => 'Alapértelmezés használata';

  @override
  String get courseReminderInvalidMinutes =>
      'Adja meg a perceket nullánál nem kisebb egész számként.';

  @override
  String get generalCustomColumnWidth => 'Egyéni nézet oszlopszélessége';

  @override
  String get generalCustomColumnWidthAuto => 'Automatikus';

  @override
  String get generalCustomColumnWidthManual => 'Minimális szélesség';

  @override
  String get generalCustomColumnWidthMinimum => 'Minimális szélesség naponta';

  @override
  String get generalCustomColumnWidthHint =>
      'Minden dátum ugyanazt a minimális szélességet használja. Az oszlopok kitöltik a rendelkezésre álló helyet, vagy oldalra görgethetők. Csak az egyéni nézetre hat.';

  @override
  String get settingsAppearanceLanguage => 'Megjelenés és nyelv';

  @override
  String get settingsAppearanceDetails => 'Színek és körvonalak';

  @override
  String get monthNoEvents => 'Ezen a napon nincs esemény';

  @override
  String get settingsOverview => 'Áttekintés';

  @override
  String get settingsThemeTarget => 'Téma célja';

  @override
  String get settingsColorMode => 'Színmód';

  @override
  String get settingsNotificationPreferences => 'Emlékeztetőbeállítások';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Alapértelmezett emlékeztetők, engedélyek és megbízhatóság';

  @override
  String get settingsFeaturesSummary => 'Munkaterületek és navigáció';

  @override
  String get settingsPrivacySummary =>
      'Adatvédelmi szabályzat és helyi adatok törlése';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tanóra',
      one: '1 tanóra',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Tanóra';

  @override
  String get periodTimesDurationColumn => 'Időtartam';

  @override
  String get periodTimesGapColumn => 'Szünet';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes perc';
  }

  @override
  String get periodTimesSavePending => 'Mentésre vár…';

  @override
  String get periodTimesSaveFailed => 'Nincs mentve · A mentés sikertelen';

  @override
  String get periodTimesInvalidStatus =>
      'Nincs mentve · Javítsa a jelölt időpontokat';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'A Sked nem tudta megerősíteni, hogy a legutóbbi mentés vissza lett-e vonva. Az írás szünetel, a helyreállítási másolatok megmaradtak. Ellenőrizze a tárhelyet, és próbálja újra betölteni az adatokat.';

  @override
  String get settingsPanelDisplayMode => 'Panelek megjelenítése';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Közös az órarendekben és a naptárakban';

  @override
  String get settingsPanelDisplayOverlay => 'Átfedés';

  @override
  String get settingsPanelDisplaySideBySide => 'Egymás mellett';

  @override
  String get settingsPanelDisplayAutomatic => 'Automatikus';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'A jobb oldalt fedi le a naptár szélességének módosítása nélkül.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Az egymás melletti nézetet részesíti előnyben; csak túl keskeny naptár esetén fed rá.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Egymás mellett jelenít meg, ha a naptár olvasható marad, különben átfedéssel.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Ha az eszköztáron kikapcsolja a Beállítások vagy Munkaterület elemet, az a Továbbiak menübe kerül. A Továbbiak nem rejthető el, amíg alapvető műveleteket tartalmaz. A munkaterületváltás csak rejtett alsó navigáció és több engedélyezett munkaterület esetén jelenik meg.';

  @override
  String get reminderEnded => 'Befejeződött';

  @override
  String get reminderAutoCloseHint =>
      '10 másodperc után bezárul. A panel használatával nyitva tarthatja.';

  @override
  String get showReminderIndependently => 'Megnyitás külön';

  @override
  String get categoryManagerTitle => 'Kategóriák kezelése';

  @override
  String get categoryHidden => 'Rejtett';

  @override
  String get categoryShowOnCalendar => 'Megjelenítés a naptárban';

  @override
  String get categoryHideOnCalendar => 'Elrejtés a naptárból';

  @override
  String get categoryEditColor => 'Kategória színének módosítása';

  @override
  String get categoryThemePalette => 'Téma színpalettája';

  @override
  String get categoryCustomColor => 'Egyéni';

  @override
  String get colorHexInvalid => 'Adjon meg hatjegyű hexadecimális színkódot.';

  @override
  String categoryColorSlot(int number) {
    return 'Téma színe: $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Az áruházi frissítések később érkezhetnek. Az elérhetőségről az áruház oldala tájékoztat.';

  @override
  String get storePrereleaseNotice =>
      'Az előzetes kiadásokról szóló értesítések fogadása nem jelent belépést az áruház tesztprogramjába.';

  @override
  String get updateFoundTitle => 'Új verzió érhető el';

  @override
  String get updateNoNotes => 'Nincsenek kiadási megjegyzések.';

  @override
  String get updateLater => 'Később';

  @override
  String get updateRetry => 'Újrapróbálás';

  @override
  String get updatePrerelease => 'Előzetes kiadás';

  @override
  String get updateNetworkFailure =>
      'Nem sikerült frissítéseket keresni. Ellenőrizze a kapcsolatot, és próbálja újra.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Nem található újabb verzió (jelenlegi: $version)';
  }

  @override
  String get backupRestoreInProgressTitle =>
      'Biztonsági mentés visszaállítása…';

  @override
  String get backupRestoreInProgressMessage =>
      'Az adatok és beállítások a visszaállítás befejezése után módosíthatók. Továbbra is megtekintheted őket.';
}
