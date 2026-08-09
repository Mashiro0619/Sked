// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get appTitle => 'Osztálytársak';

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
  String get createTimetable => 'Új menetrend';

  @override
  String get jumpToWeek => 'Ugrás a hétre';

  @override
  String get timetable => 'Naptár';

  @override
  String get timetableName => 'Időrend neve';

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
  String get settingsSectionTimetable => 'Timetable';

  @override
  String get settingsSectionGeneralSchedule => 'General schedule';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionApp => 'App';

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
      'Popup elbocsátás, hiányosságok, szürke pályák és rácsvonalak';

  @override
  String get showTimetableGridLines => 'A menetrend rácsvonalak megjelenítése';

  @override
  String get showTimetableGridLinesHint =>
      'Ellenőrizze, hogy a vízszintes és függőleges rácsvonalak láthatók-e a menetrendben.';

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
  String get outlineWidthUnit => 'pixel';

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
      'A teljes visszaállítás lecseréli az aktuális alkalmazásadatokat. Az egyéni elemző API-kulcsai biztonságos tárhelyen vannak, és nem kerülnek a mentési fájlokba.';

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
      'Teljes alkalmazásmentés visszaállítva. Az elemző API-kulcsait újra meg kell adni.';

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
  String get googlePlay => 'Google Játék';

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
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'GitHub tároló';

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
      'On native platforms, Sked stores timetable data, general schedules, related settings, and editable school-site configuration in the operating system\'s application-support directory; browser builds use browser storage. Files written by earlier versions to the user Documents directory remain in place, but they are not read or migrated automatically. To retain that data, export a full app backup from the old version before upgrading, then restore it afterward. Custom timetable parser settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. Full app backups do not include the custom API key. The app does not automatically upload this local data to a developer-controlled server.';

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
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importáljon jegyzeteket';

  @override
  String get schoolWebImportOpenPageHint =>
      'Jelentkezzen be az iskola webhelyére az alkalmazásban, majd navigáljon a menetrend oldalára manuálisan.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

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
  String get schoolWebImportGoBack => 'Előző oldal';

  @override
  String get schoolWebImportLoadingPage => 'Oldal betöltése…';

  @override
  String get schoolWebImportParsing => 'Az aktuális oldal elemzése...';

  @override
  String get schoolWebImportLoadFailed =>
      'Az oldal betöltése nem sikerült. Kérjük, frissítse meg vagy próbálja meg újra később.';

  @override
  String get schoolWebImportLoadTimedOut =>
      'Az oldal betöltése lejárt. Kérjük, frissítse meg és próbálja meg újra.';

  @override
  String get schoolWebImportUnknownOrigin => 'Ismeretlen webhely';

  @override
  String get schoolWebImportCrossOriginTitle =>
      'Folytatja egy másik webhelyen?';

  @override
  String schoolWebImportCrossOriginMessage(Object origin) {
    return 'Az iskolai bejelentkezéshez szükség lehet egy másik webhely megnyitására. Csak akkor folytassa, ha az aktuális importálási munkamenetben megbízik ebben a célban:\n\n$origin';
  }

  @override
  String get schoolWebImportEmptyPage =>
      'Az aktuális oldal tartalma üres, és még nem lehet importálni.';

  @override
  String get schoolWebImportSuccess => 'Web menetrend importált';

  @override
  String get schoolImportParserSettingsTitle =>
      'A menetrend elemző beállításai';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure your own OpenAI-compatible endpoint. HTTP and HTTPS base URLs are supported.';

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
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

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
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

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
      'Naptárak, események, emlékeztetők és JSON / ICS adatok kezelése.';

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
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'Ma';

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
      'Toggles for the general schedule view';

  @override
  String get closePopupOnOutsideTap => 'Close popup on tap outside';

  @override
  String get showGridLines => 'Show grid lines';

  @override
  String get generalScheduleImportExport => 'Schedule import & export';

  @override
  String get generalScheduleImportExportDesc =>
      'Import or share general schedules';

  @override
  String get importGeneralSchedules => 'Import schedules';

  @override
  String get importGeneralSchedulesDesc => 'Read schedules from a JSON file';

  @override
  String get shareGeneralSchedules => 'Share schedules';

  @override
  String get shareGeneralSchedulesDesc => 'Share schedules as a JSON file';

  @override
  String get saveGeneralSchedules => 'Save schedules';

  @override
  String get saveGeneralSchedulesDesc => 'Save schedules as a JSON file';

  @override
  String get selectSchedulesToExport => 'Select schedules to export';

  @override
  String get selectSchedulesToImport => 'Select schedules to import';

  @override
  String generalScheduleEventCount(int count) {
    return 'Events: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Imported $count schedules';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Replace current schedule with the imported one?';

  @override
  String get addAsNewSchedule => 'Add as new';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Please select at least one schedule.';

  @override
  String get noExportableScheduleMessage => 'No schedule available to export.';

  @override
  String get noSchedulesInImportMessage => 'Import file contains no schedules.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Choose exactly one schedule to replace the current one.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'No current schedule to replace.';

  @override
  String get calendars => 'Calendars';

  @override
  String get calendar => 'Calendar';

  @override
  String get viewWeek => 'Hét';

  @override
  String get viewDay => 'Nap';

  @override
  String get viewList => 'List';

  @override
  String get viewMonth => 'Month';

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
  String moreEvents(int count) {
    return '+$count more';
  }

  @override
  String get noMatchingEvents => 'No matching events';

  @override
  String get noUpcomingEvents => 'No upcoming events';

  @override
  String get addCalendar => 'Add calendar';

  @override
  String get newCalendar => 'New calendar';

  @override
  String get hideCalendar => 'Hide calendar';

  @override
  String get showCalendar => 'Show calendar';

  @override
  String get rename => 'Rename';

  @override
  String get renameCalendar => 'Rename calendar';

  @override
  String get name => 'Name';

  @override
  String get deleteCalendar => 'Delete calendar';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteThisOccurrence => 'Delete this';

  @override
  String get deleteFutureOccurrences => 'Delete future';

  @override
  String get deleteAllOccurrences => 'Delete all';

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
  String get importJsonFile => 'Import JSON file';

  @override
  String get pasteJson => 'Paste JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Import calendars from copied JSON';

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
  String get copyJsonDesc => 'Copy selected calendars as JSON text';

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
    return 'Found $count events. Import as a new calendar or replace the active calendar?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Imported $count schedules with $warningCount warnings';
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
  String get generalScheduleDisplaySection => 'Schedule display';

  @override
  String get generalTimeGridSection => 'Time grid';

  @override
  String get generalPopupSection => 'Popup behavior';

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
}
