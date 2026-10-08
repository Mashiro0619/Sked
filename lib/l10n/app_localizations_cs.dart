// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Sked';

  @override
  String weekLabel(int week) {
    return 'Týden $week';
  }

  @override
  String get addCourse => 'Přidat kurz';

  @override
  String get settings => 'Nastavení';

  @override
  String get multiTimetableSwitch => 'Přepnout rozvrhy';

  @override
  String currentTimetableWeeks(int weeks) {
    return 'Aktuální jízdní řád · $weeks týdny';
  }

  @override
  String tapToSwitchWeeks(int weeks) {
    return 'Klepnutím přepněte · $weeks týdny';
  }

  @override
  String get editTimetable => 'Upravit rozvrh';

  @override
  String get schoolImportResultEditorTitle => 'Upravit výsledek analýzy';

  @override
  String get schoolImportParsePageTitle => 'Analyzovat rozvrh';

  @override
  String get schoolImportParsePageParsing => 'Analyzování…';

  @override
  String get schoolImportParsePageFailed => 'Analýza se nezdařila';

  @override
  String get schoolImportParsePageComplete => 'Analýza dokončena';

  @override
  String get schoolImportParsePageContinue => 'Pokračovat';

  @override
  String get schoolImportParsePageRawContent => 'Nezpracovaná odpověď';

  @override
  String get schoolImportParsePageExpandRaw => 'Rozbalit nezpracovanou odpověď';

  @override
  String get schoolImportParsePageCollapseRaw => 'Sbalit nezpracovanou odpověď';

  @override
  String get schoolImportExpandWarnings => 'Rozbalit upozornění k importu';

  @override
  String get schoolImportCollapseWarnings => 'Sbalit upozornění k importu';

  @override
  String schoolImportTotalWeeksTooShort(int week) {
    return 'Některé kurzy pokračují až do $week. týdne.';
  }

  @override
  String get replaceCurrentTimetableConfirmTitle => 'Nahradit aktuální rozvrh?';

  @override
  String get replaceCurrentTimetableConfirmMessage =>
      'Importovaný rozvrh nahradí aktuální rozvrh.';

  @override
  String get createTimetable => 'Nový rozvrh';

  @override
  String get jumpToWeek => 'Skočit na týden';

  @override
  String get timetable => 'Rozvrh';

  @override
  String get themeWorkspaceSchedule => 'Plán';

  @override
  String get timetableName => 'Název jízdního řádu';

  @override
  String get timetableNameRequired => 'Zadejte název rozvrhu';

  @override
  String get totalWeeks => 'Celkem týdny';

  @override
  String get delete => 'Odstranit';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get deleteTimetableTitle => 'Smazat rozvrh';

  @override
  String deleteTimetableMessage(Object name) {
    return 'Smazat \"$name\"?';
  }

  @override
  String get noTimetableTitle => 'Zatím žádný časový rozvrh';

  @override
  String get noTimetableMessage =>
      'Vytvořte plán nebo importujte z souboru JSON.';

  @override
  String get importTimetable => 'Importovat rozvrh';

  @override
  String get courseName => 'Název kurzu';

  @override
  String get location => 'Umístění';

  @override
  String get dayOfWeek => 'Den';

  @override
  String get semesterWeeks => 'Týdny';

  @override
  String get startTime => 'Čas zahájení';

  @override
  String get endTime => 'Konečný čas';

  @override
  String get linkedPeriods => 'Související období';

  @override
  String get linkedPeriodsUnmatched =>
      'Žádné období není odpovídající aktuálnímu času. Klepnutím vyberte ručně.';

  @override
  String periodRangeLabel(int start, int end) {
    return 'Období $start-$end';
  }

  @override
  String get teacherName => 'Učitel';

  @override
  String get credits => 'Kredity';

  @override
  String get remarks => 'Poznámky';

  @override
  String get customFields => 'Vlastní pole';

  @override
  String get customFieldsHint => 'Jeden na řádek, formát: klíč:hodnota';

  @override
  String get more => 'Další';

  @override
  String get selectDayOfWeek => 'Vyberte si den';

  @override
  String get selectSemesterWeeks => 'Vyberte si týdny';

  @override
  String get selectAll => 'Vyberte všechny';

  @override
  String get clear => 'Vymazat';

  @override
  String get confirm => 'Potvrdit';

  @override
  String get selectLinkedPeriods => 'Vyberte propojená období';

  @override
  String get addCourseTitle => 'Přidat kurz';

  @override
  String get editCourseTitle => 'Upravit kurz';

  @override
  String get editCourseTooltip => 'Upravit kurz';

  @override
  String get place => 'Umístění';

  @override
  String get time => 'Čas';

  @override
  String get notFilled => 'Neplněno';

  @override
  String get none => 'Žádný';

  @override
  String get conflictCourses => 'Konfliktní kurzy';

  @override
  String get locationNotFilled => 'Umístění není vyplněno';

  @override
  String get setAsDisplayed => 'Nastavit jako zobrazené';

  @override
  String get editThisCourse => 'Upravit tento kurz';

  @override
  String get settingsTitle => 'Nastavení';

  @override
  String get settingsSectionTimetable => 'Rozvrh';

  @override
  String get settingsSectionGeneralSchedule => 'Obecný plán';

  @override
  String get settingsSectionAppearance => 'Vzhled';

  @override
  String get settingsSectionApp => 'Aplikace';

  @override
  String get settingsSectionWorkspace => 'Pracovní prostor';

  @override
  String get settingsSectionAppearanceLanguage => 'Vzhled a jazyk';

  @override
  String get settingsSectionDataSecurity => 'Data a zabezpečení';

  @override
  String get settingsSectionAbout => 'O aplikaci Sked';

  @override
  String get noTimetableSettings =>
      'V současné době není k dispozici žádný časový rozvrh pro nastavení.';

  @override
  String get semesterStartDate => 'Datum zahájení semestru';

  @override
  String get periodTimeSets => 'Nastavení časového období';

  @override
  String get noPeriodTimeAvailable => 'Není nastaven žádný čas';

  @override
  String periodTimeSetSummary(Object name, int count) {
    return ' $name · $count období';
  }

  @override
  String get coursePopupDismissSetting =>
      'Povolit vnější klepnutí pro zavření vyskakovacího okna kurzu';

  @override
  String get coursePopupDismissSettingHint =>
      'Vypnutí této funkce také zakáže propuštění posunutím dolů.';

  @override
  String get preserveTimetableGaps => 'Zachování mezer v rozvrhu';

  @override
  String get preserveTimetableGapsHint =>
      'Když je volno, oběd a přestávka mezery se zhroutí, takže pozdější třídy pohybovat nahoru.';

  @override
  String get showPastEndedCourses => 'Zobrazit minulé kurzy';

  @override
  String get showPastEndedCoursesHint =>
      'Zobrazte kurzy, které již skončily skutečným aktuálním týdnem ve světlejším šedem stylu.';

  @override
  String get showFutureCourses => 'Zobrazit budoucí kurzy';

  @override
  String get showFutureCoursesHint =>
      'Zobrazit kurzy, které nejsou aktivní tento týden, ale budou se objevovat v následujících týdnech s šedým stylem.';

  @override
  String get timetableDisplaySettings => 'Zobrazení a interakce rozvrhu';

  @override
  String get timetableDisplaySettingsDesc =>
      'Zobrazení kurzů, rozložení, gesta pro týdny a rychlé přidání';

  @override
  String get showTimetableGridLines => 'Zobrazit řádky mřížky rozvrhu';

  @override
  String get showTimetableGridLinesHint =>
      'Ovládejte, zda jsou v rozvrhu viditelné vodorovné a svislé čáry mřížky.';

  @override
  String get timetableHorizontalLayoutSection => 'Vodorovné rozložení a gesta';

  @override
  String get fitDaySelectorToWidth => 'Přizpůsobit výběr dne obrazovce';

  @override
  String get fitDaySelectorToWidthHint =>
      'Pokud je to možné, zobrazí všech sedm dní na obrazovce. Vypnutím použijete pevnou šířku s posouváním.';

  @override
  String get fitWeekColumnsToWidth => 'Přizpůsobit sloupce týdne obrazovce';

  @override
  String get fitWeekColumnsToWidthHint =>
      'Pokud je to možné, zobrazí všech sedm sloupců rozvrhu na obrazovce. Vypnutím použijete pevnou šířku s posouváním.';

  @override
  String get enableWeekSwipeNavigation => 'Měnit týdny přejetím';

  @override
  String get enableWeekSwipeNavigationHint =>
      'Přejetím doleva nebo doprava přejdete na jiný týden. Při pevné šířce nejprve posuňte obsah až k okraji.';

  @override
  String get liveCourseOutlineColor => 'Barva obrysu kurzu';

  @override
  String get liveCourseOutlineColorHint =>
      'Zvolte, zda se obrysy zaměřují na aktuální/další kurz nebo na všechny kurzy zobrazené na aktuální stránce.';

  @override
  String get liveCourseOutlineSettings => 'Náčrt kurzu';

  @override
  String get liveCourseOutlineSettingsHint =>
      'Nastavte, zda je obris povolen, na co se zaměřuje, zda sleduje barvu tématu a efektivní barvu obrisu.';

  @override
  String get liveCourseOutlineEnabled => 'Povolit obrys';

  @override
  String get liveCourseOutlineFollowTheme => 'Sledujte barvu tématu';

  @override
  String get liveCourseOutlineTarget => 'Návrh cíle';

  @override
  String get liveCourseOutlineTargetCurrentOrNext => 'Aktuální/příští kurz';

  @override
  String get liveCourseOutlineTargetAllDisplayed => 'Všechny zobrazené kurzy';

  @override
  String get liveCourseOutlineEffectiveColor => 'Efektivní barva';

  @override
  String get liveCourseOutlineCustomColor => 'Vlastní barva obrysu';

  @override
  String get liveCourseOutlineWidth => 'Šířka obrysu';

  @override
  String get outlineWidthUnit => 'px';

  @override
  String get language => 'Jazyk';

  @override
  String get languagePageDescription =>
      'Vyberte si jeden z jazyků, který je opravdu k dispozici v aplikaci.';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'angličtina';

  @override
  String get githubRepositoryUrl => 'github.com/Mashiro0619/Sked';

  @override
  String get apiResponseTitle => 'Odpověď API';

  @override
  String get theme => 'Téma';

  @override
  String get themeFollowSystem => 'Sledujte systém';

  @override
  String get themeLight => 'Světlo';

  @override
  String get themeDark => 'Temná';

  @override
  String get themeColor => 'Barva tématu';

  @override
  String get themeColorModeSingle => 'Barva jednoho tématu';

  @override
  String get themeColorModeColorful => 'Barevné';

  @override
  String get themeColorUiColors => 'Barvy uživatelského rozhraní';

  @override
  String get themeColorCourseColors => 'Barvy kurzu';

  @override
  String get themeColorPrimary => 'Primární';

  @override
  String get themeColorSecondary => 'Sekundární';

  @override
  String get themeColorTertiary => 'Terciární';

  @override
  String get themeColorCourseText => 'Text kurzu';

  @override
  String get themeColorCourseTextAuto => 'automatické';

  @override
  String get themeColorCourseTextCustom => 'Vlastní barva';

  @override
  String get themeColorCourseColorsEmpty =>
      'Barvy kurzu budou generovány po importu rozvrhu.';

  @override
  String get themeCustomColor => 'Vlastní barva';

  @override
  String get themeApplyCustomColor => 'Použít barvu';

  @override
  String get themeApplySettings => 'Použít nastavení';

  @override
  String get dataImportExport => 'Import a export dat';

  @override
  String get dataImportExportDesc =>
      'Importovat úplná data nebo jednotlivé rozvrhy nebo exportovat aktuální/všechny rozvrhy.';

  @override
  String get appBackupTitle => 'Záloha a obnovení aplikace';

  @override
  String get appBackupSubtitle =>
      'Zálohujte nebo obnovte rozvrhy, plány, nastavení a školní weby. Klíče API nejsou zahrnuty.';

  @override
  String get appBackupSheetSubtitle =>
      'Úplné obnovení nahradí aktuální data aplikace. Klíče AI API jsou uloženy v zabezpečeném úložišti a nezapisují se do záloh.';

  @override
  String get restoreBackupFileTitle => 'Obnovit ze souboru JSON';

  @override
  String get restoreBackupFileSubtitle =>
      'Vyberte úplný záložní soubor Sked. Před obnovením budete požádáni o potvrzení.';

  @override
  String get restoreBackupTextTitle => 'Vložit JSON zálohy';

  @override
  String get restoreBackupTextSubtitle =>
      'Vložte úplnou zálohu a obnovte aktuální data aplikace.';

  @override
  String get shareBackupTitle => 'Sdílet soubor zálohy';

  @override
  String get shareBackupSubtitle =>
      'Exportujte všechna data aplikace jako JSON. Klíče API jsou vynechány.';

  @override
  String get saveBackupTitle => 'Uložit soubor zálohy';

  @override
  String get saveBackupSubtitle =>
      'Uložte úplnou zálohu aplikace do místního souboru.';

  @override
  String get copyBackupTitle => 'Kopírovat text zálohy';

  @override
  String get copyBackupSubtitle =>
      'Zobrazí úplný JSON zálohy, abyste jej mohli zkopírovat nebo dočasně uložit.';

  @override
  String get restoreBackupConfirmTitle => 'Obnovit úplnou zálohu?';

  @override
  String get restoreBackupConfirmMessage =>
      'Tím nahradíte všechny aktuální rozvrhy, obecné plány, nastavení a školní weby. Klíče API se ze záloh neimportují; před dalším parsováním rozvrhů zadejte klíč znovu.';

  @override
  String get restoreBackupConfirmAction => 'Obnovit zálohu';

  @override
  String get restoreBackupSuccessMessage =>
      'Úplná záloha aplikace byla obnovena. Klíče AI API je nutné zadat znovu.';

  @override
  String get restoreBackupFailureMessage =>
      'Obnovení selhalo. Zkontrolujte obsah zálohy a zkuste to znovu.';

  @override
  String get openSourceLicenses => 'Licence s otevřeným zdrojovým kódem';

  @override
  String get openSourceLicensesDesc =>
      'Zobrazení licencí pro závislosti Flutter a aktiva ikon aplikací.';

  @override
  String get checkForUpdates => 'Zkontrolujte aktualizace';

  @override
  String get checkForUpdatesDesc => 'GitHub';

  @override
  String get microsoftStoreUpdates => 'Aktualizace spravuje Microsoft Store';

  @override
  String get includePrereleaseUpdates => 'Přijímat předběžné aktualizace';

  @override
  String get includePrereleaseUpdatesDesc =>
      'Zahrnout verze Alpha, Beta a RC, které mohou být nestabilní. Při vypnutí se nabízejí pouze stabilní verze.';

  @override
  String alreadyLatestVersion(Object version) {
    return 'Již v nejnovější verzi ($version)';
  }

  @override
  String get currentVersionLabel => 'Aktuální verze';

  @override
  String get newVersionAvailable => 'Aktualizace k dispozici';

  @override
  String get latestVersionLabel => 'Nejnovější verze';

  @override
  String get updateContentLabel => 'Aktualizace podrobností';

  @override
  String get officialWebsite => 'Oficiální webové stránky';

  @override
  String get googlePlay => 'Google Play';

  @override
  String get cloudDrive => 'Cloud disk';

  @override
  String get ignoreThisVersion => 'Ignorovat tuto verzi';

  @override
  String get openUpdatesFailed => 'Nelze otevřít odkaz na aktualizaci';

  @override
  String get updateCheckFailedTitle => 'Kontrola aktualizace selhala';

  @override
  String get updateCheckFailedMessage =>
      'Nejnovější verzi se nepodařilo načíst z GitHubu. Níže můžete otevřít GitHub Releases ručně.';

  @override
  String get githubRepository => 'Úložiště GitHub';

  @override
  String get googlePlayStoreDesc => 'Zobrazit Sked na Google Play';

  @override
  String get openGooglePlayFailed => 'Google Play se nepodařilo otevřít';

  @override
  String get starSkedOnGithub => 'Dejte Sked hvězdičku na GitHubu!';

  @override
  String get starSkedOnGithubDesc =>
      'Otevřete repozitář projektu a dejte Sked hvězdičku';

  @override
  String get openGithubFailed => 'Nelze otevřít odkaz na úložiště GitHub';

  @override
  String get openPrivacyPolicyFailed =>
      'Nelze otevřít odkaz na zásady ochrany osobních údajů';

  @override
  String get selectPeriodTimeSet => 'Vyberte nastavení časového období';

  @override
  String get newItem => 'Nový';

  @override
  String get editPeriodTimeSet => 'Upravit časový nastavení období';

  @override
  String get importTimetableFiles => 'Importovat rozvrh';

  @override
  String get importTimetableFilesDesc =>
      'Podporuje jeden nebo více souborů rozvrhu.';

  @override
  String get importTimetableText => 'Importovat časový rozvrh z textu';

  @override
  String get importTimetableTextDesc =>
      'Vložte obsah časového rozvrhu JSON a importujte ho.';

  @override
  String get shareTimetableFiles => 'Sdílet soubory rozvrhu';

  @override
  String get shareTimetableFilesDesc =>
      'Nejprve vyberte jeden nebo více plánů.';

  @override
  String get saveTimetableFiles => 'Uložit soubory rozvrhu';

  @override
  String get saveTimetableFilesDesc => 'Nejprve vyberte jeden nebo více plánů.';

  @override
  String get exportTimetableText => 'Exportovat plán jako text';

  @override
  String get exportTimetableTextDesc =>
      'Vyberte jeden nebo více harmonogramů a zkopírujte obsah JSON.';

  @override
  String get jsonContent => 'Obsah JSON';

  @override
  String get pasteJsonContentHint => 'Vložte obsah JSON k importu.';

  @override
  String get jsonContentEmpty => 'Nejprve vložte obsah JSON.';

  @override
  String get copyText => 'Kopírovat';

  @override
  String get copiedToClipboard => 'Kopírovat do schránky';

  @override
  String get share => 'Sdílet';

  @override
  String get selectTimetablesToExport => 'Vyberte plány pro export';

  @override
  String get selectTimetablesToImport => 'Vyberte plány pro import';

  @override
  String timetableCourseCount(int count) {
    return '$count kurzy';
  }

  @override
  String get importAction => 'Importovat';

  @override
  String get importTimetableDialogTitle => 'Importovat rozvrh';

  @override
  String get chooseImportMethod => 'Vyberte si, jak importovat.';

  @override
  String get importAsNewTimetable => 'Importovat jako nový rozvrh';

  @override
  String get replaceCurrentTimetable => 'Nahradit aktuální rozvrh';

  @override
  String get importPeriodTimeSetDialogTitle => 'Importovat časové sady období';

  @override
  String get importPeriodTimeSetDialogBody =>
      'Tento soubor obsahuje shromážděné časové sady období. Chcete je importovat a propojit?';

  @override
  String get importBundledPeriodTimeSets => 'Import a přidružení';

  @override
  String get discardBundledPeriodTimeSets => 'Vyhodit svázané sady';

  @override
  String get importDiscardPeriodTimeSetUnavailable =>
      'Neexistuje žádná stávající časová sada období, takže svázané časové sady období nelze odstranit.';

  @override
  String savedToPath(Object path) {
    return 'Uloženo na $path';
  }

  @override
  String get saveCancelled => 'Uložit zrušeno';

  @override
  String get fileSaveRestrictedTitle => 'Uložení souboru omezeno';

  @override
  String get fileSaveRestrictedRetryMessage =>
      'Systém nemohl soubor uložit. Můžete to zkusit znovu nebo použít sdílení.';

  @override
  String get retrySave => 'Zkuste uložit znovu';

  @override
  String get fileSaveRestrictedSettingsMessage =>
      'Povolit přístup k souboru v nastavení systému, pak se vrátit a zkuste znovu exportovat.';

  @override
  String get openSettings => 'Otevřít nastavení';

  @override
  String get browserDownloadRestrictedTitle => 'Omezené stahování prohlížeče';

  @override
  String get browserDownloadRestrictedMessage =>
      'Tento prohlížeč nepodporuje přímé uložení do lokálního souboru. Zkontrolujte oprávnění ke stahování prohlížeče nebo místo toho použijte sdílení souborů.';

  @override
  String get switchToShare => 'Místo toho používejte sdílení';

  @override
  String get fileSaveFailedTitle => 'Uložení souboru selhalo';

  @override
  String get fileSaveFailedWindowsMessage =>
      'Nelze zapsat do aktuální cesty. Cílová složka může být chráněna, soubor může být používán nebo cesta může být nepsátelná.';

  @override
  String get fileSaveFailedGenericMessage =>
      'Systém nemohl soubor uložit. Můžete to zkusit znovu, zkontrolovat nastavení systému nebo místo toho použít sdílení souborů.';

  @override
  String get retryLater => 'Zkuste to znovu později';

  @override
  String get exportSwitchedToShare => 'Přepnuto na sdílení souborů pro export';

  @override
  String get saveFailedRetry =>
      'Uložení selhalo. Zkuste to prosím znovu později.';

  @override
  String get periodTimesUnsavedExitTitle => 'Změny nejsou uložené';

  @override
  String get periodTimesSaveFailureExitMessage =>
      'Poslední změny časů hodin se nepodařilo uložit. Můžete to zkusit znovu, pokračovat v úpravách nebo změny zahodit.';

  @override
  String get periodTimesInvalidExitMessage =>
      'Některé časy hodin nejsou platné. Před uložením je opravte, nebo změny zahoďte a odejděte.';

  @override
  String get discardChangesAndExit => 'Zahodit změny a odejít';

  @override
  String get appInstanceBlockedTitle => 'Sked je již otevřený';

  @override
  String get appInstanceBlockedMessage =>
      'Vaše místní data používá jiné okno aplikace Sked nebo jiná karta prohlížeče. Zavřete je a zkuste to znovu.';

  @override
  String get appInstanceLeaseFailedTitle => 'Místní data nejsou dostupná';

  @override
  String get appInstanceLeaseFailedMessage =>
      'Aplikaci Sked se nepodařilo ověřit výhradní přístup k místním datům. Vaše data nebyla otevřena ani změněna. Zkontrolujte přístup k úložišti a zkuste to znovu.';

  @override
  String get savingChanges => 'Ukládání změn...';

  @override
  String get showApiKey => 'Zobrazit klíč API';

  @override
  String get hideApiKey => 'Skrýt klíč API';

  @override
  String get importFailedCheckContent =>
      'Import selhal. Zkontrolujte prosím obsah souboru.';

  @override
  String get noImportableTimetables =>
      'V importovaném souboru nebyly nalezeny žádné použitelné harmonogramy.';

  @override
  String importedTimetablesCount(int count) {
    return 'Importované $count rozvrhy';
  }

  @override
  String get periodTimesTitle => 'Časy období';

  @override
  String get importExport => 'Import a export';

  @override
  String get importPeriodTemplate => 'Šablona období importu';

  @override
  String get importPeriodTemplateText => 'Importovat šablonu období z textu';

  @override
  String get sharePeriodTemplate => 'Šablona období podílu';

  @override
  String get saveTemplateToFile => 'Uložit šablonu do souboru';

  @override
  String get exportPeriodTemplateText => 'Exportovat šablonu období jako text';

  @override
  String get deletePeriodTimeSet => 'Smazat nastavený čas období';

  @override
  String get periodTimeSetName => 'Název nastavení času období';

  @override
  String get addOnePeriod => 'Přidat období';

  @override
  String periodNumberLabel(int index) {
    return 'Období $index';
  }

  @override
  String get deleteThisPeriod => 'Smazat tuto dobu';

  @override
  String durationMinutes(int minutes) {
    return 'Trvání $minutes min';
  }

  @override
  String gapFromPrevious(int minutes) {
    return 'Mezeru od předchozího $minutes min';
  }

  @override
  String get endTimeMustBeLater =>
      'Čas ukončení musí být později než čas zahájení';

  @override
  String get periodOverlapPrevious => 'Toto období překrývá předchozí';

  @override
  String get periodTimesSaved => 'Uložené období';

  @override
  String get deletePeriodTimeSetTitle => 'Smazat nastavený čas období';

  @override
  String deletePeriodTimeSetMessage(Object name) {
    return 'Smazat \"$name\"?';
  }

  @override
  String get currentPeriodTimeSet => 'nastavení času aktuálního období';

  @override
  String importedPeriodTimesCount(int count) {
    return 'Importované období $count';
  }

  @override
  String get periodFilePermissionTitle => 'Povolení k souboru potřebné';

  @override
  String get androidFilePermissionMessage =>
      'Android export vyžaduje oprávnění k přístupu k souborům. Udělejte oprávnění pokračovat v ukládání.';

  @override
  String get reauthorize => 'Opět autorizovat';

  @override
  String get permissionPermanentlyDeniedTitle => 'Povolení trvale odmítnuto';

  @override
  String get permissionSettingsExportMessage =>
      'Povolit přístup k souboru v nastavení systému, pak se vrátit a zkuste znovu exportovat.';

  @override
  String get privacyPolicyTitle => 'Zásady ochrany osobních údajů';

  @override
  String get privacyPolicyEntryDesc =>
      'Přečtěte si, jak aplikace zpracovává místní úložiště, konfiguraci školního webu, import/export souborů, analýzu webových stránek a externí odkazy.';

  @override
  String privacyPolicyAcceptedVersionLabel(Object version) {
    return 'Přijatá verze: $version';
  }

  @override
  String get privacyPolicyIntro =>
      'Sked je rozvrhový nástroj upřednostňující lokální ukládání. Rozvrhy, časové sady a konfigurace školních stránek jsou uloženy pouze ve vašem zařízení nebo prohlížeči a nikdy nejsou automaticky nahrávány. Aplikace zpracovává data pouze tehdy, když výslovně spustíte akce jako import, analýzu webových stránek, sdílení nebo otevírání externích odkazů. Úplné zásady ochrany osobních údajů jsou k dispozici online.';

  @override
  String get privacyPolicyLocalStorageTitle => 'Lokální skladování';

  @override
  String get privacyPolicyLocalStorageBody =>
      'V nativních verzích ukládá Sked rozvrhy, obecné plány, související nastavení a upravitelnou konfiguraci školních webů do složky podpory aplikace v operačním systému. Verze pro prohlížeč používá úložiště prohlížeče. Soubory, které starší verze uložily do uživatelské složky Dokumenty, zůstávají na místě, ale automaticky se nečtou ani nepřenášejí. Pokud je chcete zachovat, před aktualizací exportujte úplnou zálohu ze staré verze a poté ji obnovte. Nastavení AI API se ukládá místně. Vlastní klíč API se ukládá prostřednictvím zabezpečeného úložiště platformy, pokud je k dispozici. Úplné zálohy tento klíč neobsahují. Aplikace místní data automaticky neodesílá na server spravovaný vývojářem.';

  @override
  String get privacyPolicyImportExportTitle => 'Import a export';

  @override
  String get privacyPolicyImportExportBody =>
      'Aplikace čte nebo zapisuje soubory JSON časového rozvrhu, soubory JSON školních stránek a soubory šablon období pouze tehdy, když explicitně vyberete soubor nebo spustíte akci exportu. Import těchto souborů je lokální operací, pokud nevyberte také analýzu webových stránek. Nalezení vlastního seznamu modelů je také explicitní síťovou akci a kontaktuje pouze vlastní koncový bod, který jste nakonfigurovali.';

  @override
  String get privacyPolicySharingTitle => 'Sdílení';

  @override
  String get privacyPolicySharingBody =>
      'Když explicitně používáte sdílení, aplikace předá exportovaný soubor do listu sdílení systému nebo do cílové aplikace, kterou vyberete. Jak bude tento soubor následně zpracován, závisí na cílové aplikaci nebo službě, kterou jste vybrali.';

  @override
  String get privacyPolicyExternalLinksTitle => 'Externí odkazy';

  @override
  String get privacyPolicyExternalLinksBody =>
      'Když otevřete externí odkazy, jako je úložiště GitHub, aplikace předá akci vašemu prohlížeči nebo jiné externí aplikaci. Zpracování údajů po tomto bodě se řídí třetí stranou, kterou otevřete.';

  @override
  String get privacyPolicyNoCollectionTitle => 'Co aplikace neshromažďuje';

  @override
  String get privacyPolicyNoCollectionBody =>
      'Aplikace nevyžaduje účet Sked a neumožňuje analýzu, reklamní identifikátory ani cloudové zálohování. Také neposkytuje vyhrazené pole pro shromažďování hesel školních účtů. Pokud se přihlásíte na webové stránky školy uvnitř aplikace, dojde k této interakci na stránce školy, kterou jste otevřeli.';

  @override
  String get privacyPolicyFutureFeatureTitle => 'Analýza webových stránek';

  @override
  String get privacyPolicyFutureFeatureBody =>
      'Když použijete import školní webové stránky nebo analyzujete vložený text rozvrhu / HTML, aplikace obsah nejprve připraví a vyčistí lokálně a potom odešle zadaný text rozvrhu, text stránky nebo obsah HTML, volitelný název stránky a URL, aktuální jazyk aplikace a obsah pokynů pro parser do vámi nastaveného koncového bodu kompatibilního s OpenAI. Na stejný koncový bod se požaduje také načtení seznamu modelů. Sked neposkytuje vestavěný koncový bod parseru a neposílá požadavky na analýzu do backendu pro rozvrhy řízeného vývojářem. Vlastní koncový bod a případné nadřazené služby mohou data ukládat, přeposílat, omezovat, mazat nebo jinak zpracovávat podle pravidel vámi zvoleného poskytovatele služeb. Pokud používáte http:// Base URL, používejte jej pouze na důvěryhodných zařízeních, v důvěryhodných sítích a s důvěryhodnými službami koncového bodu, protože obsah a API klíče nemusí být chráněny transportním šifrováním.';

  @override
  String get privacyPolicyUpdatesTitle => 'Aktualizace zásad';

  @override
  String privacyPolicyUpdatesBody(Object version) {
    return 'Aktuální verze zásad ochrany osobních údajů je $version. Pokud pozdější verze změní způsob zpracování dat, aplikace vás může požádat, abyste si znovu přečetli aktualizované zásady a souhlasili s nimi.';
  }

  @override
  String get privacyGateTitle =>
      'Souhlaste prosím se zásadami ochrany osobních údajů před použitím aplikace';

  @override
  String get privacyGateSummaryStorage =>
      'Plány, časové sady a konfigurace školy jsou uloženy pouze lokálně a nejsou automaticky nahrány na server vývojářů.';

  @override
  String get privacyGateSummaryImportExport =>
      'Import, export a sdílení se odehrávají pouze tehdy, když je explicitně spustíte; Analýza webových stránek odesílá pouze komprimovaný obsah, který odešlete do nakonfigurovaného koncového bodu analýzy, a před uložením můžete zkontrolovat analyzovaný časový rozvrh.';

  @override
  String get privacyGateSummaryUpdates =>
      'Pokud pozdější verze změní způsob zpracování dat, aplikace vás může požádat, abyste znovu přezkoumali aktualizované zásady ochrany osobních údajů.';

  @override
  String get schoolWebImportEntry => 'Import ze školní stránky';

  @override
  String get schoolWebImportEntryDesc =>
      'Importujte aktuální časový rozvrh ze školních stránek.';

  @override
  String get schoolSitesManageEntry => 'Správa školních stránek';

  @override
  String get schoolSitesManageEntryDesc =>
      'Přidat, upravit a odstranit přihlašovací adresy školy pomocí importu a exportu JSON.';

  @override
  String get schoolSitesPageTitle => 'Správa školních míst';

  @override
  String get schoolSitesImportJson => 'Importovat školní JSON';

  @override
  String get schoolSitesShareJson => 'Sdílet školu JSON';

  @override
  String get schoolSitesSaveJson => 'Uložit školní JSON';

  @override
  String get schoolSitesSaved => 'Uložené školní stránky';

  @override
  String get schoolSitesImported => 'Školní stránky importované';

  @override
  String get schoolSitesImportPreviewTitle =>
      'Zkontrolovat import školních webů';

  @override
  String schoolSitesImportPreviewSummary(int validCount, int invalidCount) {
    return 'Platné weby: $validCount, neplatné záznamy: $invalidCount.';
  }

  @override
  String get schoolSitesImportEmptyPreview =>
      'Soubor obsahuje prázdný seznam školních webů.';

  @override
  String schoolSitesImportInvalidEntry(int position) {
    return 'Záznam $position je neplatný a bude přeskočen.';
  }

  @override
  String get schoolSitesImportMerge => 'Sloučit';

  @override
  String get schoolSitesImportReplace => 'Nahradit';

  @override
  String get schoolSitesImportReplaceConfirmTitle =>
      'Nahradit aktuální školní weby?';

  @override
  String schoolSitesImportReplaceConfirmMessage(
    int currentCount,
    int importedCount,
  ) {
    return 'Počet odstraněných současných webů: $currentCount. Počet uložených importovaných webů: $importedCount. Tuto akci nelze vrátit zpět.';
  }

  @override
  String get schoolSitesRecoveryCorruptTitle =>
      'Data školních webů vyžadují obnovu';

  @override
  String get schoolSitesRecoveryCorruptMessage =>
      'Sked nedokázal přečíst soubor školních webů ani jeho zálohu. Před zablokováním zápisu byly vytvořeny chráněné kopie.';

  @override
  String get schoolSitesRecoveryIoFailureTitle =>
      'Úložiště školních webů není dostupné';

  @override
  String get schoolSitesRecoveryIoFailureMessage =>
      'Sked teď nemá přístup k úložišti školních webů. Zkontrolujte přístup k úložišti nebo dostupnost zařízení a zkuste to znovu. Současná data nebudou přepsána.';

  @override
  String get schoolSitesRecoveryArtifactsHint =>
      'Níže jsou uvedeny soubory pro obnovu nebo dotčená umístění úložiště. Dokud se seznam webů neobnoví, soubory neměňte.';

  @override
  String get schoolSitesRecoveryStartFreshAction => 'Začít bez školních webů';

  @override
  String get schoolSitesRecoveryStartFreshConfirmTitle =>
      'Začít s prázdným seznamem školních webů?';

  @override
  String get schoolSitesRecoveryStartFreshConfirmMessage =>
      'Chráněné kopie zůstanou zachovány, ale Sked vytvoří nový prázdný soubor školních webů. Pokračujte pouze tehdy, pokud nechcete nejprve znovu zkusit obnovu.';

  @override
  String get schoolSitesEmpty => 'Zatím žádná konfigurace školních stránek.';

  @override
  String get schoolSitesNameLabel => 'Název školy';

  @override
  String get schoolSitesLoginUrlLabel => 'URL přihlášení';

  @override
  String get schoolSitesAdd => 'Přidat školu';

  @override
  String get schoolSitesEdit => 'Upravit školu';

  @override
  String get schoolSitesDeleteTitle => 'Odstranit školu';

  @override
  String schoolSitesDeleteMessage(Object name) {
    return 'Smazat \"$name\"?';
  }

  @override
  String get schoolSitesFormInvalid =>
      'Nejprve vyplňte název školy a přihlašovací adresu.';

  @override
  String get schoolSitesJsonFileName => 'Sked_school_sites.json';

  @override
  String get schoolHtmlImportEntry =>
      'Importovat vložením obsahu stránky rozvrhu';

  @override
  String get schoolHtmlImportEntryDesc =>
      'Vložte zdrojový kód nebo surový obsah stránky obsahující informace o harmonogramu ručně.';

  @override
  String get schoolHtmlImportPageTitle =>
      'Analyzovat časový rozvrh z obsahu stránky';

  @override
  String get schoolHtmlImportUrlLabel => 'Zdrojová adresa (volitelná)';

  @override
  String get schoolHtmlImportTitleLabel => 'Název stránky (volitelné)';

  @override
  String get schoolHtmlImportHtmlLabel => 'Obsah stránky';

  @override
  String get schoolHtmlImportHtmlHint =>
      'Vložte zdrojový kód nebo surový obsah stránky obsahující informace o harmonogramu sem.';

  @override
  String get schoolHtmlImportNonHtmlHint =>
      'Veškerý obsah obsahující informace o harmonogramu může být analyzován a importován, nejen HTML.';

  @override
  String get schoolHtmlImportCompress => 'Připravit obsah';

  @override
  String get schoolHtmlImportCompressed => 'Obsah připraven';

  @override
  String get schoolHtmlImportCompressFirst => 'Nejdřív připravte obsah.';

  @override
  String get schoolHtmlImportSubmit => 'Analyzovat a importovat';

  @override
  String get schoolImportContentTruncated =>
      'Tato stránka dosáhla bezpečného limitu importu. K analýze bude odeslána pouze zachycená část.';

  @override
  String get schoolHtmlImportParsingMayTakeLong =>
      'Parsing může chvíli trvat. Počkejte, prosím.';

  @override
  String get schoolHtmlImportEmpty => 'Nejprve vložte HTML stránku.';

  @override
  String get schoolHtmlImportReturnToWebPage => 'Zpět na stránku';

  @override
  String get schoolWebImportPageTitle => 'Import školních webových stránek';

  @override
  String get schoolWebImportPreview => 'Importovat náhled';

  @override
  String schoolWebImportCourseCount(int count) {
    return '$count kurzy';
  }

  @override
  String schoolWebImportPeriodCount(int count) {
    return '$count období';
  }

  @override
  String get schoolWebImportPageTitleLabel => 'Název stránky';

  @override
  String get schoolWebImportParserUsed => 'Analyzátor';

  @override
  String get schoolWebImportWarnings => 'Importovat poznámky';

  @override
  String get schoolWebImportParserDetails => 'Podrobnosti analýzy';

  @override
  String get schoolWebImportExpandParserDetails =>
      'Rozbalit podrobnosti analýzy';

  @override
  String get schoolWebImportCollapseParserDetails =>
      'Sbalit podrobnosti analýzy';

  @override
  String get schoolWebImportOpenPageHint =>
      'Přihlaste se na stránku školy v aplikaci a přejděte na stránku časového rozvrhu ručně.';

  @override
  String get schoolWebImportConfigMissing =>
      'Konfigurace vlastního analyzátoru není úplná. Nejprve vyplňte základní URL, klíč API a model.';

  @override
  String get schoolWebImportUnsupportedPlatform =>
      'Tato platforma zatím nepodporuje vložené webové přihlášení. Používejte platformu s podporou WebView.';

  @override
  String get schoolWebImportSelectSchool => 'Vyberte si školu';

  @override
  String get schoolWebImportNoSchools =>
      'Školní konfigurace není k dispozici. Nejprve zkontrolujte school_sites.json.';

  @override
  String get schoolWebImportSchoolLoadFailed =>
      'Nepodařilo se načíst konfiguraci školy. Zkontrolujte formát souboru JSON.';

  @override
  String get schoolWebImportImportCurrentPage => 'Importovat aktuální stránku';

  @override
  String get schoolWebImportLoadingPage => 'Načítání stránky…';

  @override
  String get schoolWebImportParsing => 'Analyzuje aktuální stránku...';

  @override
  String get schoolWebImportLoadFailed =>
      'Načítání stránky selhalo. Prosím, obnovte nebo zkuste to znovu později.';

  @override
  String get schoolWebImportUnknownOrigin => 'Neznámý web';

  @override
  String get schoolWebImportExitTitle => 'Opustit prohlížeč?';

  @override
  String get schoolWebImportExitMessage =>
      'Stránka se zavře. Vše, co jste dosud neimportovali, bude ztraceno.';

  @override
  String get schoolWebImportExitConfirm => 'Opustit';

  @override
  String get schoolWebImportEmptyPage =>
      'Aktuální obsah stránky je prázdný a zatím nelze importovat.';

  @override
  String get schoolWebImportSuccess => 'Webový rozvrh importován';

  @override
  String get schoolImportParserSettingsTitle => 'API pro zpracování rozvrhu';

  @override
  String get schoolImportParserSettingsDesc =>
      'Nastavte API kompatibilní s OpenAI pro import rozvrhů, nikoli pro chatovacího asistenta.';

  @override
  String get schoolImportParserSourceTitle => 'Zdroj parseru';

  @override
  String get schoolImportParserSourceCustomOpenAi => 'Kompatibilní s OpenAI';

  @override
  String get schoolImportParserSourceCustomOpenAiDesc =>
      'Send page content directly to your own OpenAI-compatible endpoint. HTTP endpoints are allowed only for trusted networks.';

  @override
  String get schoolImportParserCustomOpenAi =>
      'Vlastní parser kompatibilní s OpenAI';

  @override
  String get schoolImportParserCustomPromptTitle => 'Vlastní výzva';

  @override
  String get schoolImportParserCustomPromptDescription =>
      'Upravte vestavěnou výzvu parseru zde. Změny ovlivňují pouze vlastní parser kompatibilní s OpenAI.';

  @override
  String get schoolImportParserCustomPromptHint =>
      'Vestavěná výzva je zde ve výchozím nastavení načtená. Vymazejte ji, abyste se vrátili k vestavěné verzi.';

  @override
  String get schoolImportParserResetDefaultPrompt => 'Resetovat výchozí výzvu';

  @override
  String get schoolImportParserBaseUrl => 'Základní adresa URL';

  @override
  String get schoolImportParserBaseUrlInvalid =>
      'Base URL musí být adresa HTTP nebo HTTPS s hostitelem.';

  @override
  String get schoolImportParserApiKey => 'Klíč API';

  @override
  String get schoolImportParserModel => 'modelu';

  @override
  String get schoolImportParserFetchModels => 'Přinést seznam modelů';

  @override
  String get schoolImportParserFetchingModels => 'Přivádět modely. ..';

  @override
  String get schoolImportParserNoModelsFound =>
      'Konečným bodem nebyly vráceny žádné modely.';

  @override
  String get schoolImportParserFetchModelsFailed =>
      'Modely se nepodařilo načíst. Zkontrolujte koncový bod a zkuste to znovu.';

  @override
  String schoolImportParserModelsFetched(int count) {
    return 'Přihlášené modely $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'Vlastní klíč API se ukládá prostřednictvím zabezpečeného úložiště platformy, pokud je dostupné. Přihlašovací údaje analyzátoru a adresy HTTP používejte pouze na zařízeních, v prohlížečích a sítích, kterým důvěřujete.';

  @override
  String get schoolImportHttpConfirmationTitle =>
      'Použít nešifrovaný koncový bod HTTP?';

  @override
  String get schoolImportHttpConfirmationMessage =>
      'Klíč API a obsah rozvrhu mohou být během přenosu přečteny nebo změněny. Pokračujte pouze tehdy, pokud důvěřujete tomuto zařízení, síti a koncovému bodu. Toto schválení platí, dokud Sked nezavřete.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Konfigurace vlastního parseru je neúplná. Nejprve vyplňte základní adresu URL, klíč API a model.';

  @override
  String get clearAppData => 'Vymazat data';

  @override
  String get clearAppDataDesc =>
      'Trvale odstranit všechna místní data Sked a ukončit aplikaci';

  @override
  String get clearAppDataConfirmTitle => 'Vymazat všechna data Sked?';

  @override
  String get clearAppDataConfirmMessage =>
      'Trvale odstraní rozvrhy, plány, nastavení, školní weby, místní zálohy, kopie pro obnovu a klíč AI API. Poté se Sked ukončí. Soubory exportované jinam se neodstraní. Tuto akci nelze vrátit zpět.';

  @override
  String get clearAppDataAction => 'Vymazat data a ukončit';

  @override
  String get clearAppDataFailed =>
      'Všechna místní data se nepodařilo vymazat. Sked zůstane otevřený, abyste to mohli zkusit znovu.';

  @override
  String get clearAppDataExitFailed =>
      'Místní data byla vymazána, ale Sked se nepodařilo ukončit. Před dalším použitím aplikaci ručně zavřete.';

  @override
  String schoolImportParserCurrentSourceCustom(Object model) {
    return 'Parser: Vlastní ($model)';
  }

  @override
  String get privacyViewFullPolicy =>
      'Zobrazit úplné zásady ochrany osobních údajů';

  @override
  String get privacyAgreeAndContinue => 'Souhlasím a pokračujeme';

  @override
  String get privacyDecline => 'Odmítnutí';

  @override
  String get privacyDeclineWebHint =>
      'Toto prostředí prohlížeče neumožňuje aplikaci zavřít stránku pro vás. Pokud nesouhlasíte, zavřete prosím tuto kartu nebo okno sami.';

  @override
  String get defaultPeriodTimeSetName => 'Výchozí období';

  @override
  String get periodTimeSetFallbackName => 'Časy období';

  @override
  String get untitledTimetableName => 'Rozvrh bez názvu';

  @override
  String get newTimetableName => 'Nový rozvrh';

  @override
  String get newPeriodTimeSetName => 'Nastavení nového období';

  @override
  String get emptyTimetableName => 'Prázdný rozvrh';

  @override
  String importedPeriodTimeSetName(Object name) {
    return '$name období';
  }

  @override
  String get importFileTypeMismatchMessage =>
      'Typ souboru importu se neshoduje.';

  @override
  String get importFileVersionUnsupportedMessage =>
      'Tato verze importového souboru zatím není podporována.';

  @override
  String get noPeriodTimesInImportMessage =>
      'V souboru importu nebyly nalezeny žádné časové období.';

  @override
  String get selectAtLeastOneTimetableMessage =>
      'Vyberte alespoň jeden časový rozvrh.';

  @override
  String get noExportableTimetableMessage =>
      'Pro export není k dispozici žádný časový rozvrh.';

  @override
  String get replaceActiveRequiresSingleTimetableMessage =>
      'Nahrazení aktuálního harmonogramu podporuje pouze výběr jednoho harmonogramu.';

  @override
  String get noActiveTimetableToReplaceMessage =>
      'Neexistuje žádný aktuální časový rozvrh k nahrazení.';

  @override
  String periodTimeSetInUseMessage(int count) {
    return 'Toto časové období je stále používáno časovým rozvrhem $count. Před smazáním je znovu přiřaďte.';
  }

  @override
  String get weekdayMonday => 'pondělí';

  @override
  String get weekdayTuesday => 'Úterý';

  @override
  String get weekdayWednesday => 'Středa';

  @override
  String get weekdayThursday => 'Čtvrtek';

  @override
  String get weekdayFriday => 'pátek';

  @override
  String get weekdaySaturday => 'sobota';

  @override
  String get weekdaySunday => 'Neděle';

  @override
  String get weekdayShortMonday => 'pondělí';

  @override
  String get weekdayShortTuesday => 'úterý';

  @override
  String get weekdayShortWednesday => 'Středa';

  @override
  String get weekdayShortThursday => 'Čtvrtek';

  @override
  String get weekdayShortFriday => 'pátek';

  @override
  String get weekdayShortSaturday => 'sobotu';

  @override
  String get weekdayShortSunday => 'Slunce';

  @override
  String get monthJanuary => 'leden';

  @override
  String get monthFebruary => 'Únor';

  @override
  String get monthMarch => 'března';

  @override
  String get monthApril => 'duben';

  @override
  String get monthMay => 'května';

  @override
  String get monthJune => 'června';

  @override
  String get monthJuly => 'červenec';

  @override
  String get monthAugust => 'srpen';

  @override
  String get monthSeptember => 'září';

  @override
  String get monthOctober => 'říjen';

  @override
  String get monthNovember => 'listopad';

  @override
  String get monthDecember => 'prosinec';

  @override
  String get semesterWeeksWholeTerm => 'Celý semestr';

  @override
  String semesterWeeksRange(Object start, Object end) {
    return 'Týdny $start-$end';
  }

  @override
  String semesterWeeksList(Object value) {
    return 'Týdny $value';
  }

  @override
  String get generalSchedule => 'Obecný plán';

  @override
  String get studentTimetable => 'Studijní rozvrh';

  @override
  String get firstLaunchTitle => 'Vyberte výchozí režim';

  @override
  String get firstLaunchSubtitle =>
      'Vyberte pracovní prostor, který používáte nejčastěji. Režim můžete později změnit.';

  @override
  String get firstLaunchStudentDesc =>
      'Spravujte rozvrhy, kurzy, týdny, časy hodin a importy.';

  @override
  String get firstLaunchGeneralDesc =>
      'Spravujte kategorie, události, připomenutí a data JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Začít s rozvrhem';

  @override
  String get firstLaunchStartGeneral => 'Začít s plánem';

  @override
  String get firstLaunchPrivacyConsentBefore =>
      'Výběrem počátečního pracovního prostoru potvrzujete, že jste si přečetli a souhlasíte se ';

  @override
  String get firstLaunchPrivacyConsentLink => 'zásadami ochrany osobních údajů';

  @override
  String get firstLaunchPrivacyConsentAfter => '.';

  @override
  String get switchMode => 'Přepnout režim';

  @override
  String get generalScheduleComingSoon => 'Obecný plán připravujeme';

  @override
  String get switchToStudentTimetable => 'Přepnout na studijní rozvrh';

  @override
  String get mySchedule => 'Můj plán';

  @override
  String get today => 'Dnes';

  @override
  String get addEvent => 'Přidat událost';

  @override
  String get editEvent => 'Upravit událost';

  @override
  String get eventTitle => 'Název';

  @override
  String get eventTitleRequired => 'Zadejte název';

  @override
  String get eventStartTime => 'Čas začátku';

  @override
  String get eventEndTime => 'Čas konce';

  @override
  String get eventDate => 'Datum';

  @override
  String get eventTime => 'Čas';

  @override
  String get eventNotes => 'Poznámky';

  @override
  String get eventColor => 'Barva';

  @override
  String get eventRecurrence => 'Opakování';

  @override
  String get recurrenceNone => 'Neopakovat';

  @override
  String get recurrenceWeekly => 'Každý týden';

  @override
  String get recurrenceEndDate => 'Datum konce';

  @override
  String get recurrenceNoEndDate => 'Bez data konce';

  @override
  String get recurrenceSetEndDate => 'Nastavit';

  @override
  String get recurrenceChangeEndDate => 'Změnit';

  @override
  String get repeatsWeekly => 'Opakuje se každý týden';

  @override
  String recurrenceUntil(Object date) {
    return 'Do $date';
  }

  @override
  String get switchToGeneralSchedule => 'Přepnout na obecný plán';

  @override
  String get generalDisplaySettings => 'Nastavení zobrazení plánu';

  @override
  String get generalDisplaySettingsDesc =>
      'Zobrazení, panel nástrojů, formát data a rychlé přidání';

  @override
  String get closePopupOnOutsideTap => 'Zavřít okno klepnutím mimo něj';

  @override
  String get showGridLines => 'Zobrazit čáry mřížky';

  @override
  String get generalScheduleImportExport => 'Import a export kategorií';

  @override
  String get generalScheduleImportExportDesc =>
      'Importovat nebo sdílet kategorie plánu';

  @override
  String get importGeneralSchedules => 'Importovat kategorie';

  @override
  String get importGeneralSchedulesDesc => 'Načíst kategorie ze souboru JSON';

  @override
  String get shareGeneralSchedules => 'Sdílet kategorie';

  @override
  String get shareGeneralSchedulesDesc => 'Sdílet kategorie jako soubor JSON';

  @override
  String get saveGeneralSchedules => 'Uložit kategorie';

  @override
  String get saveGeneralSchedulesDesc => 'Uložit kategorie jako soubor JSON';

  @override
  String get selectSchedulesToExport => 'Vybrat kategorie k exportu';

  @override
  String get selectSchedulesToImport => 'Vybrat kategorie k importu';

  @override
  String generalScheduleEventCount(int count) {
    return 'Události: $count';
  }

  @override
  String importedSchedulesCount(int count) {
    return 'Importované kategorie: $count';
  }

  @override
  String get replaceActiveSchedulePrompt =>
      'Přidat jako novou kategorii, nebo nahradit existující?';

  @override
  String get addAsNewSchedule => 'Přidat jako novou kategorii';

  @override
  String get selectAtLeastOneScheduleMessage =>
      'Vyberte alespoň jednu kategorii.';

  @override
  String get noExportableScheduleMessage =>
      'Není dostupná žádná kategorie k exportu.';

  @override
  String get noSchedulesInImportMessage =>
      'Importovaný soubor neobsahuje žádné kategorie.';

  @override
  String get replaceActiveRequiresSingleScheduleMessage =>
      'Pro nahrazení vyberte právě jednu importovanou kategorii.';

  @override
  String get noActiveScheduleToReplaceMessage =>
      'Vybraná kategorie k nahrazení není dostupná.';

  @override
  String get calendars => 'Kategorie';

  @override
  String get calendar => 'Kategorie';

  @override
  String get viewWeek => 'Týden';

  @override
  String get viewDay => 'Den';

  @override
  String get viewList => 'Seznam';

  @override
  String get viewMonth => 'Měsíc';

  @override
  String visibleCategoryCount(int count) {
    return 'Kategorie: $count';
  }

  @override
  String get noVisibleCategories => 'Žádné viditelné kategorie';

  @override
  String get selectCategoryToReplace => 'Vybrat kategorii k nahrazení';

  @override
  String get replaceCategory => 'Nahradit kategorii';

  @override
  String get deleteEventTitle => 'Smazat událost';

  @override
  String get deleteEventConfirmation => 'Tato událost bude trvale smazána.';

  @override
  String get deleteRecurringEventTitle => 'Smazat opakovanou událost';

  @override
  String get eventDuplicated => 'Událost byla duplikována';

  @override
  String get searchEvents => 'Hledat události';

  @override
  String get clearSearch => 'Vymazat hledání';

  @override
  String get filterByColor => 'Filtrovat podle barvy';

  @override
  String get allColors => 'Všechny barvy';

  @override
  String upcomingEventsCount(int count) {
    return 'Nadcházející: $count';
  }

  @override
  String overdueEventsCount(int count) {
    return 'Po konci: $count';
  }

  @override
  String get allDay => 'Celý den';

  @override
  String get collapseAllDayTimeline => 'Sbalit celodenní události';

  @override
  String get expandAllDayTimeline => 'Rozbalit celodenní události';

  @override
  String allDayEventsCount(int count) {
    return 'Celodenní události: $count';
  }

  @override
  String moreEvents(int count) {
    return 'Další: $count';
  }

  @override
  String get noMatchingEvents => 'Žádné odpovídající události';

  @override
  String get noUpcomingEvents => 'Žádné nadcházející události';

  @override
  String get addCalendar => 'Přidat kategorii';

  @override
  String get newCalendar => 'Nová kategorie';

  @override
  String get hideCalendar => 'Skrýt kategorii';

  @override
  String get showCalendar => 'Zobrazit kategorii';

  @override
  String get rename => 'Přejmenovat';

  @override
  String get renameCalendar => 'Přejmenovat kategorii';

  @override
  String get name => 'Název';

  @override
  String get deleteCalendar => 'Smazat kategorii';

  @override
  String deleteCalendarMessage(Object name) {
    return 'Smazat „$name“?';
  }

  @override
  String get deleteThisOccurrence => 'Smazat pouze tento výskyt';

  @override
  String get deleteFutureOccurrences => 'Smazat tento a následující výskyty';

  @override
  String get deleteAllOccurrences => 'Smazat celou sérii';

  @override
  String get duplicateEvent => 'Duplikovat';

  @override
  String get repeatsDaily => 'Opakuje se každý den';

  @override
  String get repeatsMonthly => 'Opakuje se každý měsíc';

  @override
  String repeatsEvery(int interval, Object unit) {
    return 'Interval opakování: $interval $unit';
  }

  @override
  String recurrenceCountTimes(int count) {
    return '$count×';
  }

  @override
  String get recurrenceDaily => 'Každý den';

  @override
  String get recurrenceMonthly => 'Každý měsíc';

  @override
  String get recurrenceCustom => 'Vlastní';

  @override
  String get recurrenceEvery => 'Interval';

  @override
  String get recurrenceUnit => 'Jednotka';

  @override
  String get recurrenceDays => 'dny';

  @override
  String get recurrenceWeeks => 'týdny';

  @override
  String get recurrenceMonths => 'měsíce';

  @override
  String get recurrenceRepeatCount => 'Počet opakování';

  @override
  String get recurrenceNoLimit => 'Bez omezení';

  @override
  String get recurrencePositiveNumber => 'Zadejte kladné číslo';

  @override
  String get clearEndDate => 'Vymazat datum konce';

  @override
  String get pickDate => 'Vybrat datum';

  @override
  String get pickTime => 'Vybrat čas';

  @override
  String get reminder => 'Připomenutí v aplikaci';

  @override
  String get reminderAtStart => 'Při začátku';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min předem';
  }

  @override
  String get reminderHourBefore => '1 hodinu předem';

  @override
  String get reminderDayBefore => '1 den předem';

  @override
  String get markReminderHandled => 'Označit jako vyřízené';

  @override
  String get restoreReminder => 'Obnovit připomenutí v aplikaci';

  @override
  String get reminderHandled =>
      'Připomenutí v aplikaci bylo označeno jako vyřízené';

  @override
  String get reminderRestored => 'Připomenutí v aplikaci bylo obnoveno';

  @override
  String get reminderUpcoming => 'Nadcházející';

  @override
  String get reminderOverdue => 'Po konci';

  @override
  String get generalFitWeekColumnsToWidth => 'Přizpůsobit týden obrazovce';

  @override
  String get generalFitWeekColumnsToWidthHint =>
      'Zobrazí celý týden v kompaktním rozložení. Vypnutím povolíte vodorovné posouvání. Vlastní rozsahy nad 7 dní se posouvají i nadále.';

  @override
  String get showWeekends => 'Zobrazit víkendy';

  @override
  String get startHour => 'Počáteční hodina zobrazení';

  @override
  String get endHour => 'Koncová hodina zobrazení';

  @override
  String get timeGridDensity => 'Interval časové mřížky';

  @override
  String get timeGridHourHeight => 'Výška řádku hodiny';

  @override
  String get timeGridHourHeightHint =>
      'Upravuje svislé měřítko denního a týdenního zobrazení, aniž by měnil interval mřížky 15, 30 nebo 60 minut.';

  @override
  String timeGridHourHeightValue(int height) {
    return '$height dp';
  }

  @override
  String get importJsonFile => 'Importovat soubor JSON';

  @override
  String get pasteJson => 'Vložit JSON';

  @override
  String get importGeneralSchedulesJsonTextDesc =>
      'Importovat kategorie ze zkopírovaného JSON';

  @override
  String get importIcsFile => 'Importovat soubor ICS';

  @override
  String get importIcsFileDesc =>
      'Načíst události z kalendářového souboru .ics';

  @override
  String get pasteIcs => 'Vložit ICS';

  @override
  String get pasteIcsDesc =>
      'Importovat události ze zkopírovaného kalendářového textu';

  @override
  String get copyJson => 'Kopírovat JSON';

  @override
  String get copyJsonDesc => 'Kopírovat vybrané kategorie jako text JSON';

  @override
  String get shareIcs => 'Sdílet ICS';

  @override
  String get shareIcsDesc => 'Sdílet vybrané kalendáře jako .ics';

  @override
  String get saveIcs => 'Uložit ICS';

  @override
  String get saveIcsDesc => 'Uložit vybrané kalendáře jako .ics';

  @override
  String get copyIcs => 'Kopírovat ICS';

  @override
  String get copyIcsDesc => 'Kopírovat vybrané kalendáře jako text ICS';

  @override
  String get importIcs => 'Importovat ICS';

  @override
  String get icsContent => 'Obsah ICS';

  @override
  String get pasteIcsContentHint =>
      'Sem vložte obsah začínající BEGIN:VCALENDAR';

  @override
  String importIcsPreviewPrompt(int count) {
    return 'Nalezené události: $count. Přidat jako novou kategorii, nebo nahradit existující?';
  }

  @override
  String importedSchedulesWithWarnings(int count, int warningCount) {
    return 'Importované kategorie: $count, upozornění: $warningCount';
  }

  @override
  String get importWarningSkippedMissingStart =>
      'Událost bez času začátku byla přeskočena.';

  @override
  String get importWarningSkippedUnsupportedStart =>
      'Událost s nepodporovaným časem začátku byla přeskočena.';

  @override
  String get importWarningAdjustedEnd =>
      'Čas konce, který nebyl po začátku, byl upraven.';

  @override
  String importWarningUnsupportedFields(Object fields) {
    return 'Nepodporovaná pole ICS byla přidána do poznámek: $fields';
  }

  @override
  String importWarningUnsupportedRRuleFrequency(Object frequency) {
    return 'Nepodporovaná frekvence opakování byla ignorována: $frequency';
  }

  @override
  String get selectCalendarsToCopyIcs =>
      'Vybrat kalendáře ke kopírování jako ICS';

  @override
  String get selectCalendarsToExportIcs =>
      'Vybrat kalendáře k exportu jako ICS';

  @override
  String get exportIcsText => 'Exportovat text ICS';

  @override
  String get exportJsonText => 'Exportovat text JSON';

  @override
  String get dataRestoredFromBackupNotice =>
      'Hlavní soubor se nepodařilo načíst, proto byla data aplikace obnovena z předchozí zálohy.';

  @override
  String get dataBackupRestoreFailedNotice =>
      'Hlavní datový soubor i jeho záloha jsou poškozené. Aplikace nyní používá nový výchozí stav.';

  @override
  String get dataRecoveryCorruptTitle => 'Vaše data vyžadují obnovu';

  @override
  String get dataRecoveryCorruptMessage =>
      'Sked nedokázal přečíst hlavní datový soubor ani jeho zálohu. Před zablokováním zápisu byly vytvořeny chráněné kopie.';

  @override
  String get dataRecoveryIoFailureTitle => 'Úložiště není dostupné';

  @override
  String get dataRecoveryIoFailureMessage =>
      'Sked teď nemá přístup k místnímu úložišti. Zkontrolujte přístup k úložišti nebo dostupnost zařízení a zkuste to znovu. Stávající data nebudou přepsána.';

  @override
  String get dataRecoveryUnsupportedVersionTitle =>
      'Pro otevření těchto dat aktualizujte Sked';

  @override
  String get dataRecoveryUnsupportedVersionMessage =>
      'Tato data vytvořila novější verze Sked. Aktualizujte aplikaci a zkuste to znovu. Nový začátek je kvůli ochraně dat zakázán.';

  @override
  String get dataRecoveryRetryAction => 'Zkusit znovu';

  @override
  String get dataRecoveryArtifactsHint =>
      'Níže jsou uvedeny soubory pro obnovu nebo dotčená umístění úložiště. Dokud data neobnovíte, soubory neměňte.';

  @override
  String get dataRecoveryArtifactsAction =>
      'Zobrazit soubory a umístění pro obnovu';

  @override
  String get dataRecoveryStartFreshAction => 'Začít s novými daty';

  @override
  String get dataRecoveryStartFreshConfirmTitle => 'Začít s novými daty?';

  @override
  String get dataRecoveryStartFreshConfirmMessage =>
      'Chráněné kopie zůstanou zachovány, ale Sked vytvoří nový místní datový soubor. Pokračujte pouze tehdy, pokud nechcete nejprve znovu zkusit obnovu.';

  @override
  String get previousMonth => 'Předchozí měsíc';

  @override
  String get nextMonth => 'Další měsíc';

  @override
  String timeGridMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get reminderInProgress => 'Probíhá';

  @override
  String get deleteCourseTitle => 'Smazat kurz';

  @override
  String get deleteCourseMessage => 'Smazat tento kurz?';

  @override
  String get showLunarCalendar => 'Zobrazit lunární kalendář';

  @override
  String monthDayEvents(int day, int count) {
    return '$day, události: $count';
  }

  @override
  String get defaultView => 'Výchozí zobrazení';

  @override
  String get generalDefaultViewSection => 'Při spuštění';

  @override
  String get generalViewSwitchBehavior => 'Tlačítko přepínání zobrazení';

  @override
  String get settingsWorkspaceMode => 'Aktivní pracovní prostor';

  @override
  String get hideHomeWorkspaceNavigation =>
      'Skrýt navigaci pracovních prostorů';

  @override
  String get hideHomeWorkspaceNavigationDesc =>
      'Skryje navigaci pracovních prostorů. Přepínat je lze v nabídce na hlavní obrazovce.';

  @override
  String get generalDateLabelFormat => 'Formát popisku data';

  @override
  String get generalDateLabelFormatLocalized => 'Místní formát (červenec 2026)';

  @override
  String get generalDateLabelFormatSlash => 'S lomítkem (2026/7)';

  @override
  String get generalDateLabelFormatIso => 'ISO (2026-07)';

  @override
  String get generalToolbarSection => 'Rozložení panelu nástrojů';

  @override
  String get toolbarNavigationSection => 'Navigace na panelu nástrojů';

  @override
  String get toolbarNavigationHiddenBehavior => 'Skryté položky';

  @override
  String get toolbarNavigationRemove => 'Úplně skrýt';

  @override
  String get toolbarNavigationMore => 'Přesunout do nabídky Další';

  @override
  String get toolbarNavigationReorder => 'Změnit pořadí položek panelu';

  @override
  String get toolbarNavigationVisibility => 'Zobrazit položku panelu';

  @override
  String get toolbarNavigationTimetable => 'Výběr rozvrhu';

  @override
  String get toolbarNavigationWeek => 'Výběr týdne';

  @override
  String get toolbarNavigationView => 'Přepínání zobrazení';

  @override
  String get toolbarNavigationCategory => 'Výběr kategorie';

  @override
  String get toolbarNavigationDate => 'Výběr data';

  @override
  String get generalToolbarWidthPolicy => 'Rozdělení místa na panelu nástrojů';

  @override
  String get generalToolbarWidthContent => 'Automatické rozdělení';

  @override
  String get generalToolbarWidthBalanced => 'Vyvážené';

  @override
  String get generalToolbarWidthCalendarPriority => 'Přednost kategorií';

  @override
  String get generalToolbarWidthDatePriority => 'Přednost data';

  @override
  String get generalViewSwitchCycle => 'Postupně přepínat zobrazení';

  @override
  String get generalViewSwitchMenu => 'Otevřít nabídku zobrazení';

  @override
  String get generalViewSwitchTooltip => 'Přepnout zobrazení';

  @override
  String get generalViewSwitchMenuTooltip => 'Vybrat zobrazení';

  @override
  String get generalViewLongPressTodayHint => 'Podržením přejdete na dnešek';

  @override
  String get generalScheduleDisplaySection => 'Zobrazení plánu';

  @override
  String get generalTimeGridSection => 'Časová mřížka';

  @override
  String get generalPopupSection => 'Chování vyskakovacích oken';

  @override
  String get quickActionsSection => 'Rychlé akce';

  @override
  String get showAddCourseFab => 'Zobrazit plovoucí tlačítko pro přidání kurzu';

  @override
  String get showAddCourseFabHint =>
      'Zobrazí nebo skryje plovoucí tlačítko pro přidání kurzu v pravém dolním rohu rozvrhu.';

  @override
  String get showAddEventFab =>
      'Zobrazit plovoucí tlačítko pro přidání události';

  @override
  String get showAddEventFabHint =>
      'Zobrazí nebo skryje plovoucí tlačítko pro přidání události v pravém dolním rohu plánu.';

  @override
  String get enableLongPressAddCourse => 'Přidat kurz podržením prázdné mřížky';

  @override
  String get enableLongPressAddCourseHint =>
      'Podržením prázdného místa v mřížce rozvrhu přidáte kurz.';

  @override
  String get enableLongPressAddEvent =>
      'Přidat událost podržením prázdné mřížky';

  @override
  String get enableLongPressAddEventHint =>
      'V denním nebo týdenním zobrazení podržte prázdné místo v časové mřížce a přidejte událost.';

  @override
  String get developerModeTitle => 'Vývojářský režim';

  @override
  String get developerModeDescription =>
      'Nástroje pro přidání kompletních ukázkových dat k ověření vzhledu a ovládání.';

  @override
  String get developerSampleLanguage => 'Jazyk ukázkových dat';

  @override
  String get developerSampleChinese => 'Čínština';

  @override
  String get developerSampleEnglish => 'Angličtina';

  @override
  String get developerSampleDataDescription =>
      'Přidá jeden rozvrh a sadu kategorií a událostí, aniž by nahradil stávající data.';

  @override
  String get developerAddSampleData => 'Přidat ukázková data';

  @override
  String get developerSampleDataAdded =>
      'Ukázkový rozvrh a data událostí byly přidány.';

  @override
  String get developerModeLongPressHint =>
      'Dlouhým stisknutím na 3 sekundy otevřete vývojářský režim';

  @override
  String get developerNotificationDiagnostics => 'Diagnostika oznámení';

  @override
  String get developerNotificationDiagnosticsDescription =>
      'Zkontrolujte doručování v Androidu, obnovte stávající plán připomenutí a odešlete bezpečná testovací oznámení prostřednictvím běžné služby Sked.';

  @override
  String get developerNotificationUnsupported =>
      'Diagnostika oznámení je dostupná pouze v Androidu.';

  @override
  String get developerNotificationCoordinatorUnavailable =>
      'Diagnostika oznámení bude dostupná po spuštění koordinátoru plánovaných oznámení.';

  @override
  String get developerNotificationRefresh => 'Obnovit diagnostiku';

  @override
  String get developerNotificationSystemStatus =>
      'Systémové oprávnění k oznámením';

  @override
  String get developerNotificationPermissionAllowed => 'Povoleno';

  @override
  String get developerNotificationPermissionBlocked => 'Blokováno';

  @override
  String get developerNotificationExactAlarm => 'Přesné budíky';

  @override
  String get developerNotificationExactAlarmAllowed => 'Povoleny';

  @override
  String get developerNotificationExactAlarmBlocked => 'Nepovoleny';

  @override
  String get developerNotificationPlan => 'Plán oznámení agendy';

  @override
  String get developerNotificationCoverage => 'Pokrytí';

  @override
  String get developerNotificationCoverageReady =>
      'Všechna známá připomenutí s konečným počtem opakování jsou přímo naplánována';

  @override
  String get developerNotificationCoverageRenewable =>
      'Opakovaná připomenutí se dlouhodobě obnovují podle možností systému';

  @override
  String get developerNotificationCoverageCapacityLimited =>
      'Kapacita přímých budíků je plná; pozdější připomenutí se obnovují podle možností systému';

  @override
  String get developerNotificationCoverageBlocked =>
      'Podmínky přesného doručení nejsou splněny';

  @override
  String get developerNotificationCoverageFailed =>
      'Poslední synchronizace připomenutí selhala';

  @override
  String developerNotificationDirectCapacitySummary(
    int scheduled,
    int capacity,
  ) {
    return 'Přímé budíky: $scheduled / kapacita: $capacity';
  }

  @override
  String developerNotificationPlanSummary(int scheduled, int planned) {
    return 'Naplánováno: $scheduled, v plánu: $planned';
  }

  @override
  String developerNotificationPlanError(Object message) {
    return 'Poslední chyba: $message';
  }

  @override
  String get developerNotificationRunMaintenance =>
      'Znovu vytvořit plán oznámení';

  @override
  String get developerNotificationMaintenanceComplete =>
      'Plán oznámení byl znovu vytvořen.';

  @override
  String get developerNotificationTestChannel => 'Testovací kanál';

  @override
  String get developerNotificationTestCourse => 'Připomenutí kurzů';

  @override
  String get developerNotificationTestSchedule => 'Připomenutí událostí';

  @override
  String get developerNotificationImmediateTest => 'Odeslat okamžitý test';

  @override
  String get developerNotificationThirtySecondTest =>
      'Naplánovat test na pozadí za 30 sekund';

  @override
  String get developerNotificationImmediateQueued =>
      'Okamžité testovací oznámení bylo odesláno.';

  @override
  String get developerNotificationThirtySecondQueued =>
      'Test na pozadí je naplánován za 30 sekund.';

  @override
  String get developerNotificationAppSwitch =>
      'Přepínač připomenutí v aplikaci';

  @override
  String get developerNotificationAppSwitchEnabled =>
      'Běžná připomenutí jsou zapnutá';

  @override
  String get developerNotificationAppSwitchDisabled =>
      'Běžná připomenutí jsou vypnutá; vývojářské testy lze stále spouštět';

  @override
  String get developerNotificationTimeZone => 'Místní časové pásmo';

  @override
  String developerNotificationTimeZoneValue(Object zone, Object offset) {
    return '$zone (UTC$offset)';
  }

  @override
  String get developerNotificationChannelNotCreated =>
      'Zatím není vytvořen. Vytvoří jej vývojářský test.';

  @override
  String get developerNotificationChannelEnabledState => 'Zapnuto';

  @override
  String get developerNotificationChannelBlockedState => 'Blokováno';

  @override
  String developerNotificationChannelImportance(int importance) {
    return 'Důležitost: $importance';
  }

  @override
  String get developerNotificationChannelImportanceUnavailable =>
      'Důležitost není dostupná';

  @override
  String developerNotificationChannelSummary(Object state, Object importance) {
    return '$state · $importance';
  }

  @override
  String developerNotificationPlatformState(int pending, int active) {
    return 'Čekající: $pending / aktivní: $active';
  }

  @override
  String developerNotificationNativeLastPosted(String time) {
    return 'Poslední systémové zobrazení: $time';
  }

  @override
  String get developerNotificationNoDiagnostic =>
      'Zatím nebylo zaznamenáno žádné přepočítání.';

  @override
  String get developerNotificationNextReminder => 'Další skutečné připomenutí';

  @override
  String get developerNotificationNoPendingReminder =>
      'V aktuálním plánu není žádné budoucí připomenutí';

  @override
  String get developerNotificationNextMaintenance => 'Další údržba';

  @override
  String get developerNotificationNextRenewal => 'Další pokus o obnovení';

  @override
  String get developerNotificationNoMaintenance => 'Nenaplánováno';

  @override
  String get developerNotificationTruncation => 'Omezení plánu';

  @override
  String developerNotificationTruncationCount(int count) {
    return 'Vynecháno kvůli limitu plánu: $count';
  }

  @override
  String get developerNotificationLastReconciliation => 'Poslední přepočítání';

  @override
  String get developerNotificationLastSynchronization =>
      'Poslední synchronizace připomenutí';

  @override
  String get developerNotificationLateRecovery =>
      'Obnova opožděných připomenutí';

  @override
  String developerNotificationLateRecoveryCount(int count) {
    return 'Po původním čase byla obnovena připomenutí v počtu $count';
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
  String get developerNotificationReconcileOriginForeground => 'Na popředí';

  @override
  String get developerNotificationReconcileOriginBackground => 'Na pozadí';

  @override
  String get developerNotificationReconcileModeAuthoritative =>
      'Úplné přepočítání';

  @override
  String get developerNotificationReconcileModeMaintenance => 'Údržba';

  @override
  String get developerNotificationReconcileModeRecovery => 'Obnova';

  @override
  String get developerNotificationRunRecovery => 'Spustit obnovu připomenutí';

  @override
  String get developerNotificationRecoveryComplete =>
      'Obnova připomenutí byla dokončena';

  @override
  String get developerNotificationReconcileResultSuccess => 'Úspěšné';

  @override
  String get developerNotificationReconcileResultSkipped => 'Přeskočeno';

  @override
  String get developerNotificationReconcileResultBlocked =>
      'Blokováno do splnění všech podmínek přesného doručení';

  @override
  String get developerNotificationReconcileResultFailed => 'Selhalo';

  @override
  String get developerNotificationBackgroundLimits =>
      'Omezení běhu na pozadí od výrobce';

  @override
  String get developerNotificationOemBackgroundRestriction =>
      'Omezení běhu na pozadí od výrobce mohou ovlivnit doručování.';

  @override
  String get developerNotificationAutostart =>
      'Spouštění na pozadí podle výrobce';

  @override
  String developerNotificationAutostartVendor(Object vendor) {
    return 'Výrobce: $vendor. Je dostupný odkaz do jeho nastavení. Android neumí zjistit stav tohoto oprávnění.';
  }

  @override
  String developerNotificationAutostartFallback(Object vendor) {
    return 'Výrobce: $vendor. Místo jeho nastavení se otevřou podrobnosti aplikace. Android neumí zjistit stav tohoto oprávnění.';
  }

  @override
  String get developerNotificationAutostartUnavailable =>
      'Není dostupný odkaz do nastavení běhu na pozadí od výrobce.';

  @override
  String developerNotificationAutostartLastTarget(Object target) {
    return 'Poslední otevřený cíl: $target';
  }

  @override
  String get developerNotificationAutostartTargetVendor => 'nastavení výrobce';

  @override
  String get developerNotificationAutostartTargetApplicationDetails =>
      'podrobnosti aplikace';

  @override
  String get developerNotificationAutostartTargetUnavailable => 'žádný';

  @override
  String get developerNotificationRebootBoundaryTitle =>
      'Podmínky obnovy po restartu';

  @override
  String get developerNotificationRebootBoundary =>
      'Obnova začíná až po prvním odemknutí. Nuceně zastavená aplikace se nemůže sama spustit.';

  @override
  String get developerNotificationTestChecking =>
      'Během kontroly stavu oznámení nejsou testy dostupné.';

  @override
  String get developerNotificationTestBlockedSystem =>
      'Testy nejsou dostupné, protože systémová oznámení jsou blokovaná.';

  @override
  String get developerNotificationTestBlockedChannel =>
      'Testy nejsou dostupné, protože vybraný kanál oznámení je blokovaný.';

  @override
  String get developerNotificationWindowsPermissionManaged =>
      'Spravováno nastavením oznámení Windows';

  @override
  String get developerNotificationWindowsExactNotApplicable =>
      'Nevztahuje se na Windows';

  @override
  String get developerNotificationWindowsIdentity => 'Identita balíčku Windows';

  @override
  String get developerNotificationWindowsMsixReady =>
      'Identita MSIX je dostupná; zobrazená oznámení lze zrušit';

  @override
  String get developerNotificationWindowsMsixRequired =>
      'Pro spolehlivé rušení zobrazených oznámení nainstalujte verzi MSIX';

  @override
  String get collapseWorkspaceNavigation =>
      'Sbalit navigaci pracovního prostoru';

  @override
  String get expandWorkspaceNavigation =>
      'Rozbalit navigaci pracovního prostoru';

  @override
  String get schoolWebImportExitBrowser => 'Ukončit vestavěný prohlížeč';

  @override
  String get schoolWebImportEditAddress => 'Upravit adresu';

  @override
  String get schoolWebImportAddressLabel => 'Webová adresa';

  @override
  String get schoolWebImportOpenAddress => 'Otevřít';

  @override
  String get schoolWebImportAddressInvalid =>
      'Zadejte adresu HTTP nebo HTTPS s hostitelem.';

  @override
  String get schoolWebImportNewWindowUnsupported =>
      'Tato webová stránka požádala o nové okno, které na tomto zařízení nelze otevřít.';

  @override
  String get schoolWebImportSecureConnection => 'Zabezpečené připojení';

  @override
  String get schoolWebImportInsecureConnection => 'Nezabezpečené připojení';

  @override
  String get schoolWebImportSignInConsentTitle =>
      'Otevřít přihlášení do školního systému?';

  @override
  String schoolWebImportSignInConsentMessage(Object origin) {
    return 'Přihlášení do školního systému může odeslat přihlašovací údaje prostřednictvím formulářů nebo přesměrování serveru škole a jejím poskytovatelům přihlášení. Android nemůže každé takové odeslání pozastavit a zobrazit samostatné potvrzení cíle. Pokračujte pouze tehdy, pokud jim pro tuto relaci importu důvěřujete:\n\n$origin';
  }

  @override
  String get schoolWebImportInsecureSignInConsentTitle =>
      'Otevřít nezabezpečené přihlášení ke škole?';

  @override
  String schoolWebImportInsecureSignInConsentMessage(Object origin) {
    return 'Toto přihlášení ke škole používá HTTP. Kdokoli, kdo může toto připojení sledovat nebo měnit, může přečíst či změnit vaše přihlašovací údaje a obsah stránky. Pokračujte pouze tehdy, pokud toto riziko přijímáte pro:\n\n$origin';
  }

  @override
  String get notificationSettingsSection => 'Připomenutí a oznámení';

  @override
  String get notificationCoverage => 'Pokrytí připomenutí';

  @override
  String get notificationCoverageRenewable =>
      'Opakované plány bez data konce používají obnovování na pozadí pro dlouhodobé pokrytí.';

  @override
  String notificationCoverageCapacityLimited(int capacity) {
    return 'Android může přímo uchovat až $capacity připomenutí. Pozdější připomenutí se pokusí obnovit předem.';
  }

  @override
  String get notificationSettingsEnabled => 'Zapnout připomenutí a oznámení';

  @override
  String get notificationSettingsEnabledHint =>
      'Plánuje pouze položky s připomenutím. Pro kurzy, které dědí výchozí nastavení, zadejte níže výchozí připomenutí.';

  @override
  String get notificationPrecisionLimitations =>
      'Připomenutí závisí na systémových oprávněních a běhu na pozadí. Vypnutí, změny času nebo systémová omezení je mohou zpozdit.';

  @override
  String get notificationSettingsEnabledSummary => 'Zapnuto';

  @override
  String get notificationSettingsDisabledSummary => 'Vypnuto';

  @override
  String get notificationDefaultsSection => 'Výchozí připomenutí';

  @override
  String get notificationCourseDefaultReminder => 'Výchozí připomenutí kurzu';

  @override
  String get notificationGeneralDefaultReminder =>
      'Výchozí připomenutí události';

  @override
  String get notificationReminderOff => 'Bez připomenutí';

  @override
  String notificationReminderCustom(int minutes) {
    return '$minutes min předem';
  }

  @override
  String get notificationPermission => 'Oprávnění k oznámením';

  @override
  String get notificationPermissionGranted => 'Povoleno systémem';

  @override
  String get notificationPermissionDenied => 'Blokováno systémem';

  @override
  String get notificationPermissionChecking => 'Kontrola oprávnění…';

  @override
  String get notificationPermissionRequest => 'Požádat o oprávnění';

  @override
  String get notificationPermissionOpenSettings =>
      'Otevřít systémové nastavení';

  @override
  String get notificationPermissionRequestFailed =>
      'Oprávnění k oznámením se nepodařilo zjistit. Zkuste to znovu.';

  @override
  String get notificationExactAlarm => 'Oprávnění k přesným budíkům';

  @override
  String get notificationExactAlarmAllowed => 'Povoleno systémem';

  @override
  String get notificationExactAlarmRequired =>
      'Nutné pro připomenutí v přesný čas';

  @override
  String get notificationExactAlarmRequest => 'Povolit přesné budíky';

  @override
  String get notificationBatteryOptimization => 'Optimalizace baterie';

  @override
  String get notificationBatteryOptimizationAllowed =>
      'Povolena výjimka z optimalizace baterie Androidu';

  @override
  String get notificationBatteryOptimizationRequired =>
      'Přesná připomenutí vyžadují výjimku z optimalizace baterie Androidu';

  @override
  String get notificationBatteryOptimizationRequest =>
      'Otevřít nastavení optimalizace baterie';

  @override
  String get notificationAutostart => 'Spouštění na pozadí podle výrobce';

  @override
  String get notificationAutostartVendorHint =>
      'Povolte automatické spouštění nebo běh na pozadí, aby bylo možné obnovit připomenutí po restartu.';

  @override
  String get notificationAutostartFallbackHint =>
      'Otevřete podrobnosti aplikace Sked a povolte běh na pozadí. Android nedokáže toto nastavení výrobce ověřit.';

  @override
  String get notificationAutostartUnavailable =>
      'Nastavení výrobce nebylo nalezeno. Ručně zkontrolujte podrobnosti aplikace Sked.';

  @override
  String get notificationAutostartRequest =>
      'Otevřít nastavení běhu na pozadí od výrobce';

  @override
  String get notificationAutostartOpenFailed =>
      'Nastavení běhu na pozadí od výrobce se nepodařilo otevřít. Ručně zkontrolujte podrobnosti aplikace Sked.';

  @override
  String get notificationLockScreenTitles =>
      'Zobrazovat názvy na zamčené obrazovce';

  @override
  String get notificationLockScreenTitlesHint =>
      'Po vypnutí zůstanou podrobnosti oznámení na zamčené obrazovce skryté.';

  @override
  String get notificationWidgets => 'Widgety na domovské obrazovce';

  @override
  String get notificationWidgetsDesc =>
      'Obnovte widgety Sked a zjistěte, jak je přidat z domovské obrazovky.';

  @override
  String get notificationWidgetsDialogTitle => 'Přidat widget Sked';

  @override
  String get notificationWidgetsDialogMessage =>
      'Na domovské obrazovce podržte prázdné místo, vyberte Widgety a přidejte widget Sked. Zobrazuje nadcházející kurzy nebo události.';

  @override
  String get notificationWidgetsRefresh => 'Obnovit widgety';

  @override
  String get notificationWidgetsRefreshed => 'Widgety byly obnoveny';

  @override
  String get notificationPlatformUnsupported =>
      'Tato platforma neposkytuje nativní oznámení.';

  @override
  String get workspaceFeatures => 'Správa funkcí';

  @override
  String get workspaceBoth => 'Rozvrh a kalendář';

  @override
  String get workspaceOnlyStudent => 'Pouze rozvrh';

  @override
  String get workspaceOnlyGeneral => 'Pouze kalendář';

  @override
  String get workspaceDisableTitle => 'Vypnout tento pracovní prostor?';

  @override
  String get workspaceDisableMessage =>
      'Data a předvolby zůstanou zachovány. Funkce a připomenutí se pozastaví, dokud prostor zde znovu nezapnete.';

  @override
  String get workspaceEnableHint =>
      'Vyberte používané funkce. Alespoň jedna musí zůstat zapnutá.';

  @override
  String get workspaceLastRequired =>
      'Alespoň jeden pracovní prostor musí zůstat zapnutý.';

  @override
  String get workspaceReminderCleanupFailed =>
      'Pracovní prostor je vypnutý, ale připomenutí se nepodařilo odstranit. Zkuste obnovení oznámení znovu.';

  @override
  String get settingsSearch => 'Hledat v nastavení';

  @override
  String get settingsNoResults => 'Žádné odpovídající nastavení';

  @override
  String get settingsDataPrivacy => 'Data a soukromí';

  @override
  String get workspacePreferences => 'Zobrazení a ovládání';

  @override
  String get workspaceManage => 'Spravovat';

  @override
  String get selectedDayAgenda => 'Vybraný den';

  @override
  String get notificationTroubleshooting => 'Oprávnění a řešení problémů';

  @override
  String get settingsConnection => 'Připojení';

  @override
  String get settingsAdvanced => 'Pokročilé';

  @override
  String get unsavedChangesMessage =>
      'Máte neuložené změny. Zahodit je a odejít?';

  @override
  String get backupWorkspaceSelection =>
      'Úplná záloha obsahuje data a výběr zapnutých pracovních prostorů.';

  @override
  String get assistantLayoutPreview => 'AI · Náhled rozložení';

  @override
  String get assistantSelectionContext => 'Používá aktuální výběr jako kontext';

  @override
  String get assistantPreviewDescription =>
      'A separate place to discuss and work with your schedule. This preview only demonstrates the layout; AI is not connected.';

  @override
  String get assistantDraftLabel => 'Koncept zprávy';

  @override
  String get assistantPreviewNoSend =>
      'Pouze náhled rozložení. Nic se neodešle ani nezmění.';

  @override
  String get resizePanel => 'Změnit velikost panelu';

  @override
  String get minimizeWindow => 'Minimalizovat';

  @override
  String get maximizeWindow => 'Maximalizovat';

  @override
  String get restoreWindow => 'Obnovit velikost okna';

  @override
  String get closeWindow => 'Zavřít okno';

  @override
  String get courseSystemReminder => 'Systémové připomenutí';

  @override
  String courseReminderInherit(String reminder) {
    return 'Použít výchozí ($reminder)';
  }

  @override
  String get courseReminderMasterOff =>
      'Systémová připomenutí jsou v nastavení oznámení vypnutá. Nastavení tohoto kurzu lze přesto uložit.';

  @override
  String get courseReminderDefaultOff =>
      'Výchozí připomenutí kurzu není nastavené. Zde vyberte vlastní nebo nastavte výchozí v nastavení oznámení.';

  @override
  String get courseReminderDeliveryHint =>
      'Tato volba se ukládá s kurzem. Doručení závisí na systémových oprávněních k oznámením a omezeních běhu na pozadí.';

  @override
  String get courseReminderPermissionUnknown =>
      'Stav systémových oznámení zatím nebyl zkontrolován. Než se na připomenutí spolehnete, zkontrolujte nastavení oznámení.';

  @override
  String get courseReminderMinutesLabel => 'Minuty před začátkem kurzu';

  @override
  String get exportAction => 'Exportovat';

  @override
  String get datePickerSelectWeek => 'Vybrat týden';

  @override
  String get datePickerSelectMonth => 'Vybrat měsíc';

  @override
  String get generalDateLabelFormatDescription =>
      'Platí pro navigaci podle data na počítačích i menších obrazovkách.';

  @override
  String get dateRangeTitle => 'Vybrat rozsah dat';

  @override
  String get dateRangeCustom => 'Vlastní';

  @override
  String get dateRangeChooseStart => 'Vyberte počáteční datum';

  @override
  String get dateRangeChooseEnd => 'Vyberte koncové datum';

  @override
  String get dateRangeLimit => 'Vyberte 1 až 14 dní včetně obou krajních dat.';

  @override
  String dateRangeCustomDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dní',
      few: '$days dny',
      one: '1 den',
    );
    return 'Vlastní · $_temp0';
  }

  @override
  String get timePickerWheelMode => 'Vybrat pomocí koleček';

  @override
  String get courseReminderUseDefault => 'Použít výchozí';

  @override
  String get courseReminderInvalidMinutes =>
      'Zadejte celé nezáporné číslo minut.';

  @override
  String get generalCustomColumnWidth => 'Šířka sloupců ve vlastním zobrazení';

  @override
  String get generalCustomColumnWidthAuto => 'Automaticky';

  @override
  String get generalCustomColumnWidthManual => 'Minimální šířka';

  @override
  String get generalCustomColumnWidthMinimum => 'Minimální šířka dne';

  @override
  String get generalCustomColumnWidthHint =>
      'Všechny dny mají stejnou minimální šířku. Sloupce vyplní dostupné místo nebo se posouvají vodorovně. Platí pouze pro vlastní zobrazení.';

  @override
  String get settingsAppearanceLanguage => 'Vzhled a jazyk';

  @override
  String get settingsAppearanceDetails => 'Barvy a obrysy';

  @override
  String get monthNoEvents => 'Na tento den nejsou žádné události';

  @override
  String get settingsOverview => 'Přehled';

  @override
  String get settingsThemeTarget => 'Motiv pro';

  @override
  String get settingsColorMode => 'Barevný režim';

  @override
  String get settingsNotificationPreferences => 'Nastavení připomenutí';

  @override
  String get settingsNotificationPreferencesSummary =>
      'Výchozí připomenutí, oprávnění a spolehlivost';

  @override
  String get settingsFeaturesSummary => 'Pracovní prostory a navigace';

  @override
  String get settingsPrivacySummary =>
      'Zásady ochrany soukromí a vymazání místních dat';

  @override
  String periodTimesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '1',
    );
    return 'Počet hodin: $_temp0';
  }

  @override
  String get periodTimesPeriodColumn => 'Hodina';

  @override
  String get periodTimesDurationColumn => 'Délka';

  @override
  String get periodTimesGapColumn => 'Přestávka';

  @override
  String periodTimesMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get periodTimesSavePending => 'Čeká na uložení…';

  @override
  String get periodTimesSaveFailed => 'Neuloženo · Uložení selhalo';

  @override
  String get periodTimesInvalidStatus => 'Neuloženo · Opravte označené časy';

  @override
  String get dataRecoveryWriteStateUnknownMessage =>
      'Sked nemohl ověřit, zda bylo poslední uložení vráceno zpět. Zápis je pozastaven a kopie pro obnovení jsou zachovány. Zkontrolujte úložiště a zkuste data znovu načíst.';

  @override
  String get settingsPanelDisplayMode => 'Zobrazení panelů';

  @override
  String get settingsPanelDisplayModeGlobal =>
      'Společné pro rozvrhy a kalendáře';

  @override
  String get settingsPanelDisplayOverlay => 'Překrytí';

  @override
  String get settingsPanelDisplaySideBySide => 'Vedle sebe';

  @override
  String get settingsPanelDisplayAutomatic => 'Automaticky';

  @override
  String get settingsPanelDisplayOverlayDescription =>
      'Překryje pravou stranu bez změny šířky kalendáře.';

  @override
  String get settingsPanelDisplaySideBySideDescription =>
      'Upřednostní zobrazení vedle sebe; překryje kalendář jen při nedostatku místa.';

  @override
  String get settingsPanelDisplayAutomaticDescription =>
      'Zobrazí panely vedle sebe, pokud kalendář zůstane čitelný, jinak jako překrytí.';

  @override
  String get toolbarNavigationEssentialHint =>
      'Vypnutím Nastavení nebo Pracovního prostoru na panelu nástrojů je přesunete do nabídky Další, nikoli odstraníte. Nabídku Další nelze skrýt, pokud obsahuje nezbytné akce. Přepínání pracovních prostorů se zobrazuje pouze při skryté dolní navigaci a více zapnutých pracovních prostorech.';

  @override
  String get reminderEnded => 'Skončilo';

  @override
  String get reminderAutoCloseHint =>
      'Zavře se za 10 sekund. Interakcí ponecháte panel otevřený.';

  @override
  String get showReminderIndependently => 'Otevřít samostatně';

  @override
  String get categoryManagerTitle => 'Spravovat kategorie';

  @override
  String get categoryHidden => 'Skrytá';

  @override
  String get categoryShowOnCalendar => 'Zobrazit v kalendáři';

  @override
  String get categoryHideOnCalendar => 'Skrýt v kalendáři';

  @override
  String get categoryEditColor => 'Změnit barvu kategorie';

  @override
  String get categoryThemePalette => 'Paleta motivu';

  @override
  String get categoryCustomColor => 'Vlastní';

  @override
  String get colorHexInvalid => 'Zadejte šestimístný šestnáctkový kód barvy.';

  @override
  String categoryColorSlot(int number) {
    return 'Barva motivu $number';
  }

  @override
  String get microsoftStoreUpdateButton => 'Microsoft Store';

  @override
  String get storeUpdateDelay =>
      'Aktualizace v obchodě mohou být dostupné později. Dostupnost určuje stránka v obchodě.';

  @override
  String get storePrereleaseNotice =>
      'Oznámení o předběžných verzích vás nepřihlásí do testovacího programu obchodu.';

  @override
  String get updateFoundTitle => 'Je dostupná nová verze';

  @override
  String get updateNoNotes => 'Poznámky k vydání nebyly poskytnuty.';

  @override
  String get updateLater => 'Později';

  @override
  String get updateRetry => 'Zkusit znovu';

  @override
  String get updatePrerelease => 'Předběžná verze';

  @override
  String get updateNetworkFailure =>
      'Aktualizace se nepodařilo zkontrolovat. Ověřte připojení a zkuste to znovu.';

  @override
  String updateNoNewerVersion(String version) {
    return 'Novější verze nebyla nalezena (aktuální: $version)';
  }

  @override
  String get backupRestoreInProgressTitle => 'Obnovování zálohy…';

  @override
  String get backupRestoreInProgressMessage =>
      'Data a nastavení bude možné změnit po dokončení obnovy. Stále si je můžete prohlížet.';
}
