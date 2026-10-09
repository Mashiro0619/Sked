// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Viikko $week';
  }

  @override
  String get addCourse => 'Lisää kurssi';

  @override
  String get settings => 'Asetukset';

  @override
  String get multiTimetableSwitch => 'Vaihda lukujärjestystä';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Nykyinen lukujärjestys · $weeks viikkoa';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Vaihda napauttamalla · $weeks viikkoa';
  }

  @override
  String get editTimetable => 'Muokkaa lukujärjestystä';

  @override
  String get schoolImportResultEditorTitle => 'Muokkaa jäsennettyä tulosta';

  @override
  String get schoolImportParsePageTitle => 'Jäsennä lukujärjestys';

  @override
  String get schoolImportParsePageParsing => 'Jäsennetään…';

  @override
  String get schoolImportParsePageFailed => 'Jäsennys epäonnistui';

  @override
  String get schoolImportParsePageComplete => 'Jäsennys valmis';

  @override
  String get schoolImportParsePageContinue => 'Jatka';

  @override
  String get schoolImportParsePageRawContent => 'Raakavastaus';

  @override
  String get schoolImportParsePageExpandRaw => 'Laajenna raakavastaus';

  @override
  String get schoolImportParsePageCollapseRaw => 'Supista raakavastaus';

  @override
  String get schoolImportExpandWarnings => 'Laajenna tuonnin varoitukset';

  @override
  String get schoolImportCollapseWarnings => 'Supista tuonnin varoitukset';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Osa kursseista jatkuu viikolle $week asti.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle =>
      'Korvataanko nykyinen lukujärjestys?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Tuotu lukujärjestys korvaa nykyisen lukujärjestyksen.';

  @override
  String get createTimetable => 'Uusi lukujärjestys';

  @override
  String get jumpToWeek => 'Hyppää viikkoon';

  @override
  String get timetable => 'Lukujärjestys';

  @override
  String get themeWorkspaceSchedule => 'Aikataulu';

  @override
  String get timetableName => 'Lukujärjestyksen nimi';

  @override
  String get timetableNameRequired => 'Anna lukujärjestykselle nimi';

  @override
  String get totalWeeks => 'Viikot yhteensä';

  @override
  String get delete => 'Poista';

  @override
  String get cancel => 'Peruuta';

  @override
  String get save => 'Tallenna';

  @override
  String get deleteTimetableTitle => 'Poista lukujärjestys';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Poista \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Ei aikataulua vielä';

  @override
  String get noTimetableMessage =>
      'Luo aikataulu tai tuo yksi JSON-tiedostosta.';

  @override
  String get importTimetable => 'Tuo aikataulu';

  @override
  String get courseName => 'Kurssin nimi';

  @override
  String get location => 'Sijainti';

  @override
  String get dayOfWeek => 'Päivä';

  @override
  String get semesterWeeks => 'Viikot';

  @override
  String get startTime => 'Aloitusaika';

  @override
  String get endTime => 'Loppuaika';

  @override
  String get linkedPeriods => 'Liitetyt jaksot';

  @override
  String get linkedPeriodsUnmatched =>
      'Nykyiselle ajanjaksolle ei ole yhteensopivia jaksoja. Valitse manuaalisesti.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Ajankohta $start-$end';
  }

  @override
  String get teacherName => 'Opettaja';

  @override
  String get credits => 'Krediitit';

  @override
  String get remarks => 'Huomautukset';

  @override
  String get customFields => 'Mukautetut kentät';

  @override
  String get customFieldsHint => 'Yksi rivistä kohti, muoto: avain:arvo';

  @override
  String get customFieldsInvalidJson =>
      'Anna kelvollinen JSON-objekti tai tyhjennä kenttä.';

  @override
  String get more => 'Lisää';

  @override
  String get selectDayOfWeek => 'Valitse päivä';

  @override
  String get selectSemesterWeeks => 'Valitse viikot';

  @override
  String get selectAll => 'Valitse kaikki';

  @override
  String get clear => 'Tyhjennä';

  @override
  String get confirm => 'Vahvista';

  @override
  String get selectLinkedPeriods => 'Valitse linkitetyt ajanjaksot';

  @override
  String get addCourseTitle => 'Lisää kurssi';

  @override
  String get editCourseTitle => 'Muokkaa kurssia';

  @override
  String get editCourseTooltip => 'Muokkaa kurssia';

  @override
  String get place => 'Sijainti';

  @override
  String get time => 'Aika';

  @override
  String get notFilled => 'Ei täytetty';

  @override
  String get none => 'Ei mitään';

  @override
  String get conflictCourses => 'ristiriitaisia kursseja';

  @override
  String get locationNotFilled => 'Sijainti ei ole täytetty';

  @override
  String get setAsDisplayed => 'Aseta näytetyksi';

  @override
  String get editThisCourse => 'Muokkaa tätä kurssia';

  @override
  String get settingsTitle => 'Asetukset';

  @override
  String get settingsSectionTimetable => 'Lukujärjestys';

  @override
  String get settingsSectionGeneralSchedule => 'Yleinen aikataulu';

  @override
  String get settingsSectionAppearance => 'Ulkoasu';

  @override
  String get settingsSectionApp => 'Sovellus';

  @override
  String get settingsSectionWorkspace => 'Työtila';

  @override
  String get settingsSectionAppearanceLanguage => 'Ulkoasu ja kieli';

  @override
  String get settingsSectionDataSecurity => 'Tiedot ja tietoturva';

  @override
  String get settingsSectionAbout => 'Tietoja Skedistä';

  @override
  String get noTimetableSettings =>
      'Aikataulua ei ole tällä hetkellä saatavilla asetuksille.';

  @override
  String get semesterStartDate => 'Lukukauden alkamispäivä';

  @override
  String get periodTimeSets => 'Ajankohta asetettu';

  @override
  String get noPeriodTimeAvailable => 'Ei käytettävissä olevaa ajanjaksoa';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count jaksot';
  }

  @override
  String get coursePopupDismissSetting =>
      'Salli ulkopuolinen napautus sulkea kurssin ponnahdusikkuna';

  @override
  String get coursePopupDismissSettingHint =>
      'Tämän sammuttaminen poistaa myös pyyhkäisy alaspäin erottamisen käytöstä.';

  @override
  String get preserveTimetableGaps => 'Säilytä aikataulun aukot';

  @override
  String get preserveTimetableGapsHint =>
      'Kun pois, lounas ja tauko aukot romahtavat, joten myöhemmät luokat siirtyvät ylöspäin.';

  @override
  String get showPastEndedCourses => 'Näytä aiemmin päättyneet kurssit';

  @override
  String get showPastEndedCoursesHint =>
      'Näytä kursseja, jotka ovat jo päättyneet todellisella nykyisellä viikolla vaaleanharmaalla tyylillä.';

  @override
  String get showFutureCourses => 'Näytä tulevia kursseja';

  @override
  String get showFutureCoursesHint =>
      'Näytä kursseja, jotka eivät ole aktiivisia tällä viikolla, mutta näkyvät myöhemmin harmalla tyylillä.';

  @override
  String get timetableDisplaySettings => 'Aikataulun näyttö ja vuorovaikutus';

  @override
  String get timetableDisplaySettingsDesc =>
      'Kurssien näyttö, asettelu, viikkoeleet ja pikalisäys';

  @override
  String get showTimetableGridLines => 'Näytä aikataulun verkko-rivit';

  @override
  String get showTimetableGridLinesHint =>
      'Hallitse, näkyvätkö aikataulussa vaakasuora- ja pystysuora-verkkovinjat.';

  @override
  String get timetableHorizontalLayoutSection => 'Vaaka-asettelu ja eleet';

  @override
  String get fitDaySelectorToWidth => 'Sovita päivävalitsin näytölle';

  @override
  String get fitDaySelectorToWidthHint =>
      'Näyttää kaikki seitsemän päivää näytöllä, jos mahdollista. Poista käytöstä, jos haluat kiinteän leveyden ja vierityksen.';

  @override
  String get fitWeekColumnsToWidth => 'Sovita viikon sarakkeet näytölle';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Näyttää kaikki seitsemän lukujärjestyksen saraketta näytöllä, jos mahdollista. Poista käytöstä, jos haluat kiinteän leveyden ja vierityksen.';

  @override
  String get enableWeekSwipeNavigation => 'Vaihda viikkoa pyyhkäisemällä';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Siirry toiseen viikkoon pyyhkäisemällä vasemmalle tai oikealle. Kiinteää leveyttä käytettäessä vieritä ensin reunaan ja vedä sen yli.';

  @override
  String get liveCourseOutlineColor => 'Kurssin luonteen väri';

  @override
  String get liveCourseOutlineColorHint =>
      'Valitse, kohdistuvatko piirrokset nykyiseen/seuraavaan kurssiin vai kaikkiin nykyisellä sivulla näkyviin kursseihin.';

  @override
  String get liveCourseOutlineSettings => 'Kurssin luonnokset';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Määritä, onko ääriviiva käytössä, mihin se kohdistuu, noudattaanko se teemaväriä ja tehokasta ääriviivaria.';

  @override
  String get liveCourseOutlineEnabled => 'Ota käyttöön piirrokset';

  @override
  String get liveCourseOutlineFollowTheme => 'Seuraa teeman väriä';

  @override
  String get liveCourseOutlineTarget => 'Suunnitelmakohde';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Nykyinen/seuraava kurssi';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Kaikki näytetyt kurssit';

  @override
  String get liveCourseOutlineEffectiveColor => 'Tehokas väri';

  @override
  String get liveCourseOutlineCustomColor => 'Mukautettu ääriviiva väri';

  @override
  String get liveCourseOutlineWidth => 'Viivan leveys';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Kieli';

  @override
  String get languagePageDescription =>
      'Valitse yksi kielistä, jotka ovat todella saatavilla sovelluksessa.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'englanninkielinen';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'API-vastaus';

  @override
  String get theme => 'Teema';

  @override
  String get themeFollowSystem => 'Seuraa järjestelmää';

  @override
  String get themeLight => 'Valo';

  @override
  String get themeDark => 'Pimeä';

  @override
  String get themeColor => 'Teeman väri';

  @override
  String get themeColorModeSingle => 'Yksi teema väri';

  @override
  String get themeColorModeColorful => 'Värikäs';

  @override
  String get themeColorUiColors => 'Käyttöliittymän värit';

  @override
  String get themeColorCourseColors => 'Kurssin värit';

  @override
  String get themeColorPrimary => 'Ensisijainen';

  @override
  String get themeColorSecondary => 'Sekundaariset';

  @override
  String get themeColorTertiary => 'Tertiaarinen';

  @override
  String get themeColorCourseText => 'Kurssin teksti';

  @override
  String get themeColorCourseTextAuto => 'Automaattinen';

  @override
  String get themeColorCourseTextCustom => 'Mukautettu väri';

  @override
  String get themeColorCourseColorsEmpty =>
      'Kurssin värit luodaan aikataulun tuomisen jälkeen.';

  @override
  String get themeCustomColor => 'Mukautettu väri';

  @override
  String get themeApplyCustomColor => 'Käytä väriä';

  @override
  String get themeApplySettings => 'Soveltaa asetuksia';

  @override
  String get dataImportExport => 'Tuo- ja vientitiedot';

  @override
  String get dataImportExportDesc =>
      'Tuo täydet tiedot tai yksittäiset aikataulut tai vie nykyiset/kaikki aikataulut.';

  @override
  String get appBackupTitle => 'Sovelluksen varmuuskopiointi ja palautus';

  @override
  String get appBackupSubtitle =>
      'Varmuuskopioi tai palauta lukujärjestykset, aikataulut, asetukset ja koulusivustot. API-avaimia ei sisällytetä.';

  @override
  String get appBackupSheetSubtitle =>
      'Täysi palautus korvaa nykyiset sovellustiedot. AI API -avaimet ovat suojatussa tallennustilassa, eikä niitä kirjoiteta varmuuskopiotiedostoihin.';

  @override
  String get restoreBackupFileTitle => 'Palauta JSON-tiedostosta';

  @override
  String get restoreBackupFileSubtitle =>
      'Valitse täydellinen Sked-varmuuskopiotiedosto. Vahvistat ennen palautusta.';

  @override
  String get restoreBackupTextTitle => 'Liitä varmuuskopion JSON';

  @override
  String get restoreBackupTextSubtitle =>
      'Liitä täydellinen varmuuskopio ja palauta nykyiset sovellustiedot.';

  @override
  String get shareBackupTitle => 'Jaa varmuuskopiotiedosto';

  @override
  String get shareBackupSubtitle =>
      'Vie kaikki sovellustiedot JSON-muodossa. API-avaimet jätetään pois.';

  @override
  String get saveBackupTitle => 'Tallenna varmuuskopiotiedosto';

  @override
  String get saveBackupSubtitle =>
      'Tallenna sovelluksen täydellinen varmuuskopio paikalliseen tiedostoon.';

  @override
  String get copyBackupTitle => 'Kopioi varmuuskopion teksti';

  @override
  String get copyBackupSubtitle =>
      'Näytä varmuuskopion koko JSON, jotta voit kopioida sen tai tallentaa sen väliaikaisesti.';

  @override
  String get restoreBackupConfirmTitle =>
      'Palautetaanko täydellinen varmuuskopio?';

  @override
  String get restoreBackupConfirmMessage =>
      'Tämä korvaa kaikki nykyiset lukujärjestykset, yleiset aikataulut, asetukset ja koulusivustot. API-avaimia ei tuoda varmuuskopioista; syötä avain uudelleen ennen lukujärjestysten jäsentämistä.';

  @override
  String get restoreBackupConfirmAction => 'Palauta varmuuskopio';

  @override
  String get restoreBackupSuccessMessage =>
      'Sovelluksen täydellinen varmuuskopio palautettiin. AI API -avaimet on syötettävä uudelleen.';

  @override
  String get restoreBackupFailureMessage =>
      'Palautus epäonnistui. Tarkista varmuuskopion sisältö ja yritä uudelleen.';

  @override
  String get openSourceLicenses => 'Avoimen lähdekoodin lisenssit';

  @override
  String get openSourceLicensesDesc =>
      'Katso Flutterin riippuvuuksien ja mukana olevien sovelluskuvakkeiden lisenssit.';

  @override
  String get checkForUpdates => 'Tarkista päivitykset';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates => 'Microsoft Store hallitsee päivityksiä';

  @override
  String get includePrereleaseUpdates => 'Vastaanota ennakkoversioita';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Sisällytä Alpha-, Beta- ja RC-versiot, jotka voivat olla epävakaita. Pois käytöstä tarjotaan vain vakaita versioita.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Jo uusimmassa versiossa ($version)';
  }

  @override
  String get currentVersionLabel => 'Nykyinen versio';

  @override
  String get newVersionAvailable => 'Päivitys saatavilla';

  @override
  String get latestVersionLabel => 'Viimeisin versio';

  @override
  String get updateContentLabel => 'Päivitä yksityiskohdat';

  @override
  String get officialWebsite => 'Virallinen verkkosivusto';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Pilviasema';

  @override
  String get ignoreThisVersion => 'Jätä tämä versio huomiotta';

  @override
  String get openUpdatesFailed => 'Päivityslinkkiä ei voi avata';

  @override
  String get updateCheckFailedTitle => 'Päivitystarkastus epäonnistui';

  @override
  String get updateCheckFailedMessage =>
      'Uusimman version hakeminen GitHubista epäonnistui. Voit silti avata GitHubin julkaisusivun alta.';

  @override
  String get githubRepository => 'GitHub-varasto';

  @override
  String get googlePlayStoreDesc => 'Näytä Sked Google Playssa';

  @override
  String get openGooglePlayFailed => 'Google Playn avaaminen epäonnistui';

  @override
  String get starSkedOnGithub => 'Anna Skedille tähti GitHubissa!';

  @override
  String get starSkedOnGithubDesc =>
      'Avaa projektin tietovarasto ja anna Skedille tähti';

  @override
  String get openGithubFailed => 'GitHub-arkiston linkkiä ei voi avata';

  @override
  String get openPrivacyPolicyFailed =>
      'Tietosuojakäytännön linkkiä ei voi avata';

  @override
  String get selectPeriodTimeSet => 'Valitse ajanjaksoa';

  @override
  String get newItem => 'Uusi';

  @override
  String get editPeriodTimeSet => 'Muokkaa jakson aikaasetetta';

  @override
  String get importTimetableFiles => 'Tuo aikataulu';

  @override
  String get importTimetableFilesDesc =>
      'Tukee yhtä tai useampaa aikataulutiedostoa.';

  @override
  String get importTimetableText => 'Tuo aikataulu tekstistä';

  @override
  String get importTimetableTextDesc =>
      'Liitä aikataulun JSON-sisältö ja tuo se.';

  @override
  String get shareTimetableFiles => 'Jaa aikataulutiedostoja';

  @override
  String get shareTimetableFilesDesc =>
      'Valitse ensin yksi tai useampi aikataulu.';

  @override
  String get saveTimetableFiles => 'Tallenna aikataulutiedostot';

  @override
  String get saveTimetableFilesDesc =>
      'Valitse ensin yksi tai useampi aikataulu.';

  @override
  String get exportTimetableText => 'Vie aikataulu tekstinä';

  @override
  String get exportTimetableTextDesc =>
      'Valitse yksi tai useampi aikataulu ja kopioi sitten JSON-sisältö.';

  @override
  String get jsonContent => 'JSON-sisältö';

  @override
  String get pasteJsonContentHint => 'Liitä JSON-sisältö tuodaan.';

  @override
  String get jsonContentEmpty => 'Liitä ensin JSON-sisältö.';

  @override
  String get copyText => 'Kopioi';

  @override
  String get copiedToClipboard => 'Kopioi leikepöydälle';

  @override
  String get share => 'Jaa';

  @override
  String get selectTimetablesToExport => 'Valitse aikataulut vientiin';

  @override
  String get selectTimetablesToImport => 'Valitse aikataulut tuoda';

  @override
  String timetableCourseCount(int count) {
    return '$count kursseja';
  }

  @override
  String get importAction => 'Tuo';

  @override
  String get importTimetableDialogTitle => 'Tuo aikataulu';

  @override
  String get chooseImportMethod => 'Valitse, miten tuodaan.';

  @override
  String get importAsNewTimetable => 'Tuo uutena aikatauluna';

  @override
  String get replaceCurrentTimetable => 'Korvaa nykyinen aikataulu';

  @override
  String get importPeriodTimeSetDialogTitle => 'Tuontijakson aikaasetteet';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Tämä tiedosto sisältää sidottuja ajanjaksoja. Haluatko tuoda ja yhdistää ne?';

  @override
  String get importBundledPeriodTimeSets => 'Tuo ja liitä';

  @override
  String get discardBundledPeriodTimeSets => 'Hävittää sitoutuneet sarjat';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Ei ole olemassa olemassa olevaa jaksoaikaasetetta, joten niputettuja jaksoaikaasetteita ei voida hylätä.';

  @override
  String savedToPath(Object path) {
    return 'Tallennettu $path';
  }

  @override
  String get saveCancelled => 'Tallenna peruutettu';

  @override
  String get fileSaveRestrictedTitle => 'Tiedoston tallennus rajoitettu';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Järjestelmä ei voinut tallentaa tiedostoa. Voit kokeilla uudelleen tai käyttää jakamista sen sijaan.';

  @override
  String get retrySave => 'Yritä tallentaa uudelleen';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Ota tiedostojen käyttö käyttöön järjestelmäasetuksissa, palaa sitten ja yritä viedä uudelleen.';

  @override
  String get openSettings => 'Avaa asetukset';

  @override
  String get browserDownloadRestrictedTitle => 'Selaimen lataus rajoitettu';

  @override
  String get browserDownloadRestrictedMessage =>
      'Tämä selain ei tue suoraa tallennusta paikalliseen tiedostoon. Tarkista selaimen latausoikeudet tai käytä tiedostojen jakamista sen sijaan.';

  @override
  String get switchToShare => 'Käytä jakamista sen sijaan';

  @override
  String get fileSaveFailedTitle => 'Tiedoston tallennus epäonnistui';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Nykyiseen polkuun ei voi kirjoittaa. Kohdekansio saattaa olla suojattu, tiedosto saattaa olla käytössä tai polku saattaa olla kirjoittamaton.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Järjestelmä ei voinut tallentaa tiedostoa. Voit yrittää uudelleen, tarkistaa järjestelmän asetukset tai käyttää tiedostojen jakamista sen sijaan.';

  @override
  String get retryLater => 'Yritä uudelleen myöhemmin';

  @override
  String get exportSwitchedToShare =>
      'Vaihdettu tiedostojen jakamiseen vientiä varten';

  @override
  String get saveFailedRetry =>
      'Tallennus epäonnistui. Yritä uudelleen myöhemmin.';

  @override
  String get periodTimesUnsavedExitTitle => 'Muutoksia ei ole tallennettu';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Oppituntien aikojen viimeisimpiä muutoksia ei voitu tallentaa. Voit yrittää uudelleen, jatkaa muokkausta tai hylätä muutokset.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Osa oppituntien ajoista on virheellisiä. Korjaa ne ennen tallentamista tai hylkää muutokset ja poistu.';

  @override
  String get discardChangesAndExit => 'Hylkää muutokset ja poistu';

  @override
  String get appInstanceBlockedTitle => 'Sked on jo avoinna';

  @override
  String get appInstanceBlockedMessage =>
      'Toinen Sked-ikkuna tai selaimen välilehti käyttää paikallisia tietojasi. Sulje se ja yritä uudelleen.';

  @override
  String get appInstanceLeaseFailedTitle =>
      'Paikalliset tiedot eivät ole käytettävissä';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Sked ei voinut vahvistaa yksinomaista pääsyä paikallisiin tietoihin. Tietojasi ei avattu eikä muutettu. Tarkista tallennustilan käyttöoikeus ja yritä uudelleen.';

  @override
  String get savingChanges => 'Tallennetaan muutoksia...';

  @override
  String get showApiKey => 'Näytä API-avain';

  @override
  String get hideApiKey => 'Piilota API-avain';

  @override
  String get importFailedCheckContent =>
      'Tuo epäonnistui. Tarkista tiedoston sisältö.';

  @override
  String get noImportableTimetables =>
      'Tuotusta tiedostosta ei löytynyt käytettäviä aikatauluja.';

  @override
  String importedTimetablesCount(int count) {
    return 'Tuotut $count aikataulut';
  }

  @override
  String get periodTimesTitle => 'Ajankohdat';

  @override
  String get importExport => 'Tuonti ja vienti';

  @override
  String get importPeriodTemplate => 'Tuontikauden malli';

  @override
  String get importPeriodTemplateText => 'Tuo ajanjaksomalli tekstistä';

  @override
  String get sharePeriodTemplate => 'Osakeaikauden malli';

  @override
  String get saveTemplateToFile => 'Tallenna malli tiedostoon';

  @override
  String get exportPeriodTemplateText => 'Vie jakson malli tekstinä';

  @override
  String get deletePeriodTimeSet => 'Poista ajanjaksoa';

  @override
  String get periodTimeSetName => 'Ajankohta asetettu nimi';

  @override
  String get addOnePeriod => 'Lisää jakso';

  @override
  String periodNumberLabel(int index) {
    return 'Ajankohta $index';
  }

  @override
  String get deleteThisPeriod => 'Poista tämä jakso';

  @override
  String durationMinutes(int minutes) {
    return 'Kesto $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Aikaisesta aukosta $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'Loppuajan on oltava myöhemmin kuin alkamisaika';

  @override
  String get periodOverlapPrevious => 'Tämä jakso ylittää edellisen';

  @override
  String get periodTimesSaved => 'Säästetyt ajanjaksot';

  @override
  String get deletePeriodTimeSetTitle => 'Poista ajanjaksoa';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Poista \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'nykyisen ajan asettaminen';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Tuotut $count jaksoajat';
  }

  @override
  String get periodFilePermissionTitle => 'Tiedoston käyttöoikeus tarvitaan';

  @override
  String get androidFilePermissionMessage =>
      'Android export edellyttää tiedostojen käyttöoikeutta. Anna lupa jatkaa säästämistä.';

  @override
  String get reauthorize => 'Hyväksy uudelleen';

  @override
  String get permissionPermanentlyDeniedTitle => 'Lupa kielletty pysyvästi';

  @override
  String get permissionSettingsExportMessage =>
      'Ota tiedostojen käyttö käyttöön järjestelmäasetuksissa, palaa sitten ja yritä viedä uudelleen.';

  @override
  String get privacyPolicyTitle => 'Tietosuojakäytäntö';

  @override
  String get privacyPolicyEntryDesc =>
      'Lue, miten sovellus käsittelee paikallista tallennusta, koulun sivuston konfigurointia, tiedostojen tuontia/vientiä, verkkosivujen analysointia ja ulkoisia linkkejä.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Hyväksytty versio: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked on paikalliskäyttöön keskittyvä lukujärjestystyökalu. Lukujärjestykset, ajanjaksot ja koulusivuston asetukset tallennetaan vain laitteellesi tai selaimeesi, eikä niitä koskaan ladata automaattisesti. Sovellus käsittelee tietoja vain, kun käynnistät nimenomaisesti toimintoja kuten tuonnin, verkkosivujen analysoinnin, jakamisen tai ulkoisten linkkien avaamisen. Täydellinen tietosuojakäytäntö on saatavilla verkossa.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Paikallinen varastointi';

  @override
  String get privacyPolicyLocalStorageBody =>
      'Skedin laitesovellus tallentaa lukujärjestykset, yleiset aikataulut, niihin liittyvät asetukset ja muokattavat oppilaitosten sivustoasetukset käyttöjärjestelmän sovellustukihakemistoon. Selainversio käyttää selaimen tallennustilaa. Aiempien versioiden käyttäjän Tiedostot-kansioon tallentamat tiedostot säilyvät, mutta niitä ei lueta tai siirretä automaattisesti. Säilytä nämä tiedot viemällä vanhasta versiosta sovelluksen täydellinen varmuuskopio ennen päivitystä ja palauttamalla se päivityksen jälkeen. AI API -asetukset tallennetaan paikallisesti. Mukautettu API-avain tallennetaan alustan suojattuun tallennustilaan, kun se on käytettävissä. Sovelluksen täydelliset varmuuskopiot eivät sisällä mukautettua API-avainta. Sovellus ei lähetä näitä paikallisia tietoja automaattisesti kehittäjän hallinnoimalle palvelimelle.';

  @override
  String get privacyPolicyImportExportTitle => 'Tuonti ja vienti';

  @override
  String get privacyPolicyImportExportBody =>
      'Sovellus lukee tai kirjoittaa aikataulun JSON-tiedostoja, koulun sivuston JSON-tiedostoja ja ajanjaksomallitiedostoja vain, kun valitset nimenomaisesti tiedoston tai aloitat vientitoimen. Näiden tiedostojen tuominen on paikallista, ellet valitse myös verkkosivujen analysointia. Mukautetun malliluettelon hakeminen on myös nimenomainen verkkotoiminta ja se ottaa yhteyttä vain määrittämääsi mukautettuun päätepisteeseen.';

  @override
  String get privacyPolicySharingTitle => 'Jaaminen';

  @override
  String get privacyPolicySharingBody =>
      'Kun käytät nimenomaisesti jakamista, sovellus siirtää viedyn tiedoston järjestelmän jakamiseen tai valitsemallesi kohde-sovellukselle. Tiedoston käsittelytapa riippuu valitsemastasi kohde-sovelluksesta tai palvelusta.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Ulkoiset linkit';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Kun avaat ulkoisia linkkejä, kuten GitHub-arkistoa, sovellus siirtää toiminnan selaimeesi tai muulle ulkoiselle sovellukselle. Tietojen käsittelyä tämän kohdan jälkeen hallitsee avaamasi kolmas osapuoli.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Mitä sovellus ei kerää';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Sovellus ei vaadi Sked-tiliä eikä salli analyysiä, mainontunnisteita tai pilvivarmuuskopiointia. Se ei myöskään tarjoa erityistä kenttää koulutilien salasanojen keräämiseen. Jos kirjaudut koulun verkkosivustoon sovelluksen sisällä, tämä vuorovaikutus tapahtuu avaamallasi koulusivulla.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Verkkosivujen analysointi';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Kun käytät koulun verkkosivun tuontia tai jäsennät liitettyä lukujärjestystekstiä / HTML:ää, sovellus valmistelee ja puhdistaa sisällön ensin paikallisesti ja lähettää sen jälkeen lähettämäsi lukujärjestystekstin, sivutekstin tai HTML-sisällön, valinnaisen sivun otsikon ja URL-osoitteen, sovelluksen nykyisen kielen sekä jäsentimen kehotesisällön määrittämääsi OpenAI-yhteensopivaan päätepisteeseen. Malliluettelon haku tekee pyynnön samaan päätepisteeseen. Sked ei tarjoa sisäänrakennettua jäsenninpäätepistettä eikä lähetä jäsennyspyyntöjä kehittäjän hallitsemaan lukujärjestysjäsentimen taustapalveluun. Mukautettu päätepiste ja mahdolliset ylävirran palvelut voivat tallentaa, välittää, rajoittaa, poistaa tai muuten käsitellä tietoja valitsemasi palveluntarjoajan sääntöjen mukaisesti. Jos käytät http:// Base URL -osoitetta, käytä sitä vain luotetuilla laitteilla, luotetuissa verkoissa ja luotetuissa päätepistepalveluissa, koska sisältöä ja API-avaimia ei välttämättä suojata siirtokerroksen salauksella.';

  @override
  String get privacyPolicyUpdatesTitle => 'Käytännön päivitykset';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Nykyinen tietosuojakäytännön versio on $version. Jos myöhempi versio muuttaa tietojen käsittelytapaa, sovellus saattaa pyytää sinua lukemaan ja hyväksymään päivitetyn käytännön uudelleen.';
  }

  @override
  String get privacyGateTitle =>
      'Hyväksy tietosuojakäytäntö ennen sovelluksen käyttöä';

  @override
  String get privacyGateSummaryStorage =>
      'Aikataulut, ajanjaksot ja koulun sivuston konfiguraatio tallennetaan vain paikallisesti eikä niitä ladata automaattisesti kehittäjän palvelimelle.';

  @override
  String get privacyGateSummaryImportExport =>
      'Tuo, vienti ja jakaminen tapahtuu vain, kun käynnistät ne nimenomaisesti; verkkosivujen analysointi lähettää vain toimittamasi pakkautetun sisällön määritettyyn analysointipäätepisteeseen, ja voit tarkistaa analysoidun aikataulun ennen tallennusta.';

  @override
  String get privacyGateSummaryUpdates =>
      'Jos myöhempi versio muuttaa tietojen käsittelyä, sovellus saattaa pyytää sinua tarkistamaan päivitetyn tietosuojakäytännön uudelleen.';

  @override
  String get schoolWebImportEntry => 'Tuo koulun verkkosivulta';

  @override
  String get schoolWebImportEntryDesc =>
      'Tuo nykyinen aikataulun sivu koulun sivustosta.';

  @override
  String get schoolSitesManageEntry => 'Hallitse koulun sivustoja';

  @override
  String get schoolSitesManageEntryDesc =>
      'Lisää, muokkaa ja poista koulun kirjautumisURL-osoitteita JSON-tuonnin ja -viennin avulla.';

  @override
  String get schoolSitesPageTitle => 'Koulun sivuston hallinta';

  @override
  String get schoolSitesImportJson => 'Tuo koulun JSON';

  @override
  String get schoolSitesShareJson => 'Jaa koulun JSON';

  @override
  String get schoolSitesSaveJson => 'Tallenna koulun JSON';

  @override
  String get schoolSitesSaved => 'Koulun sivustot tallennettu';

  @override
  String get schoolSitesImported => 'Koulun sivustot tuodaan';

  @override
  String get schoolSitesImportPreviewTitle =>
      'Tarkista oppilaitossivustojen tuonti';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return '$validCount kelvollista sivustoa, $invalidCount virheellistä merkintää.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Tiedosto sisältää tyhjän oppilaitossivustojen luettelon.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Merkintä $position on virheellinen ja ohitetaan.';
  }

  @override
  String get schoolSitesImportMerge => 'Yhdistä';

  @override
  String get schoolSitesImportReplace => 'Korvaa';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Korvataanko nykyiset oppilaitossivustot?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Tämä poistaa $currentCount nykyistä sivustoa ja tallentaa $importedCount tuotua sivustoa. Tätä ei voi kumota.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Oppilaitossivustojen tiedot on palautettava';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked ei voinut lukea oppilaitossivustojen tiedostoa tai sen varmuuskopiota. Suojatut kopiot luotiin ennen kirjoittamisen estämistä.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Oppilaitossivustojen tallennustila ei ole käytettävissä';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked ei pääse oppilaitossivustojen tallennustilaan juuri nyt. Tarkista tallennustilan käyttöoikeus tai laitteen saatavuus ja yritä uudelleen. Nykyisiä sivustotietoja ei korvata.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Palautustiedostot tai kyseiset tallennussijainnit luetellaan alla. Älä muuta tiedostoja ennen sivustoluettelon palauttamista.';

  @override
  String get schoolSitesRecoveryStartFreshAction =>
      'Aloita ilman oppilaitossivustoja';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Aloitetaanko tyhjällä oppilaitossivustojen luettelolla?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Suojatut kopiot säilytetään, mutta Sked luo uuden tyhjän oppilaitossivustojen tiedoston. Jatka vain, jos et halua ensin yrittää palautusta uudelleen.';

  @override
  String get schoolSitesEmpty => 'Ei koulun sivuston määritystä vielä.';

  @override
  String get schoolSitesNameLabel => 'Koulun nimi';

  @override
  String get schoolSitesLoginUrlLabel => 'Kirjautumisen URL';

  @override
  String get schoolSitesAdd => 'Lisää koulu';

  @override
  String get schoolSitesEdit => 'Muokkaa koulua';

  @override
  String get schoolSitesDeleteTitle => 'Poista koulu';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Poista \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Täytä ensin koulun nimi ja kirjautumisosoite.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Tuo liittämällä aikataulun sivun sisältö';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Liitä lähdekoodi tai raaka-sivun sisältö, joka sisältää aikataulutietoja manuaalisesti.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Aikataulun analysointi sivun sisällöstä';

  @override
  String get schoolHtmlImportUrlLabel => 'Lähde-URL (valinnainen)';

  @override
  String get schoolHtmlImportTitleLabel => 'Sivun otsikko (valinnainen)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Sivun sisältö';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Liitä lähdekoodi tai raaka-sivun sisältö, joka sisältää aikataulutietoja täällä.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Kaikki aikataulutietoja sisältävä sisältö voidaan analysoida ja tuoda, ei vain HTML.';

  @override
  String get schoolHtmlImportCompress => 'Valmistele sisältö';

  @override
  String get schoolHtmlImportCompressed => 'Sisältö valmisteltu';

  @override
  String get schoolHtmlImportCompressFirst => 'Valmistele sisältö ensin.';

  @override
  String get schoolHtmlImportSubmit => 'Analyysi ja tuonti';

  @override
  String get schoolImportContentTruncated =>
      'Tämä sivu saavutti turvallisen tuonnin rajan. Vain tallennettu osa lähetetään jäsennettäväksi.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsing voi kestää jonkin aikaa. Odottakaa.';

  @override
  String get schoolHtmlImportEmpty => 'Liitä ensin HTML-sivu.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Takaisin verkkosivulle';

  @override
  String get schoolWebImportPageTitle => 'Koulun verkkosivujen tuonti';

  @override
  String get schoolWebImportPreview => 'Tuo esikatselu';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count kursseja';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return ' $count jaksot';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Sivun otsikko';

  @override
  String get schoolWebImportParserUsed => 'Parseri';

  @override
  String get schoolWebImportWarnings => 'Tuo muistiinpanot';

  @override
  String get schoolWebImportParserDetails => 'Jäsennyksen tiedot';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Laajenna jäsennyksen tiedot';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Kutista jäsennyksen tiedot';

  @override
  String get schoolWebImportOpenPageHint =>
      'Kirjaudu koulun sivustolle sovelluksessa ja siirry sitten aikataulun sivulle manuaalisesti.';

  @override
  String get schoolWebImportConfigMissing =>
      'Mukautetun jäsentimen asetukset ovat puutteelliset. Täytä ensin perus-URL, API-avain ja malli.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Tämä alusta ei vielä tue upotettua verkkokirjautumista. Käytä alustaa, jossa on WebView-tuki.';

  @override
  String get schoolWebImportSelectSchool => 'Valitse koulu';

  @override
  String get schoolWebImportNoSchools =>
      'Koulun konfiguraatiota ei ole käytettävissä. Tarkista ensin school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Koulun asetuksen lataaminen epäonnistui. Tarkista JSON-tiedostomuoto.';

  @override
  String get schoolWebImportImportCurrentPage => 'Tuo nykyinen sivu';

  @override
  String get schoolWebImportLoadingPage => 'Sivu ladataan…';

  @override
  String get schoolWebImportParsing => 'Nykyisen sivun analysointi...';

  @override
  String get schoolWebImportLoadFailed =>
      'Sivun lataus epäonnistui. Virkistä tai yritä uudelleen myöhemmin.';

  @override
  String get schoolWebImportUnknownOrigin => 'Tuntematon sivusto';

  @override
  String get schoolWebImportExitTitle => 'Poistutaanko selaimesta?';

  @override
  String get schoolWebImportExitMessage =>
      'Sivu suljetaan. Kaikki, mitä et ole vielä tuonut, menetetään.';

  @override
  String get schoolWebImportExitConfirm => 'Poistu';

  @override
  String get schoolWebImportEmptyPage =>
      'Nykyinen sivun sisältö on tyhjä eikä sitä voi tuoda vielä.';

  @override
  String get schoolWebImportSuccess => 'Web aikataulu tuotu';

  @override
  String get schoolImportParserSettingsTitle =>
      'Lukujärjestyksen tuontirajapinta';

  @override
  String get schoolImportParserSettingsDesc =>
      'Määritä OpenAI-yhteensopiva rajapinta lukujärjestysten tuontiin, ei keskusteluavustajalle.';

  @override
  String get schoolImportParserSourceTitle => 'Parserin lähde';

  @override
  String get schoolImportParserSourceCustomOpenAi =>
      'Custom OpenAI-yhteensopiva';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Mukautettu OpenAI-yhteensopiva analysoija';

  @override
  String get schoolImportParserCustomPromptTitle => 'Mukautettu pyyntö';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Muokkaa sisäänrakennettua analysointipyyntöä täällä. Muutokset vaikuttavat vain mukautettuun OpenAI-yhteensopivaan analysoijaan.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Sisäänrakennettu pyyntö ladataan täällä oletusarvoisesti. Tyhjennä se pudota takaisin sisäänrakennettuun versioon.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Palauta oletuspyyntö';

  @override
  String get schoolImportParserBaseUrl => 'Perus-URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL -osoitteen on oltava HTTP- tai HTTPS-osoite, jossa on isäntä.';

  @override
  String get schoolImportParserApiKey => 'API-avain';

  @override
  String get schoolImportParserModel => 'malli';

  @override
  String get schoolImportParserFetchModels => 'Hae malliluettelo';

  @override
  String get schoolImportParserFetchingModels => 'Haen malleja. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Loppupisteeseen ei palautettu malleja.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Malleja ei voitu hakea. Tarkista päätepiste ja yritä uudelleen.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Haetut $count mallit';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'Mukautettu API-avain tallennetaan alustan suojattuun tallennustilaan, kun se on käytettävissä. Käytä mukautetun jäsentimen tunnuksia ja HTTP-päätepisteitä vain luotettavissa laitteissa, selaimissa ja verkoissa.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Käytetäänkö salaamatonta HTTP-päätepistettä?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'API-avain ja lukujärjestyksen sisältö voidaan lukea tai niitä voidaan muuttaa siirron aikana. Jatka vain, jos luotat tähän laitteeseen, verkkoon ja päätepisteeseen. Hyväksyntä on voimassa, kunnes suljet Skedin.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Mukautettu analysoinnin konfigurointi on epätäydellinen. Täytä ensin perus-URL, API-avain ja malli.';

  @override
  String get clearAppData => 'Tyhjennä tiedot';

  @override
  String get clearAppDataDesc =>
      'Poista kaikki paikalliset Skedin tiedot pysyvästi ja sulje sovellus';

  @override
  String get clearAppDataConfirmTitle => 'Tyhjennetäänkö kaikki Skedin tiedot?';

  @override
  String get clearAppDataConfirmMessage =>
      'Tämä poistaa pysyvästi lukujärjestykset, aikataulut, asetukset, oppilaitossivustot, paikalliset varmuuskopiot, palautuskopiot ja AI API -avaimen sekä sulkee Skedin. Muualle vietyjä tiedostoja ei poisteta. Tätä ei voi kumota.';

  @override
  String get clearAppDataAction => 'Tyhjennä tiedot ja poistu';

  @override
  String get clearAppDataFailed =>
      'Kaikkien paikallisten tietojen tyhjentäminen epäonnistui. Sked pysyy avoinna, jotta voit yrittää uudelleen.';

  @override
  String get clearAppDataExitFailed =>
      'Paikalliset tiedot tyhjennettiin, mutta Skediä ei voitu sulkea. Sulje sovellus käsin ennen kuin käytät sitä uudelleen.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Parseri: Mukautettu ($model)';
  }

  @override
  String get privacyViewFullPolicy => 'Katso täysi tietosuojakäytäntö';

  @override
  String get privacyAgreeAndContinue => 'Suostu ja jatka';

  @override
  String get privacyDecline => 'Vältä';

  @override
  String get privacyDeclineWebHint =>
      'Tämä selainympäristö ei salli sovelluksen sulkea sivua puolestasi. Jos et ole samaa mieltä, sulje tämä välilehti tai ikkuna itse.';

  @override
  String get defaultPeriodTimeSetName => 'Oletusajat';

  @override
  String get periodTimeSetFallbackName => 'Ajankohdat';

  @override
  String get untitledTimetableName => 'Nimettömä aikataulu';

  @override
  String get newTimetableName => 'Uusi aikataulu';

  @override
  String get newPeriodTimeSetName => 'Uusi aikakausi asetettu';

  @override
  String get emptyTimetableName => 'Tyhjä aikataulu';

  @override
  String importedPeriodTimeSetName(Object name) {
    return ' $name jaksot';
  }

  @override
  String get importFileTypeMismatchMessage => 'Tuo tiedostotyyppi ei vastaa.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Tätä tuontitiedoston versiota ei vielä tueta.';

  @override
  String get noPeriodTimesInImportMessage =>
      'Tuontitiedostossa ei löytynyt ajanjaksoja.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Valitse ainakin yksi aikataulu.';

  @override
  String get noExportableTimetableMessage => 'Viennille ei ole aikataulua.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Nykyisen aikataulun korvaaminen tukee vain yhden aikataulun valintaa.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Nykyistä aikataulua ei ole korvattavana.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Tätä ajanjaksoa käyttää edelleen $count aikataulu. Aseta ne uudelleen ennen poistamista.';
  }

  @override
  String get weekdayMonday => 'Maanantai';

  @override
  String get weekdayTuesday => 'tiistaina';

  @override
  String get weekdayWednesday => 'Keskiviikko';

  @override
  String get weekdayThursday => 'Torstaina';

  @override
  String get weekdayFriday => 'perjantaina';

  @override
  String get weekdaySaturday => 'Lauantai';

  @override
  String get weekdaySunday => 'Sunnuntai';

  @override
  String get weekdayShortMonday => 'maanantaina';

  @override
  String get weekdayShortTuesday => 'tiistai';

  @override
  String get weekdayShortWednesday => 'Keskiviikko';

  @override
  String get weekdayShortThursday => 'torstaina';

  @override
  String get weekdayShortFriday => 'perjantai';

  @override
  String get weekdayShortSaturday => 'Lauantaina';

  @override
  String get weekdayShortSunday => 'Aurinko';

  @override
  String get monthJanuary => 'tammikuu';

  @override
  String get monthFebruary => 'helmikuu';

  @override
  String get monthMarch => 'maaliskuu';

  @override
  String get monthApril => 'huhtikuu';

  @override
  String get monthMay => 'toukokuu';

  @override
  String get monthJune => 'kesäkuu';

  @override
  String get monthJuly => 'heinäkuu';

  @override
  String get monthAugust => 'elokuu';

  @override
  String get monthSeptember => 'syyskuu';

  @override
  String get monthOctober => 'lokakuu';

  @override
  String get monthNovember => 'marraskuu';

  @override
  String get monthDecember => 'joulukuu';

  @override
  String get semesterWeeksWholeTerm => 'Koko lukukausi';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Viikot $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Viikot $value';
  }

  @override
  String get generalSchedule => 'Yleinen aikataulu';

  @override
  String get studentTimetable => 'Lukujärjestys';

  @override
  String get firstLaunchTitle => 'Valitse aloitustila';

  @override
  String get firstLaunchSubtitle =>
      'Valitse työtila, jota käytät eniten. Voit vaihtaa tilaa myöhemmin.';

  @override
  String get firstLaunchStudentDesc =>
      'Hallitse lukujärjestyksiä, kursseja, viikkoja, oppituntien aikoja ja tuonteja.';

  @override
  String get firstLaunchGeneralDesc =>
      'Hallitse kategorioita, tapahtumia, muistutuksia ja JSON / ICS -tietoja.';

  @override
  String get firstLaunchStartStudent => 'Aloita lukujärjestyksellä';

  @override
  String get firstLaunchStartGeneral => 'Aloita aikataululla';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Valitsemalla aloitustyötilan vahvistat, että olet lukenut ja hyväksyt ';

  @override
  String get firstLaunchPrivacyConsentLink => 'tietosuojakäytännön';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Vaihda tilaa';

  @override
  String get generalScheduleComingSoon => 'Yleinen aikataulu on tulossa pian';

  @override
  String get switchToStudentTimetable => 'Siirry lukujärjestykseen';

  @override
  String get mySchedule => 'Oma aikataulu';

  @override
  String get today => 'Tänään';

  @override
  String get addEvent => 'Lisää tapahtuma';

  @override
  String get editEvent => 'Muokkaa tapahtumaa';

  @override
  String get eventTitle => 'Otsikko';

  @override
  String get eventTitleRequired => 'Anna otsikko';

  @override
  String get eventStartTime => 'Alkuaika';

  @override
  String get eventEndTime => 'Loppuaika';

  @override
  String get eventDate => 'Päivämäärä';

  @override
  String get eventTime => 'Aika';

  @override
  String get eventNotes => 'Muistiinpanot';

  @override
  String get eventColor => 'Väri';

  @override
  String get eventRecurrence => 'Toisto';

  @override
  String get recurrenceNone => 'Ei toistoa';

  @override
  String get recurrenceWeekly => 'Viikoittain';

  @override
  String get recurrenceEndDate => 'Päättymispäivä';

  @override
  String get recurrenceNoEndDate => 'Ei päättymispäivää';

  @override
  String get recurrenceSetEndDate => 'Aseta';

  @override
  String get recurrenceChangeEndDate => 'Muuta';

  @override
  String get repeatsWeekly => 'Toistuu viikoittain';

  @override
  String recurrenceUntil(Object date) {
    return '$date asti';
  }

  @override
  String get switchToGeneralSchedule => 'Siirry yleiseen aikatauluun';

  @override
  String get generalDisplaySettings => 'Aikataulun näyttöasetukset';

  @override
  String get generalDisplaySettingsDesc =>
      'Näkymät, työkalurivi, päivämäärämuoto ja pikalisäys';

  @override
  String get closePopupOnOutsideTap =>
      'Sulje ponnahdusikkuna napauttamalla sen ulkopuolelle';

  @override
  String get showGridLines => 'Näytä ruudukon viivat';

  @override
  String get generalScheduleImportExport => 'Kategorioiden tuonti ja vienti';

  @override
  String get generalScheduleImportExportDesc =>
      'Tuo tai jaa aikataulun kategorioita';

  @override
  String get importGeneralSchedules => 'Tuo kategoriat';

  @override
  String get importGeneralSchedulesDesc => 'Lue kategoriat JSON-tiedostosta';

  @override
  String get shareGeneralSchedules => 'Jaa kategoriat';

  @override
  String get shareGeneralSchedulesDesc => 'Jaa kategoriat JSON-tiedostona';

  @override
  String get saveGeneralSchedules => 'Tallenna kategoriat';

  @override
  String get saveGeneralSchedulesDesc => 'Tallenna kategoriat JSON-tiedostona';

  @override
  String get selectSchedulesToExport => 'Valitse vietävät kategoriat';

  @override
  String get selectSchedulesToImport => 'Valitse tuotavat kategoriat';

  @override
  String generalScheduleEventCount(int count) {
    return 'Tapahtumia: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Tuotiin $count kategoriaa';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Lisätäänkö tuonti uutena kategoriana vai korvataanko olemassa oleva kategoria?';

  @override
  String get addAsNewSchedule => 'Lisää uutena kategoriana';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Valitse vähintään yksi kategoria.';

  @override
  String get noExportableScheduleMessage => 'Vietäviä kategorioita ei ole.';

  @override
  String get noSchedulesInImportMessage =>
      'Tuontitiedosto ei sisällä kategorioita.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Valitse korvaamista varten täsmälleen yksi tuotu kategoria.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Korvattavaksi valittu kategoria ei ole käytettävissä.';

  @override
  String get calendars => 'Kategoriat';

  @override
  String get calendar => 'Kategoria';

  @override
  String get viewWeek => 'Viikko';

  @override
  String get viewDay => 'Päivä';

  @override
  String get viewList => 'Luettelo';

  @override
  String get viewMonth => 'Kuukausi';

  @override
  String visibleCategoryCount(int count) {
    return '$count kategoriaa';
  }

  @override
  String get noVisibleCategories => 'Ei näkyviä kategorioita';

  @override
  String get selectCategoryToReplace => 'Valitse korvattava kategoria';

  @override
  String get replaceCategory => 'Korvaa kategoria';

  @override
  String get deleteEventTitle => 'Poista tapahtuma';

  @override
  String get deleteEventConfirmation => 'Tämä tapahtuma poistetaan pysyvästi.';

  @override
  String get deleteRecurringEventTitle => 'Poista toistuva tapahtuma';

  @override
  String get eventDuplicated => 'Tapahtuma kopioitiin';

  @override
  String get searchEvents => 'Hae tapahtumia';

  @override
  String get clearSearch => 'Tyhjennä haku';

  @override
  String get filterByColor => 'Suodata värin mukaan';

  @override
  String get allColors => 'Kaikki värit';

  @override
  String upcomingEventsCount(int count) {
    return 'Tulevia: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Myöhässä: $count';
  }

  @override
  String get allDay => 'Koko päivä';

  @override
  String get collapseAllDayTimeline => 'Supista koko päivän tapahtumat';

  @override
  String get expandAllDayTimeline => 'Laajenna koko päivän tapahtumat';

  @override
  String allDayEventsCount(int count) {
    return '$count koko päivän tapahtumaa';
  }

  @override
  String moreEvents(int count) {
    return '+$count muuta';
  }

  @override
  String get noMatchingEvents => 'Ei vastaavia tapahtumia';

  @override
  String get noUpcomingEvents => 'Ei tulevia tapahtumia';

  @override
  String get addCalendar => 'Lisää kategoria';

  @override
  String get newCalendar => 'Uusi kategoria';

  @override
  String get hideCalendar => 'Piilota kategoria';

  @override
  String get showCalendar => 'Näytä kategoria';

  @override
  String get rename => 'Nimeä uudelleen';

  @override
  String get renameCalendar => 'Nimeä kategoria uudelleen';

  @override
  String get name => 'Nimi';

  @override
  String get deleteCalendar => 'Poista kategoria';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Poistetaanko ”$name”?';
  }

  @override
  String get deleteThisOccurrence => 'Poista tämä esiintymä';

  @override
  String get deleteFutureOccurrences => 'Poista tämä ja seuraavat';

  @override
  String get deleteAllOccurrences => 'Poista koko sarja';

  @override
  String get duplicateEvent => 'Luo kopio';

  @override
  String get repeatsDaily => 'Toistuu päivittäin';

  @override
  String get repeatsMonthly => 'Toistuu kuukausittain';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Toistuu $interval $unit välein';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count kertaa';
  }

  @override
  String get recurrenceDaily => 'Päivittäin';

  @override
  String get recurrenceMonthly => 'Kuukausittain';

  @override
  String get recurrenceCustom => 'Mukautettu';

  @override
  String get recurrenceEvery => 'Joka';

  @override
  String get recurrenceUnit => 'Yksikkö';

  @override
  String get recurrenceDays => 'päivän';

  @override
  String get recurrenceWeeks => 'viikon';

  @override
  String get recurrenceMonths => 'kuukauden';

  @override
  String get recurrenceRepeatCount => 'Toistojen määrä';

  @override
  String get recurrenceNoLimit => 'Ei rajoitusta';

  @override
  String get recurrencePositiveNumber => 'Anna positiivinen luku';

  @override
  String get clearEndDate => 'Poista päättymispäivä';

  @override
  String get pickDate => 'Valitse päivämäärä';

  @override
  String get pickTime => 'Valitse aika';

  @override
  String get reminder => 'Sovelluksen sisäinen muistutus';

  @override
  String get reminderAtStart => 'Alkaessa';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min ennen';
  }

  @override
  String get reminderHourBefore => '1 tunti ennen';

  @override
  String get reminderDayBefore => '1 päivä ennen';

  @override
  String get markReminderHandled => 'Merkitse käsitellyksi';

  @override
  String get restoreReminder => 'Palauta sovelluksen sisäinen muistutus';

  @override
  String get reminderHandled =>
      'Sovelluksen sisäinen muistutus merkittiin käsitellyksi';

  @override
  String get reminderRestored => 'Sovelluksen sisäinen muistutus palautettiin';

  @override
  String get reminderUpcoming => 'Tulossa';

  @override
  String get reminderOverdue => 'Myöhässä';

  @override
  String get generalFitWeekColumnsToWidth => 'Sovita viikkonäkymä näytölle';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Näytä koko viikko tiiviissä asettelussa. Poista käytöstä vierittääksesi vaakasuunnassa. Yli 7 päivän mukautetut jaksot ovat edelleen vieritettäviä.';

  @override
  String get showWeekends => 'Näytä viikonloput';

  @override
  String get startHour => 'Alkutunti';

  @override
  String get endHour => 'Lopputunti';

  @override
  String get timeGridDensity => 'Aikaruudukon tiheys';

  @override
  String get timeGridHourHeight => 'Tuntirivin korkeus';

  @override
  String get timeGridHourHeightHint =>
      'Säätää päivä- ja viikkonäkymän pystysuuntaista mittakaavaa muuttamatta ruudukon 15, 30 tai 60 minuutin väliä.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Tuo JSON-tiedosto';

  @override
  String get pasteJson => 'Liitä JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Tuo kategoriat kopioidusta JSON-tekstistä';

  @override
  String get importIcsFile => 'Tuo ICS-tiedosto';

  @override
  String get importIcsFileDesc => 'Lue tapahtumat .ics-kalenteritiedostosta';

  @override
  String get pasteIcs => 'Liitä ICS';

  @override
  String get pasteIcsDesc => 'Tuo tapahtumat kopioidusta kalenteritekstistä';

  @override
  String get copyJson => 'Kopioi JSON';

  @override
  String get copyJsonDesc => 'Kopioi valitut kategoriat JSON-tekstinä';

  @override
  String get shareIcs => 'Jaa ICS';

  @override
  String get shareIcsDesc => 'Jaa valitut kalenterit .ics-tiedostona';

  @override
  String get saveIcs => 'Tallenna ICS';

  @override
  String get saveIcsDesc => 'Tallenna valitut kalenterit .ics-tiedostona';

  @override
  String get copyIcs => 'Kopioi ICS';

  @override
  String get copyIcsDesc => 'Kopioi valitut kalenterit ICS-tekstinä';

  @override
  String get importIcs => 'Tuo ICS';

  @override
  String get icsContent => 'ICS-sisältö';

  @override
  String get pasteIcsContentHint => 'Liitä BEGIN:VCALENDAR-sisältö tähän';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Löytyi $count tapahtumaa. Lisätäänkö ne uutena kategoriana vai korvataanko olemassa oleva kategoria?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Tuotiin $count kategoriaa. Varoituksia: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Tapahtuma ohitettiin, koska siltä puuttui alkuaika.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Tapahtuma ohitettiin, koska sen alkuaikaa ei tueta.';

  @override
  String get importWarningAdjustedEnd =>
      'Muokattiin tapahtumaa, jonka loppuaika ei ollut alkuajan jälkeen.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'ICS-kentät, joita ei tueta, lisättiin muistiinpanoihin: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Ohitettiin toistoväli, jota ei tueta: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Valitse ICS-muodossa kopioitavat kalenterit';

  @override
  String get selectCalendarsToExportIcs =>
      'Valitse ICS-muodossa vietävät kalenterit';

  @override
  String get exportIcsText => 'Vie ICS-teksti';

  @override
  String get exportJsonText => 'Vie JSON-teksti';

  @override
  String get dataRestoredFromBackupNotice =>
      'Sovelluksen tiedot palautettiin edellisestä varmuuskopiosta, koska päätiedostoa ei voitu ladata.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Sekä päätiedosto että sen varmuuskopio ovat vaurioituneet. Sovellus käyttää nyt uusia tietoja.';

  @override
  String get dataRecoveryCorruptTitle => 'Tietosi on palautettava';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked ei voinut lukea päätiedostoa tai sen varmuuskopiota. Suojatut kopiot luotiin ennen kirjoittamisen estämistä.';

  @override
  String get dataRecoveryIoFailureTitle => 'Tallennustila ei ole käytettävissä';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked ei pääse paikalliseen tallennustilaan juuri nyt. Tarkista tallennustilan käyttöoikeus tai laitteen saatavuus ja yritä uudelleen. Nykyisiä tietoja ei korvata.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Päivitä Sked näiden tietojen avaamiseksi';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Nämä tiedot on luotu Skedin uudemmalla versiolla. Päivitä sovellus ennen kuin yrität uudelleen. Uusilla tiedoilla aloittaminen on estetty tietojen suojaamiseksi.';

  @override
  String get dataRecoveryRetryAction => 'Yritä uudelleen';

  @override
  String get dataRecoveryArtifactsHint =>
      'Palautustiedostot tai kyseiset tallennussijainnit luetellaan alla. Älä muuta tiedostoja ennen tietojesi palauttamista.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Näytä palautustiedostot ja sijainnit';

  @override
  String get dataRecoveryStartFreshAction => 'Aloita uusilla tiedoilla';

  @override
  String get dataRecoveryStartFreshConfirmTitle =>
      'Aloitetaanko uusilla tiedoilla?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Suojatut kopiot säilytetään, mutta Sked luo uuden paikallisen tietotiedoston. Jatka vain, jos et halua ensin yrittää palautusta uudelleen.';

  @override
  String get previousMonth => 'Edellinen kuukausi';

  @override
  String get nextMonth => 'Seuraava kuukausi';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Käynnissä';

  @override
  String get deleteCourseTitle => 'Poista kurssi';

  @override
  String get deleteCourseMessage => 'Poistetaanko tämä kurssi?';

  @override
  String get showLunarCalendar => 'Näytä kuukalenteri';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, $count tapahtumaa';
  }

  @override
  String get defaultView => 'Oletusnäkymä';

  @override
  String get generalDefaultViewSection => 'Käynnistettäessä';

  @override
  String get generalViewSwitchBehavior => 'Näkymän vaihtopainike';

  @override
  String get settingsWorkspaceMode => 'Aktiivinen työtila';

  @override
  String get hideHomeWorkspaceNavigation => 'Piilota työtilojen navigointi';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Piilota työtilojen navigointi. Voit edelleen vaihtaa työtilaa päänäkymän työtilavalikosta.';

  @override
  String get generalDateLabelFormat => 'Päivämääräotsikon muoto';

  @override
  String get generalDateLabelFormatLocalized => 'Paikallinen (heinäkuu 2026)';

  @override
  String get generalDateLabelFormatSlash => 'Vinoviiva (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Työkalupalkin asettelu';

  @override
  String get toolbarNavigationSection => 'Työkalupalkin navigointi';

  @override
  String get toolbarNavigationHiddenBehavior => 'Piilotetut kohteet';

  @override
  String get toolbarNavigationRemove => 'Piilota kokonaan';

  @override
  String get toolbarNavigationMore => 'Siirrä Lisää-valikkoon';

  @override
  String get toolbarNavigationReorder => 'Järjestä työkalupalkin kohteet';

  @override
  String get toolbarNavigationVisibility => 'Näytä työkalupalkin kohde';

  @override
  String get toolbarNavigationTimetable => 'Lukujärjestyksen valitsin';

  @override
  String get toolbarNavigationWeek => 'Viikon valitsin';

  @override
  String get toolbarNavigationView => 'Näkymän vaihto';

  @override
  String get toolbarNavigationCategory => 'Kategorian valitsin';

  @override
  String get toolbarNavigationDate => 'Päivämäärän valitsin';

  @override
  String get generalToolbarWidthPolicy => 'Työkalupalkin tilanjako';

  @override
  String get generalToolbarWidthContent => 'Automaattinen jako';

  @override
  String get generalToolbarWidthBalanced => 'Tasainen jako';

  @override
  String get generalToolbarWidthCalendarPriority => 'Kategoria etusijalla';

  @override
  String get generalToolbarWidthDatePriority => 'Päivämäärä etusijalla';

  @override
  String get generalViewSwitchCycle => 'Kierrä näkymiä';

  @override
  String get generalViewSwitchMenu => 'Avaa näkymävalikko';

  @override
  String get generalViewSwitchTooltip => 'Vaihda näkymää';

  @override
  String get generalViewSwitchMenuTooltip => 'Valitse näkymä';

  @override
  String get generalViewLongPressTodayHint =>
      'Siirry tähän päivään painamalla pitkään';

  @override
  String get generalScheduleDisplaySection => 'Aikataulun näyttö';

  @override
  String get generalTimeGridSection => 'Aikaruudukko';

  @override
  String get generalPopupSection => 'Ponnahdusikkunan toiminta';

  @override
  String get quickActionsSection => 'Pikatoiminnot';

  @override
  String get showAddCourseFab => 'Näytä kelluva kurssin lisäyspainike';

  @override
  String get showAddCourseFabHint =>
      'Näytä tai piilota kelluva kurssin lisäyspainike lukujärjestyksen oikeassa alakulmassa.';

  @override
  String get showAddEventFab => 'Näytä kelluva tapahtuman lisäyspainike';

  @override
  String get showAddEventFabHint =>
      'Näytä tai piilota kelluva tapahtuman lisäyspainike aikataulun oikeassa alakulmassa.';

  @override
  String get enableLongPressAddCourse =>
      'Lisää kurssi painamalla tyhjää ruudukkoa pitkään';

  @override
  String get enableLongPressAddCourseHint =>
      'Lisää kurssi painamalla pitkään lukujärjestyksen ruudukon tyhjää aluetta.';

  @override
  String get enableLongPressAddEvent =>
      'Lisää tapahtuma painamalla tyhjää ruudukkoa pitkään';

  @override
  String get enableLongPressAddEventHint =>
      'Lisää tapahtuma painamalla päivä- tai viikkonäkymässä pitkään aikaruudukon tyhjää aluetta.';

  @override
  String get developerModeTitle => 'Kehittäjätila';

  @override
  String get developerModeDescription =>
      'Työkalut kattavien esimerkkitietojen lisäämiseen ulkoasun ja käytön tarkistamista varten.';

  @override
  String get developerSampleLanguage => 'Esimerkkitietojen kieli';

  @override
  String get developerSampleChinese => 'Kiina';

  @override
  String get developerSampleEnglish => 'Englanti';

  @override
  String get developerSampleDataDescription =>
      'Lisää yhden lukujärjestyksen sekä kategorioita ja tapahtumia korvaamatta nykyisiä tietoja.';

  @override
  String get developerAddSampleData => 'Lisää esimerkkitiedot';

  @override
  String get developerSampleDataAdded =>
      'Esimerkkilukujärjestys ja tapahtumat lisättiin.';

  @override
  String get developerModeLongPressHint =>
      'Avaa kehittäjätila painamalla 3 sekunnin ajan';

  @override
  String get developerNotificationDiagnostics => 'Ilmoitusten diagnostiikka';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Tarkista Androidin ilmoitusten toimitustila, luo nykyinen muistutussuunnitelma uudelleen ja lähetä turvallisia testi-ilmoituksia Skedin tavallisen ilmoituspalvelun kautta.';

  @override
  String get developerNotificationUnsupported =>
      'Ilmoitusten diagnostiikka on käytettävissä vain Androidissa.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Ilmoitusten diagnostiikka on käytettävissä, kun aikataulun koordinaattori on käynnistynyt.';

  @override
  String get developerNotificationRefresh => 'Päivitä diagnostiikka';

  @override
  String get developerNotificationSystemStatus => 'Järjestelmän ilmoituslupa';

  @override
  String get developerNotificationPermissionAllowed => 'Sallittu';

  @override
  String get developerNotificationPermissionBlocked => 'Estetty';

  @override
  String get developerNotificationExactAlarm => 'Tarkat hälytykset';

  @override
  String get developerNotificationExactAlarmAllowed => 'Sallittu';

  @override
  String get developerNotificationExactAlarmBlocked => 'Ei sallittu';

  @override
  String get developerNotificationPlan => 'Aikataulun ilmoitussuunnitelma';

  @override
  String get developerNotificationCoverage => 'Muistutusten kattavuus';

  @override
  String get developerNotificationCoverageReady =>
      'Kaikki tiedossa olevat muistutukset, joiden toistomäärä on rajallinen, on ajastettu suoraan';

  @override
  String get developerNotificationCoverageRenewable =>
      'Toistuvien muistutusten ajastusta pyritään uusimaan pitkäaikaisen kattavuuden säilyttämiseksi';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Suoran ajastuksen raja on täynnä. Myöhempien muistutusten ajastusta pyritään uusimaan';

  @override
  String get developerNotificationCoverageBlocked =>
      'Tarkan toimituksen vaatimukset eivät täyty';

  @override
  String get developerNotificationCoverageFailed =>
      'Viimeisin muistutusten synkronointi epäonnistui';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return '$scheduled suoraan ajastettua hälytystä / raja $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return '$scheduled ajastettu, $planned suunniteltu';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Viimeisin virhe: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Luo ilmoitussuunnitelma uudelleen';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Ilmoitussuunnitelma luotiin uudelleen.';

  @override
  String get developerNotificationTestChannel => 'Testikanava';

  @override
  String get developerNotificationTestCourse => 'Kurssien muistutukset';

  @override
  String get developerNotificationTestSchedule => 'Aikataulun muistutukset';

  @override
  String get developerNotificationImmediateTest => 'Lähetä testi-ilmoitus heti';

  @override
  String get developerNotificationThirtySecondTest =>
      'Ajasta taustatesti 30 sekunnin päähän';

  @override
  String get developerNotificationImmediateQueued =>
      'Välitön testi-ilmoitus lähetettiin.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Taustatesti ajastettiin 30 sekunnin päähän.';

  @override
  String get developerNotificationAppSwitch => 'Sovelluksen muistutuskytkin';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Tavalliset muistutukset ovat käytössä';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Tavalliset muistutukset on poistettu käytöstä. Kehittäjätestit voidaan silti suorittaa';

  @override
  String get developerNotificationTimeZone => 'Paikallinen aikavyöhyke';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Ei vielä luotu. Kehittäjätesti luo sen.';

  @override
  String get developerNotificationChannelEnabledState => 'Käytössä';

  @override
  String get developerNotificationChannelBlockedState => 'Estetty';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Tärkeys: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Tärkeys ei ole saatavilla';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return '$pending odottaa / $active aktiivista';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Järjestelmä näytti viimeksi: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Uudelleenlaskentaa ei ole vielä kirjattu.';

  @override
  String get developerNotificationNextReminder =>
      'Seuraava tavallinen muistutus';

  @override
  String get developerNotificationNoPendingReminder =>
      'Nykyisessä suunnitelmassa ei ole tulevia muistutuksia';

  @override
  String get developerNotificationNextMaintenance => 'Seuraava ylläpito';

  @override
  String get developerNotificationNextRenewal =>
      'Seuraava ajastuksen uusimisyritys';

  @override
  String get developerNotificationNoMaintenance => 'Ei ajastettu';

  @override
  String get developerNotificationTruncation => 'Suunnitelman rajaus';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Suunnitelman rajan vuoksi jätettiin pois $count';
  }

  @override
  String get developerNotificationLastReconciliation =>
      'Viimeisin uudelleenlaskenta';

  @override
  String get developerNotificationLastSynchronization =>
      'Viimeisin muistutusten synkronointi';

  @override
  String get developerNotificationLateRecovery =>
      'Myöhästyneiden muistutusten palautus';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return '$count muistutusta palautettiin ja toimitettiin alkuperäisen ajankohdan jälkeen';
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
  String get developerNotificationReconcileOriginForeground => 'Etuala';

  @override
  String get developerNotificationReconcileOriginBackground => 'Tausta';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Täysi uudelleenlaskenta';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Ylläpito';

  @override
  String get developerNotificationReconcileModeRecovery => 'Palautus';

  @override
  String get developerNotificationRunRecovery =>
      'Suorita muistutusten palautus';

  @override
  String get developerNotificationRecoveryComplete =>
      'Muistutusten palautus valmistui';

  @override
  String get developerNotificationReconcileResultSuccess => 'Onnistui';

  @override
  String get developerNotificationReconcileResultSkipped => 'Ohitettu';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Ajastaminen on estetty, kunnes kaikki tarkan toimituksen ehdot täyttyvät';

  @override
  String get developerNotificationReconcileResultFailed => 'Epäonnistui';

  @override
  String get developerNotificationBackgroundLimits =>
      'Valmistajan taustarajoitukset';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Valmistajan taustarajoitukset voivat vaikuttaa toimitukseen.';

  @override
  String get developerNotificationAutostart => 'Valmistajan taustakäynnistys';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Valmistaja: $vendor. Valmistajan asetuksiin on saatavilla linkki. Android ei pysty näyttämään tämän luvan tilaa.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Valmistaja: $vendor. Käytetään sovelluksen tietosivua. Android ei pysty näyttämään tämän luvan tilaa.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Valmistajan tausta-asetuksiin ei ole saatavilla linkkiä.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Viimeksi avattu kohde: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor =>
      'valmistajan asetukset';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'sovelluksen tiedot';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'ei mitään';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Uudelleenkäynnistyksen jälkeisen palautuksen rajoitukset';

  @override
  String get developerNotificationRebootBoundary =>
      'Palautus alkaa ensimmäisen lukituksen avauksen jälkeen. Pakotetusti pysäytetty sovellus ei voi käynnistyä itsestään.';

  @override
  String get developerNotificationTestChecking =>
      'Testit eivät ole käytettävissä ilmoitusten tilan tarkistuksen aikana.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Testit eivät ole käytettävissä, koska järjestelmän ilmoitukset on estetty.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Testit eivät ole käytettävissä, koska valittu ilmoituskanava on estetty.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Hallitaan Windowsin ilmoitusasetuksissa';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Ei koske Windowsia';

  @override
  String get developerNotificationWindowsIdentity =>
      'Windows-paketin identiteetti';

  @override
  String get developerNotificationWindowsMsixReady =>
      'MSIX-identiteetti on käytettävissä. Näkyvät ilmoitukset voidaan poistaa';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Asenna MSIX-versio, jotta näkyvät ilmoitukset voidaan poistaa luotettavasti';

  @override
  String get collapseWorkspaceNavigation => 'Tiivistä työtilan navigointi';

  @override
  String get expandWorkspaceNavigation => 'Laajenna työtilan navigointi';

  @override
  String get schoolWebImportExitBrowser => 'Poistu sisäisestä selaimesta';

  @override
  String get schoolWebImportEditAddress => 'Muokkaa osoitetta';

  @override
  String get schoolWebImportAddressLabel => 'Verkko-osoite';

  @override
  String get schoolWebImportOpenAddress => 'Avaa';

  @override
  String get schoolWebImportAddressInvalid =>
      'Anna HTTP- tai HTTPS-osoite isäntänimellä.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Tämä verkkosivu pyysi uutta ikkunaa, jota ei voi avata tällä laitteella.';

  @override
  String get schoolWebImportSecureConnection => 'Suojattu yhteys';

  @override
  String get schoolWebImportInsecureConnection => 'Suojaamaton yhteys';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Avataanko koulun kirjautuminen?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Koulun kirjautuminen voi lähettää tunnistetietoja lomakkeiden tai palvelimen uudelleenohjausten kautta koululle ja sen kirjautumispalvelujen tarjoajille. Android ei voi keskeyttää jokaista tällaista siirtoa erillistä kohteen vahvistusta varten. Jatka vain, jos luotat niihin tämän tuonti-istunnon ajan:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Avataanko suojaamaton koulukirjautuminen?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Tämä koulukirjautuminen käyttää HTTP-yhteyttä. Kuka tahansa yhteyttä tarkkaileva tai muuttava voi lukea tai muuttaa kirjautumistietojasi ja sivun sisältöä. Jatka vain, jos hyväksyt tämän riskin kohteelle:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Muistutukset ja ilmoitukset';

  @override
  String get notificationCoverage => 'Muistutusten kattavuus';

  @override
  String get notificationCoverageRenewable =>
      'Ilman päättymispäivää toistuvien tapahtumien ajastusta uusitaan taustalla pitkäaikaisen kattavuuden säilyttämiseksi.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android voi ajastaa suoraan enintään $capacity muistutusta. Myöhempien muistutusten ajastusta pyritään uusimaan etukäteen.';
  }

  @override
  String get notificationSettingsEnabled =>
      'Ota muistutukset ja ilmoitukset käyttöön';

  @override
  String get notificationSettingsEnabledHint =>
      'Ilmoitukset ajastetaan vain kohteille, joille on asetettu muistutus. Määritä alla oletusmuistutus kursseille, jotka käyttävät sitä.';

  @override
  String get notificationPrecisionLimitations =>
      'Muistutukset riippuvat järjestelmän oikeuksista ja taustatoiminnoista. Sammutus, ajan muutokset tai järjestelmän rajoitukset voivat viivästyttää niitä.';

  @override
  String get notificationSettingsEnabledSummary => 'Käytössä';

  @override
  String get notificationSettingsDisabledSummary => 'Pois käytöstä';

  @override
  String get notificationDefaultsSection => 'Oletusmuistutukset';

  @override
  String get notificationCourseDefaultReminder => 'Kurssien oletusmuistutus';

  @override
  String get notificationGeneralDefaultReminder => 'Aikataulun oletusmuistutus';

  @override
  String get notificationReminderOff => 'Ei muistutusta';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes minuuttia ennen';
  }

  @override
  String get notificationPermission => 'Ilmoituslupa';

  @override
  String get notificationPermissionGranted => 'Järjestelmä on sallinut';

  @override
  String get notificationPermissionDenied => 'Järjestelmä on estänyt';

  @override
  String get notificationPermissionChecking => 'Tarkistetaan lupaa…';

  @override
  String get notificationPermissionRequest => 'Pyydä lupaa';

  @override
  String get notificationPermissionOpenSettings => 'Avaa järjestelmäasetukset';

  @override
  String get notificationPermissionRequestFailed =>
      'Ilmoituslupaa ei voitu lukea. Yritä uudelleen.';

  @override
  String get notificationExactAlarm => 'Tarkkojen hälytysten lupa';

  @override
  String get notificationExactAlarmAllowed => 'Järjestelmä on sallinut';

  @override
  String get notificationExactAlarmRequired =>
      'Tarvitaan muistutusten tarkkaan ajoitukseen';

  @override
  String get notificationExactAlarmRequest => 'Salli tarkat hälytykset';

  @override
  String get notificationBatteryOptimization => 'Akun optimointi';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Poikkeus Androidin akun optimoinnista on sallittu';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Tarkat muistutukset edellyttävät poikkeusta Androidin akun optimoinnista';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Avaa akun optimointiasetukset';

  @override
  String get notificationAutostart => 'Valmistajan taustakäynnistys';

  @override
  String get notificationAutostartVendorHint =>
      'Salli automaattinen käynnistys tai taustalla toimiminen, jotta muistutukset voidaan palauttaa uudelleenkäynnistyksen jälkeen.';

  @override
  String get notificationAutostartFallbackHint =>
      'Avaa Skedin sovellustiedot ja salli taustalla toimiminen. Android ei voi tarkistaa tätä valmistajan asetusta.';

  @override
  String get notificationAutostartUnavailable =>
      'Valmistajan asetussivua ei löytynyt. Tarkista Skedin sovellustiedot käsin.';

  @override
  String get notificationAutostartRequest =>
      'Avaa valmistajan tausta-asetukset';

  @override
  String get notificationAutostartOpenFailed =>
      'Valmistajan tausta-asetuksia ei voitu avata. Tarkista Skedin sovellustiedot käsin.';

  @override
  String get notificationLockScreenTitles => 'Näytä otsikot lukitusnäytöllä';

  @override
  String get notificationLockScreenTitlesHint =>
      'Kun asetus on pois käytöstä, ilmoitusten yksityiskohdat piilotetaan lukitusnäytöllä.';

  @override
  String get notificationWidgets => 'Aloitusnäytön widgetit';

  @override
  String get notificationWidgetsDesc =>
      'Päivitä Skedin widgetit ja katso, miten voit lisätä widgetin aloitusnäytölle.';

  @override
  String get notificationWidgetsDialogTitle => 'Lisää Sked-widget';

  @override
  String get notificationWidgetsDialogMessage =>
      'Paina laitteen aloitusnäytön tyhjää aluetta pitkään, valitse Widgetit ja lisää Sked-widget. Widget näyttää seuraavat kurssisi tai tapahtumasi.';

  @override
  String get notificationWidgetsRefresh => 'Päivitä widgetit';

  @override
  String get notificationWidgetsRefreshed => 'Widgetit päivitettiin';

  @override
  String get notificationPlatformUnsupported =>
      'Tämä alusta ei tue järjestelmäilmoituksia.';

  @override
  String get workspaceFeatures => 'Toimintojen hallinta';

  @override
  String get workspaceBoth => 'Lukujärjestys ja kalenteri';

  @override
  String get workspaceOnlyStudent => 'Vain lukujärjestys';

  @override
  String get workspaceOnlyGeneral => 'Vain kalenteri';

  @override
  String get workspaceDisableTitle => 'Poistetaanko tämä työtila käytöstä?';

  @override
  String get workspaceDisableMessage =>
      'Tiedot ja asetukset säilytetään. Toiminnot ja muistutukset pysäytetään, kunnes otat työtilan uudelleen käyttöön täällä.';

  @override
  String get workspaceEnableHint =>
      'Valitse käyttämäsi toiminnot. Vähintään yhden on oltava käytössä.';

  @override
  String get workspaceLastRequired =>
      'Vähintään yhden työtilan on oltava käytössä.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Työtila on poistettu käytöstä, mutta muistutuksia ei voitu poistaa. Yritä ilmoitusten palautusta uudelleen.';

  @override
  String get settingsSearch => 'Hae asetuksia';

  @override
  String get settingsNoResults => 'Vastaavia asetuksia ei löytynyt';

  @override
  String get settingsDataPrivacy => 'Tiedot ja tietosuoja';

  @override
  String get workspacePreferences => 'Näyttö ja käyttö';

  @override
  String get workspaceManage => 'Hallitse';

  @override
  String get selectedDayAgenda => 'Valittu päivä';

  @override
  String get notificationTroubleshooting => 'Käyttöoikeudet ja vianmääritys';

  @override
  String get settingsConnection => 'Yhteys';

  @override
  String get settingsAdvanced => 'Lisäasetukset';

  @override
  String get unsavedChangesMessage =>
      'Sinulla on tallentamattomia muutoksia. Hylätäänkö ne ja poistutaan?';

  @override
  String get backupWorkspaceSelection =>
      'Täysi varmuuskopio sisältää tiedot ja käytössä olevien työtilojen valinnan.';

  @override
  String get assistantLayoutPreview => 'AI · Asettelun esikatselu';

  @override
  String get assistantSelectionContext =>
      'Käyttää nykyistä valintaa kontekstina';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Viestiluonnos';

  @override
  String get assistantPreviewNoSend =>
      'Vain asettelun esikatselu. Mitään ei lähetetä tai muuteta.';

  @override
  String get resizePanel => 'Muuta paneelin kokoa';

  @override
  String get minimizeWindow => 'Pienennä';

  @override
  String get maximizeWindow => 'Suurenna';

  @override
  String get restoreWindow => 'Palauta ikkuna';

  @override
  String get closeWindow => 'Sulje ikkuna';

  @override
  String get courseSystemReminder => 'Järjestelmämuistutus';

  @override
  String courseReminderInherit(String reminder) {
    return 'Käytä oletusta ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Järjestelmämuistutukset on poistettu käytöstä ilmoitusasetuksissa. Tämän kurssin asetus voidaan silti tallentaa.';

  @override
  String get courseReminderDefaultOff =>
      'Kurssien oletusmuistutusta ei ole asetettu. Valitse tässä mukautettu muistutus tai määritä oletus ilmoitusasetuksissa.';

  @override
  String get courseReminderDeliveryHint =>
      'Tämä asetus tallennetaan kurssin mukana. Toimitus riippuu järjestelmän ilmoitusluvista ja taustarajoituksista.';

  @override
  String get courseReminderPermissionUnknown =>
      'Järjestelmän ilmoitusten tilaa ei ole tarkistettu. Tarkista ilmoitusasetukset ennen kuin luotat muistutuksiin.';

  @override
  String get courseReminderMinutesLabel => 'Minuuttia ennen oppituntia';

  @override
  String get exportAction => 'Vie';

  @override
  String get datePickerSelectWeek => 'Valitse viikko';

  @override
  String get datePickerSelectMonth => 'Valitse kuukausi';

  @override
  String get generalDateLabelFormatDescription =>
      'Koskee päivämääränavigointia tietokoneilla ja pienillä näytöillä.';

  @override
  String get dateRangeTitle => 'Valitse päivämääräväli';

  @override
  String get dateRangeCustom => 'Mukautettu';

  @override
  String get dateRangeChooseStart => 'Valitse aloituspäivä';

  @override
  String get dateRangeChooseEnd => 'Valitse lopetuspäivä';

  @override
  String get dateRangeLimit =>
      'Valitse 1–14 päivää, alku- ja loppupäivä mukaan lukien.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days päivää',
      one: '1 päivä',
    );
    return 'Mukautettu · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Valitse vierityspyörillä';

  @override
  String get courseReminderUseDefault => 'Käytä oletusta';

  @override
  String get courseReminderInvalidMinutes =>
      'Anna minuuttimääräksi kokonaisluku, joka on nolla tai suurempi.';

  @override
  String get generalCustomColumnWidth => 'Mukautetun näkymän sarakeleveys';

  @override
  String get generalCustomColumnWidthAuto => 'Automaattinen';

  @override
  String get generalCustomColumnWidthManual => 'Vähimmäisleveys';

  @override
  String get generalCustomColumnWidthMinimum =>
      'Päiväsarakkeen vähimmäisleveys';

  @override
  String get generalCustomColumnWidthHint =>
      'Kaikilla päivämäärillä on sama vähimmäisleveys. Sarakkeet täyttävät käytettävissä olevan tilan tai niitä voi vierittää sivusuunnassa. Vaikuttaa vain mukautettuun näkymään.';

  @override
  String get settingsAppearanceLanguage => 'Ulkoasu ja kieli';

  @override
  String get settingsAppearanceDetails => 'Värit ja ääriviivat';

  @override
  String get monthNoEvents => 'Ei tapahtumia tänä päivänä';

  @override
  String get settingsOverview => 'Yleiskatsaus';

  @override
  String get settingsThemeTarget => 'Teeman kohde';

  @override
  String get settingsColorMode => 'Väritila';

  @override
  String get settingsNotificationPreferences => 'Muistutusasetukset';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Oletusmuistutukset, luvat ja luotettavuus';

  @override
  String get settingsFeaturesSummary => 'Työtilat ja navigointi';

  @override
  String get settingsPrivacySummary =>
      'Tietosuojakäytäntö ja paikallisten tietojen tyhjennys';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oppituntia',
      one: '1 oppitunti',
    );
    return '$_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Oppitunti';

  @override
  String get periodTimesDurationColumn => 'Kesto';

  @override
  String get periodTimesGapColumn => 'Välitunti';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Odotetaan tallennusta…';

  @override
  String get periodTimesSaveFailed => 'Tallentamatta · Tallennus epäonnistui';

  @override
  String get periodTimesInvalidStatus =>
      'Tallentamatta · Korjaa korostetut ajat';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked ei voinut vahvistaa, peruttiinko viimeisin tallennus. Kirjoittaminen on keskeytetty ja palautuskopiot säilytetty. Tarkista tallennustila ja yritä lataamista uudelleen.';

  @override
  String get settingsPanelDisplayMode => 'Paneelien näyttötapa';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Yhteinen lukujärjestyksille ja kalentereille';

  @override
  String get settingsPanelDisplayOverlay => 'Päällekkäin';

  @override
  String get settingsPanelDisplaySideBySide => 'Vierekkäin';

  @override
  String get settingsPanelDisplayAutomatic => 'Automaattinen';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Näyttää paneelin oikealla kalenterin päällä muuttamatta sen leveyttä.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Suosii vierekkäistä näkymää; näyttää päällekkäin vain, jos kalenteri kapenee liikaa.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Näyttää vierekkäin, jos kalenteri säilyy luettavana, muuten päällekkäin.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Asetukset- tai Työtila-kohteen poistaminen käytöstä työkalupalkissa siirtää sen Lisää-valikkoon poistamisen sijaan. Lisää-valikkoa ei voi piilottaa, kun se sisältää välttämättömiä toimintoja. Työtilan vaihto näkyy vain, kun alanavigointi on piilotettu ja käytössä on useita työtiloja.';

  @override
  String get reminderEnded => 'Päättynyt';

  @override
  String get reminderAutoCloseHint =>
      'Sulkeutuu 10 sekunnin kuluttua. Käytä paneelia pitääksesi sen avoinna.';

  @override
  String get showReminderIndependently => 'Avaa erikseen';

  @override
  String get categoryManagerTitle => 'Hallitse kategorioita';

  @override
  String get categoryHidden => 'Piilotettu';

  @override
  String get categoryShowOnCalendar => 'Näytä kalenterissa';

  @override
  String get categoryHideOnCalendar => 'Piilota kalenterista';

  @override
  String get categoryEditColor => 'Vaihda kategorian väriä';

  @override
  String get categoryThemePalette => 'Teeman väripaletti';

  @override
  String get categoryCustomColor => 'Mukautettu';

  @override
  String get colorHexInvalid => 'Anna kuusimerkkinen heksadesimaalivärikoodi.';

  @override
  String categoryColorSlot(int number) {
    return 'Teeman väri $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Kaupan päivitykset voivat viivästyä. Saatavuus määräytyy kaupan sivun mukaan.';

  @override
  String get storePrereleaseNotice =>
      'Esiversioiden päivitysilmoitusten vastaanottaminen ei liitä sinua kaupan testiohjelmaan.';

  @override
  String get updateFoundTitle => 'Uusi versio on saatavilla';

  @override
  String get updateNoNotes => 'Julkaisutietoja ei ole annettu.';

  @override
  String get updateLater => 'Myöhemmin';

  @override
  String get updateRetry => 'Yritä uudelleen';

  @override
  String get updatePrerelease => 'Esiversio';

  @override
  String get updateNetworkFailure =>
      'Päivitysten tarkistaminen epäonnistui. Tarkista yhteys ja yritä uudelleen.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Uudempaa versiota ei löytynyt (nykyinen: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Palautetaan varmuuskopiota…';

  @override
  String get backupRestoreInProgressMessage =>
      'Tietoja ja asetuksia voi muuttaa palautuksen valmistuttua. Voit edelleen tarkastella niitä.';
}
