// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'Spoluučedník';

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
  String get createTimetable => 'Nový rozvrh';

  @override
  String get jumpToWeek => 'Skočit na týden';

  @override
  String get timetable => 'Rozvrh';

  @override
  String get timetableName => 'Název jízdního řádu';

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
  String get settingsSectionTimetable => 'Timetable';

  @override
  String get settingsSectionGeneralSchedule => 'General schedule';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionApp => 'App';

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
      'Popup propuštění, mezery, šedé kurzy a mřížkové čáry';

  @override
  String get showTimetableGridLines => 'Zobrazit řádky mřížky rozvrhu';

  @override
  String get showTimetableGridLinesHint =>
      'Ovládejte, zda jsou v rozvrhu viditelné vodorovné a svislé čáry mřížky.';

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
  String get outlineWidthUnit => 'Px';

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
      'Úplné obnovení nahradí aktuální data aplikace. Klíče API vlastního parseru jsou uloženy v zabezpečeném úložišti a nezapisují se do záloh.';

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
      'Úplná záloha aplikace byla obnovena. Klíče API parseru je nutné zadat znovu.';

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
  String get googlePlay => 'služby Google Play';

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
      'Unable to fetch the latest version from GitHub. You can still open GitHub Releases below.';

  @override
  String get githubRepository => 'Úložiště GitHub';

  @override
  String get openGithubFailed => 'Nelze otevřít odkaz na úložiště GitHub';

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
      'Timetable data and related settings are stored in a local file named Sked_data.json inside the app documents directory. Editable school-site configuration is stored separately in Sked_school_sites.json. Custom timetable parser settings are stored locally; the custom API key is stored through the platform secure-storage layer when available. When used in a browser, the same kinds of data are stored in browser storage. The app does not automatically upload this local data to a developer-controlled server.';

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
  String get schoolWebImportParserUsed => 'Parser';

  @override
  String get schoolWebImportWarnings => 'Importovat poznámky';

  @override
  String get schoolWebImportOpenPageHint =>
      'Přihlaste se na stránku školy v aplikaci a přejděte na stránku časového rozvrhu ručně.';

  @override
  String get schoolWebImportConfigMissing =>
      'Custom parser configuration is incomplete. Fill in the base URL, API key, and model first.';

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
  String get schoolWebImportGoBack => 'Předchozí stránka';

  @override
  String get schoolWebImportLoadingPage => 'Načítání stránky…';

  @override
  String get schoolWebImportParsing => 'Analyzuje aktuální stránku...';

  @override
  String get schoolWebImportLoadFailed =>
      'Načítání stránky selhalo. Prosím, obnovte nebo zkuste to znovu později.';

  @override
  String get schoolWebImportLoadTimedOut =>
      'Načítání stránky vypršelo. Prosím, osvěžte a zkuste znovu.';

  @override
  String get schoolWebImportEmptyPage =>
      'Aktuální obsah stránky je prázdný a zatím nelze importovat.';

  @override
  String get schoolWebImportSuccess => 'Webový rozvrh importován';

  @override
  String get schoolImportParserSettingsTitle => 'Nastavení rozvrhu parseru';

  @override
  String get schoolImportParserSettingsDesc =>
      'Configure your own OpenAI-compatible endpoint. HTTP and HTTPS base URLs are supported.';

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
  String schoolImportParserModelsFetched(int count) {
    return 'Přihlášené modely $count';
  }

  @override
  String get schoolImportParserPlaintextWarning =>
      'The custom API key is stored through the platform secure-storage layer when available. Only use custom parser credentials and HTTP endpoints on devices, browsers, and networks you trust.';

  @override
  String get schoolImportParserCustomConfigIncomplete =>
      'Konfigurace vlastního parseru je neúplná. Nejprve vyplňte základní adresu URL, klíč API a model.';

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
  String get monthJanuary => 'Jan';

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
  String get generalSchedule => 'General schedule';

  @override
  String get studentTimetable => 'Student timetable';

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
      'Spravujte kalendáře, události, připomenutí a data JSON / ICS.';

  @override
  String get firstLaunchStartStudent => 'Začít s rozvrhem';

  @override
  String get firstLaunchStartGeneral => 'Začít s plánem';

  @override
  String get firstLaunchPrivacyHint =>
      'Před vstupem si přečtete a odsouhlasíte zásady ochrany osobních údajů.';

  @override
  String get firstLaunchPreparingPrivacy =>
      'Připravuje se kontrola zásad ochrany osobních údajů...';

  @override
  String get switchMode => 'Switch mode';

  @override
  String get generalScheduleComingSoon => 'General schedule coming soon';

  @override
  String get switchToStudentTimetable => 'Switch to Student timetable';

  @override
  String get mySchedule => 'My schedule';

  @override
  String get today => 'Today';

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
  String get viewWeek => 'Week';

  @override
  String get viewDay => 'Day';

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
}
